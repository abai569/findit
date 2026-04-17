class ItemCategory {
  final int? id;
  final String name;
  final String icon;
  final String color;

  ItemCategory({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  factory ItemCategory.fromMap(Map<String, dynamic> map) {
    return ItemCategory(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
    );
  }

  ItemCategory copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
  }) {
    return ItemCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  static List<ItemCategory> getDefaults() {
    return [
      ItemCategory(name: '电子产品', icon: '📱', color: '#2196F3'),
      ItemCategory(name: '证件', icon: '📄', color: '#4CAF50'),
      ItemCategory(name: '工具', icon: '🔧', color: '#FF9800'),
      ItemCategory(name: '衣物', icon: '👕', color: '#9C27B0'),
      ItemCategory(name: '书籍', icon: '📚', color: '#795548'),
      ItemCategory(name: '药品', icon: '💊', color: '#F44336'),
      ItemCategory(name: '化妆品', icon: '💄', color: '#E91E63'),
      ItemCategory(name: '运动用品', icon: '⚽', color: '#00BCD4'),
      ItemCategory(name: '厨房用品', icon: '🍳', color: '#FFC107'),
      ItemCategory(name: '其他', icon: '📦', color: '#607D8B'),
    ];
  }
}
