import 'package:caissechicopets/variant.dart';

class Product {
  int id; // Nouvel ID auto-incrémenté
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
  int isDeleted;
  double marge;
  List<Variant> variants;
  double remiseMax;
  double remiseValeurMax;

  Product({
    this.id = 0, // 0 signifie que l'ID n'est pas encore attribué
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
    this.isDeleted = 0,
    required this.marge,
    this.variants = const [],
    this.remiseMax = 0.0,
    this.remiseValeurMax = 0.0,
  });

  // Méthode pour obtenir la référence produit (utilise maintenant l'ID)
  String get productReferenceId => id.toString();

  // ... (autres méthodes restent inchangées jusqu'à toMap)

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Ajout de l'ID dans la map
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
      'remise_max': remiseMax,
      'remise_valeur_max': remiseValeurMax,
      // product_reference_id n'est plus nécessaire car calculé à partir de l'ID
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? 0, // Récupération de l'ID
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
      remiseMax: map['remise_max'] ?? 0.0,
      remiseValeurMax: map['remise_valeur_max'] ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, code: $code, designation: $designation, ...)';
  }
}