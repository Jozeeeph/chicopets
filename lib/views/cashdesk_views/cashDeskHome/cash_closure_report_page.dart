import 'dart:convert';
import 'dart:io';
import 'package:caissechicopets/views/home_views/home_page.dart';
import 'package:caissechicopets/models/cash_state.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
      total += order.total;
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

  Future<void> printReport(BuildContext context) async {
    try {
      // 1. Fetch all necessary data
      final orders = await _getOrdersSinceOpening();
      final user = await _getCurrentUser();
      final totalSales = await _calculateTotalSales(orders);
      final totalProfit = await _calculateTotalProfit(orders);
      final productsSold = await _getProductsSold(orders);
      final newCashAmount = cashState.initialAmount + totalSales;

      // 2. Generate PDF document
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Rapport de Clôture de Caisse',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text(
                    'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                if (user != null) pw.Text('Caissier: ${user.username}'),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text(
                    'Ouverture: ${DateFormat('dd/MM/yyyy HH:mm').format(cashState.openingTime!)}'),
                pw.Text(
                    'Clôture: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text(
                    'Fond initial: ${cashState.initialAmount.toStringAsFixed(2)} DT'),
                pw.Text('Total ventes: ${totalSales.toStringAsFixed(2)} DT'),
                pw.Text('Bénéfice total: ${totalProfit.toStringAsFixed(2)} DT'),
                pw.Text(
                    'Nouveau fond de caisse: ${newCashAmount.toStringAsFixed(2)} DT'),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text('Produits vendus:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...productsSold.entries
                    .map((entry) => pw.Text('- ${entry.key}: ${entry.value}')),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text('Commandes:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...orders.map((order) => pw.Text(
                    '- #${order.idOrder} (${DateFormat('dd/MM HH:mm').format(DateTime.parse(order.date))}): ${order.total.toStringAsFixed(2)} DT')),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text('*** Merci de votre travail ***')),
              ],
            );
          },
        ),
      );

      // 3. Save PDF to temporary file
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/rapport_cloture_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      // 4. Get admin emails from database
      final db = await _sqlDb.db;
      final userJson = await _sqlDb.getAllUsers();
      print('Users: $userJson');
      final admins = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
      );
      print('Admins: $admins');

      if (admins.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun administrateur trouvé')),
          );
        }
        return;
      }

      final adminEmails = admins
          .map((a) => a['mail'] as String?)
          .where((email) => email != null && email.isNotEmpty)
          .toList();

      if (adminEmails.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun email administrateur trouvé')),
          );
        }
        return;
      }

      // 5. Option 1: Open email client with mailto (simpler)
      final emailLaunchUri = Uri(
        scheme: 'mailto',
        path: adminEmails.join(','),
        queryParameters: {
          'subject':
              'Rapport de clôture de caisse - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
          'body':
              'Bonjour,\n\nVeuillez trouver ci-joint le rapport de clôture de caisse.\n\nCordialement,\n${user?.username ?? "Le caissier"}',
        },
      );

      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Impossible d\'ouvrir le client email')),
          );
        }
      }

      // 5. Option 2: Direct SMTP sending (more control)
      try {
        final smtpServer =
            gmail('bensalahyoussef111@gmail.com', 'awop mxzl myun ikgo');
        final message = Message()
          ..from = Address('noreply@yourdomain.com', 'Caisse Chicopets')
          ..recipients.addAll(adminEmails)
          ..subject =
              'Rapport de clôture de caisse - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'
          ..text =
              'Bonjour,\n\nVeuillez trouver ci-joint le rapport de clôture de caisse.\n\nCordialement,\n${user?.username ?? "Le caissier"}'
          ..attachments.add(FileAttachment(file));

        await send(message, smtpServer);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Rapport envoyé par email avec succès')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'envoi du email: $e')),
          );
        }
      }

      // 6. Show print dialog
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());

      // 7. Return to home page
      if (context.mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const HomePage()));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors de la génération du rapport: $e')),
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Titre principal
                        Text('Rapport de caisse',
                            style: GoogleFonts.poppins(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 16),

                        // Deux colonnes (cards)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Première colonne (gauche)
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Informations générales',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Divider(),
                                      _buildReportRow(
                                          'Ouverture', cashState.openingTime),
                                      _buildReportRow(
                                          'Clôture', DateTime.now()),
                                      _buildReportRow(
                                          'Caissier', user?.username ?? 'N/A'),
                                      _buildReportRow(
                                          'Nombre de commandes', orders.length),
                                      SizedBox(height: 8),
                                      Text('Résumé financier',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Divider(),
                                      _buildReportRow('Fond initial',
                                          '${cashState.initialAmount.toStringAsFixed(2)} DT'),
                                      FutureBuilder<double>(
                                        future: _calculateTotalSales(orders),
                                        builder: (context, salesSnapshot) {
                                          if (!salesSnapshot.hasData) {
                                            return _buildReportRow(
                                                'Total ventes', 'Calcul...');
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
                                            return _buildReportRow(
                                                'Bénéfice total', 'Calcul...');
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
                                            return _buildReportRow(
                                                'Nouveau fond de caisse',
                                                'Calcul...');
                                          }
                                          final newCashAmount =
                                              cashState.initialAmount +
                                                  (salesSnapshot.data ?? 0);
                                          return _buildReportRow(
                                            'Nouveau fond de caisse',
                                            '${newCashAmount.toStringAsFixed(2)} DT',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(width: 16),

                            // Deuxième colonne (droite)
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Produits vendus',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Divider(),
                                      FutureBuilder<Map<String, int>>(
                                        future: _getProductsSold(orders),
                                        builder: (context, productsSnapshot) {
                                          if (!productsSnapshot.hasData) {
                                            return Center(
                                                child:
                                                    CircularProgressIndicator());
                                          }

                                          return productsSnapshot.data!.isEmpty
                                              ? Text('Aucun produit vendu')
                                              : Column(
                                                  children: productsSnapshot
                                                      .data!.entries
                                                      .map((entry) {
                                                    return _buildReportRow(
                                                      entry.key,
                                                      '${entry.value} unités',
                                                    );
                                                  }).toList(),
                                                );
                                        },
                                      ),
                                      SizedBox(height: 16),
                                      Text('Commandes',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Divider(),
                                      orders.isEmpty
                                          ? Text('Aucune commande')
                                          : Column(
                                              children: orders.map((order) {
                                                return _buildReportRow(
                                                  '#${order.idOrder} (${DateFormat('dd/MM HH:mm').format(DateTime.parse(order.date))})',
                                                  '${order.total.toStringAsFixed(2)} DT',
                                                );
                                              }).toList(),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Boutons en bas
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => printReport(context),
                            icon: Icon(Icons.print),
                            label: Text(
                              'Enregistrer et imprimer rapport',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomePage()),
                              );
                            },
                            child: Text(
                              'Retour à l\'accueil',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (value is DateTime)
            Text(
              DateFormat('dd/MM HH:mm').format(value),
              style: GoogleFonts.poppins(),
            ),
          if (value is String)
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.poppins(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (value is int)
            Text(
              value.toString(),
              style: GoogleFonts.poppins(),
            ),
        ],
      ),
    );
  }
}
