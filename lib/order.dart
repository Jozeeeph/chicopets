import 'package:caissechicopets/orderline.dart';

class Order {
  int? idOrder;
  String date;
  List<OrderLine> orderLines;
  double total;
  String modePaiement;
  String status; // Non-nullable with a default value
  double remainingAmount; // Non-nullable with a default value
  int? idClient; // Optional field

  Order({
    this.idOrder,
    required this.date,
    required this.orderLines,
    required this.total,
    required this.modePaiement,
    this.status = "non payée", // Default status
    this.remainingAmount = 0.0, // Default remaining amount
    this.idClient,
  });

  // Convert Order object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id_order': idOrder,
      'date': date,
      'total': total,
      'mode_paiement': modePaiement,
      'status': status,
      'remaining_amount': remainingAmount, // Include remainingAmount
      'id_client': idClient,
    };
  }

  // Create an Order object from a Map
  factory Order.fromMap(Map<String, dynamic> map, List<OrderLine> orderLines) {
    return Order(
      idOrder: map['id_order'],
      date: map['date'],
      orderLines: orderLines, // Pass the orderLines explicitly
      total: map['total'].toDouble(),
      modePaiement: map['mode_paiement'],
      status: map['status'] ?? "non payée", // Default status if null
      remainingAmount: map['remaining_amount']?.toDouble() ?? 0.0, // Default remainingAmount if null
      idClient: map['id_client'],
    );
  }
}
