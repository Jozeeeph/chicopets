import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/paymentDetails.dart';

class Order {
  final int? idOrder;
  final String date;
  List<OrderLine> orderLines;
  final String modePaiement;
  double total;
  double remainingAmount;
  String status;
  final int? idClient;
  double globalDiscount;
  bool isPercentageDiscount;
  final int? userId;
  PaymentDetails paymentDetails;

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
    required this.isPercentageDiscount,
    this.userId,
    required this.paymentDetails,
  }) {
    if (total < 0) throw ArgumentError("Total cannot be negative");
    if (globalDiscount < 0) throw ArgumentError("Discount cannot be negative");
    if (remainingAmount < 0) {
      throw ArgumentError("Remaining amount cannot be negative");
    }
  }

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
      'user_id': userId,
      ...paymentDetails.toMap(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, List<OrderLine> orderLines) {
    return Order(
      idOrder: map['id_order'] as int?,
      date: map['date'] as String,
      orderLines: orderLines,
      total: (map['total'] as num).toDouble(),
      modePaiement: map['mode_paiement'] as String,
      status: map['status'] as String? ?? "non payée",
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      idClient: map['id_client'] as int?,
      globalDiscount: (map['global_discount'] as num).toDouble(),
      isPercentageDiscount: (map['is_percentage_discount'] as int?) == 1,
      userId: map['user_id'] as int?,
      paymentDetails: PaymentDetails.fromMap(map),
    );
  }

  Order copyWith({
    int? idOrder,
    String? date,
    List<OrderLine>? orderLines,
    double? total,
    String? modePaiement,
    String? status,
    double? remainingAmount,
    int? idClient,
    double? globalDiscount,
    bool? isPercentageDiscount,
    int? userId,
    PaymentDetails? paymentDetails,
  }) {
    return Order(
      idOrder: idOrder ?? this.idOrder,
      date: date ?? this.date,
      orderLines: orderLines ?? this.orderLines,
      total: total ?? this.total,
      modePaiement: modePaiement ?? this.modePaiement,
      status: status ?? this.status,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      idClient: idClient ?? this.idClient,
      globalDiscount: globalDiscount ?? this.globalDiscount,
      isPercentageDiscount: isPercentageDiscount ?? this.isPercentageDiscount,
      userId: userId ?? this.userId,
      paymentDetails: paymentDetails ?? this.paymentDetails,
    );
  }

  double get totalPayment => paymentDetails.calculateTotalPayment();

  bool get usedVoucher => paymentDetails.voucherAmount != null && paymentDetails.voucherAmount! > 0;

  void processPayment() {
    final totalPaid = paymentDetails.calculateTotalPayment();
    remainingAmount = total - totalPaid;
    status = remainingAmount <= 0 ? "payée" : "partiellement payée";
  }

  @override
  String toString() {
    return 'Order{'
        'id: $idOrder, '
        'date: $date, '
        'total: $total DT, '
        'payment: $modePaiement, '
        'status: $status, '
        'client: $idClient, '
        'user: $userId, '
        'voucher: ${paymentDetails.voucherAmount?.toStringAsFixed(2)} DT'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          idOrder == other.idOrder &&
          date == other.date &&
          total == other.total;

  @override
  int get hashCode => idOrder.hashCode ^ date.hashCode ^ total.hashCode;
}