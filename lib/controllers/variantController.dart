import 'package:caissechicopets/models/variant.dart';
import 'package:sqflite/sqflite.dart';

class Variantcontroller {
  Future<List<Variant>> getVariantsByProductId(int productId, dbClient) async {
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'variants',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    return maps.map(Variant.fromMap).toList();
  }

  Future<int> addVariant(Variant variant, dbClient) async {
    return await dbClient.transaction((txn) async {
      // Verify parent product exists
      final productExists = await txn.query(
        'products',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [variant.productId],
        limit: 1,
      );

      if (productExists.isEmpty) {
        throw Exception('Le produit parent n\'existe pas ou a été supprimé');
      }

      // Verify barcode uniqueness for this product
      if (variant.code.isNotEmpty) {
        final existing = await txn.query(
          'variants',
          where: 'code = ? AND product_id = ?',
          whereArgs: [variant.code, variant.productId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          throw Exception(
              'Un variant avec ce code-barres existe déjà pour ce produit');
        }
      }

      // Insert variant
      final id = await txn.insert(
        'variants',
        variant.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // Update has_variants flag on product
      await txn.update(
        'products',
        {'has_variants': 1},
        where: 'id = ?',
        whereArgs: [variant.productId],
      );

      return id;
    });
  }

  Future<List<Variant>> getVariantsByProductCode(String productCode,dbClient) async {
    // D'abord trouver l'ID du produit
    final product = await dbClient.query('products',
        where: 'code = ?', whereArgs: [productCode], limit: 1);

    if (product.isEmpty) return [];

    final productId = product.first['id'] as int;

    // Puis récupérer les variantes
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'variants',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'combination_name ASC',
    );

    return maps.map((map) => Variant.fromMap(map)).toList();
  }

  Future<int> updateVariant(Variant variant,dbClient) async {
    // Vérifier l'unicité du code-barres
    if (variant.code.isNotEmpty) {
      final existing = await dbClient.query('variants',
          where: 'code = ? AND id != ?',
          whereArgs: [variant.code, variant.id],
          limit: 1);

      if (existing.isNotEmpty) {
        throw Exception('Un variant avec ce code-barres existe déjà');
      }
    }

    return await dbClient.update(
      'variants',
      {
        'code': variant.code,
        'combination_name': variant.combinationName,
        'price': variant.price,
        'price_impact': variant.priceImpact,
        'final_price': variant.finalPrice,
        'stock': variant.stock,
        'attributes': variant.attributes.toString(),
      },
      where: 'id = ?',
      whereArgs: [variant.id],
    );
  }

  Future<int> deleteVariant(int variantId,db) async {
    return await db.delete(
      'variants',
      where: 'id = ?',
      whereArgs: [variantId],
    );
  }

  Future<int> deleteVariantsByProductReferenceId(
      String productReferenceId,dbClient) async {
    return await dbClient.delete(
      'variants',
      where: 'product_reference_id = ?',
      whereArgs: [productReferenceId],
    );
  }
}
