
import 'package:caissechicopets/orderline.dart';

class Order {
  int? idOrder; 
  String date;
  List<OrderLine> orderLines; // ✅ Change from List<Product> to List<OrderLine>
  double total;
  String modePaiement;
  String? status;
  int? idClient; 

  Order({
    this.idOrder, 
    required this.date,
    required this.orderLines, // ✅ Updated
    required this.total,
    required this.modePaiement,
    this.status,
    this.idClient,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_order': idOrder,
      'date': date,
      'total': total,
      'mode_paiement': modePaiement,
      'status': status,
      'id_client': idClient,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      idOrder: map['id_order'],
      date: map['date'],
      orderLines: [], 
      total: map['total'].toDouble(),
      modePaiement: map['mode_paiement'],
      status: map['status'],
      idClient: map['id_client'],
    );
  }
}
