class Variant {
  int? id;
  String code;
  String combinationName;
  double price;
  double priceImpact;
  double finalPrice; // Calculated field
  int stock;
  Map<String, String> attributes;
  int productId;

  Variant({
    this.id,
    required this.code,
    required this.combinationName,
    required this.price,
    required this.priceImpact,
    required this.stock,
    required this.attributes,
    required this.productId,
  }) : finalPrice = price + priceImpact; // Initialize finalPrice in constructor

  Variant copyWith({
    int? id,
    String? code,
    String? combinationName,
    double? price,
    double? priceImpact,
    int? stock,
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
      'attributes': _serializeAttributes(attributes),
      'product_id': productId,
    };

    // Only include ID if it's not null
    if (id != null) {
      map['id'] = id as Object;
    }

    return map;
  }

  factory Variant.fromMap(Map<String, dynamic> map) {
    return Variant(
      id: map['id'],
      code: map['code'] ?? '',
      combinationName: map['combination_name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      priceImpact: (map['price_impact'] ?? 0.0).toDouble(),
      stock: map['stock'] ?? 0,
      attributes: _parseAttributes(map['attributes'] ?? '{}'),
      productId: map['product_id'] ?? 0,
    );
  }

  static String _serializeAttributes(Map<String, String> attributes) {
    return attributes.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  static Map<String, String> _parseAttributes(String attributesString) {
    final attributes = <String, String>{};
    try {
      attributesString =
          attributesString.replaceAll('{', '').replaceAll('}', '');
      if (attributesString.trim().isNotEmpty) {
        for (final pair in attributesString.split(',')) {
          final keyValue = pair.split(':');
          if (keyValue.length >= 2) {
            final key = keyValue[0].trim();
            final value = keyValue.sublist(1).join(':').trim();
            attributes[key] = value;
          }
        }
      }
    } catch (e) {
      print('Error parsing variant attributes: $e');
    }
    return attributes;
  }

  @override
  String toString() {
    return 'Variant(id: $id, code: $code, combination: $combinationName, '
        'price: $price (impact: $priceImpact), stock: $stock, '
        'productId: $productId, attributes: $attributes)';
  }

  bool get isValid {
    return code.isNotEmpty &&
        combinationName.isNotEmpty &&
        price >= 0 &&
        stock >= 0;
  }
}
