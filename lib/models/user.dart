class User {
  final int? id;
  final String username;
  final String code; // Le code d'accès
  final String role; // 'admin' ou 'cashier'
  final bool isActive;
  final String? email; // Optional email field

  User({
    this.id,
    required this.username,
    required this.code,
    required this.role,
    this.isActive = true,
    this.email,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      code: map['code'],
      role: map['role'],
      isActive: map['is_active'] == 1,
      email: map['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'code': code,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'email': email,
    };
  }
}