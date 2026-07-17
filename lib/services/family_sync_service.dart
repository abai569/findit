import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'image_service.dart';

class FamilySyncService {
  static const _configuredUrl = String.fromEnvironment('POCKETBASE_URL');
  static const _authKey = 'pocketbase_auth';
  static const _familyIdKey = 'pocketbase_family_sync_family_id';
  static const _boundFamilyIdKey = 'pocketbase_family_sync_bound_family_id';

  static PocketBase? _pocketBase;

  final DatabaseService _db = DatabaseService();
  final ImageService _images = ImageService();
  Future<void>? _activeSync;

  static String get pocketBaseUrl =>
      _configuredUrl.trim().replaceFirst(RegExp(r'/$'), '');
  static bool get isConfigured => pocketBaseUrl.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured || _pocketBase != null) return;
    final prefs = await SharedPreferences.getInstance();
    final authStore = AsyncAuthStore(
      initial: prefs.getString(_authKey),
      save: (data) async {
        await prefs.setString(_authKey, data);
      },
      clear: () async {
        await prefs.remove(_authKey);
      },
    );
    _pocketBase = PocketBase(
      pocketBaseUrl,
      authStore: authStore,
      lang: 'zh-CN',
    );
    if (authStore.token.isNotEmpty && !authStore.isValid) {
      authStore.clear();
    } else if (authStore.isValid) {
      unawaited(_refreshAuth());
    }
  }

  static Future<void> _refreshAuth() async {
    try {
      await _pocketBase!
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 8));
    } on ClientException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _pocketBase!.authStore.clear();
      }
    } on TimeoutException {
      // Keep the cached token so the app remains usable while offline.
    }
  }

  PocketBase get _client {
    final client = _pocketBase;
    if (client == null) throw Exception('PocketBase 尚未初始化');
    return client;
  }

  RecordModel? get currentUser => isConfigured ? _pocketBase?.authStore.record : null;

  Future<String?> getFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_familyIdKey);
  }

  Future<void> initializeFamily() async {
    if (currentUser == null) return;
    final memberships = await _client.collection('family_members').getList(
          page: 1,
          perPage: 1,
          filter: _client.filter('user = {:user}', {'user': currentUser!.id}),
        );
    if (memberships.items.isEmpty) return;

    final familyId = memberships.items.first.getStringValue('family');
    final prefs = await SharedPreferences.getInstance();
    final boundFamilyId = prefs.getString(_boundFamilyIdKey);
    if (boundFamilyId != null && boundFamilyId != familyId) {
      await signOut();
      throw Exception('本机数据已绑定其他家庭，不能切换家庭账号');
    }
    await prefs.setString(_familyIdKey, familyId);
    if (boundFamilyId == null) {
      await _replaceWithRemoteFamily(familyId);
      await prefs.setString(_boundFamilyIdKey, familyId);
    } else {
      await sync();
    }
  }

  Future<void> signUp(String email, String password) async {
    _requireConfigured();
    try {
      await _client.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });
    } on ClientException catch (error) {
      throw Exception(_clientErrorMessage(error, auth: true));
    }
  }

  Future<void> signIn(String email, String password) async {
    _requireConfigured();
    try {
      await _client.collection('users').authWithPassword(email, password);
      await initializeFamily();
    } on ClientException catch (error) {
      throw Exception(_clientErrorMessage(error, auth: true));
    }
  }

  Future<void> signOut() async {
    _client.authStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_familyIdKey);
  }

  Future<String> createFamily(String name) async {
    await _requireUnboundDevice();
    if (name.trim().isEmpty) throw Exception('请输入家庭名称');
    try {
      final data = await _client.send<Map<String, dynamic>>(
        '/api/findit/create-family',
        method: 'POST',
        body: {'name': name.trim()},
      );
      final familyId = data['family_id'] as String;
      await _saveFamilyId(familyId);
      await _bindFamily(familyId);
      await sync();
      return data['invite_code'] as String;
    } on ClientException catch (error) {
      throw Exception(_clientErrorMessage(error));
    }
  }

  Future<void> joinFamily(String inviteCode) async {
    await _requireUnboundDevice();
    if (inviteCode.trim().isEmpty) throw Exception('请输入邀请码');
    try {
      final data = await _client.send<Map<String, dynamic>>(
        '/api/findit/join-family',
        method: 'POST',
        body: {'invite_code': inviteCode.trim().toUpperCase()},
      );
      final familyId = data['family_id'] as String;
      await _saveFamilyId(familyId);
      await _replaceWithRemoteFamily(familyId);
      await _bindFamily(familyId);
    } on ClientException catch (error) {
      throw Exception(_clientErrorMessage(error));
    }
  }

  Future<Map<String, dynamic>?> getFamily() async {
    final familyId = await getFamilyId();
    if (familyId == null) return null;
    final family = await _client.collection('families').getOne(familyId);
    final members = await _client.collection('family_members').getFullList(
          filter: _client.filter('family = {:family}', {'family': familyId}),
        );
    return {
      'id': family.id,
      'name': family.getStringValue('name'),
      'invite_code': family.getStringValue('invite_code'),
      'members': members.map((record) => record.toJson()).toList(),
    };
  }

  Future<void> sync() {
    final active = _activeSync;
    if (active != null) return active;
    final operation = _syncOnce();
    _activeSync = operation;
    return operation.whenComplete(() {
      if (identical(_activeSync, operation)) _activeSync = null;
    });
  }

  Future<void> _syncOnce() async {
    final familyId = await getFamilyId();
    if (currentUser == null || familyId == null) return;
    await _db.ensureSyncIds();

    final localLocations = await _db.getSyncRows('locations');
    final localCategories = await _db.getSyncRows('categories');
    final localItems = await _db.getSyncRows('items');
    var remoteLocations = await _getFamilyRecords('locations', familyId);
    var remoteCategories = await _getFamilyRecords('categories', familyId);

    final locations = await _mergeStructure(
      table: 'locations',
      familyId: familyId,
      localRows: localLocations,
      remoteRows: remoteLocations,
    );
    final categories = await _mergeStructure(
      table: 'categories',
      familyId: familyId,
      localRows: localCategories,
      remoteRows: remoteCategories,
    );
    await _db.applySyncRows(
      locations: locations,
      categories: categories,
      items: const [],
    );

    remoteLocations = await _getFamilyRecords('locations', familyId);
    remoteCategories = await _getFamilyRecords('categories', familyId);
    final remoteItems = await _getFamilyRecords('items', familyId);
    final items = await _mergeItems(
      familyId: familyId,
      localRows: localItems,
      remoteRows: remoteItems,
      remoteLocations: remoteLocations,
      remoteCategories: remoteCategories,
    );
    await _db.applySyncRows(
      locations: const [],
      categories: const [],
      items: items,
    );
  }

  Future<void> _replaceWithRemoteFamily(String familyId) async {
    final remoteLocations = await _getFamilyRecords('locations', familyId);
    final remoteCategories = await _getFamilyRecords('categories', familyId);
    final remoteItems = await _getFamilyRecords('items', familyId);

    final locations = <Map<String, dynamic>>[];
    final locationIds = <String, int>{};
    for (var index = 0; index < remoteLocations.length; index++) {
      final remote = remoteLocations[index];
      final id = index + 1;
      locationIds[remote['id'] as String] = id;
      locations.add({
        'id': id,
        'sync_id': remote['sync_id'],
        'name': remote['name'],
        'parent_id': null,
        'sort_order': remote['sort_order'],
        'updated_at': remote['updated'],
        'is_deleted': remote['is_deleted'] == true ? 1 : 0,
      });
    }

    final categories = <Map<String, dynamic>>[];
    final categoryIds = <String, int>{};
    for (var index = 0; index < remoteCategories.length; index++) {
      final remote = remoteCategories[index];
      final id = index + 1;
      categoryIds[remote['id'] as String] = id;
      categories.add({
        'id': id,
        'sync_id': remote['sync_id'],
        'name': remote['name'],
        'icon': remote['icon'],
        'color': remote['color'],
        'sort_order': remote['sort_order'],
        'updated_at': remote['updated'],
        'is_deleted': remote['is_deleted'] == true ? 1 : 0,
      });
    }

    String? fileToken;
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < remoteItems.length; index++) {
      final remote = remoteItems[index];
      final locationId = locationIds[remote['location']];
      if (locationId == null) continue;
      final photoNames = (remote['photos'] as List? ?? [])
          .whereType<String>()
          .toList();
      if (photoNames.isNotEmpty) fileToken ??= await _client.files.getToken();
      final imagePaths = await _downloadPhotos(remote, photoNames, fileToken);
      items.add({
        'id': index + 1,
        'sync_id': remote['sync_id'],
        'name': remote['name'],
        'location_id': locationId,
        'category_id': categoryIds[remote['category']],
        'image_path': imagePaths.isEmpty ? null : imagePaths.first,
        'image_paths': jsonEncode(imagePaths),
        'notes': remote['notes'],
        'created_at': remote['item_created_at'],
        'updated_at': remote['updated'],
        'is_deleted': remote['is_deleted'] == true ? 1 : 0,
        'sync_dirty': 0,
      });
    }

    await _db.replaceSyncData(
      locations: locations,
      categories: categories,
      items: items,
    );
  }

  Future<List<Map<String, dynamic>>> _getFamilyRecords(
    String collection,
    String familyId,
  ) async {
    final records = await _client.collection(collection).getFullList(
          filter: _client.filter('family = {:family}', {'family': familyId}),
        );
    return records.map((record) => record.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _mergeStructure({
    required String table,
    required String familyId,
    required List<Map<String, dynamic>> localRows,
    required List<Map<String, dynamic>> remoteRows,
  }) async {
    final localById = {
      for (final row in localRows) row['sync_id'] as String: row,
    };
    final remoteById = {
      for (final row in remoteRows) row['sync_id'] as String: row,
    };
    final merged = <Map<String, dynamic>>[];
    for (final syncId in {...localById.keys, ...remoteById.keys}) {
      final local = localById[syncId];
      final remote = remoteById[syncId];
      if (local != null &&
          remote != null &&
          _time(local['updated_at']).isAtSameMomentAs(_time(remote['updated']))) {
        merged.add(local);
        continue;
      }
      final useLocal = remote == null ||
          (local != null &&
              _time(local['updated_at']).isAfter(_time(remote['updated'])));
      if (useLocal) {
        final body = <String, dynamic>{
          'family': familyId,
          'sync_id': syncId,
          'name': local!['name'],
          'sort_order': local['sort_order'],
          'is_deleted': local['is_deleted'] == 1,
          if (table == 'locations') 'parent': '',
          if (table == 'categories') ...{
            'icon': local['icon'],
            'color': local['color'],
          },
        };
        final record = remote == null
            ? await _client.collection(table).create(body: body)
            : await _client.collection(table).update(
                  remote['id'] as String,
                  body: body,
                );
        merged.add({
          ...local,
          'updated_at': _time(record.updated).toIso8601String(),
        });
      } else {
        merged.add({
          'sync_id': syncId,
          'name': remote!['name'],
          'sort_order': remote['sort_order'],
          'updated_at': remote['updated'],
          'is_deleted': remote['is_deleted'] == true ? 1 : 0,
          if (table == 'locations') 'parent_id': null,
          if (table == 'categories') ...{
            'icon': remote['icon'],
            'color': remote['color'],
          },
        });
      }
    }
    return merged;
  }

  Future<List<Map<String, dynamic>>> _mergeItems({
    required String familyId,
    required List<Map<String, dynamic>> localRows,
    required List<Map<String, dynamic>> remoteRows,
    required List<Map<String, dynamic>> remoteLocations,
    required List<Map<String, dynamic>> remoteCategories,
  }) async {
    final localById = {
      for (final row in localRows) row['sync_id'] as String: row,
    };
    final remoteById = {
      for (final row in remoteRows) row['sync_id'] as String: row,
    };
    final localLocationSync = await _localIdToSyncId('locations');
    final localCategorySync = await _localIdToSyncId('categories');
    final locationLocalIds = await _syncIdToLocalId('locations');
    final categoryLocalIds = await _syncIdToLocalId('categories');
    final locationRecordIds = {
      for (final row in remoteLocations) row['sync_id']: row['id'] as String,
    };
    final categoryRecordIds = {
      for (final row in remoteCategories) row['sync_id']: row['id'] as String,
    };
    final locationSyncIds = {
      for (final row in remoteLocations) row['id']: row['sync_id'] as String,
    };
    final categorySyncIds = {
      for (final row in remoteCategories) row['id']: row['sync_id'] as String,
    };

    String? fileToken;
    final merged = <Map<String, dynamic>>[];
    for (final syncId in {...localById.keys, ...remoteById.keys}) {
      final local = localById[syncId];
      final remote = remoteById[syncId];
      if (local != null &&
          remote != null &&
          local['sync_dirty'] != 1 &&
          _time(local['updated_at']).isAtSameMomentAs(_time(remote['updated']))) {
        merged.add(local);
        continue;
      }
      final useLocal = remote == null ||
          local?['sync_dirty'] == 1 ||
          (local != null &&
              _time(local['updated_at']).isAfter(_time(remote['updated'])));
      if (useLocal) {
        final deleted = local!['is_deleted'] == 1;
        final locationSyncId = localLocationSync[local['location_id']];
        final locationRecordId = locationRecordIds[locationSyncId];
        if (locationRecordId == null) throw Exception('物品关联的位置尚未同步');
        final categorySyncId = localCategorySync[local['category_id']];
        final categoryRecordId =
            categorySyncId == null ? null : categoryRecordIds[categorySyncId];
        final paths = deleted
            ? <String>[]
            : _decodePaths(local['image_paths'] as String?);
        final files = await _photoFiles(paths);
        final body = <String, dynamic>{
          'family': familyId,
          'sync_id': syncId,
          'name': local['name'],
          'location': locationRecordId,
          'category': categoryRecordId ?? '',
          'notes': local['notes'],
          'item_created_at': local['created_at'],
          'is_deleted': deleted,
          if (remote != null) 'photos-': remote['photos'] ?? <dynamic>[],
          if (files.isEmpty) 'photos': <dynamic>[],
        };
        final record = remote == null
            ? await _client.collection('items').create(body: body, files: files)
            : await _client.collection('items').update(
                  remote['id'] as String,
                  body: body,
                  files: files,
                );
        merged.add({
          ...local,
          'updated_at': _time(record.updated).toIso8601String(),
          'sync_dirty': 0,
        });
      } else {
        final photoNames = (remote!['photos'] as List? ?? [])
            .whereType<String>()
            .toList();
        if (photoNames.isNotEmpty) fileToken ??= await _client.files.getToken();
        final imagePaths = await _downloadPhotos(remote, photoNames, fileToken);
        final locationSyncId = locationSyncIds[remote['location']];
        final locationId = locationLocalIds[locationSyncId];
        if (locationId == null) continue;
        final categorySyncId = categorySyncIds[remote['category']];
        merged.add({
          'sync_id': syncId,
          'name': remote['name'],
          'location_id': locationId,
          'category_id': categoryLocalIds[categorySyncId],
          'image_path': imagePaths.isEmpty ? null : imagePaths.first,
          'image_paths': jsonEncode(imagePaths),
          'notes': remote['notes'],
          'created_at': remote['item_created_at'],
          'updated_at': remote['updated'],
          'is_deleted': remote['is_deleted'] == true ? 1 : 0,
          'sync_dirty': 0,
        });
      }
    }
    return merged;
  }

  Future<List<http.MultipartFile>> _photoFiles(List<String> paths) async {
    final files = <http.MultipartFile>[];
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) throw Exception('本地照片不存在，已停止同步：$path');
      final bytes = await file.readAsBytes();
      final lower = path.toLowerCase();
      final extension = lower.endsWith('.png')
          ? '.png'
          : lower.endsWith('.webp')
              ? '.webp'
              : '.jpg';
      files.add(http.MultipartFile.fromBytes(
        'photos',
        bytes,
        filename: '${sha256.convert(bytes)}$extension',
      ));
    }
    return files;
  }

  Future<List<String>> _downloadPhotos(
    Map<String, dynamic> remote,
    List<String> names,
    String? token,
  ) async {
    final record = RecordModel.fromJson(remote);
    final paths = <String>[];
    for (final name in names) {
      final response = await http.get(
        _client.files.getURL(record, name, token: token),
      );
      if (response.statusCode != 200) {
        throw Exception('照片下载失败：HTTP ${response.statusCode}');
      }
      final lower = name.toLowerCase();
      final extension = lower.endsWith('.png')
          ? '.png'
          : lower.endsWith('.webp')
              ? '.webp'
              : '.jpg';
      paths.add(await _images.saveImageBytes(response.bodyBytes, extension));
    }
    return paths;
  }

  Future<Map<Object?, String>> _localIdToSyncId(String table) async {
    final rows = await _db.getSyncRows(table);
    return {for (final row in rows) row['id']: row['sync_id'] as String};
  }

  Future<Map<Object?, int>> _syncIdToLocalId(String table) async {
    final rows = await _db.getSyncRows(table);
    return {for (final row in rows) row['sync_id']: row['id'] as int};
  }

  List<String> _decodePaths(String? value) {
    if (value == null || value.isEmpty) return [];
    return (jsonDecode(value) as List).whereType<String>().toList();
  }

  DateTime _time(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc() ?? DateTime(1970);

  Future<void> _saveFamilyId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyIdKey, id);
  }

  Future<void> _bindFamily(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boundFamilyIdKey, id);
  }

  Future<void> _requireUnboundDevice() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_boundFamilyIdKey)) {
      throw Exception('本机数据已经绑定家庭，不能加入其他家庭');
    }
  }

  void _requireConfigured() {
    if (!isConfigured) throw Exception('PocketBase 尚未配置');
  }

  String _clientErrorMessage(ClientException error, {bool auth = false}) {
    final raw =
        '${error.response['message'] ?? ''} ${error.response['data'] ?? ''}'
            .toLowerCase();
    if (raw.contains('already_belongs_to_family')) return '该账号已经加入家庭';
    if (raw.contains('invalid_invite_code')) return '邀请码无效，请检查后重试';
    if (raw.contains('invalid_family_name')) return '请输入有效的家庭名称';
    if (auth && error.statusCode == 400 && raw.contains('identity')) {
      return '邮箱或密码错误';
    }
    if (auth && raw.contains('email') && raw.contains('unique')) {
      return '该邮箱已经注册，请直接登录';
    }
    if (auth && raw.contains('password')) return '密码不符合要求，请至少输入 8 位';
    if (auth && raw.contains('email')) return '邮箱地址无效或暂时无法使用';
    if (error.statusCode == 0) return '无法连接 PocketBase，请检查网络和服务地址';
    return auth ? '账号操作失败，请检查邮箱和密码' : '家庭操作失败，请稍后重试';
  }
}
