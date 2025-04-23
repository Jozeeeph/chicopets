class Attribut {
  int? id;
  final String name;
  final Set<String> values;

  Attribut({this.id, required this.name, Set<String>? values})
      : values = values ?? <String>{};

  void addValue(String value) {
    values.add(value);
  }

  // Convert to map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'attributs_values': values.join(','), // Store values as comma-separated string
    };
  }

  Attribut copyWith({
    int? id,
    String? name,
    Set<String>? values,
  }) {
    return Attribut(
      id: id ?? this.id,
      name: name ?? this.name,
      values: values ?? Set.from(this.values),
    );
  }

  // Create from database map
  factory Attribut.fromMap(Map<String, dynamic> map) {
    return Attribut(
      id: map['id'],
      name: map['name'],
      values: (map['attributs_values'] as String).split(',').toSet(),
    );
  }

  @override
  String toString() {
    return '$name: ${values.join(', ')}';
  }
}
