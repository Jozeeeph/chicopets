import 'dart:io';
import 'package:caissechicopets/sqldb.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/product.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class Getorderlist {
  static void showListOrdersPopUp(BuildContext context) async {
    final SqlDb sqldb = SqlDb();
    List<Order> orders = await sqldb.getOrdersWithOrderLines(); // Récupération des commandes

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for clarity
          title: const Text(
            "Liste des Commandes",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
          ),
          content: orders.isEmpty
              ? const Text("Aucune commande disponible.", style: TextStyle(color: Color(0xFF000000))) // Deep Blue
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      Order order = orders[index];
                      return ExpansionTile(
                        title: Text(
                          "Commande #${order.idOrder} - ${formatDate(order.date)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000000)), // Deep Blue
                        ),
                        children: [
                          ...order.orderLines.map((orderLine) {
                            return FutureBuilder<Product?>(
                              future: sqldb.getProductByCode(orderLine.idProduct),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF26A9E0), // Sky Blue
                                      ));
                                }

                                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                                  return const ListTile(
                                      title: Text("Produit introuvable", style: TextStyle(color: Color(0xFFE53935)))); // Warm Red
                                }

                                Product product = snapshot.data!;
                                return ListTile(
                                  title: Text(product.designation, style: TextStyle(color: Color(0xFF000000))), // Deep Blue
                                  subtitle: Text("Quantité: ${orderLine.quantite}", style: TextStyle(color: Color(0xFF0056A6))), // Teal Green
                                  trailing: Text(
                                    "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, color: Color(0xFF000000)), // Deep Blue
                                  ),
                                );
                              },
                            );
                          }).toList(),

                          // 🔹 Bouton "Imprimer Ticket"
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showOrderTicketPopup(context, order);
                              },
                              icon: Icon(Icons.print, color: Colors.white),
                              label: Text("Imprimer Ticket", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF26A9E0), // Deep Blue
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer", style: TextStyle(color: Color(0xFF000000))), // Deep Blue
            ),
          ],
        );
      },
    );
  }

  static void _showOrderTicketPopup(BuildContext context, Order order) {
    final SqlDb sqldb = SqlDb();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for clarity
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Center(
            child: Text(
              "🧾 Ticket de Commande",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Courier',
                  color: Color(0xFF000000)), // Deep Blue
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(thickness: 1, color: Color(0xFFE0E0E0)), // Light Gray

                // Numéro de commande et date
                Text(
                  "Commande #${order.idOrder}\nDate: ${formatDate(order.date)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                      color: Color(0xFF000000)), // Deep Blue
                ),

                Divider(thickness: 1, color: Color(0xFFE0E0E0)), // Light Gray

                // Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Qt",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              color: Color(0xFF000000)), // Deep Blue
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Article",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              color: Color(0xFF000000)), // Deep Blue
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Prix U",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              color: Color(0xFF000000)), // Deep Blue
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Montant",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              color: Color(0xFF000000)), // Deep Blue
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(thickness: 1, color: Color(0xFFE0E0E0)), // Light Gray

                // Liste des produits
                ...order.orderLines.map((orderLine) {
                  return FutureBuilder<Product?>(
                    future: sqldb.getProductByCode(orderLine.idProduct),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF26A9E0), // Sky Blue
                            ));
                      }

                      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                        return const ListTile(
                            title: Text("Produit introuvable", style: TextStyle(color: Color(0xFFE53935)))); // Warm Red
                      }

                      Product product = snapshot.data!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                "x${orderLine.quantite}",
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Courier', color: Color(0xFF000000)), // Deep Blue
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                product.designation,
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Courier', color: Color(0xFF000000)), // Deep Blue
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Courier', color: Color(0xFF000000)), // Deep Blue
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                    color: Color(0xFF000000)), // Deep Blue
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),

                Divider(thickness: 1, color: Color(0xFFE0E0E0)), // Light Gray

                // Total et Mode de paiement
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total:",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          color: Color(0xFF000000)), // Deep Blue
                    ),
                    Text(
                      "${order.total.toStringAsFixed(2)} DT",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          color: Color(0xFF000000)), // Deep Blue
                    ),
                  ],
                ),

                SizedBox(height: 10),

                Text(
                  "Mode de Paiement: ${order.modePaiement}",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                      color: Color(0xFF000000)), // Deep Blue
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Fermer", style: TextStyle(color: Color(0xFF000000))), // Deep Blue
            ),
            TextButton(
              onPressed: () {
                generateAndSavePDF(context, order);
              },
              child: Text("Imprimer", style: TextStyle(color: Color(0xFF000000))), // Deep Blue
            ),
          ],
        );
      },
    );
  }

  static String formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
  }

  //Convert to PDF
  static Future<void> generateAndSavePDF(BuildContext context, Order order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text("Ticket de Commande",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 18)),
            ),
            pw.Divider(),

            // Numéro de commande et date
            pw.Text("Commande #${order.idOrder}"),
            pw.Text("Date: ${formatDate(order.date)}"),
            pw.Divider(),

            // Header de la liste des articles
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Qt",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Article",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Prix U",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Montant",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(),

            // Liste des produits
            ...order.orderLines.map((orderLine) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("x${orderLine.quantite}"),
                  pw.Text(orderLine.idProduct),
                  pw.Text("${orderLine.prixUnitaire.toStringAsFixed(2)} DT"),
                  pw.Text(
                      "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT"),
                ],
              );
            }).toList(),

            pw.Divider(),

            // Total et mode de paiement
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total:",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("${order.total.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text("Mode de Paiement: ${order.modePaiement}"),
          ],
        ),
      ),
    );

    // Obtenir le répertoire de téléchargement
    final directory = await getDownloadsDirectory();
    final filePath = "${directory!.path}/ticket_commande_${order.idOrder}.pdf";

    // Sauvegarde du fichier
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Afficher une notification de succès
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("PDF enregistré dans: $filePath"),
        backgroundColor: Color(0xFF009688), // Teal Green
      ),
    );
  }
}