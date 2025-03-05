class Variant {
  String code;
  String productCode; // Code du produit principal
  String combinationName; // Nom de la combinaison (ex: "Small-Red")
  double price;
  int stock;
  Map<String, String> attributes; // Attributs de la variante (ex: {"size": "small", "color": "red"})

  Variant({
    required this.code,
    required this.productCode,
    required this.combinationName,
    required this.price,
    required this.stock,
    required this.attributes,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'product_code': productCode,
      'combination_name': combinationName,
      'price': price,
      'stock': stock,
      'attributes': attributes.toString(), // Convertir Map en String pour la base de données
    };
  }

  factory Variant.fromMap(Map<String, dynamic> map) {
    return Variant(
      code: map['code'],
      productCode: map['product_code'],
      combinationName: map['combination_name'],
      price: map['price'],
      stock: map['stock'],
      attributes: _parseAttributes(map['attributes']), // Convertir String en Map
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