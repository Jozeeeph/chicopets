import 'dart:convert';

class Variant {
  int? id;
  String? code;
  String combinationName;
  double price;
  double priceImpact;
  double finalPrice;
  int stock;
  bool defaultVariant;
  Map<String, String> attributes;
  int productId;

  Variant({
    this.id,
    this.code,
    required this.combinationName,
    required this.price,
    required this.priceImpact,
    required this.stock,
    required this.defaultVariant,
    required this.attributes,
    required this.productId,
  }) : finalPrice = price + priceImpact;

  Variant copyWith({
    int? id,
    String? code,
    String? combinationName,
    double? price,
    double? priceImpact,
    int? stock,
    bool? defaultVariant,
    Map<String, String>? attributes,
    int? productId,
  }) {
    return Variant(
      id: id ?? this.id,
      code: code ?? this.code,
      combinationName: combinationName ?? this.combinationName,
      price: price ?? this.price,
      priceImpact: priceImpact ?? this.priceImpact,
      stock: stock ?? this.stock,
      defaultVariant: defaultVariant ?? this.defaultVariant,
      attributes: attributes ?? Map.from(this.attributes),
      productId: productId ?? this.productId,
    )..finalPrice = (price ?? this.price) + (priceImpact ?? this.priceImpact);
  }

  Map<String, dynamic> toMap() {
    final map = {
      'code': code,
      'combination_name': combinationName,
      'price': price,
      'price_impact': priceImpact,
      'final_price': finalPrice,
      'stock': stock,
      'default_variant': defaultVariant ? 1 : 0,
      'attributes': _serializeAttributes(attributes),
      'product_id': productId,
    };

    if (id != null) {
      map['id'] = id as Object;
    }

    return map;
  }

  Map<String, dynamic> toExportMap() {
    return {
      'name': combinationName,
      'defaultVariant': defaultVariant,
      'priceImpact': priceImpact,
      'stock': stock,
      'attributes': attributes.isNotEmpty ? attributes : {},
    };
  }

  factory Variant.fromMap(Map<String, dynamic> map) {
    return Variant(
      id: map['id'],
      code: map['code'] ?? '',
      combinationName: map['combination_name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      priceImpact: (map['price_impact'] ?? 0.0).toDouble(),
      stock: map['stock'] ?? 0,
      defaultVariant: (map['default_variant'] ?? 0) == 1, // Convert int to bool
      attributes: _parseAttributes(map['attributes'] ?? '{}'),
      productId: map['product_id'] ?? 0,
    );
  }

  static String _serializeAttributes(Map<String, String> attributes) {
    return jsonEncode(attributes); // Using JSON for more reliable serialization
  }

  static Map<String, String> _parseAttributes(String attributesString) {
    try {
      final decoded = jsonDecode(attributesString) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print('Error parsing variant attributes: $e');
      return {};
    }
  }

  @override
  String toString() {
    return 'Variant(id: $id, code: $code, combination: $combinationName, '
        'price: $price (impact: $priceImpact), stock: $stock, '
        'defaultVariant: $defaultVariant, productId: $productId, '
        'attributes: $attributes)';
  }

  bool get isValid {
    return combinationName.isNotEmpty && price >= 0 && stock >= 0;
  }
}
