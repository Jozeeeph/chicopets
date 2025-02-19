class VariantProd {
  String id;
  String productCode;
  String size;
  double prixHT;
  double taxe;
  double prixTTC;

  VariantProd({
    required this.id,
    required this.productCode,
    required this.size,
    required this.prixHT,
    required this.taxe,
    required this.prixTTC,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_code': productCode,
      'size': size,
      'prix_ht': prixHT,
      'taxe': taxe,
      'prix_ttc': prixTTC,
    };
  }

  factory VariantProd.fromMap(Map<String, dynamic> map) {
    return VariantProd(
      id: map['id'],
      productCode: map['product_code'],
      size: map['size'],
      prixHT: map['prix_ht'],
      taxe: map['taxe'],
      prixTTC: map['prix_ttc'],
    );
  }
}