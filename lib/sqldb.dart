import 'dart:io';

import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/product.dart';
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

//   Future<void> copyDatabase() async {
//   // Get the path to the app's documents directory
//   final documentsDirectory = await getApplicationDocumentsDirectory();
//   final dbPath = join(documentsDirectory.path, 'cashdesk1.db');

//   // Check if the database file already exists
//   if (!File(dbPath).existsSync()) {
//     // Load the database file from assets
//     final data = await rootBundle.load('assets/database/cashdesk.db');
//     // Write the database file to the app's documents directory
//     await File(dbPath).writeAsBytes(data.buffer.asUint8List());
//   }
// }

  Future<Database> initDb() async {
  // Get the correct path for the database file
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final dbPath = join(documentsDirectory.path, 'cashdesk1.db');


  return openDatabase(
    dbPath, // Use the correct path
    version: 1,
    onCreate: (Database db, int version) async {
        print("Creating tables...");
      await db.execute('''
        CREATE TABLE products(
          code TEXT PRIMARY KEY,
          designation TEXT,
          stock INTEGER,
          prix_ht REAL,
          taxe REAL,
          prix_ttc REAL,
          date_expiration TEXT
        )
      ''');
  print("Products table created");

      await db.execute('''
        CREATE TABLE orders(
          id_order INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          total REAL,
          mode_paiement TEXT,
          id_client INTEGER
        )
      ''');
  print("Orders table created");

      await db.execute('''
        CREATE TABLE order_items(
          id_order INTEGER,
          product_code TEXT,
          quantity INTEGER,
          FOREIGN KEY(id_order) REFERENCES orders(id_order),
          FOREIGN KEY(product_code) REFERENCES products(code)
        )
      ''');
        print("Order items table created");

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
  Database db = await this.db;
  List<Map<String, dynamic>> maps = await db.query('products');
  return maps.map((map) => Product.fromMap(map)).toList();
}



  Future<void> addProduct(
    String code,
    String designation,
    int stock,
    double prixHT,
    double taxe,
    double prixTTC,
    String date,
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Handle conflicts if the same code is inserted
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
      for (var product in order.listeProduits) {
        await txn.insert(
          'order_items',
          {
            'id_order': orderId,
            'product_code': product.code,
            'quantity': 1, // Assuming quantity is 1 for each product
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return orderId;
    });

    return orderId;
  }

  Future<List<Order>> getOrders() async {
    final dbClient = await db;
    List<Map<String, dynamic>> orderMaps = await dbClient.query('orders');

    List<Order> orders = [];
    for (var orderMap in orderMaps) {
      int orderId = orderMap['id_order'];
      List<Map<String, dynamic>> itemMaps = await dbClient.query(
        'order_items',
        where: 'id_order = ?',
        whereArgs: [orderId],
      );

      List<Product> products = [];
      for (var itemMap in itemMaps) {
        List<Map<String, dynamic>> productMaps = await dbClient.query(
          'products',
          where: 'code = ?',
          whereArgs: [itemMap['product_code']],
        );

        if (productMaps.isNotEmpty) {
          products.add(Product.fromMap(productMaps.first));
        }
      }

      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        listeProduits: products,
        total: orderMap['total'],
        modePaiement: orderMap['mode_paiement'],
        idClient: orderMap['id_client'],
      ));
    }

    return orders;
  }

}



  