import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/services/sqldb.dart';
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

    // Ajoutez un délai minimal pour simuler l'entraînement
    await Future.delayed(const Duration(seconds: 2));

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
    List<Map<String, dynamic>> data = [];

    try {
      // Essayer de récupérer les données réelles
      data = await db.rawQuery('''
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
        debugPrint("Utilisation de données de test pour l'entraînement");
        final now = DateTime.now();
        final lastMonth = DateTime(now.year, now.month - 1, now.day);
        final twoMonthsAgo = DateTime(now.year, now.month - 2, now.day);

        // Données de test complètes et variées
        data = [
          // Produit 1 - Historique stable
          {
            'product_id': 1,
            'stock_in': 100,
            'current_stock': 25,
            'month': twoMonthsAgo.month,
            'weekday': DateTime.monday,
            'avg_sale': 8,
            'sales': 75
          },
          {
            'product_id': 1,
            'stock_in': 80,
            'current_stock': 30,
            'month': lastMonth.month,
            'weekday': DateTime.tuesday,
            'avg_sale': 7,
            'sales': 70
          },
          {
            'product_id': 1,
            'stock_in': 60,
            'current_stock': 20,
            'month': now.month,
            'weekday': now.weekday,
            'avg_sale': 7.5,
            'sales': 60
          },

          // Produit 2 - Ventes saisonnières (été)
          {
            'product_id': 2,
            'stock_in': 150,
            'current_stock': 10,
            'month': DateTime.june,
            'weekday': DateTime.friday,
            'avg_sale': 12,
            'sales': 140
          },
          {
            'product_id': 2,
            'stock_in': 50,
            'current_stock': 40,
            'month': DateTime.september,
            'weekday': DateTime.saturday,
            'avg_sale': 5,
            'sales': 45
          },

          // Produit 3 - Ventes en semaine vs weekend
          {
            'product_id': 3,
            'stock_in': 60,
            'current_stock': 15,
            'month': now.month,
            'weekday': DateTime.friday,
            'avg_sale': 10,
            'sales': 45
          },
          {
            'product_id': 3,
            'stock_in': 60,
            'current_stock': 30,
            'month': now.month,
            'weekday': DateTime.monday,
            'avg_sale': 6,
            'sales': 30
          },

          // Produit 4 - Stock faible
          {
            'product_id': 4,
            'stock_in': 20,
            'current_stock': 2,
            'month': now.month,
            'weekday': now.weekday,
            'avg_sale': 3,
            'sales': 18
          },

          // Produit 5 - Nouveau produit (peu de données)
          {
            'product_id': 5,
            'stock_in': 30,
            'current_stock': 12,
            'month': now.month,
            'weekday': now.weekday,
            'avg_sale': 2,
            'sales': 18
          }
        ];
      }

      _createModel(data);
      // N'affiche que en mode debug
      printTestPredictions();
    } catch (e) {
      debugPrint("Erreur lors de l'entraînement: $e");
      // En cas d'erreur, utilisez des données de base minimales
      final now = DateTime.now();
      _createModel([
        {
          'product_id': 0,
          'stock_in': 0,
          'current_stock': 0,
          'month': now.month,
          'weekday': now.weekday,
          'avg_sale': 0,
          'sales': 0
        }
      ]);
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

  Future<Map<int, int>> predictStockNeeds(
      {int timeHorizon = 30, bool debugMode = false}) async {
    try {
      if (debugMode) {
        debugPrint("╔═══════════════════════════════════════════");
        debugPrint("║ MODE DEBUG - PRÉDICTIONS AVEC DONNÉES TEST");
        debugPrint("╚═══════════════════════════════════════════");
      }
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

  void printTestPredictions() {
    final now = DateTime.now();
    final testProducts = [
      {
        'id': 1,
        'stock': 25,
        'name': 'Nourriture pour chien Premium',
        'type': 'Alimentation'
      },
      {
        'id': 2,
        'stock': 10,
        'name': 'Piscine pour chien',
        'type': 'Accessoire été'
      },
      {'id': 3, 'stock': 15, 'name': 'Jouet à mâcher', 'type': 'Jouet'},
      {'id': 4, 'stock': 2, 'name': 'Laisse ergonomique', 'type': 'Accessoire'},
      {'id': 5, 'stock': 12, 'name': 'Nouveau produit test', 'type': 'Test'}
    ];

    debugPrint("\n\n╔═══════════════════════════════════════════");
    debugPrint("║ PRÉDICTIONS POUR LES PRODUITS DE TEST");
    debugPrint("╟───────────────────────────────────────");

    for (var product in testProducts) {
      final features = [
        product['id'],
        0.0, // stock_in
        product['stock'],
        now.month.toDouble(),
        now.weekday.toDouble(),
        5.0, 
      ];

      final featuresDf = DataFrame([features], header: _featureNames);
      final prediction = _model!.predict(featuresDf).rows.first.first as num;
      final predictedSales = prediction.toInt();
      final stockNeeded = (predictedSales * (30 / 30)).round() -
          (product['stock'] as num).toInt();

      debugPrint("║ Produit #${product['id']}: ${product['name']}");
      debugPrint("║ Type: ${product['type']}");
      debugPrint("║ Stock actuel: ${product['stock']}");
      debugPrint("║ Prédiction mensuelle: $predictedSales");
      debugPrint("║ Besoin estimé: ${stockNeeded > 0 ? stockNeeded : 0}");
      debugPrint("║───────────────────────────────────────");
    }
    debugPrint("╚═══════════════════════════════════════════\n\n");
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

      double avgSales = result.first['avg_sales'] as double? ?? 0;

      // Si pas de données, utilisez une valeur par défaut réaliste
      if (avgSales == 0) {
        avgSales = 3.0; // Valeur par défaut pour les tests
      }

      final product = await _sqlDb.getProductById(productId);
      final currentStock = product?.stock ?? 0;
      final predictedSales = (avgSales * (timeHorizon / 30)).round();
      final stockNeeded = predictedSales - currentStock;

      return stockNeeded > 0 ? stockNeeded : 0;
    } catch (e) {
      debugPrint("Erreur dans simplePredictionForProduct: $e");
      // Retourne une prédiction par défaut
      return 5; // Valeur par défaut pour les tests
    }
  }

  Future<Map<String, dynamic>> predictAllStockNeeds() async {
    final shortTermProducts = await predictStockNeeds(timeHorizon: 30);
    final mediumTermProducts = await predictStockNeeds(timeHorizon: 90);
    final longTermProducts = await predictStockNeeds(timeHorizon: 365);

    final shortTermVariants = await predictVariantStockNeeds(timeHorizon: 30);
    final mediumTermVariants = await predictVariantStockNeeds(timeHorizon: 90);
    final longTermVariants = await predictVariantStockNeeds(timeHorizon: 365);

    return {
      'products': {
        'short_term': shortTermProducts,
        'medium_term': mediumTermProducts,
        'long_term': longTermProducts,
      },
      'variants': {
        'short_term': shortTermVariants,
        'medium_term': mediumTermVariants,
        'long_term': longTermVariants,
      },
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

  Future<List<Map<String, dynamic>>> getProductPredictions(
      int productId) async {
    final db = await _sqlDb.db;
    return await db.query(
      'stock_predictions',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'prediction_date DESC',
    );
  }

  Future<Map<int, Map<int, int>>> predictVariantStockNeeds(
      {int timeHorizon = 30}) async {
    try {
      // Utilisez la méthode simplifiée pour les variantes
      return await _simpleVariantStockPrediction(timeHorizon);
    } catch (e) {
      debugPrint("Erreur dans predictVariantStockNeeds: $e");
      return {};
    }
  }

  Future<Map<int, Map<int, int>>> _simpleVariantStockPrediction(
      int timeHorizon) async {
    final variants = await _getAllVariantsWithSales();
    final predictions = <int, Map<int, int>>{};

    for (final variant in variants) {
      final productId = variant.productId;
      final variantId = variant.id!;

      if (!predictions.containsKey(productId)) {
        predictions[productId] = {};
      }

      predictions[productId]![variantId] =
          await _simplePredictionForVariant(variantId, timeHorizon);
    }

    return predictions;
  }

  Future<int> _simplePredictionForVariant(
      int variantId, int timeHorizon) async {
    final db = await _sqlDb.db;
    try {
      final result = await db.rawQuery('''
      SELECT AVG(quantity) as avg_sales 
      FROM stock_movements 
      WHERE variant_id = ? 
      AND movement_type = 'sale'
      AND movement_date >= date('now', '-3 months')
    ''', [variantId]);

      final avgSales = result.first['avg_sales'] as double? ?? 0;
      final variant = await _sqlDb.getVariantById(variantId);
      final currentStock = variant?.stock ?? 0;
      final predictedSales = (avgSales * (timeHorizon / 30)).round();
      final stockNeeded = predictedSales - currentStock;

      return stockNeeded > 0 ? stockNeeded : 0;
    } catch (e) {
      debugPrint("Erreur dans simplePredictionForVariant: $e");
      return 0;
    }
  }

  Future<List<Variant>> _getAllVariantsWithSales() async {
    final db = await _sqlDb.db;
    final result = await db.rawQuery('''
    SELECT DISTINCT v.* 
    FROM variants v
    JOIN stock_movements sm ON sm.variant_id = v.id
    WHERE sm.movement_type = 'sale'
  ''');

    return result.map((map) => Variant.fromMap(map)).toList();
  }
}
