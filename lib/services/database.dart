import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../models/location.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('findit.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parent_id INTEGER,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location_id INTEGER NOT NULL,
        category_id INTEGER,
        image_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (location_id) REFERENCES locations(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_backup_time TEXT,
        last_sync_version INTEGER,
        device_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE backup_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backup_time TEXT NOT NULL,
        backup_version INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER
      )
    ''');

    final defaultLocations = [
      {'name': '卧室', 'parent_id': null, 'sort_order': 1},
      {'name': '客厅', 'parent_id': null, 'sort_order': 2},
      {'name': '厨房', 'parent_id': null, 'sort_order': 3},
      {'name': '卫生间', 'parent_id': null, 'sort_order': 4},
      {'name': '书房', 'parent_id': null, 'sort_order': 5},
      {'name': '办公室', 'parent_id': null, 'sort_order': 6},
      {'name': '储物间', 'parent_id': null, 'sort_order': 7},
    ];
    for (var loc in defaultLocations) {
      await db.insert('locations', loc);
    }

    for (var cat in Category.getDefaults()) {
      await db.insert('categories', cat.toMap());
    }
  }

  Future<int> insertLocation(Location location) async {
    final db = await database;
    return await db.insert('locations', location.toMap());
  }

  Future<List<Location>> getAllLocations() async {
    final db = await database;
    final maps = await db.query('locations', orderBy: 'sort_order, id');
    return maps.map((map) => Location.fromMap(map)).toList();
  }

  Future<int> insertItem(Item item) async {
    final db = await database;
    return await db.insert('items', item.toMap());
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    final updatedItem = item.copyWith(updatedAt: DateTime.now());
    return await db.update(
      'items',
      updatedItem.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> searchItems(String keyword) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'is_deleted = 0 AND name LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> getItemsByLocation(int locationId) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'is_deleted = 0 AND location_id = ?',
      whereArgs: [locationId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> getItemsByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'is_deleted = 0 AND category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<void> updateSyncMetadata({
    String? lastBackupTime,
    int? lastSyncVersion,
    String? deviceId,
  }) async {
    final db = await database;
    final existing = await db.query('sync_metadata');
    final data = {
      'last_backup_time': lastBackupTime,
      'last_sync_version': lastSyncVersion,
      'device_id': deviceId,
    };
    if (existing.isEmpty) {
      await db.insert('sync_metadata', data);
    } else {
      await db.update('sync_metadata', data, where: 'id = 1');
    }
  }

  Future<Map<String, dynamic>?> getSyncMetadata() async {
    final db = await database;
    final maps = await db.query('sync_metadata');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> addBackupHistory({
    required String backupTime,
    required int backupVersion,
    required String fileName,
    int? fileSize,
  }) async {
    final db = await database;
    await db.insert('backup_history', {
      'backup_time': backupTime,
      'backup_version': backupVersion,
      'file_name': fileName,
      'file_size': fileSize,
    });

    await _cleanupOldBackups(db);
  }

  Future<void> _cleanupOldBackups(Database db) async {
    final result = await db.rawQuery(
      'SELECT id FROM backup_history ORDER BY backup_version DESC LIMIT 5 OFFSET 5',
    );
    if (result.isNotEmpty) {
      final idsToDelete = result.map((r) => r['id'] as int).toList();
      await db.delete(
        'backup_history',
        where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
        whereArgs: idsToDelete,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getBackupHistory() async {
    final db = await database;
    return await db.query(
      'backup_history',
      orderBy: 'backup_version DESC',
      limit: 5,
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
