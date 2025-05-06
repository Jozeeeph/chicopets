import 'dart:convert';

class OrderLine {
  final int idOrder;
  final String? productCode;
  final String? productName;
  final int? productId;
  final int? variantId;
  final String? variantCode;
  final String? variantName;
  final int quantity;
  final double prixUnitaire;
  final double discount;
  final bool isPercentage;
  final Map<String, dynamic>? productData;

  OrderLine({
    required this.idOrder,
    this.productCode,
    this.productName,
    this.productId,
    this.variantId,
    this.variantCode,
    this.variantName,
    required this.quantity,
    required this.prixUnitaire,
    required this.discount,
    required this.isPercentage,
    this.productData,
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
      'product_name': productName,
      'product_id': productId,
      'variant_id': variantId,
      'variant_code': variantCode,
      'variant_name': variantName,
      'quantity': quantity,
      'prix_unitaire': prixUnitaire,
      'discount': discount,
      'isPercentage': isPercentage ? 1 : 0,
      'product_data': productData != null ? jsonEncode(productData) : null,
    };
  }

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      idOrder: map['id_order'] as int,
      productCode: map['product_code'] as String?,
      productName: map['product_name'] as String?,
      productId: map['product_id'] as int?,
      variantId: map['variant_id'] as int?,
      variantCode: map['variant_code'] as String?,
      variantName: map['variant_name'] as String?,
      quantity: map['quantity'] as int,
      prixUnitaire: (map['prix_unitaire'] as num).toDouble(),
      discount: (map['discount'] as num).toDouble(),
      isPercentage: map['isPercentage'] == 1,
      productData: map['product_data'] != null
          ? jsonDecode(map['product_data'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'OrderLine{'
        'idOrder: $idOrder, '
        'productCode: $productCode, '
        'productName: $productName, '
        'productId: $productId, '
        'variantId: $variantId, '
        'variantCode: $variantCode, '
        'variantName: $variantName, '
        'quantity: $quantity, '
        'prixUnitaire: $prixUnitaire, '
        'discount: $discount, '
        'isPercentage: $isPercentage, '
        'finalPrice: $finalPrice'
        '}';
  }
}
