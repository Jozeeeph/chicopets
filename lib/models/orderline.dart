class OrderLine {
  int idOrder;
  String? idProduct;
  int quantite;
  double prixUnitaire;
  double discount;
  bool isPercentage;

  OrderLine({
    required this.idOrder,
    this.idProduct,
    required this.quantite,
    required this.prixUnitaire,
    required this.discount,
    required this.isPercentage,
  });

  double get finalPrice {
    if (discount == 0) {
      return prixUnitaire;
    } else if (isPercentage) {
      return prixUnitaire * (1 - discount / 100);
    } else {
      return prixUnitaire - discount;
    }
  }

  // ✅ Convertir `isPercentage` en `0` ou `1`
  Map<String, dynamic> toMap() {
    return {
      'idOrder': idOrder,
      'idProduct': idProduct,
      'quantite': quantite,
      'prixUnitaire': prixUnitaire,
      'discount': discount,
      'isPercentage': isPercentage ? 1 : 0, // ✅ Convertir bool en int
    };
  }

  // ✅ Récupérer `isPercentage` depuis un entier
  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      idOrder: map['idOrder'],
      idProduct: map['idProduct'],
      quantite: map['quantite'],
      prixUnitaire: map['prixUnitaire'],
      discount: map['discount'],
      isPercentage: map['isPercentage'] == 1, // ✅ Convertir int en bool
    );
  }
}
