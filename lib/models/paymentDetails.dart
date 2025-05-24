class PaymentDetails {
  // Payment amounts
  double? cashAmount;
  double? cardAmount;
  double? checkAmount;
  final double? ticketRestaurantAmount;
  double? voucherAmount;
  List<int>? voucherIds;
  String? voucherReference;

  // Payment metadata
  String? checkNumber;
  String? cardTransactionId;
  DateTime? checkDate;
  String? bankName;

  // Ticket restaurant details
  final int? numberOfTicketsRestaurant;
  final double? ticketValue;
  final double? ticketTax;
  final double? ticketCommission;

  final double? giftTicketAmount;
  final double? traiteAmount;
  final double? virementAmount;

  // New payment details
  final String? giftTicketNumber;
  final String? giftTicketIssuer;
  final String? traiteNumber;
  final String? traiteBank;
  final String? traiteBeneficiary;
  final DateTime? traiteDate;
  final String? virementReference;
  final String? virementBank;
  final String? virementSender;
  final DateTime? virementDate;

  // Loyalty program
  final int? pointsUsed;
  final double? pointsDiscount;

  PaymentDetails({
    this.cashAmount,
    this.cardAmount,
    this.checkAmount,
    this.ticketRestaurantAmount,
    this.voucherAmount,
    this.voucherIds,
    this.voucherReference,
    this.checkNumber,
    this.cardTransactionId,
    this.checkDate,
    this.bankName,
    this.numberOfTicketsRestaurant,
    this.ticketValue,
    this.ticketTax,
    this.ticketCommission,
    this.giftTicketAmount,
    this.traiteAmount,
    this.virementAmount,
    this.giftTicketNumber,
    this.giftTicketIssuer,
    this.traiteNumber,
    this.traiteBank,
    this.traiteBeneficiary,
    this.traiteDate,
    this.virementReference,
    this.virementBank,
    this.virementSender,
    this.virementDate,
    this.pointsUsed,
    this.pointsDiscount,
  }) {
    if (voucherAmount != null && voucherAmount! < 0) {
      throw ArgumentError("Voucher amount cannot be negative");
    }
  }

  Map<String, dynamic> toMap() {
    return {
      // Payment amounts
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'check_amount': checkAmount,
      'ticket_restaurant_amount': ticketRestaurantAmount,
      'voucher_amount': voucherAmount,
      'voucher_ids': voucherIds?.join(','),
      'voucher_reference': voucherReference,

      // Payment details
      'check_number': checkNumber,
      'card_transaction_id': cardTransactionId,
      'check_date': checkDate?.toIso8601String(),
      'bank_name': bankName,

      // Ticket restaurant details
      'number_of_tickets_restaurant': numberOfTicketsRestaurant,
      'ticket_value': ticketValue,
      'ticket_tax': ticketTax,
      'ticket_commission': ticketCommission,
      'gift_ticket_amount': giftTicketAmount,
      'traite_amount': traiteAmount,
      'virement_amount': virementAmount,

      // New payment details
      'gift_ticket_number': giftTicketNumber,
      'gift_ticket_issuer': giftTicketIssuer,
      'traite_number': traiteNumber,
      'traite_bank': traiteBank,
      'traite_beneficiary': traiteBeneficiary,
      'traite_date': traiteDate?.toIso8601String(),
      'virement_reference': virementReference,
      'virement_bank': virementBank,
      'virement_sender': virementSender,
      'virement_date': virementDate?.toIso8601String(),

      // Loyalty program
      'points_used': pointsUsed,
      'points_discount': pointsDiscount,
    };
  }

  factory PaymentDetails.fromMap(Map<String, dynamic> map) {
    List<int>? voucherIds;
    if (map['voucher_ids'] != null && map['voucher_ids'].toString().isNotEmpty) {
      voucherIds = (map['voucher_ids'] as String).split(',').map(int.parse).toList();
    }

    return PaymentDetails(
      // Payment amounts
      cashAmount: (map['cash_amount'] as num?)?.toDouble(),
      cardAmount: (map['card_amount'] as num?)?.toDouble(),
      checkAmount: (map['check_amount'] as num?)?.toDouble(),
      ticketRestaurantAmount: (map['ticket_restaurant_amount'] as num?)?.toDouble(),
      voucherAmount: (map['voucher_amount'] as num?)?.toDouble(),
      voucherIds: voucherIds,
      voucherReference: map['voucher_reference'] as String?,

      // Payment details
      checkNumber: map['check_number'] as String?,
      cardTransactionId: map['card_transaction_id'] as String?,
      checkDate: map['check_date'] != null ? DateTime.parse(map['check_date'] as String) : null,
      bankName: map['bank_name'] as String?,

      // Ticket restaurant details
      numberOfTicketsRestaurant: map['number_of_tickets_restaurant'] as int?,
      ticketValue: (map['ticket_value'] as num?)?.toDouble(),
      ticketTax: (map['ticket_tax'] as num?)?.toDouble(),
      ticketCommission: (map['ticket_commission'] as num?)?.toDouble(),

      giftTicketAmount: (map['gift_ticket_amount'] as num?)?.toDouble(),
      traiteAmount: (map['traite_amount'] as num?)?.toDouble(),
      virementAmount: (map['virement_amount'] as num?)?.toDouble(),
      giftTicketNumber: map['gift_ticket_number'] as String?,
      giftTicketIssuer: map['gift_ticket_issuer'] as String?,
      traiteNumber: map['traite_number'] as String?,
      traiteBank: map['traite_bank'] as String?,
      traiteBeneficiary: map['traite_beneficiary'] as String?,
      traiteDate: map['traite_date'] != null ? DateTime.parse(map['traite_date'] as String) : null,
      virementReference: map['virement_reference'] as String?,
      virementBank: map['virement_bank'] as String?,
      virementSender: map['virement_sender'] as String?,
      virementDate: map['virement_date'] != null ? DateTime.parse(map['virement_date'] as String) : null,
      
      // Loyalty program
      pointsUsed: map['points_used'] as int?,
      pointsDiscount: (map['points_discount'] as num?)?.toDouble(),
    );
  }

  PaymentDetails copyWith({
    double? cashAmount,
    double? cardAmount,
    double? checkAmount,
    double? ticketRestaurantAmount,
    double? voucherAmount,
    List<int>? voucherIds,
    String? voucherReference,
    String? checkNumber,
    String? cardTransactionId,
    DateTime? checkDate,
    String? bankName,
    int? numberOfTicketsRestaurant,
    double? ticketValue,
    double? ticketTax,
    double? ticketCommission,
    double? giftTicketAmount,
    double? traiteAmount,
    double? virementAmount,
    String? giftTicketNumber,
    String? giftTicketIssuer,
    String? traiteNumber,
    String? traiteBank,
    String? traiteBeneficiary,
    DateTime? traiteDate,
    String? virementReference,
    String? virementBank,
    String? virementSender,
    DateTime? virementDate,
    int? pointsUsed,
    double? pointsDiscount,
  }) {
    return PaymentDetails(
      cashAmount: cashAmount ?? this.cashAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      checkAmount: checkAmount ?? this.checkAmount,
      ticketRestaurantAmount: ticketRestaurantAmount ?? this.ticketRestaurantAmount,
      voucherAmount: voucherAmount ?? this.voucherAmount,
      voucherIds: voucherIds ?? this.voucherIds,
      voucherReference: voucherReference ?? this.voucherReference,
      checkNumber: checkNumber ?? this.checkNumber,
      cardTransactionId: cardTransactionId ?? this.cardTransactionId,
      checkDate: checkDate ?? this.checkDate,
      bankName: bankName ?? this.bankName,
      numberOfTicketsRestaurant: numberOfTicketsRestaurant ?? this.numberOfTicketsRestaurant,
      ticketValue: ticketValue ?? this.ticketValue,
      ticketTax: ticketTax ?? this.ticketTax,
      ticketCommission: ticketCommission ?? this.ticketCommission,
      giftTicketAmount: giftTicketAmount ?? this.giftTicketAmount,
      traiteAmount: traiteAmount ?? this.traiteAmount,
      virementAmount: virementAmount ?? this.virementAmount,
      giftTicketNumber: giftTicketNumber ?? this.giftTicketNumber,
      giftTicketIssuer: giftTicketIssuer ?? this.giftTicketIssuer,
      traiteNumber: traiteNumber ?? this.traiteNumber,
      traiteBank: traiteBank ?? this.traiteBank,
      traiteBeneficiary: traiteBeneficiary ?? this.traiteBeneficiary,
      traiteDate: traiteDate ?? this.traiteDate,
      virementReference: virementReference ?? this.virementReference,
      virementBank: virementBank ?? this.virementBank,
      virementSender: virementSender ?? this.virementSender,
      virementDate: virementDate ?? this.virementDate,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      pointsDiscount: pointsDiscount ?? this.pointsDiscount,
    );
  }

  double calculateTotalPayment() {
    return (cashAmount ?? 0) +
        (cardAmount ?? 0) +
        (checkAmount ?? 0) +
        (ticketRestaurantAmount ?? 0) +
        (voucherAmount ?? 0) +
        (giftTicketAmount ?? 0) +
        (traiteAmount ?? 0) +
        (virementAmount ?? 0) +
        (pointsDiscount ?? 0);
  }

  bool get hasPaymentDetails {
    return cashAmount != null ||
        cardAmount != null ||
        checkAmount != null ||
        ticketRestaurantAmount != null ||
        voucherAmount != null ||
        giftTicketAmount != null ||
        traiteAmount != null ||
        virementAmount != null;
  }
}