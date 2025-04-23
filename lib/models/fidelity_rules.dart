class FidelityRules {
  double pointsPerDinar; // Ex: 0.1 = 1 point pour 10 dinars
  double dinarPerPoint; // Ex: 1.0 = 1 point = 1 dinar
  int minPointsToUse; // Points minimums pour pouvoir utiliser
  double maxPercentageUse; // Pourcentage max du total payable avec points
  int pointsValidityMonths; // Durée de validité des points

  FidelityRules({
    this.pointsPerDinar = 0.1,
    this.dinarPerPoint = 1.0,
    this.minPointsToUse = 10,
    this.maxPercentageUse = 50.0,
    this.pointsValidityMonths = 12,
  });

  Map<String, dynamic> toMap() {
    return {
      'points_per_dinar': pointsPerDinar,
      'dinar_per_point': dinarPerPoint,
      'min_points_to_use': minPointsToUse,
      'max_percentage_use': maxPercentageUse,
      'points_validity_months': pointsValidityMonths,
    };
  }

  factory FidelityRules.fromMap(Map<String, dynamic> map) {
    return FidelityRules(
      pointsPerDinar: map['points_per_dinar'] ?? 0.1,
      dinarPerPoint: map['dinar_per_point'] ?? 1.0,
      minPointsToUse: map['min_points_to_use'] ?? 10,
      maxPercentageUse: map['max_percentage_use'] ?? 50.0,
      pointsValidityMonths: map['points_validity_months'] ?? 12,
    );
  }
}