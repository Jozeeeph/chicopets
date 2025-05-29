import 'package:caissechicopets/models/attribute.dart';
import 'package:sqflite/sqflite.dart';

class Attributcontroller {
  Future<int> addAttribute(Attribut attribut, db) async {
    return await db.insert(
      'attributes',
      attribut.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all attributes
  Future<List<Attribut>> getAllAttributes(db) async {
    try {
      print("Querying attributes table...");
      final List<Map<String, dynamic>> maps = await db.query('attributes');
      print("Raw database results: $maps");

      final attributs = List.generate(maps.length, (i) {
        return Attribut.fromMap(maps[i]);
      });

      print("Parsed attributs: $attributs");
      return attributs;
    } catch (e) {
      print("Error in getAllAttributes: $e");
      rethrow;
    }
  }

  // Get attribute by name
  Future<Attribut?> getAttributeByName(String name, db) async {
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
  Future<int> updateAttribute(Attribut attribut, db) async {
    return await db.update(
      'attributes',
      attribut.toMap(),
      where: 'id = ?',
      whereArgs: [attribut.id],
    );
  }

  // Delete an attribute
  Future<int> deleteAttribute(int id, db) async {
    return await db.delete(
      'attributes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
