import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

class FinancialReportPage extends StatefulWidget {
  const FinancialReportPage({super.key});

  @override
  _FinancialReportPageState createState() => _FinancialReportPageState();
}

class _FinancialReportPageState extends State<FinancialReportPage> {
  // Couleurs
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _paymentData = [];
  double _totalCash = 0;
  double _totalCard = 0;
  double _totalCheck = 0;
  double _totalMixed = 0;
  double _totalAll = 0;
  double _totalDiscount = 0;
  double _totalTicketRestaurant = 0;
  double _totalGiftTicket = 0;
  double _totalTraite = 0;
  double _totalVirement = 0;
  double _totalVoucher = 0;
  double _totalRemaining = 0;
  int _clientCount = 0;
  int _articleCount = 0;
  double _totalPercentageDiscount = 0;
  double _totalFixedDiscount = 0;

  @override
  void initState() {
    super.initState();
    _debugPrintAllOrders();
  }

  void _debugPrintAllOrders() async {
    final db = await SqlDb().db;
    final allOrders = await db.rawQuery('''
      SELECT id_order, date, total, mode_paiement 
      FROM orders 
      ORDER BY date DESC
    ''');
    print('Toutes les commandes dans la base:');
    for (var order in allOrders) {
      print(
          'Commande ${order['id_order']}: ${order['date']} - ${order['total']} DT (${order['mode_paiement']})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text('Rapports Financiers'),
        backgroundColor: deepBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(),
            const SizedBox(height: 20),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(deepBlue),
                ),
              )
            else if (_paymentData.isNotEmpty)
              Column(
                children: [
                  _buildFinancialSummary(),
                  const SizedBox(height: 20),
                  _buildExportButton(),
                ],
              )
            else if (_startDate != null)
              Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 50, color: darkBlue),
                      const SizedBox(height: 10),
                      Text(
                        'Aucune donnée disponible\npour la période sélectionnée',
                        style: TextStyle(
                            fontSize: 16,
                            color: darkBlue,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ]),
              )
            else
              Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 50, color: darkBlue),
                      const SizedBox(height: 10),
                      Text(
                        'Sélectionnez une période\npour générer le rapport',
                        style: TextStyle(
                            fontSize: 16,
                            color: darkBlue,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ]),
              ),
          ],
        ),
      ),
    );
  }

  // Remplacer la méthode _buildDateSelector par ceci :
  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: deepBlue),
                const SizedBox(width: 8),
                Text(
                  'Sélectionner la période:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: darkBlue),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate != null
                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                          : 'Début',
                    ),
                    onPressed: () => _pickDate(isStartDate: true),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: darkBlue,
                      backgroundColor: lightGray,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _endDate != null
                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                          : 'Fin',
                    ),
                    onPressed: () => _pickDate(isStartDate: false),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: darkBlue,
                      backgroundColor: lightGray,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_startDate != null || _endDate != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: deepBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Période sélectionnée:',
                      style: TextStyle(color: darkBlue),
                    ),
                    Text(
                      '${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : '--'} '
                      'à ${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : '--'}',
                      style: TextStyle(
                          color: darkBlue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (_startDate != null)
              Center(
                child: SizedBox(
                  child: ElevatedButton(
                    onPressed: _fetchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepBlue,
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, color: white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Générer Rapport',
                          style: TextStyle(color: white),
                        ),
                      ],
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

// Ajouter cette nouvelle méthode pour le picker de dates
  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    // Si on sélectionne une date de fin et qu'il n'y a pas de date de début,
    // on force la sélection de la date de début d'abord
    if (!isStartDate && _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez d\'abord sélectionner une date de début'),
          backgroundColor: warmRed,
        ),
      );
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? (_endDate ?? DateTime.now()),
      firstDate: isStartDate ? firstDate : _startDate!,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: deepBlue,
              onPrimary: white,
              onSurface: darkBlue,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: deepBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          // Si la date de fin est antérieure à la nouvelle date de début, on la réinitialise
          if (_endDate != null && _endDate!.isBefore(pickedDate)) {
            _endDate = null;
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Widget _buildFinancialSummary() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: lightGray, width: 1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.assessment, color: deepBlue, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'Résumé Financier',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: darkBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Chiffre d'affaires
            _buildSectionHeader('Chiffre d\'affaires', icon: Icons.bar_chart),
            _buildAmountCard(_totalAll, 'Total', tealGreen),
            const SizedBox(height: 16),

            // Paiements
            _buildSectionHeader('Détails des paiements', icon: Icons.payments),
            _buildPaymentDetailsSection(),
            const SizedBox(height: 16),

            // Remises
            // Section Remises
            _buildSectionHeader('Remises appliquées'),
            if (_totalPercentageDiscount == 0 && _totalFixedDiscount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Aucune remise faite',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              )
            else ...[
              if (_totalPercentageDiscount > 0)
                _buildDiscountItem('%', _totalPercentageDiscount),
              if (_totalFixedDiscount > 0)
                _buildDiscountItem('DT', _totalFixedDiscount),
            ],

            // Statistiques
            _buildSectionHeader('Statistiques', icon: Icons.pie_chart_outline),
            _buildStatisticsGrid(),
            const SizedBox(height: 16),

            // En attente
            if (_totalRemaining > 0) ...[
              _buildSectionHeader('En attente', icon: Icons.pending_actions),
              _buildPendingAmountCard(_totalRemaining),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 18, color: deepBlue),
          if (icon != null) const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(double amount, String label, Color color) {
    return Card(
      color: color.withOpacity(0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: color)),
            const SizedBox(height: 6),
            Text(
              '${amount.toStringAsFixed(2)} DT',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    return Card(
      color: lightGray.withOpacity(0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            if (_totalCash > 0)
              _buildPaymentDetailItem('Espèces', _totalCash, Icons.money),
            if (_totalCard > 0)
              _buildPaymentDetailItem('Carte', _totalCard, Icons.credit_card),
            if (_totalCheck > 0)
              _buildPaymentDetailItem(
                  'Chèque', _totalCheck, Icons.account_balance),
            if (_totalTicketRestaurant > 0)
              _buildPaymentDetailItem('Ticket Restaurant',
                  _totalTicketRestaurant, Icons.restaurant),
            if (_totalGiftTicket > 0)
              _buildPaymentDetailItem(
                  'Ticket cadeau', _totalGiftTicket, Icons.card_giftcard),
            if (_totalTraite > 0)
              _buildPaymentDetailItem(
                  'Traite', _totalTraite, Icons.receipt_long),
            if (_totalVirement > 0)
              _buildPaymentDetailItem(
                  'Virement', _totalVirement, Icons.account_balance_wallet),
            if (_totalVoucher > 0)
              _buildPaymentDetailItem(
                  'Bon d\'achat', _totalVoucher, Icons.confirmation_number),
            if (_totalMixed > 0)
              _buildPaymentDetailItem('Mixtes', _totalMixed, Icons.blur_on),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailItem(String label, double value, IconData icon) {
    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: deepBlue, size: 26),
      title: Text(
        label,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        '${value.toStringAsFixed(2)} DT',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: darkBlue,
        ),
      ),
    );
  }

  Widget _buildDiscountItem(String type, double value) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(Icons.discount, color: warmRed),
      title: Text('Remise ($type)'),
      trailing: Text(
        type == '%'
            ? '${value.toStringAsFixed(1)}%'
            : '-${value.toStringAsFixed(2)} DT',
        style: TextStyle(fontWeight: FontWeight.bold, color: warmRed),
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatisticItem('Clients', _clientCount, Icons.people),
        _buildStatisticItem('Articles', _articleCount, Icons.shopping_basket),
      ],
    );
  }

  Widget _buildStatisticItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: softOrange, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: softOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingAmountCard(double amount) {
    return Card(
      color: warmRed.withOpacity(0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: warmRed.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text('Montant à recevoir',
                style: TextStyle(fontSize: 14, color: warmRed)),
            const SizedBox(height: 6),
            Text(
              '${amount.toStringAsFixed(2)} DT',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: warmRed),
            ),
            const SizedBox(height: 4),
            Text(
              '(Non réglé)',
              style: TextStyle(
                  fontSize: 12, fontStyle: FontStyle.italic, color: warmRed),
            ),
          ],
        ),
      ),
    );
  }

// Méthode pour les lignes principales de paiement
  Widget _buildPaymentRow(String label, double value, IconData icon,
      {bool hasMixed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: darkBlue),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: darkBlue,
                    ),
                  ),
                  if (hasMixed) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Inclut les paiements mixtes',
                      child: Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              Text(
                '${value.toStringAsFixed(2)} DT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

// Méthode pour les sous-lignes de détail
  Widget _buildPaymentSubRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 32, top: 4, bottom: 4), // Augmentez le padding left
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: darkBlue.withOpacity(0.8),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} DT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500, // Ajoutez un peu de gras
              color: darkBlue.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

// Méthode pour les lignes de résumé
  Widget _buildSummaryRow(
    String label,
    double value,
    IconData icon, {
    bool isMain = false,
    bool isDiscount = false,
    bool isCount = false,
    bool isAlert = false,
    String suffix = '',
  }) {
    Color textColor = darkBlue;
    if (isDiscount) textColor = warmRed;
    if (isAlert) textColor = softOrange;
    if (isMain) textColor = deepBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMain ? 16 : 15,
                  color: textColor,
                  fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          Text(
            isCount
                ? '${value.toInt()}$suffix'
                : '${value.toStringAsFixed(2)}$suffix',
            style: TextStyle(
              fontSize: isMain ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(Map<String, dynamic> payment) {
    String details = '';

    if (payment['modePaiement'] == 'Espèce') {
      details =
          'Espèces: ${payment['cashAmount']?.toStringAsFixed(2) ?? '0.00'} DT';
    } else if (payment['modePaiement'] == 'TPE') {
      details =
          'Carte: ${payment['cardAmount']?.toStringAsFixed(2) ?? '0.00'} DT\n'
          'Transaction: ${payment['cardTransactionId'] ?? 'N/A'}';
    } else if (payment['modePaiement'] == 'Chèque') {
      details =
          'Chèque: ${payment['checkAmount']?.toStringAsFixed(2) ?? '0.00'} DT\n'
          'N°: ${payment['checkNumber'] ?? 'N/A'}\n'
          'Banque: ${payment['bankName'] ?? 'N/A'}\n'
          'Date: ${payment['checkDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(payment['checkDate'])) : 'N/A'}';
    } else if (payment['modePaiement'] == 'Mixte') {
      details =
          'Espèces: ${payment['cashAmount']?.toStringAsFixed(2) ?? '0.00'} DT\n'
          'Carte: ${payment['cardAmount']?.toStringAsFixed(2) ?? '0.00'} DT\n'
          'Chèque: ${payment['checkAmount']?.toStringAsFixed(2) ?? '0.00'} DT';
    }

    return Tooltip(
      message: details,
      child: Icon(Icons.info_outline, color: deepBlue),
    );
  }

  Widget _buildExportButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(Icons.picture_as_pdf, color: white),
        label: Text('Exporter en PDF', style: TextStyle(color: white)),
        onPressed: _exportToPDF,
        style: ElevatedButton.styleFrom(
          backgroundColor: deepBlue,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _fetchData() async {
    if (_startDate == null) return;

    setState(() => _isLoading = true);

    try {
      final db = await SqlDb().db;
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endDateStr = _endDate != null
          ? DateFormat('yyyy-MM-dd').format(_endDate!)
          : startDateStr;

      final result = await db.rawQuery('''
      SELECT 
        id_order as idOrder,
        date,
        mode_paiement as modePaiement,
        total as amount,
        cash_amount as cashAmount,
        card_amount as cardAmount,
        check_amount as checkAmount,
        ticket_restaurant_amount as ticketRestaurantAmount,
        gift_ticket_amount as giftTicketAmount,
        traite_amount as traiteAmount,
        virement_amount as virementAmount,
        voucher_amount as voucherAmount,
        global_discount as discount,
        is_percentage_discount as isPercentageDiscount,
        remaining_amount as remainingAmount,
        id_client as idClient
      FROM orders 
      WHERE date(date) BETWEEN date(?) AND date(?)
      ORDER BY date DESC
    ''', [startDateStr, endDateStr]);

      // Initialize all payment type totals
      double totalCash = 0;
      double totalCard = 0;
      double totalCheck = 0;
      double totalTicketRestaurant = 0;
      double totalGiftTicket = 0;
      double totalTraite = 0;
      double totalVirement = 0;
      double totalVoucher = 0;
      double totalMixed = 0;
      double totalPercentageDiscount = 0;
      double totalFixedDiscount = 0;
      double totalRemaining = 0;
      int clientCount = 0;
      int articleCount = 0;
      Set<int> uniqueClients = Set();

      // Calculate sold articles
      final articlesResult = await db.rawQuery('''
      SELECT SUM(quantity) as total 
      FROM order_items oi
      JOIN orders o ON oi.id_order = o.id_order
      WHERE date(o.date) BETWEEN date(?) AND date(?)
    ''', [startDateStr, endDateStr]);

      articleCount =
          int.tryParse(articlesResult.first['total']?.toString() ?? '0') ?? 0;

      for (var payment in result) {
        final idClient = payment['idClient'] as int?;
        final modePaiement = payment['modePaiement'] as String?;
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
        final cashAmount = (payment['cashAmount'] as num?)?.toDouble() ?? 0.0;
        final cardAmount = (payment['cardAmount'] as num?)?.toDouble() ?? 0.0;
        final checkAmount = (payment['checkAmount'] as num?)?.toDouble() ?? 0.0;
        final ticketRestaurantAmount =
            (payment['ticketRestaurantAmount'] as num?)?.toDouble() ?? 0.0;
        final giftTicketAmount =
            (payment['giftTicketAmount'] as num?)?.toDouble() ?? 0.0;
        final traiteAmount =
            (payment['traiteAmount'] as num?)?.toDouble() ?? 0.0;
        final virementAmount =
            (payment['virementAmount'] as num?)?.toDouble() ?? 0.0;
        final voucherAmount =
            (payment['voucherAmount'] as num?)?.toDouble() ?? 0.0;
        final discount = (payment['discount'] as num?)?.toDouble() ?? 0.0;
        final isPercentage = payment['isPercentageDiscount'] == 1;
        final remainingAmount =
            (payment['remainingAmount'] as num?)?.toDouble() ?? 0.0;

        if (idClient != null) {
          uniqueClients.add(idClient);
        }

        // Calculate totals by payment type
        switch (modePaiement) {
          case 'Espèce':
            totalCash += amount;
            break;
          case 'TPE':
            totalCard += amount;
            break;
          case 'Chèque':
            totalCheck += amount;
            break;
          case 'Ticket Restaurant':
            totalTicketRestaurant += amount;
            break;
          case 'Ticket cadeau':
            totalGiftTicket += amount;
            break;
          case 'Traite':
            totalTraite += amount;
            break;
          case 'Virement':
            totalVirement += amount;
            break;
          case 'Bon d\'achat':
            totalVoucher += amount;
            break;
          case 'Mixte':
            totalMixed += amount;
            break;
        }

        // Calculate discounts
        if (isPercentage) {
          totalPercentageDiscount += discount;
        } else {
          totalFixedDiscount += discount;
        }

        totalRemaining += remainingAmount;
      }

      clientCount = uniqueClients.length;

      // Total is sum of all payment types
      double totalAll = totalCash +
          totalCard +
          totalCheck +
          totalTicketRestaurant +
          totalGiftTicket +
          totalTraite +
          totalVirement +
          totalVoucher +
          totalMixed;

      setState(() {
        _paymentData = result;
        _totalCash = totalCash;
        _totalCard = totalCard;
        _totalCheck = totalCheck;
        _totalTicketRestaurant = totalTicketRestaurant;
        _totalGiftTicket = totalGiftTicket;
        _totalTraite = totalTraite;
        _totalVirement = totalVirement;
        _totalVoucher = totalVoucher;
        _totalMixed = totalMixed;
        _totalAll = totalAll;
        _totalPercentageDiscount = totalPercentageDiscount;
        _totalFixedDiscount = totalFixedDiscount;
        _totalRemaining = totalRemaining;
        _clientCount = clientCount;
        _articleCount = articleCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: warmRed,
        ),
      );
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('Rapport Financier',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      )),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Période: ${DateFormat('dd/MM/yyyy').format(_startDate!)}'
                  '${_endDate != null ? ' - ${DateFormat('dd/MM/yyyy').format(_endDate!)}' : ''}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Total Sales
                _buildPdfSummaryRow('TOTAL VENTES', _totalAll, isMain: true),
                pw.SizedBox(height: 10),

                // Payment Details
                if (_totalCash > 0) _buildPdfDetailRow('Espèces', _totalCash),
                if (_totalCard > 0) _buildPdfDetailRow('Carte', _totalCard),
                if (_totalCheck > 0) _buildPdfDetailRow('Chèque', _totalCheck),
                if (_totalTicketRestaurant > 0)
                  _buildPdfDetailRow(
                      'Ticket Restaurant', _totalTicketRestaurant),
                if (_totalGiftTicket > 0)
                  _buildPdfDetailRow('Ticket cadeau', _totalGiftTicket),
                if (_totalTraite > 0)
                  _buildPdfDetailRow('Traite', _totalTraite),
                if (_totalVirement > 0)
                  _buildPdfDetailRow('Virement', _totalVirement),
                if (_totalVoucher > 0)
                  _buildPdfDetailRow('Bon d\'achat', _totalVoucher),
                if (_totalMixed > 0) _buildPdfDetailRow('Mixtes', _totalMixed),

                pw.SizedBox(height: 10),
                pw.Divider(),

                // Discounts
                if (_totalPercentageDiscount > 0)
                  _buildPdfSummaryRow('Remise (%)', _totalPercentageDiscount,
                      isDiscount: true, suffix: '%'),
                if (_totalFixedDiscount > 0)
                  _buildPdfSummaryRow('Remise (DT)', _totalFixedDiscount,
                      isDiscount: true),

                // Pending
                if (_totalRemaining > 0)
                  _buildPdfSummaryRow('À recevoir', _totalRemaining,
                      isAlert: true),

                // Statistics
                pw.SizedBox(height: 10),
                _buildPdfSummaryRow('Clients', _clientCount.toDouble(),
                    isCount: true),
                _buildPdfSummaryRow('Articles', _articleCount.toDouble(),
                    isCount: true),

                // Footer
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'rapport_financier_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

// Méthodes helpers pour construire les lignes du PDF
  pw.Widget _buildPdfSummaryRow(
    String label,
    double value, {
    bool isMain = false,
    bool isDiscount = false,
    bool isCount = false,
    bool isAlert = false,
    String suffix = '',
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isMain ? 10 : 8,
            fontWeight: isMain ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          isCount
              ? '${value.toInt()}$suffix'
              : '${value.toStringAsFixed(2)}$suffix',
          style: pw.TextStyle(
            fontSize: isMain ? 11 : 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfDetailRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            '${value.toStringAsFixed(2)} DT',
            style: pw.TextStyle(
              // Removed `const` here
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
