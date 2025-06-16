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

  Future<void> sendEmailReport(BuildContext context) async {
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
                // pw.Text('Bénéfice total: ${totalProfit.toStringAsFixed(2)} DT'),
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
      final admins = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
      );

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

      // 5. Send email directly via SMTP without showing UI
      try {
        final smtpServer =
            gmail('bensalahyoussef111@gmail.com', 'awop mxzl myun ikgo');
        final message = Message()
          ..from = Address('noreply@chicopets.com', 'Caisse Chicopets')
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
    // Cette méthode n'est plus utilisée car on ne montre plus l'interface de rapport
    return Container();
  }
}
