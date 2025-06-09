class StockItem {
  final int? id;
  final int productId;
  final int warehouseId;
  final int quantity;
  final int? variantId;

  StockItem({
    this.id,
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    this.variantId,
  });

  // Factory constructor to create a StockItem from JSON
  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'],
      productId: json['productId'],
      warehouseId: json['warehouseId'],
      quantity: json['quantity'],
      variantId: json['variantId'],
    );
  }

  // Convert StockItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'warehouseId': warehouseId,
      'quantity': quantity,
      'variantId': variantId,
    };
  }
}
