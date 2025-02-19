import 'dart:io';

import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // Added to get the correct database path

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

    // Ensure the directory exists
    if (!Directory(appSupportDir.path).existsSync()) {
      Directory(appSupportDir.path).createSync(recursive: true);
    }

    // Open the database
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        print("Creating tables...");
        await db.execute('''
        CREATE TABLE IF NOT EXISTS products(
          code TEXT PRIMARY KEY,
          designation TEXT,
          stock INTEGER,
          prix_ht REAL,
          taxe REAL,
          prix_ttc REAL,
          date_expiration TEXT,
          category_id INTEGER,
          FOREIGN KEY(category_id) REFERENCES categories(id_category) ON DELETE SET NULL
        )
      ''');
        print("Products table created");

        await db.execute('''
        CREATE TABLE IF NOT EXISTS orders(
          id_order INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          total REAL,
          mode_paiement TEXT,
          id_client INTEGER
        )
      ''');
        print("Orders table created");

        await db.execute('''
        CREATE TABLE IF NOT EXISTS order_items(
          id_order INTEGER,
          product_code TEXT,
          quantity INTEGER,
          prix_unitaire REAL DEFAULT 0,
          FOREIGN KEY(id_order) REFERENCES orders(id_order),
          FOREIGN KEY(product_code) REFERENCES products(code)
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
            category_id INTEGER NOT NULL,
            FOREIGN KEY (category_id) REFERENCES categories (id_category) ON DELETE CASCADE
          )
        ''');
        print("Sub-categories table created");
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
      SELECT p.*, c.category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id_category
    ''');

    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getProductsWithCategory() async {
    final dbClient = await db;
    return await dbClient.rawQuery('''
    SELECT p.*, c.category_name 
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id_category
  ''');
  }

  Future<void> addProduct(
    String code,
    String designation,
    int stock,
    double prixHT,
    double taxe,
    double prixTTC,
    String date,
    int categoryId,
  ) async {
    final dbClient = await db;
    await dbClient.insert(
      'products',
      {
        'code': code,
        'designation': designation,
        'stock': stock,
        'prix_ht': prixHT,
        'taxe': taxe,
        'prix_ttc': prixTTC,
        'date_expiration': date,
        'category_id': categoryId,
      },
      conflictAlgorithm: ConflictAlgorithm
          .replace, // Handle conflicts if the same code is inserted
    );
  }

  Future<int> addOrder(Order order) async {
    final dbClient = await db;
    int orderId = await dbClient.transaction((txn) async {
      // Insert the order into the orders table
      int orderId = await txn.insert(
        'orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert each product in the order into the order_items table
      for (var product in order.orderLines) {
        await txn.insert(
          'order_items',
          {
            'id_order': orderId,
            'product_code': product.idProduct,
            'quantity': product.quantite,
            'prix_unitaire': product.prixUnitaire,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return orderId;
    });

    return orderId;
  }

  Future<List<Order>> getOrdersWithOrderLines() async {
    final db1 = await db;

    // Fetch all orders
    List<Map<String, dynamic>> ordersData = await db1.query("orders");

    List<Order> orders = [];

    for (var orderMap in ordersData) {
      int orderId =
          orderMap['id_order']; // Ensure this matches your table schema
      List<Map<String, dynamic>> orderLinesData = await db1.query(
        "order_items", // Fixed table name
        where: "id_order = ?",
        whereArgs: [orderId],
      );

      List<OrderLine> orderLines = orderLinesData.map((line) {
        return OrderLine(
          idOrder: orderId,
          idProduct: line['product_code'].toString(),
          quantite: (line['quantity'] ?? 1) as int, // Default to 1 if null
          prixUnitaire: (line['prix_unitaire'] ?? 0.0)
              as double, // Default to 0.0 if null
        );
      }).toList();

      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        total: (orderMap['total'] ?? 0.0) as double, // Default to 0.0 if null
        modePaiement:
            orderMap['mode_paiement'] ?? "N/A", // Default value if null
        orderLines: orderLines,
      ));
    }

    return orders;
  }

  Future<Product?> getProductByCode(String productCode) async {
    try {
      var dbC = await db;

      // Query the database to get the product by its code
      List<Map<String, dynamic>> result = await dbC.query(
        'products',
        where: 'code = ?',
        whereArgs: [productCode], // Passing the productCode as a string
      );

      if (result.isNotEmpty) {
        return Product.fromMap(
            result.first); // If found, convert the first result
      } else {
        return null; // Return null if no product found
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

      List<OrderLine> orderLines = []; // Corrected variable

      for (var itemMap in itemMaps) {
        // Fetch the product details
        List<Map<String, dynamic>> productMaps = await dbClient.query(
          'products',
          where: 'code = ?',
          whereArgs: [itemMap['product_code']],
        );

        if (productMaps.isNotEmpty) {
          Product product = Product.fromMap(productMaps.first);

          // Create an OrderLine for each item, pass the correct idProduct
          orderLines.add(OrderLine(
            idOrder: orderId,
            idProduct: itemMap['product_code'], // Pass the product code
            quantite: itemMap['quantity'],
            prixUnitaire: product
                .prixTTC, // Assuming the unit price is the product's TTC price
          ));
        }
      }

      // Create the Order object with the list of OrderLines
      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        orderLines: orderLines, //Assign correct list
        total: orderMap['total'].toDouble(),
        modePaiement: orderMap['mode_paiement'],
        idClient: orderMap['id_client'],
      ));
    }

    return orders;
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

  Future<int> deleteCategory(int id) async {
    final dbClient = await db;
    return await dbClient.delete(
      'categories',
      where: 'id_category = ?',
      whereArgs: [id],
    );
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
  Future<List<SubCategory>> getSubCategories(int categoryId) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'sub_categories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
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
}