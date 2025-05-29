import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String _selectedTimeHorizon = 'all'; // Filtre de période: 'all', 'short_term', 'medium_term', 'long_term'

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
      final patterns = await _analyzeMovementPatterns(products, timeHorizon ?? _selectedTimeHorizon);
      setState(() {
        _products = products;
        _movementPatterns = patterns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de chargement: ${e.toString()}');
    }
  }

  // Analyse des patterns de mouvement avec prise en compte de tous les types
  Future<List<MovementPattern>> _analyzeMovementPatterns(List<Product> products, String timeHorizon) async {
    List<MovementPattern> patterns = [];

    for (final product in products) {
      // Récupérer les mouvements avec le filtre de période
      final movements = await _stockMovementService.getMovementsForProduct(
        product.id!,
        timeHorizon: timeHorizon != 'all' ? timeHorizon : null,
      );

      // Compter chaque type de mouvement
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

      // Calcul d'un score d'activité (pondération pour chaque type)
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

      // Classification des patterns
      String patternCategory;
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

      patterns.add(MovementPattern(
        productId: product.id!,
        productName: product.designation,
        movementCounts: movementCounts,
        patternCategory: patternCategory,
        movementScore: movementScore,
      ));
    }

    // Trier par score d'activité
    patterns.sort((a, b) => b.movementScore.compareTo(a.movementScore));
    return patterns;
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
      height: 300, // Augmenté pour une meilleure lisibilité dans la popup agrandie
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: movementTypes
              .map((type) => pattern.movementCounts[type]!.toDouble())
              .reduce((a, b) => a > b ? a : b) * 1.2, // Échelle max + 20%
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24), // Légèrement augmenté pour un meilleur espacement
          constraints: const BoxConstraints(
            maxWidth: 800, // Agrandi de 600 à 800 pixels
            maxHeight: 700, // Ajout d'une hauteur maximale pour éviter un débordement
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pattern.productName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0056A6),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPatternChip(pattern.patternCategory, const Color(0xFF0056A6)),
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
            style: const TextStyle(color: Colors.white),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movementPatterns.isEmpty
              ? _buildEmptyState()
              : _buildAnalysisContent(),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movementPatterns.length,
      itemBuilder: (context, index) {
        final pattern = _movementPatterns[index];
        Color cardColor = Colors.white;
        Color textColor = const Color(0xFF0056A6);

        // Couleur basée sur la catégorie de pattern
        if (pattern.patternCategory.contains('Ventes Élevées')) {
          cardColor = const Color(0xFFE8F5E9);
          textColor = const Color(0xFF388E3C);
        } else if (pattern.patternCategory.contains('Retours Fréquents') ||
                   pattern.patternCategory.contains('Pertes Élevées')) {
          cardColor = const Color(0xFFFFF0F0);
          textColor = const Color(0xFFD32F2F);
        } else if (pattern.patternCategory.contains('Sur-Approvisionnement')) {
          cardColor = const Color(0xFFFFF8E1);
          textColor = const Color(0xFFF57C00);
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
                      child: Icon(
                        pattern.patternCategory.contains('Ventes') ? Icons.trending_up :
                        pattern.patternCategory.contains('Retours') ? Icons.undo :
                        pattern.patternCategory.contains('Pertes') ? Icons.warning :
                        Icons.analytics,
                        color: textColor,
                        size: 24,
                      ),
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
                          const SizedBox(height: 8),
                          _buildPatternChip(pattern.patternCategory, textColor),
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