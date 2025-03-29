class SubCategory {
  final int? id;
  final String name;
  final int? parentId;
  final int? categoryId;

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
      id: map['id_sub_category'] as int?,
      name: (map['sub_category_name'] ?? 'Unnamed Subcategory') as String,
      parentId: map['parent_id'] as int?,
      categoryId: map['category_id'] as int?,
    );
  }
}
