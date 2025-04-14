import 'dart:convert';
import 'dart:io';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/client.dart';
import 'package:caissechicopets/user.dart';
import 'package:caissechicopets/variant.dart';
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Added to get the correct database path

class SqlDb {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    // Get the application support directory for storing the database
    final appSupportDir = await getApplicationSupportDirectory();
    final dbPath = join(appSupportDir.path, 'cashdesk1.db');
//await deleteDatabase(dbPath);

    // Ensure the directory exists
    if (!Directory(appSupportDir.path).existsSync()) {
      Directory(appSupportDir.path).createSync(recursive: true);
    }

    // Open the databases
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        print("Creating tables...");
        await db.execute('''
  CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    designation TEXT,
    description TEXT,
    stock INTEGER,
    prix_ht REAL,
    taxe REAL,
    prix_ttc REAL,
    date_expiration TEXT,
    category_id INTEGER,
    sub_category_id INTEGER,
    category_name TEXT,
    sub_category_name TEXT,
    is_deleted INTEGER DEFAULT 0,
    marge REAL,
    remise_max REAL DEFAULT 0.0, -- Nouvel attribut pour la remise maximale en pourcentage
    remise_valeur_max REAL DEFAULT 0.0, -- Nouvel attribut pour la valeur maximale de la remise
    has_variants INTEGER DEFAULT 0,
    sellable INTEGER DEFAULT 1
);
''');
        print("Products table created");

        await db.execute('''
        CREATE TABLE IF NOT EXISTS orders(
  id_order INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT,
  total REAL,
  mode_paiement TEXT,
  status TEXT,
  remaining_amount REAL,
  id_client INTEGER,
  global_discount REAL DEFAULT 0.0,
  is_percentage_discount INTEGER DEFAULT 1 -- 1 for true (percentage), 0 for false (fixed value)
);
      ''');
        print("Orders table created");

        await db.execute('''
  CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT, -- Clé primaire auto-incrémentée
    id_order INTEGER NOT NULL,
    product_code TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    prix_unitaire REAL DEFAULT 0 NOT NULL,
    discount REAL NOT NULL,
    isPercentage INTEGER NOT NULL CHECK(isPercentage IN (0,1)), -- Booléen sécurisé
    FOREIGN KEY (id_order) REFERENCES orders(id_order) ON DELETE CASCADE,
    FOREIGN KEY (product_code) REFERENCES products(code) ON DELETE CASCADE
  )
''');

        print("Order items table created");

        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id_category INTEGER PRIMARY KEY AUTOINCREMENT,
            category_name TEXT NOT NULL,
            image_path TEXT
          )
        ''');
        print("Categories table created");

        await db.execute('''
          CREATE TABLE IF NOT EXISTS sub_categories (
            id_sub_category INTEGER PRIMARY KEY AUTOINCREMENT,
            sub_category_name TEXT NOT NULL,
            parent_id INTEGER,
            category_id INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES sub_categories (id_sub_category) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories (id_category) ON DELETE CASCADE
          )
        ''');
        print("Sub-categories table created");

        await db.execute('''
  CREATE TABLE variants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  combination_name TEXT NOT NULL,
  price REAL NOT NULL,
  price_impact REAL NOT NULL,
  final_price REAL NOT NULL,
  stock INTEGER NOT NULL,
  default_variant INTEGER DEFAULT 0,
  attributes TEXT NOT NULL,
  product_id INTEGER NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
''');
        print("Variants table created");

        await db.execute('''
  CREATE TABLE IF NOT EXISTS gallery_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    image_path TEXT NOT NULL,
    name TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');
        print("Gallery images table created");

        await db.execute('''
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL,
    role TEXT NOT NULL, -- 'admin' ou 'cashier'
    is_active INTEGER DEFAULT 1
  )
''');
        print("Users table created");
        await db.execute('''
  CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    phone_number TEXT NOT NULL UNIQUE,
    loyalty_points INTEGER DEFAULT 0,
    id_orders TEXT DEFAULT '' -- Stocke les IDs de commandes séparés par des virgules
  )
''');
        print("Clients table created");
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS orders(
            id_order INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total REAL,
            mode_paiement TEXT,
            id_client INTEGER
          )
        ''');
        }
      },
    );
  }

  Future<List<Product>> getProducts() async {
    final dbClient = await db;
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

  Future<void> updateOrderStatus(int idOrder, String status) async {
    final dbClient = await db;
    await dbClient.update(
      'orders',
      {'status': status},
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<int> updateProductWithoutId(Product product) async {
    final db = await this.db;
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

  Future<int> updateProduct(Product product) async {
    final dbClient = await db;
    return await dbClient.update(
      'products',
      product.toMap(),
      where: 'code = ?', // Assuming 'code' is unique for the product
      whereArgs: [product.code], // Using 'code' to identify the product
    );
  }

  Future<int> deleteProduct(String productCode) async {
    final dbClient = await db;
    return await dbClient.update(
      'products',
      {'is_deleted': 1},
      where: 'code = ?',
      whereArgs: [productCode],
    );
  }

  Future<void> deleteOrderLine(int idOrder, String idProduct) async {
    final dbClient = await db;
    await dbClient.delete(
      'order_items',
      where: 'id_order = ? AND product_code = ?',
      whereArgs: [idOrder, idProduct],
    );
  }

  Future<List<Map<String, dynamic>>> getProductsWithCategory() async {
    final dbClient = await db;
    return await dbClient.rawQuery('''
    SELECT p.*, c.category_name 
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id_category
  ''');
  }

  Future<int> addProduct(Product product) async {
    final dbClient = await db;
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

  Future<int> addOrder(Order order) async {
    final dbClient = await db;

    // Insert the order details into the 'orders' table
    int orderId = await dbClient.insert(
      'orders',
      {
        'date': order.date,
        'total': order.total,
        'mode_paiement': order.modePaiement,
        'status': order.status,
        'remaining_amount': order.remainingAmount,
        'id_client': order.idClient,
        'global_discount': order.globalDiscount,
        'is_percentage_discount':
            order.isPercentageDiscount ? 1 : 0, // Added field
      },
    );

    // Insert each order line into the 'order_items' table
    for (var orderLine in order.orderLines) {
      await dbClient.insert(
        'order_items',
        {
          'id_order': orderId,
          'product_code': orderLine.idProduct,
          'quantity': orderLine.quantite,
          'prix_unitaire': orderLine.prixUnitaire,
          'discount': orderLine.discount,
          'isPercentage':
              orderLine.isPercentage ? 1 : 0, // Convert bool to int (1 or 0)
        },
      );
    }

    return orderId;
  }

  Future<Map<String, Map<String, dynamic>>> getSalesByCategoryAndProduct({
    String? dateFilter,
  }) async {
    final db = await this.db;
    final salesData = <String, Map<String, dynamic>>{};

    try {
      String query = '''
    SELECT 
      COALESCE(p.category_name, c.category_name, 'Uncategorized') AS category_name,
      p.designation AS product_name,
      SUM(oi.quantity) AS total_quantity,
      SUM(
        CASE 
          WHEN oi.isPercentage = 1 THEN oi.quantity * (oi.prix_unitaire * (1 - oi.discount/100))
          ELSE oi.quantity * (oi.prix_unitaire - oi.discount)
        END
      ) AS total_sales,
      AVG(oi.discount) AS avg_discount,
      AVG(CASE WHEN oi.isPercentage = 1 THEN 1 ELSE 0 END) AS is_percentage_discount
    FROM 
      order_items oi
    JOIN 
      products p ON oi.product_code = p.code
    LEFT JOIN
      categories c ON p.category_id = c.id_category
    JOIN 
      orders o ON oi.id_order = o.id_order
    WHERE 
      o.status IN ('completed', 'paid', 'semi-payée')
      AND p.is_deleted = 0
    ''';

      // Add date filter if provided
      if (dateFilter != null && dateFilter.isNotEmpty) {
        query += ' $dateFilter';
      }

      query += '''
    GROUP BY 
      COALESCE(p.category_name, c.category_name, 'Uncategorized'), p.designation
    ORDER BY 
      category_name, total_sales DESC
    ''';

      final result = await db.rawQuery(query);
      print('Query result: $result');

      // Process the results
      for (final row in result) {
        final category = row['category_name']?.toString() ?? 'Uncategorized';
        final productName =
            row['product_name']?.toString() ?? 'Unknown Product';
        final quantity = row['total_quantity'] as int? ?? 0;
        final total = row['total_sales'] as double? ?? 0.0;
        final discount = row['avg_discount'] as double? ?? 0.0;
        final isPercentage =
            (row['is_percentage_discount'] as num?)?.toDouble() ?? 0.0 > 0.5;

        // Initialize category if not exists
        salesData.putIfAbsent(
            category,
            () => {
                  'products': <String, dynamic>{},
                  'total': 0.0,
                });

        // Add product to category
        salesData[category]!['products'][productName] = {
          'quantity': quantity,
          'total': total,
          'discount': discount,
          'isPercentage': isPercentage,
        };

        // Update category total
        salesData[category]!['total'] =
            (salesData[category]!['total'] as double) + total;
      }

      return salesData;
    } catch (e) {
      print('Error getting sales by category and product: $e');
      return {};
    }
  }

  Future<List<Order>> getOrdersWithOrderLines() async {
    final db1 = await db;

    // Fetch all orders
    List<Map<String, dynamic>> ordersData = await db1.query("orders");

    List<Order> orders = [];

    for (var orderMap in ordersData) {
      int orderId = orderMap['id_order'];
      double total = (orderMap['total'] ?? 0.0) as double;
      double remaining = (orderMap['remaining_amount'] ?? 0.0) as double;
      double globalDiscount = (orderMap['global_discount'] ?? 0.0) as double;
      bool isPercentageDiscount =
          (orderMap['is_percentage_discount'] as int?) == 1;
      int? idClient = orderMap['id_client'] as int?; // Récupérez l'ID client

      List<Map<String, dynamic>> orderLinesData = await db1.query(
        "order_items",
        where: "id_order = ?",
        whereArgs: [orderId],
      );

      List<OrderLine> orderLines = orderLinesData.map((line) {
        return OrderLine(
          idOrder: orderId,
          idProduct: line['product_code'].toString(),
          quantite: (line['quantity'] ?? 1) as int,
          prixUnitaire: (line['prix_unitaire'] ?? 0.0) as double,
          discount: (line['discount'] ?? 0.0) as double,
          isPercentage: (line['isPercentage'] as int?) == 1,
        );
      }).toList();

      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        total: total,
        modePaiement: orderMap['mode_paiement'] ?? "N/A",
        status: orderMap['status'],
        orderLines: orderLines,
        remainingAmount: remaining,
        globalDiscount: globalDiscount,
        isPercentageDiscount: isPercentageDiscount,
        idClient: idClient, // Passez l'ID client ici
      ));
    }

    return orders;
  }

  Future<int> updateProductStock(String productCode, int newStock) async {
    final db1 = await db;
    return await db1.update(
      'products', // Table name
      {'stock': newStock}, // Update stock column
      where: 'code = ?', // Condition
      whereArgs: [productCode], // Pass product code
    );
  }

  Future<Product?> getProductByCode(String productCode) async {
    try {
      var dbC = await db;

      List<Map<String, dynamic>> result = await dbC.query(
        'products',
        where: 'code = ?',
        whereArgs: [productCode],
      );

      if (result.isNotEmpty) {
        return Product.fromMap(result.first);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching product by code: $e');
      return null;
    }
  }

  Future<List<Order>> getOrders() async {
    final dbClient = await db;
    List<Map<String, dynamic>> orderMaps = await dbClient.query('orders');

    List<Order> orders = [];
    for (var orderMap in orderMaps) {
      int orderId = orderMap['id_order'];

      // Fetch order lines from order_items
      List<Map<String, dynamic>> itemMaps = await dbClient.query(
        'order_items',
        where: 'id_order = ?',
        whereArgs: [orderId],
      );

      List<OrderLine> orderLines = [];

      for (var itemMap in itemMaps) {
        // Fetch the product details
        List<Map<String, dynamic>> productMaps = await dbClient.query(
          'products',
          where: 'code = ?',
          whereArgs: [itemMap['product_code']],
        );

        if (productMaps.isNotEmpty) {
          Product product = Product.fromMap(productMaps.first);

          // Create an OrderLine for each item, including isPercentage
          orderLines.add(OrderLine(
            idOrder: orderId,
            idProduct: itemMap['product_code'],
            quantite: itemMap['quantity'] ?? 1, // Default to 1 if null
            prixUnitaire: product.prixTTC, // TTC price from product
            discount: (itemMap['discount'] ?? 0.0).toDouble(), // Ensure double
            isPercentage:
                (itemMap['isPercentage'] ?? 1) == 1, // Convert 0/1 to bool
          ));
        }
      }

      // Create the Order object with the list of OrderLines
      orders.add(Order(
          idOrder: orderId,
          date: orderMap['date'],
          orderLines: orderLines,
          total: (orderMap['total'] ?? 0.0).toDouble(), // Ensure double
          modePaiement: orderMap['mode_paiement'] ?? "N/A",
          status: orderMap['status'] ?? "Pending",
          idClient: orderMap['id_client'],
          globalDiscount: orderMap['global_discount'].toDouble(),
          isPercentageDiscount: orderMap['is_percentage_discount']));
    }

    return orders;
  }

  Future<void> cancelOrderLine(int idOrder, String idProduct) async {
    final dbClient = await db;
    await dbClient.delete(
      'order_items',
      where: 'id_order = ? AND product_code = ?',
      whereArgs: [idOrder, idProduct],
    );
  }

  Future<void> deleteOrder(int idOrder) async {
    final dbClient = await db;
    await dbClient.delete(
      'orders',
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<int> cancelOrder(int idOrder) async {
    final dbClient = await db;

    // Update the status of the order to "Annulée"
    return await dbClient.update(
      'orders',
      {'status': 'Annulée'},
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  // In your sqldb class
  Future<String> getCategoryNameById(int id) async {
    final db = await this.db;
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

  Future<String> getSubCategoryNameById(int id) async {
    final db = await this.db;
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

  Future<Product?> getDesignationByCode(String code) async {
    final dbClient = await db;
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

  Future<int> addCategory(String name, String imagePath) async {
    final dbClient = await db;
    return await dbClient.insert(
        'categories', {'category_name': name, 'image_path': imagePath},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCategory(int id, String name, String imagePath) async {
    final dbClient = await db;
    return await dbClient.update(
      'categories',
      {'category_name': name, 'image_path': imagePath},
      where: 'id_category = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateOrderInDatabase(Order order) async {
    final dbClient = await db;
    try {
      // Update the order in the database with the new remaining amount and status
      await dbClient.update(
        'orders', // Table name
        {
          'remaining_amount': order.remainingAmount,
          'status': order.status,
        },
        where: 'id_order = ?',
        whereArgs: [order.idOrder], // The ID of the order to update
      );
    } catch (e) {
      // Handle any errors during the update
      print('Error updating order: $e');
      throw Exception('Error updating order');
    }
  }

  Future<int> deleteCategory(int id) async {
    final dbClient = await db;

    // Vérifier d'abord s'il y a des produits associés
    bool hasProducts = await hasProductsInCategory(id);
    if (hasProducts) {
      return -2; // Code spécial pour indiquer qu'il y a des produits
    }

    return await dbClient.delete(
      'categories',
      where: 'id_category = ?',
      whereArgs: [id],
    );
  }

  Future<List<Product>> searchProducts(
      {String? category, required String query}) async {
    final dbClient = await db;
    print("Exécution de la recherche: catégorie=$category, query=$query");

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

    final List<Map<String, dynamic>> results =
        await dbClient.rawQuery(sqlQuery, args);
    print("Résultats SQL: ${results.length}");

    return results.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Category>> getCategories() async {
    final dbClient = await db;
    // Fetch categories as maps from the 'categories' table
    var categoryMaps = await dbClient.query('categories');
    print(
        'Fetched categories: $categoryMaps'); // Debugging: Check the fetched categories
    // Create a list to store the categories
    List<Category> categories = [];
    // Iterate over each category and fetch its subcategories
    for (var categoryMap in categoryMaps) {
      // Fetch subcategories for the current category
      var subCategoryMaps = await dbClient.query(
        'sub_categories',
        where: 'category_id = ?',
        whereArgs: [
          categoryMap['id_category']
        ], // Ensure this is the correct field
      );
      // Map the subcategories into SubCategory objects
      List<SubCategory> subCategories = subCategoryMaps
          .map((subCategoryMap) => SubCategory.fromMap(subCategoryMap))
          .toList();
      // Map the category from map to a Category object, passing the subcategories
      Category category =
          Category.fromMap(categoryMap, subCategories: subCategories);
      // Add the category to the list
      categories.add(category);
    }
    return categories;
  }

  /// **Créer une sous-catégorie**
  Future<int> addSubCategory(SubCategory subCategory) async {
    try {
      final dbClient = await db;
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

  /// **Lire toutes les sous-catégories d'une catégorie spécifique**
  Future<List<SubCategory>> getSubCategories(int categoryId,
      {int? parentId}) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'sub_categories',
      where: 'category_id = ? AND parent_id = ?',
      whereArgs: [categoryId, parentId],
    );
    return List.generate(maps.length, (i) => SubCategory.fromMap(maps[i]));
  }

  /// **Mettre à jour une sous-catégorie**
  Future<int> updateSubCategory(SubCategory subCategory) async {
    final dbClient = await db;
    return await dbClient.update(
      'sub_categories',
      subCategory.toMap(),
      where: 'id_sub_category = ?',
      whereArgs: [subCategory.id],
    );
  }

  /// **Supprimer une sous-catégorie**
  Future<int> deleteSubCategory(int subCategoryId) async {
    final dbClient = await db;

    // Vérifier d'abord s'il y a des produits associés (directement ou indirectement)
    bool hasProducts = await hasProductsInSubCategory(subCategoryId);
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

  /// **Lire toutes les sous-catégories (sans filtrer par catégorie)**
  Future<List<SubCategory>> getAllSubCategories() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps =
        await dbClient.query('sub_categories');
    return List.generate(maps.length, (i) => SubCategory.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getSubCategoriesByCategory(
      int categoryId) async {
    final dbClient = await db;
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

  // Fetch categories with their subcategories
  Future<List<Category>> getCategoriesWithSubcategories() async {
    final db = await this.db;
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

  // Fetch subcategory by id and category_id
  Future<List<Map<String, dynamic>>> getSubCategoryById(
      int subCategoryId, int categoryId) async {
    final dbClient = await db;
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

  Future<int> addVariant(Variant variant) async {
    final dbClient = await db;
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

  Future<List<Variant>> getVariantsByProductCode(String productCode) async {
    final dbClient = await db;

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

  Future<List<Variant>> getVariantsByProductId(int productId) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'variants',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    return maps.map(Variant.fromMap).toList();
  }

  Future<int> updateVariant(Variant variant) async {
    final dbClient = await db;

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

  Future<int> deleteVariant(String variantCode) async {
    final dbClient = await db;
    return await dbClient.delete(
      'variants',
      where: 'code = ?',
      whereArgs: [variantCode],
    );
  }

  Future<int> deleteVariantsByProductReferenceId(
      String productReferenceId) async {
    final dbClient = await db;
    return await dbClient.delete(
      'variants',
      where: 'product_reference_id = ?',
      whereArgs: [productReferenceId],
    );
  }

  // Méthode pour insérer une image dans la base de données
  Future<int> insertImage(String imagePath, String name) async {
    final dbClient = await db;
    return await dbClient.insert(
      'gallery_images',
      {'image_path': imagePath, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> searchImagesByName(String name) async {
    final dbClient = await db;
    return await dbClient.query(
      'gallery_images',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
    );
  }

// Méthode pour récupérer toutes les images de la galerie
  Future<List<Map<String, dynamic>>> getGalleryImages() async {
    final dbClient = await db;
    return await dbClient.query('gallery_images');
  }

// Méthode pour supprimer une image de la galerie
  Future<int> deleteImage(int id) async {
    final dbClient = await db;
    return await dbClient.delete(
      'gallery_images',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateImageName(int id, String name) async {
    final dbClient = await db;
    return await dbClient.update(
      'gallery_images',
      {'name': name}, // Mettre à jour le nom de l'image
      where: 'id = ?', // Condition : l'ID de l'image
      whereArgs: [id], // Passer l'ID de l'image
    );
  }

  Future<bool> hasProductsInCategory(int categoryId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'products',
      where: 'category_id = ? AND is_deleted = 0',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

// Vérifie si une sous-catégorie a des produits associés
  Future<bool> hasProductsInSubCategory(int subCategoryId) async {
    final dbClient = await db;

    // Vérifier les produits directement assignés
    final directProducts = await dbClient.query(
      'products',
      where: 'sub_category_id = ? AND is_deleted = 0',
      whereArgs: [subCategoryId],
      limit: 1,
    );

    if (directProducts.isNotEmpty) {
      return true;
    }

    // Vérifier les sous-catégories enfants
    final childSubCategories = await dbClient.query(
      'sub_categories',
      where: 'parent_id = ?',
      whereArgs: [subCategoryId],
    );

    // Vérifier récursivement chaque sous-catégorie enfant
    for (var child in childSubCategories) {
      bool hasProducts =
          await hasProductsInSubCategory(child['id_sub_category'] as int);
      if (hasProducts) {
        return true;
      }
    }

    return false;
  }

  Future<Product> getProductWithVariants(int productId) async {
    final dbClient = await db;
    final product = await dbClient.query(
      'products',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [productId],
      limit: 1,
    );

    if (product.isEmpty) {
      throw Exception('Produit non trouvé');
    }

    final variants = await getVariantsByProductId(productId);
    return Product.fromMap(product.first)..variants = variants;
  }

  Future<int> updateProductWithVariants(Product product) async {
    final dbClient = await db;
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

// Récupère les IDs des produits associés à une catégorie
  Future<List<String>> getProductsInCategory(int categoryId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'products',
      where: 'category_id = ? AND is_deleted = 0',
      whereArgs: [categoryId],
      columns: ['code'],
    );
    return result.map((e) => e['code'] as String).toList();
  }

// Récupère les IDs des produits associés à une sous-catégorie (récursivement)
  Future<List<String>> getProductsInSubCategory(int subCategoryId) async {
    final dbClient = await db;
    List<String> productCodes = [];

    // Produits directs
    final directProducts = await dbClient.query(
      'products',
      where: 'sub_category_id = ? AND is_deleted = 0',
      whereArgs: [subCategoryId],
      columns: ['code'],
    );
    productCodes.addAll(directProducts.map((e) => e['code'] as String));

    // Sous-catégories enfants
    final childSubCategories = await dbClient.query(
      'sub_categories',
      where: 'parent_id = ?',
      whereArgs: [subCategoryId],
    );

    // Produits des enfants (récursivement)
    for (var child in childSubCategories) {
      productCodes.addAll(
          await getProductsInSubCategory(child['id_sub_category'] as int));
    }

    return productCodes;
  }

  // Méthodes pour gérer les utilisateurs
  Future<int> addUser(User user) async {
    final dbClient = await db;
    return await dbClient.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<User?> getUserByUsername(String username) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> result = await dbClient.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<List<User>> getAllUsers() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> result = await dbClient.query('users');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<bool> hasAdminAccount() async {
    final dbClient = await db;
    final count = Sqflite.firstIntValue(
      await dbClient
          .rawQuery('SELECT COUNT(*) FROM users WHERE role = "admin"'),
    );
    return count != null && count > 0;
  }

  Future<bool> verifyCode(String code) async {
    final dbClient = await db;
    final count = Sqflite.firstIntValue(
      await dbClient
          .rawQuery('SELECT COUNT(*) FROM users WHERE code = ?', [code]),
    );
    return count != null && count > 0;
  }

  Future<User?> getUserByCode(String code) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> result = await dbClient.query(
      'users',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<int> updateUserCode(String username, String newCode) async {
    final dbClient = await db;
    return await dbClient.update(
      'users',
      {'code': newCode},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  Future<int> deleteUser(int userId) async {
    final dbClient = await db;
    return await dbClient.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> addClient(Client client) async {
    final dbClient = await db;
    try {
      int id = await dbClient.insert(
        'clients',
        client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Client ajouté avec ID: $id'); // Debug
      return id;
    } catch (e) {
      print('Erreur lors de l\'ajout du client: $e');
      return -1; // Retourne -1 en cas d'erreur
    }
  }

  Future<List<Client>> getAllClients() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query('clients');
    print('Clients from DB: $maps'); // Debug
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  Future<Client?> getClientById(int id) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> result = await dbClient.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? Client.fromMap(result.first) : null;
  }

  Future<int> updateClient(Client client) async {
    final dbClient = await db;
    return await dbClient.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<int> deleteClient(int id) async {
    final dbClient = await db;
    return await dbClient.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Client>> searchClients(String query) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> result = await dbClient.query(
      'clients',
      where: 'name LIKE ? OR first_name LIKE ? OR phone_number LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return result.map((map) => Client.fromMap(map)).toList();
  }

  Future<void> addOrderToClient(int clientId, int orderId) async {
    final dbClient = await db;
    print('Adding order $orderId to client $clientId'); // Debug

    // Méthode 1: Mettre à jour la liste des commandes du client
    final client = await getClientById(clientId);
    if (client != null) {
      client.idOrders.add(orderId);
      await dbClient.update(
        'clients',
        {'id_orders': client.idOrders.join(',')},
        where: 'id = ?',
        whereArgs: [clientId],
      );
      print('Updated client orders: ${client.idOrders}'); // Debug
    }

    // Méthode 2: Alternative plus simple
    await dbClient.update(
      'orders',
      {'id_client': clientId},
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    print('Updated order with client ID'); // Debug
  }

  Future<void> debugCheckOrder(int orderId) async {
    final dbClient = await db;
    final order = await dbClient.query(
      'orders',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    print('Order from DB: ${order.first}');

    if (order.first['id_client'] != null) {
      final client = await dbClient.query(
        'clients',
        where: 'id = ?',
        whereArgs: [order.first['id_client']],
      );
      print('Associated client: ${client.isNotEmpty ? client.first : 'None'}');
    }
  }
}
