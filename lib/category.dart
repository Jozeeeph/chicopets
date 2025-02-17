import 'dart:io';
import 'package:flutter/material.dart';

class Category {
  int? id;
  String name;
  String imagePath;

  Category({this.id, required this.name, required this.imagePath});

  Map<String, dynamic> toMap() {
    return {
      'id_category': id,
      'category_name': name,
      'image_path': imagePath,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
  print('Mapping category: ${map['category_name']}'); // Debugging line
  return Category(
    id: map['id_category'],
    name: map['category_name'],
    imagePath: map['image_path'],
  );
}


}