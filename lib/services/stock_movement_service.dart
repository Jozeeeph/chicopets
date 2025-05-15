// stock_movement_service.dart
import 'package:caissechicopets/models/stock_movement.dart';
import 'package:caissechicopets/sqldb.dart';

class StockMovementService {
  final SqlDb _sqlDb;
  final Map<int, List<StockMovement>> _productMovementCache = {};
  final Map<int, List<StockMovement>> _variantMovementCache = {};

  StockMovementService(this._sqlDb);

  Future<void> recordMovement(StockMovement movement) async {
  final db = await _sqlDb.db;
  
  // Enregistrement du mouvement
  await db.insert('stock_movements', movement.toMap());
  
  // Mise à jour du cache
  if (movement.variantId != null) {
    _variantMovementCache[movement.variantId!] ??= [];
    _variantMovementCache[movement.variantId!]!.add(movement);
  } else {
    _productMovementCache[movement.productId] ??= [];
    _productMovementCache[movement.productId]!.add(movement);
  }
  
  // Enregistrement des statistiques pour l'IA
  await _updatePredictionData(movement);
}

Future<void> _updatePredictionData(StockMovement movement) async {
  final db = await _sqlDb.db;
  
  // Calcul des moyennes pour l'IA
  await db.rawInsert('''
    INSERT OR REPLACE INTO stock_prediction_stats (
      product_id, 
      variant_id,
      last_movement_date,
      avg_daily_sales,
      avg_weekly_sales,
      last_month_sales
    )
    VALUES (
      ?, ?, 
      COALESCE((SELECT last_movement_date FROM stock_prediction_stats WHERE product_id = ?), datetime('now')),
      (
        SELECT AVG(quantity) 
        FROM stock_movements 
        WHERE product_id = ? 
        AND movement_type = 'sale'
        AND movement_date >= date('now', '-30 days')
      ),
      (
        SELECT AVG(quantity) 
        FROM stock_movements 
        WHERE product_id = ? 
        AND movement_type = 'sale'
        AND movement_date >= date('now', '-90 days')
      ),
      (
        SELECT SUM(quantity)
        FROM stock_movements
        WHERE product_id = ?
        AND movement_type = 'sale'
        AND movement_date >= date('now', '-30 days')
      )
    )
  ''', [
    movement.productId,
    movement.variantId,
    movement.productId,
    movement.productId,
    movement.productId,
    movement.productId
  ]);
}

Future<List<Map<String, dynamic>>> getSalesTrends(int productId, {String? timeHorizon}) async {
  final db = await _sqlDb.db;
  
  String whereClause = 'product_id = ? AND movement_type = "sale"';
  List<dynamic> whereArgs = [productId];
  
  if (timeHorizon != null) {
    whereClause += ' AND movement_date >= ?';
    whereArgs.add(_getDateCutoff(timeHorizon));
  }
  
  return await db.rawQuery('''
    SELECT 
      strftime('%Y-%m', movement_date) as month,
      SUM(quantity) as total_sales
    FROM stock_movements
    WHERE $whereClause
    GROUP BY month
    ORDER BY month
  ''', whereArgs);
}
  Future<List<StockMovement>> getMovementsForProduct(int productId, {int? limit, String? timeHorizon}) async {
  if (_productMovementCache.containsKey(productId)) { 
    return _filterByTimeHorizon(_productMovementCache[productId]!, timeHorizon, limit);
  }

  final db = await _sqlDb.db;
  final whereClause = timeHorizon != null 
    ? 'product_id = ? AND movement_date >= ?'
    : 'product_id = ?';

  final whereArgs = timeHorizon != null
    ? [productId, _getDateCutoff(timeHorizon)]
    : [productId];

  final result = await db.query(
    'stock_movements',
    where: whereClause,
    whereArgs: whereArgs,
    orderBy: 'movement_date DESC',
    limit: limit,
  );

  final movements = result.map((map) => StockMovement.fromMap(map)).toList();
  _productMovementCache[productId] = movements;
  return movements;
}


  Future<List<StockMovement>> getMovementsForVariant(int variantId, {int? limit, String? timeHorizon}) async {
    if (_variantMovementCache.containsKey(variantId)) {
      return _filterByTimeHorizon(_variantMovementCache[variantId]!, timeHorizon, limit);
    }
    
    final db = await _sqlDb.db;
    final whereClause = timeHorizon != null 
      ? 'variant_id = ? AND movement_date >= ?'
      : 'variant_id = ?';
    
    final whereArgs = timeHorizon != null
      ? [variantId, _getDateCutoff(timeHorizon)]
      : [variantId];
    
    final result = await db.query(
      'stock_movements',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'movement_date DESC',
      limit: limit,
    );
    
    final movements = result.map((map) => StockMovement.fromMap(map)).toList();
    _variantMovementCache[variantId] = movements;
    return movements;
  }

  String _getDateCutoff(String timeHorizon) {
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

  List<StockMovement> _filterByTimeHorizon(List<StockMovement> movements, String? timeHorizon, int? limit) {
    if (timeHorizon == null) {
      return limit != null ? movements.take(limit).toList() : movements;
    }
    
    final cutoff = _getDateCutoff(timeHorizon);
    final filtered = movements.where((m) => m.movementDate.isAfter(DateTime.parse(cutoff))).toList();
    return limit != null ? filtered.take(limit).toList() : filtered;
  }

  Future<Map<String, dynamic>> getProductMovementStats(int productId) async {
    final db = await _sqlDb.db;
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE 0 END) as total_in,
        SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END) as total_out,
        SUM(CASE WHEN movement_type = 'sale' THEN quantity ELSE 0 END) as total_sales,
        SUM(CASE WHEN movement_type = 'loss' THEN quantity ELSE 0 END) as total_losses,
        COUNT(*) as movement_count
      FROM stock_movements
      WHERE product_id = ?
    ''', [productId]);
    
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getStockMovementStats() async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.designation as product_name,
        p.category_name as category,
        p.stock as current_stock,
        COUNT(sm.id) as movement_count,
        SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END) as total_in,
        SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END) as total_out,
        SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END) as total_sales,
        SUM(CASE WHEN sm.movement_type = 'loss' THEN sm.quantity ELSE 0 END) as total_losses,
        (SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END) / 
          NULLIF(COUNT(DISTINCT strftime('%Y-%m', sm.movement_date)), 1)) as avg_monthly_sales
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      GROUP BY p.id
      ORDER BY movement_count DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getSlowMovingProducts({int thresholdDays = 90}) async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.designation,
        p.stock,
        p.category_name,
        MAX(sm.movement_date) as last_movement_date,
        julianday('now') - julianday(MAX(sm.movement_date)) as days_since_last_movement
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      GROUP BY p.id
      HAVING days_since_last_movement > ? OR (days_since_last_movement IS NULL AND p.stock > 0)
      ORDER BY days_since_last_movement DESC
    ''', [thresholdDays]);
  }

  Future<List<Map<String, dynamic>>> getFastMovingProducts({double thresholdRatio = 0.5}) async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.designation,
        p.stock,
        p.category_name,
        SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END) as total_sales,
        p.stock / NULLIF(SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END), 0) as stock_ratio
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      GROUP BY p.id
      HAVING stock_ratio < ? AND total_sales > 0
      ORDER BY stock_ratio ASC
    ''', [thresholdRatio]);
  }

  
}