class SubCategory {
  final int? id;
  final String name;
  final int categoryId;  // The ID of the parent category

  SubCategory({this.id, required this.name, required this.categoryId});

  Map<String, dynamic> toMap() {
    return {
      'id_sub_category': id,
      'sub_category_name': name,
      'category_id': categoryId, // Store the parent category ID
    };
  }

  factory SubCategory.fromMap(Map<String, dynamic> map) {
    return SubCategory(
      id: map['id_sub_category'],
      name: map['sub_category_name'],
      categoryId: map['category_id'], // Extract the parent category ID
    );
  }
}
