import 'package:flutter/material.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/services/stock_analysis_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StockAnalysisPage extends StatefulWidget {
  const StockAnalysisPage({super.key});

  @override
  _StockAnalysisPageState createState() => _StockAnalysisPageState();
}

class _StockAnalysisPageState extends State<StockAnalysisPage> with SingleTickerProviderStateMixin {
  final SqlDb _sqlDb = SqlDb();
  late final StockAnalysisService _stockAnalysisService;
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  List<Product> _products = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _timeFilter = '30j';
  String _categoryFilter = 'Toutes';
  List<String> _categories = ['Toutes'];

  // Data for charts
  List<Map<String, dynamic>> _slowMovingProducts = [];
  List<Map<String, dynamic>> _fastMovingProducts = [];
  List<Map<String, dynamic>> _stockAnomalies = [];
  List<Map<String, dynamic>> _salesTrends = [];
  Map<String, dynamic> _stockOverview = {};

  @override
  void initState() {
    super.initState();
    _stockAnalysisService = StockAnalysisService(_sqlDb);
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load all data in parallel
      final results = await Future.wait([
        _sqlDb.getProducts(),
        _stockAnalysisService.identifySlowMovingProducts(),
        _stockAnalysisService.identifyFastMovingProducts(),
        _getStockOverview(),
        _getCategories(),
      ]);

      _products = results[0] as List<Product>;
      _slowMovingProducts = results[1] as List<Map<String, dynamic>>;
      _fastMovingProducts = results[2] as List<Map<String, dynamic>>;
      _stockOverview = results[3] as Map<String, dynamic>;
      _categories = ['Toutes'] + (results[4] as List<String>);

      // Load additional data
      _stockAnomalies = await _identifyStockAnomalies();
      _salesTrends = await _getSalesTrends();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de chargement: ${e.toString()}');
    }
  }

  Future<List<String>> _getCategories() async {
    final db = await _sqlDb.db;
    final result = await db.query('categories', 
      where: 'is_deleted = 0',
      columns: ['category_name']);
    return result.map((e) => e['category_name'] as String).toList();
  }

  Future<Map<String, dynamic>> _getStockOverview() async {
    final db = await _sqlDb.db;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_products,
        SUM(stock) as total_stock,
        SUM(CASE WHEN status = 'En stock' THEN 1 ELSE 0 END) as in_stock,
        SUM(CASE WHEN status = 'Stock faible' THEN 1 ELSE 0 END) as low_stock,
        SUM(CASE WHEN status = 'Rupture' THEN 1 ELSE 0 END) as out_of_stock,
        SUM(CASE WHEN julianday(date_expiration) - julianday('now') BETWEEN 0 AND 30 THEN 1 ELSE 0 END) as expiring_soon
      FROM products
      WHERE is_deleted = 0
    ''');
    
    return result.first;
  }

  Future<List<Map<String, dynamic>>> _identifyStockAnomalies() async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        p.id,
        p.designation,
        p.stock,
        p.category_name,
        COUNT(sm.id) as movement_count,
        SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END) as total_in,
        SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END) as total_out,
        (SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END) - 
         SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END) - p.stock) as discrepancy
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      GROUP BY p.id
      HAVING discrepancy != 0
      ORDER BY ABS(discrepancy) DESC
      LIMIT 10
    ''');
  }

  Future<List<Map<String, dynamic>>> _getSalesTrends() async {
    final db = await _sqlDb.db;
    return await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', movement_date) as month,
        SUM(quantity) as total_sales
      FROM stock_movements
      WHERE movement_type = 'sale'
      GROUP BY month
      ORDER BY month
      LIMIT 12
    ''');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: warmRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse de Stock'),
        backgroundColor: deepBlue,
        foregroundColor: white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: white,
          unselectedLabelColor: lightGray,
          indicatorColor: tealGreen,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Vue Globale'),
            Tab(icon: Icon(Icons.trending_up), text: 'Rotation'),
            Tab(icon: Icon(Icons.warning), text: 'Anomalies'),
            Tab(icon: Icon(Icons.insights), text: 'Tendances'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildRotationTab(),
                _buildAnomaliesTab(),
                _buildTrendsTab(),
              ],
            ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeFilterRow(),
          const SizedBox(height: 16),
          _buildKPICards(),
          const SizedBox(height: 24),
          _buildStockStatusChart(),
          const SizedBox(height: 24),
          _buildExpiringProductsChart(),
          const SizedBox(height: 24),
          _buildTopProductsTable(),
        ],
      ),
    );
  }
Widget _buildTimeFilterRow() {
  return Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: _timeFilter,
          items: const [
            DropdownMenuItem(value: '7j', child: Text('7 derniers jours')),
            DropdownMenuItem(value: '30j', child: Text('30 derniers jours')),
            DropdownMenuItem(value: '90j', child: Text('3 derniers mois')),
            DropdownMenuItem(value: '1a', child: Text('12 derniers mois')),
          ],
          onChanged: (value) {
            setState(() => _timeFilter = value!);
            _loadData();
          },
          decoration: InputDecoration(
            labelText: 'Période',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: DropdownButtonFormField<String>(
          value: _categoryFilter,
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _categoryFilter = value!);
            _loadData();
          },
          decoration: InputDecoration(
            labelText: 'Catégorie',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ],
  );
}


  Widget _buildKPICards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard(
          'Produits en Stock',
          _stockOverview['in_stock'].toString(),
          Icons.inventory,
          tealGreen,
        ),
        _buildKPICard(
          'Stock Faible',
          _stockOverview['low_stock'].toString(),
          Icons.warning,
          softOrange,
        ),
        _buildKPICard(
          'Ruptures',
          _stockOverview['out_of_stock'].toString(),
          Icons.error,
          warmRed,
        ),
        _buildKPICard(
          'Stock Total',
          _stockOverview['total_stock'].toString(),
          Icons.stacked_bar_chart,
          deepBlue,
        ),
      ],
    );
  }
Widget _buildKPICard(String title, String value, IconData icon, Color color) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: darkBlue.withOpacity(0.7),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          SizedBox(height: 10), // facultatif pour l'espacement
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildStockStatusChart() {
    final inStock = _stockOverview['in_stock'] ?? 0;
    final lowStock = _stockOverview['low_stock'] ?? 0;
    final outOfStock = _stockOverview['out_of_stock'] ?? 0;
    final total = inStock + lowStock + outOfStock;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statut du Stock',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: inStock.toDouble(),
                      color: tealGreen,
                      title: '${((inStock / total) * 100).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: white,
                      ),
                    ),
                    PieChartSectionData(
                      value: lowStock.toDouble(),
                      color: softOrange,
                      title: '${((lowStock / total) * 100).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: white,
                      ),
                    ),
                    PieChartSectionData(
                      value: outOfStock.toDouble(),
                      color: warmRed,
                      title: '${((outOfStock / total) * 100).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: white,
                      ),
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(tealGreen, 'En Stock ($inStock)'),
                _buildLegendItem(softOrange, 'Stock Faible ($lowStock)'),
                _buildLegendItem(warmRed, 'Rupture ($outOfStock)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: darkBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringProductsChart() {
    final expiringSoon = _stockOverview['expiring_soon'] ?? 0;
    final totalProducts = _stockOverview['total_products'] ?? 1;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produits Périssables',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: expiringSoon / totalProducts,
                        strokeWidth: 12,
                        backgroundColor: lightGray,
                        color: softOrange,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          expiringSoon.toString(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: softOrange,
                          ),
                        ),
                        Text(
                          'sur $totalProducts',
                          style: TextStyle(
                            fontSize: 14,
                            color: darkBlue.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Produits expirant dans 30 jours',
                style: TextStyle(
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsTable() {
    final topProducts = _products
      ..sort((a, b) => b.stock.compareTo(a.stock));
    final displayedProducts = topProducts.take(5).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Produits en Stock',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: lightGray,
                        width: 1,
                      ),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Produit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Stock',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                ...displayedProducts.map((product) {
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: lightGray,
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          product.designation,
                          style: TextStyle(
                            color: darkBlue.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          product.stock.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: darkBlue.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeFilterRow(),
          const SizedBox(height: 16),
          Text(
            'Produits à Rotation Rapide',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          _buildFastMovingProductsChart(),
          const SizedBox(height: 24),
          Text(
            'Produits à Rotation Lente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          _buildSlowMovingProductsChart(),
        ],
      ),
    );
  }

  Widget _buildFastMovingProductsChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _fastMovingProducts.take(5).map((product) {
                    final index = _fastMovingProducts.indexOf(product);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (product['total_sales'] ?? 0).toDouble(),
                          color: tealGreen,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _fastMovingProducts.length) {
                            return const Text('');
                          }
                          final product = _fastMovingProducts[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              product['designation'].toString().split(' ').first,
                              style: TextStyle(
                                fontSize: 10,
                                color: darkBlue,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: darkBlue,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: lightGray,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._fastMovingProducts.take(3).map((product) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: tealGreen.withOpacity(0.2),
                  child: Icon(Icons.trending_up, size: 20, color: tealGreen),
                ),
                title: Text(
                  product['designation'].toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: darkBlue,
                  ),
                ),
                subtitle: Text(
                  'Ventes: ${product['total_sales']} | Stock: ${product['stock']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: darkBlue.withOpacity(0.6),
                  ),
                ),
                trailing: Text(
                  '${product['weeks_in_stock']?.toStringAsFixed(1) ?? '0'} sem.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: tealGreen,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSlowMovingProductsChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _slowMovingProducts.take(5).map((product) {
                    final index = _slowMovingProducts.indexOf(product);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (product['months_in_stock'] ?? 0).toDouble(),
                          color: softOrange,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _slowMovingProducts.length) {
                            return const Text('');
                          }
                          final product = _slowMovingProducts[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              product['designation'].toString().split(' ').first,
                              style: TextStyle(
                                fontSize: 10,
                                color: darkBlue,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()} mois',
                            style: TextStyle(
                              fontSize: 10,
                              color: darkBlue,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: lightGray,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._slowMovingProducts.take(3).map((product) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: softOrange.withOpacity(0.2),
                  child: Icon(Icons.trending_down, size: 20, color: softOrange),
                ),
                title: Text(
                  product['designation'].toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: darkBlue,
                  ),
                ),
                subtitle: Text(
                  'Stock: ${product['stock']} | Ventes: ${product['total_sales'] ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: darkBlue.withOpacity(0.6),
                  ),
                ),
                trailing: Text(
                  '${product['months_in_stock']?.toStringAsFixed(1) ?? '0'} mois',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: softOrange,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeFilterRow(),
          const SizedBox(height: 16),
          Text(
            'Anomalies de Stock',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          _buildAnomaliesChart(),
          const SizedBox(height: 24),
          ..._stockAnomalies.map((anomaly) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: warmRed.withOpacity(0.1),
                  child: Icon(Icons.warning, color: warmRed),
                ),
                title: Text(
                  anomaly['designation'].toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Stock actuel: ${anomaly['stock']}',
                      style: TextStyle(
                        color: darkBlue.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      'Écart calculé: ${anomaly['discrepancy']}',
                      style: TextStyle(
                        color: darkBlue.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.arrow_forward, color: deepBlue),
                  onPressed: () {
                    // Navigate to product detail
                  },
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

Widget _buildAnomaliesChart() {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                labelStyle: TextStyle(color: darkBlue),
              ),
              primaryYAxis: NumericAxis(
                labelStyle: TextStyle(color: darkBlue),
              ),
              series: <CartesianSeries>[
                BarSeries<Map<String, dynamic>, String>(
                  dataSource: _stockAnomalies.take(5).toList(),
                  xValueMapper: (data, _) =>
                      data['designation'].toString().split(' ').first,
                  yValueMapper: (data, _) =>
                      (data['discrepancy'] ?? 0).abs().toDouble(),
                  pointColorMapper: (data, _) => warmRed,
                  name: 'Écart',
                  width: 0.6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info, size: 16, color: warmRed),
              const SizedBox(width: 8),
              Text(
                '${_stockAnomalies.length} anomalies détectées',
                style: TextStyle(
                  color: darkBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeFilterRow(),
          const SizedBox(height: 16),
          Text(
            'Tendances des Ventes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          _buildSalesTrendsChart(),
          
        ],
      ),
    );
  }

  Widget _buildSalesTrendsChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _salesTrends.map((trend) {
                        final month = trend['month'].toString().split('-').last;
                        return FlSpot(
                          double.parse(month),
                          (trend['total_sales'] ?? 0).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: deepBlue,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        color: deepBlue.withOpacity(0.1),
                      ),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final months = [
                            'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
                            'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
                          ];
                          if (value.toInt() >= 1 && value.toInt() <= 12) {
                            return Text(
                              months[value.toInt() - 1],
                              style: TextStyle(
                                fontSize: 10,
                                color: darkBlue,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: darkBlue,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: lightGray,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: lightGray, width: 1),
                      left: BorderSide(color: lightGray, width: 1),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrendIndicator(
                  Icons.trending_up,
                  'Meilleur mois',
                  _getBestMonth(),
                  tealGreen,
                ),
                _buildTrendIndicator(
                  Icons.trending_down,
                  'Plus bas',
                  _getWorstMonth(),
                  softOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getBestMonth() {
    if (_salesTrends.isEmpty) return '-';
    final best = _salesTrends.reduce((a, b) => 
      (a['total_sales'] ?? 0) > (b['total_sales'] ?? 0) ? a : b);
    final month = best['month'].toString().split('-').last;
    final year = best['month'].toString().split('-').first;
    return '${_getMonthName(int.parse(month))} $year';
  }

  String _getWorstMonth() {
    if (_salesTrends.isEmpty) return '-';
    final worst = _salesTrends.reduce((a, b) => 
      (a['total_sales'] ?? 0) < (b['total_sales'] ?? 0) ? a : b);
    final month = worst['month'].toString().split('-').last;
    final year = worst['month'].toString().split('-').first;
    return '${_getMonthName(int.parse(month))} $year';
  }

  String _getMonthName(int month) {
    final months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  Widget _buildTrendIndicator(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: darkBlue.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

