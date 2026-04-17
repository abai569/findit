import 'dart:io';
import 'dart:convert';
import 'package:webdav_client/webdav_client.dart';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'encryption_service.dart';

class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  factory WebDAVService() => _instance;
  WebDAVService._internal();

  Client? _client;
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

  Future<Client> getClient() async {
    if (_client != null) return _client!;

    final creds = await getCredentials();
    if (creds == null) {
      throw Exception('WebDAV credentials not found');
    }

    _client = newClient(
      creds['url']!,
      user: creds['username']!,
      password: creds['password']!,
    );

    await _client!.mkdir(_backupDir);

    return _client!;
  }

  Future<void> resetClient() async {
    _client = null;
  }

  Future<int> _getBackupVersion() async {
    final metadata = await _dbService.getSyncMetadata();
    return metadata?['last_sync_version'] as int? ?? 0;
  }

  Future<String> _generateBackupFileName(int version, bool isFull) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final deviceId = await _getDeviceId();
    return 'findit_backup_v${version}_$deviceId${isFull ? '_full' : '_incr'}_$timestamp.zip.enc';
  }

  Future<String> _getDeviceId() async {
    final metadata = await _dbService.getSyncMetadata();
    if (metadata?['device_id'] != null) {
      return metadata!['device_id'] as String;
    }
    final deviceId = const Uuid().v4().substring(0, 8);
    await _dbService.updateSyncMetadata(deviceId: deviceId);
    return deviceId;
  }

  Future<Map<String, dynamic>> _getChangedItems(int sinceVersion) async {
    final metadata = await _dbService.getSyncMetadata();
    final lastBackupTime = metadata?['last_backup_time'] as String?;
    
    if (lastBackupTime == null) {
      return {'full': true, 'items': await _dbService.getAllItems()};
    }

    final lastBackup = DateTime.parse(lastBackupTime);
    final allItems = await _dbService.getAllItems();
    final changedItems = allItems
        .where((item) => item.updatedAt.isAfter(lastBackup))
        .toList();

    return {
      'full': changedItems.length == allItems.length,
      'items': changedItems,
    };
  }

  Future<String> backup() async {
    final client = await getClient();
    final version = await _getBackupVersion();
    final changes = await _getChangedItems(version);
    final isFullBackup = changes['full'] as bool || version == 0;
    final items = changes['items'] as List;

    if (items.isEmpty && !isFullBackup) {
      throw Exception('没有需要备份的变更');
    }

    final backupVersion = version + 1;
    final fileName = await _generateBackupFileName(backupVersion, isFullBackup);

    final tempDir = await _createBackupPackage(items, isFullBackup);
    final encryptedPath = await _encryptBackupFile(tempDir.path);

    final encryptedFile = File(encryptedPath);
    final fileBytes = await encryptedFile.readAsBytes();

    await client.writeBytes('$_backupDir/$fileName', fileBytes);

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

    await encryptedFile.delete();
    await Directory(tempDir.path).delete(recursive: true);

    await _cleanupOldBackups(client);

    return fileName;
  }

  Future<Directory> _createBackupPackage(List items, bool isFull) async {
    final tempDir = await Directory.systemTemp.createTemp('findit_backup_');
    
    final dbPath = await _dbService.database.then((db) => db.path);
    final dbFile = File(dbPath);
    
    if (isFull) {
      await dbFile.copy('${tempDir.path}/database.db');
    }

    final itemsJson = jsonEncode(items.map((item) => item.toMap()).toList());
    await File('${tempDir.path}/items.json').writeAsString(itemsJson);

    final metadata = await _dbService.getSyncMetadata() ?? {};
    metadata['backup_time'] = DateTime.now().toIso8601String();
    metadata['is_full_backup'] = isFull;
    await File('${tempDir.path}/metadata.json')
        .writeAsString(jsonEncode(metadata));

    final locations = await _dbService.getAllLocations();
    await File('${tempDir.path}/locations.json')
        .writeAsString(jsonEncode(locations.map((l) => l.toMap()).toList()));

    final categories = await _dbService.getAllCategories();
    await File('${tempDir.path}/categories.json')
        .writeAsString(jsonEncode(categories.map((c) => c.toMap()).toList()));

    return tempDir;
  }

  Future<String> _encryptBackupFile(String dirPath) async {
    final tempFile = File('${dirPath}_encrypted.enc');
    final sink = tempFile.openWrite();

    final files = [
      'database.db',
      'items.json',
      'metadata.json',
      'locations.json',
      'categories.json',
    ];

    for (final fileName in files) {
      final file = File('$dirPath/$fileName');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final encrypted = _encryption.encryptBytes(bytes);
        final header = '${fileName.length}';
        sink.add(utf8.encode(header.padLeft(4, '0')));
        sink.add(utf8.encode(fileName));
        sink.add(encrypted);
      }
    }

    await sink.close();
    return tempFile.path;
  }

  Future<void> _cleanupOldBackups(Client client) async {
    final history = await _dbService.getBackupHistory();
    if (history.length <= 5) return;

    final filesToKeep = history.take(5).map((h) => h['file_name'] as String).toSet();
    
    try {
      final files = await client.readDir(_backupDir);
      for (final file in files) {
        if (!filesToKeep.contains(file.name) && 
            file.name.startsWith('findit_backup_') &&
            file.name.endsWith('.enc')) {
          await client.remove('$_backupDir/${file.name}');
        }
      }
    } catch (e) {
      print('清理旧备份失败：$e');
    }
  }

  Future<String> restore(String? fileName) async {
    final client = await getClient();

    if (fileName == null) {
      final files = await client.readDir(_backupDir);
      final backupFiles = files
          .where((f) => f.name.startsWith('findit_backup_') && 
                       f.name.endsWith('.enc'))
          .toList();
      
      if (backupFiles.isEmpty) {
        throw Exception('没有找到备份文件');
      }
      
      backupFiles.sort((a, b) => b.name.compareTo(a.name));
      fileName = backupFiles.first.name;
    }

    final encryptedBytes = await client.readBytes('$_backupDir/$fileName');
    final tempDir = await _decryptBackupFile(encryptedBytes);

    await _importBackupData(tempDir.path);

    await Directory(tempDir.path).delete(recursive: true);

    return '恢复成功';
  }

  Future<Directory> _decryptBackupFile(List<int> encryptedBytes) async {
    final tempFile = await File.systemTemp.createTemp('findit_decrypt_');
    await tempFile.writeAsBytes(encryptedBytes);
    
    final decryptedDir = await Directory.systemTemp.createTemp('findit_restored_');
    
    final bytes = await tempFile.readAsBytes();
    int offset = 0;

    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;
      
      final headerLength = int.parse(
        utf8.decode(bytes.sublist(offset, offset + 4)),
      );
      offset += 4;

      if (offset + headerLength > bytes.length) break;
      
      final fileName = utf8.decode(bytes.sublist(offset, offset + headerLength));
      offset += headerLength;

      final encryptedData = bytes.sublist(offset);
      final decrypted = _encryption.decryptBytes(encryptedData);

      await File('${decryptedDir.path}/$fileName').writeAsBytes(decrypted);
      offset = bytes.length;
    }

    await tempFile.delete();
    return decryptedDir;
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
        .where((f) => f.name.startsWith('findit_backup_') && 
                     f.name.endsWith('.enc'))
        .map((f) => f.name)
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
