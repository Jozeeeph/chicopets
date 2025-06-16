import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/stock_movement.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:caissechicopets/views/paymentmode_views/PaymentModeMgt.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Classe pour représenter les résultats de l'analyse
class MovementPattern {
  final int productId;
  final String productName;
  final Map<String, int> movementCounts;
  final String patternCategory;
  final double movementScore;
  final String expirationDate; // Nouvelle propriété

  MovementPattern({
    required this.productId,
    required this.productName,
    required this.movementCounts,
    required this.patternCategory,
    required this.movementScore,
    this.expirationDate = '', // Valeur par défaut
  });
}

// Classe pour représenter les clients performants
class ClientPerformance {
  final int clientId;
  final String clientName;
  final int orderCount;
  final int loyaltyPoints;
  final double performanceScore;

  ClientPerformance({
    required this.clientId,
    required this.clientName,
    required this.orderCount,
    required this.loyaltyPoints,
    required this.performanceScore,
  });
}

class StockMovementAnalysisPage extends StatefulWidget {
  const StockMovementAnalysisPage({super.key});

  @override
  _StockMovementAnalysisPageState createState() =>
      _StockMovementAnalysisPageState();
}

class _StockMovementAnalysisPageState extends State<StockMovementAnalysisPage> {
  final SqlDb _sqlDb = SqlDb();
  late final StockMovementService _stockMovementService;
  String _selectedTimeHorizon = 'all';
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _stockMovementService = StockMovementService(_sqlDb);
    _dataFuture = _loadAllData();
  }

  Future<Map<String, dynamic>> _loadAllData({String? timeHorizon}) async {
    try {
      final products = await _sqlDb.getProducts();
      for (final product in products) {
        if (product.hasVariants) {
          product.variants = await _sqlDb.getVariantsByProductId(product.id!);
        }
      }
      final patterns = await _analyzeMovementPatterns(
          products, timeHorizon ?? _selectedTimeHorizon);
      final clientPerformances = await _analyzeClientPerformances();
      final orders = await _sqlDb.getOrders();

      return {
        'products': products,
        'patterns': patterns,
        'clientPerformances': clientPerformances,
        'orders': orders,
      };
    } catch (e) {
      _showError('Erreur de chargement: ${e.toString()}');
      return {
        'products': [],
        'patterns': [],
        'clientPerformances': [],
        'orders': [],
      };
    }
  }

  Future<List<MovementPattern>> _analyzeMovementPatterns(
      List<Product> products, String timeHorizon) async {
    List<MovementPattern> patterns = [];

    for (final product in products) {
      if (!product.hasVariants) {
        final pattern = await _analyzeProductMovement(product, timeHorizon);
        patterns.add(pattern);
      }

      if (product.hasVariants && product.variants.isNotEmpty) {
        for (final variant in product.variants) {
          final pattern =
              await _analyzeVariantMovement(product, variant, timeHorizon);
          patterns.add(pattern);
        }
      }
    }

    final now = DateTime.now();
    final expirationThreshold = now.add(const Duration(days: 30));
    for (final product in products) {
      if (product.dateExpiration.isNotEmpty) {
        try {
          final expirationDate =
              DateFormat('dd-MM-yyyy').parse(product.dateExpiration);
          if (expirationDate.isBefore(expirationThreshold)) {
            final pattern = await _createExpirationPattern(product);
            patterns.add(pattern);
          }
        } catch (e) {
          continue;
        }
      }
    }

    patterns.sort((a, b) => b.movementScore.compareTo(a.movementScore));
    return patterns;
  }

  Future<List<ClientPerformance>> _analyzeClientPerformances() async {
    List<ClientPerformance> performances = [];
    final clients = await _sqlDb.getAllClients();

    for (final client in clients) {
      final orders = await _sqlDb.getClientOrders(client.id!);
      final orderCount = orders.length;
      final loyaltyPoints = client.loyaltyPoints;
      final performanceScore = (orderCount * 0.6 + loyaltyPoints * 0.4 / 100);
      performances.add(ClientPerformance(
        clientId: client.id!,
        clientName: '${client.name} ${client.firstName}',
        orderCount: orderCount,
        loyaltyPoints: loyaltyPoints,
        performanceScore: performanceScore,
      ));
    }

    performances
        .sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
    return performances.take(10).toList();
  }

  Future<MovementPattern> _analyzeProductMovement(
      Product product, String timeHorizon) async {
    final movements = await _stockMovementService.getMovementsForProduct(
      product.id!,
      timeHorizon: timeHorizon != 'all' ? timeHorizon : null,
    );

    return _createMovementPattern(
      id: product.id!,
      name: product.designation,
      movements: movements,
    );
  }

  Future<MovementPattern> _analyzeVariantMovement(
      Product product, Variant variant, String timeHorizon) async {
    final movements = await _stockMovementService.getMovementsForVariant(
      variant.id!,
      timeHorizon: timeHorizon != 'all' ? timeHorizon : null,
    );

    return _createMovementPattern(
      id: variant.id!,
      name: '${product.designation} - ${variant.combinationName}',
      movements: movements,
      isVariant: true,
    );
  }

  Future<MovementPattern> _createExpirationPattern(Product product) async {
    final movements = await _stockMovementService.getMovementsForProduct(
      product.id!,
      timeHorizon: null,
    );

    return MovementPattern(
      productId: product.id!,
      productName: product.designation,
      movementCounts: {
        'sale': 0,
        'return': 0,
        'loss': 0,
        'in': 0,
        'out': 0,
        'adjustment': 0,
        'transfer': 0,
      },
      patternCategory: 'Date d\'Expiration Proche',
      movementScore: 0,
      expirationDate: product.dateExpiration, // Ajout de la date d'expiration
    );
  }

  MovementPattern _createMovementPattern({
    required int id,
    required String name,
    required List<StockMovement> movements,
    bool isVariant = false,
    String? patternCategoryOverride,
  }) {
    final movementCounts = {
      'sale': 0,
      'return': 0,
      'loss': 0,
      'in': 0,
      'out': 0,
      'adjustment': 0,
      'transfer': 0,
    };

    for (final movement in movements) {
      if (movementCounts.containsKey(movement.movementType)) {
        movementCounts[movement.movementType] =
            movementCounts[movement.movementType]! + movement.quantity;
      }
    }

    final totalMovements = movementCounts.values.reduce((a, b) => a + b);
    final movementScore = (movementCounts['sale']! * 1.0 +
            movementCounts['return']! * 0.8 +
            movementCounts['loss']! * 0.5 +
            movementCounts['in']! * 0.3 +
            movementCounts['out']! * 0.3 +
            movementCounts['adjustment']! * 0.2 +
            movementCounts['transfer']! * 0.2) /
        (totalMovements == 0 ? 1 : totalMovements);

    String patternCategory = patternCategoryOverride ?? '';
    if (patternCategoryOverride == null) {
      if (movementCounts['sale']! > 20 &&
          movementCounts['return']! < 5 &&
          movementCounts['loss']! < 5) {
        patternCategory = 'Ventes Élevées, Faibles Retours';
      } else if (movementCounts['return']! > movementCounts['sale']! * 0.3) {
        patternCategory = 'Retours Fréquents';
      } else if (movementCounts['loss']! > movementCounts['sale']! * 0.2) {
        patternCategory = 'Pertes Élevées';
      } else if (movementCounts['in']! > movementCounts['sale']! * 1.5 &&
          movementCounts['sale']! > 0) {
        patternCategory = 'Sur-Approvisionnement';
      } else if (movementCounts['sale']! > 10) {
        patternCategory = 'Activité Modérée';
      } else {
        patternCategory = 'Activité Faible';
      }
    }

    if (isVariant && patternCategoryOverride == null) {
      patternCategory = '[Variante] $patternCategory';
    }

    return MovementPattern(
      productId: id,
      productName: name,
      movementCounts: movementCounts,
      patternCategory: patternCategory,
      movementScore: movementScore,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int _calculateTotalStock(List<Product> products) {
    int totalStock = 0;

    for (final product in products) {
      // Ajouter le stock du produit principal
      totalStock += product.stock;

      // Ajouter le stock des variantes si elles existent
      if (product.hasVariants && product.variants.isNotEmpty) {
        totalStock +=
            product.variants.fold(0, (sum, variant) => sum + variant.stock);
      }
    }

    return totalStock;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Text(
              'Analyse Dynamique des Stocks',
              style: GoogleFonts.poppins(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
        centerTitle: false,
        actions: [
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _dataFuture = _loadAllData();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final List<Product> products = data['products'] ?? [];
          final List<MovementPattern> movementPatterns = data['patterns'] ?? [];
          final List<ClientPerformance> clientPerformances =
              data['clientPerformances'] ?? [];
          final List<Order> orders = data['orders'] ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildKpiCard(
                              'Stock Total',
                              _calculateTotalStock(products).toString(),
                              const Color(0xFF3B82F6),
                              Icons.inventory),
                          _buildKpiCard(
                              'Ventes Totales',
                              movementPatterns
                                  .fold(
                                      0,
                                      (sum, p) =>
                                          sum + p.movementCounts['sale']!)
                                  .toString(),
                              const Color(0xFF10B981),
                              Icons.shopping_cart),
                          _buildKpiCard(
                              'Retours Produits',
                              movementPatterns
                                  .where((p) => p.patternCategory
                                      .contains('Retours Fréquents'))
                                  .length
                                  .toString(),
                              const Color(0xFFF59E0B),
                              Icons.assignment_return),
                          _buildKpiCard(
                              'Expirations Proches',
                              movementPatterns
                                  .where((p) => p.patternCategory
                                      .contains('Date d\'Expiration Proche'))
                                  .length
                                  .toString(),
                              const Color(0xFFEF4444),
                              Icons.warning),
                          _buildKpiCard(
                              'Top Clients',
                              clientPerformances.length.toString(),
                              const Color(0xFF22C55E),
                              Icons.star),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Visualisations',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 800 ? 3 : 1,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.5,
                        children: [
                          _buildChartContainer('Stock par Catégorie',
                              _buildBarChart(products), Icons.category),
                          _buildChartContainer(
                              'Répartition des Ventes',
                              _buildPieChart(movementPatterns),
                              Icons.pie_chart),
                          _buildChartContainer('Évolution Journalière',
                              _buildLineChart(orders), Icons.show_chart),
                          _buildChartContainer(
                              'Types de Mouvements',
                              _buildDoughnutChart(movementPatterns),
                              Icons.donut_large),
                          _buildChartContainer(
                              'Expirations Proches',
                              _buildExpiryChart(movementPatterns),
                              Icons.warning),
                          _buildChartContainer(
                              'Retours Fréquents',
                              _buildReturnsChart(movementPatterns),
                              Icons.assignment_returned),
                          _buildChartContainer(
                              'Top Clients',
                              _buildTopClientsTable(clientPerformances),
                              Icons.people_alt),
                          _buildChartContainer(
                              'Activité Faible',
                              _buildLowActivityChart(movementPatterns),
                              Icons.trending_down),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 284,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Product> products) {
    final categories = products
        .map((p) => p.categoryName ?? 'Non catégorisé')
        .toSet()
        .toList();

    // Fonction pour abréger les noms des catégories
    String abbreviateCategory(String category, {int maxLength = 10}) {
      if (category.length <= maxLength) return category;
      return '${category.substring(0, maxLength - 3)}...';
    }

    final categoryStocks = {
      for (var cat in categories)
        cat: products
            .where((p) =>
                p.categoryName == cat ||
                (cat == 'Non catégorisé' && p.categoryName == null))
            .fold(0, (sum, p) => sum + p.stock)
    };

    final data = categories.map((cat) => categoryStocks[cat] ?? 0).toList();

    if (data.isEmpty || data.every((d) => d == 0)) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final maxY = data.reduce((a, b) => a > b ? a : b).toDouble() * 1.3;
    final horizontalInterval = maxY / 5 > 0 ? maxY / 5 : 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${categories[groupIndex]}\n${rod.toY.toInt()} en stock', // Nom complet dans le tooltip
                GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        barGroups: categories.asMap().entries.map((entry) {
          final index = entry.key;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[index].toDouble(),
                color: const Color(0xFF3B82F6),
                width: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 80, // Augmente l'espace réservé pour les titres
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < categories.length) {
                  return Transform.rotate(
                    angle: -0.785, // Garde l'angle de rotation
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        abbreviateCategory(categories[index]), // Nom abrégé
                        style: GoogleFonts.poppins(
                          fontSize: 10, // Réduit légèrement la taille
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  Widget _buildPieChart(List<MovementPattern> movementPatterns) {
    final topProducts = movementPatterns.take(5).toList();
    if (topProducts.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 200, // Taille fixe pour le pie chart
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {},
              ),
              sections: topProducts.asMap().entries.map((entry) {
                final index = entry.key;
                final pattern = entry.value;
                return PieChartSectionData(
                  value: pattern.movementCounts['sale']!.toDouble(),
                  color: colors[index % 5],
                  radius: 60,
                  title: '', // On enlève le titre du pie chart
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Légendes sous le graphique
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: topProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final pattern = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: colors[index % 5],
                ),
                const SizedBox(width: 4),
                Text(
                  '${pattern.productName.length > 15 ? '${pattern.productName.substring(0, 15)}...' : pattern.productName} (${pattern.movementCounts['sale']})',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<Order> orders) {
    final Map<int, int> ordersByWeekday = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };

    for (final order in orders) {
      try {
        final orderDate = DateTime.parse(order.date);
        final weekday = orderDate.weekday;
        ordersByWeekday[weekday] = (ordersByWeekday[weekday] ?? 0) + 1;
      } catch (_) {}
    }

    final weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    final spots = List.generate(7, (index) {
      final weekdayNumber = index + 1;
      return FlSpot(
        index.toDouble(),
        ordersByWeekday[weekdayNumber]?.toDouble() ?? 0,
      );
    });

    final maxY = ordersByWeekday.values.isEmpty
        ? 10.0
        : ordersByWeekday.values.reduce((a, b) => a > b ? a : b).toDouble() *
            1.2;

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF3B82F6),
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF3B82F6).withOpacity(0.2),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 32,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index > 6) return const SizedBox.shrink();
                return Text(
                  weekdays[index],
                  style:
                      GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 5,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5 > 0 ? maxY / 5 : 1.0,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        minX: 0,
        maxX: 6,
        maxY: maxY,
      ),
    );
  }

  Widget _buildDoughnutChart(List<MovementPattern> movementPatterns) {
    final movementTypes = ['sale', 'return', 'loss', 'in', 'out'];
    final labels = ['Ventes', 'Retours', 'Pertes', 'Entrées', 'Sorties'];
    final data = movementTypes
        .map((type) => movementPatterns
            .fold(0, (sum, p) => sum + p.movementCounts[type]!)
            .toDouble())
        .toList();

    if (data.isEmpty || data.every((d) => d == 0)) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (event is FlTapUpEvent && pieTouchResponse != null) {
              // Handle touch for details
            }
          },
        ),
        sections: data.asMap().entries.map((entry) {
          final index = entry.key;
          return PieChartSectionData(
            value: entry.value,
            color: [
              const Color(0xFF3B82F6),
              const Color(0xFFF59E0B),
              const Color(0xFFEF4444),
              const Color(0xFF10B981),
              const Color(0xFF8B5CF6),
            ][index],
            title: '${labels[index]}\n${entry.value.toInt()}',
            radius: 60,
            titleStyle: GoogleFonts.poppins(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
            titlePositionPercentageOffset: 0.55,
          );
        }).toList(),
        sectionsSpace: 4,
        centerSpaceRadius: 60,
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  Widget _buildExpiryChart(List<MovementPattern> movementPatterns) {
    // Filtrer les produits avec expiration proche et ayant une date valide
    final expiryProducts = movementPatterns
        .where((p) =>
            p.patternCategory.contains('Date d\'Expiration Proche') &&
            p.expirationDate.isNotEmpty)
        .take(5)
        .toList();

    if (expiryProducts.isEmpty) {
      return const Center(child: Text('Aucun produit avec expiration proche'));
    }

    // Calculer les jours restants pour chaque produit
    final now = DateTime.now();
    final List<Map<String, dynamic>> productsWithDaysRemaining = [];

    for (final pattern in expiryProducts) {
      try {
        final expirationDate =
            DateFormat('dd-MM-yyyy').parse(pattern.expirationDate);
        final daysRemaining = expirationDate.difference(now).inDays;
        if (daysRemaining >= 0) {
          // Ne garder que les produits non encore expirés
          productsWithDaysRemaining.add({
            'name': pattern.productName,
            'daysRemaining': daysRemaining,
            'expirationDate': pattern.expirationDate,
          });
        }
      } catch (e) {
        continue; // Ignorer les dates mal formatées
      }
    }

    // Trier par jours restants (du plus urgent au moins urgent)
    productsWithDaysRemaining
        .sort((a, b) => a['daysRemaining'].compareTo(b['daysRemaining']));

    if (productsWithDaysRemaining.isEmpty) {
      return const Center(
          child: Text('Aucun produit avec expiration proche valide'));
    }

    // Trouver le maximum des jours restants
    final maxDaysRemaining = productsWithDaysRemaining.fold(
        0,
        (max, item) =>
            item['daysRemaining'] > max ? item['daysRemaining'] : max);

    // Ajouter une marge de 20% mais avec un minimum de 5 jours pour éviter les cas où maxY=0
    final maxY = (maxDaysRemaining * 1.2).clamp(5.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final product = productsWithDaysRemaining[groupIndex];
              return BarTooltipItem(
                '${product['name']}\nExp: ${product['expirationDate']}\n${product['daysRemaining']} jours restants',
                GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        barGroups: productsWithDaysRemaining.asMap().entries.map((entry) {
          final index = entry.key;
          final daysRemaining = entry.value['daysRemaining'] as int;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: daysRemaining.toDouble(),
                color: daysRemaining <= 7
                    ? const Color(0xFFEF4444)
                    : daysRemaining <= 14
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF3B82F6),
                width: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < productsWithDaysRemaining.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      productsWithDaysRemaining[index]['name'].length > 12
                          ? '${productsWithDaysRemaining[index]['name'].substring(0, 12)}...'
                          : productsWithDaysRemaining[index]['name'],
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}j',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5 > 0 ? maxY / 5 : 1.0,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildReturnsChart(List<MovementPattern> movementPatterns) {
    final returnProducts = movementPatterns
        .where((p) => p.patternCategory.contains('Retours Fréquents'))
        .take(5)
        .toList();

    if (returnProducts.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (event is FlTapUpEvent && pieTouchResponse != null) {
              // Handle touch for details
            }
          },
        ),
        sections: returnProducts.asMap().entries.map((entry) {
          final index = entry.key;
          final pattern = entry.value;
          return PieChartSectionData(
            value: pattern.movementCounts['return']!.toDouble(),
            color: [
              const Color(0xFFF59E0B),
              const Color(0xFFEF4444),
              const Color(0xFF3B82F6),
              const Color(0xFF10B981),
              const Color(0xFF8B5CF6),
            ][index % 5],
            title:
                '${pattern.productName.length > 10 ? '${pattern.productName.substring(0, 10)}...' : pattern.productName}\n${pattern.movementCounts['return']} retours',
            radius: 80,
            titleStyle: GoogleFonts.poppins(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
            titlePositionPercentageOffset: 0.55,
          );
        }).toList(),
        sectionsSpace: 3,
        centerSpaceRadius: 40,
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

Widget _buildTopClientsTable(List<ClientPerformance?> clientPerformances) {
  // Filter out null entries and take top 5 clients, sorted by performance score (descending)
  final topClients = clientPerformances
      .asMap()
      .entries
      .where((entry) => entry.value != null) // Remove null entries
      .map((entry) => {'index': entry.key, 'client': entry.value!})
      .toList()
    ..sort((a, b) {
      final scoreA = (a['client'] as ClientPerformance?)?.performanceScore ?? 0.0;
      final scoreB = (b['client'] as ClientPerformance?)?.performanceScore ?? 0.0;
      return scoreB.compareTo(scoreA); // Descending order
    })
    ..take(5);

  if (topClients.isEmpty) {
    return const Center(child: Text('Aucune donnée disponible'));
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          spreadRadius: 2,
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E), // Green header
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Rang',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Client',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Score',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Data Rows
        ...topClients.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final client = entry.value['client'] as ClientPerformance;
          return Container(
            color: rank % 2 == 0 ? Colors.grey[100] : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '$rank',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    client.clientName.length > 20
                        ? '${client.clientName.substring(0, 20)}...'
                        : client.clientName,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    client.performanceScore.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}

  Widget _buildLowActivityChart(List<MovementPattern> movementPatterns) {
    final lowActivityProducts = movementPatterns
        .where((p) => p.patternCategory.contains('Activité Faible'))
        .take(5)
        .toList();

    if (lowActivityProducts.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final maxY = lowActivityProducts
            .map((p) => p.movementCounts['sale']!.toDouble())
            .reduce((a, b) => a > b ? a : b) *
        1.3;
    final horizontalInterval = maxY / 5 > 0 ? maxY / 5 : 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${lowActivityProducts[groupIndex].productName}\n${rod.toY.toInt()} ventes',
                GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        barGroups: lowActivityProducts.asMap().entries.map((entry) {
          final index = entry.key;
          final pattern = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: pattern.movementCounts['sale']!.toDouble(),
                color: const Color(0xFF8B5CF6),
                width: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < lowActivityProducts.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      lowActivityProducts[index].productName.length > 12
                          ? '${lowActivityProducts[index].productName.substring(0, 12)}...'
                          : lowActivityProducts[index].productName,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }
}
