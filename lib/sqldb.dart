import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqlDb {
  static Database? _db;

  Future <Database?> get db async{
    if (_db == null){
      _db = await initialDb();
    }
    else{
      return _db;
    }
  }

initialDb() async {
  String databasepath = await getDatabasesPath();
  String path = join(databasepath, 'chicopets.db');
  Database mydb = await openDatabase(path, onCreate: _onCreate, version: 3, onUpgrade: _onUpgrade);
  return mydb;
}

_onUpgrade(Database db, int oldVersion, int newVersion){

}

_onCreate(Database db, int version) async{
  await db.execute('''
  CREATE TABLE "product" (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    codeabarre INTEGER UNIQUE
    designation TEXT
    quantite INTEGER
    prixHT REAL
    prixTTC REAL
    dateexpiration DATE
  )
  ''');
  print("table created successfully");
}

getProducts(String sql) async {
  Database? mydb = await db;
  List<Map> response = await mydb!.rawQuery(sql);
  return response;
}

addProducts(String sql) async {
  Database? mydb = await db;
  int response = await mydb!.rawInsert(sql);
  return response;
}

updateProducts(String sql) async {
  Database? mydb = await db;
  int response = await mydb!.rawUpdate(sql);
  return response;
}


deleteProducts(String sql) async {
  Database? mydb = await db;
  int response = await mydb!.rawDelete(sql);
  return response;
}

}