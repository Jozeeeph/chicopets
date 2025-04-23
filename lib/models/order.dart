import 'package:caissechicopets/models/orderline.dart';

class Order {
  int? idOrder;
  String date;
  List<OrderLine> orderLines;
  double total;
  String modePaiement; // Peut être "Espèce", "TPE", "Chèque", "Mixte"
  String status;
  double remainingAmount;
  int? idClient;
  double globalDiscount;
  bool isPercentageDiscount;

  // Nouveaux champs pour les paiements mixtes
  double? cashAmount;
  double? cardAmount;
  double? checkAmount;
  String? checkNumber; // Numéro du chèque
  String? cardTransactionId; // ID de transaction TPE
  DateTime? checkDate; // Date du chèque
  String? bankName; // Nom de la banque pour les chèques
  int? pointsUsed;
  double? pointsDiscount;

  Order(
      {this.idOrder,
      required this.date,
      required this.orderLines,
      required this.total,
      required this.modePaiement,
      this.status = "non payée",
      this.remainingAmount = 0.0,
      this.idClient,
      required this.globalDiscount,
      required this.isPercentageDiscount,
      this.cashAmount,
      this.cardAmount,
      this.checkAmount,
      this.checkNumber,
      this.cardTransactionId,
      this.checkDate,
      this.bankName,
      this.pointsUsed,
      this.pointsDiscount});

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
      'is_percentage_discount': isPercentageDiscount ? 1 : 0,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'check_amount': checkAmount,
      'check_number': checkNumber,
      'card_transaction_id': cardTransactionId,
      'check_date': checkDate?.toIso8601String(),
      'bank_name': bankName,
      'points_used': pointsUsed,
      'points_discount': pointsDiscount,
    };
  }

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
      isPercentageDiscount: map['is_percentage_discount'] == 1,
      cashAmount: map['cash_amount']?.toDouble(),
      cardAmount: map['card_amount']?.toDouble(),
      checkAmount: map['check_amount']?.toDouble(),
      checkNumber: map['check_number'],
      cardTransactionId: map['card_transaction_id'],
      checkDate:
          map['check_date'] != null ? DateTime.parse(map['check_date']) : null,
      bankName: map['bank_name'],
      pointsUsed: map['points_used'],
      pointsDiscount: map['points_discount'],
    );
  }

  @override
  String toString() {
    return 'reste: $remainingAmount';
  }
}
