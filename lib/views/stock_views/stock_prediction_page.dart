import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/services/stock_prediction_service.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockPredictionPage extends StatefulWidget {
  const StockPredictionPage({super.key});

  @override
  _StockPredictionPageState createState() => _StockPredictionPageState();
}

class _StockPredictionPageState extends State<StockPredictionPage> {
  final SqlDb _sqlDb = SqlDb();
  late final StockPredictionService _stockPredictionService;
  bool _isLoading = true;
  List<Product> _products = [];
  Map<String, Map<int, int>> _allPredictions = {
    'short_term': {},
    'medium_term': {},
    'long_term': {},
  };

  @override
  void initState() {
    super.initState();
    _stockPredictionService = StockPredictionService(_sqlDb);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final products = await _sqlDb.getProducts();
      final predictions = await _stockPredictionService.predictAllStockNeeds();
      setState(() {
        _products = products;
        _allPredictions = predictions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de chargement: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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

  void _showPredictionDetails(BuildContext context, Product product,
      int prediction, String timeHorizon) {
    final stockNeeded = prediction - product.stock;
    final percentage = product.stock > 0
        ? (stockNeeded / product.stock * 100).clamp(0, 200).toInt()
        : 100;

    Color primaryColor;
    IconData statusIcon;
    String statusText;

    if (stockNeeded > product.stock * 0.5) {
      primaryColor = const Color(0xFFD32F2F);
      statusIcon = Icons.warning_rounded;
      statusText = 'Niveau Critique';
    } else if (stockNeeded > 0) {
      primaryColor = const Color(0xFFF57C00);
      statusIcon = Icons.trending_up_rounded;
      statusText = 'Attention Requise';
    } else {
      primaryColor = const Color(0xFF388E3C);
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _stockPredictionService
                          .getProductPredictions(product.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
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
                                        _getTimeHorizonIcon(
                                            pred['time_horizon']),
                                        color: Colors.grey[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${pred['time_horizon']}: ',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${pred['predicted_quantity']} unités',
                                        style:
                                            TextStyle(color: Colors.grey[700]),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(
                                          DateTime.parse(
                                              pred['prediction_date']),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prédictions de Stock IA'),
        backgroundColor: const Color(0xFF0056A6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _buildEmptyState()
              : _buildPredictionContent(),
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

  Widget _buildPredictionContent() {
    return Column(
      children: [
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
              const Icon(Icons.lightbulb_outline,
                  color: Color(0xFFFFC107), size: 28),
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
                    final predictions =
                        await _stockPredictionService.predictAllStockNeeds();
                    await _stockPredictionService.savePredictions(
                        predictions['short_term']!,
                        timeHorizon: 'short_term');
                    await _stockPredictionService.savePredictions(
                        predictions['medium_term']!,
                        timeHorizon: 'medium_term');
                    await _stockPredictionService.savePredictions(
                        predictions['long_term']!,
                        timeHorizon: 'long_term');
                    setState(() {
                      _allPredictions = predictions;
                    });
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPredictionList('short_term', '30 jours'),
                      _buildPredictionList('medium_term', '90 jours'),
                      _buildPredictionList('long_term', '1 an'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionList(String timeHorizon, String horizonLabel) {
    final predictions = _allPredictions[timeHorizon] ?? {};
    final productsWithPredictions =
        _products.where((p) => predictions.containsKey(p.id)).toList();

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
              onTap: () => _showPredictionDetails(
                  context, product, prediction, timeHorizon),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 16),
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
                                  percentage > 50
                                      ? Icons.arrow_upward
                                      : Icons.trending_up,
                                  statusColor,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
}