class OrderLine {
  int idOrder;       // Required to link the order line to a specific order
  String idProduct;  // Product code
  int quantite;      // Quantity of the product
  double prixUnitaire; // Unit price
  double discount; 

  OrderLine({
    required this.idOrder,
    required this.idProduct,
    required this.quantite,
    required this.prixUnitaire,
    required this.discount,
  });

  // Convert OrderLine to a map (for database storage)
  Map<String, dynamic> toMap() {
    return {
      'idOrder': idOrder,
      'idProduct': idProduct,
      'quantite': quantite,
      'prixUnitaire': prixUnitaire,
      'discount': discount,
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
    );
  }
}
