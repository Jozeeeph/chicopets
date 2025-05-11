class PaymentMethod {
  final int? id;
  final String name;
  final String? icon;
  final bool isActive;
  final DateTime createdAt;

  PaymentMethod({
    this.id,
    required this.name,
    this.icon,
    required this.isActive,
    required this.createdAt,
  });

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PaymentMethod copyWith({
    int? id,
    String? name,
    String? icon,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
