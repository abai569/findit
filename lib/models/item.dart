import 'dart:convert';

class Item {
  final int? id;
  final String name;
  final int locationId;
  final int? categoryId;
  final List<String> imagePaths;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Item({
    this.id,
    required this.name,
    required this.locationId,
    this.categoryId,
    this.imagePaths = const [],
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String? get imagePath => imagePaths.isEmpty ? null : imagePaths.first;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location_id': locationId,
      'category_id': categoryId,
      'image_path': imagePath,
      'image_paths': jsonEncode(imagePaths),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      locationId: map['location_id'],
      categoryId: map['category_id'],
      imagePaths: _readImagePaths(map),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Item copyWith({
    int? id,
    String? name,
    int? locationId,
    int? categoryId,
    bool clearCategory = false,
    List<String>? imagePaths,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      locationId: locationId ?? this.locationId,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      imagePaths: imagePaths ?? this.imagePaths,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static List<String> _readImagePaths(Map<String, dynamic> map) {
    final encodedPaths = map['image_paths'] as String?;
    if (encodedPaths != null && encodedPaths.isNotEmpty) {
      try {
        return (jsonDecode(encodedPaths) as List)
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList();
      } catch (_) {}
    }

    final legacyPath = map['image_path'] as String?;
    return legacyPath == null || legacyPath.isEmpty ? [] : [legacyPath];
  }
}
