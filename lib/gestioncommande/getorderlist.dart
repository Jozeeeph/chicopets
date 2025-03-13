import 'dart:io';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/product.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class Getorderlist {
  static Future<void> cancelOrder(
      BuildContext context, Order order, Function() onOrderCanceled) async {
    TextEditingController confirmController = TextEditingController();
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
                    controller: confirmController,
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

  static Future<void> cancelOrderLine(
      BuildContext context, Order order, OrderLine orderLine) async {
    final SqlDb sqldb = SqlDb();

    // Annuler la ligne de commande
    await sqldb.cancelOrderLine(order.idOrder!, orderLine.idProduct);

    // Restocker le produit
    await sqldb.updateProductStock(orderLine.idProduct, orderLine.quantite);

    // Recalculer le total de la commande
    final dbClient = await sqldb.db;
    final List<Map<String, dynamic>> remainingOrderLines = await dbClient.query(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    double newTotal = 0.0;
    for (var line in remainingOrderLines) {
      double prixUnitaire = line['prix_unitaire'] as double;
      int quantite = line['quantity'] as int;
      newTotal += prixUnitaire * quantite;
    }

    // Mettre à jour le total de la commande dans la base de données
    await dbClient.update(
      'orders',
      {'total': newTotal},
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    // Mettre à jour l'objet Order localement
    order.total = newTotal;
    order.orderLines
        .removeWhere((line) => line.idProduct == orderLine.idProduct);

    // Rafraîchir la liste des commandes
    Navigator.pop(context); // Fermer la boîte de dialogue
    showListOrdersPopUp(
        context); // Rouvrir la boîte de dialogue avec les données mises à jour
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
                      bool isCancelled = order.status == 'annulée';
                      bool isSemiPaid = order.remainingAmount >
                          0; // Check if the order is semi-paid

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: isCancelled
                            ? Colors.red.shade100
                            : isSemiPaid
                                ? Colors.orange
                                    .shade100 // Orange background for semi-paid orders
                                : order.status == "payée"
                                    ? Colors.green
                                        .shade100 // Green background for fully paid orders
                                    : Colors.white,
                        child: ExpansionTile(
                          title: Text(
                            'Commande #${order.idOrder} - ${formatDate(order.date)}',
                            style: TextStyle(
                              color: isCancelled
                                  ? Colors.red
                                  : order.remainingAmount ==
                                          0 // Check if remaining amount is 0
                                      ? Colors
                                          .green // Green text for fully paid orders
                                      : isSemiPaid
                                          ? Colors
                                              .orange // Orange text for semi-paid orders
                                          : const Color(
                                              0xFF0056A6), // Default color
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            isCancelled
                                ? 'Commande annulée'
                                : order.remainingAmount ==
                                        0 // Check if remaining amount is 0
                                    ? 'Payée - Total: ${order.total.toStringAsFixed(2)} DT' // Fully paid
                                    : isSemiPaid
                                        ? 'Semi-payée - Reste: ${order.remainingAmount.toStringAsFixed(2)} DT' // Semi-paid
                                        : 'Non payée - Total: ${order.total.toStringAsFixed(2)} DT', // Not paid
                            style: TextStyle(
                              color: isCancelled
                                  ? Colors.red
                                  : order.remainingAmount ==
                                          0 // Check if remaining amount is 0
                                      ? Colors
                                          .green // Green text for fully paid orders
                                      : isSemiPaid
                                          ? Colors
                                              .orange // Orange text for semi-paid orders
                                          : const Color(0xFF009688), // Default color
                              fontSize: 14,
                            ),
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
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      subtitle: Text(
                                          "Quantité: ${orderLine.quantite}"),
                                      trailing: Text(
                                        "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT",
                                      ),
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
                                          orderLine.isPercentage
                                              ? "${(orderLine.prixUnitaire * orderLine.quantite * (1 - orderLine.discount / 100)).toStringAsFixed(2)} DT" // Percentage discount
                                              : "${(orderLine.prixUnitaire * orderLine.quantite - orderLine.discount).toStringAsFixed(2)} DT", // Fixed value discount
                                        ),
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
                                              await cancelOrderLine(
                                                  context, order, orderLine);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),

                            // 🔹 Boutons alignés horizontalement
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceEvenly, // Align buttons evenly
                                children: [
                                  // Bouton "Imprimer Ticket"
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showOrderTicketPopup(context, order);
                                    },
                                    icon:
                                        Icon(Icons.print, color: Colors.white),
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
                                    icon:
                                        Icon(Icons.cancel, color: Colors.white),
                                    label: Text("Annuler Commande",
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors
                                          .red, // Red color for cancellation
                                      foregroundColor: Colors.white,
                                    ),
                                  ),

                                  // Bouton "Mettre à jour" pour les commandes semi-payées
                                  if (isSemiPaid)
                                    IconButton(
                                      icon: Icon(Icons.update,
                                          color: Colors.blue),
                                      onPressed: () {
                                        // Trigger an update action for semi-paid orders
                                        _updateSemiPaidOrder(context, order);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  static void _updateSemiPaidOrder(BuildContext context, Order order) {
    // Calculate the remaining amount
    double remainingAmount = order.remainingAmount;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController amountController = TextEditingController();

        return AlertDialog(
          title: const Text('Ajouter un montant à la commande'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Montant restant: ${remainingAmount.toStringAsFixed(2)} DT',
                style: TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Montant à ajouter',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close the dialog
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                double amountToAdd =
                    double.tryParse(amountController.text) ?? 0;

                if (amountToAdd > 0) {
                  // Call your method to update the order with the added amount
                  _addAmountToOrder(context, order, amountToAdd);
                  Navigator.pop(context); // Close the dialog after action
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez entrer un montant valide'),
                    ),
                  );
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  static void _addAmountToOrder(
      BuildContext context, Order order, double amount) async {
    // Update the order with the additional amount
    final SqlDb sqldb = SqlDb();
    order.remainingAmount -= amount;

    // Check if the remaining amount is zero or less to mark the order as paid
    if (order.remainingAmount <= 0) {
      order.status = 'payée'; // Mark order as fully paid
    }

    // Update the order in the database
    await sqldb.updateOrderInDatabase(order);

    // Show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Commande #${order.idOrder} mise à jour avec ${amount.toStringAsFixed(2)} DT',
        ),
      ),
    );

    // Auto-reload orders after updating
    Navigator.pop(context); // Close the dialog
    showListOrdersPopUp(context); // Reload the orders
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
                      double discountedPrice = orderLine.prixUnitaire *
                          (1 - orderLine.discount / 100);
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
                                "${(discountedPrice * orderLine.quantite).toStringAsFixed(2)} DT",
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
                }),

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
              double discountedPrice =
                  orderLine.prixUnitaire * (1 - orderLine.discount / 100);
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("x${orderLine.quantite}"),
                  pw.Text(orderLine.idProduct),
                  pw.Text("${discountedPrice.toStringAsFixed(2)} DT"),
                  pw.Text(
                      "${(discountedPrice * orderLine.quantite).toStringAsFixed(2)} DT"),
                ],
              );
            }),

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
