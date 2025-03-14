import 'dart:io';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:caissechicopets/order.dart';
import 'package:pdf/pdf.dart'; // Import the PdfPageFormat class
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
     // Ajout de isValueDiscount
    

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
                      bool isValueDiscount = order.globalDiscount >0;
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
                                  : isSemiPaid
                                      ? Colors
                                          .orange // Orange text for semi-paid orders
                                      : order.status == "payée"
                                          ? Colors
                                              .green // Green text for fully paid orders
                                          : const Color(0xFF0056A6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            isCancelled
                                ? 'Commande annulée'
                                : isSemiPaid
                                    ? 'Semi-payée - Reste: ${order.remainingAmount.toStringAsFixed(2)} DT' // Display remaining amount
                                    : order.status == "payée"
                                        ? 'Payée - Total: ${order.total.toStringAsFixed(2)} DT'
                                        : 'Non payée - Total: ${order.total.toStringAsFixed(2)} DT',
                            style: TextStyle(
                                color: isCancelled
                                    ? Colors.red
                                    : isSemiPaid
                                        ? Colors
                                            .orange // Orange text for semi-paid orders
                                        : order.status == "payée"
                                            ? Colors
                                                .green // Green text for fully paid orders
                                            : const Color(0xFF009688),
                                fontSize: 14),
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
                                    return const ListTile(
                                        title: Text("Produit supprimé",
                                            style: TextStyle(
                                                color: Color(0xFFE53935))));
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
                                                fontSize: 16, color: Color(0xFF000000)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            product.designation,
                                            style: TextStyle(
                                                fontSize: 16, color: Color(0xFF000000)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                            style: TextStyle(
                                                fontSize: 16, color: Color(0xFF000000)),
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
                                                color: Color(0xFF000000)),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }).toList(),

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
                                      _showOrderTicketPopup(context, order,isValueDiscount);
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

  static void _showOrderTicketPopup(BuildContext context, Order order,bool isValueDiscount) {
    final SqlDb sqldb = SqlDb();
    bool isPercentageDiscount = !isValueDiscount; 


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Center(
            child: Text(
              "🧾 Ticket de Commande",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF000000)),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(thickness: 1, color: Color(0xFFE0E0E0)),

                // Numéro de commande et date
                Text(
                  "Commande #${order.idOrder}\nDate: ${formatDate(order.date)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000)),
                ),

                Divider(thickness: 1, color: Color(0xFFE0E0E0)),

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
                              color: Color(0xFF000000)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Article",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000)),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Prix U",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000)),
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
                              color: Color(0xFF000000)),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(thickness: 1, color: Color(0xFFE0E0E0)),

                // Liste des produits
                ...order.orderLines.map((orderLine) {
                  return FutureBuilder<Product?>(
                    future: sqldb.getProductByCode(orderLine.idProduct),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                          color: Color(0xFF26A9E0),
                        ));
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        return const ListTile(
                            title: Text("Produit introuvable",
                                style: TextStyle(color: Color(0xFFE53935))));
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
                                    fontSize: 16, color: Color(0xFF000000)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                product.designation,
                                style: TextStyle(
                                    fontSize: 16, color: Color(0xFF000000)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 16, color: Color(0xFF000000)),
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
                                    color: Color(0xFF000000)),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),

                Divider(thickness: 1, color: Color(0xFFE0E0E0)),

                // Global Discount
                if (isPercentageDiscount)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Remise Globale:",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000)),
                      ),
                      Text(
                        "${order.globalDiscount.toStringAsFixed(2)} %",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                    ],
                  )
                else if (isValueDiscount)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Remise Globale:",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000)),
                      ),
                      Text(
                        "${order.globalDiscount.toStringAsFixed(2)} DT",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                    ],
                  ),

                // Total et Mode de paiement
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total:",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000)),
                    ),
                    Text(
                      "${order.total.toStringAsFixed(2)} DT",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000)),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                Text(
                  "Mode de Paiement: ${order.modePaiement}",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Fermer", style: TextStyle(color: Color(0xFF000000))),
            ),
            TextButton(
              onPressed: () {
                generateAndSavePDF(context, order, isValueDiscount);
              },
              child:
                  Text("Imprimer", style: TextStyle(color: Color(0xFF000000))),
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
      BuildContext context, Order order, bool isValueDiscount) async {
    final pdf = pw.Document();
    bool isPercentageDiscount =!isValueDiscount; // Vérifie si la remise est en pourcentage

    // Define the page format for a standard receipt (80mm width, auto height)
    const double pageWidth = 70 * PdfPageFormat.mm;
    const double pageHeight = double.infinity;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight,
            marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with welcome message
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    "Bienvenue chez Chicopets!",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Merci pour votre visite!",
                    style: pw.TextStyle(
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            pw.Divider(),

            // Order number and date
            pw.Text(
              "Commande #${order.idOrder}",
              style: pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              "Date: ${formatDate(order.date)}",
              style: pw.TextStyle(fontSize: 8),
            ),
            pw.Divider(),

            // Header row for items
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Qt",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "Article",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "Prix U",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "Montant",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            pw.Divider(),

            // List of products
            ...order.orderLines.map((orderLine) {
              double discountedPrice =
                  orderLine.prixUnitaire * (1 - orderLine.discount / 100);
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "x${orderLine.quantite}",
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    orderLine.idProduct,
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    "${discountedPrice.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    "${(discountedPrice * orderLine.quantite).toStringAsFixed(2)} DT",
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              );
            }).toList(),

            pw.Divider(),

            // Global Discount
            if (isPercentageDiscount && order.globalDiscount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Remise Globale:",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "${order.globalDiscount.toStringAsFixed(2)} %",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ],
              )
            else if (isValueDiscount && order.globalDiscount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Remise Globale:",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "${order.globalDiscount.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),

            // Total and payment method
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Total:",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "${order.total.toStringAsFixed(2)} DT",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "Mode de Paiement: ${order.modePaiement}",
              style: pw.TextStyle(fontSize: 8),
            ),

            // Footer with thank you message
            pw.Center(
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "Merci pour votre confiance!",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "À bientôt chez Chicopets!",
                    style: pw.TextStyle(
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Save the PDF to the downloads directory
    final directory = await getDownloadsDirectory();
    final filePath = "${directory!.path}/ticket_commande_${order.idOrder}.pdf";

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("PDF enregistré dans: $filePath"),
        backgroundColor: Color(0xFF009688),
      ),
    );
  }
}