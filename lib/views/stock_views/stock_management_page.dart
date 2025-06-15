import 'dart:async';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:caissechicopets/services/stock_prediction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:intl/intl.dart';
import 'package:caissechicopets/models/stock_movement.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  _StockManagementPageState createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  final SqlDb _sqlDb = SqlDb();
  late final StockMovementService _stockMovementService;
  late final StockPredictionService _stockPredictionService;
  final List<String> _stockAdjustmentReasons = [
    'Retour client',
    'Produit cassé',
    'Produit volé',
    'Erreur d\'inventaire',
    'Ajustement manuel',
    'Collecte par le gérant',
    'Autre raison'
  ];

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
  final Map<String, dynamic> _predictions = {
    'products': {
      'short_term': {},
      'medium_term': {},
      'long_term': {},
    },
    'variants': {
      'short_term': {},
      'medium_term': {},
      'long_term': {},
    }
  };

  final Map<int, StockMovement?> _pendingCollections = {};
  final Map<int, StockMovement?> _readyForConfirmation = {};

  @override
  void initState() {
    super.initState();
    _stockMovementService = StockMovementService(_sqlDb);
    _stockPredictionService = StockPredictionService(_sqlDb);
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

  String _getCollectionCountdown(StockMovement movement) {
    final now = DateTime.now();
    final difference = movement.movementDate.difference(now);
    if (difference.isNegative) return 'En retard';
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    return days > 0 ? 'Dans $days jour(s)' : 'Dans $hours heure(s)';
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
      final predictions = await _stockPredictionService.predictAllStockNeeds();

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
        _predictions['products'] = predictions['products'] ??
            {
              'short_term': {},
              'medium_term': {},
              'long_term': {},
            };
        _predictions['variants'] = predictions['variants'] ??
            {
              'short_term': {},
              'medium_term': {},
              'long_term': {},
            };
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

  Future<void> _updateProductStock(Product product, int newStock,
      {String? reason}) async {
    try {
      final previousStock = product.stock;
      final quantity = (newStock - previousStock).abs();
      final movementType = newStock > previousStock ? 'in' : 'out';

      await _sqlDb.updateProductStock(product.id!, newStock);

      await _stockMovementService.recordMovement(StockMovement(
        productId: product.id!,
        movementType: movementType,
        quantity: quantity,
        previousStock: previousStock,
        newStock: newStock,
        movementDate: DateTime.now(),
        notes: reason ?? 'Ajustement manuel',
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

  Future<void> _updateVariantStock(Variant variant, int newStock,
      {String? reason}) async {
    try {
      final previousStock = variant.stock;
      final quantity = (newStock - previousStock).abs();
      final movementType = newStock > previousStock ? 'in' : 'out';

      await _sqlDb.updateVariantStock(variant.id!, newStock);

      await _stockMovementService.recordMovement(StockMovement(
        productId: variant.productId,
        variantId: variant.id,
        movementType: movementType,
        quantity: quantity,
        previousStock: previousStock,
        newStock: newStock,
        movementDate: DateTime.now(),
        notes: reason ?? 'Ajustement manuel',
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
      final reason = await _showReasonSelectionDialog(context);
      if (reason == null) return;

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

      for (final entry in _pendingStockChanges.entries) {
        final product = _products.firstWhere((p) => p.id == entry.key);
        final newStock = entry.value;
        final previousStock = product.stock;
        final quantity = (newStock - previousStock).abs();
        if (quantity <= 0) continue;

        await _updateProductStock(product, newStock, reason: reason);
      }

      for (final productEntry in _pendingVariantChanges.entries) {
        final variants = _productVariants[productEntry.key] ?? [];
        for (final variantEntry in productEntry.value.entries) {
          final variant = variants.firstWhere((v) => v.id == variantEntry.key);
          final newStock = variantEntry.value;
          final previousStock = variant.stock;
          final quantity = (newStock - previousStock).abs();
          if (quantity <= 0) continue;

          await _updateVariantStock(variant, newStock, reason: reason);
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
      _loadData();
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

  Future<List<StockMovement>> _getProductMovements(int productId) async {
    try {
      final movements =
          await _stockMovementService.getMovementsForProduct(productId);
      movements.sort((a, b) => b.movementDate.compareTo(a.movementDate));
      return movements;
    } catch (e) {
      _showError('Erreur de chargement des mouvements: ${e.toString()}');
      return [];
    }
  }

  Widget _buildMovementsDialog(
      BuildContext context, List<StockMovement> movements) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historique des mouvements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0056A6),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey[600],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: movements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun mouvement enregistré',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: movements.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final movement = movements[index];
                        final isIn = movement.movementType == 'in';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getMovementColor(
                                                    movement.movementType)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getMovementColor(
                                                      movement.movementType)
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            _getMovementTypeLabel(
                                                movement.movementType),
                                            style: TextStyle(
                                              color: _getMovementColor(
                                                  movement.movementType),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${movement.quantity} unités',
                                          style: TextStyle(
                                            color: _getMovementColor(
                                                movement.movementType),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      DateFormat('dd/MM/yy HH:mm')
                                          .format(movement.movementDate),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      'Stock: ',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${movement.previousStock}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward,
                                        size: 16, color: Colors.grey),
                                    Text(
                                      '${movement.newStock}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isIn ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                if (movement.notes != null &&
                                    movement.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        movement.notes!,
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMovementColor(String movementType) {
    switch (movementType) {
      case 'in':
        return Colors.green;
      case 'out':
        return Colors.red;
      case 'sale':
        return Colors.blue;
      case 'loss':
        return Colors.orange;
      case 'adjustment':
        return Colors.purple;
      case 'transfer':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getMovementTypeLabel(String movementType) {
    switch (movementType) {
      case 'in':
        return 'Entrée stock';
      case 'out':
        return 'Sortie stock';
      case 'sale':
        return 'Vente';
      case 'loss':
        return 'Perte';
      case 'adjustment':
        return 'Ajustement';
      case 'transfer':
        return 'Transfert';
      default:
        return movementType;
    }
  }

  void _showAddMovementDialog(Product product) {
    final _formKey = GlobalKey<FormState>();
    String _movementType = 'in';
    int _quantity = 0;
    String? _notes;
    int? _variantId;
    String? _reason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nouveau mouvement',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _movementType,
                      items: const [
                        DropdownMenuItem(
                            value: 'in', child: Text('Entrée stock')),
                        DropdownMenuItem(
                            value: 'out', child: Text('Sortie stock')),
                        DropdownMenuItem(value: 'sale', child: Text('Vente')),
                        DropdownMenuItem(value: 'loss', child: Text('Perte')),
                        DropdownMenuItem(
                            value: 'adjustment', child: Text('Ajustement')),
                      ],
                      onChanged: (value) =>
                          setState(() => _movementType = value!),
                      decoration: const InputDecoration(
                        labelText: 'Type de mouvement',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_productVariants[product.id]?.isNotEmpty ?? false)
                      Column(
                        children: [
                          DropdownButtonFormField<int>(
                            value: _variantId,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Produit principal'),
                              ),
                              ..._productVariants[product.id]!.map(
                                (v) => DropdownMenuItem(
                                  value: v.id,
                                  child: Text('Variante: ${v.combinationName}'),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _variantId = value),
                            decoration: const InputDecoration(
                              labelText: 'Variante (optionnel)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantité',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Champ obligatoire';
                        if (int.tryParse(value) == null)
                          return 'Nombre invalide';
                        return null;
                      },
                      onSaved: (value) => _quantity = int.parse(value!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _reason,
                      items: _stockAdjustmentReasons
                          .map((reason) => DropdownMenuItem(
                                value: reason,
                                child: Text(reason),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _reason = value),
                      decoration: const InputDecoration(
                        labelText: 'Raison',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null
                          ? 'Veuillez sélectionner une raison'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Notes (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onSaved: (value) => _notes = value,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();

                              try {
                                final previousStock = _variantId != null
                                    ? _productVariants[product.id]!
                                        .firstWhere((v) => v.id == _variantId)
                                        .stock
                                    : product.stock;

                                final newStock = _movementType == 'in'
                                    ? previousStock + _quantity
                                    : previousStock - _quantity;

                                final movement = StockMovement(
                                  productId: product.id!,
                                  variantId: _variantId,
                                  movementType: _movementType,
                                  quantity: _quantity,
                                  previousStock: previousStock,
                                  newStock: newStock,
                                  movementDate: DateTime.now(),
                                  notes: _reason != null
                                      ? 'Raison: $_reason${_notes != null ? ' - $_notes' : ''}'
                                      : _notes,
                                );

                                await _stockMovementService
                                    .recordMovement(movement);

                                if (_variantId != null) {
                                  await _updateVariantStock(
                                    _productVariants[product.id]!
                                        .firstWhere((v) => v.id == _variantId),
                                    newStock,
                                    reason: _reason,
                                  );
                                } else {
                                  await _updateProductStock(product, newStock,
                                      reason: _reason);
                                }

                                Navigator.pop(context);
                                _showSuccess(
                                    'Mouvement enregistré avec succès');
                                _loadData();
                              } catch (e) {
                                _showError('Erreur: ${e.toString()}');
                              }
                            }
                          },
                          child: const Text('Enregistrer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmCollectionDialog(Product product, StockMovement collection) {
    final _formKey = GlobalKey<FormState>();
    int _quantity = collection.quantity;

    // Define color palette
    final Color deepBlue = const Color(0xFF0056A6);
    final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
    final Color white = Colors.white;
    final Color lightGray = const Color(0xFFE0E0E0);
    final Color tealGreen = const Color(0xFF009688);
    final Color warmRed = const Color(0xFFE53935);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 5,
        backgroundColor: white,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: deepBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Confirmer la collecte',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: lightGray, thickness: 1),
                const SizedBox(height: 16),
                // Product designation
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: lightGray.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: tealGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Produit: ${product.designation}',
                          style: TextStyle(fontSize: 16, color: darkBlue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Quantity field
                TextFormField(
                  initialValue: _quantity.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantité collectée',
                    labelStyle: TextStyle(color: darkBlue),
                    prefixIcon: Icon(Icons.numbers, color: tealGreen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: lightGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: deepBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: lightGray.withOpacity(0.2),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Champ obligatoire';
                    if (int.tryParse(value) == null || int.parse(value) < 0)
                      return 'Nombre invalide';
                    return null;
                  },
                  onSaved: (value) => _quantity = int.parse(value!),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _readyForConfirmation.remove(product.id);
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: warmRed,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: warmRed),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 18, color: warmRed),
                          const SizedBox(width: 8),
                          Text(
                            'Annuler',
                            style: TextStyle(
                              color: warmRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          try {
                            Navigator.pop(context);
                            setState(() {
                              _readyForConfirmation.remove(product.id);
                            });
                            _showSuccess('Collecte confirmée avec succès');
                            _loadData();
                          } catch (e) {
                            _showError('Erreur: ${e.toString()}');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deepBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Confirmer',
                            style: TextStyle(
                              color: white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showReasonSelectionDialog(BuildContext context) async {
    String? selectedReason;
    final TextEditingController _customReasonController =
        TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width < 400
                ? MediaQuery.of(context).size.width * 0.9
                : 400,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sélectionnez une raison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0056A6),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _stockAdjustmentReasons.map((reason) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                selectedReason = reason;
                                if (reason != 'Autre raison') {
                                  _customReasonController.clear();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: selectedReason == reason
                                    ? const Color(0xFF0056A6).withOpacity(0.1)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedReason == reason
                                      ? const Color(0xFF0056A6)
                                      : Colors.grey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selectedReason == reason
                                            ? const Color(0xFF0056A6)
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: selectedReason == reason
                                        ? const Icon(Icons.check,
                                            size: 14, color: Color(0xFF0056A6))
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: selectedReason == reason
                                            ? const Color(0xFF0056A6)
                                            : Colors.grey[800],
                                        fontWeight: selectedReason == reason
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (selectedReason == 'Autre raison') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _customReasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Décrivez la raison',
                        hintText: 'Entrez la raison de l\'ajustement...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF0056A6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF0056A6), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        selectedReason = value;
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedReason != null &&
                              (selectedReason != 'Autre raison' ||
                                  _customReasonController.text.isNotEmpty)) {
                            Navigator.pop(
                                context,
                                selectedReason == 'Autre raison'
                                    ? _customReasonController.text
                                    : selectedReason);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0056A6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirmer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    try {
      final barcode = await FlutterBarcodeScanner.scanBarcode(
        '#FF0056A6', // Scanner line color
        'Annuler', // Cancel button text
        true, // Show flash option
        ScanMode.BARCODE, // Scan mode
      );

      if (barcode != '-1') {
        // -1 is returned when scan is cancelled
        _searchController.text = barcode;
        _filterProducts(barcode);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de scan: ${e.toString()}')),
      );
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_filteredProducts.isNotEmpty) {
              _showAddMovementDialog(_filteredProducts.first);
            }
          },
          child: const Icon(Icons.add),
          backgroundColor: const Color(0xFF0056A6),
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
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.barcode_reader,
                          color: Color(0xFF0056A6)),
                      onPressed: _scanBarcode,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (value) {
                    // Your existing search logic
                    _filterProducts(value);
                  },
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
                  Expanded(
                      flex: 2,
                      child:
                          Text('Prédiction (30j)', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Collecte', style: _headerTextStyle())),
                  Expanded(
                      flex: 1, child: Text('MVMT', style: _headerTextStyle())),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final variants = _productVariants[product.id] ?? [];
                final isExpiring = _isExpiringSoon(product.dateExpiration);
                final hasPendingChanges =
                    _pendingStockChanges.containsKey(product.id) ||
                        _pendingVariantChanges.containsKey(product.id);
                final shortTermPrediction =
                    _predictions['products']['short_term']?[product.id] ?? 0;
                final stockNeeded = shortTermPrediction - product.stock;
                _pendingCollections.containsKey(product.id);

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
                            const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
                            Expanded(
                                flex: 2,
                                child: _buildStatusIndicator(product.status)),
                            const SizedBox(width: 8),
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
                            Expanded(
                              flex: 2,
                              child: Text(
                                stockNeeded > 0
                                    ? 'Besoin: $stockNeeded'
                                    : 'Suffisant',
                                style: _cellTextStyle().copyWith(
                                  color: stockNeeded > product.stock * 0.5
                                      ? Colors.red
                                      : stockNeeded > 0
                                          ? Colors.orange
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.local_shipping,
                                      color: _readyForConfirmation
                                              .containsKey(product.id)
                                          ? Colors
                                              .red // Couleur rouge si la collecte est prête
                                          : const Color(0xFF0056A6),
                                    ),
                                    onPressed: () {
                                      if (_readyForConfirmation
                                          .containsKey(product.id)) {
                                        // Afficher la boîte de dialogue de confirmation si la collecte est prête
                                        _confirmCollectionDialog(product,
                                            _readyForConfirmation[product.id]!);
                                      }
                                    },
                                  ),
                                  if (_pendingCollections
                                      .containsKey(product.id))
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors
                                              .orange, // Orange pour les collectes en attente
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          _getCollectionCountdown(
                                              _pendingCollections[product.id]!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_readyForConfirmation
                                      .containsKey(product.id))
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors
                                              .red, // Rouge pour indiquer que la collecte est prête
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.warning,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: IconButton(
                                icon: const Icon(Icons.history,
                                    color: Color(0xFF0056A6)),
                                onPressed: () async {
                                  final movements =
                                      await _getProductMovements(product.id!);
                                  showDialog(
                                    context: context,
                                    builder: (context) => _buildMovementsDialog(
                                        context, movements),
                                  );
                                },
                              ),
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
