import 'dart:io';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/variant.dart';
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/subcategory.dart';
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
    await deleteDatabase(dbPath);

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
    code TEXT PRIMARY KEY,
    designation TEXT,
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
    product_reference_id TEXT, -- Now it's not UNIQUE
    remise_max REAL DEFAULT 0.0, -- Nouvel attribut pour la remise maximale en pourcentage
    remise_valeur_max REAL DEFAULT 0.0 -- Nouvel attribut pour la valeur maximale de la remise
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
  CREATE TABLE IF NOT EXISTS variants (
    code TEXT PRIMARY KEY,
    combination_name TEXT,
    price REAL,
    price_impact REAL,
    final_price REAL,
    stock INTEGER,
    attributes TEXT,
    product_reference_id TEXT,
    FOREIGN KEY(product_reference_id) REFERENCES products(product_reference_id) ON DELETE CASCADE
);
''');
        print("Variants table created");

        await db.execute('''
  CREATE TABLE IF NOT EXISTS gallery_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    image_path TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');
        print("Gallery images table created");
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
    WHERE p.is_deleted = 0
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

  // Ajoutez ces méthodes dans la classe SqlDb

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

  Future<void> addProduct(
    String code,
    String designation,
    int stock,
    double prixHT,
    double taxe,
    double prixTTC,
    String date,
    int categoryId,
    int subCategoryId,
    double marge,
    String productReferenceId,
    double remiseMax, // Ajout de remiseMax
    double remiseValeurMax, // Ajout de remiseValeurMax
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
        'sub_category_id': subCategoryId,
        'marge': marge,
        'product_reference_id': productReferenceId,
        'remise_max': remiseMax, // Ajout dans la base
        'remise_valeur_max': remiseValeurMax, // Ajout dans la base
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
          (orderMap['is_percentage_discount'] as int?) == 1; // Fix here

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
          isPercentage: (line['isPercentage'] as int?) == 1, // Fix here
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
        isPercentageDiscount: isPercentageDiscount, // Fix here
        idClient: orderMap['id_client'],
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
    final dbClient = await db;

    List<Map<String, dynamic>> results = await dbClient.rawQuery('''
    SELECT 
      c.id_category, c.category_name, c.image_path,
      s.id_sub_category, s.sub_category_name
    FROM categories c
    LEFT JOIN subcategories s ON c.id_category = s.category_id
  ''');

    // Organiser les résultats dans une structure de données correcte
    Map<int, Category> categoryMap = {};

    for (var row in results) {
      int categoryId = row['id_category'];

      if (!categoryMap.containsKey(categoryId)) {
        categoryMap[categoryId] = Category(
          id: categoryId,
          name: row['category_name'],
          imagePath: row['image_path'],
          subCategories: [],
        );
      }

      if (row['id_sub_category'] != null) {
        categoryMap[categoryId]!.subCategories.add(
              SubCategory(
                id: row['id_sub_category'],
                name: row['sub_category_name'],
                categoryId: categoryId,
              ),
            );
      }
    }
    return categoryMap.values.toList();
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
    return await dbClient.insert(
      'variants',
      variant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Variant>> getVariantsByProductCode(String productCode) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'variants',
      where: 'product_code = ?',
      whereArgs: [productCode],
    );
    return maps.map((map) => Variant.fromMap(map)).toList();
  }

  Future<int> updateVariant(Variant variant) async {
    final dbClient = await db;
    return await dbClient.update(
      'variants',
      variant.toMap(),
      where: 'code = ?',
      whereArgs: [variant.code],
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

  Future<List<Variant>> getVariantsByProductReferenceId(
      String productReferenceId) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'variants',
      where: 'product_reference_id = ?',
      whereArgs: [productReferenceId],
    );
    return maps.map((map) => Variant.fromMap(map)).toList();
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
  Future<int> insertImage(String imagePath) async {
    final dbClient = await db;
    return await dbClient.insert(
      'gallery_images',
      {'image_path': imagePath},
      conflictAlgorithm: ConflictAlgorithm.replace,
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
}
