class Voucher {
  final int id;
  final int clientId;
  final double amount;
  final int pointsUsed;
  final DateTime createdAt;
  final bool isUsed;
  final DateTime? usedAt;

  Voucher({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.pointsUsed,
    required this.createdAt,
    required this.isUsed,
    this.usedAt,
  });
}