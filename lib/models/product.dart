import 'package:caissechicopets/models/variant.dart';

class Product {
  int? id; // Changed from int id = 0 to nullable
  String? code;
  String designation;
  String? description;
  int stock;
  double prixHT;
  double taxe;
  double prixTTC;
  String dateExpiration;
  int categoryId;
  int? subCategoryId;
  String? categoryName;
  String? subCategoryName;
  int isDeleted;
  double marge;
  List<Variant> variants;
  double remiseMax;
  double remiseValeurMax;
  bool hasVariants;
  bool sellable;
  String status;
  String? image; // Added image attribute
  String? brand; // Added brand attribute
  bool earnsFidelityPoints; // Whether product earns points
  int fidelityPointsEarned; // Points earned when buying
  bool redeemableWithPoints; // Can be bought with points
  int fidelityPointsCost; // Points needed to redeem
  double? maxPointsDiscount; // Max discount allowed with points
  double? pointsDiscountPercentage; // Discount percentage when using points

  Product({
    this.id, // Changed from default 0 to nullable
    this.code,
    required this.designation,
    this.description,
    required this.stock,
    required this.prixHT,
    required this.taxe,
    required this.prixTTC,
    required this.dateExpiration,
    required this.categoryId,
    this.categoryName,
    this.subCategoryId,
    this.subCategoryName,
    this.isDeleted = 0,
    required this.marge,
    this.variants = const [],
    this.remiseMax = 0.0,
    this.remiseValeurMax = 0.0,
    this.hasVariants = false,
    this.sellable = true,
    this.status = 'En stock',
    this.image, // Added to constructor
    this.brand, // Added to constructor
    this.earnsFidelityPoints = false,
    this.fidelityPointsEarned = 0,
    this.redeemableWithPoints = false,
    this.fidelityPointsCost = 0,
    this.maxPointsDiscount,
    this.pointsDiscountPercentage,
  });

  String get productReferenceId => id?.toString() ?? 'new';

  Product copyWith({
    int? id,
    String? code,
    String? designation,
    String? description,
    int? stock,
    double? prixHT,
    double? taxe,
    double? prixTTC,
    String? dateExpiration,
    int? categoryId,
    int? subCategoryId,
    String? categoryName,
    String? subCategoryName,
    int? isDeleted,
    double? marge,
    List<Variant>? variants,
    double? remiseMax,
    double? remiseValeurMax,
    bool? hasVariants,
    bool? sellable,
    String? status,
    String? image,
    String? brand,
    bool? earnsFidelityPoints,
    int? fidelityPointsEarned,
    bool? redeemableWithPoints,
    int? fidelityPointsCost,
    double? maxPointsDiscount,
    double? pointsDiscountPercentage,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      designation: designation ?? this.designation,
      description: description ?? this.description,
      stock: stock ?? this.stock,
      prixHT: prixHT ?? this.prixHT,
      taxe: taxe ?? this.taxe,
      prixTTC: prixTTC ?? this.prixTTC,
      dateExpiration: dateExpiration ?? this.dateExpiration,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      categoryName: categoryName ?? this.categoryName,
      subCategoryName: subCategoryName ?? this.subCategoryName,
      isDeleted: isDeleted ?? this.isDeleted,
      marge: marge ?? this.marge,
      variants: variants ?? this.variants,
      remiseMax: remiseMax ?? this.remiseMax,
      remiseValeurMax: remiseValeurMax ?? this.remiseValeurMax,
      hasVariants: hasVariants ?? this.hasVariants,
      sellable: sellable ?? this.sellable,
      status: status ?? this.status,
      image: image ?? this.image,
      brand: brand ?? this.brand,
      earnsFidelityPoints: earnsFidelityPoints ?? this.earnsFidelityPoints,
      fidelityPointsEarned: fidelityPointsEarned ?? this.fidelityPointsEarned,
      redeemableWithPoints: redeemableWithPoints ?? this.redeemableWithPoints,
      fidelityPointsCost: fidelityPointsCost ?? this.fidelityPointsCost,
      maxPointsDiscount: maxPointsDiscount ?? this.maxPointsDiscount,
      pointsDiscountPercentage:
          pointsDiscountPercentage ?? this.pointsDiscountPercentage,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'code': code,
      'designation': designation,
      'description': description,
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
      'sellable': sellable ? 1 : 0,
      'status': status,
      'image': image, // Added to toMap
      'brand': brand, // Added to toMap
      'earns_fidelity_points': earnsFidelityPoints ? 1 : 0,
      'fidelity_points_earned': fidelityPointsEarned,
      'redeemable_with_points': redeemableWithPoints ? 1 : 0,
      'fidelity_points_cost': fidelityPointsCost,
      'max_points_discount': maxPointsDiscount,
      'points_discount_percentage': pointsDiscountPercentage,
    };

    // Only include ID if it's not null and not 0 (for updates)
    if (id != null && id != 0) {
      map['id'] = id;
    }

    return map;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'], // No default value here
      code: map['code'] ?? '',
      designation: map['designation'] ?? '',
      description: map['description'] ?? '',
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
      sellable: map['sellable'] == 1,
      status: map['status'] ?? 'En stock',
      image: map['image'], // Added to fromMap
      brand: map['brand'], // Added to fromMap
      earnsFidelityPoints: map['earns_fidelity_points'] == 1,
      fidelityPointsEarned: map['fidelity_points_earned'] ?? 0,
      redeemableWithPoints: map['redeemable_with_points'] == 1,
      fidelityPointsCost: map['fidelity_points_cost'] ?? 0,
      maxPointsDiscount: (map['max_points_discount'] as num?)?.toDouble(),
      pointsDiscountPercentage:
          (map['points_discount_percentage'] as num?)?.toDouble(),
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

  // New method to calculate points earned for a quantity
  int calculatePointsEarned(int quantity) {
    if (!earnsFidelityPoints) return 0;
    return fidelityPointsEarned * quantity;
  }

  // New method to check if product can be redeemed with points
  bool canRedeemWithPoints(int customerPoints) {
    if (!redeemableWithPoints) return false;
    return customerPoints >= fidelityPointsCost;
  }

  // New method to calculate maximum discount from points
  double calculatePointsDiscount(int pointsToUse) {
    if (!redeemableWithPoints || pointsDiscountPercentage == null) return 0.0;

    // Calculate discount based on percentage
    double discount = prixTTC * (pointsDiscountPercentage! / 100);

    // Apply maximum discount limit if set
    if (maxPointsDiscount != null && discount > maxPointsDiscount!) {
      return maxPointsDiscount!;
    }
    return discount;
  }

  Map<String, dynamic> toExportMap() {
    return {
      'product': {
        'name': designation,
        'reference': code ?? '',
        'category': categoryName ?? 'Default',
        'subCategory': subCategoryName,
        'brand': brand,
        'description': description,
        'costPrice': prixHT - marge,
        'prixHT': prixHT,
        'taxe': taxe,
        'prixTTC': prixTTC,
        'stock': stock,
        'sellable': sellable,
        'simpleProduct': !hasVariants, // True for simple products
        'image': image,
        'status': status,
        'dateExpiration': dateExpiration,
        'fidelity': {
          'earnsPoints': earnsFidelityPoints,
          'pointsEarned': fidelityPointsEarned,
          'redeemable': redeemableWithPoints,
          'pointsCost': fidelityPointsCost,
          'maxDiscount': maxPointsDiscount,
          'discountPercentage': pointsDiscountPercentage,
        },
      },
      'variants': hasVariants
          ? variants.map((v) => v.toExportMap()).toList()
          : [], // Empty array for simple products
    };
  }

  @override
  String toString() {
    return 'Product(id: $id, code: $code, designation: $designation, description: $description '
        'stock: $stock, prixHT: $prixHT, taxe: $taxe, prixTTC: $prixTTC, '
        'category: $categoryName ($categoryId), '
        'subCategory: $subCategoryName ($subCategoryId), '
        'variants: ${variants.length}, sellable: $sellable, '
        'image: $image, brand: $brand'; // Updated toString
  }
}
