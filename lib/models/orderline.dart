class OrderLine {
  final int idOrder;
  final String? productCode; // Renamed from idProduct for clarity
  final int? productId; // New field
  final int quantity;
  final double prixUnitaire;
  final double discount;
  final bool isPercentage;

  OrderLine({
    required this.idOrder,
    this.productCode,
    this.productId,
    required this.quantity,
    required this.prixUnitaire,
    required this.discount,
    required this.isPercentage,
  }) : assert(productCode != null || productId != null,
            'Either productCode or productId must be provided');

  double get finalPrice {
    if (discount == 0) {
      return prixUnitaire;
    } else if (isPercentage) {
      return prixUnitaire * (1 - discount / 100);
    } else {
      return prixUnitaire - discount;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id_order': idOrder,
      'product_code': productCode,
      'product_id': productId,
      'quantity': quantity,
      'prix_unitaire': prixUnitaire,
      'discount': discount,
      'isPercentage': isPercentage ? 1 : 0,
    };
  }

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      idOrder: map['id_order'],
      productCode: map['product_code'],
      productId: map['product_id'],
      quantity: map['quantity'],
      prixUnitaire: map['prix_unitaire'],
      discount: map['discount'],
      isPercentage: map['isPercentage'] == 1,
    );
  }
}
