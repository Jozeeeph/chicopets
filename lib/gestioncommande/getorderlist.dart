import 'dart:io';
import 'package:caissechicopets/sqldb.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/product.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';


class Getorderlist {
  static Future<void> cancelOrder(
      BuildContext context, Order order, Function() onOrderCanceled) async {
    TextEditingController _confirmController = TextEditingController();
    bool isConfirmed = false;
    final SqlDb sqlDb = SqlDb();

    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 10),
                  Text(
                    'Confirmation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tapez "Annuler" pour confirmer l\'annulation de cette commande.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _confirmController,
                    onChanged: (value) {
                      setState(() {
                        isConfirmed = (value.toLowerCase().trim() == "annuler");
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Annuler',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Non'),
                ),
                ElevatedButton(
                  onPressed: isConfirmed
                      ? () async {
                          Navigator.of(context).pop(true);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isConfirmed ? Colors.red : Colors.grey[400],
                  ),
                  child: const Text('Annuler la commande'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmCancel == true) {
      await sqlDb.updateOrderStatus(order.idOrder!, 'annulée');

      // Restocker les produits de la commande annulée
      final dbClient = await sqlDb.db;
      final List<Map<String, dynamic>> orderLinesData = await dbClient.query(
        'order_items',
        where: 'id_order = ?',
        whereArgs: [order.idOrder],
      );

      for (var line in orderLinesData) {
        String productCode = line['product_code'].toString();
        int canceledQuantity = line['quantity'] as int;

        final List<Map<String, dynamic>> productData = await dbClient.query(
          'products',
          where: 'code = ?',
          whereArgs: [productCode],
        );

        if (productData.isNotEmpty) {
          int currentStock = productData.first['stock'] as int;
          int newStock = currentStock + canceledQuantity;

          await dbClient.update(
            'products',
            {'stock': newStock},
            where: 'code = ?',
            whereArgs: [productCode],
          );
        }
      }

      // Appeler le callback pour mettre à jour l'interface utilisateur
      onOrderCanceled();
    }
  }

  static void showListOrdersPopUp(BuildContext context) async {
    final SqlDb sqldb = SqlDb();
    List<Order> orders =
        await sqldb.getOrdersWithOrderLines(); // Récupération des commandes

    // Filtrer les commandes non annulées
    orders = orders.where((order) => order.status != 'annulée').toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for clarity
          title: const Text(
            "Liste des Commandes",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0056A6)), // Deep Blue
          ),
          content: orders.isEmpty
              ? const Text("Aucune commande disponible.",
                  style: TextStyle(color: Color(0xFF000000))) // Deep Blue
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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000)), // Deep Blue
                        ),
                        children: [
                          ...order.orderLines.map((orderLine) {
                            return FutureBuilder<Product?>(
                              future:
                                  sqldb.getProductByCode(orderLine.idProduct),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data == null) {
                                  return ListTile(
                                    title: Text(
                                        "Produit supprimé (${orderLine.idProduct})",
                                        style: TextStyle(color: Colors.red)),
                                    subtitle:
                                        Text("Quantité: ${orderLine.quantite}"),
                                    trailing: Text(
                                        "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT"),
                                  );
                                }

                                Product product = snapshot.data!;
                                return ListTile(
                                  title: Text(product.designation),
                                  subtitle:
                                      Text("Quantité: ${orderLine.quantite}"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT"),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () async {
                                          // Show confirmation dialog
                                          bool? confirmDelete =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text(
                                                    "Confirmer la suppression"),
                                                content: const Text(
                                                    "Êtes-vous sûr de vouloir supprimer ce produit de la commande ? La quantité de ce produit sera restockée"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(false),
                                                    child: const Text("Non"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(true),
                                                    child: const Text("Oui"),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          // If user confirms, delete the order line
                                          if (confirmDelete == true) {
                                            // Annuler la ligne de commande
                                            await sqldb.cancelOrderLine(
                                                order.idOrder!,
                                                orderLine.idProduct);

                                            // Restocker le produit
                                            await sqldb.updateProductStock(
                                                orderLine.idProduct,
                                                orderLine.quantite);

                                            // Check if the order has any remaining order lines
                                            final dbClient = await sqldb
                                                .db; // Access the database instance
                                            final List<Map<String, dynamic>>
                                                remainingOrderLines =
                                                await dbClient.query(
                                              'order_items',
                                              where: 'id_order = ?',
                                              whereArgs: [order.idOrder],
                                            );
                                            // If no order lines remain, delete the order
                                            if (remainingOrderLines.isEmpty) {
                                              await sqldb
                                                  .deleteOrder(order.idOrder!);
                                            }

                                            // Rafraîchir la liste des commandes
                                            orders = await sqldb
                                                .getOrdersWithOrderLines();
                                            Navigator.pop(
                                                context); // Fermer la boîte de dialogue
                                            showListOrdersPopUp(
                                                context); // Rouvrir la boîte de dialogue avec les données mises à jour
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),

                          // 🔹 Boutons alignés horizontalement
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .spaceEvenly, // Align buttons evenly
                              children: [
                                // Bouton "Imprimer Ticket"
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showOrderTicketPopup(context, order);
                                  },
                                  icon: Icon(Icons.print, color: Colors.white),
                                  label: Text("Imprimer Ticket",
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Color(0xFF26A9E0), // Deep Blue
                                    foregroundColor: Colors.white,
                                  ),
                                ),

                                // Bouton "Annuler Commande"
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    // Annuler la commande
                                    await cancelOrder(context, order, () {
                                      // Fermer la boîte de dialogue et mettre à jour la liste
                                      Navigator.pop(context);
                                      showListOrdersPopUp(context);
                                    });
                                  },
                                  icon: Icon(Icons.cancel, color: Colors.white),
                                  label: Text("Annuler Commande",
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors
                                        .red, // Red color for cancellation
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
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
              child: const Text(
                "Fermer",
                style: TextStyle(color: Color(0xFF000000)), // Deep Blue
              ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Center(
            child: Text(
              "🧾 Ticket de Commande",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        return const ListTile(
                            title: Text("Produit introuvable",
                                style: TextStyle(
                                    color: Color(0xFFE53935)))); // Warm Red
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
                                    fontSize: 16,
                                    color: Color(0xFF000000)), // Deep Blue
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                product.designation,
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF000000)), // Deep Blue
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF000000)), // Deep Blue
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
                          color: Color(0xFF000000)), // Deep Blue
                    ),
                    Text(
                      "${order.total.toStringAsFixed(2)} DT",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
              child: Text("Fermer",
                  style: TextStyle(color: Color(0xFF000000))), // Deep Blue
            ),
            TextButton(
              onPressed: () {
                generateAndSavePDF(context, order);
              },
              child: Text("Imprimer",
                  style: TextStyle(color: Color(0xFF000000))), // Deep Blue
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
  static Future<void> generateAndSavePDF(
      BuildContext context, Order order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text("Ticket de Commande",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ),
            pw.Divider(),

            // Numéro de commande et date
            pw.Text(" Commande #${order.idOrder}",
                style: pw.TextStyle(fontSize: 10)),
            pw.Text(" Date: ${formatDate(order.date)}",
                style: pw.TextStyle(fontSize: 10)),
            pw.Divider(),

            // Liste des articles avec un format compact
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(" Qt",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text("Article",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text("PU",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text("Total   ",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ],
            ),
            pw.Divider(),

            // Liste des produits
            ...order.orderLines.map((orderLine) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(" x${orderLine.quantite}                ",
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Text(orderLine.idProduct,
                        style: pw.TextStyle(fontSize: 10),
                        overflow: pw.TextOverflow.clip),
                  ),
                  pw.Text("${orderLine.prixUnitaire.toStringAsFixed(2)}  DT  ",
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text(
                      "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)}  DT ",
                      style: pw.TextStyle(fontSize: 10)),
                ],
              );
            }).toList(),

            pw.Divider(),

            // Total et mode de paiement
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(" Total:",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text("${order.total.toStringAsFixed(2)} DT ",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(" Paiement: ${order.modePaiement}",
                style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),

            // Message de remerciement
            pw.Center(
              child: pw.Text("Merci de votre visite !",
                  style: pw.TextStyle(
                      fontSize: 10, fontStyle: pw.FontStyle.italic)),
            ),
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
