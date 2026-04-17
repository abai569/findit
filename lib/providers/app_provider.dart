import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/location.dart';
import '../models/category.dart';
import '../services/database.dart';
import '../services/webdav_service.dart';
import '../services/image_service.dart';

class AppProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final WebDAVService _webdav = WebDAVService();
  final ImageService _imageService = ImageService();

  List<Item> _items = [];
  List<Location> _locations = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  bool _hasWebDAVConfig = false;
  List<Map<String, dynamic>> _backupHistory = [];

  List<Item> get items => _items;
  List<Location> get locations => _locations;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWebDAVConfig => _hasWebDAVConfig;
  List<Map<String, dynamic>> get backupHistory => _backupHistory;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadAllData();
      _hasWebDAVConfig = await _webdav.hasCredentials();
      _backupHistory = await _db.getBackupHistory();
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
    String? imagePath,
  }) async {
    final item = Item(
      name: name,
      locationId: locationId,
      categoryId: categoryId,
      imagePath: imagePath,
    );
    
    await _db.insertItem(item);
    await loadAllData();
    
    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        print('自动备份失败：$e');
      }
    }
  }

  Future<void> updateItem(Item item) async {
    await _db.updateItem(item);
    await loadAllData();
    
    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        print('自动备份失败：$e');
      }
    }
  }

  Future<void> deleteItem(int id) async {
    await _db.deleteItem(id);
    await loadAllData();
    
    if (_hasWebDAVConfig) {
      try {
        await _webdav.backup();
      } catch (e) {
        print('自动备份失败：$e');
      }
    }
  }

  Future<void> searchItems(String keyword) async {
    if (keyword.isEmpty) {
      _items = await _db.getAllItems();
    } else {
      _items = await _db.searchItems(keyword);
    }
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
  }) async {
    try {
      await _webdav.saveCredentials(
        url: url,
        username: username,
        password: password,
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
      orElse: () => Category(name: '未分类', icon: '📦', color: '#607D8B'),
    );
    return category.name;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
