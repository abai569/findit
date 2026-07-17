import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/location.dart';
import '../models/item_category.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  static const _uuid = Uuid();

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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT,
        name TEXT NOT NULL,
        parent_id INTEGER,
        sort_order INTEGER DEFAULT 0,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT,
        name TEXT NOT NULL,
        location_id INTEGER NOT NULL,
        category_id INTEGER,
        image_path TEXT,
        image_paths TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        sync_dirty INTEGER DEFAULT 1,
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
      await db.insert('locations', {
        ...loc,
        'sync_id': _uuid.v4(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    final defaultCategories = ItemCategory.getDefaults();
    for (var index = 0; index < defaultCategories.length; index++) {
      await db.insert(
        'categories',
        {
          ...defaultCategories[index].copyWith(sortOrder: index).toMap(),
          'sync_id': _uuid.v4(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE items ADD COLUMN image_paths TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN notes TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN sort_order INTEGER DEFAULT 0',
      );
      await db.execute('UPDATE categories SET sort_order = id');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE locations ADD COLUMN sync_id TEXT');
      await db.execute('ALTER TABLE locations ADD COLUMN updated_at TEXT');
      await db.execute(
        'ALTER TABLE locations ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE categories ADD COLUMN sync_id TEXT');
      await db.execute('ALTER TABLE categories ADD COLUMN updated_at TEXT');
      await db.execute(
        'ALTER TABLE categories ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE items ADD COLUMN sync_id TEXT');
      final now = DateTime.now().toUtc().toIso8601String();
      for (final table in ['locations', 'categories', 'items']) {
        final rows = await db.query(table, columns: ['id']);
        for (final row in rows) {
          final values = <String, Object?>{'sync_id': _uuid.v4()};
          if (table != 'items') values['updated_at'] = now;
          await db.update(
            table,
            values,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE items ADD COLUMN sync_dirty INTEGER DEFAULT 0',
      );
    }
  }

  Future<int> insertLocation(Location location) async {
    final db = await database;
    await _ensureUniqueLocationName(db, location.name, location.parentId);
    final map = location.toMap();
    map['sync_id'] = _uuid.v4();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sort_order'] = await _nextSortOrder(db, 'locations');
    return await db.insert('locations', map);
  }

  Future<List<Location>> getAllLocations() async {
    final db = await database;
    final maps = await db.query(
      'locations',
      where: 'is_deleted = 0',
      orderBy: 'sort_order, id',
    );
    return maps.map((map) => Location.fromMap(map)).toList();
  }

  Future<void> reorderLocations(List<int> ids) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (var index = 0; index < ids.length; index++) {
        await txn.update(
          'locations',
          {'sort_order': index, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [ids[index]],
        );
      }
    });
  }

  Future<int> updateLocation(Location location) async {
    final db = await database;
    await _ensureUniqueLocationName(
      db,
      location.name,
      location.parentId,
      excludeId: location.id,
    );
    return db.update(
      'locations',
      {
        ...location.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [location.id],
    );
  }

  Future<int> deleteLocation(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final items = await txn.query(
        'items',
        columns: ['id'],
        where: 'location_id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (items.isNotEmpty) {
        throw Exception('该位置下还有物品，不能删除');
      }
      final children = await txn.query(
        'locations',
        columns: ['id'],
        where: 'parent_id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (children.isNotEmpty) {
        throw Exception('该位置下还有子位置，不能删除');
      }
      return txn.update(
        'locations',
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> _ensureUniqueLocationName(
    DatabaseExecutor db,
    String name,
    int? parentId, {
    int? excludeId,
  }) async {
    final whereParts = <String>['name = ?', 'is_deleted = 0'];
    final whereArgs = <Object?>[name];
    if (parentId == null) {
      whereParts.add('parent_id IS NULL');
    } else {
      whereParts.add('parent_id = ?');
      whereArgs.add(parentId);
    }
    if (excludeId != null) {
      whereParts.add('id != ?');
      whereArgs.add(excludeId);
    }
    final existing = await db.query(
      'locations',
      columns: ['id'],
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    if (existing.isNotEmpty) throw Exception('位置名称已存在');
  }

  Future<int> insertItem(Item item) async {
    final db = await database;
    final now = DateTime.now().toUtc();
    return await db.insert('items', {
      ...item.copyWith(createdAt: now, updatedAt: now).toMap(),
      'sync_id': _uuid.v4(),
      'sync_dirty': 1,
    });
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    final updatedItem = item.copyWith(updatedAt: DateTime.now().toUtc());
    return await db.update(
      'items',
      {...updatedItem.toMap(), 'sync_dirty': 1},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.update(
      'items',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'sync_dirty': 1,
      },
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

  Future<List<Item>> queryItems({
    String? keyword,
    int? locationId,
    int? categoryId,
  }) async {
    final db = await database;
    final where = <String>['is_deleted = 0'];
    final whereArgs = <Object?>[];
    if (keyword != null && keyword.isNotEmpty) {
      where.add('name LIKE ?');
      whereArgs.add('%$keyword%');
    }
    if (locationId != null) {
      where.add('location_id = ?');
      whereArgs.add(locationId);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      whereArgs.add(categoryId);
    }
    final maps = await db.query(
      'items',
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
    return maps.map(Item.fromMap).toList();
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

  Future<List<ItemCategory>> getAllCategories() async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'is_deleted = 0',
      orderBy: 'sort_order, id',
    );
    return maps.map((map) => ItemCategory.fromMap(map)).toList();
  }

  Future<void> reorderCategories(List<int> ids) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (var index = 0; index < ids.length; index++) {
        await txn.update(
          'categories',
          {'sort_order': index, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [ids[index]],
        );
      }
    });
  }

  Future<int> insertCategory(ItemCategory category) async {
    final db = await database;
    await _ensureUniqueCategoryName(db, category.name);
    final map = category.toMap();
    map['sync_id'] = _uuid.v4();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sort_order'] = await _nextSortOrder(db, 'categories');
    return db.insert('categories', map);
  }

  Future<int> updateCategory(ItemCategory category) async {
    final db = await database;
    await _ensureUniqueCategoryName(db, category.name, excludeId: category.id);
    return db.update(
      'categories',
      {
        ...category.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update(
        'items',
        {
          'category_id': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'sync_dirty': 1,
        },
        where: 'category_id = ?',
        whereArgs: [id],
      );
      return txn.update(
        'categories',
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> _ensureUniqueCategoryName(
    DatabaseExecutor db,
    String name, {
    int? excludeId,
  }) async {
    final existing = await db.query(
      'categories',
      columns: ['id'],
      where: excludeId == null
          ? 'name = ? AND is_deleted = 0'
          : 'name = ? AND id != ? AND is_deleted = 0',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
      limit: 1,
    );
    if (existing.isNotEmpty) throw Exception('分类名称已存在');
  }

  Future<int> _nextSortOrder(DatabaseExecutor db, String table) async {
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM $table',
    );
    return result.first['next_order'] as int;
  }

  Future<List<Map<String, dynamic>>> getSyncRows(String table) async {
    if (!const ['locations', 'categories', 'items'].contains(table)) {
      throw ArgumentError.value(table, 'table');
    }
    final db = await database;
    final rows = await db.query(table);
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<void> clearSyncData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('locations');
      await txn.delete('categories');
    });
  }

  Future<void> replaceSyncData({
    required List<Map<String, dynamic>> locations,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('locations');
      await txn.delete('categories');
      for (final row in locations) {
        await txn.insert('locations', row);
      }
      for (final row in categories) {
        await txn.insert('categories', row);
      }
      for (final row in items) {
        await txn.insert('items', row);
      }
    });
  }

  Future<void> ensureSyncIds() async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final table in ['locations', 'categories', 'items']) {
        final rows = await txn.query(
          table,
          columns: ['id'],
          where: 'sync_id IS NULL OR sync_id = ?',
          whereArgs: [''],
        );
        for (final row in rows) {
          final values = <String, Object?>{'sync_id': _uuid.v4()};
          if (table != 'items') values['updated_at'] = now;
          await txn.update(
            table,
            values,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    });
  }

  Future<void> applySyncRows({
    required List<Map<String, dynamic>> locations,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final row in locations) {
        await _upsertSyncRow(txn, 'locations', row);
      }
      for (final row in categories) {
        await _upsertSyncRow(txn, 'categories', row);
      }
      for (final row in items) {
        await _upsertSyncRow(txn, 'items', row);
      }
    });
  }

  Future<void> _upsertSyncRow(
    DatabaseExecutor db,
    String table,
    Map<String, dynamic> row,
  ) async {
    final existing = await db.query(
      table,
      columns: ['id'],
      where: 'sync_id = ?',
      whereArgs: [row['sync_id']],
      limit: 1,
    );
    final values = Map<String, dynamic>.from(row)..remove('id');
    if (existing.isEmpty) {
      await db.insert(table, values);
    } else {
      await db.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
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
