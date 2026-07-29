import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/location.dart';
import '../models/item_category.dart';
import '../services/database.dart';
import '../services/webdav_service.dart';
import '../services/image_service.dart';
import '../services/family_sync_service.dart';

class AppProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final WebDAVService _webdav = WebDAVService();
  final ImageService _imageService = ImageService();
  final FamilySyncService _familySync = FamilySyncService();

  List<Item> _items = [];
  List<Location> _locations = [];
  List<ItemCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  bool _hasWebDAVConfig = false;
  List<Map<String, dynamic>> _backupHistory = [];

  List<Item> get items => _items;
  List<Location> get locations => _locations;
  List<ItemCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWebDAVConfig => _hasWebDAVConfig;
  List<Map<String, dynamic>> get backupHistory => _backupHistory;
  FamilySyncService get familySync => _familySync;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadAllData();
      _hasWebDAVConfig = await _webdav.hasCredentials();
      _backupHistory = await _db.getBackupHistory();
      await _familySync.initializeFamily();
      await loadAllData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllData() async {
    _items = await _db.getAllItems();
    _locations = await _db.getAllLocations();
    _categories = await _db.getAllCategories();
    notifyListeners();
  }

  Future<void> addItem({
    required String name,
    required int locationId,
    int? categoryId,
    List<String> imagePaths = const [],
    String? notes,
  }) async {
    final item = Item(
      name: name,
      locationId: locationId,
      categoryId: categoryId,
      imagePaths: imagePaths,
      notes: notes,
    );
    
    await _db.insertItem(item);
    try {
      await loadAllData();
    } catch (e) {
      debugPrint('刷新物品数据失败：$e');
    }
    
    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        print('自动备份失败：$e');
      }
    }
    await _syncAfterChange();
  }

  Future<void> updateItem(Item item) async {
    Item? previousItem;
    for (final existingItem in _items) {
      if (existingItem.id == item.id) {
        previousItem = existingItem;
        break;
      }
    }

    final updatedRows = await _db.updateItem(item);
    if (updatedRows != 1) {
      throw Exception('物品不存在或已被删除');
    }
    try {
      await loadAllData();
    } catch (e) {
      debugPrint('刷新物品数据失败：$e');
    }

    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        print('自动备份失败：$e');
      }
    }
    await _syncAfterChange();

    if (previousItem != null) {
      final removedPaths = previousItem.imagePaths.toSet()
        ..removeAll(item.imagePaths);
      for (final path in removedPaths) {
        try {
          await _imageService.deleteImage(path);
        } catch (e) {
          debugPrint('删除旧图片失败：$e');
        }
      }
    }
    
  }

  Future<void> deleteItem(int id) async {
    Item? deletedItem;
    for (final item in _items) {
      if (item.id == id) {
        deletedItem = item;
        break;
      }
    }

    await _db.deleteItem(id);
    await loadAllData();

    if (deletedItem != null) {
      for (final path in deletedItem.imagePaths) {
        try {
          await _imageService.deleteImage(path);
        } catch (e) {
          debugPrint('删除物品图片失败：$e');
        }
      }
    }
    
    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        print('自动备份失败：$e');
      }
    }
    await _syncAfterChange();
  }

  Future<void> addLocation(String name) async {
    await _db.insertLocation(Location(name: name.trim()));
    await _refreshAfterStructureChange();
  }

  Future<void> updateLocation(Location location, String name) async {
    await _db.updateLocation(location.copyWith(name: name.trim()));
    await _refreshAfterStructureChange();
  }

  Future<void> deleteLocation(int id) async {
    await _db.deleteLocation(id);
    await _refreshAfterStructureChange();
  }

  Future<void> reorderLocations(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<Location>.from(_locations);
    final location = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, location);
    _locations = reordered;
    notifyListeners();
    try {
      await _db.reorderLocations(
        reordered.map((location) => location.id!).toList(),
      );
      await loadAllData();
      await _backupStructureChange();
    } catch (e) {
      await loadAllData();
      debugPrint('保存位置排序失败：$e');
    }
  }

  Future<void> addCategory({
    required String name,
  }) async {
    await _db.insertCategory(
      ItemCategory(name: name.trim(), icon: '📦', color: '#607D8B'),
    );
    await _refreshAfterStructureChange();
  }

  Future<void> updateCategory(ItemCategory category, {
    required String name,
  }) async {
    await _db.updateCategory(
      category.copyWith(name: name.trim()),
    );
    await _refreshAfterStructureChange();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    await _refreshAfterStructureChange();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<ItemCategory>.from(_categories);
    final category = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, category);
    _categories = reordered;
    notifyListeners();
    try {
      await _db.reorderCategories(
        reordered.map((category) => category.id!).toList(),
      );
      await loadAllData();
      await _backupStructureChange();
    } catch (e) {
      await loadAllData();
      debugPrint('保存分类排序失败：$e');
    }
  }

  Future<void> _refreshAfterStructureChange() async {
    await loadAllData();
    await _backupStructureChange();
  }

  Future<void> _backupStructureChange() async {
    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        debugPrint('自动备份失败：$e');
      }
    }
    await _syncAfterChange();
  }

  Future<void> _syncAfterChange() async {
    if (!FamilySyncService.isConfigured || _familySync.currentUser == null) return;
    try {
      await _familySync.sync();
      await loadAllData();
    } catch (e) {
      debugPrint('家庭同步失败：$e');
    }
  }

  Future<void> syncFamily() async {
    await _familySync.sync();
    await loadAllData();
  }

  Future<void> searchItems(String keyword) async {
    if (keyword.isEmpty) {
      _items = await _db.getAllItems();
    } else {
      _items = await _db.searchItems(keyword);
    }
    notifyListeners();
  }

  Future<void> queryItems({
    String? keyword,
    int? locationId,
    int? categoryId,
  }) async {
    _items = await _db.queryItems(
      keyword: keyword,
      locationId: locationId,
      categoryId: categoryId,
    );
    notifyListeners();
  }

  Future<void> filterByLocation(int locationId) async {
    _items = await _db.getItemsByLocation(locationId);
    notifyListeners();
  }

  Future<void> filterByCategory(int categoryId) async {
    _items = await _db.getItemsByCategory(categoryId);
    notifyListeners();
  }

  Future<bool> saveWebDAVConfig({
    required String url,
    required String username,
    required String password,
    String? backupDir,
  }) async {
    try {
      await _webdav.saveCredentials(
        url: url,
        username: username,
        password: password,
        backupDir: backupDir,
      );
      _hasWebDAVConfig = true;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, String>?> getWebDAVCredentials() async {
    return await _webdav.getCredentials();
  }

  Future<void> clearWebDAVConfig() async {
    await _webdav.clearCredentials();
    _hasWebDAVConfig = false;
    _webdav.resetClient();
    notifyListeners();
  }

  Future<bool> testWebDAVConnection() async {
    return await _webdav.testConnection();
  }

  Future<String> manualBackup() async {
    try {
      final fileName = await _webdav.backup();
      _backupHistory = await _db.getBackupHistory();
      notifyListeners();
      return '备份成功：$fileName';
    } catch (e) {
      throw Exception('备份失败：$e');
    }
  }

  Future<String> restoreFromWebDAV(String? fileName) async {
    try {
      final result = await _webdav.restore(fileName);
      await loadAllData();
      _backupHistory = await _db.getBackupHistory();
      notifyListeners();
      return result;
    } catch (e) {
      throw Exception('恢复失败：$e');
    }
  }

  Future<List<String>> listBackups() async {
    return await _webdav.listBackups();
  }

  String getLocationName(int locationId) {
    final location = _locations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => Location(name: '未知位置'),
    );
    return location.getFullPath(_locations);
  }

  String? getCategoryName(int? categoryId) {
    if (categoryId == null) return null;
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => ItemCategory(name: '未分类', icon: '📦', color: '#607D8B'),
    );
    return category.name;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
