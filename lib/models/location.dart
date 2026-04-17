class Location {
  final int? id;
  final String name;
  final int? parentId;
  final int sortOrder;

  Location({
    this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'sort_order': sortOrder,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'],
      name: map['name'],
      parentId: map['parent_id'],
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Location copyWith({
    int? id,
    String? name,
    int? parentId,
    int? sortOrder,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  String getFullPath(List<Location> allLocations) {
    if (parentId == null) {
      return name;
    }
    final parent = allLocations.firstWhere(
      (l) => l.id == parentId,
      orElse: () => Location(name: ''),
    );
    if (parent.id == null) {
      return name;
    }
    return '${parent.getFullPath(allLocations)} / $name';
  }
}
