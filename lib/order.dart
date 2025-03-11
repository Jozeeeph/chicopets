import 'package:caissechicopets/orderline.dart';

class Order {
  int? idOrder;
  String date;
  List<OrderLine> orderLines;
  double total;
  String modePaiement;
  String status;
  double remainingAmount;
  int? idClient;
  double globalDiscount;

  Order({
    this.idOrder,
    required this.date,
    required this.orderLines,
    required this.total,
    required this.modePaiement,
    this.status = "non payée",
    this.remainingAmount = 0.0,
    this.idClient,
    required this.globalDiscount,
  });

  // Convert Order object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id_order': idOrder,
      'date': date,
      'total': total,
      'mode_paiement': modePaiement,
      'status': status,
      'remaining_amount': remainingAmount,
      'id_client': idClient,
      'global_discount': globalDiscount,
    };
  }

  // Create an Order object from a Map
  factory Order.fromMap(Map<String, dynamic> map, List<OrderLine> orderLines) {
    return Order(
      idOrder: map['id_order'],
      date: map['date'],
      orderLines: orderLines,
      total: map['total'].toDouble(),
      modePaiement: map['mode_paiement'],
      status: map['status'] ?? "non payée",
      remainingAmount: map['remaining_amount']?.toDouble() ?? 0.0,
      idClient: map['id_client'],
      globalDiscount: map['global_discount'],
    );
  }

  @override
  String toString() {
    return 'reste: $remainingAmount';
  }
}
