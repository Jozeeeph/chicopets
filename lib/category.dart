import 'package:caissechicopets/subcategory.dart';

class Category {
  int? id;
  String name;
  String imagePath;
  List<SubCategory> subCategories;

  Category({
    this.id,
    required this.name,
    required this.imagePath,
    this.subCategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id_category': id,
      'category_name': name,
      'image_path': imagePath,
      'sub_categories': subCategories.map((sub) => sub.toMap()).toList(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map, {List<SubCategory>? subCategories}) {
    return Category(
      id: map['id_category'],
      name: map['category_name'],
      imagePath: map['image_path'],
      subCategories: subCategories ?? [],
    );
  }
}
