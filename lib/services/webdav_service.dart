import 'dart:convert';
import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'database.dart';
import 'encryption_service.dart';

class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  factory WebDAVService() => _instance;
  WebDAVService._internal();

  webdav.Client? _client;
  final DatabaseService _dbService = DatabaseService();
  final EncryptionService _encryption = EncryptionService();

  static const String _prefsKey = 'webdav_config';
  static const String _backupDir = '/findit_backups';

  Future<void> saveCredentials({
    required String url,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final config = {
      'url': url,
      'username': username,
      'password': password,
    };
    final encrypted = _encryption.encrypt(jsonEncode(config));
    await prefs.setString(_prefsKey, encrypted);
  }

  Future<Map<String, String>?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(_prefsKey);
    if (encrypted == null) return null;
    
    try {
      final decrypted = _encryption.decrypt(encrypted);
      final config = jsonDecode(decrypted) as Map<String, dynamic>;
      return {
        'url': config['url'] as String,
        'username': config['username'] as String,
        'password': config['password'] as String,
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefsKey);
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<webdav.Client> getClient() async {
    if (_client != null) return _client!;

    final creds = await getCredentials();
    if (creds == null) {
      throw Exception('WebDAV credentials not found');
    }

    _client = webdav.newClient(
      creds['url']!,
      user: creds['username']!,
      password: creds['password']!,
    );

    try {
      await _client!.mkdir(_backupDir);
    } catch (e) {
      // Directory might already exist
    }

    return _client!;
  }

  Future<void> resetClient() async {
    _client = null;
  }

  Future<int> _getBackupVersion() async {
    final metadata = await _dbService.getSyncMetadata();
    return metadata?['last_sync_version'] as int? ?? 0;
  }

  Future<String> _generateBackupFileName(int version) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final deviceId = await _getDeviceId();
    return 'findit_backup_v${version}_${deviceId}_$timestamp.zip.enc';
  }

  Future<String> _getDeviceId() async {
    final metadata = await _dbService.getSyncMetadata();
    if (metadata?['device_id'] != null) {
      return metadata!['device_id'] as String;
    }
    final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    await _dbService.updateSyncMetadata(deviceId: deviceId);
    return deviceId;
  }

  Future<String> backup() async {
    final client = await getClient();
    final version = await _getBackupVersion();
    final backupVersion = version + 1;
    final fileName = await _generateBackupFileName(backupVersion);

    final tempDir = await Directory.systemTemp.createTemp('findit_backup_');
    
    try {
      // Export data
      final items = await _dbService.getAllItems();
      final locations = await _dbService.getAllLocations();
      final categories = await _dbService.getAllCategories();
      final metadata = await _dbService.getSyncMetadata() ?? {};
      
      metadata['backup_time'] = DateTime.now().toIso8601String();
      metadata['last_sync_version'] = backupVersion;

      await File('${tempDir.path}/items.json').writeAsString(jsonEncode(items.map((i) => i.toMap()).toList()));
      await File('${tempDir.path}/locations.json').writeAsString(jsonEncode(locations.map((l) => l.toMap()).toList()));
      await File('${tempDir.path}/categories.json').writeAsString(jsonEncode(categories.map((c) => c.toMap()).toList()));
      await File('${tempDir.path}/metadata.json').writeAsString(jsonEncode(metadata));

      // Copy images
      final imagesDir = Directory('${tempDir.path}/images');
      await imagesDir.create();
      final appDir = await getApplicationDocumentsDirectory();
      final appImagesDir = Directory('${appDir.path}/images');
      if (await appImagesDir.exists()) {
        await _copyDirectory(appImagesDir, imagesDir);
      }

      // Zip and encrypt
      final zipPath = await _createZip(tempDir.path);
      final encryptedPath = await _encryptFile(zipPath);
      final encryptedFile = File(encryptedPath);
      final fileBytes = await encryptedFile.readAsBytes();

      // Upload
      await client.write('$_backupDir/$fileName', fileBytes);

      // Update metadata
      await _dbService.updateSyncMetadata(
        lastBackupTime: DateTime.now().toIso8601String(),
        lastSyncVersion: backupVersion,
      );

      await _dbService.addBackupHistory(
        backupTime: DateTime.now().toIso8601String(),
        backupVersion: backupVersion,
        fileName: fileName,
        fileSize: fileBytes.length,
      );

      // Cleanup
      await encryptedFile.delete();
      await File(zipPath).delete();
      await tempDir.delete(recursive: true);

      await _cleanupOldBackups(client);

      return fileName;
    } catch (e) {
      await tempDir.delete(recursive: true);
      rethrow;
    }
  }

  Future<String> _createZip(String dirPath) async {
    final zipPath = '${dirPath}.zip';
    final result = await Process.run('zip', ['-r', zipPath, '.'], workingDirectory: dirPath);
    if (result.exitCode != 0) {
      throw Exception('Failed to create zip: ${result.stderr}');
    }
    return zipPath;
  }

  Future<String> _encryptFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final encrypted = _encryption.encryptBytes(bytes);
    final encryptedPath = '${filePath}.enc';
    await File(encryptedPath).writeAsBytes(encrypted);
    return encryptedPath;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: true)) {
      final relativePath = entity.path.substring(source.path.length + 1);
      final newPath = '${destination.path}/$relativePath';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      }
    }
  }

  Future<void> _cleanupOldBackups(webdav.Client client) async {
    final history = await _dbService.getBackupHistory();
    if (history.length <= 5) return;

    final filesToKeep = history.take(5).map((h) => h['file_name'] as String).toSet();
    
    try {
      final files = await client.readDir(_backupDir);
      for (final file in files) {
        final fileName = file.name ?? '';
        if (!filesToKeep.contains(fileName) && 
            fileName.startsWith('findit_backup_') &&
            fileName.endsWith('.enc')) {
          await client.remove('$_backupDir/$fileName');
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<String> restore(String? fileName) async {
    final client = await getClient();

    if (fileName == null) {
      final files = await client.readDir(_backupDir);
      final backupFiles = files
          .where((f) => (f.name ?? '').startsWith('findit_backup_') && 
                       (f.name ?? '').endsWith('.enc'))
          .toList();
      
      if (backupFiles.isEmpty) {
        throw Exception('没有找到备份文件');
      }
      
      backupFiles.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
      fileName = backupFiles.first.name;
    }

    if (fileName == null) {
      throw Exception('备份文件名为空');
    }

    final encryptedBytes = await client.read('$_backupDir/$fileName');
    final tempDir = await _decryptAndExtract(encryptedBytes);

    await _importBackupData(tempDir.path);
    await tempDir.delete(recursive: true);

    return '恢复成功';
  }

  Future<Directory> _decryptAndExtract(List<int> encryptedBytes) async {
    // Decrypt
    final decrypted = _encryption.decryptBytes(encryptedBytes);
    
    final tempDir = await Directory.systemTemp.createTemp('findit_decrypt_');
    final tempFile = File('${tempDir.path}/encrypted.zip');
    await tempFile.writeAsBytes(decrypted);
    
    final extractDir = await Directory.systemTemp.createTemp('findit_restored_');
    
    // Unzip
    final result = await Process.run('unzip', ['-o', tempFile.path, '-d', extractDir.path]);
    await tempDir.delete(recursive: true);
    
    if (result.exitCode != 0) {
      throw Exception('Failed to extract: ${result.stderr}');
    }
    
    return extractDir;
  }

  Future<void> _importBackupData(String dirPath) async {
    final db = await _dbService.database;

    await db.delete('items');
    await db.delete('locations');
    await db.delete('categories');

    final locationsFile = File('$dirPath/locations.json');
    if (await locationsFile.exists()) {
      final locations = jsonDecode(await locationsFile.readAsString()) as List;
      for (var loc in locations) {
        await db.insert('locations', loc);
      }
    }

    final categoriesFile = File('$dirPath/categories.json');
    if (await categoriesFile.exists()) {
      final categories = jsonDecode(await categoriesFile.readAsString()) as List;
      for (var cat in categories) {
        await db.insert('categories', cat);
      }
    }

    final itemsFile = File('$dirPath/items.json');
    if (await itemsFile.exists()) {
      final items = jsonDecode(await itemsFile.readAsString()) as List;
      for (var item in items) {
        await db.insert('items', item);
      }
    }

    final metadataFile = File('$dirPath/metadata.json');
    if (await metadataFile.exists()) {
      final metadata = jsonDecode(await metadataFile.readAsString()) as Map;
      await _dbService.updateSyncMetadata(
        lastBackupTime: metadata['backup_time'] as String?,
        lastSyncVersion: metadata['last_sync_version'] as int?,
        deviceId: metadata['device_id'] as String?,
      );
    }
  }

  Future<List<String>> listBackups() async {
    final client = await getClient();
    final files = await client.readDir(_backupDir);
    return files
        .where((f) => (f.name ?? '').startsWith('findit_backup_') && 
                     (f.name ?? '').endsWith('.enc'))
        .map((f) => f.name ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<bool> testConnection() async {
    try {
      final client = await getClient();
      await client.readDir(_backupDir);
      return true;
    } catch (e) {
      return false;
    }
  }
}
