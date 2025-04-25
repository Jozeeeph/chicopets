import 'dart:io';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:caissechicopets/models/order.dart';
import 'package:pdf/pdf.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // Added for font loading

class Getorderlist {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

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

      // Restock products from canceled order
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

      // Call callback to update UI
      onOrderCanceled();
    }
  }

  static double calculateTotalBeforeDiscount(Order order) {
    double total = 0.0;
    for (var orderLine in order.orderLines) {
      total += orderLine.prixUnitaire * orderLine.quantity;
    }
    return total;
  }

  static Future<void> cancelOrderLine(
      BuildContext context, Order order, OrderLine orderLine) async {
    final SqlDb sqldb = SqlDb();

    // Cancel order line
    await sqldb.cancelOrderLine(order.idOrder!, orderLine.productCode ?? '');

    // Restock product
    await sqldb.updateProductStock(orderLine.productId!, orderLine.quantity);

    // Recalculate order total
    final dbClient = await sqldb.db;
    final List<Map<String, dynamic>> remainingOrderLines = await dbClient.query(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    double newTotal = 0.0;
    for (var line in remainingOrderLines) {
      double prixUnitaire = line['prix_unitaire'] as double;
      int quantity = line['quantity'] as int;
      newTotal += prixUnitaire * quantity;
    }

    // Update order total in database
    await dbClient.update(
      'orders',
      {'total': newTotal},
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    // Update local Order object
    order.total = newTotal;
    order.orderLines
        .removeWhere((line) => line.productCode == orderLine.productCode);

    // Refresh order list
    Navigator.pop(context);
    showListOrdersPopUp(context);
  }

  static void showListOrdersPopUp(BuildContext context) async {
    final SqlDb sqldb = SqlDb();
    List<Order> orders = await sqldb.getOrdersWithOrderLines();
    orders = orders.where((order) => order.status != 'annulée').toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Liste des Commandes",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF0056A6)),
          ),
          content: orders.isEmpty
              ? const Text("Aucune commande disponible.",
                  style: TextStyle(color: Color(0xFF000000)))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      Order order = orders[index];
                      bool isCancelled = order.status == 'annulée';
                      bool isSemiPaid = order.remainingAmount > 0;

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: isCancelled
                            ? Colors.red.shade100
                            : isSemiPaid
                                ? Colors.orange.shade100
                                : order.status == "payée"
                                    ? Colors.green.shade100
                                    : Colors.white,
                        child: ExpansionTile(
                          title: Text(
                            'Commande #${order.idOrder} - ${formatDate(order.date)}',
                            style: TextStyle(
                              color: isCancelled
                                  ? Colors.red
                                  : isSemiPaid
                                      ? Colors.orange
                                      : order.status == "payée"
                                          ? Colors.green
                                          : const Color(0xFF0056A6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            isCancelled
                                ? 'Commande annulée'
                                : isSemiPaid
                                    ? 'Semi-payée - Reste: ${order.remainingAmount.toStringAsFixed(2)} DT'
                                    : order.status == "payée"
                                        ? 'Payée - Total: ${order.total.toStringAsFixed(2)} DT'
                                        : 'Non payée - Total: ${order.total.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              color: isCancelled
                                  ? Colors.red
                                  : isSemiPaid
                                      ? Colors.orange
                                      : order.status == "payée"
                                          ? Colors.green
                                          : const Color(0xFF009688),
                            ),
                          ),
                          children: [
                            ...order.orderLines.map((orderLine) {
                              return FutureBuilder<Product?>(
                                future:
                                    sqldb.getProductById(orderLine.productId!),
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
                                  double discountedPrice =
                                      orderLine.prixUnitaire *
                                          (1 - orderLine.discount / 100);
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            "x${orderLine.quantity}",
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF000000)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            product.designation,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF000000)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF000000)),
                                              ),
                                              if (orderLine.discount > 0)
                                                Text(
                                                  orderLine.isPercentage
                                                      ? "-${orderLine.discount.toStringAsFixed(2)}%"
                                                      : "-${orderLine.discount.toStringAsFixed(2)} DT",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            "${(orderLine.finalPrice * orderLine.quantity).toStringAsFixed(2)} DT",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF000000),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showOrderTicketPopup(context, order);
                                    },
                                    icon:
                                        Icon(Icons.print, color: Colors.white),
                                    label: Text("Imprimer Ticket",
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF26A9E0),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await cancelOrder(context, order, () {
                                        Navigator.pop(context);
                                        showListOrdersPopUp(context);
                                      });
                                    },
                                    icon:
                                        Icon(Icons.cancel, color: Colors.white),
                                    label: Text("Annuler Commande",
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                  ),
                                  if (isSemiPaid)
                                    IconButton(
                                      icon: Icon(Icons.update,
                                          color: Colors.blue),
                                      onPressed: () {
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
                style: TextStyle(color: Color(0xFF000000)),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _updateSemiPaidOrder(BuildContext context, Order order) {
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                double amountToAdd =
                    double.tryParse(amountController.text) ?? 0;

                if (amountToAdd > 0) {
                  _addAmountToOrder(context, order, amountToAdd);
                  Navigator.pop(context);
                } else {
                  Getorderlist.scaffoldMessengerKey.currentState?.showSnackBar(
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
    final SqlDb sqldb = SqlDb();
    order.remainingAmount -= amount;

    if (order.remainingAmount <= 0) {
      order.status = 'payée';
    }

    await sqldb.updateOrderInDatabase(order);

    Getorderlist.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Commande #${order.idOrder} mise à jour avec ${amount.toStringAsFixed(2)} DT',
        ),
      ),
    );

    Navigator.pop(context);
    showListOrdersPopUp(context);
  }

  static void _showOrderTicketPopup(BuildContext context, Order order) async {
    final SqlDb sqldb = SqlDb();
    bool isPercentageDiscount = order.isPercentageDiscount;
    double totalBeforeDiscount = calculateTotalBeforeDiscount(order);

    Client? client;
    if (order.idClient != null) {
      client = await sqldb.getClientById(order.idClient!);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Center(
            child: Row(
              children: [
                Icon(Icons.receipt, color: Color(0xFF000000)),
                SizedBox(width: 8),
                Text(
                  "Ticket de Commande",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF000000)),
                ),
              ],
            ),
          ),
          content: Container(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(thickness: 1, color: Color(0xFFE0E0E0)),
                  Text(
                    "Commande #${order.idOrder}\nDate: ${formatDate(order.date)}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000)),
                  ),
                  if (client != null) ...[
                    SizedBox(height: 8),
                    Text(
                      "Client: ${client.name} ${client.firstName}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF000000)),
                    ),
                  ],
                  Divider(thickness: 1, color: Color(0xFFE0E0E0)),
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(thickness: 1, color: Color(0xFFE0E0E0)),
                  ...order.orderLines.map((orderLine) {
                    return FutureBuilder<Product?>(
                      future:
                          sqldb.getProductByCode(orderLine.productCode ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                                  "x${orderLine.quantity}",
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
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                  style: TextStyle(
                                      fontSize: 16, color: Color(0xFF000000)),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  "${(discountedPrice * orderLine.quantity).toStringAsFixed(2)} DT",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF000000)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                  Divider(thickness: 1, color: Color(0xFFE0E0E0)),
                  if (order.globalDiscount > 0 ||
                      order.orderLines.any((ol) => ol.discount > 0))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total avant remise:",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000)),
                        ),
                        Text(
                          "${totalBeforeDiscount.toStringAsFixed(2)} DT",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000)),
                        ),
                      ],
                    ),
                  if (isPercentageDiscount && order.globalDiscount > 0)
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
                  else if (!isPercentageDiscount && order.globalDiscount > 0)
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
                  if (order.modePaiement == "Espèce" &&
                      order.cashAmount != null) ...[
                    SizedBox(height: 5),
                    Text(
                      "Montant espèces: ${order.cashAmount!.toStringAsFixed(2)} DT",
                      style: TextStyle(fontSize: 14),
                    ),
                    if ((order.cashAmount! - order.total) > 0)
                      Text(
                        "Monnaie rendue: ${(order.cashAmount! - order.total).toStringAsFixed(2)} DT",
                        style: TextStyle(fontSize: 14),
                      ),
                  ],
                  if (order.modePaiement == "TPE" &&
                      order.cardAmount != null) ...[
                    SizedBox(height: 5),
                    Text(
                      "Montant carte: ${order.cardAmount!.toStringAsFixed(2)} DT",
                      style: TextStyle(fontSize: 14),
                    ),
                    if (order.cardTransactionId != null)
                      Text(
                        "Transaction: ${order.cardTransactionId}",
                        style: TextStyle(fontSize: 14),
                      ),
                  ],
                  if (order.modePaiement == "Chèque" &&
                      order.checkAmount != null) ...[
                    SizedBox(height: 5),
                    Text(
                      "Montant chèque: ${order.checkAmount!.toStringAsFixed(2)} DT",
                      style: TextStyle(fontSize: 14),
                    ),
                    if (order.checkNumber != null)
                      Text(
                        "N° chèque: ${order.checkNumber}",
                        style: TextStyle(fontSize: 14),
                      ),
                    if (order.bankName != null)
                      Text(
                        "Banque: ${order.bankName}",
                        style: TextStyle(fontSize: 14),
                      ),
                    if (order.checkDate != null)
                      Text(
                        "Date: ${DateFormat('dd/MM/yyyy').format(order.checkDate!)}",
                        style: TextStyle(fontSize: 14),
                      ),
                  ],
                  if (order.modePaiement == "Mixte") ...[
                    SizedBox(height: 5),
                    if (order.cashAmount != null && order.cashAmount! > 0)
                      Text(
                        "Espèces: ${order.cashAmount!.toStringAsFixed(2)} DT",
                        style: TextStyle(fontSize: 14),
                      ),
                    if (order.cardAmount != null && order.cardAmount! > 0) ...[
                      Text(
                        "Carte: ${order.cardAmount!.toStringAsFixed(2)} DT",
                        style: TextStyle(fontSize: 14),
                      ),
                      if (order.cardTransactionId != null)
                        Text(
                          "Transaction: ${order.cardTransactionId}",
                          style: TextStyle(fontSize: 14),
                        ),
                    ],
                    if (order.checkAmount != null &&
                        order.checkAmount! > 0) ...[
                      Text(
                        "Chèque: ${order.checkAmount!.toStringAsFixed(2)} DT",
                        style: TextStyle(fontSize: 14),
                      ),
                      if (order.checkNumber != null)
                        Text(
                          "N°: ${order.checkNumber}",
                          style: TextStyle(fontSize: 14),
                        ),
                      if (order.bankName != null)
                        Text(
                          "Banque: ${order.bankName}",
                          style: TextStyle(fontSize: 14),
                        ),
                      if (order.checkDate != null)
                        Text(
                          "Date: ${DateFormat('dd/MM/yyyy').format(order.checkDate!)}",
                          style: TextStyle(fontSize: 14),
                        ),
                    ],
                  ],
                  if (order.remainingAmount > 0) ...[
                    SizedBox(height: 5),
                    Text(
                      "Reste à payer: ${order.remainingAmount.toStringAsFixed(2)} DT",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Fermer",
                style: TextStyle(color: Color(0xFF000000)),
              ),
            ),
            TextButton(
              onPressed: () {
                generateAndSavePDF(order);
              },
              child: Text(
                "Imprimer",
                style: TextStyle(color: Color(0xFF000000)),
              ),
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

  static Future<void> generateAndSavePDF(Order order) async {
    // Load the custom font
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");

    final ttf = pw.Font.ttf(fontData);
    final boldTtf = pw.Font.ttf(boldFontData);

    final SqlDb sqldb = SqlDb();
    final pdf = pw.Document();
    bool isPercentageDiscount = order.isPercentageDiscount;
    double totalBeforeDiscount = calculateTotalBeforeDiscount(order);

    // Get client information
    Client? client;
    if (order.idClient != null) {
      client = await sqldb.getClientById(order.idClient!);
    }

    // Define the page format for a standard receipt
    const double pageWidth = 70 * PdfPageFormat.mm;
    const double pageHeight = double.infinity;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight,
            marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    "Bienvenue chez Chicopets!",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Merci pour votre visite!",
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            pw.Divider(),

            // Order information
            pw.Text(
              "Commande #${order.idOrder}",
              style: pw.TextStyle(font: ttf, fontSize: 8),
            ),
            pw.Text(
              "Date: ${formatDate(order.date)}",
              style: pw.TextStyle(font: ttf, fontSize: 8),
            ),

            // Client information
            if (client != null)
              pw.Text(
                "Client: ${client.name} ${client.firstName}",
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),

            pw.Divider(),

            // Items header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Qt",
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "Article",
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "Prix U",
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "Montant",
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            pw.Divider(),

            // Items list
            ...order.orderLines.map((orderLine) {
              double discountedPrice =
                  orderLine.prixUnitaire * (1 - orderLine.discount / 100);
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "x${orderLine.quantity}",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                  pw.Text(
                    orderLine.productCode ?? '',
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                  pw.Text(
                    "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                  pw.Text(
                    "${(discountedPrice * orderLine.quantity).toStringAsFixed(2)} DT",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                ],
              );
            }).toList(),

            pw.Divider(),

            // Totals and discounts
            if (order.globalDiscount > 0 ||
                order.orderLines.any((ol) => ol.discount > 0))
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Total avant remise:",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "${totalBeforeDiscount.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),

            if (isPercentageDiscount && order.globalDiscount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Remise Globale:",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "${order.globalDiscount.toStringAsFixed(2)} %",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                ],
              )
            else if (!isPercentageDiscount && order.globalDiscount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Remise Globale:",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "${order.globalDiscount.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),

            // Final total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Total:",
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  "${order.total.toStringAsFixed(2)} DT",
                  style: pw.TextStyle(
                    font: boldTtf,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "Mode de Paiement: ${order.modePaiement}",
              style: pw.TextStyle(font: ttf, fontSize: 8),
            ),

            // Payment details
            if (order.modePaiement == "Espèce" && order.cashAmount != null) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                "Montant espèces: ${order.cashAmount!.toStringAsFixed(2)} DT",
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
              if ((order.cashAmount! - order.total) > 0)
                pw.Text(
                  "Monnaie rendue: ${(order.cashAmount! - order.total).toStringAsFixed(2)} DT",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
            ],

            if (order.modePaiement == "TPE" && order.cardAmount != null) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                "Montant carte: ${order.cardAmount!.toStringAsFixed(2)} DT",
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
              if (order.cardTransactionId != null)
                pw.Text(
                  "Transaction: ${order.cardTransactionId}",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
            ],

            if (order.modePaiement == "Chèque" &&
                order.checkAmount != null) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                "Montant chèque: ${order.checkAmount!.toStringAsFixed(2)} DT",
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
              if (order.checkNumber != null)
                pw.Text(
                  "N° chèque: ${order.checkNumber}",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
              if (order.bankName != null)
                pw.Text(
                  "Banque: ${order.bankName}",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
              if (order.checkDate != null)
                pw.Text(
                  "Date: ${DateFormat('dd/MM/yyyy').format(order.checkDate!)}",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
            ],

            if (order.modePaiement == "Mixte") ...[
              pw.SizedBox(height: 5),
              if (order.cashAmount != null && order.cashAmount! > 0)
                pw.Text(
                  "Espèces: ${order.cashAmount!.toStringAsFixed(2)} DT",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
              if (order.cardAmount != null && order.cardAmount! > 0) ...[
                pw.Text(
                  "Carte: ${order.cardAmount!.toStringAsFixed(2)} DT",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
                if (order.cardTransactionId != null)
                  pw.Text(
                    "Transaction: ${order.cardTransactionId}",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
              ],
              if (order.checkAmount != null && order.checkAmount! > 0) ...[
                pw.Text(
                  "Chèque: ${order.checkAmount!.toStringAsFixed(2)} DT",
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
                if (order.checkNumber != null)
                  pw.Text(
                    "N°: ${order.checkNumber}",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                if (order.bankName != null)
                  pw.Text(
                    "Banque: ${order.bankName}",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
                if (order.checkDate != null)
                  pw.Text(
                    "Date: ${DateFormat('dd/MM/yyyy').format(order.checkDate!)}",
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                  ),
              ],
            ],

            // Remaining amount
            if (order.remainingAmount > 0) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                "Reste à payer: ${order.remainingAmount.toStringAsFixed(2)} DT",
                style: pw.TextStyle(
                  font: boldTtf,
                  fontSize: 8,
                ),
              ),
            ],

            // Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 10),
                  pw.Text(
                    "Merci pour votre confiance!",
                    style: pw.TextStyle(
                      font: boldTtf,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "À bientôt chez Chicopets!",
                    style: pw.TextStyle(
                      font: ttf,
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

    // Save the PDF
    final directory = await getDownloadsDirectory();
    final filePath = "${directory!.path}/ticket_commande_${order.idOrder}.pdf";

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Show success message
    Getorderlist.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("PDF enregistré dans: $filePath"),
        backgroundColor: Color(0xFF009688),
      ),
    );
  }
}
