class Variant {
  String code;
  String combinationName; // Nom de la combinaison (ex: "Small-Red")
  double price; // Prix de base
  double priceImpact; // Prix d'impact (positif ou négatif)
  double finalPrice; // Prix total après application du prix d'impact
  int stock;
  Map<String, String> attributes; // Attributs de la variante (ex: {"size": "small", "color": "red"})
  String productReferenceId; // Nouvel attribut (clé étrangère)

  Variant({
    required this.code,
    required this.combinationName,
    required this.price,
    required this.priceImpact,
    required this.stock,
    required this.attributes,
    required this.productReferenceId, // Nouvel attribut
  }) : finalPrice = price + priceImpact; // Calcul du prix total

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'combination_name': combinationName,
      'price': price,
      'price_impact': priceImpact,
      'final_price': finalPrice,
      'stock': stock,
      'attributes': attributes.toString(), // Convertir Map en String pour la base de données
      'product_reference_id': productReferenceId, // Nouvel attribut
    };
  }

  factory Variant.fromMap(Map<String, dynamic> map) {
    return Variant(
      code: map['code'],
      combinationName: map['combination_name'],
      price: map['price'],
      priceImpact: map['price_impact'] ?? 0.0,
      stock: map['stock'],
      attributes: _parseAttributes(map['attributes']), // Convertir String en Map
      productReferenceId: map['product_reference_id'], // Nouvel attribut
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