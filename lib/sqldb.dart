import 'dart:io';
import 'package:caissechicopets/controllers/categoryController.dart';
import 'package:caissechicopets/controllers/clientController.dart';
import 'package:caissechicopets/controllers/galleryImagesController.dart';
import 'package:caissechicopets/controllers/orderController.dart';
import 'package:caissechicopets/controllers/orderLineController.dart';
import 'package:caissechicopets/controllers/productController.dart';
import 'package:caissechicopets/controllers/rapportController.dart';
import 'package:caissechicopets/controllers/subCategoryController.dart';
import 'package:caissechicopets/controllers/userController.dart';
import 'package:caissechicopets/controllers/variantController.dart';
import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/subcategory.dart';
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
            code TEXT,
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
    is_percentage_discount INTEGER DEFAULT 1,
    cash_amount REAL,
    card_amount REAL,
    check_amount REAL,
    check_number TEXT,
    card_transaction_id TEXT,
    check_date TEXT,
    bank_name TEXT
  );
''');
        print("Orders table created");

        await db.execute('''
 CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_order INTEGER NOT NULL,
    product_code TEXT,
    product_id INTEGER,
    quantity INTEGER NOT NULL,
    prix_unitaire REAL DEFAULT 0 NOT NULL,
    discount REAL NOT NULL,
    isPercentage INTEGER NOT NULL CHECK(isPercentage IN (0,1)),
    FOREIGN KEY (id_order) REFERENCES orders(id_order) ON DELETE CASCADE,
    FOREIGN KEY (product_code) REFERENCES products(code) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CHECK (product_code IS NOT NULL OR product_id IS NOT NULL) -- Ensure at least one reference exists
);
''');

        print("Order items table created");

        await db.execute('''
  CREATE TABLE IF NOT EXISTS categories (
    id_category INTEGER PRIMARY KEY AUTOINCREMENT,
    category_name TEXT NOT NULL,
    image_path TEXT,
    is_deleted INTEGER DEFAULT 0 CHECK (is_deleted IN (0, 1))
  )
''');
        print("Categories table created/verified");

        await db.execute('''
  CREATE TABLE IF NOT EXISTS sub_categories (
    id_sub_category INTEGER PRIMARY KEY AUTOINCREMENT,
    sub_category_name TEXT NOT NULL,
    parent_id INTEGER,
    category_id INTEGER NOT NULL,
    is_deleted INTEGER DEFAULT 0 CHECK (is_deleted IN (0, 1)),
    FOREIGN KEY (parent_id) REFERENCES sub_categories (id_sub_category) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories (id_category) ON DELETE CASCADE
  )
''');
        print("Sub-categories table created/verified");

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

  //PRODUCT Repository
  Future<List<Product>> getProducts() async {
    final dbClient = await db;
    return await ProductController().getProducts(dbClient);
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

  Future<int> updateProductStock(String productCode, int newStock) async {
    final db1 = await db;
    return await ProductController()
        .updateProductStock(productCode, newStock, db1);
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

  Future<void> deleteOrderLine(int idOrder, String idProduct) async {
    final dbClient = await db;
    await Orderlinecontroller().deleteOrderLine(idOrder, idProduct, dbClient);
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

// Get variants by product ID
  Future<List<Variant>> getVariantsByProductId(int productId) async {
    final dbClient = await db;
    return await Variantcontroller()
        .getVariantsByProductId(productId, dbClient);
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
  Future<Map<String, Map<String, dynamic>>> getSalesByCategoryAndProduct({
    String? dateFilter,
  }) async {
    final dbClient = await db;
    return await Rapportcontroller().getSalesByCategoryAndProduct(
      dateFilter: dateFilter,
      db: dbClient,
    );
  }
}
