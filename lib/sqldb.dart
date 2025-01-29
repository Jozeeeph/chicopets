import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqlDb {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    return openDatabase(
      'cashdesk1.db',
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
    onUpgrade: (db, oldVersion, newVersion) async {}
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    Database? db = await this.db;
    List<Map<String, dynamic>> products = await db.query('products');
    return products; // Returning a list of product rows
  }

  Future<void> addProduct(
      String code,
      String designation,
      int stock,
      int quantity,
      double prixHT,
      double taxe,
      double prixTTC,
      String date) async {
    final dbClient = await db;
    await dbClient.insert('products', {
      'code': code,
      'designation': designation,
      'stock': stock,
      'quantity': quantity,
      'prix_ht': prixHT,
      'taxe': taxe,
      'prix_ttc': prixTTC,
      'date_expiration': date
    });
  }
}
