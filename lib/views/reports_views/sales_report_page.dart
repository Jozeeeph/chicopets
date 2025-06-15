import 'dart:io';

import 'package:caissechicopets/models/variant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

class SalesReportPage extends StatefulWidget {
  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  // Couleurs
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  DateTime? _selectedStartDate = DateTime.now();
  DateTime? _selectedEndDate = DateTime.now();
  List<User> _users = [];
  User? _selectedUser;
  bool _groupByUser = false;
  List<Map<String, dynamic>> _salesData = [];
  bool _isLoading = false;
  bool _showDownloadButton = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final db = SqlDb();
    _users = await db.getAllUsers();
    print(
        "Loaded users: ${_users.map((u) => '${u.id}: ${u.username}').join(', ')}"); // Debug
    setState(() {});
  }

  Future<void> _generateReport() async {
    if (_selectedStartDate == null) return;

    if (_groupByUser && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez sélectionner un utilisateur'),
          backgroundColor: warmRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showDownloadButton = false;
    });

    try {
      print(
          'Generating report for dates: $_selectedStartDate to $_selectedEndDate');

      if (_groupByUser) {
        print('Generating user report for user ID: ${_selectedUser!.id}');
        _salesData = await _getSalesReportByUser(_selectedUser!.id!);
      } else {
        print('Generating category report');
        _salesData = await _getSalesReportByCategory();
      }

      print('Report generated with ${_salesData.length} categories');
    } catch (e, stack) {
      print('Error generating report: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du rapport: $e'),
          backgroundColor: warmRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _showDownloadButton = _salesData.isNotEmpty;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getSalesReportByCategory() async {
    final db = SqlDb();
    final orders = await db.getOrders();

    // Filter orders by date range
    final filteredOrders = orders.where((order) {
      final orderDate = DateTime.parse(order.date).toLocal();
      return _isDateInRange(orderDate, _selectedStartDate!, _selectedEndDate!);
    }).toList();

    final Map<String, Map<String, dynamic>> reportData = {};

    for (final order in filteredOrders) {
      for (final line in order.orderLines) {
        final product = await db.getProductById(line.productId ?? 0);
        if (product == null) continue;

        final category = await db.getCategoryNameById(product.categoryId);
        final categoryName = category;

        if (!reportData.containsKey(categoryName)) {
          reportData[categoryName] = {
            'total': 0.0,
            'totalDiscount': 0.0,
            'totalBeforeDiscount': 0.0,
            'totalAfterDiscount': 0.0,
            'globalDiscount': 0.0,
            'products': <String, Map<String, dynamic>>{},
            'discountDetails':
                [], // Pour stocker les détails des remises globales
          };
        }

        // Ajouter la remise globale si elle existe
        if (order.globalDiscount > 0) {
          double globalDiscountAmount = order.isPercentageDiscount
              ? (line.finalPrice * line.quantity) * (order.globalDiscount / 100)
              : (order.globalDiscount *
                  (line.finalPrice * line.quantity) /
                  order.total);

          reportData[categoryName]!['globalDiscount'] += globalDiscountAmount;
          reportData[categoryName]!['discountDetails'].add({
            'type': 'Globale',
            'amount': globalDiscountAmount,
            'isPercentage': order.isPercentageDiscount,
            'value': order.globalDiscount,
            'orderId': order.idOrder,
          });
        }

        // Get variant details if available
        Variant? variant;
        if (line.variantId != null) {
          variant = await db.getVariantById(line.variantId!);
        }

        final unitPrice = variant?.finalPrice ?? line.prixUnitaire;
        final lineTotalBeforeDiscount = unitPrice * line.quantity;

        // Calcul des remises ligne
        double discountAmount = 0;
        if (line.isPercentage) {
          discountAmount = lineTotalBeforeDiscount * (line.discount / 100);
        } else {
          discountAmount = line.discount * line.quantity;
        }

        final lineTotal = lineTotalBeforeDiscount - discountAmount;
        final productKey = "${line.productName}";

        if (!reportData[categoryName]!['products'].containsKey(productKey)) {
          reportData[categoryName]!['products'][productKey] = {
            'quantity': 0,
            'total': 0.0,
            'totalBeforeDiscount': 0.0,
            'discount': 0.0,
            'isPercentage': line.isPercentage,
            'variant':
                variant?.combinationName ?? line.variantName ?? 'Standard',
            'unitPrice': unitPrice,
            'discountDetails': [], // Pour stocker les détails des remises ligne
          };
        }

        // Mise à jour des totaux
        reportData[categoryName]!['products'][productKey]!['quantity'] +=
            line.quantity;
        reportData[categoryName]!['products'][productKey]!['total'] +=
            lineTotal;
        reportData[categoryName]!['products']
            [productKey]!['totalBeforeDiscount'] += lineTotalBeforeDiscount;
        reportData[categoryName]!['products'][productKey]!['discount'] +=
            discountAmount;

        // Ajout des détails de remise ligne
        reportData[categoryName]!['products'][productKey]!['discountDetails']
            .add({
          'type': 'Ligne',
          'amount': discountAmount,
          'isPercentage': line.isPercentage,
          'value': line.discount,
          'orderId': order.idOrder,
        });

        reportData[categoryName]!['total'] += lineTotal;
        reportData[categoryName]!['totalDiscount'] += discountAmount;
        reportData[categoryName]!['totalBeforeDiscount'] +=
            lineTotalBeforeDiscount;
      }
    }

    // Dans _getSalesReportByCategory, ligne ~150
    return reportData.entries.map((entry) {
      return <String, dynamic>{
        'category': entry.key,
        'total': entry.value['total'],
        'totalDiscount': entry.value['totalDiscount'],
        'globalDiscount': entry.value['globalDiscount'],
        'totalBeforeDiscount': entry.value['totalBeforeDiscount'],
        'totalAfterDiscount': entry.value['totalBeforeDiscount'] -
            entry.value['totalDiscount'] -
            entry.value['globalDiscount'],
        'discountDetails': entry.value['discountDetails'],
        'products': (entry.value['products'] as Map<String, dynamic>)
            .entries
            .map((product) {
          return <String, dynamic>{
            'name': product.key,
            'quantity': product.value['quantity'],
            'total': product.value['total'],
            'totalBeforeDiscount': product.value['totalBeforeDiscount'],
            'totalAfterDiscount': product.value['totalBeforeDiscount'] -
                product.value[
                    'discount'], // Correction ici : remise spécifique au produit
            'discount': product.value['discount'],
            'isPercentage': product.value['isPercentage'],
            'variant': product.value['variant'],
            'unitPrice': product.value['unitPrice'],
            'discountDetails': product.value['discountDetails'],
          };
        }).toList(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getSalesReportByUser(int userId) async {
    final db = SqlDb();
    final orders = await db.getOrders();

    // Filter orders by user and date range
    final filteredOrders = orders.where((order) {
      if (order.userId != userId) return false;
      final orderDate = DateTime.parse(order.date).toLocal();
      return _isDateInRange(orderDate, _selectedStartDate!, _selectedEndDate!);
    }).toList();

    final Map<String, Map<String, dynamic>> reportData = {};

    for (final order in filteredOrders) {
      for (final line in order.orderLines) {
        final product = await db.getProductById(line.productId ?? 0);
        if (product == null) continue;

        final category = await db.getCategoryNameById(product.categoryId);
        final categoryName = category;

        if (!reportData.containsKey(categoryName)) {
          reportData[categoryName] = {
            'total': 0.0,
            'totalDiscount': 0.0,
            'totalBeforeDiscount': 0.0,
            'globalDiscount': 0.0,
            'products': <String, Map<String, dynamic>>{},
            'discountDetails':
                [], // Pour stocker les détails des remises globales
          };
        }

        // Ajouter la remise globale si elle existe
        if (order.globalDiscount > 0) {
          double globalDiscountAmount = order.isPercentageDiscount
              ? (line.finalPrice * line.quantity) * (order.globalDiscount / 100)
              : (order.globalDiscount *
                  (line.finalPrice * line.quantity) /
                  order.total);

          reportData[categoryName]!['globalDiscount'] += globalDiscountAmount;
          reportData[categoryName]!['discountDetails'].add({
            'type': 'Globale',
            'amount': globalDiscountAmount,
            'isPercentage': order.isPercentageDiscount,
            'value': order.globalDiscount,
            'orderId': order.idOrder,
          });
        }

        // Get variant details if available
        Variant? variant;
        if (line.variantId != null) {
          variant = await db.getVariantById(line.variantId!);
        }

        final unitPrice = variant?.finalPrice ??
            line.prixUnitaire; // Ajout d'une valeur par défaut
        final lineTotalBeforeDiscount = unitPrice * line.quantity;

        double discountAmount = 0;
        if (line.isPercentage) {
          discountAmount = lineTotalBeforeDiscount * (line.discount / 100);
        } else {
          discountAmount = line.discount * line.quantity;
        }

        final lineTotal = lineTotalBeforeDiscount - discountAmount;
        final variantName =
            variant?.combinationName ?? line.variantName ?? 'Standard';
        final productKey = '${product.designation} ($variantName)';

        if (!reportData[categoryName]!['products'].containsKey(productKey)) {
          reportData[categoryName]!['products'][productKey] = {
            'quantity': 0,
            'total': 0.0,
            'totalBeforeDiscount': 0.0,
            'discount': 0.0,
            'isPercentage': line.isPercentage,
            'variant':
                variant?.combinationName ?? line.variantName ?? 'Standard',
            'unitPrice': unitPrice,
            'discountDetails': [], // Pour stocker les détails des remises ligne
          };
        }

        // Mise à jour des totaux
        reportData[categoryName]!['products'][productKey]!['quantity'] +=
            line.quantity;
        reportData[categoryName]!['products'][productKey]!['total'] +=
            lineTotal;
        reportData[categoryName]!['products']
            [productKey]!['totalBeforeDiscount'] += lineTotalBeforeDiscount;
        reportData[categoryName]!['products'][productKey]!['discount'] +=
            discountAmount;

        // Ajout des détails de remise ligne
        reportData[categoryName]!['products'][productKey]!['discountDetails']
            .add({
          'type': 'Ligne',
          'amount': discountAmount,
          'isPercentage': line.isPercentage,
          'value': line.discount,
          'orderId': order.idOrder,
        });

        reportData[categoryName]!['total'] += lineTotal;
        reportData[categoryName]!['totalDiscount'] += discountAmount;
        reportData[categoryName]!['totalBeforeDiscount'] +=
            lineTotalBeforeDiscount;
      }
    }

    return reportData.entries.map((entry) {
      return <String, dynamic>{
        'category': entry.key,
        'total': entry.value['total'],
        'totalDiscount': entry.value['totalDiscount'],
        'totalBeforeDiscount': entry.value['totalBeforeDiscount'],
        'totalAfterDiscount': entry.value['totalBeforeDiscount'] -
            entry.value['totalDiscount'] -
            entry.value['globalDiscount'],
        'globalDiscount': entry.value['globalDiscount'] ?? 0,
        'discountDetails': entry.value['discountDetails'] ?? [],
        'products': (entry.value['products'] as Map<String, dynamic>)
            .entries
            .map((product) {
          return <String, dynamic>{
            'name': product.key.split(' (')[0],
            'quantity': product.value['quantity'],
            'total': product.value['total'],
            'totalBeforeDiscount': product.value['totalBeforeDiscount'],
            'totalAfterDiscount': product.value['totalBeforeDiscount'] -
                product.value['discount'], // Remise spécifique au produit
            'discount': product.value['discount'],
            'isPercentage': product.value['isPercentage'],
            'variant': product.value['variant'],
            'unitPrice': product.value['unitPrice'],
            'discountDetails': product.value['discountDetails'] ?? [],
          };
        }).toList(),
      };
    }).toList();
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    // Normalize dates by removing time components
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);

    print(
        'Checking date: $normalizedDate between $normalizedStart and $normalizedEnd');

    return normalizedDate.isAtSameMomentAs(normalizedStart) ||
        normalizedDate.isAtSameMomentAs(normalizedEnd) ||
        (normalizedDate.isAfter(normalizedStart) &&
            normalizedDate.isBefore(normalizedEnd));
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _selectedStartDate ?? DateTime.now()
          : _selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
          // Si la date de fin est antérieure à la nouvelle date de début, on la réinitialise
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
            _selectedEndDate = null;
          }
        } else {
          // On ne permet pas de sélectionner une date de fin sans date de début
          if (_selectedStartDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Veuillez d\'abord sélectionner une date de début'),
                backgroundColor: warmRed,
              ),
            );
            return;
          }
          _selectedEndDate = picked;
        }
      });
    }
  }

  Future<void> _downloadPdfReport() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(70 * PdfPageFormat.mm, double.infinity,
            marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Rapport des ventes',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Période: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)}'
                      ' - ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    if (_groupByUser && _selectedUser != null)
                      pw.Text(
                        'Utilisateur: ${_selectedUser!.username}',
                        style: pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 5),

              // Sales details
              ..._salesData.map((category) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (category['category'] ?? 'Non catégorisé')
                            .toString()
                            .toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),

                      // Products
                      ...(category['products'] as List<dynamic>)
                          .map((product) => pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Container(
                                        width: 80,
                                        child: pw.Text(
                                          '${product['name']}${product['variant'] != null ? '\n${_formatVariant(product['variant'])}' : ''}',
                                          style:
                                              const pw.TextStyle(fontSize: 8),
                                          maxLines: 2,
                                          overflow: pw.TextOverflow.clip,
                                        ),
                                      ),
                                      pw.Text(
                                        '${product['quantity']}x ${product['unitPrice'].toStringAsFixed(2)} DT',
                                        style: const pw.TextStyle(fontSize: 8),
                                      ),
                                    ],
                                  ),
                                  if ((product['discount'] as num) > 0) ...[
                                    pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Avant remise:',
                                            style: const pw.TextStyle(
                                                fontSize: 7)),
                                        pw.Text(
                                          '${product['totalBeforeDiscount'].toStringAsFixed(2)} DT',
                                          style:
                                              const pw.TextStyle(fontSize: 7),
                                        ),
                                      ],
                                    ),
                                    pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Après remise:',
                                            style: const pw.TextStyle(
                                                fontSize: 7)),
                                        pw.Text(
                                          '${product['totalAfterDiscount'].toStringAsFixed(2)} DT',
                                          style:
                                              const pw.TextStyle(fontSize: 7),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if ((product['discount'] as num) > 0)
                                    pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          'Remises:',
                                          style: pw.TextStyle(
                                            fontSize: 7,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        ...(product['discountDetails'] as List)
                                            .map((discount) => pw.Padding(
                                                  padding:
                                                      const pw.EdgeInsets.only(
                                                          left: 5),
                                                  child: pw.Text(
                                                    '- ${discount['type']}: ${discount['value']}${discount['isPercentage'] ? '%' : 'DT'} (${discount['amount'].toStringAsFixed(2)} DT)',
                                                    style: const pw.TextStyle(
                                                        fontSize: 6),
                                                  ),
                                                )),
                                      ],
                                    ),
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        'Total:',
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.Text(
                                        '${product['totalAfterDiscount'].toStringAsFixed(2)} DT',
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  pw.Divider(thickness: 0.5),
                                ],
                              )),

                      if ((category['globalDiscount'] as num) > 0)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Remises globales:',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            ...(category['discountDetails'] as List)
                                .map((discount) => pw.Padding(
                                      padding:
                                          const pw.EdgeInsets.only(left: 5),
                                      child: pw.Text(
                                        '- ${discount['type']}: ${discount['value']}${discount['isPercentage'] ? '%' : 'DT'} (${discount['amount'].toStringAsFixed(2)} DT)',
                                        style: const pw.TextStyle(fontSize: 7),
                                      ),
                                    )),
                          ],
                        ),

                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total catégorie:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${category['totalAfterDiscount'].toStringAsFixed(2)} DT',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 0.5),
                    ],
                  )),

              // Grand total
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL GÉNÉRAL:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_salesData.fold(0.0, (sum, category) => sum + (category['totalAfterDiscount'] as num)).toStringAsFixed(2)} DT',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Footer
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(now)}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Get downloads directory
    final directory = await getDownloadsDirectory();
    final filePath =
        '${directory!.path}/rapport_ventes_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';

    // Save the PDF file
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Show download confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF téléchargé: $filePath'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatVariant(String variant) {
    // Format variant to show "Color: (Yellow)" instead of full variant name
    if (variant.contains(':')) {
      final parts = variant.split(':');
      if (parts.length > 1) {
        final valuePart = parts[1].trim();
        // Get first word of the value
        final firstWord = valuePart.split(' ').first;
        return '${parts[0]}: ($firstWord)';
      }
    }
    // If no colon or formatting fails, return original variant
    return variant;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rapports des ventes', style: TextStyle(color: white)),
        backgroundColor: deepBlue,
        iconTheme: IconThemeData(color: white),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Aide'),
                  content: Text(
                      'Générez des rapports de vente par période et par utilisateur.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK', style: TextStyle(color: deepBlue)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightGray.withOpacity(0.1), white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            // Sélecteur de période
            Card(
              elevation: 4,
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
                            color: darkBlue,
                          ),
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
                              _selectedStartDate != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_selectedStartDate!)
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
                              _selectedEndDate != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_selectedEndDate!)
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
                    if (_selectedStartDate != null || _selectedEndDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
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
                              '${_selectedStartDate != null ? DateFormat('dd/MM/yyyy').format(_selectedStartDate!) : '--'} '
                              'à ${_selectedEndDate != null ? DateFormat('dd/MM/yyyy').format(_selectedEndDate!) : '--'}',
                              style: TextStyle(
                                color: darkBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Options de rapport
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Grouper par utilisateur',
                          style: TextStyle(color: darkBlue)),
                      subtitle: Text(_groupByUser
                          ? 'Rapport filtré par utilisateur'
                          : 'Rapport global'),
                      value: _groupByUser,
                      onChanged: (value) =>
                          setState(() => _groupByUser = value),
                      activeColor: tealGreen,
                      secondary: Icon(Icons.group,
                          color: _groupByUser ? tealGreen : lightGray),
                    ),
                    if (_groupByUser) ...[
                      DropdownButtonFormField<User>(
                        value: _selectedUser,
                        onChanged: (user) {
                          setState(() {
                            _selectedUser = user;
                            print(
                                'Selected user: ${user?.username} (ID: ${user?.id})');
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Sélectionner un utilisateur',
                          border: OutlineInputBorder(),
                        ),
                        items: _users.map((user) {
                          return DropdownMenuItem<User>(
                            value: user,
                            child: Text(user.username),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Bouton pour générer le rapport
            SizedBox(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepBlue,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: white),
                          SizedBox(width: 10),
                          Text('Génération...', style: TextStyle(color: white)),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, color: white, size: 20),
                          SizedBox(width: 8),
                          Text('Générer le rapport',
                              style: TextStyle(color: white)),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 8),

            // Bouton de téléchargement PDF (visible seulement après génération)
            if (_showDownloadButton)
              SizedBox(
                child: ElevatedButton(
                  onPressed: _downloadPdfReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealGreen,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf, color: white, size: 20),
                      SizedBox(width: 8),
                      Text('Télécharger PDF', style: TextStyle(color: white)),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 16),

            // Résultats
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: deepBlue))
                  : _salesData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.insert_chart_outlined,
                                  size: 60, color: lightGray),
                              SizedBox(height: 16),
                              Text('Aucune donnée à afficher',
                                  style:
                                      TextStyle(color: darkBlue, fontSize: 18)),
                              Text(
                                  'Sélectionnez une période et générez un rapport',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _salesData.length,
                          itemBuilder: (context, index) {
                            final categoryData = _salesData[index];
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ExpansionTile(
                                leading: Icon(Icons.category, color: tealGreen),
                                title: Text(
                                  categoryData['category'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                                // Dans build, ligne ~540, dans ExpansionTile
                                // Dans build, dans ExpansionTile (~ligne 540)
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Afficher seulement s'il y a des remises
                                    if ((categoryData['totalDiscount'] as num) +
                                            (categoryData['globalDiscount']
                                                as num) >
                                        0) ...[
                                      Text(
                                        'Total avant remise: ${categoryData['totalBeforeDiscount'].toStringAsFixed(2)} DT',
                                        style: TextStyle(
                                          color: deepBlue,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Remises: ${(categoryData['totalDiscount'] + categoryData['globalDiscount']).toStringAsFixed(2)} DT',
                                        style: TextStyle(
                                          color: warmRed,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Total après remise: ${categoryData['totalAfterDiscount'].toStringAsFixed(2)} DT',
                                        style: TextStyle(
                                          color: tealGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    // Toujours afficher le total si aucune remise
                                    if ((categoryData['totalDiscount'] as num) +
                                            (categoryData['globalDiscount']
                                                as num) ==
                                        0)
                                      Text(
                                        'Total: ${categoryData['totalAfterDiscount'].toStringAsFixed(2)} DT',
                                        style: TextStyle(
                                          color: tealGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                children: [
                                  ...(categoryData['products'] as List)
                                      .map((product) {
                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.shopping_bag,
                                              color:
                                                  softOrange.withOpacity(0.7)),
                                          title: Text(
                                            '${product['name']} (${product['variant']})',
                                            style: TextStyle(color: darkBlue),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Quantité: ${product['quantity']}'),
                                              Text(
                                                'Prix unitaire: ${product['unitPrice'].toStringAsFixed(2)} DT',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              // Afficher seulement s'il y a une remise
                                              if ((product['discount'] as num) >
                                                  0) ...[
                                                Text(
                                                  'Total avant remise: ${product['totalBeforeDiscount'].toStringAsFixed(2)} DT',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                                Text(
                                                  'Total après remise: ${product['totalAfterDiscount'].toStringAsFixed(2)} DT',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                              ],
                                              // Toujours afficher le total si aucune remise
                                              if ((product['discount']
                                                      as num) ==
                                                  0)
                                                Text(
                                                  'Total: ${product['totalAfterDiscount'].toStringAsFixed(2)} DT',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Affichage des détails des remises pour ce produit
                                        if ((product['discount'] as num) > 0)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Détails des remises:',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: darkBlue,
                                                  ),
                                                ),
                                                ...(product['discountDetails']
                                                        as List)
                                                    .map((discount) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8.0),
                                                    child: Text(
                                                      '- ${discount['type']}: ${discount['value']}${discount['isPercentage'] ? '%' : 'DT'} (${discount['amount'].toStringAsFixed(2)} DT)',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: warmRed,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                        Divider(height: 1),
                                      ],
                                    );
                                  }).toList(),
                                  // Affichage des remises globales pour cette catégorie
                                  if ((categoryData['globalDiscount'] as num) >
                                      0)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Remises globales appliquées:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: darkBlue,
                                            ),
                                          ),
                                          ...(categoryData['discountDetails']
                                                  as List)
                                              .map((discount) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: Text(
                                                '- ${discount['type']}: ${discount['value']}${discount['isPercentage'] ? '%' : 'DT'} (${discount['amount'].toStringAsFixed(2)} DT)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: warmRed,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
