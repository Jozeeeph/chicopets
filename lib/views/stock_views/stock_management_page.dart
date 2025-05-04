import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  _StockManagementPageState createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  final SqlDb _sqlDb = SqlDb();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Map<int, List<Variant>> _productVariants = {};
  final Map<int, double> _productSales = {};
  final Map<int, TextEditingController> _stockControllers = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
          // Mettre à jour le stock du produit si il a des variantes
          if (products[i].hasVariants) {
            products[i].stock = variants[i].fold(0, (sum, v) => sum + v.stock);
          }
        }
        _isLoading = false;
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
      await _sqlDb.updateProductStock(product.id!, newStock);
      setState(() {
        product.stock = newStock;
        _stockControllers[product.id!]?.text = newStock.toString();
        _updateStatusBasedOnStock(product);
      });
      _showSuccess('Stock mis à jour');
    } catch (e) {
      _showError('Erreur de mise à jour: ${e.toString()}');
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
      _showSuccess('Statut mis à jour');
    } catch (e) {
      _showError('Erreur de mise à jour: ${e.toString()}');
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

  // Méthode pour mettre à jour le stock d'une variante
  Future<void> _updateVariantStock(Variant variant, int newStock) async {
    try {
      await _sqlDb.updateVariantStock(variant.id!, newStock);
      setState(() {
        variant.stock = newStock;
        _updateProductStockFromVariants(variant.productId);
      });
      _showSuccess('Stock variante mis à jour');
    } catch (e) {
      _showError('Erreur de mise à jour: ${e.toString()}');
    }
  }

// Méthode pour recalculer le stock total du produit à partir des variantes
  void _updateProductStockFromVariants(int productId) {
    final variants = _productVariants[productId] ?? [];
    final totalStock = variants.fold(0, (sum, variant) => sum + variant.stock);

    // Mettre à jour le contrôleur du stock total
    _stockControllers[productId]?.text = totalStock.toString();

    // Trouver et mettre à jour le produit correspondant
    final product = _products.firstWhere((p) => p.id == productId);
    if (product.stock != totalStock) {
      product.stock = totalStock;
      _updateStatusBasedOnStock(product);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Stock'),
        backgroundColor: const Color(0xFF0056A6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : _buildProductTable(),
          ),
        ],
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
                      flex: 2, child: Text('Stock', style: _headerTextStyle())),
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
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
                              flex: 2,
                              child: product.hasVariants
                                  ? TextFormField(
                                      controller:
                                          _stockControllers[product.id!],
                                      enabled:
                                          false, // Désactivé pour les produits avec variantes
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
                                        _updateProductStock(product, newStock);
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
                                            width: 100,
                                            child: TextFormField(
                                              initialValue: v.stock.toString(),
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
                                                _updateVariantStock(
                                                    v, newStock);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 8),
                                Text(
                                  'Stock total variantes: ${variants.fold(0, (sum, v) => sum + v.stock)}',
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
