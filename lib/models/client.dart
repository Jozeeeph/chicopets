class Client {
  int? id;
  String name;
  String firstName;
  String phoneNumber;
  int loyaltyPoints;
  List<int> idOrders;
  DateTime? lastPurchaseDate; 

  Client({
    this.id,
    required this.name,
    required this.firstName,
    required this.phoneNumber,
    this.loyaltyPoints = 0,
    this.idOrders = const [],
    this.lastPurchaseDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'phone_number': phoneNumber,
      'loyalty_points': loyaltyPoints,
      'id_orders': idOrders.isEmpty ? null : idOrders.join(','),
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
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
      lastPurchaseDate: map['last_purchase_date'] != null 
          ? DateTime.parse(map['last_purchase_date']) 
          : null,
    );
  }
}