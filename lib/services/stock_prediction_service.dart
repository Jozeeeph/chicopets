import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:ml_algo/ml_algo.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';

class StockPredictionService {
  final SqlDb _sqlDb;
  LinearRegressor? _model;
  bool _isTraining = false;
  Standardizer? _standardizer;
  final List<String> _featureNames = [
    'product_id',
    'stock_in',
    'stock',
    'month',
    'weekday',
    'average_sales',
  ];

  StockPredictionService(this._sqlDb);

  Future<void> _ensureModelReady() async {
    if (_model != null) return;
    if (_isTraining) {
      while (_isTraining) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isTraining = true;
    try {
      await _trainModel();
    } finally {
      _isTraining = false;
    }
  }

  Future<void> _trainModel() async {
    final db = await _sqlDb.db;

    try {
      final data = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END), 0) as stock_in,
        p.stock as current_stock,
        CAST(strftime('%m', sm.movement_date) as INTEGER) as month,
        CAST(strftime('%w', sm.movement_date) as INTEGER) as weekday,
        (SELECT COALESCE(AVG(quantity), 0) 
          FROM stock_movements sm2 
          WHERE sm2.product_id = p.id AND sm2.movement_type = 'sale'
          AND sm2.movement_date >= date('now', '-3 months')
        ) as avg_sale,
        COALESCE(SUM(CASE WHEN sm.movement_type = 'sale' THEN sm.quantity ELSE 0 END), 0) as sales
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      WHERE sm.movement_date IS NOT NULL
      GROUP BY p.id, month, weekday
      HAVING sales > 0 OR stock_in > 0
      ORDER BY p.id, month
    ''');

      if (data.isEmpty) {
        debugPrint("Aucune donnée valide pour l'entraînement");
        // Ajoutez des données par défaut minimales pour éviter un modèle vide
        final defaultData = [
          {
            'product_id': 0,
            'stock_in': 0,
            'current_stock': 0,
            'month': DateTime.now().month,
            'weekday': DateTime.now().weekday,
            'avg_sale': 0,
            'sales': 0
          }
        ];
        _createModel(defaultData);
        return;
      }

      _createModel(data);
    } catch (e) {
      debugPrint("Erreur lors de l'entraînement du modèle: $e");
      rethrow;
    }
  }

  void _createModel(List<Map<String, dynamic>> data) {
    // Préparation des données
    final rows = data.map((row) {
      return [
        row['product_id'] ?? 0,
        row['stock_in'] ?? 0,
        row['current_stock'] ?? 0,
        row['month'] ?? DateTime.now().month,
        row['weekday'] ?? DateTime.now().weekday,
        row['avg_sale'] ?? 0,
        row['sales'] ?? 0 // Target variable
      ];
    }).toList();

    final dataframe = DataFrame(
      rows,
      header: [..._featureNames, 'sales'],
    );

    // Séparation des features et de la target
    final features = dataframe.dropSeries(names: ['sales']);
    final target = dataframe['sales'];

    // Normalisation des features
    _standardizer = Standardizer(features);
    final normalizedFeatures = _standardizer!.process(features);

    // Combinaison des features normalisées avec la target
    final processedData = DataFrame(
      normalizedFeatures.rows.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return [...row, target.data.elementAt(index)];
      }).toList(),
      header: [..._featureNames, 'sales'],
    );

    // Entraînement du modèle
    _model = LinearRegressor(
      processedData,
      'sales',
      optimizerType: LinearOptimizerType.coordinate,
      iterationsLimit: 100,
      fitIntercept: true,
    );
  }

  Future<Map<int, int>> predictStockNeeds({int timeHorizon = 30}) async {
    try {
      await _ensureModelReady();

      if (_model == null || _standardizer == null) {
        debugPrint(
            "Modèle non initialisé - utilisation de la méthode simplifiée");
        return await _simpleStockPrediction(timeHorizon);
      }

      final products = await _sqlDb.getProducts();
      final avgSales = await _getAverageSalesPerProduct();
      final predictions = <int, int>{};
      final now = DateTime.now();

      for (final product in products) {
        try {
          final productId = product.id ?? 0;
          final currentStock = product.stock;
          final avgSale = avgSales[productId] ?? 0;

          // Vérification des données de base
          if (productId == 0 || currentStock < 0) {
            predictions[productId] = 0;
            continue;
          }

          // Préparation des features
          final features = [
            [
              productId.toDouble(),
              0.0, // stock_in
              currentStock.toDouble(),
              now.month.toDouble(),
              now.weekday.toDouble(),
              avgSale,
            ]
          ];

          final featuresDf = DataFrame(features, header: _featureNames);

          // Vérification du dataframe
          if (featuresDf.rows.isEmpty) {
            debugPrint(
                "DataFrame vide pour le produit $productId - utilisation de la méthode simplifiée");
            final simplePrediction =
                await _simplePredictionForProduct(productId, timeHorizon);
            predictions[productId] = simplePrediction;
            continue;
          }

          // Prédiction
          final predictedValue = _model!.predict(featuresDf).rows.first.first;
          final predictedSales = (predictedValue as num).toInt();
          final stockNeeded =
              (predictedSales * (timeHorizon / 30)).round() - currentStock;

          predictions[productId] = stockNeeded > 0 ? stockNeeded : 0;
        } catch (e) {
          debugPrint("Erreur de prédiction pour le produit ${product.id}: $e");
          final simplePrediction =
              await _simplePredictionForProduct(product.id ?? 0, timeHorizon);
          predictions[product.id ?? 0] = simplePrediction;
        }
      }

      return predictions;
    } catch (e) {
      debugPrint(
          "Erreur majeure dans predictStockNeeds: $e - Utilisation de la méthode simplifiée");
      return await _simpleStockPrediction(timeHorizon);
    }
  }

  Future<Map<int, int>> _simpleStockPrediction(int timeHorizon) async {
    final products = await _sqlDb.getProducts();
    final predictions = <int, int>{};

    for (final product in products) {
      final productId = product.id ?? 0;
      predictions[productId] =
          await _simplePredictionForProduct(productId, timeHorizon);
    }

    return predictions;
  }

  Future<int> _simplePredictionForProduct(
      int productId, int timeHorizon) async {
    final db = await _sqlDb.db;
    try {
      final result = await db.rawQuery('''
      SELECT AVG(quantity) as avg_sales 
      FROM stock_movements 
      WHERE product_id = ? 
      AND movement_type = 'sale'
      AND movement_date >= date('now', '-3 months')
    ''', [productId]);

      final avgSales = result.first['avg_sales'] as double? ?? 0;
      final product = await _sqlDb.getProductById(productId);
      final currentStock = product?.stock ?? 0;
      final predictedSales = (avgSales * (timeHorizon / 30)).round();
      final stockNeeded = predictedSales - currentStock;

      return stockNeeded > 0 ? stockNeeded : 0;
    } catch (e) {
      debugPrint("Erreur dans simplePredictionForProduct: $e");
      return 0;
    }
  }

  Future<Map<String, Map<int, int>>> predictAllStockNeeds() async {
    final shortTerm = await predictStockNeeds(timeHorizon: 30);
    final mediumTerm = await predictStockNeeds(timeHorizon: 90);
    final longTerm = await predictStockNeeds(timeHorizon: 365);

    return {
      'short_term': shortTerm,
      'medium_term': mediumTerm,
      'long_term': longTerm,
    };
  }

  Future<Map<int, double>> _getAverageSalesPerProduct() async {
    final db = await _sqlDb.db;
    final result = await db.rawQuery('''
    SELECT 
      product_id,
      COALESCE(AVG(quantity), 0) as avg_sale
    FROM stock_movements
    WHERE movement_type = 'sale'
    AND movement_date >= date('now', '-3 months')
    GROUP BY product_id
  ''');

    final avgSales = <int, double>{};
    for (final row in result) {
      avgSales[row['product_id'] as int] = (row['avg_sale'] as num).toDouble();
    }

    // Ajouter une valeur par défaut pour tous les produits
    final products = await _sqlDb.getProducts();
    for (final product in products) {
      avgSales.putIfAbsent(product.id ?? 0, () => 0.0);
    }

    return avgSales;
  }

  Future<void> savePredictions(Map<int, int> predictions,
      {String timeHorizon = 'short_term'}) async {
    final db = await _sqlDb.db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Suppression des anciennes prédictions pour cet horizon
      await txn.delete(
        'stock_predictions',
        where: 'time_horizon = ?',
        whereArgs: [timeHorizon],
      );

      // Insertion des nouvelles prédictions
      for (final entry in predictions.entries) {
        await txn.insert('stock_predictions', {
          'product_id': entry.key,
          'prediction_date': now,
          'predicted_quantity': entry.value,
          'time_horizon': timeHorizon,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getProductPredictions(int productId) async {
    final db = await _sqlDb.db;
    return await db.query(
      'stock_predictions',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'prediction_date DESC',
    );
  }
}