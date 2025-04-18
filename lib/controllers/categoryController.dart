import 'dart:developer';

import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/models/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Categorycontroller {
  Future<String> getCategoryNameById(int id, db) async {
    final result = await db.query(
      'categories',
      where: 'id_category = ?',
      whereArgs: [id],
      columns: ['category_name'],
    );
    if (result.isNotEmpty) {
      return result.first['category_name'] as String;
    }
    return 'Unknown Category';
  }

  Future<List<String>> getProductsInCategory(
      int categoryId, Database dbClient) async {
    try {
      final result = await dbClient.query(
        'products',
        where: 'category_id = ? AND is_deleted = 0',
        whereArgs: [categoryId],
        columns: ['code'],
      );

      // Safely handle null values and convert to String
      return result
          .map((e) => e['code']?.toString() ?? '')
          .where((code) => code.isNotEmpty)
          .toList();
    } catch (e) {
      log('Error getting products in category: $e');
      return [];
    }
  }

  Future<List<Category>> getCategoriesWithSubcategories(db) async {
    try {
      // Get all categories
      final List<Map<String, dynamic>> categoriesData = await db.query(
        'categories',
        where: 'category_name IS NOT NULL',
      );

      List<Category> categories = [];

      for (var categoryData in categoriesData) {
        // Get subcategories for each category
        final List<Map<String, dynamic>> subCategoriesData = await db.query(
          'sub_categories',
          where: 'category_id = ?',
          whereArgs: [categoryData['id_category']],
        );

        categories.add(Category.fromMap(
          categoryData,
          subCategories: subCategoriesData
              .map((subCat) => SubCategory.fromMap(subCat))
              .toList(),
        ));
      }

      return categories;
    } catch (e) {
      debugPrint('Error loading categories: $e');
      return [];
    }
  }

  Future<int> addCategory(String name, String imagePath, dbClient) async {
    return await dbClient.insert(
        'categories', {'category_name': name, 'image_path': imagePath},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCategory(
      int id, String name, String imagePath, dbClient) async {
    return await dbClient.update(
      'categories',
      {'category_name': name, 'image_path': imagePath},
      where: 'id_category = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id, dbClient) async {
    // Vérifier d'abord s'il y a des produits associés
    bool hasProducts = await hasProductsInCategory(id, dbClient);
    if (hasProducts) {
      return -2; // Code spécial pour indiquer qu'il y a des produits
    }

    return await dbClient.delete(
      'categories',
      where: 'id_category = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasProductsInCategory(int categoryId, dbClient) async {
    final result = await dbClient.query(
      'products',
      where: 'category_id = ? AND is_deleted = 0',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Category>> getCategories(Database dbClient) async {
    try {
      // 1. Fetch all categories
      final categoryMaps = await dbClient.query(
        'categories',
        where: 'is_deleted = 0',
        orderBy: 'category_name ASC',
      );

      if (categoryMaps.isEmpty) return [];

      // 2. Fetch all subcategories in one query
      final categoryIds =
          categoryMaps.map((c) => c['id_category'] as int).toList();
      final subCategoryMaps = await dbClient.query(
        'sub_categories',
        where:
            'category_id IN (${List.filled(categoryIds.length, '?').join(',')})',
        whereArgs: categoryIds,
        orderBy: 'sub_category_name ASC',
      );

      // 3. Convert subcategory maps to SubCategory objects
      final subCategories = subCategoryMaps
          .map((map) {
            try {
              return SubCategory.fromMap(map);
            } catch (e) {
              debugPrint('Error converting subcategory: $e');
              return null;
            }
          })
          .whereType<SubCategory>()
          .toList();

      // 4. Group subcategories by category ID
      final subCategoriesByCategory = <int, List<SubCategory>>{};
      for (final subCat in subCategories) {
        subCategoriesByCategory
            .putIfAbsent(subCat.categoryId!, () => [])
            .add(subCat);
      }

      // 5. Build complete category objects
      return categoryMaps.map((categoryMap) {
        final id = categoryMap['id_category'] as int;
        return Category.fromMap(
          categoryMap,
          subCategories: subCategoriesByCategory[id] ?? [],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }
}
