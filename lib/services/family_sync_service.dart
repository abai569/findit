import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database.dart';
import 'image_service.dart';

class FamilySyncService {
  static const _configuredSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _familyIdKey = 'family_sync_family_id';
  static const _boundFamilyIdKey = 'family_sync_bound_family_id';
  static const _bucket = 'item-photos';

  final DatabaseService _db = DatabaseService();
  final ImageService _images = ImageService();

  static String get supabaseUrl {
    final uri = Uri.tryParse(_configuredSupabaseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return _configuredSupabaseUrl.trim();
    }
    return Uri(scheme: uri.scheme, host: uri.host).toString();
  }

  static bool get isConfigured =>
      _configuredSupabaseUrl.trim().isNotEmpty && supabaseAnonKey.isNotEmpty;
  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => isConfigured ? _client.auth.currentUser : null;

  Future<String?> getFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_familyIdKey);
  }

  Future<void> initializeFamily() async {
    if (currentUser == null) return;
    final rows = await _client
        .from('family_members')
        .select('family_id')
        .eq('user_id', currentUser!.id)
        .limit(1);
    if ((rows as List).isNotEmpty) {
      final familyId =
          (rows.first as Map<String, dynamic>)['family_id'] as String;
      final prefs = await SharedPreferences.getInstance();
      final boundFamilyId = prefs.getString(_boundFamilyIdKey);
      if (boundFamilyId != null && boundFamilyId != familyId) {
        await _client.auth.signOut();
        throw Exception('本机数据已绑定其他家庭，不能切换家庭账号');
      }
      await prefs.setString(_familyIdKey, familyId);
      if (boundFamilyId == null) {
        await _db.clearSyncData();
        await sync();
        await prefs.setString(_boundFamilyIdKey, familyId);
      }
    }
  }

  Future<void> signUp(String email, String password) async {
    _requireConfigured();
    try {
      await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<void> signIn(String email, String password) async {
    _requireConfigured();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await initializeFamily();
    } on AuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_familyIdKey);
  }

  Future<String> createFamily(String name) async {
    await _requireUnboundDevice();
    if (name.trim().isEmpty) throw Exception('请输入家庭名称');
    try {
      final result = await _client.rpc(
        'create_family',
        params: {'family_name': name.trim()},
      );
      final data = Map<String, dynamic>.from(result as Map);
      final familyId = data['family_id'] as String;
      await _saveFamilyId(familyId);
      await sync();
      await _bindFamily(familyId);
      return data['invite_code'] as String;
    } on PostgrestException catch (error) {
      throw Exception(_databaseErrorMessage(error));
    }
  }

  Future<void> joinFamily(String inviteCode) async {
    await _requireUnboundDevice();
    if (inviteCode.trim().isEmpty) throw Exception('请输入邀请码');
    try {
      final familyId = await _client.rpc(
        'join_family',
        params: {'code': inviteCode.trim().toUpperCase()},
      );
      await _saveFamilyId(familyId as String);
      await _db.clearSyncData();
      await sync();
      await _bindFamily(familyId);
    } on PostgrestException catch (error) {
      throw Exception(_databaseErrorMessage(error));
    }
  }

  Future<Map<String, dynamic>?> getFamily() async {
    final familyId = await getFamilyId();
    if (familyId == null) return null;
    final row = await _client
        .from('families')
        .select('id, name, invite_code')
        .eq('id', familyId)
        .single();
    final members = await _client
        .from('family_members')
        .select('user_id, role, joined_at')
        .eq('family_id', familyId);
    return {...row, 'members': members};
  }

  Future<void> sync() async {
    final familyId = await getFamilyId();
    if (currentUser == null || familyId == null) return;
    await _db.ensureSyncIds();

    final localLocations = await _db.getSyncRows('locations');
    final localCategories = await _db.getSyncRows('categories');
    final localItems = await _db.getSyncRows('items');
    final remoteLocations = _maps(await _client
        .from('locations')
        .select()
        .eq('family_id', familyId));
    final remoteCategories = _maps(await _client
        .from('categories')
        .select()
        .eq('family_id', familyId));
    final remoteItems = _maps(await _client
        .from('items')
        .select()
        .eq('family_id', familyId));

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
    final items = await _mergeItems(
      familyId: familyId,
      localRows: localItems,
      remoteRows: remoteItems,
    );
    await _db.applySyncRows(
      locations: const [],
      categories: const [],
      items: items,
    );
  }

  Future<List<Map<String, dynamic>>> _mergeStructure({
    required String table,
    required String familyId,
    required List<Map<String, dynamic>> localRows,
    required List<Map<String, dynamic>> remoteRows,
  }) async {
    final localById = {for (final row in localRows) row['sync_id'] as String: row};
    final remoteById = {for (final row in remoteRows) row['id'] as String: row};
    final syncIds = {...localById.keys, ...remoteById.keys};
    final merged = <Map<String, dynamic>>[];
    for (final syncId in syncIds) {
      final local = localById[syncId];
      final remote = remoteById[syncId];
      final useLocal = remote == null ||
          (local != null &&
              !_time(local['updated_at']).isBefore(_time(remote['updated_at'])));
      if (useLocal) {
        final cloud = {
          'id': syncId,
          'family_id': familyId,
          'name': local!['name'],
          'sort_order': local['sort_order'],
          'updated_at': local['updated_at'],
          'is_deleted': local['is_deleted'] == 1,
          if (table == 'locations') 'parent_id': null,
          if (table == 'categories') ...{
            'icon': local['icon'],
            'color': local['color'],
          },
        };
        await _client.from(table).upsert(cloud);
        merged.add(local);
      } else {
        merged.add({
          'sync_id': syncId,
          'name': remote!['name'],
          'sort_order': remote['sort_order'],
          'updated_at': remote['updated_at'],
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
  }) async {
    final localById = {for (final row in localRows) row['sync_id'] as String: row};
    final remoteById = {for (final row in remoteRows) row['id'] as String: row};
    final localLocationSync = await _localIdToSyncId('locations');
    final localCategorySync = await _localIdToSyncId('categories');
    final locationLocalIds = await _syncIdToLocalId('locations');
    final categoryLocalIds = await _syncIdToLocalId('categories');
    final merged = <Map<String, dynamic>>[];
    for (final syncId in {...localById.keys, ...remoteById.keys}) {
      final local = localById[syncId];
      final remote = remoteById[syncId];
      final useLocal = remote == null ||
          local?['sync_dirty'] == 1 ||
          (local != null &&
              !_time(local['updated_at']).isBefore(_time(remote['updated_at'])));
      if (useLocal) {
        final deleted = local!['is_deleted'] == 1;
        final photoPaths = deleted
            ? (remote?['photo_paths'] as List? ?? const [])
            : await _uploadPhotos(
                familyId,
                syncId,
                _decodePaths(local['image_paths'] as String?),
              );
        await _client.from('items').upsert({
          'id': syncId,
          'family_id': familyId,
          'name': local['name'],
          'location_id': localLocationSync[local['location_id']],
          'category_id': localCategorySync[local['category_id']],
          'notes': local['notes'],
          'photo_paths': photoPaths,
          'created_at': local['created_at'],
          'updated_at': local['updated_at'],
          'is_deleted': deleted,
        });
        merged.add({...local, 'sync_dirty': 0});
      } else {
        final imagePaths = await _downloadPhotos(remote!['photo_paths'] as List? ?? []);
        final locationId = locationLocalIds[remote['location_id']];
        if (locationId == null) continue;
        merged.add({
          'sync_id': syncId,
          'name': remote['name'],
          'location_id': locationId,
          'category_id': categoryLocalIds[remote['category_id']],
          'image_path': imagePaths.isEmpty ? null : imagePaths.first,
          'image_paths': jsonEncode(imagePaths),
          'notes': remote['notes'],
          'created_at': remote['created_at'],
          'updated_at': remote['updated_at'],
          'is_deleted': remote['is_deleted'] == true ? 1 : 0,
          'sync_dirty': 0,
        });
      }
    }
    return merged;
  }

  Future<List<String>> _uploadPhotos(
    String familyId,
    String itemId,
    List<String> localPaths,
  ) async {
    final paths = <String>[];
    for (final localPath in localPaths) {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('本地照片不存在，已停止同步：$localPath');
      }
      final bytes = await file.readAsBytes();
      final extension = localPath.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      final path = '$familyId/$itemId/${sha256.convert(bytes)}$extension';
      try {
        await _client.storage.from(_bucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: false),
            );
      } on StorageException catch (error) {
        if (error.statusCode != '409') rethrow;
      }
      paths.add(path);
    }
    return paths;
  }

  Future<List<String>> _downloadPhotos(List<dynamic> remotePaths) async {
    final localPaths = <String>[];
    for (final value in remotePaths.whereType<String>()) {
      final bytes = await _client.storage.from(_bucket).download(value);
      final extension = value.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      localPaths.add(await _images.saveImageBytes(bytes, extension));
    }
    return localPaths;
  }

  Future<Map<Object?, String>> _localIdToSyncId(String table) async {
    final rows = await _db.getSyncRows(table);
    return {for (final row in rows) row['id']: row['sync_id'] as String};
  }

  Future<Map<Object?, int>> _syncIdToLocalId(String table) async {
    final rows = await _db.getSyncRows(table);
    return {for (final row in rows) row['sync_id']: row['id'] as int};
  }

  List<Map<String, dynamic>> _maps(dynamic rows) =>
      (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();

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
    if (!isConfigured) throw Exception('Supabase 尚未配置');
  }

  String _authErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == '404' || message.contains('invalid path')) {
      return 'Supabase 地址配置错误，请填写项目根地址，例如 https://项目ID.supabase.co';
    }
    if (message.contains('email not confirmed')) return '邮箱尚未确认，请先打开确认邮件';
    if (message.contains('invalid login credentials')) return '邮箱或密码错误';
    if (message.contains('already registered')) return '该邮箱已经注册，请直接登录';
    if (message.contains('password')) return '密码不符合要求，请至少输入 6 位';
    if (message.contains('email')) return '邮箱地址无效或暂时无法使用';
    return '认证失败：${error.message}';
  }

  String _databaseErrorMessage(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('gen_random_bytes')) {
      return '家庭服务配置需要更新，请在 Supabase 重新执行最新版 schema.sql';
    }
    if (message.contains('already belongs')) return '该账号已经加入家庭';
    if (message.contains('invalid invite code')) return '邀请码无效，请检查后重试';
    if (message.contains('family name')) return '请输入有效的家庭名称';
    return '家庭操作失败，请稍后重试';
  }
}
