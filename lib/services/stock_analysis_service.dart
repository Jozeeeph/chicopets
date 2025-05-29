import 'package:caissechicopets/services/sqldb.dart';

class StockAnalysisService {
  final SqlDb _sqlDb;

  StockAnalysisService(this._sqlDb);

  Future<Map<String, dynamic>> analyzeProductTrends(int productId) async {
    final db = await _sqlDb.db;
    
    // Analyse des ventes hebdomadaires
    final weeklySales = await db.rawQuery('''
      SELECT 
        strftime('%Y-%W', movement_date) as week,
        SUM(quantity) as total_sales
      FROM stock_movements
      WHERE product_id = ? AND movement_type = 'sale'
      GROUP BY week
      ORDER BY week
    ''', [productId]);
    
    // Analyse des mouvements de stock
    final stockMovements = await db.rawQuery('''
      SELECT 
        movement_type,
        COUNT(*) as count,
        SUM(quantity) as total_quantity
      FROM stock_movements
      WHERE product_id = ?
      GROUP BY movement_type
    ''', [productId]);
    
    // Calcul de la vitesse de vente
    final salesVelocity = await db.rawQuery('''
      SELECT 
        AVG(daily_sales) as avg_daily_sales
      FROM (
        SELECT 
          strftime('%Y-%m-%d', movement_date) as day,
          SUM(quantity) as daily_sales
        FROM stock_movements
        WHERE product_id = ? AND movement_type = 'sale'
        GROUP BY day
      )
    ''', [productId]);
    
    return {
      'weekly_sales': weeklySales,
      'movement_stats': stockMovements,
      'avg_daily_sales': salesVelocity.first['avg_daily_sales'] ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> identifySlowMovingProducts() async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.designation,
        p.stock,
        p.category_name,
        IFNULL(SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END), 0) as total_sales,
        p.stock / NULLIF(SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END), 0) as months_in_stock
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      GROUP BY p.id
      HAVING months_in_stock > 6 OR (total_sales = 0 AND p.stock > 0)
      ORDER BY months_in_stock DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> identifyFastMovingProducts() async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.designation,
        p.stock,
        p.category_name,
        SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END) as total_sales,
        p.stock / NULLIF(SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END), 0) as weeks_in_stock
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      GROUP BY p.id
      HAVING weeks_in_stock < 2 AND total_sales > 0
      ORDER BY weeks_in_stock ASC
    ''');
  }
}