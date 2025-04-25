import 'package:intl/intl.dart';

class Rapport {
  final int orderId;
  final String? productCode;
  final String productName;
  final String category;
  final DateTime date;
  final int quantity;
  final double unitPrice;
  final double discount;
  final bool isPercentageDiscount;
  final double total;
  final String paymentMethod;
  final String status;
  final int? clientId;  // Added clientId
  final int? variantId;
  final int userId;     // Added userId

  Rapport({
    required this.orderId,
    required this.productCode,
    required this.productName,
    required this.category,
    required this.date,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.isPercentageDiscount,
    required this.total,
    required this.paymentMethod,
    required this.status,
    this.clientId,      // Nullable if client is optional
    this.variantId,      // Nullable if client is optional
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'product_code': productCode,
      'product_name': productName,
      'category': category,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'is_percentage_discount': isPercentageDiscount ? 1 : 0,
      'total': total,
      'payment_method': paymentMethod,
      'status': status,
      'client_id': clientId,    // Added
      'variant_id': variantId,    // Added
      'user_id': userId,        // Added
    };
  }

  factory Rapport.fromMap(Map<String, dynamic> map) {
    return Rapport(
      orderId: map['order_id'],
      productCode: map['product_code'],
      productName: map['product_name'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
      discount: map['discount'],
      isPercentageDiscount: map['is_percentage_discount'] == 1,
      total: map['total'],
      paymentMethod: map['payment_method'],
      status: map['status'],
      clientId: map['client_id'],  // Added
      variantId: map['variant_id'],  // Added
      userId: map['user_id'],      // Added
    );
  }
}