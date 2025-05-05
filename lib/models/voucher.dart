import 'dart:math';

import 'package:intl/intl.dart';

class Voucher {
  final int id;
  final int clientId;
  final double amount;
  double remainingAmount; // New field to track unused portion
  final int pointsUsed;
  final DateTime createdAt;
  final DateTime? expiresAt; // New field for expiration
  final bool isUsed;
  final DateTime? usedAt;
  final String? code; // Unique voucher code
  final String? notes; // Optional notes

  Voucher({
    required this.id,
    required this.clientId,
    required this.amount,
    this.remainingAmount = 0,
    required this.pointsUsed,
    required this.createdAt,
    this.expiresAt,
    this.isUsed = false,
    this.usedAt,
    this.code,
    this.notes,
  }) {
    // Initialize remaining amount to full amount if not specified
    if (remainingAmount == 0) {
      remainingAmount = amount;
    }
  }

  // Convert Voucher to Map for database operations
  Map<String, dynamic> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'client_id': clientId,
      'amount': amount,
      'remaining_amount': remainingAmount,
      'points_used': pointsUsed,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_used': isUsed ? 1 : 0,
      'used_at': usedAt?.toIso8601String(),
      'code': code,
      'notes': notes,
    };
  }

  // Create Voucher from Map (database result)
  factory Voucher.fromMap(Map<String, dynamic> map) {
    return Voucher(
      id: map['id'] as int,
      clientId: map['client_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ??
          (map['amount'] as num).toDouble(),
      pointsUsed: map['points_used'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      isUsed: (map['is_used'] as int) == 1,
      usedAt: map['used_at'] != null
          ? DateTime.parse(map['used_at'] as String)
          : null,
      code: map['code'] as String?,
      notes: map['notes'] as String?,
    );
  }

  // Copy with modified fields
  Voucher copyWith({
    int? id,
    int? clientId,
    double? amount,
    double? remainingAmount,
    int? pointsUsed,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
    DateTime? usedAt,
    String? code,
    String? notes,
  }) {
    return Voucher(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      amount: amount ?? this.amount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      usedAt: usedAt ?? this.usedAt,
      code: code ?? this.code,
      notes: notes ?? this.notes,
    );
  }

  // Check if voucher is expired
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  // Check if voucher can be used
  bool get canBeUsed => !isUsed && !isExpired && remainingAmount > 0;

  // Get the maximum amount that can be used from this voucher
  double get availableAmount => canBeUsed ? remainingAmount : 0;

  // Apply voucher to an order (returns amount actually used)
  double applyToOrder(double orderTotal) {
    if (!canBeUsed) return 0;

    final amountToUse = min(remainingAmount, orderTotal);
    return amountToUse;
  }

  // Mark voucher as used (or partially used)
  Voucher markAsUsed(double amountUsed, DateTime usedDate) {
    if (amountUsed <= 0 || amountUsed > remainingAmount) {
      throw ArgumentError('Invalid amount used');
    }

    return copyWith(
      remainingAmount: remainingAmount - amountUsed,
      isUsed: (remainingAmount - amountUsed) <= 0,
      usedAt: usedDate,
    );
  }

  @override
  String toString() {
    return 'Voucher #$id (${code ?? 'no code'}) - '
        'Amount: $remainingAmount/$amount DT - '
        'Client: $clientId - '
        '${isUsed ? 'Used' : canBeUsed ? 'Valid' : 'Invalid'}'
        '${expiresAt != null ? ' (Expires: ${DateFormat('yyyy-MM-dd').format(expiresAt!)})' : ''}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Voucher &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          clientId == other.clientId;

  @override
  int get hashCode => id.hashCode ^ clientId.hashCode;
}
