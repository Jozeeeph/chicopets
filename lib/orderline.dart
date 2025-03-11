class OrderLine {
  int idOrder;       // Required to link the order line to a specific order
  String idProduct;  // Product code
  int quantite;      // Quantity of the product
  double prixUnitaire; // Unit price
  double discount;   // Discount value
  bool isPercentage; // True if discount is %, false if it's DT

  OrderLine({
    required this.idOrder,
    required this.idProduct,
    required this.quantite,
    required this.prixUnitaire,
    required this.discount,
    required this.isPercentage,
  });

  // Computed property for final price
  double get finalPrice {
    if (discount == 0) {
      // If no discount, return the unit price
      return prixUnitaire;
    } else if (isPercentage) {
      // If discount is a percentage, apply it
      return prixUnitaire * (1 - discount / 100);
    } else {
      // If discount is a fixed value, subtract it
      return prixUnitaire - discount;
    }
  }

  // Convert OrderLine to a map (for database storage)
  Map<String, dynamic> toMap() {
    return {
      'idOrder': idOrder,
      'idProduct': idProduct,
      'quantite': quantite,
      'prixUnitaire': prixUnitaire,
      'discount': discount,
      'isPercentage': isPercentage,
    };
  }

  // Create an OrderLine from a map (for database retrieval)
  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      idOrder: map['idOrder'],
      idProduct: map['idProduct'],
      quantite: map['quantite'],
      prixUnitaire: map['prixUnitaire'],
      discount: map['discount'],
      isPercentage: map['isPercentage'],
    );
  }
}
