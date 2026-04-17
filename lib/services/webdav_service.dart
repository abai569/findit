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
    return 'findit_backup_v${version}_$timestamp.zip.enc';
  }

  Future<String> backup() async {
    final client = await getClient();
    final version = await _getBackupVersion();
    final backupVersion = version + 1;
    final fileName = await _generateBackupFileName(backupVersion);

    try {
      // Export data
      final items = await _dbService.getAllItems();
      final locations = await _dbService.getAllLocations();
      final categories = await _dbService.getAllCategories();
      final metadata = await _dbService.getSyncMetadata() ?? {};
      
      metadata['backup_time'] = DateTime.now().toIso8601String();
      metadata['last_sync_version'] = backupVersion;

      // Create JSON data
      final backupData = {
        'items': items.map((i) => i.toMap()).toList(),
        'locations': locations.map((l) => l.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'metadata': metadata,
      };

      final jsonData = jsonEncode(backupData);
      final encryptedData = _encryption.encrypt(jsonData);
      final fileBytes = utf8.encode(encryptedData);

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

      return fileName;
    } catch (e) {
      rethrow;
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
    await _importBackupData(encryptedBytes);

    return '恢复成功';
  }

  Future<void> _importBackupData(List<int> encryptedBytes) async {
    final db = await _dbService.database;

    try {
      final encrypted = utf8.decode(encryptedBytes, allowMalformed: true);
      final decrypted = _encryption.decrypt(encrypted);
      final backupData = jsonDecode(decrypted) as Map<String, dynamic>;

      await db.delete('items');
      await db.delete('locations');
      await db.delete('categories');

      final locations = backupData['locations'] as List? ?? [];
      for (var loc in locations) {
        await db.insert('locations', loc);
      }

      final categories = backupData['categories'] as List? ?? [];
      for (var cat in categories) {
        await db.insert('categories', cat);
      }

      final items = backupData['items'] as List? ?? [];
      for (var item in items) {
        await db.insert('items', item);
      }

      final metadata = backupData['metadata'] as Map? ?? {};
      await _dbService.updateSyncMetadata(
        lastBackupTime: metadata['backup_time'] as String?,
        lastSyncVersion: metadata['last_sync_version'] as int?,
        deviceId: metadata['device_id'] as String?,
      );
    } catch (e) {
      throw Exception('导入数据失败：$e');
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
