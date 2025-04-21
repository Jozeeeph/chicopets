import 'package:caissechicopets/controllers/variantController.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:sqflite/sqflite.dart';

class ProductController {
  Future<List<Product>> getProducts(dbClient) async {
    final List<Map<String, dynamic>> result = await dbClient.rawQuery('''
    SELECT 
      p.*, 
      c.category_name,
      sc.sub_category_name
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id_category
    LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id_sub_category
    WHERE p.is_deleted = 0
    ORDER BY p.designation ASC
  ''');

    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getProductByCode(String code, Database dbClient) async {
    final result = await dbClient.query(
      'products',
      where:
          'code = ? AND is_deleted = 0', // Ajout de la vérification is_deleted
      whereArgs: [code],
      limit: 1, // Optimisation pour ne retourner qu'un seul résultat
    );

    return result.isNotEmpty ? Product.fromMap(result.first) : null;
  }

  Future<Product?> getProductById(int id, Database dbClient) async {
    final result = await dbClient.query(
      'products',
      where: 'id = ? AND is_deleted = 0', // Ajout de la vérification is_deleted
      whereArgs: [id],
      limit: 1, // Optimisation pour ne retourner qu'un seul résultat
    );

    return result.isNotEmpty ? Product.fromMap(result.first) : null;
  }

  Future<Product?> getDesignationByCode(String code, dbClient) async {
    final List<Map<String, Object?>> result = await dbClient.query(
      'products',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1, // Limit the result to 1 row
    );

    if (result.isNotEmpty) {
      // Convert the first row to a Product object
      return Product.fromMap(result.first);
    } else {
      // No product found with the given code
      return null;
    }
  }

  Future<int> updateProductWithoutId(Product product, db) async {
    return await db.update(
      'products',
      {
        'code': product.code,
        'designation': product.designation,
        'description': product.description,
        'stock': product.stock,
        'prix_ht': product.prixHT,
        'taxe': product.taxe,
        'prix_ttc': product.prixTTC,
        'date_expiration': product.dateExpiration,
        'category_id': product.categoryId,
        'sub_category_id': product.subCategoryId,
        'is_deleted': product.isDeleted,
        'marge': product.marge,
        'remise_max': product.remiseMax,
        'remise_valeur_max': product.remiseValeurMax,
        'has_variants': product.hasVariants ? 1 : 0,
        'sellable': product.sellable ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> updateProduct(Product product, dbClient) async {
    return await dbClient.update(
      'products',
      product.toMap(),
      where: 'code = ?',
      whereArgs: [product.code],
    );
  }

  Future<int> deleteProductById(int productId, db) async {
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<Product?> getProductByDesignation(String designation, db) async {
    var result = await db.query(
      'products',
      where: 'designation = ?',
      whereArgs: [designation],
    );
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getProductsWithCategory(dbClient) async {
    return await dbClient.rawQuery('''
    SELECT p.*, c.category_name 
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id_category
  ''');
  }

  Future<int> addProduct(Product product, dbClient) async {
    return await dbClient.transaction((txn) async {
      // Insert product
      final productId = await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert variants if they exist
      if (product.variants.isNotEmpty) {
        for (final variant in product.variants) {
          await txn.insert(
            'variants',
            variant.copyWith(productId: productId).toMap(),
          );
        }

        // Update has_variants flag
        await txn.update(
          'products',
          {'has_variants': 1},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      return productId;
    });
  }

  Future<int> updateProductStock(String productCode, int newStock, db1) async {
    return await db1.update(
      'products',
      {'stock': newStock},
      where: 'code = ?',
      whereArgs: [productCode],
    );
  }

  Future<List<Product>> searchProducts({
    String? category,
    String query = '',
    bool lowStock = false,
    dbClient,
  }) async {
    print(
        "Exécution de la recherche: catégorie=$category, query=$query, lowStock=$lowStock");

    // Début de la requête SQL
    String sqlQuery = '''
    SELECT * FROM products 
    WHERE 1 = 1 
  ''';

    List<dynamic> args = [];

    // Filtrer par catégorie si elle est sélectionnée
    if (category != null && category.isNotEmpty) {
      sqlQuery += " AND category_id = ?";
      args.add(category);
    }

    // Filtrer par code ou désignation (si une recherche est effectuée)
    if (query.isNotEmpty) {
      sqlQuery += " AND (code LIKE ? OR designation LIKE ?)";
      args.add('%$query%');
      args.add('%$query%');
    }

    // Filtrer par stock faible si demandé
    if (lowStock) {
      sqlQuery += " AND stock < 10";
    }

    final List<Map<String, dynamic>> results =
        await dbClient.rawQuery(sqlQuery, args);
    print("Résultats SQL: ${results.length}");

    return results.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product> getProductWithVariants(int productId, dbClient) async {
    final product = await dbClient.query(
      'products',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [productId],
      limit: 1,
    );

    if (product.isEmpty) {
      throw Exception('Produit non trouvé');
    }

    final variants =
        await Variantcontroller().getVariantsByProductId(productId, dbClient);
    return Product.fromMap(product.first)..variants = variants;
  }

  Future<int> updateProductWithVariants(Product product, dbClient) async {
    return await dbClient.transaction((txn) async {
      // Update product
      await txn.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Delete existing variants
      await txn.delete(
        'variants',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );

      // Insert new variants if they exist
      if (product.variants.isNotEmpty) {
        for (final variant in product.variants) {
          await txn.insert(
            'variants',
            variant.copyWith(productId: product.id!).toMap(),
          );
        }
      }

      // Update has_variants flag
      await txn.update(
        'products',
        {'has_variants': product.variants.isNotEmpty ? 1 : 0},
        where: 'id = ?',
        whereArgs: [product.id],
      );

      return 1;
    });
  }

  Future<List<String>> getProductsInCategory(int categoryId, dbClient) async {
    final result = await dbClient.query(
      'products',
      where: 'category_id = ? AND is_deleted = 0',
      whereArgs: [categoryId],
      columns: ['code'],
    );
    return result.map((e) => e['code'] as String).toList();
  }

  Future<List<String>> getProductsInSubCategory(
      int subCategoryId, Database dbClient) async {
    List<String> productCodes = [];

    // 1. Récupère les produits directs de la sous-catégorie
    final directProducts = await dbClient.query(
      'products',
      where: 'sub_category_id = ? AND is_deleted = 0',
      whereArgs: [subCategoryId],
      columns: ['code'],
    );
    productCodes.addAll(directProducts.map((e) => e['code'] as String));

    // 2. Récupère les sous-catégories enfants
    final childSubCategories = await dbClient.query(
      'sub_categories',
      where: 'parent_id = ?',
      whereArgs: [subCategoryId],
    );

    // 3. Récupère récursivement les produits des sous-catégories enfants
    for (final child in childSubCategories) {
      final childId = child['id_sub_category'] as int;
      productCodes.addAll(await getProductsInSubCategory(childId, dbClient));
    }

    return productCodes;
  }

  Future<List<Map<String, dynamic>>> getProductsPurchasedByClient(
    int clientId, Database dbClient) async {
  print('Recherche des produits pour client ID: $clientId');
  
  final results = await dbClient.rawQuery('''
    SELECT 
      p.designation,
      p.code,
      SUM(oi.quantity) as total_quantity,
      SUM(
        CASE 
          WHEN oi.isPercentage = 1 THEN oi.quantity * (oi.prix_unitaire * (1 - oi.discount/100))
          ELSE oi.quantity * (oi.prix_unitaire - oi.discount)
        END
      ) as total_spent,
      AVG(
        CASE 
          WHEN oi.isPercentage = 1 THEN (oi.prix_unitaire * (1 - oi.discount/100))
          ELSE (oi.prix_unitaire - oi.discount)
        END
      ) as average_price
    FROM 
      order_items oi
    JOIN 
      products p ON oi.product_code = p.code
    JOIN 
      orders o ON oi.id_order = o.id_order
    WHERE 
      o.id_client = ?
      AND o.status != 'cancelled'
      AND p.is_deleted = 0
    GROUP BY 
      p.designation, p.code
    ORDER BY 
      total_quantity DESC
  ''', [clientId]);

  print('Résultats trouvés: ${results.length}');
  results.forEach(print); // Affiche chaque résultat
  
  return results;
}
}
