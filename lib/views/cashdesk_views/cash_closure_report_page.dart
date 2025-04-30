import 'dart:convert';

import 'package:caissechicopets/home_page.dart';
import 'package:caissechicopets/models/cash_state.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashClosureReportPage extends StatelessWidget {
  final CashState cashState;
  final SqlDb _sqlDb = SqlDb();

  CashClosureReportPage({super.key, required this.cashState});

  Future<List<Order>> _getOrdersSinceOpening() async {
    if (cashState.openingTime == null) return [];
    
    final db = await _sqlDb.db;
    final result = await db.query(
      'orders',
      where: 'date >= ? AND status IN (?, ?)',
      whereArgs: [
        cashState.openingTime!.toIso8601String(),
        'payée',
        'semi-payée'
      ],
    );
    
    final orders = <Order>[];
    for (var e in result) {
      final orderLines = await _getOrderLinesForOrder(e['id_order'] as int);
      orders.add(Order.fromMap(e, orderLines));
    }
    return orders;
  }

  Future<List<OrderLine>> _getOrderLinesForOrder(int orderId) async {
    final db = await _sqlDb.db;
    final result = await db.query(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    return result.map((e) => OrderLine.fromMap(e)).toList();
  }

  Future<User?> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    return userJson != null ? User.fromMap(jsonDecode(userJson)) : null;
  }

  Future<double> _calculateTotalSales(List<Order> orders) async {
  double total = 0.0;
  for (var order in orders) {
    total += order.total ?? 0.0;
  }
  return total;
}

  Future<double> _calculateTotalProfit(List<Order> orders) async {
    double totalProfit = 0.0;
    
    for (var order in orders) {
      for (var line in order.orderLines) {
        final product = await _sqlDb.getProductById(line.productId!);
        if (product != null) {
          double costPrice = product.prixHT;
          double sellingPrice = line.prixUnitaire * (1 - (line.discount / 100));
          totalProfit += (sellingPrice - costPrice) * line.quantity;
        }
      }
    }
    
    return totalProfit;
  }

  Future<Map<String, int>> _getProductsSold(List<Order> orders) async {
    Map<String, int> productsSold = {};
    
    for (var order in orders) {
      for (var line in order.orderLines) {
        final product = await _sqlDb.getProductById(line.productId!);
        if (product != null) {
          String key = product.designation;
          if (line.variantName != null) {
            key += " (${line.variantName})";
          }
          productsSold[key] = (productsSold[key] ?? 0) + line.quantity;
        }
      }
    }
    
    return productsSold;
  }

  Future<void> _printReport(BuildContext context) async {
    try {
      final orders = await _getOrdersSinceOpening();
      final user = await _getCurrentUser();
      final totalSales = await _calculateTotalSales(orders);
      final totalProfit = await _calculateTotalProfit(orders);
      final productsSold = await _getProductsSold(orders);
      final newCashAmount = cashState.initialAmount + totalSales;

      // Create PDF
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    'Rapport de Clôture de Caisse',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),

                // General Info
                pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                if (user != null) pw.Text('Caissier: ${user.username}'),
                pw.SizedBox(height: 10),
                pw.Divider(),

                // Opening/Closing Info
                pw.Text('Ouverture: ${DateFormat('dd/MM/yyyy HH:mm').format(cashState.openingTime!)}'),
                pw.Text('Clôture: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                pw.SizedBox(height: 10),
                pw.Divider(),

                // Financial Summary
                pw.Text('Fond initial: ${cashState.initialAmount.toStringAsFixed(2)} DT'),
                pw.Text('Total ventes: ${totalSales.toStringAsFixed(2)} DT'),
                pw.Text('Bénéfice total: ${totalProfit.toStringAsFixed(2)} DT'),
                pw.Text('Nouveau fond de caisse: ${newCashAmount.toStringAsFixed(2)} DT'),
                pw.SizedBox(height: 10),
                pw.Divider(),

                // Products Sold
                pw.Text('Produits vendus:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...productsSold.entries.map((entry) {
                  return pw.Text('- ${entry.key}: ${entry.value}');
                }).toList(),
                pw.SizedBox(height: 10),
                pw.Divider(),

                // Orders Summary
                pw.Text('Commandes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...orders.map((order) {
                  return pw.Text('- #${order.idOrder} (${DateFormat('dd/MM HH:mm').format(DateTime.parse(order.date))}): ${order.total.toStringAsFixed(2)} DT');
                }).toList(),

                // Footer
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text('*** Merci de votre travail ***'),
                ),
              ],
            );
          },
        ),
      );

      // Print the document
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      // Return to home page
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rapport de clôture'),
      ),
      body: FutureBuilder(
        future: Future.wait([
          _getOrdersSinceOpening(),
          _getCurrentUser(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data![0] as List<Order>;
          final user = snapshot.data![1] as User?;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Rapport de caisse',
                            style: GoogleFonts.poppins(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Divider(),
                        _buildReportRow('Ouverture', cashState.openingTime),
                        _buildReportRow('Clôture', DateTime.now()),
                        _buildReportRow('Fond initial',
                            '${cashState.initialAmount.toStringAsFixed(2)} DT'),
                        Divider(),
                        _buildReportRow('Caissier', user?.username ?? 'N/A'),
                        _buildReportRow('Nombre de commandes', orders.length),
                        FutureBuilder<double>(
                          future: _calculateTotalSales(orders),
                          builder: (context, salesSnapshot) {
                            if (!salesSnapshot.hasData) {
                              return _buildReportRow('Total ventes', 'Calcul...');
                            }
                            return _buildReportRow(
                              'Total ventes',
                              '${salesSnapshot.data!.toStringAsFixed(2)} DT',
                            );
                          },
                        ),
                        FutureBuilder<double>(
                          future: _calculateTotalProfit(orders),
                          builder: (context, profitSnapshot) {
                            if (!profitSnapshot.hasData) {
                              return _buildReportRow('Bénéfice total', 'Calcul...');
                            }
                            return _buildReportRow(
                              'Bénéfice total',
                              '${profitSnapshot.data!.toStringAsFixed(2)} DT',
                            );
                          },
                        ),
                        FutureBuilder<double>(
                          future: _calculateTotalSales(orders),
                          builder: (context, salesSnapshot) {
                            if (!salesSnapshot.hasData) {
                              return _buildReportRow('Nouveau fond de caisse', 'Calcul...');
                            }
                            final newCashAmount = cashState.initialAmount + (salesSnapshot.data ?? 0);
                            return _buildReportRow(
                              'Nouveau fond de caisse',
                              '${newCashAmount.toStringAsFixed(2)} DT',
                            );
                          },
                        ),
                        Divider(),
                        Text('Produits vendus:',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        FutureBuilder<Map<String, int>>(
                          future: _getProductsSold(orders),
                          builder: (context, productsSnapshot) {
                            if (!productsSnapshot.hasData) {
                              return Center(child: CircularProgressIndicator());
                            }
                            
                            return Column(
                              children: productsSnapshot.data!.entries.map((entry) {
                                return _buildReportRow(entry.key, '${entry.value} unités');
                              }).toList(),
                            );
                          },
                        ),
                        Divider(),
                        Text('Commandes:',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        ...orders.map((order) {
                          return _buildReportRow(
                            '#${order.idOrder} (${DateFormat('dd/MM HH:mm').format(DateTime.parse(order.date))})',
                            '${order.total.toStringAsFixed(2)} DT',
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _printReport(context),
                  icon: Icon(Icons.print),
                  label: Text('Enregistrer et imprimer rapport'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                  child: Text('Retour à l\'accueil'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          if (value is DateTime)
            Text('${value.day}/${value.month}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}'),
          if (value is String) Text(value),
        ],
      ),
    );
  }
}