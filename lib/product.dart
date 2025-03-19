import 'package:caissechicopets/variant.dart';

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
  double marge; // Nouveau champ pour la marge %
  String productReferenceId; // Nouvel attribut
  List<Variant> variants; // Liste des variantes
  double remiseMax; // Nouvel attribut pour la remise maximale en pourcentage
  double remiseValeurMax; // Nouvel attribut pour la valeur maximale de la remise

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
    required this.marge,
    required this.productReferenceId, // Nouvel attribut
    this.variants = const [], // Liste des variantes (vide par défaut)
    this.remiseMax = 0.0, // Valeur par défaut 0.0
    this.remiseValeurMax = 0.0, // Valeur par défaut 0.0
  });

  // Méthode pour calculer la marge %
  double calculateMargePercentage() {
    return ((prixTTC - prixHT) / prixHT) * 100;
  }

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
      'is_deleted': isDeleted,
      'marge': marge,
      'product_reference_id': productReferenceId, // Nouvel attribut
      'remise_max': remiseMax, // Nouvel attribut
      'remise_valeur_max': remiseValeurMax, // Nouvel attribut
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
      isDeleted: map['is_deleted'] ?? 0,
      marge: map['marge'] ?? 0.0,
      productReferenceId: map['product_reference_id'], // Nouvel attribut
      remiseMax: map['remise_max'] ?? 0.0, // Nouvel attribut
      remiseValeurMax: map['remise_valeur_max'] ?? 0.0, // Nouvel attribut
    );
  }

  @override
  String toString() {
    return 'Product(code: $code, designation: $designation, stock: $stock, prixTTC: $prixTTC, dateExpiration: $dateExpiration, categoryName: ${categoryName ?? "N/A"}, subCategoryId: $subCategoryId, subCategoryName: ${subCategoryName ?? "N/A"}, isDeleted: $isDeleted, marge: $marge%, productReferenceId: $productReferenceId, remiseMax: $remiseMax%, remiseValeurMax: $remiseValeurMax)';
  }
}