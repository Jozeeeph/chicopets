import 'package:caissechicopets/models/subcategory.dart';
import 'package:sqflite/sqflite.dart';

class Subcategorycontroller {
  Future<String> getSubCategoryNameById(int id, db) async {
    final result = await db.query(
      'sub_categories',
      where: 'id_sub_category = ?',
      whereArgs: [id],
      columns: ['sub_category_name'],
    );
    if (result.isNotEmpty) {
      return result.first['sub_category_name'] as String;
    }
    return 'Unknown Sub-Category';
  }

  Future<int> addSubCategory(SubCategory subCategory, dbClient) async {
    try {
      return await dbClient.insert(
        'sub_categories',
        subCategory.toMap(),
        conflictAlgorithm:
            ConflictAlgorithm.replace, // Évite les conflits d'insertion
      );
    } catch (e) {
      print("Erreur lors de l'ajout de la sous-catégorie: $e");
      return -1; // Retourne une valeur négative en cas d'échec
    }
  }

  Future<List<SubCategory>> getSubCategories(int categoryId, dbClient,
      {int? parentId}) async {
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'sub_categories',
      where: 'category_id = ? AND parent_id = ?',
      whereArgs: [categoryId, parentId],
    );
    return List.generate(maps.length, (i) => SubCategory.fromMap(maps[i]));
  }

  Future<int> updateSubCategory(SubCategory subCategory, dbClient) async {
    return await dbClient.update(
      'sub_categories',
      subCategory.toMap(),
      where: 'id_sub_category = ?',
      whereArgs: [subCategory.id],
    );
  }

  Future<int> deleteSubCategory(int subCategoryId, dbClient) async {
    // Vérifier d'abord s'il y a des produits associés (directement ou indirectement)
    bool hasProducts = await hasProductsInSubCategory(subCategoryId, dbClient);
    if (hasProducts) {
      return -2; // Code spécial pour indiquer qu'il y a des produits
    }

    // Si c'est une sous-catégorie parente, déplacer ses enfants au niveau supérieur
    await dbClient.update(
      'sub_categories',
      {'parent_id': null},
      where: 'parent_id = ?',
      whereArgs: [subCategoryId],
    );

    return await dbClient.delete(
      'sub_categories',
      where: 'id_sub_category = ?',
      whereArgs: [subCategoryId],
    );
  }

  Future<bool> hasProductsInSubCategory(
      int subCategoryId, Database dbClient) async {
    try {
      // Check direct products first
      if (await _hasDirectProducts(subCategoryId, dbClient)) {
        return true;
      }

      // Check child subcategories recursively
      return await _hasProductsInChildSubCategories(subCategoryId, dbClient);
    } catch (e) {
      print('Error checking products in subcategory: $e');
      return true; // Fail-safe - assume there are products to prevent accidental deletion
    }
  }

  Future<bool> _hasDirectProducts(int subCategoryId, Database dbClient) async {
    final result = await dbClient.rawQuery(
      '''
      SELECT EXISTS(
        SELECT 1 FROM products 
        WHERE sub_category_id = ? AND is_deleted = 0
        LIMIT 1
      ) as has_products
      ''',
      [subCategoryId],
    );
    return result.first['has_products'] == 1;
  }

  Future<bool> _hasProductsInChildSubCategories(
      int parentId, Database dbClient) async {
    final children = await dbClient.query(
      'sub_categories',
      where: 'parent_id = ? AND is_deleted = 0',
      whereArgs: [parentId],
    );

    for (final child in children) {
      final childId = child['id_sub_category'] as int;
      // Check direct products for this child
      if (await _hasDirectProducts(childId, dbClient)) {
        return true;
      }
      // Check recursively for grandchildren
      if (await _hasProductsInChildSubCategories(childId, dbClient)) {
        return true;
      }
    }

    return false;
  }

  Future<List<SubCategory>> getAllSubCategories(dbClient) async {
    final List<Map<String, dynamic>> maps =
        await dbClient.query('sub_categories');
    return List.generate(maps.length, (i) => SubCategory.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getSubCategoriesByCategory(
      int categoryId, dbClient) async {
    try {
      var result = await dbClient.query(
        'sub_categories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      print('Subcategories fetched: $result'); // Debugging print
      return result;
    } catch (e) {
      print("Error fetching subcategories from database: $e");
      return [];
    }
  }

  // Fetch subcategory by id and category_id
  Future<List<Map<String, dynamic>>> getSubCategoryById(
      int subCategoryId, dbClient, int categoryId) async {
    try {
      List<Map<String, dynamic>> result = await dbClient.query(
        'sub_categories',
        where: 'id_sub_category = ? AND category_id = ?',
        whereArgs: [subCategoryId, categoryId],
      );

      return result;
    } catch (e) {
      print('Error fetching subcategory: $e');
      return [];
    }
  }
}
