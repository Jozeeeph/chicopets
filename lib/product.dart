import 'package:caissechicopets/variantprod.dart';

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
  bool hasVariants;
  List<VariantProd> variants;

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
    this.hasVariants = false,
    this.variants = const [],
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
      'has_variants': hasVariants ? 1 : 0,
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
      hasVariants: map['has_variants'] == 1,
    );
  }

  @override
  String toString() {
    return 'Product(code: $code, designation: $designation, stock: $stock, prixTTC: $prixTTC, dateExpiration: $dateExpiration, categoryName: ${categoryName ?? "N/A"}, hasVariants: $hasVariants)';
  }
}