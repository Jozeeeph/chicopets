import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class RapportPdf {
  final Map<String, Map<String, dynamic>> salesData;
  final DateTimeRange? dateRange;
  final double totalSales;

  RapportPdf({
    required this.salesData,
    required this.totalSales,
    this.dateRange,
  });

  Future<void> generateAndPrintPdf(BuildContext context) async {
    try {
      final doc = await _generatePdfDocument();
      
      // Option 1: Direct printing
      await Printing.layoutPdf(
        onLayout: (format) => doc.save(),
        name: 'Rapport_Ventes_Chicopets',
      );

      // Option 2: Save to downloads folder
      await _savePdfToDownloads(doc, context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF: $e')),
      );
    }
  }

  Future<pw.Document> _generatePdfDocument() async {
    final doc = pw.Document();

    // Use a receipt-like format (80mm width)
    const pageWidth = 80 * PdfPageFormat.mm;
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, double.infinity,
            marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildDateRange(),
            _buildSalesData(),
            _buildTotalSection(),
            _buildFooter(),
          ],
        ),
      ),
    );

    return doc;
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'RAPPORT DES VENTES',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Chicopets - Caisse',
            style: pw.TextStyle(
              fontSize: 10,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1),
      ],
    );
  }

  pw.Widget _buildDateRange() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.SizedBox(width: 5),
              pw.Text(
                dateRange != null
                    ? 'Période: ${DateFormat('dd/MM/yyyy').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}'
                    : 'Toutes les ventes',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );
  }

  pw.Widget _buildSalesData() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...salesData.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildCategorySection(String category, Map<String, dynamic> categoryData) {
    final products = categoryData['products'] as Map<String, dynamic>;
    final categoryTotal = categoryData['total'] as double;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Category header
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                category.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${categoryTotal.toStringAsFixed(2)} DT',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Products list
        if (products.isNotEmpty) ...[
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text('Produit', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text('Qté', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text('Prix U.', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text('Total', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Product rows
              ...products.entries.map((entry) {
                final productData = entry.value as Map<String, dynamic>;
                final unitPrice = productData['total'] / productData['quantity'];
                final discount = productData.containsKey('discount') ? productData['discount'] : 0.0;
                final discountedPrice = unitPrice * (1 - discount / 100);

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(productData['quantity'].toString(), style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(
                        '${discountedPrice.toStringAsFixed(2)} DT${discount > 0 ? ' (-${discount.toStringAsFixed(0)}%)' : ''}',
                        style: const pw.TextStyle(fontSize: 7)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(
                        '${productData['total'].toStringAsFixed(2)} DT',
                        style: const pw.TextStyle(fontSize: 7)),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ] else ...[
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'Aucun produit vendu dans cette catégorie',
              style: pw.TextStyle(
                fontStyle: pw.FontStyle.italic,
                fontSize: 7,
              ),
            ),
          ),
        ],
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildTotalSection() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
      ),
      child: pw.Row(
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
            '${totalSales.toStringAsFixed(2)} DT',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Merci pour votre confiance!',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _savePdfToDownloads(pw.Document doc, BuildContext context) async {
    try {
      final directory = await getDownloadsDirectory();
      final fileName = 'Rapport_Ventes_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory!.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(await doc.save());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF enregistré dans: $filePath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}