class Stock {
  final int? id;
  final int productId;
  final String productName;
  final String reason; // New attribute
  final int quantity;
  final DateTime lastUpdated;
  final bool isSynced;

  Stock({
    this.id,
    required this.productId,
    required this.productName,
    required this.reason, // Added to constructor
    required this.quantity,
    required this.lastUpdated,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'reason': reason, // Added to map
      'quantity': quantity,
      'last_updated': lastUpdated.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      id: map['id'],
      productId: map['product_id'],
      productName: map['product_name'],
      reason: map['reason'] ?? '', // Handle potential null values
      quantity: map['quantity'],
      lastUpdated: DateTime.parse(map['last_updated']),
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // Include id in JSON if needed
      'productId': productId,
      'productName': productName,
      'reason': reason, // Include reason in JSON
      'quantity': quantity,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  @override
  String toString() {
    return 'Stock{id: $id, productId: $productId, productName: $productName, reason: $reason, quantity: $quantity, lastUpdated: $lastUpdated, isSynced: $isSynced}';
  }
}
