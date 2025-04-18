import 'package:caissechicopets/models/subcategory.dart';

class Category {
  final int? id;
  final String name;
  final String? imagePath;
  final List<SubCategory> subCategories;

  Category({
    this.id,
    required this.name,
    this.imagePath,
    this.subCategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id_category': id,
      'category_name': name,
      'image_path': imagePath,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map,
      {List<SubCategory>? subCategories}) {
    return Category(
      id: map['id_category'] as int?,
      name: (map['category_name'] ?? 'Unnamed Category') as String,
      imagePath: map['image_path'] as String?,
      subCategories: subCategories ?? [],
    );
  }

  @override
  String toString() {
    return 'Category{'
        'id: $id, '
        'name: "$name", '
        'imagePath: ${imagePath != null ? '"$imagePath"' : 'null'}, '
        'subCategories: ${subCategories.length} items'
        '}';
  }
}
