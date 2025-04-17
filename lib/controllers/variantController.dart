import 'package:caissechicopets/models/variant.dart';
import 'package:sqflite/sqflite.dart';

class Variantcontroller {
  Future<List<Variant>> getVariantsByProductId(int productId,dbClient) async {
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'variants',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    return maps.map(Variant.fromMap).toList();
  }
}
