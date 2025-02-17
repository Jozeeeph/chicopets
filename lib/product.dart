class Product {
  String code;
  String designation;
  int stock;
  double prixHT;
  double taxe;
  double prixTTC;
  String dateExpiration;
  int categoryId;
  String? categoryName; // Champ optionnel pour le nom de la catégorie

  Product({
    required this.code,
    required this.designation,
    required this.stock,
    required this.prixHT,
    required this.taxe,
    required this.prixTTC,
    required this.dateExpiration,
    required this.categoryId,
    this.categoryName,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'designation': designation,
      'stock': stock,
      'prix_ht': prixHT,
      'taxe': taxe,
      'prix_ttc': prixTTC,
      'date_expiration': dateExpiration,
      'category_id': categoryId,
      // Note : Vous n'avez pas besoin de sauvegarder categoryName si c'est uniquement utilisé pour l'affichage
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      code: map['code'],
      designation: map['designation'],
      stock: map['stock'],
      prixHT: map['prix_ht'],
      taxe: map['taxe'],
      prixTTC: map['prix_ttc'],
      dateExpiration: map['date_expiration'],
      categoryId: map['category_id'] ?? 0,
      categoryName: map['category_name'], // Récupération du nom de la catégorie si présent
    );
  }

  @override
  String toString() {
    return 'Product(code: $code, designation: $designation, stock: $stock, prixTTC: $prixTTC, dateExpiration: $dateExpiration, categoryName: ${categoryName ?? "N/A"})';
  }
}