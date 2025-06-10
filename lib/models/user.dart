class User {
  final int? id;
  final String username;
  final String code; // Le code d'accès
  final String role; // 'admin' ou 'cashier'
  final bool isActive;
  final String? mail;

  User({
    this.id,
    required this.username,
    required this.code,
    required this.role,
    this.isActive = true,
    this.mail,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      code: map['code'],
      role: map['role'],
      isActive: map['is_active'] == 1,
      mail: map['mail'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'code': code,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'mail': mail,
    };
  }

  @override
  String toString() {
    return 'User{id: $id, username: "$username", role: "$role", isActive: $isActive, mail: ${mail ?? "null"}}';
    // Note: We're not showing the code here for security reasons
  }
}
