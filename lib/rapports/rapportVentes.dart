import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:intl/intl.dart';
import 'rapportpdf.dart';

class RapportVentesPage extends StatefulWidget {
  const RapportVentesPage({super.key});

  @override
  State<RapportVentesPage> createState() => _RapportVentesPageState();
}

class _RapportVentesPageState extends State<RapportVentesPage> {
  final sqldb = SqlDb();
  Map<String, Map<String, dynamic>>? salesData;
  bool isLoading = true;
  DateTimeRange? dateRange;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    try {
      setState(() => isLoading = true);

      String? dateFilter;
      if (dateRange != null) {
        // Format dates to match the ISO format stored in database
        final startDate = dateRange!.start.toIso8601String();
        final endDate =
            dateRange!.end.add(const Duration(days: 1)).toIso8601String();
        dateFilter = "AND o.date >= '$startDate' AND o.date < '$endDate'";
      }

      final data = await sqldb.getSalesByCategoryAndProduct(dateFilter: dateFilter);

      setState(() {
        salesData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données: $e')),
      );
    }
  }

  double _calculateTotalSales() {
    if (salesData == null || salesData!.isEmpty) return 0.0;
    return salesData!.values.fold(
        0.0, (sum, categoryData) => sum + (categoryData['total'] as double));
  }

  Widget _buildCategoryTable(
      String category, Map<String, dynamic> categoryData) {
    final products = categoryData['products'] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10.0)),
            ),
            child: Row(
              // This is the correct way to provide a child
              children: [
                Expanded(
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    'Total: ${(categoryData['total'] as double).toStringAsFixed(2)} DT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (products.isNotEmpty) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: Colors.grey[100],
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('PRODUIT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        )),
                  ),
                  Expanded(
                    child: Text('QTÉ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                        textAlign: TextAlign.center),
                  ),
                  Expanded(
                    child: Text('PRIX U.',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                        textAlign: TextAlign.center),
                  ),
                  Expanded(
                    child: Text('REMISE',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                        textAlign: TextAlign.center),
                  ),
                  Expanded(
                    child: Text('TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.grey),
            ...products.entries.map((entry) {
              final productData = entry.value as Map<String, dynamic>;
              final unitPrice = (productData['total'] as double) /
                  (productData['quantity'] as int);

              return Container(
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.grey[200]!))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          productData['quantity'].toString(),
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          unitPrice.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          productData.containsKey('discount')
                              ? '${productData['discount'].toStringAsFixed(2)}%'
                              : '0.00%',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${productData['total'].toStringAsFixed(2)} DT',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Aucun produit vendu dans cette catégorie',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportButton({required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(left: 8.0),
      child: FloatingActionButton(
        onPressed: () {
          if (salesData == null || salesData!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucune donnée à exporter !')),
            );
            return;
          }

          final pdfGenerator = RapportPdf(
            salesData: salesData!,
            totalSales: _calculateTotalSales(),
            dateRange: dateRange,
          );

          pdfGenerator.generateAndPrintPdf(context);
        },
        backgroundColor: color,
        child: Icon(icon, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport des Ventes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0056A6),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 26),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                helpText: 'Sélectionner une période',
                cancelText: 'Annuler',
                confirmText: 'Confirmer',
                saveText: 'Enregistrer',
                fieldStartLabelText: 'Date de début',
                fieldEndLabelText: 'Date de fin',
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF0056A6),
                        onPrimary: Colors.white,
                        onSurface: Colors.black,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0056A6),
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => dateRange = picked);
                _loadSalesData();
              }
            },
            tooltip: 'Choisir une période',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 26),
            onPressed: _loadSalesData,
            tooltip: 'Actualiser les données',
          ),
        ],
      ),
      body: Column(
        children: [
          if (dateRange != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  bottom: BorderSide(color: Colors.blue[100]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Période du ${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} au ${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des données en cours...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : salesData == null || salesData!.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Aucune donnée de vente disponible',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            Text('Veuillez sélectionner une autre période',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 80),
                        children: [
                          const SizedBox(height: 8),
                          ...salesData!.entries
                              .map((entry) =>
                                  _buildCategoryTable(entry.key, entry.value))
                              .toList(),
                          const SizedBox(height: 16),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOTAL GÉNÉRAL: ${_calculateTotalSales().toStringAsFixed(2)} DT',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0056A6),
              ),
            ),
            Row(
              children: [
                _buildExportButton(
                  icon: Icons.picture_as_pdf,
                  color: Colors.red[700]!,
                ),
                _buildExportButton(
                  icon: Icons.insert_drive_file,
                  color: Colors.green[700]!,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
