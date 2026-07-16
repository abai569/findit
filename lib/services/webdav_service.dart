import 'dart:convert';
import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'encryption_service.dart';
import 'image_service.dart';

class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  factory WebDAVService() => _instance;
  WebDAVService._internal();

  webdav.Client? _client;
  final DatabaseService _dbService = DatabaseService();
  final EncryptionService _encryption = EncryptionService();
  final ImageService _imageService = ImageService();

  static const String _prefsKey = 'webdav_config';
  static const String _backupDir = '/findit_backups';
  static const int _backupFormatVersion = 2;

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
    return 'findit_backup_v${version}_$timestamp.json.enc';
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

      final images = <String, dynamic>{};
      final itemMaps = <Map<String, dynamic>>[];
      var imageIndex = 0;
      for (final item in items) {
        final imageRefs = <String>[];
        for (final imagePath in item.imagePaths) {
          final file = File(imagePath);
          if (!await file.exists()) {
            throw Exception('照片文件不存在：$imagePath');
          }

          final imageRef = 'image_${imageIndex++}';
          images[imageRef] = {
            'extension': _fileExtension(imagePath),
            'data': base64Encode(await file.readAsBytes()),
          };
          imageRefs.add(imageRef);
        }

        final itemMap = item.toMap();
        itemMap['image_path'] = null;
        itemMap['image_paths'] = jsonEncode(imageRefs);
        itemMaps.add(itemMap);
      }

      // Create JSON data
      final backupData = {
        'format_version': _backupFormatVersion,
        'items': itemMaps,
        'images': images,
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
    final restoredImagePaths = <String>[];
    final oldImagePaths = (await _dbService.getAllItems())
        .expand((item) => item.imagePaths)
        .toSet();
    var databaseCommitted = false;

    try {
      final encrypted = utf8.decode(encryptedBytes, allowMalformed: true);
      final decrypted = _encryption.decrypt(encrypted);
      final backupData = jsonDecode(decrypted) as Map<String, dynamic>;
      final formatVersion = backupData['format_version'] as int? ?? 1;
      final images = backupData['images'] as Map<String, dynamic>? ?? {};
      final restoredImages = <String, String>{};

      if (formatVersion >= 2) {
        if (formatVersion != _backupFormatVersion) {
          throw Exception('不支持的备份格式：$formatVersion');
        }
        for (final entry in images.entries) {
          final imageData = Map<String, dynamic>.from(entry.value as Map);
          final bytes = base64Decode(imageData['data'] as String);
          final path = await _imageService.saveImageBytes(
            bytes,
            imageData['extension'] as String? ?? '.jpg',
          );
          restoredImages[entry.key] = path;
          restoredImagePaths.add(path);
        }
      }

      final locations = backupData['locations'] as List? ?? [];
      final categories = backupData['categories'] as List? ?? [];
      final items = backupData['items'] as List? ?? [];
      final metadata = backupData['metadata'] as Map? ?? {};
      final referencedImageRefs = <String>{};
      if (formatVersion >= 2) {
        for (final rawItem in items) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          referencedImageRefs.addAll(
            _decodeStringList(item['image_paths'] as String?),
          );
        }
        final missingRefs = referencedImageRefs
            .where((ref) => !restoredImages.containsKey(ref))
            .toList();
        if (missingRefs.isNotEmpty) {
          throw Exception('备份缺少照片文件：${missingRefs.join(', ')}');
        }
        final unusedRefs = restoredImages.keys
            .where((ref) => !referencedImageRefs.contains(ref))
            .toList();
        if (unusedRefs.isNotEmpty) {
          throw Exception('备份包含未关联的照片文件');
        }
      }
      await db.transaction((txn) async {
        await txn.delete('items');
        await txn.delete('locations');
        await txn.delete('categories');

        for (final loc in locations) {
          await txn.insert('locations', Map<String, dynamic>.from(loc as Map));
        }

        for (final cat in categories) {
          await txn.insert('categories', Map<String, dynamic>.from(cat as Map));
        }

        for (final rawItem in items) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          if (formatVersion >= 2) {
            final refs = _decodeStringList(item['image_paths'] as String?);
            final paths = refs
                .map((ref) => restoredImages[ref])
                .whereType<String>()
                .toList();
            item['image_path'] = paths.isEmpty ? null : paths.first;
            item['image_paths'] = jsonEncode(paths);
          }
          await txn.insert('items', item);
        }

        final syncMetadata = {
          'last_backup_time': metadata['backup_time'] as String?,
          'last_sync_version': metadata['last_sync_version'] as int?,
          'device_id': metadata['device_id'] as String?,
        };
        final existingMetadata = await txn.query('sync_metadata');
        if (existingMetadata.isEmpty) {
          await txn.insert('sync_metadata', syncMetadata);
        } else {
          await txn.update(
            'sync_metadata',
            syncMetadata,
            where: 'id = ?',
            whereArgs: [existingMetadata.first['id']],
          );
        }
      });
      databaseCommitted = true;

      final newImagePaths = (await _dbService.getAllItems())
          .expand((item) => item.imagePaths)
          .toSet();
      for (final path in oldImagePaths.difference(newImagePaths)) {
        try {
          await _imageService.deleteImage(path);
        } catch (e) {
          print('清理旧照片失败：$e');
        }
      }
    } catch (e) {
      for (final path in restoredImagePaths) {
        if (!databaseCommitted) {
          try {
            await _imageService.deleteImage(path);
          } catch (_) {}
        }
      }
      throw Exception('导入数据失败：$e');
    }
  }

  String _fileExtension(String path) {
    final normalizedPath = path.replaceAll('\\', '/');
    final fileName = normalizedPath.substring(normalizedPath.lastIndexOf('/') + 1);
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex <= 0 ? '.jpg' : fileName.substring(dotIndex);
  }

  List<String> _decodeStringList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    return (jsonDecode(encoded) as List).whereType<String>().toList();
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
