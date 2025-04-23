import 'package:caissechicopets/models/attribut.dart';
import 'package:sqflite/sqflite.dart';

class Attributcontroller {
  Future<int> addAttribute(Attribut attribut,db) async {
    return await db.insert(
      'attributes',
      attribut.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all attributes
  Future<List<Attribut>> getAllAttributes(db) async {
    final List<Map<String, dynamic>> maps = await db.query('attributes');
    return List.generate(maps.length, (i) {
      return Attribut.fromMap(maps[i]);
    });
  }

  // Get attribute by name
  Future<Attribut?> getAttributeByName(String name,db) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'attributes',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (maps.isNotEmpty) {
      return Attribut.fromMap(maps.first);
    }
    return null;
  }

  // Update an attribute
  Future<int> updateAttribute(Attribut attribut,db) async {
    return await db.update(
      'attributes',
      attribut.toMap(),
      where: 'id = ?',
      whereArgs: [attribut.id],
    );
  }

  // Delete an attribute
  Future<int> deleteAttribute(int id,db) async {
    return await db.delete(
      'attributes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}