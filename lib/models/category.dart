class Category {
  final int? id;
  final String name;
  final String icon;
  final String color;

  Category({
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

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  static List<Category> getDefaults() {
    return [
      Category(name: '电子产品', icon: '📱', color: '#2196F3'),
      Category(name: '证件', icon: '📄', color: '#4CAF50'),
      Category(name: '工具', icon: '🔧', color: '#FF9800'),
      Category(name: '衣物', icon: '👕', color: '#9C27B0'),
      Category(name: '书籍', icon: '📚', color: '#795548'),
      Category(name: '药品', icon: '💊', color: '#F44336'),
      Category(name: '化妆品', icon: '💄', color: '#E91E63'),
      Category(name: '运动用品', icon: '⚽', color: '#00BCD4'),
      Category(name: '厨房用品', icon: '🍳', color: '#FFC107'),
      Category(name: '其他', icon: '📦', color: '#607D8B'),
    ];
  }
}
