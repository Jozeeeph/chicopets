import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/stock_movement.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Classe pour représenter les résultats de l'analyse
class MovementPattern {
  final int productId;
  final String productName;
  final Map<String, int> movementCounts; // Map des types de mouvement et leurs quantités
  final String patternCategory; // e.g., "High Sales, Low Returns", etc.
  final double movementScore; // Score pour classer l'intensité des mouvements

  MovementPattern({
    required this.productId,
    required this.productName,
    required this.movementCounts,
    required this.patternCategory,
    required this.movementScore,
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
  _StockMovementAnalysisPageState createState() => _StockMovementAnalysisPageState();
}

class _StockMovementAnalysisPageState extends State<StockMovementAnalysisPage> {
  final SqlDb _sqlDb = SqlDb();
  late final StockMovementService _stockMovementService;
  bool _isLoading = true;
  List<Product> _products = [];
  List<MovementPattern> _movementPatterns = [];
  List<ClientPerformance> _clientPerformances = [];
  String _selectedTimeHorizon = 'all'; // Filtre de période
  String _selectedMovementType = 'Ventes Élevées, Faibles Retours'; // Valeur initiale pour l'onglet par défaut

  @override
  void initState() {
    super.initState();
    _stockMovementService = StockMovementService(_sqlDb);
    _loadData();
  }

  Future<void> _loadData({String? timeHorizon}) async {
    try {
      setState(() => _isLoading = true);
      final products = await _sqlDb.getProducts();
      
      // Charger les variantes pour chaque produit
      for (final product in products) {
        if (product.hasVariants) {
          product.variants = await _sqlDb.getVariantsByProductId(product.id!);
        }
      }
      
      final patterns = await _analyzeMovementPatterns(products, timeHorizon ?? _selectedTimeHorizon);
      final clientPerformances = await _analyzeClientPerformances();

      setState(() {
        _products = products;
        _movementPatterns = patterns;
        _clientPerformances = clientPerformances;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de chargement: ${e.toString()}');
    }
  }

  // Analyse des patterns de mouvement
  Future<List<MovementPattern>> _analyzeMovementPatterns(List<Product> products, String timeHorizon) async {
    List<MovementPattern> patterns = [];

    for (final product in products) {
      if (!product.hasVariants) {
        final pattern = await _analyzeProductMovement(product, timeHorizon);
        patterns.add(pattern);
      }
      
      if (product.hasVariants && product.variants.isNotEmpty) {
        for (final variant in product.variants) {
          final pattern = await _analyzeVariantMovement(product, variant, timeHorizon);
          patterns.add(pattern);
        }
      }
    }

    // Ajouter les produits avec date d'expiration proche
    final now = DateTime.now();
    final expirationThreshold = now.add(const Duration(days: 30));
    for (final product in products) {
      if (product.dateExpiration.isNotEmpty) {
        try {
          final expirationDate = DateFormat('dd-MM-yyyy').parse(product.dateExpiration);
          if (expirationDate.isBefore(expirationThreshold)) {
            final pattern = await _createExpirationPattern(product);
            patterns.add(pattern);
          }
        } catch (e) {
          // Ignorer les erreurs de parsing de date
          continue;
        }
      }
    }

    // Trier par score d'activité
    patterns.sort((a, b) => b.movementScore.compareTo(a.movementScore));
    return patterns;
  }

  // Analyse des performances des clients
  Future<List<ClientPerformance>> _analyzeClientPerformances() async {
    List<ClientPerformance> performances = [];
    final clients = await _sqlDb.getAllClients();

    for (final client in clients) {
      final orders = await _sqlDb.getClientOrders(client.id!);
      final orderCount = orders.length;
      final loyaltyPoints = client.loyaltyPoints;
      // Calculer un score de performance (par exemple, combinaison normalisée des commandes et points)
      final performanceScore = (orderCount * 0.6 + loyaltyPoints * 0.4 / 100);
      performances.add(ClientPerformance(
        clientId: client.id!,
        clientName: '${client.name} ${client.firstName}',
        orderCount: orderCount,
        loyaltyPoints: loyaltyPoints,
        performanceScore: performanceScore,
      ));
    }

    // Trier par score de performance
    performances.sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
    return performances.take(10).toList(); // Limiter aux 10 premiers
  }

  Future<MovementPattern> _analyzeProductMovement(Product product, String timeHorizon) async {
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

  Future<MovementPattern> _analyzeVariantMovement(Product product, Variant variant, String timeHorizon) async {
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

    return _createMovementPattern(
      id: product.id!,
      name: product.designation,
      movements: movements,
      patternCategoryOverride: 'Date d\'Expiration Proche',
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
        movementCounts[movement.movementType] = movementCounts[movement.movementType]! + movement.quantity;
      }
    }

    final totalMovements = movementCounts.values.reduce((a, b) => a + b);
    final movementScore = (
      movementCounts['sale']! * 1.0 +
      movementCounts['return']! * 0.8 +
      movementCounts['loss']! * 0.5 +
      movementCounts['in']! * 0.3 +
      movementCounts['out']! * 0.3 +
      movementCounts['adjustment']! * 0.2 +
      movementCounts['transfer']! * 0.2
    ) / (totalMovements == 0 ? 1 : totalMovements);

    String patternCategory = patternCategoryOverride ?? '';
    if (patternCategoryOverride == null) {
      if (movementCounts['sale']! > 20 && movementCounts['return']! < 5 && movementCounts['loss']! < 5) {
        patternCategory = 'Ventes Élevées, Faibles Retours';
      } else if (movementCounts['return']! > movementCounts['sale']! * 0.3) {
        patternCategory = 'Retours Fréquents';
      } else if (movementCounts['loss']! > movementCounts['sale']! * 0.2) {
        patternCategory = 'Pertes Élevées';
      } else if (movementCounts['in']! > movementCounts['sale']! * 1.5 && movementCounts['sale']! > 0) {
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
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildPatternChip(String text, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(0.2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildStatChip(String text, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(0.1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      label: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementChart(MovementPattern pattern) {
    final movementTypes = ['sale', 'return', 'loss', 'in', 'out', 'adjustment', 'transfer'];
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.cyan,
    ];
    final labels = [
      'Ventes',
      'Retours',
      'Pertes',
      'Entrées',
      'Sorties',
      'Ajustements',
      'Transferts',
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: movementTypes
              .map((type) => pattern.movementCounts[type]!.toDouble())
              .reduce((a, b) => a > b ? a : b) * 1.2,
          barGroups: movementTypes.asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: pattern.movementCounts[type]!.toDouble(),
                  color: colors[index],
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[index],
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${labels[groupIndex]}: ${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showMovementDetails(BuildContext context, MovementPattern pattern) {
    final isVariant = pattern.patternCategory.startsWith('[Variante]');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(
            maxWidth: 800,
            maxHeight: 700,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pattern.productName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0056A6),
                          ),
                        ),
                        if (isVariant)
                          Text(
                            'Variante de produit',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple,
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPatternChip(
                  pattern.patternCategory.replaceAll('[Variante] ', ''),
                  const Color(0xFF0056A6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Visualisation des Mouvements',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildMovementChart(pattern),
                const SizedBox(height: 16),
                const Text(
                  'Statistiques des Mouvements',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildStatRow('Ventes', pattern.movementCounts['sale'].toString(), Colors.blue),
                _buildStatRow('Retours', pattern.movementCounts['return'].toString(), Colors.orange),
                _buildStatRow('Pertes', pattern.movementCounts['loss'].toString(), Colors.red),
                _buildStatRow('Entrées', pattern.movementCounts['in'].toString(), Colors.green),
                _buildStatRow('Sorties', pattern.movementCounts['out'].toString(), Colors.purple),
                _buildStatRow('Ajustements', pattern.movementCounts['adjustment'].toString(), Colors.teal),
                _buildStatRow('Transferts', pattern.movementCounts['transfer'].toString(), Colors.cyan),
                _buildStatRow('Score d\'Activité', pattern.movementScore.toStringAsFixed(2), Colors.teal),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056A6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Fermer', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientPerformanceContent() {
    if (_clientPerformances.isEmpty) {
      return Center(
        child: Text(
          'Aucun client performant trouvé',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clientPerformances.length,
      itemBuilder: (context, index) {
        final client = _clientPerformances[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                // Optionnel : Ajouter une action au clic, par exemple afficher les détails du client
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF009688).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, color: Color(0xFF009688), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF009688),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildStatChip('Commandes: ${client.orderCount}', Colors.blue),
                              _buildStatChip('Points: ${client.loyaltyPoints}', Colors.orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Score: ${client.performanceScore.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.teal,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Mouvements de Stock'),
        backgroundColor: const Color(0xFF0056A6),
        foregroundColor: Colors.white,
        actions: [
          DropdownButton<String>(
            value: _selectedTimeHorizon,
            icon: const Icon(Icons.filter_list, color: Colors.white),
            dropdownColor: const Color(0xFF0056A6),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            underline: Container(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tout')),
              DropdownMenuItem(value: 'short_term', child: Text('30 jours')),
              DropdownMenuItem(value: 'medium_term', child: Text('90 jours')),
              DropdownMenuItem(value: 'long_term', child: Text('1 an')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTimeHorizon = value!;
                _loadData(timeHorizon: _selectedTimeHorizon);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 8, // Ajout d'un onglet pour les clients performants
        initialIndex: 0,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
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
              child: TabBar(
                isScrollable: true,
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
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.trending_up, size: 20),
                    text: 'Ventes Élevées',
                  ),
                  Tab(
                    icon: Icon(Icons.undo, size: 20),
                    text: 'Retours Fréquents',
                  ),
                  Tab(
                    icon: Icon(Icons.warning, size: 20),
                    text: 'Pertes Élevées',
                  ),
                  Tab(
                    icon: Icon(Icons.inventory, size: 20),
                    text: 'Sur-Approvisionnement',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics, size: 20),
                    text: 'Activité Modérée',
                  ),
                  Tab(
                    icon: Icon(Icons.low_priority, size: 20),
                    text: 'Activité Faible',
                  ),
                  Tab(
                    icon: Icon(Icons.event_busy, size: 20),
                    text: 'Expiration Proche',
                  ),
                  Tab(
                    icon: Icon(Icons.star, size: 20),
                    text: 'Clients Performants',
                  ),
                ],
                onTap: (index) {
                  setState(() {
                    switch (index) {
                      case 0:
                        _selectedMovementType = 'Ventes Élevées, Faibles Retours';
                        break;
                      case 1:
                        _selectedMovementType = 'Retours Fréquents';
                        break;
                      case 2:
                        _selectedMovementType = 'Pertes Élevées';
                        break;
                      case 3:
                        _selectedMovementType = 'Sur-Approvisionnement';
                        break;
                      case 4:
                        _selectedMovementType = 'Activité Modérée';
                        break;
                      case 5:
                        _selectedMovementType = 'Activité Faible';
                        break;
                      case 6:
                        _selectedMovementType = 'Date d\'Expiration Proche';
                        break;
                      case 7:
                        _selectedMovementType = 'Clients Performants';
                        break;
                    }
                  });
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _movementPatterns.isEmpty && _selectedMovementType != 'Clients Performants'
                      ? _buildEmptyState()
                      : _buildAnalysisContent(),
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
          Icon(Icons.analytics, size: 60, color: const Color(0xFF0056A6).withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text(
            'Aucune analyse disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0056A6),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Aucun mouvement de stock enregistré',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent() {
    if (_selectedMovementType == 'Clients Performants') {
      return _buildClientPerformanceContent();
    }

    // Filtrer les patterns en fonction du type de mouvement sélectionné
    final filteredPatterns = _movementPatterns
        .where((pattern) => pattern.patternCategory.contains(_selectedMovementType))
        .toList();

    return filteredPatterns.isEmpty
        ? Center(
            child: Text(
              'Aucun produit pour $_selectedMovementType',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPatterns.length,
            itemBuilder: (context, index) {
              final pattern = filteredPatterns[index];
              final isVariant = pattern.patternCategory.startsWith('[Variante]');
              
              Color cardColor = Colors.white;
              Color textColor = const Color(0xFF0056A6);
              IconData icon = Icons.analytics;

              if (pattern.patternCategory.contains('Ventes Élevées')) {
                cardColor = const Color(0xFFE8F5E9);
                textColor = const Color(0xFF388E3C);
                icon = Icons.trending_up;
              } else if (pattern.patternCategory.contains('Retours Fréquents')) {
                cardColor = const Color(0xFFFFF0F0);
                textColor = const Color(0xFFD32F2F);
                icon = Icons.undo;
              } else if (pattern.patternCategory.contains('Pertes Élevées')) {
                cardColor = const Color(0xFFFFF0F0);
                textColor = const Color(0xFFD32F2F);
                icon = Icons.warning;
              } else if (pattern.patternCategory.contains('Sur-Approvisionnement')) {
                cardColor = const Color(0xFFFFF8E1);
                textColor = const Color(0xFFF57C00);
                icon = Icons.inventory;
              } else if (pattern.patternCategory.contains('Date d\'Expiration Proche')) {
                cardColor = const Color(0xFFFFE0B2);
                textColor = const Color(0xFFFF6F00);
                icon = Icons.event_busy;
              }

              if (isVariant) {
                cardColor = cardColor.withOpacity(0.7);
                textColor = Colors.purple;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  borderRadius: BorderRadius.circular(15),
                  color: cardColor,
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => _showMovementDetails(context, pattern),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: textColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pattern.productName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                if (isVariant)
                                  const SizedBox(height: 4),
                                if (isVariant)
                                  Text(
                                    'Variante de produit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.withOpacity(0.7),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                _buildPatternChip(
                                  pattern.patternCategory.replaceAll('[Variante] ', ''),
                                  textColor,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildStatChip('Ventes: ${pattern.movementCounts['sale']}', Colors.blue),
                                    _buildStatChip('Retours: ${pattern.movementCounts['return']}', Colors.orange),
                                    _buildStatChip('Pertes: ${pattern.movementCounts['loss']}', Colors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Score: ${pattern.movementScore.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.teal,
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
}