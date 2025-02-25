class Product {
  String code;
  String designation;
  int stock;
  double prixHT;
  double taxe;
  double prixTTC;
  String dateExpiration;
  int categoryId;
  String? categoryName;
  int subCategoryId;
  String? subCategoryName;
  int isDeleted; // Nouvelle colonne

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
    required this.subCategoryId,
    this.subCategoryName,
    this.isDeleted = 0, // Valeur par défaut 0 (non supprimé)
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
      'sub_category_id': subCategoryId,
      'category_name': categoryName,
      'sub_category_name': subCategoryName,
      'is_deleted': isDeleted, // Nouvelle colonne
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
      categoryName: map['category_name'],
      subCategoryId: map['sub_category_id'] ?? 0,
      subCategoryName: map['sub_category_name'] ?? "Sans sous-catégorie",
      isDeleted: map['is_deleted'] ?? 0, // Valeur par défaut
    );
  }

  @override
  String toString() {
    return 'Product(code: $code, designation: $designation, stock: $stock, prixTTC: $prixTTC, dateExpiration: $dateExpiration, categoryName: ${categoryName ?? "N/A"}, subCategoryId: $subCategoryId, subCategoryName: ${subCategoryName ?? "N/A"}, isDeleted: $isDeleted)';
  }
}
