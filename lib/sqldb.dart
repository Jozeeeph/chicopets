import 'dart:convert';
import 'dart:io';
import 'package:caissechicopets/controllers/attributController.dart';
import 'package:caissechicopets/controllers/categoryController.dart';
import 'package:caissechicopets/controllers/clientController.dart';
import 'package:caissechicopets/controllers/galleryImagesController.dart';
import 'package:caissechicopets/controllers/orderController.dart';
import 'package:caissechicopets/controllers/orderLineController.dart';
import 'package:caissechicopets/controllers/productController.dart';
import 'package:caissechicopets/controllers/subCategoryController.dart';
import 'package:caissechicopets/controllers/userController.dart';
import 'package:caissechicopets/controllers/variantController.dart';
import 'package:caissechicopets/models/attribut.dart';
import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/fidelity_rules.dart';
import 'package:caissechicopets/models/paymentMode.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/subcategory.dart';
import 'package:caissechicopets/models/voucher.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Added to get the correct database path

class SqlDb {
  static Database? _db;
  Attributcontroller get attributController => Attributcontroller();

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
    final directory = Directory(appSupportDir.path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    // Open the database
    return await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      try {
        print("Creating tables...");

        await db.execute('''
  CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT,
    designation TEXT NOT NULL,
    description TEXT,
    stock INTEGER NOT NULL,
    prix_ht REAL NOT NULL,
    taxe REAL NOT NULL,
    prix_ttc REAL NOT NULL,
    date_expiration TEXT NOT NULL,
    category_id INTEGER NOT NULL,
    sub_category_id INTEGER,
    category_name TEXT,
    sub_category_name TEXT,
    is_deleted INTEGER DEFAULT 0,
    marge REAL NOT NULL,
    remise_max REAL DEFAULT 0.0,
    remise_valeur_max REAL DEFAULT 0.0,
    has_variants INTEGER DEFAULT 0,
    sellable INTEGER DEFAULT 1,
    status TEXT DEFAULT 'En stock',
    image TEXT,
    brand TEXT,
    earns_fidelity_points INTEGER DEFAULT 0,
    fidelity_points_earned INTEGER DEFAULT 0,
    redeemable_with_points INTEGER DEFAULT 0,
    fidelity_points_cost INTEGER DEFAULT 0,
    max_points_discount REAL,
    points_discount_percentage REAL
    );
    ''');
        print("Products table created");

        await db.execute('''
  CREATE TABLE orders (
    id_order INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT,
    total REAL,
    mode_paiement TEXT,
    status TEXT,
    remaining_amount REAL,
    id_client INTEGER,
    global_discount REAL DEFAULT 0.0,
    is_percentage_discount INTEGER DEFAULT 1,
    user_id INTEGER,
    
    -- Payment amounts
    cash_amount REAL,
    card_amount REAL,
    check_amount REAL,
    ticket_restaurant_amount REAL,
    voucher_amount REAL,
    gift_ticket_amount REAL,
    traite_amount REAL,
    virement_amount REAL,
    
    -- Payment details
    check_number TEXT,
    card_transaction_id TEXT,
    check_date TEXT,
    bank_name TEXT,
    gift_ticket_number TEXT,
    gift_ticket_issuer TEXT,
    traite_number TEXT,
    traite_bank TEXT,
    traite_beneficiary TEXT,
    traite_date TEXT,
    virement_reference TEXT,
    virement_bank TEXT,
    virement_sender TEXT,
    virement_date TEXT,
    
    -- Ticket restaurant details
    number_of_tickets_restaurant INTEGER,
    ticket_value REAL,
    ticket_tax REAL,
    ticket_commission REAL,
    
    -- Voucher details
    voucher_ids TEXT,
    voucher_reference TEXT,
    
    -- Loyalty program
    points_used INTEGER,
    points_discount REAL,
    
    -- Foreign keys
    FOREIGN KEY (id_client) REFERENCES clients(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
''');
        print("Orders table created");

        await db.execute('''
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_order INTEGER NOT NULL,
            product_code TEXT,
            product_name TEXT,
            product_id INTEGER,
            variant_id INTEGER,
            variant_code TEXT,
            variant_name TEXT,
            quantity INTEGER NOT NULL,
            prix_unitaire REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            isPercentage INTEGER NOT NULL CHECK (isPercentage IN (0, 1)),
            product_data TEXT,
            FOREIGN KEY (id_order) REFERENCES orders(id_order) ON DELETE CASCADE,
            FOREIGN KEY (product_code) REFERENCES products(code) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY (variant_id) REFERENCES variants(id) ON DELETE CASCADE,
            CHECK (product_code IS NOT NULL OR product_id IS NOT NULL)
          );

        ''');
        print("Order items table created");

        await db.execute('''
          CREATE TABLE categories (
            id_category INTEGER PRIMARY KEY AUTOINCREMENT,
            category_name TEXT NOT NULL,
            image_path TEXT,
            is_deleted INTEGER DEFAULT 0 CHECK (is_deleted IN (0, 1))
          );
        ''');
        print("Categories table created");

        await db.execute('''
          CREATE TABLE sub_categories (
            id_sub_category INTEGER PRIMARY KEY AUTOINCREMENT,
            sub_category_name TEXT NOT NULL,
            parent_id INTEGER,
            category_id INTEGER NOT NULL,
            is_deleted INTEGER DEFAULT 0 CHECK (is_deleted IN (0, 1)),
            FOREIGN KEY (parent_id) REFERENCES sub_categories (id_sub_category) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories (id_category) ON DELETE CASCADE
          );
        ''');
        print("Sub-categories table created");

        await db.execute('''
          CREATE TABLE variants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT,
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
          CREATE TABLE gallery_images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            name TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        ''');
        print("Gallery images table created");

        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            code TEXT NOT NULL,
            role TEXT NOT NULL,
            is_active INTEGER DEFAULT 1
          );
        ''');
        print("Users table created");

        await db.execute('''
          CREATE TABLE clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            first_name TEXT NOT NULL,
            phone_number TEXT NOT NULL UNIQUE,
            loyalty_points INTEGER DEFAULT 0,
            debt REAL DEFAULT 0.0,
            id_orders TEXT DEFAULT '',
            last_purchase_date TEXT
          );
        ''');
        print("Clients table created");

        await db.execute('''
    CREATE TABLE IF NOT EXISTS client_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL,
      points INTEGER NOT NULL,
      order_id INTEGER,
      reason TEXT,
      date_earned TEXT NOT NULL,
      expiry_date TEXT NOT NULL,
      is_used INTEGER DEFAULT 0,
      FOREIGN KEY (client_id) REFERENCES clients (id),
      FOREIGN KEY (order_id) REFERENCES orders (id)
    )
  ''');

        await db.execute('''
          CREATE TABLE attributes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            attributs_values TEXT NOT NULL,
            UNIQUE(name) ON CONFLICT REPLACE
          );
        ''');
        print("Attributes table created");

        await db.execute('''
            CREATE TABLE payment_methods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      icon TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
);
          ''');
        print("payment_methods table created");
        // Après la création des tables
        await db.execute('''
            CREATE VIEW IF NOT EXISTS sales_report_view AS
              SELECT
    o.id_order,
    o.date,
    p.designation as product_name,
    c.category_name as category,
    oi.quantity,
    oi.prix_unitaire as unit_price,
    oi.discount,
    oi.isPercentage as is_percentage_discount,
    (oi.quantity * oi.prix_unitaire * (1 - CASE WHEN oi.isPercentage THEN oi.discount/100 ELSE oi.discount/oi.prix_unitaire END)) as total,
    o.mode_paiement as payment_method,
    o.status,
    o.id_client,
    oi.variant_id,
    o.user_id
  FROM orders o
  JOIN order_items oi ON o.id_order = oi.id_order
  LEFT JOIN products p ON oi.product_id = p.id
  LEFT JOIN categories c ON p.category_id = c.id_category
  WHERE o.status IN ('payée', 'semi-payée')
''');
        await db.execute('''
            CREATE TABLE fidelity_rules (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              points_per_dinar REAL NOT NULL DEFAULT 0.1,
              dinar_per_point REAL NOT NULL DEFAULT 1.0,
              min_points_to_use INTEGER NOT NULL DEFAULT 10,
              max_percentage_use REAL NOT NULL DEFAULT 50.0,
              points_validity_months INTEGER NOT NULL DEFAULT 12
            );
        ''');
        print("Fidelity rules table created");
        await db.execute('''
  CREATE TABLE vouchers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    remaining_amount REAL NOT NULL,
    points_used INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT,
    is_used INTEGER DEFAULT 0,
    used_at TEXT,
    code TEXT,
    notes TEXT,
    FOREIGN KEY (client_id) REFERENCES clients (id)
);
''');
        await _ensureDefaultPaymentMethods(db);
      } catch (e) {
        print("Error creating tables: $e");
        rethrow;
      }
      // Dans la méthode onCreate
      await db.execute('''
  CREATE TABLE stock_movements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    variant_id INTEGER,
    movement_type TEXT NOT NULL, -- 'in', 'out', 'sale', 'loss', 'adjustment', 'transfer'
    quantity INTEGER NOT NULL,
    previous_stock INTEGER NOT NULL,
    new_stock INTEGER NOT NULL,
    movement_date TEXT NOT NULL,
    reference_id TEXT, -- ID de commande ou autre référence
    notes TEXT,
    user_id INTEGER,
    source_location TEXT, -- Pour les transferts entre magasins
    destination_location TEXT, -- Pour les transferts entre magasins
    reason_code TEXT, -- Pour les pertes/ajustements
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (variant_id) REFERENCES variants(id)
  )
''');

      await db.execute('''
  CREATE TABLE stock_predictions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    prediction_date TEXT NOT NULL,
    predicted_quantity INTEGER NOT NULL,
    confidence REAL,
    time_horizon TEXT NOT NULL, -- 'short', 'medium', 'long'
    FOREIGN KEY (product_id) REFERENCES products(id)
  )
''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS stock_prediction_stats (
    product_id INTEGER NOT NULL,
    variant_id INTEGER,
    last_movement_date TEXT NOT NULL,
    avg_daily_sales REAL,
    avg_weekly_sales REAL,
    last_month_sales INTEGER,
    PRIMARY KEY (product_id, variant_id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (variant_id) REFERENCES variants(id)
  )
''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payment_methods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            icon TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL
          )
        ''');
        print("Added payment_methods table in upgrade");

        // Insert default payment methods only if the table is empty
        final isEmpty = await _isTableEmpty(db, 'payment_methods');
        if (isEmpty) {
          await insertDefaultPaymentMethods(db);
        }
      }
    });
  }

  //PRODUCT Repository
  Future<List<Product>> getProducts() async {
    final dbClient = await db;
    return await ProductController().getProducts(dbClient);
  }

  Future<List<Map<String, dynamic>>> getProductsForExport() async {
    final dbClient = await db;

    // Get all products with their category/subcategory info
    final List<Map<String, dynamic>> products = await dbClient.rawQuery('''
    SELECT 
      p.*, 
      c.category_name,
      sc.sub_category_name
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id_category
    LEFT JOIN sub_categories sc ON p.sub_category_id = sc.id_sub_category
    WHERE p.is_deleted = 0
  ''');

    List<Map<String, dynamic>> exportData = [];

    for (var product in products) {
      // Get variants if product has variants
      List<Map<String, dynamic>> variants = [];
      if (product['has_variants'] == 1) {
        variants = await dbClient.query(
          'variants',
          where: 'product_id = ?',
          whereArgs: [product['id']],
        );
      }

      // Convert to export format
      exportData.add(_productToExportMap(product, variants));
    }

    return exportData;
  }

  Map<String, dynamic> _productToExportMap(
      Map<String, dynamic> product, List<Map<String, dynamic>> variants) {
    // Calculate cost price safely
    double prixHT = (product['prix_ht'] ?? 0).toDouble();
    double marge = (product['marge'] ?? 0).toDouble();

    return {
      'product': {
        'name': product['designation'] ?? '',
        'reference': product['code'] ?? '',
        'category': product['category_name'] ?? 'Default',
        'subCategory': product['sub_category_name'],
        'brand': product['brand'],
        'description': product['description'],
        'costPrice': prixHT - marge,
        'prixHT': prixHT,
        'taxe': (product['taxe'] ?? 0).toDouble(),
        'prixTTC': (product['prix_ttc'] ?? 0).toDouble(),
        'stock': product['stock'] ?? 0,
        'sellable': product['sellable'] == 1,
        'simpleProduct':
            product['has_variants'] == 0, // True for simple products
        'image': product['image'],
        'status': product['status'] ?? 'En stock',
        'dateExpiration': product['date_expiration'],
      },
      'variants': product['has_variants'] == 1
          ? variants.map((v) => _variantToExportMap(v)).toList()
          : [], // Empty array for simple products
    };
  }

  Map<String, dynamic> _variantToExportMap(Map<String, dynamic> variant) {
    return {
      'name': variant['combination_name'] ?? '',
      'defaultVariant': variant['default_variant'] == 1,
      'priceImpact': (variant['price_impact'] ?? 0).toDouble(),
      'stock': variant['stock'] ?? 0,
      'attributes': _parseVariantAttributes(variant['attributes']),
    };
  }

  Map<String, String> _parseVariantAttributes(dynamic attributes) {
    if (attributes == null) return {};
    try {
      if (attributes is String) {
        return Map<String, String>.from(jsonDecode(attributes));
      }
      return {};
    } catch (e) {
      debugPrint('Error parsing variant attributes: $e');
      return {};
    }
  }

  Future<Product?> getProductByCode(String? code) async {
    if (code == null) return null;
    final dbClient = await db;
    return await ProductController().getProductByCode(code, dbClient);
  }

  Future<Product?> getProductById(int id) async {
    final dbClient = await db;
    return await ProductController().getProductById(id, dbClient);
  }

  Future<int> updateProductWithoutId(Product product) async {
    final db = await this.db;
    return await ProductController().updateProductWithoutId(product, db);
  }

  Future<int> updateProduct(Product product) async {
    final dbClient = await db;
    return await ProductController().updateProduct(product, dbClient);
  }

  Future<int> deleteProductById(int productId) async {
    final db = await this.db;
    return await ProductController().deleteProductById(productId, db);
  }

  Future<Product?> getProductByDesignation(String designation) async {
    final db = await this.db;
    return await ProductController().getProductByDesignation(designation, db);
  }

  Future<Product?> getDesignationByCode(String code) async {
    final dbClient = await db;
    return await ProductController().getProductByCode(code, dbClient);
  }

  Future<List<Map<String, dynamic>>> getProductsWithCategory() async {
    final dbClient = await db;
    return await ProductController().getProductsWithCategory(dbClient);
  }

  Future<int> addProduct(Product product) async {
    final dbClient = await db;
    return await ProductController().addProduct(product, dbClient);
  }

  Future<int> updateProductStock(int productId, int newStock) async {
    final db1 = await db;
    return await ProductController()
        .updateProductStock(productId, newStock, db1);
  }

  Future<List<Product>> searchProducts({
    String? category,
    String query = '',
    bool lowStock = false,
  }) async {
    final dbClient = await db;
    return await ProductController().searchProducts(
      category: category,
      query: query,
      lowStock: lowStock,
      dbClient: dbClient,
    );
  }

  Future<Product> getProductWithVariants(int productId) async {
    final dbClient = await db;
    return await ProductController()
        .getProductWithVariants(productId, dbClient);
  }

  Future<int> updateProductWithVariants(Product product) async {
    final dbClient = await db;
    return await ProductController()
        .updateProductWithVariants(product, dbClient);
  }

  Future<List<String>> getProductsInSubCategory(int subCategoryId) async {
    final dbClient = await db;
    return await ProductController()
        .getProductsInSubCategory(subCategoryId, dbClient);
  }

  Future<List<Map<String, dynamic>>> getProductsPurchasedByClient(
      int clientId) async {
    final dbClient = await db;
    return await ProductController()
        .getProductsPurchasedByClient(clientId, dbClient);
  }

  //Order Repository
  Future<void> updateOrderStatus(int idOrder, String status) async {
    final dbClient = await db;
    await OrderController().updateOrderStatus(idOrder, status, dbClient);
  }

  Future<int> addOrder(Order order) async {
    final dbClient = await db;
    return await OrderController().addOrder(order, dbClient);
  }

  Future<List<Order>> getOrdersWithOrderLines() async {
    final dbClient = await db;
    return await OrderController().getOrdersWithOrderLines(dbClient);
  }

  Future<List<Order>> getOrders() async {
    final dbClient = await db;
    return await OrderController().getOrders(dbClient);
  }

  Future<void> deleteOrder(int idOrder) async {
    final dbClient = await db;
    await OrderController().deleteOrder(idOrder, dbClient);
  }

  Future<int> updateOrderTotal(int orderId, double newTotal) async {
    final dbClient = await db;
    return OrderController().updateOrderTotal(orderId, newTotal, dbClient);
  }

  Future<int> cancelOrder(int idOrder) async {
    final dbClient = await db;
    // Update the status of the order to "Annulée"
    return await OrderController().cancelOrder(idOrder, dbClient);
  }

  Future<void> updateOrderInDatabase(Order order) async {
    final dbClient = await db;
    return await OrderController().updateOrderInDatabase(order, dbClient);
  }

  Future<void> debugCheckOrder(int orderId) async {
    final dbClient = await db;
    await OrderController().debugCheckOrder(orderId, dbClient);
  }

  //OrderLine Repository
  Future<void> cancelOrderLine(int idOrder, String idProduct) async {
    final dbClient = await db;
    await Orderlinecontroller().cancelOrderLine(idOrder, idProduct, dbClient);
  }

  Future<void> deleteOrderLine(
      int idOrder, String idProduct, int variantId) async {
    final dbClient = await db;
    await Orderlinecontroller()
        .deleteOrderLine(idOrder, idProduct, variantId, dbClient);
  }

  //Category Repository
  Future<String> getCategoryNameById(int id) async {
    final dbClient = await db;
    return await Categorycontroller().getCategoryNameById(id, dbClient);
  }

  Future<List<Category>> getCategoriesWithSubcategories() async {
    final dbClient = await db;
    return await Categorycontroller().getCategoriesWithSubcategories(dbClient);
  }

  Future<int> addCategory(String name, String imagePath) async {
    final dbClient = await db;
    return await Categorycontroller().addCategory(name, imagePath, dbClient);
  }

  Future<int> updateCategory(int id, String name, String? imagePath) async {
    final dbClient = await db;
    return await Categorycontroller()
        .updateCategory(id, name, imagePath!, dbClient);
  }

  Future<int> deleteCategory(int id) async {
    final dbClient = await db;
    return await Categorycontroller().deleteCategory(id, dbClient);
  }

  Future<List<Category>> getCategories() async {
    final dbClient = await db;
    return await Categorycontroller().getCategories(dbClient);
  }

  Future<List<String>> getProductsInCategory(int categoryId) async {
    final dbClient = await db;
    return await Categorycontroller()
        .getProductsInCategory(categoryId, dbClient);
  }

  Future<bool> hasProductsInCategory(int categoryId) async {
    final dbClient = await db;
    return await Categorycontroller()
        .hasProductsInCategory(categoryId, dbClient);
  }

  //SubCategory Repository
  Future<String> getSubCategoryNameById(int id) async {
    final dbClient = await db;
    return await Subcategorycontroller().getSubCategoryNameById(id, dbClient);
  }

  Future<int> addSubCategory(SubCategory subCategory) async {
    final dbClient = await db;
    return await Subcategorycontroller().addSubCategory(subCategory, dbClient);
  }

  Future<List<SubCategory>> getSubCategories(int categoryId,
      {int? parentId}) async {
    final dbClient = await db;
    return await Subcategorycontroller().getSubCategories(
      categoryId,
      dbClient,
      parentId: parentId,
    );
  }

  Future<int> updateSubCategory(SubCategory subCategory) async {
    final dbClient = await db;
    return await Subcategorycontroller()
        .updateSubCategory(subCategory, dbClient);
  }

  Future<int> deleteSubCategory(int subCategoryId) async {
    final dbClient = await db;
    return await Subcategorycontroller()
        .deleteSubCategory(subCategoryId, dbClient);
  }

  Future<List<SubCategory>> getAllSubCategories() async {
    final dbClient = await db;
    return await Subcategorycontroller().getAllSubCategories(dbClient);
  }

  Future<List<Map<String, dynamic>>> getSubCategoriesByCategory(
      int categoryId) async {
    final dbClient = await db;
    return await Subcategorycontroller().getSubCategoriesByCategory(
      categoryId,
      dbClient,
    );
  }

  Future<List<Map<String, dynamic>>> getSubCategoryById(
    int subCategoryId,
    int categoryId,
  ) async {
    final dbClient = await db;
    return await Subcategorycontroller().getSubCategoryById(
      subCategoryId,
      dbClient,
      categoryId,
    );
  }

  Future<bool> hasProductsInSubCategory(int subCategoryId) async {
    final dbClient = await db;
    return await Subcategorycontroller()
        .hasProductsInSubCategory(subCategoryId, dbClient);
  }

  //Variant Repository
  // Add variant
  Future<int> addVariant(Variant variant) async {
    final dbClient = await db;
    return await Variantcontroller().addVariant(variant, dbClient);
  }

  Future<List<Variant>> getVariantsByProductId(int productId) async {
    final dbClient = await db;
    return await Variantcontroller()
        .getVariantsByProductId(productId, dbClient);
  }

  Future<Variant?> getVariantById(int id) async {
    final dbClient = await db;
    return await Variantcontroller().getVariantById(id, dbClient);
  }

  Future<List<Variant>> getVariantsByProductCode(String productCode) async {
    final dbClient = await db;
    return await Variantcontroller()
        .getVariantsByProductCode(productCode, dbClient);
  }

  Future<int> updateVariant(Variant variant) async {
    final dbClient = await db;
    return await Variantcontroller().updateVariant(variant, dbClient);
  }

  Future<int> updateVariantStock(int variantId, int newStock) async {
    final db1 = await db;
    return await Variantcontroller()
        .updateVariantStock(variantId, newStock, db1);
  }

  Future<int> deleteVariant(int variantId) async {
    final dbClient = await db;
    return await Variantcontroller().deleteVariant(variantId, dbClient);
  }

  Future<int> deleteVariantsByProductReferenceId(
      String productReferenceId) async {
    final dbClient = await db;
    return await Variantcontroller()
        .deleteVariantsByProductReferenceId(productReferenceId, dbClient);
  }

  //Client Repository
  Future<List<Order>> getClientOrders(int clientId) async {
    final dbClient = await db;
    return await Clientcontroller().getClientOrders(clientId, dbClient);
  }

  Future<void> addOrderToClient(int clientId, int orderId) async {
    final dbClient = await db;
    await Clientcontroller().addOrderToClient(clientId, orderId, dbClient);
  }

  Future<int?> getClientIdByPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) return null;

    final dbClient = await db;
    return await Clientcontroller().getClientIdByPhone(phoneNumber, dbClient);
  }

  Future<int> addClient(Client client) async {
    final dbClient = await db;
    return await Clientcontroller().addClient(client, dbClient);
  }

  Future<List<Client>> getAllClients() async {
    final dbClient = await db;
    return await Clientcontroller().getAllClients(dbClient);
  }

  Future<Client?> getClientById(int id) async {
    final dbClient = await db;
    return await Clientcontroller().getClientById(id, dbClient);
  }

  Future<int> updateClient(Client client) async {
    final dbClient = await db;
    return await Clientcontroller().updateClient(client, dbClient);
  }

  // Dans votre classe SqlDb, ajoutez ces méthodes :

  Future<FidelityRules> getFidelityRules() async {
    final dbClient = await db;
    final maps = await dbClient.query('fidelity_rules', limit: 1);

    if (maps.isEmpty) {
      return FidelityRules();
    }

    return FidelityRules.fromMap(maps.first);
  }

  Future<int> createVoucher({
    required int clientId,
    required double amount,
    required int pointsUsed,
  }) async {
    final dbClient = await db;
    return await Clientcontroller().createVoucher(
        clientId: clientId,
        amount: amount,
        pointsUsed: pointsUsed,
        db: dbClient);
  }

  Future<List<Map<String, dynamic>>> getClientVouchers(int clientId) async {
    final dbClient = await db;
    return await Clientcontroller().getClientVouchers(clientId, dbClient);
  }

  Future<int> updateClientLoyaltyPoints(int clientId, int newPoints) async {
    final dbClient = await db;
    return await Clientcontroller()
        .updateClientLoyaltyPoints(clientId, newPoints, dbClient);
  }

  Future<int> updateClientDebt(int clientId, double newDebt) async {
    final dbClient = await db;
    return await Clientcontroller()
        .updateClientDebt(clientId, newDebt, dbClient);
  }

  Future<int> deleteClient(int id) async {
    final dbClient = await db;
    return await Clientcontroller().deleteClient(id, dbClient);
  }

  Future<List<Client>> searchClients(String query) async {
    final dbClient = await db;
    return await Clientcontroller().searchClients(query, dbClient);
  }

  // User Repository Methods
  Future<int> addUser(User user) async {
    final dbClient = await db;
    return await UserController().addUser(user, dbClient);
  }

  Future<User?> getUserByUsername(String username) async {
    final dbClient = await db;
    return await UserController().getUserByUsername(username, dbClient);
  }

  Future<List<User>> getAllUsers() async {
    final dbClient = await db;
    return await UserController().getAllUsers(dbClient);
  }

  Future<bool> hasAdminAccount() async {
    final dbClient = await db;
    return await UserController().hasAdminAccount(dbClient);
  }

  Future<bool> verifyCode(String code) async {
    final dbClient = await db;
    return await UserController().verifyCode(code, dbClient);
  }

  Future<User?> getUserByCode(String code) async {
    final dbClient = await db;
    return await UserController().getUserByCode(code, dbClient);
  }

  Future<int> updateUserCode(String username, String newCode) async {
    final dbClient = await db;
    return await UserController().updateUserCode(username, newCode, dbClient);
  }

  Future<int> deleteUser(int userId) async {
    final dbClient = await db;
    return await UserController().deleteUser(userId, dbClient);
  }

  //Gallery Repository
  // Méthode pour insérer une image dans la base de données
  Future<int> insertImage(String imagePath, String name) async {
    final dbClient = await db;
    return await Galleryimagescontroller()
        .insertImage(imagePath, name, dbClient);
  }

  Future<List<Map<String, dynamic>>> searchImagesByName(String name) async {
    final dbClient = await db;
    return await Galleryimagescontroller().searchImagesByName(name, dbClient);
  }

// Méthode pour récupérer toutes les images de la galerie
  Future<List<Map<String, dynamic>>> getGalleryImages() async {
    final dbClient = await db;
    return await Galleryimagescontroller().getGalleryImages(dbClient);
  }

// Méthode pour supprimer une image de la galerie
  Future<int> deleteImage(int id) async {
    final dbClient = await db;
    return await Galleryimagescontroller().deleteImage(id, dbClient);
  }

  Future<int> updateImageName(int id, String name) async {
    final dbClient = await db;
    return await Galleryimagescontroller().updateImageName(id, name, dbClient);
  }

  //Rapport Repository

  Future<Map<String, Map<String, dynamic>>> getSalesReport({
    String? dateRange,
    int? userId,
    int? clientId,
  }) async {
    final db = await this.db;
    final salesData = <String, Map<String, dynamic>>{};

    try {
      // Base query to get sales data
      String query = '''
      SELECT 
        category,
        product_name,
        SUM(quantity) as total_quantity,
        SUM(total) as total_sales,
        AVG(unit_price) as avg_unit_price,
        AVG(discount) as avg_discount,
        MAX(is_percentage_discount) as is_percentage
      FROM rapports
      WHERE status IN ('completed', 'paid', 'semi-payée')
    ''';

      // Add filters if provided
      final List<dynamic> whereArgs = [];
      if (dateRange != null && dateRange.isNotEmpty) {
        query += ' AND $dateRange';
      }
      if (userId != null) {
        query += ' AND user_id = ?';
        whereArgs.add(userId);
      }
      if (clientId != null) {
        query += ' AND client_id = ?';
        whereArgs.add(clientId);
      }

      // Group and order results
      query += '''
      GROUP BY category, product_name
      ORDER BY category, total_sales DESC
    ''';

      // Execute the query
      final results = await db.rawQuery(query, whereArgs);

      // Process the results
      for (final row in results) {
        final category = row['category'] as String? ?? 'Uncategorized';
        final productName = row['product_name'] as String? ?? 'Unknown Product';
        final quantity = row['total_quantity'] as int? ?? 0;
        final total = row['total_sales'] as double? ?? 0.0;
        final discount = row['avg_discount'] as double? ?? 0.0;
        final isPercentage = (row['is_percentage'] as int?) == 1;

        // Initialize category if not exists
        salesData.putIfAbsent(
          category,
          () => {
            'products': <String, dynamic>{},
            'total': 0.0,
          },
        );

        // Add product to category
        salesData[category]!['products'][productName] = {
          'quantity': quantity,
          'total': total,
          'discount': discount,
          'isPercentage': isPercentage,
          'unitPrice': row['avg_unit_price'],
        };

        // Update category total
        salesData[category]!['total'] =
            (salesData[category]!['total'] as double) + total;
      }

      return salesData;
    } catch (e) {
      print('Error in getSalesReport: $e');
      return {};
    }
  }

  //Attributs Repository
  Future<int> addAttribute(Attribut attribut) async {
    final dbClient = await db;
    return await Attributcontroller().addAttribute(attribut, dbClient);
  }

  Future<List<Attribut>> getAllAttributes() async {
    final dbClient = await db;
    return await Attributcontroller().getAllAttributes(dbClient);
  }

  Future<int> updateAttribute(Attribut attribut) async {
    final dbClient = await db;
    return await Attributcontroller().updateAttribute(attribut, dbClient);
  }

  Future<int> deleteAttribute(int attributId) async {
    final db = await this.db;
    return await Attributcontroller().deleteAttribute(attributId, db);
  }

  Future<int> updateProductPrice(int productId, double newPrice) async {
    final db = await this.db;
    return await db.update(
      'products',
      {'prix_ttc': newPrice},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<Variant?> getVariantByCode(String code) async {
    try {
      final db = await this.db;
      final List<Map<String, dynamic>> maps = await db.query(
        'variants',
        where: 'code = ?',
        whereArgs: [code],
      );

      if (maps.isNotEmpty) {
        return Variant.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting variant by code: $e');
      return null;
    }
  }

  //Voucher Repository
  Future<List<Voucher>> fetchClientVouchers(int clientId) async {
    final dbClient = await db;

    try {
      final List<Map<String, dynamic>> maps = await dbClient.query(
        'vouchers',
        where: 'client_id = ? AND is_used = 0',
        whereArgs: [clientId],
        orderBy: 'created_at DESC', // Optional: order by creation date
      );

      return List.generate(maps.length, (i) {
        return Voucher(
          id: maps[i]['id'],
          clientId: maps[i]['client_id'],
          amount: maps[i]['amount'],
          pointsUsed: maps[i]['points_used'],
          createdAt: DateTime.parse(maps[i]['created_at']),
          isUsed: maps[i]['is_used'] == 1,
          usedAt: maps[i]['used_at'] != null
              ? DateTime.parse(maps[i]['used_at'])
              : null,
        );
      });
    } catch (e) {
      print('Error fetching vouchers: $e');
      return []; // Return empty list on error
    }
  }

  Future<void> markVoucherAsUsed(int voucherId) async {
    final dbClient = await db;
    await dbClient.update(
      'vouchers',
      {
        'is_used': 1,
        'used_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [voucherId],
    );
  }

  //Payment mode Repository
  Future<void> createPaymentMethodsTable() async {
    final db = await this.db;

    // Create the table if it doesn't exist
    await db.execute('''
    CREATE TABLE IF NOT EXISTS payment_methods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      icon TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )
  ''');

    // Check if table is empty
    final isEmpty = await _isTableEmpty(db, 'payment_methods');

    if (isEmpty) {
      await insertDefaultPaymentMethods(db);
    }
  }

  Future<bool> _isTableEmpty(Database db, String tableName) async {
    final count = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
    return Sqflite.firstIntValue(count) == 0;
  }

  Future<void> _ensureDefaultPaymentMethods(Database db) async {
    final isEmpty = await _isTableEmpty(db, 'payment_methods');
    if (isEmpty) {
      await insertDefaultPaymentMethods(db);
    }
  }

  Future<void> insertDefaultPaymentMethods(Database db) async {
    final defaultMethods = [
      {
        'name': 'Espèce', // Cash
        'icon': 'assets/icons/cash.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'TPE', // Credit/Debit Card
        'icon': 'assets/icons/credit-card.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Chèque', // Check
        'icon': 'assets/icons/check.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Ticket Restaurant', // Meal voucher
        'icon': 'assets/icons/meal-voucher.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Ticket Cadeau',
        'icon': 'assets/icons/meal-voucher.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Bon d\'achat', // Gift card
        'icon': 'assets/icons/gift-card.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Virement', // Bank transfer
        'icon': 'assets/icons/bank-transfer.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Traite', // Draft
        'icon': 'assets/icons/draft.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
      {
        'name': 'Mixte', // Mixed payment
        'icon': 'assets/icons/mixed-payment.png',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String()
      },
    ];

    await db.transaction((txn) async {
      for (final method in defaultMethods) {
        try {
          await txn.insert('payment_methods', method);
        } catch (e) {
          debugPrint('Error inserting default payment method: $e');
        }
      }
    });
  }

  Future<List<PaymentMethod>> getPaymentMethods(
      {bool activeOnly = false}) async {
    final db = await this.db;

    try {
      final result = await db.query(
        'payment_methods',
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'name ASC',
      );

      return result.map((map) => PaymentMethod.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
      rethrow;
    }
  }

  Future<int> addPaymentMethod(PaymentMethod method) async {
    final db = await this.db;
    return await db.insert('payment_methods', method.toMap());
  }

  Future<int> updatePaymentMethod(PaymentMethod method) async {
    final db = await this.db;
    return await db.update(
      'payment_methods',
      method.toMap(),
      where: 'id = ?',
      whereArgs: [method.id],
    );
  }

  Future<int> togglePaymentMethodStatus(int id, bool isActive) async {
    final db = await this.db;
    return await db.update(
      'payment_methods',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePaymentMethod(int id) async {
    final db = await this.db;
    return await db.delete(
      'payment_methods',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // sqldb.dart (ajouts)
  Future<List<Map<String, dynamic>>> getProductMovementHistory(int productId,
      {String? timeHorizon}) async {
    final db = await this.db;

    String whereClause = 'product_id = ?';
    List<dynamic> whereArgs = [productId];

    if (timeHorizon != null) {
      final cutoffDate = _getCutoffDate(timeHorizon);
      whereClause += ' AND movement_date >= ?';
      whereArgs.add(cutoffDate);
    }

    return await db.query(
      'stock_movements',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'movement_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getVariantMovementHistory(int variantId,
      {String? timeHorizon}) async {
    final db = await this.db;

    String whereClause = 'variant_id = ?';
    List<dynamic> whereArgs = [variantId];

    if (timeHorizon != null) {
      final cutoffDate = _getCutoffDate(timeHorizon);
      whereClause += ' AND movement_date >= ?';
      whereArgs.add(cutoffDate);
    }

    return await db.query(
      'stock_movements',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'movement_date DESC',
    );
  }

  String _getCutoffDate(String timeHorizon) {
    final now = DateTime.now();
    switch (timeHorizon) {
      case 'short_term':
        return now.subtract(Duration(days: 30)).toIso8601String();
      case 'medium_term':
        return now.subtract(Duration(days: 90)).toIso8601String();
      case 'long_term':
        return now.subtract(Duration(days: 365)).toIso8601String();
      default:
        return now.subtract(Duration(days: 30)).toIso8601String();
    }
  }

  Future<List<Map<String, dynamic>>> getStockPredictions() async {
    final db = await this.db;
    return await db.query('stock_predictions');
  }

  Future<List<Map<String, dynamic>>> getProductPredictions(
      int productId) async {
    final db = await this.db;
    return await db.query(
      'stock_predictions',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }
}
