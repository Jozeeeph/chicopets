import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/services/stock_analysis_service.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:caissechicopets/services/stock_prediction_service.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caissechicopets/models/stock_movement.dart';
import 'dart:math' as math;

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  _StockManagementPageState createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  final SqlDb _sqlDb = SqlDb();
  late final StockMovementService _stockMovementService;
  late final StockPredictionService _stockPredictionService;
  late final StockAnalysisService _stockAnalysisService;

  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Map<int, List<Variant>> _productVariants = {};
  final Map<int, double> _productSales = {};
  final Map<int, TextEditingController> _stockControllers = {};
  final TextEditingController _searchController = TextEditingController();
  final Map<int, int> _pendingStockChanges = {};
  final Map<int, Map<int, int>> _pendingVariantChanges = {};
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _stockMovementService = StockMovementService(_sqlDb);
    _stockPredictionService = StockPredictionService(_sqlDb);
    _stockAnalysisService = StockAnalysisService(_sqlDb);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _stockControllers.values.forEach((controller) => controller.dispose());
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text(
            'Vous avez des modifications non enregistrées. Voulez-vous vraiment quitter sans enregistrer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveAllChanges();
              Navigator.of(context).pop(true);
            },
            child: const Text('Enregistrer et quitter'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadData() async {
    try {
      final products = await _sqlDb.getProducts();

      final List<double> sales = await Future.wait<double>(
          products.map((p) => _getProductTotalSales(p.id!)));

      final List<List<Variant>> variants = await Future.wait<List<Variant>>(
          products.map((p) => _sqlDb.getVariantsByProductId(p.id!)));

      for (var product in products) {
        _stockControllers[product.id!] = TextEditingController(
            text: product.hasVariants
                ? variants[products.indexOf(product)]
                    .fold(0, (sum, v) => sum + v.stock)
                    .toString()
                : product.stock.toString());
      }

      setState(() {
        _products = products;
        for (int i = 0; i < products.length; i++) {
          _productSales[products[i].id!] = sales[i];
          _productVariants[products[i].id!] = variants[i];
          if (products[i].hasVariants) {
            products[i].stock = variants[i].fold(0, (sum, v) => sum + v.stock);
          }
        }
        _isLoading = false;
        _pendingStockChanges.clear();
        _pendingVariantChanges.clear();
        _hasUnsavedChanges = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de chargement: ${e.toString()}');
    }
  }

  Future<double> _getProductTotalSales(int productId) async {
    try {
      final db = await _sqlDb.db;
      final result = await db.rawQuery('''
        SELECT SUM(
          CASE 
            WHEN oi.isPercentage = 1 THEN oi.quantity * (oi.prix_unitaire * (1 - oi.discount/100))
            ELSE oi.quantity * (oi.prix_unitaire - oi.discount)
          END
        ) as total_sales
        FROM order_items oi
        JOIN orders o ON oi.id_order = o.id_order
        WHERE (oi.product_id = ? OR oi.product_code IN (
          SELECT code FROM variants WHERE product_id = ?
        )) AND o.status != 'cancelled'
      ''', [productId, productId]);

      return (result.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _updateProductStock(Product product, int newStock) async {
    try {
      final previousStock = product.stock;
      final quantity = (newStock - previousStock).abs();
      final movementType = newStock > previousStock ? 'in' : 'out';

      await _sqlDb.updateProductStock(product.id!, newStock);

      // Enregistrer le mouvement
      await _stockMovementService.recordMovement(StockMovement(
        productId: product.id!,
        movementType: movementType,
        quantity: quantity,
        previousStock: previousStock,
        newStock: newStock,
        movementDate: DateTime.now(),
      ));

      setState(() {
        product.stock = newStock;
        _stockControllers[product.id!]?.text = newStock.toString();
        _updateStatusBasedOnStock(product);
      });
    } catch (e) {
      _showError('Erreur de mise à jour: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _updateProductStatus(Product product, String newStatus) async {
    try {
      final db = await _sqlDb.db;
      await db.update(
        'products',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [product.id],
      );
      setState(() => product.status = newStatus);
    } catch (e) {
      _showError('Erreur de mise à jour: ${e.toString()}');
      rethrow;
    }
  }

  void _updateStatusBasedOnStock(Product product) {
    String newStatus;
    if (product.stock <= 0) {
      newStatus = 'Rupture';
    } else if (product.stock < 10) {
      newStatus = 'Stock faible';
    } else {
      newStatus = 'En stock';
    }

    if (product.status != newStatus) {
      _updateProductStatus(product, newStatus);
    }
  }

  Future<void> _updateVariantStock(Variant variant, int newStock) async {
    try {
      final previousStock = variant.stock;
      final quantity = (newStock - previousStock).abs();
      final movementType = newStock > previousStock ? 'in' : 'out';

      await _sqlDb.updateVariantStock(variant.id!, newStock);

      // Enregistrer le mouvement
      await _stockMovementService.recordMovement(StockMovement(
        productId: variant.productId,
        variantId: variant.id,
        movementType: movementType,
        quantity: quantity,
        previousStock: previousStock,
        newStock: newStock,
        movementDate: DateTime.now(),
      ));

      setState(() {
        variant.stock = newStock;
        _updateProductStockFromVariants(variant.productId);
      });
    } catch (e) {
      _showError('Erreur de mise à jour: ${e.toString()}');
      rethrow;
    }
  }

  void _updateProductStockFromVariants(int productId) {
    final variants = _productVariants[productId] ?? [];
    final totalStock = variants.fold(0, (sum, variant) => sum + variant.stock);

    _stockControllers[productId]?.text = totalStock.toString();

    final product = _products.firstWhere((p) => p.id == productId);
    if (product.stock != totalStock) {
      product.stock = totalStock;
      _updateStatusBasedOnStock(product);
    }
  }

  Future<void> _saveAllChanges() async {
    if (!_hasUnsavedChanges) return;

    try {
      // Confirmation dialog
      final shouldSave = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer les modifications'),
          content: Text(
              'Vous êtes sur le point d\'enregistrer ${_pendingStockChanges.length + _pendingVariantChanges.length} modifications. Continuer ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (shouldSave != true) return;

      // Save product stock changes
      for (final entry in _pendingStockChanges.entries) {
        final product = _products.firstWhere((p) => p.id == entry.key);
        await _updateProductStock(product, entry.value);
      }

      // Save variant stock changes
      for (final productEntry in _pendingVariantChanges.entries) {
        final variants = _productVariants[productEntry.key] ?? [];
        for (final variantEntry in productEntry.value.entries) {
          final variant = variants.firstWhere((v) => v.id == variantEntry.key);
          await _updateVariantStock(variant, variantEntry.value);
        }
      }

      setState(() {
        _pendingStockChanges.clear();
        _pendingVariantChanges.clear();
        _hasUnsavedChanges = false;
      });

      _showSuccess('Toutes les modifications ont été enregistrées');
    } catch (e) {
      _showError('Erreur lors de l\'enregistrement: ${e.toString()}');
    }
  }

  void _discardAllChanges() {
    setState(() {
      _pendingStockChanges.clear();
      _pendingVariantChanges.clear();
      _hasUnsavedChanges = false;
      _loadData(); // Recharger les données originales
    });
    _showSuccess('Modifications annulées');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatExpirationDate(String rawDate) {
    if (rawDate.isEmpty) return 'Non définie';

    try {
      final possibleFormats = [
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd-MM-yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('dd/MM/yyyy'),
      ];

      DateTime? parsedDate;
      for (final format in possibleFormats) {
        try {
          parsedDate = format.parseStrict(rawDate);
          break;
        } catch (_) {}
      }

      if (parsedDate != null) {
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      }
      return 'Format invalide';
    } catch (e) {
      return 'Erreur de date';
    }
  }

  bool _isExpiringSoon(String expirationDate) {
    if (expirationDate.isEmpty) return false;

    try {
      final possibleFormats = [
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd-MM-yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('dd/MM/yyyy'),
      ];

      DateTime? parsedDate;
      for (final format in possibleFormats) {
        try {
          parsedDate = format.parseStrict(expirationDate);
          break;
        } catch (_) {}
      }

      if (parsedDate == null) return false;

      final today = DateTime.now();
      final difference = parsedDate.difference(today).inDays;
      return difference <= 30 && difference >= 0;
    } catch (e) {
      return false;
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) {
      return product.designation.toLowerCase().contains(_searchQuery) ||
          (product.code?.toLowerCase().contains(_searchQuery) ?? false) ||
          (product.categoryName?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  int _getTotalStock(Product product) {
    final variants = _productVariants[product.id] ?? [];
    if (variants.isNotEmpty) {
      return variants.fold(0, (sum, variant) => sum + variant.stock);
    }
    return product.stock;
  }

// stock_management_page.dart (extrait)
 Widget _buildPredictionSection() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: ElevatedButton.icon(
      onPressed: () => _showPredictionsPopup(context),
      icon: const Icon(Icons.analytics, size: 24),
      label: const Text('Voir les prédictions IA'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0056A6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
    ),
  );
}

void _showPredictionsPopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 700,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0056A6), Color(0xFF003B7A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Prédictions Intelligentes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Contenu principal avec onglets
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<Map<String, Map<int, int>>>(
                    future: _stockPredictionService.predictAllStockNeeds(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0056A6)),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Analyse des tendances en cours...',
                                style: TextStyle(
                                  color: Color(0xFF0056A6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 50),
                              const SizedBox(height: 16),
                              Text(
                                'Erreur d\'analyse',
                                style: TextStyle(
                                  color: Colors.red[800],
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0056A6),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      }

                      final predictions = snapshot.data ?? {
                        'short_term': {},
                        'medium_term': {},
                        'long_term': {},
                      };

                      return Column(
                        children: [
                          // Barre d'info et bouton d'actualisation
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F9FF),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFE0ECFF),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lightbulb_outline, color: Color(0xFFFFC107), size: 28),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Les prédictions sont calculées en fonction des tendances de vente et des variations saisonnières',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF555555),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final predictions = await _stockPredictionService.predictAllStockNeeds();
                                      await _stockPredictionService.savePredictions(
                                        predictions['short_term']!, 
                                        timeHorizon: 'short_term'
                                      );
                                      await _stockPredictionService.savePredictions(
                                        predictions['medium_term']!, 
                                        timeHorizon: 'medium_term'
                                      );
                                      await _stockPredictionService.savePredictions(
                                        predictions['long_term']!, 
                                        timeHorizon: 'long_term'
                                      );
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Prédictions actualisées avec succès'),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.refresh, size: 20),
                                  label: const Text('Actualiser'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0056A6),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFF0056A6), width: 1),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Onglets
                          Expanded(
                            child: DefaultTabController(
                              length: 3,
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TabBar(
                                      labelColor: Colors.white,
                                      unselectedLabelColor: const Color(0xFF0056A6),
                                      indicator: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0056A6), Color(0xFF0075E1)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      tabs: const [
                                        Tab(
                                          icon: Icon(Icons.timelapse, size: 20),
                                          text: 'Court Terme (30j)',
                                        ),
                                        Tab(
                                          icon: Icon(Icons.calendar_today, size: 20),
                                          text: 'Moyen Terme (90j)',
                                        ),
                                        Tab(
                                          icon: Icon(Icons.date_range, size: 20),
                                          text: 'Long Terme (1 an)',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Contenu des onglets
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        _buildPredictionContent(predictions['short_term']!, '30 jours'),
                                        _buildPredictionContent(predictions['medium_term']!, '90 jours'),
                                        _buildPredictionContent(predictions['long_term']!, '1 an'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildPredictionContent(Map<int, int> predictions, String timeHorizon) {
  if (_products.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 60, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'Aucun produit disponible',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  final productsWithPredictions = _products.where((p) => predictions.containsKey(p.id)).toList();

  if (productsWithPredictions.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'Pas de prédictions pour $timeHorizon',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text(
            'Les données historiques sont insuffisantes',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    itemCount: productsWithPredictions.length,
    itemBuilder: (context, index) {
      final product = productsWithPredictions[index];
      final prediction = predictions[product.id!] ?? 0;
      final stockNeeded = prediction - product.stock;
      final percentage = product.stock > 0 
          ? (stockNeeded / product.stock * 100).clamp(0, 200).toInt()
          : 100;

      // Déterminer le style en fonction du besoin
      Color cardColor;
      Color textColor;
      IconData icon;
      String status;
      Color statusColor;
      
      if (stockNeeded > product.stock * 0.5) {
        cardColor = const Color(0xFFFFF0F0);
        textColor = const Color(0xFFD32F2F);
        icon = Icons.warning_amber_rounded;
        status = 'Urgent';
        statusColor = const Color(0xFFD32F2F);
      } else if (stockNeeded > 0) {
        cardColor = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFF57C00);
        icon = Icons.trending_up;
        status = 'À surveiller';
        statusColor = const Color(0xFFF57C00);
      } else {
        cardColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF388E3C);
        icon = Icons.check_circle_outline;
        status = 'OK';
        statusColor = const Color(0xFF388E3C);
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          borderRadius: BorderRadius.circular(15),
          color: cardColor,
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => _showPredictionDetails(context, product, prediction, timeHorizon),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icône
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  // Détails du produit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.designation,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildInfoChip(
                              'Stock: ${product.stock}',
                              Icons.inventory_2,
                              const Color(0xFF0056A6),
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              'Prédit: $prediction',
                              Icons.analytics,
                              const Color(0xFF5C6BC0),
                            ),
                          ],
                        ),
                        if (stockNeeded > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildAlertChip(
                                'Besoin: $stockNeeded',
                                Icons.add_shopping_cart,
                                statusColor,
                              ),
                              const SizedBox(width: 8),
                              _buildAlertChip(
                                '+$percentage%',
                                percentage > 50 ? Icons.arrow_upward : Icons.trending_up,
                                statusColor,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildInfoChip(String text, IconData icon, Color color) {
  return Chip(
    backgroundColor: color.withOpacity(0.1),
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    avatar: Icon(icon, size: 16, color: color),
    label: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
      ),
    ),
  );
}

Widget _buildAlertChip(String text, IconData icon, Color color) {
  return Chip(
    backgroundColor: color.withOpacity(0.2),
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    avatar: Icon(icon, size: 16, color: color),
    label: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
Widget _buildPredictionCard(Map<int, int> predictions, String timeHorizon) {
  if (_products.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 50, color: Colors.grey),
          SizedBox(height: 16),
          Text('Aucun produit disponible'),
        ],
      ),
    );
  }

  final productsWithPredictions = _products.where((p) => predictions.containsKey(p.id)).toList();

  if (productsWithPredictions.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 50, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Aucune prédiction pour $timeHorizon'),
        ],
      ),
    );
  }

  return ListView.builder(
    itemCount: productsWithPredictions.length,
    itemBuilder: (context, index) {
      final product = productsWithPredictions[index];
      final prediction = predictions[product.id!] ?? 0;
      final stockNeeded = prediction - product.stock;
      final percentage = product.stock > 0 
          ? (stockNeeded / product.stock * 100).clamp(0, 200).toInt()
          : 100;

      Color cardColor;
      IconData icon;
      String status;
      
      if (stockNeeded > product.stock * 0.5) {
        cardColor = Colors.red[50]!;
        icon = Icons.warning_amber_rounded;
        status = 'Urgent';
      } else if (stockNeeded > 0) {
        cardColor = Colors.orange[50]!;
        icon = Icons.trending_up;
        status = 'À surveiller';
      } else {
        cardColor = Colors.green[50]!;
        icon = Icons.check_circle_outline;
        status = 'OK';
      }

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showPredictionDetails(context, product, prediction, timeHorizon),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056A6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF0056A6)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.designation,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock actuel: ${product.stock} | Prédit: $prediction',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (stockNeeded > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Besoin estimé: $stockNeeded (+$percentage%)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0056A6)),
                        ),
                      ],
                    ],
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0xFF0056A6).withOpacity(0.1),
                  label: Text(status,
                    style: TextStyle(
                      color: status == 'Urgent' 
                        ? Colors.red[800]
                        : status == 'À surveiller'
                          ? Colors.orange[800]
                          : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildPredictionList(Map<int, int> predictions, String timeHorizon) {
  if (_products.isEmpty) {
    return const Center(child: Text('Aucun produit disponible'));
  }

  // Filtrer les produits qui ont une prédiction
  final productsWithPredictions = _products.where((p) => predictions.containsKey(p.id)).toList();

  if (productsWithPredictions.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 50, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Aucune prédiction disponible pour $timeHorizon'),
        ],
      ),
    );
  }

  return ListView.builder(
    itemCount: productsWithPredictions.length,
    itemBuilder: (context, index) {
      final product = productsWithPredictions[index];
      final prediction = predictions[product.id!] ?? 0;
      final stockNeeded = prediction - product.stock;

      // Calculer le niveau d'urgence
      Color color;
      String status;
      if (stockNeeded > product.stock * 0.5) {
        color = Colors.red[100]!;
        status = 'Urgent';
      } else if (stockNeeded > 0) {
        color = Colors.orange[100]!;
        status = 'À surveiller';
      } else {
        color = Colors.green[100]!;
        status = 'OK';
      }

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: color,
        child: ListTile(
          title: Text(product.designation),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stock actuel: ${product.stock}'),
              Text('Ventes prédites: ${prediction}'),
              if (stockNeeded > 0)
                Text('Besoin: $stockNeeded', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Statut: $status'),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showPredictionDetails(context, product, prediction, timeHorizon);
            },
          ),
        ),
      );
    },
  );
}

void _showPredictionDetails(BuildContext context, Product product, int prediction, String timeHorizon) {
  final stockNeeded = prediction - product.stock;
  final percentage = product.stock > 0 
      ? (stockNeeded / product.stock * 100).clamp(0, 200).toInt()
      : 100;

  // Détermination du niveau d'urgence
  Color primaryColor;
  IconData statusIcon;
  String statusText;

  if (stockNeeded > product.stock * 0.5) {
    primaryColor = const Color(0xFFD32F2F); // Rouge
    statusIcon = Icons.warning_rounded;
    statusText = 'Niveau Critique';
  } else if (stockNeeded > 0) {
    primaryColor = const Color(0xFFF57C00); // Orange
    statusIcon = Icons.trending_up_rounded;
    statusText = 'Attention Requise';
  } else {
    primaryColor = const Color(0xFF388E3C); // Vert
    statusIcon = Icons.check_circle_rounded;
    statusText = 'Stock Suffisant';
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête avec dégradé
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: Colors.white, size: 30),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.designation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Corps
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Détails principaux
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailCard(
                        title: 'Stock Actuel',
                        value: product.stock.toString(),
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF0056A6),
                      ),
                      _buildDetailCard(
                        title: 'Prédiction $timeHorizon',
                        value: prediction.toString(),
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF673AB7),
                      ),
                      if (stockNeeded > 0)
                        _buildDetailCard(
                          title: 'Besoin Estimé',
                          value: stockNeeded.toString(),
                          icon: Icons.add_shopping_cart_rounded,
                          color: primaryColor,
                        ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Historique des prévisions
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _stockPredictionService.getProductPredictions(product.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'Aucun historique de prédiction disponible',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final predictions = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historique des Prévisions',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...predictions.take(3).map((pred) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _getTimeHorizonIcon(pred['time_horizon']),
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${pred['time_horizon']}: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${pred['predicted_quantity']} unités',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(
                                    DateTime.parse(pred['prediction_date']),
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Pied de page
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: 10),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildDetailCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

IconData _getTimeHorizonIcon(String horizon) {
  switch (horizon.toLowerCase()) {
    case 'short_term':
      return Icons.timelapse_rounded;
    case 'medium_term':
      return Icons.calendar_today_rounded;
    case 'long_term':
      return Icons.date_range_rounded;
    default:
      return Icons.timeline_rounded;
  }
}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion de Stock'),
          backgroundColor: const Color(0xFF0056A6),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Rechercher...',
                    hintText: 'Code, désignation ou catégorie',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF0056A6)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.orange[100],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                            '${_pendingStockChanges.length + _pendingVariantChanges.length} modifications non enregistrées'),
                        const Spacer(),
                        TextButton(
                          onPressed: _discardAllChanges,
                          child: const Text('Annuler tout'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveAllChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Enregistrer tout',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _buildPredictionSection(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                      ? _buildEmptyState()
                      : _buildProductTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2,
              size: 60, color: const Color(0xFF0056A6).withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0056A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTable() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // En-têtes du tableau
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0056A6).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      flex: 2, child: Text('Code', style: _headerTextStyle())),
                  Expanded(
                      flex: 3,
                      child: Text('Désignation', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Catégorie', style: _headerTextStyle())),
                  Expanded(
                      flex: 1, child: Text('Stock', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Statut', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Prix Achat', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Prix Vente', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Profit', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Expiration', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Ventes', style: _headerTextStyle())),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Contenu sous forme de cartes
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final variants = _productVariants[product.id] ?? [];
                final totalStock = _getTotalStock(product);
                final isExpiring = _isExpiringSoon(product.dateExpiration);
                final hasPendingChanges =
                    _pendingStockChanges.containsKey(product.id) ||
                        _pendingVariantChanges.containsKey(product.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  color: hasPendingChanges ? Colors.orange[50] : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text(product.code ?? 'N/A',
                                    style: _cellTextStyle())),
                            Expanded(
                                flex: 3,
                                child: Text(product.designation,
                                    style: _cellTextStyle())),
                            Expanded(
                                flex: 2,
                                child: Text(product.categoryName ?? 'N/A',
                                    style: _cellTextStyle())),
                            Expanded(
                              flex: 1,
                              child: product.hasVariants
                                  ? TextFormField(
                                      controller:
                                          _stockControllers[product.id!],
                                      enabled: false,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    )
                                  : TextFormField(
                                      controller:
                                          _stockControllers[product.id!],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final newStock = int.tryParse(value) ??
                                            product.stock;
                                        setState(() {
                                          _pendingStockChanges[product.id!] =
                                              newStock;
                                          _hasUnsavedChanges = true;
                                        });
                                      },
                                    ),
                            ),
                            Expanded(
                                flex: 2,
                                child: _buildStatusIndicator(product.status)),
                            Expanded(
                                flex: 2,
                                child: Text(
                                    '${product.prixHT.toStringAsFixed(2)} DT',
                                    style: _cellTextStyle())),
                            Expanded(
                                flex: 2,
                                child: Text(
                                    '${product.prixTTC.toStringAsFixed(2)} DT',
                                    style: _cellTextStyle())),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${(product.prixTTC - product.prixHT).toStringAsFixed(2)} DT',
                                style: _cellTextStyle()
                                    .copyWith(color: Colors.green),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatExpirationDate(product.dateExpiration),
                                style: _cellTextStyle().copyWith(
                                  color: isExpiring ? Colors.red : null,
                                  fontWeight:
                                      isExpiring ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  '${_productSales[product.id]?.toStringAsFixed(2) ?? '0.00'} DT',
                                  style: _cellTextStyle()),
                            ),
                          ],
                        ),
                        if (variants.isNotEmpty) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Variantes:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                ...variants.map((v) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_right,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${v.combinationName} - Prix: ${v.finalPrice.toStringAsFixed(2)} DT',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              initialValue:
                                                  _pendingVariantChanges[
                                                              product.id]?[v.id]
                                                          ?.toString() ??
                                                      v.stock.toString(),
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Stock',
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 8),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                final newStock =
                                                    int.tryParse(value) ??
                                                        v.stock;
                                                setState(() {
                                                  if (v.id != null) {
                                                    if (!_pendingVariantChanges
                                                        .containsKey(
                                                            product.id)) {
                                                      _pendingVariantChanges[
                                                          product.id!] = {};
                                                    }
                                                    _pendingVariantChanges[
                                                            product
                                                                .id!]![v.id!] =
                                                        newStock;
                                                    _hasUnsavedChanges = true;
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 8),
                                Text(
                                  'Stock total variantes: ${variants.fold(0, (sum, v) => sum + (_pendingVariantChanges[product.id]?[v.id] ?? v.stock))}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    switch (status) {
      case 'En stock':
        color = Colors.green;
        break;
      case 'Stock faible':
        color = Colors.orange;
        break;
      case 'Rupture':
        color = Colors.red;
        break;
      case 'Discontinué':
        color = Colors.grey;
        break;
      default:
        color = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  TextStyle _headerTextStyle() {
    return const TextStyle(
      fontWeight: FontWeight.bold,
      color: Color(0xFF0056A6),
      fontSize: 14,
    );
  }

  TextStyle _cellTextStyle() {
    return const TextStyle(
      fontSize: 14,
      color: Color.fromARGB(255, 1, 42, 79),
    );
  }
}
