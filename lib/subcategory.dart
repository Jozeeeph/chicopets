class SubCategory {
  final int? id;
  final String name;
  final int? parentId; // Référence à la sous-catégorie parente
  final int? categoryId; // Référence à la catégorie principale

  SubCategory({
    this.id,
    required this.name,
    this.parentId,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_sub_category': id,
      'sub_category_name': name,
      'parent_id': parentId,
      'category_id': categoryId,
    };
  }

  factory SubCategory.fromMap(Map<String, dynamic> map) {
    return SubCategory(
      id: map['id_sub_category'],
      name: map['sub_category_name'],
      parentId: map['parent_id'],
      categoryId: map['category_id'],
    );
  }
}