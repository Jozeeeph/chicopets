import 'package:caissechicopets/variant.dart';

class Product {
  int? id; // Changed from int id = 0 to nullable
  String code;
  String designation;
  int stock;
  double prixHT;
  double taxe;
  double prixTTC;
  String dateExpiration;
  int categoryId;
  int subCategoryId;
  String? categoryName;
  String? subCategoryName;
  int isDeleted;
  double marge;
  List<Variant> variants;
  double remiseMax;
  double remiseValeurMax;
  bool hasVariants;

  Product({
    this.id, // Changed from default 0 to nullable
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
    this.hasVariants = false,
  });

  String get productReferenceId => id?.toString() ?? 'new';

  Product copyWith({
    int? id,
    String? code,
    String? designation,
    int? stock,
    double? prixHT,
    double? taxe,
    double? prixTTC,
    String? dateExpiration,
    int? categoryId,
    String? categoryName,
    int? subCategoryId,
    String? subCategoryName,
    int? isDeleted,
    double? marge,
    List<Variant>? variants,
    double? remiseMax,
    double? remiseValeurMax,
    bool? hasVariants,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      designation: designation ?? this.designation,
      stock: stock ?? this.stock,
      prixHT: prixHT ?? this.prixHT,
      taxe: taxe ?? this.taxe,
      prixTTC: prixTTC ?? this.prixTTC,
      dateExpiration: dateExpiration ?? this.dateExpiration,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      subCategoryName: subCategoryName ?? this.subCategoryName,
      isDeleted: isDeleted ?? this.isDeleted,
      marge: marge ?? this.marge,
      variants: variants ?? this.variants,
      remiseMax: remiseMax ?? this.remiseMax,
      remiseValeurMax: remiseValeurMax ?? this.remiseValeurMax,
      hasVariants: hasVariants ?? this.hasVariants,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
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
      'has_variants': hasVariants ? 1 : 0,
    };

    // Only include ID if it's not null (for updates)
    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'], // No default value here
      code: map['code'] ?? '',
      designation: map['designation'] ?? '',
      stock: map['stock'] ?? 0,
      prixHT: (map['prix_ht'] ?? 0.0).toDouble(),
      taxe: (map['taxe'] ?? 0.0).toDouble(),
      prixTTC: (map['prix_ttc'] ?? 0.0).toDouble(),
      dateExpiration: map['date_expiration'] ?? '',
      categoryId: map['category_id'] ?? 0,
      categoryName: map['category_name'],
      subCategoryId: map['sub_category_id'] ?? 0,
      subCategoryName: map['sub_category_name'],
      isDeleted: map['is_deleted'] ?? 0,
      marge: (map['marge'] ?? 0.0).toDouble(),
      remiseMax: (map['remise_max'] ?? 0.0).toDouble(),
      remiseValeurMax: (map['remise_valeur_max'] ?? 0.0).toDouble(),
      hasVariants: map['has_variants'] == 1,
    );
  }

  // Helper method to calculate total stock including variants
  int get totalStock {
    if (variants.isNotEmpty) {
      return variants.fold(0, (sum, variant) => sum + variant.stock);
    }
    return stock;
  }

  // Helper method to get minimum price (for variants)
  double get minPrice {
    if (variants.isNotEmpty) {
      return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
    }
    return prixHT;
  }

  @override
  String toString() {
    return 'Product(id: $id, code: $code, designation: $designation, '
        'stock: $stock, prixHT: $prixHT, taxe: $taxe, prixTTC: $prixTTC, '
        'category: $categoryName ($categoryId), '
        'subCategory: $subCategoryName ($subCategoryId), '
        'variants: ${variants.length}';
  }
}
