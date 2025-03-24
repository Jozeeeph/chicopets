class Variant {
  int id; // Nouvel ID auto-incrémenté
  String code;
  String combinationName;
  double price;
  double priceImpact;
  double finalPrice;
  int stock;
  Map<String, String> attributes;
  int productId; // Maintenant un int pour référencer l'ID du produit

  Variant({
    this.id = 0,
    required this.code,
    required this.combinationName,
    required this.price,
    required this.priceImpact,
    required this.stock,
    required this.attributes,
    required this.productId,
  }) : finalPrice = price + priceImpact;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'combination_name': combinationName,
      'price': price,
      'price_impact': priceImpact,
      'final_price': finalPrice,
      'stock': stock,
      'attributes': attributes.toString(),
      'product_id': productId, // Changé de product_reference_id à product_id
    };
  }

  factory Variant.fromMap(Map<String, dynamic> map) {
    return Variant(
      id: map['id'] ?? 0,
      code: map['code'],
      combinationName: map['combination_name'],
      price: map['price'],
      priceImpact: map['price_impact'] ?? 0.0,
      stock: map['stock'],
      attributes: _parseAttributes(map['attributes']),
      productId: map['product_id'], // Changé ici aussi
    );
  }

  static Map<String, String> _parseAttributes(String attributesString) {
    // Convertir la chaîne de caractères en Map
    Map<String, String> attributes = {};
    attributesString = attributesString.replaceAll('{', '').replaceAll('}', '');
    attributesString.split(',').forEach((pair) {
      var keyValue = pair.split(':');
      if (keyValue.length == 2) {
        attributes[keyValue[0].trim()] = keyValue[1].trim();
      }
    });
    return attributes;
  }
}
