class Product {
  String code;
  String designation;
  int stock;
  double prixHT;
  double taxe;
  double prixTTC;
  String dateExpiration;

  Product({
    required this.code,
    required this.designation,
    required this.stock,
    required this.prixHT,
    required this.taxe,
    required this.prixTTC,
    required this.dateExpiration,
  });

  // Convertir un objet Product en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'designation': designation,
      'stock': stock,
      'prix_ht': prixHT,
      'taxe': taxe,
      'prix_ttc': prixTTC,
      'date_expiration': dateExpiration,
    };
  }

  // Créer un objet Product à partir d'un Map (données SQLite)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      code: map['code'],
      designation: map['designation'],
      stock: map['stock'],
      prixHT: map['prix_ht'],
      taxe: map['taxe'],
      prixTTC: map['prix_ttc'],
      dateExpiration: map['date_expiration'],
    );
  }

  @override
  String toString() {
    return 'Product(code: $code, name: $designation, stock: $stock, price: $prixTTC DT, exp: $dateExpiration)';
  }
}
