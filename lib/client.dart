class Client {
  int? id;
  String name;
  String firstName;
  String phoneNumber;
  int loyaltyPoints;
  List<int> idOrders;

  Client({
    this.id,
    required this.name,
    required this.firstName,
    required this.phoneNumber,
    this.loyaltyPoints = 0,
    this.idOrders = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'phone_number': phoneNumber,
      'loyalty_points': loyaltyPoints,
      'id_orders': idOrders.isEmpty ? null : idOrders.join(','),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    // Gestion des id_orders
    List<int> orders = [];
    if (map['id_orders'] != null && map['id_orders'].toString().isNotEmpty) {
      orders = (map['id_orders'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toList();
    }

    return Client(
      id: map['id'],
      name: map['name'],
      firstName: map['first_name'],
      phoneNumber: map['phone_number'],
      loyaltyPoints: map['loyalty_points'] ?? 0,
      idOrders: orders,
    );
  }
}
