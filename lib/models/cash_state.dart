// models/cash_state.dart
class CashState {
  final double initialAmount;
  final DateTime? openingTime;
  final DateTime? closingTime;
  final bool isClosed;

  CashState({
    required this.initialAmount,
    this.openingTime,
    this.closingTime,
    this.isClosed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'initialAmount': initialAmount,
      'openingTime': openingTime?.toIso8601String(),
      'closingTime': closingTime?.toIso8601String(),
      'isClosed': isClosed ? 1 : 0,
    };
  }

  factory CashState.fromMap(Map<String, dynamic> map) {
    return CashState(
      initialAmount: map['initialAmount'],
      openingTime: map['openingTime'] != null ? DateTime.parse(map['openingTime']) : null,
      closingTime: map['closingTime'] != null ? DateTime.parse(map['closingTime']) : null,
      isClosed: map['isClosed'] == 1,
    );
  }
}