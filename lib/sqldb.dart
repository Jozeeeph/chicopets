import 'dart:io';

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
        await db.execute('''
          CREATE TABLE products(
            code TEXT PRIMARY KEY,
            designation TEXT,
            stock INTEGER,
            quantity INTEGER,
            prix_ht REAL,
            taxe REAL,
            prix_ttc REAL,
            date_expiration TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Handle database upgrades if needed
      },
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    Database db = await this.db;
    List<Map<String, dynamic>> products = await db.query('products');
    return products;
  }

  Future<void> addProduct(
    String code,
    String designation,
    int stock,
    int quantity,
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
        'quantity': quantity,
        'prix_ht': prixHT,
        'taxe': taxe,
        'prix_ttc': prixTTC,
        'date_expiration': date,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Handle conflicts if the same code is inserted
    );
  }

  // Add more methods for update, delete, etc., as needed
}