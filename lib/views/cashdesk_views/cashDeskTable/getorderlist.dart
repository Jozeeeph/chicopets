import 'dart:io';

import 'package:caissechicopets/controllers/userController.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/stock_movement.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:caissechicopets/views/cashdesk_views/cashDeskTable/tableCmd.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/addorder.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/applyDiscount.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/deleteline.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/modifyquantity.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:caissechicopets/models/order.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart'; // Added for font loading

class Getorderlist {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

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

    // Load orders and filter them
    List<Order> orders = await sqldb.getOrdersWithOrderLines();
    orders = orders
        .where(
            (order) => order.status != 'annulée' && order.orderLines.isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Tri par date décroissante

    // Load all clients and build a map for quick access
    final clients = await sqldb.getAllClients();
    final Map<int, Client> clientMap = {
      for (var client in clients) client.id!: client,
    };

    TextEditingController searchController = TextEditingController();
    List<Order> filteredOrders = List.from(orders);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void filterOrders(String query) {
              setState(() {
                filteredOrders = orders.where((order) {
                  final idMatch =
                      order.idOrder.toString().contains(query.trim());
                  final dateMatch = formatDate(order.date)
                      .toLowerCase()
                      .contains(query.toLowerCase().trim());
                  final clientName = clientMap[order.idClient]?.name ?? '';
                  final clientMatch = clientName
                      .toLowerCase()
                      .contains(query.toLowerCase().trim());
                  return idMatch || dateMatch || clientMatch;
                }).toList();
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                "Liste des Commandes",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF0056A6)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Rechercher par ID, Date ou Nom Client",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: filterOrders,
                  ),
                  const SizedBox(height: 10),
                  filteredOrders.isEmpty
                      ? const Text("Aucune commande trouvée.",
                          style: TextStyle(color: Color(0xFF000000)))
                      : SizedBox(
                          width: double.maxFinite,
                          height: 400,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              Order order = filteredOrders[index];
                              bool isCancelled = order.status == 'annulée';
                              bool isSemiPaid = order.remainingAmount > 0;
                              final clientName =
                                  clientMap[order.idClient]?.name ??
                                      'Client inconnu';

                              return Card(
                                margin: const EdgeInsets.all(8.0),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                    '$clientName\n${isCancelled ? 'Commande annulée' : isSemiPaid ? 'Semi-payée - Reste: ${order.remainingAmount.toStringAsFixed(2)} DT' : order.status == "payée" ? 'Payée - Total: ${order.total.toStringAsFixed(2)} DT' : 'Non payée - Total: ${order.total.toStringAsFixed(2)} DT'}',
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
                                      String productName = orderLine
                                              .productData?['designation'] ??
                                          orderLine.productName ??
                                          'Produit inconnu';

                                      if (orderLine.variantName != null) {
                                        productName +=
                                            " (${orderLine.variantName})";
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0),
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
                                                productName,
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
                                                        color:
                                                            Color(0xFF000000)),
                                                  ),
                                                  if (orderLine.discount > 0)
                                                    Text(
                                                      orderLine.isPercentage
                                                          ? "-${orderLine.discount.toStringAsFixed(2)}%"
                                                          : "-${orderLine.discount.toStringAsFixed(2)} DT",
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                            IconButton(
                                              icon: Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () async {
                                                await deleteOrderLine(
                                                    context, order, orderLine,
                                                    () {
                                                  Navigator.pop(context);
                                                  showListOrdersPopUp(context);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              _showOrderTicketPopup(
                                                  context, order);
                                            },
                                            icon: Icon(Icons.print,
                                                color: Colors.white),
                                            label: Text("Imprimer Ticket",
                                                style: TextStyle(
                                                    color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF26A9E0),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _editOrder(context, order),
                                            icon: const Icon(Icons.edit,
                                                color: Colors.white),
                                            label: const Text(
                                              "Modifier",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                            ),
                                          ),
                                          if (isSemiPaid)
                                            IconButton(
                                              icon: Icon(Icons.update,
                                                  color: Colors.blue),
                                              onPressed: () {
                                                _updateSemiPaidOrder(
                                                    context, order);
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
                ],
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
      },
    );
  }

  // This should be placed outside any class to make it reusable
  static double calculateOrderTotal(
    List<Product> products,
    List<int> quantities,
    List<double> discounts,
    List<bool> discountTypes,
    double globalDiscount,
    bool isPercentageDiscount,
  ) {
    double total = 0.0;
    for (int i = 0; i < products.length; i++) {
      double price = products[i].hasVariants && products[i].variants.isNotEmpty
          ? products[i].variants.first.finalPrice
          : products[i].prixTTC;
      double lineTotal = discountTypes[i]
          ? price * quantities[i] * (1 - discounts[i] / 100)
          : (price * quantities[i]) - discounts[i];
      total += lineTotal.clamp(0, double.infinity);
    }
    total = isPercentageDiscount
        ? total * (1 - globalDiscount / 100)
        : total - globalDiscount;
    return total.clamp(0, double.infinity);
  }

  static void _editOrder(BuildContext context, Order order) async {
    // First validate that the order has an ID
    if (order.idOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Erreur: La commande n'a pas d'ID valide")),
      );
      return;
    }

    final SqlDb sqldb = SqlDb();

    try {
      // Get all products from the order lines
      List<Product> products = [];
      List<int> quantities = [];
      List<double> discounts = [];
      List<bool> discountTypes = [];

      for (var line in order.orderLines) {
        Product? product;

        if (line.variantId != null) {
          final variant = await sqldb.getVariantById(line.variantId!);
          if (variant != null) {
            product = await sqldb.getProductById(variant.productId);
            if (product != null) {
              product.variants = [variant];
            }
          }
        } else if (line.productId != null) {
          product = await sqldb.getProductById(line.productId!);
        }

        if (product != null) {
          products.add(product);
          quantities.add(line.quantity);
          discounts.add(line.discount);
          discountTypes.add(line.isPercentage);
        }
      }

      // Navigate to edit screen
      if (context.mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Modifier Commande #${order.idOrder}'),
                  ),
                  body: TableCmd(
                    total: order.total,
                    selectedProducts: products,
                    quantityProducts: quantities,
                    discounts: discounts,
                    typeDiscounts: discountTypes,
                    globalDiscount: order.globalDiscount,
                    isPercentageDiscount: order.isPercentageDiscount,
                    selectedClient:
                        order.idClient ?? 0, // Use null-coalescing operator
                    onApplyDiscount: (index) {
                      Applydiscount.showDiscountInput(
                        context,
                        index,
                        discounts,
                        discountTypes,
                        products,
                        () => setState(() {}),
                      );
                    },
                    onDeleteProduct: (index) {
                      Deleteline.showDeleteConfirmation(
                        index,
                        context,
                        products,
                        quantities,
                        discounts,
                        discountTypes,
                        () => setState(() {}),
                      );
                    },
                    onAddProduct: () {
                      // Implement product addition logic
                    },
                    onSearchProduct: () {
                      // Implement product search logic
                    },
                    onQuantityChange: (index) {
                      ModifyQt.showQuantityInput(
                        context,
                        index,
                        quantities,
                        () => setState(() {}),
                      );
                    },
                    calculateTotal: calculateOrderTotal,
                    onFetchOrders: () {
                      Navigator.pop(context);
                    },
                    onPlaceOrder: (selectedClient) async {
                      // 1. First validate we have products
                      if (products.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Aucun produit sélectionné")),
                        );
                        return;
                      }

                      // 2. Create a DEEP COPY of the order to prevent modifications
                      final orderToUpdate = Order(
                        idOrder: order.idOrder, // Preserve the original ID
                        total: calculateOrderTotal(
                          products,
                          quantities,
                          discounts,
                          discountTypes,
                          order.globalDiscount,
                          order.isPercentageDiscount,
                        ),
                        globalDiscount: order.globalDiscount,
                        isPercentageDiscount: order.isPercentageDiscount,
                        date: order.date,
                        status: order.status,
                        idClient: selectedClient > 0
                            ? selectedClient
                            : null, // Handle client ID properly
                        modePaiement: order.modePaiement,
                        cashAmount: order.cashAmount,
                        cardAmount: order.cardAmount,
                        checkAmount: order.checkAmount,
                        checkNumber: order.checkNumber,
                        bankName: order.bankName,
                        checkDate: order.checkDate,
                        cardTransactionId: order.cardTransactionId,
                        remainingAmount: order.remainingAmount,
                        orderLines: [], // Initialize empty lines
                      );

                      // 3. Create order lines with proper reference
                      orderToUpdate.orderLines = products.map((product) {
                        return OrderLine(
                          idOrder: orderToUpdate.idOrder!,
                          productId: product.id,
                          productCode: product.code,
                          productName: product.designation,
                          variantId: product.variants.isNotEmpty
                              ? product.variants.first.id
                              : null,
                          variantName: product.variants.isNotEmpty
                              ? product.variants.first.combinationName
                              : null,
                          quantity: quantities[products.indexOf(product)],
                          prixUnitaire: product.variants.isNotEmpty
                              ? product.variants.first.finalPrice
                              : product.prixTTC,
                          discount: discounts[products.indexOf(product)],
                          isPercentage:
                              discountTypes[products.indexOf(product)],
                        );
                      }).toList();

                      // 4. Show payment dialog with the COPIED order
                      final shouldUpdate = await Addorder.showPlaceOrderPopup(
                        context,
                        orderToUpdate,
                        selectedClient,
                        products,
                        quantities,
                        discounts,
                        discountTypes,
                        isUpdating: true,
                      );

                      if (shouldUpdate != true) return;

                      // 5. Attempt to update with proper error handling
                      try {
                        await sqldb.updateOrderInDatabase(orderToUpdate);

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Commande mise à jour")),
                        );
                      } catch (e, stack) {
                        debugPrint('[onPlaceOrder] Update failed: $e\n$stack');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur: ${e.toString()}")),
                        );
                      }
                    },
                    onProductSelected: (index) {
                      // Implement product selection logic
                    },
                    onGlobalDiscountChanged: (value) {
                      setState(() {
                        order.globalDiscount = value;
                      });
                    },
                    onIsPercentageDiscountChanged: (value) {
                      setState(() {
                        order.isPercentageDiscount = value;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erreur lors de la modification: ${e.toString()}")),
        );
      }
    }
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
                  // Dans la méthode _showOrderTicketPopup, remplacez la partie d'affichage des produits par :

                  ...order.orderLines.map((orderLine) {
                    // Utilisez product_data si disponible, sinon les champs standards
                    String productName =
                        orderLine.productData?['designation'] ??
                            orderLine.productName ??
                            'Produit inconnu';

                    if (orderLine.variantName != null) {
                      productName += " (${orderLine.variantName})";
                    }

                    double discountedPrice =
                        orderLine.prixUnitaire * (1 - orderLine.discount / 100);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              "x${orderLine.quantity}", // Afficher la quantité ici
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF000000)),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              productName,
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF000000)),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "${discountedPrice.toStringAsFixed(2)} DT",
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
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  // Remplacer toute la section des détails de paiement par :
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

  // In your Getorderlist class
  static Future<void> deleteOrderLine(
    BuildContext context,
    Order order,
    OrderLine orderLine,
    Function() onOrderLineDeleted,
  ) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
            'Voulez-vous vraiment supprimer cet article de la commande?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      final SqlDb sqldb = SqlDb();
      final dbClient = await sqldb.db;

      // Calculate new total
      final double lineTotal = orderLine.finalPrice * orderLine.quantity;
      final double newTotal = order.total - lineTotal;

      // Transaction with proper error handling
      await dbClient.transaction((txn) async {
        // 1. Delete the order line and verify deletion
        final deletedCount = await _deleteOrderLineWithVerification(
          txn,
          order.idOrder!,
          orderLine,
        );

        if (deletedCount == 0) {
          throw Exception('Failed to delete order line - no rows affected');
        }

        // 2. Restock the item and record movement - TOUT doit utiliser txn
        await _restockItemAndRecordMovement(
          txn,
          orderLine,
          StockMovementService(sqldb),
          order.idOrder!,
        );

        // 3. Update order total or delete if empty
        if (order.orderLines.length == 1) {
          await txn.delete(
            'orders',
            where: 'id_order = ?',
            whereArgs: [order.idOrder],
          );
        } else {
          await txn.update(
            'orders',
            {'total': newTotal},
            where: 'id_order = ?',
            whereArgs: [order.idOrder],
          );
        }
      });

      // Update local state
      order.orderLines.removeWhere((line) =>
          line.productId == orderLine.productId &&
          line.variantId == orderLine.variantId);
      order.total = newTotal;

      // Show success message
      scaffoldMessengerKey.currentState?.showSnackBar(
        order.orderLines.isEmpty
            ? const SnackBar(
                content: Text('Commande vide supprimée'),
                backgroundColor: Colors.green,
              )
            : const SnackBar(
                content: Text('Article supprimé avec succès'),
                backgroundColor: Colors.green,
              ),
      );

      onOrderLineDeleted();
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _restockItemAndRecordMovement(
    DatabaseExecutor txn,
    OrderLine orderLine,
    StockMovementService stockMovementService,
    int orderId,
  ) async {
    if (orderLine.variantId != null) {
      // Get current stock of variant - utiliser txn au lieu de SqlDb()
      final result = await txn.query(
        'variants',
        where: 'id = ?',
        whereArgs: [orderLine.variantId],
      );

      if (result.isEmpty) return;
      final variant = Variant.fromMap(result.first);

      // Record stock movement for return
      await stockMovementService.recordMovementWithTransaction(
        txn,
        StockMovement(
          productId: orderLine.productId!,
          variantId: orderLine.variantId,
          movementType: StockMovement.movementTypeReturn,
          quantity: orderLine.quantity,
          previousStock: variant.stock,
          newStock: variant.stock + orderLine.quantity,
          movementDate: DateTime.now(),
          referenceId: orderId.toString(),
          notes: 'Suppression ligne commande #$orderId',
        ),
      );

      // Update variant stock
      await txn.rawUpdate(
        'UPDATE variants SET stock = stock + ? WHERE id = ?',
        [orderLine.quantity, orderLine.variantId],
      );
    } else if (orderLine.productId != null) {
      // Get current stock of product - utiliser txn au lieu de SqlDb()
      final result = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [orderLine.productId],
      );

      if (result.isEmpty) return;
      final product = Product.fromMap(result.first);

      // Record stock movement for return
      await stockMovementService.recordMovementWithTransaction(
        txn,
        StockMovement(
          productId: orderLine.productId!,
          movementType: StockMovement.movementTypeReturn,
          quantity: orderLine.quantity,
          previousStock: product.stock,
          newStock: product.stock + orderLine.quantity,
          movementDate: DateTime.now(),
          referenceId: orderId.toString(),
          notes: 'Suppression ligne commande #$orderId',
        ),
      );

      // Update product stock
      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ? WHERE id = ?',
        [orderLine.quantity, orderLine.productId],
      );
    }
  }

  static Future<int> _deleteOrderLineWithVerification(
    DatabaseExecutor dbClient,
    int idOrder,
    OrderLine orderLine,
  ) async {
    if (orderLine.productCode == null && orderLine.productId == null) {
      throw Exception('Invalid order line: missing product identifier');
    }

    final String idProduct =
        orderLine.productCode ?? orderLine.productId!.toString();
    final int? variantId = orderLine.variantId;
    String whereClause;
    List<dynamic> whereArgs;

    if (variantId != null) {
      whereClause =
          'id_order = ? AND variant_id = ? AND (product_code = ? OR product_id = ?)';
      whereArgs = [idOrder, variantId, idProduct, idProduct];
    } else {
      whereClause =
          'id_order = ? AND variant_id IS NULL AND (product_code = ? OR product_id = ?)';
      whereArgs = [idOrder, idProduct, idProduct];
    }

    final deletedCount = await dbClient.delete(
      'order_items',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return deletedCount;
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
    final user = await sqldb.getUserById(order.userId!);
    if (user == null) {
      throw Exception("User not found for order ${order.idOrder}");
    }

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
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Quantité
                  pw.Container(
                    width: 10, // Largeur fixe pour la quantité
                    child: pw.Text(
                      "x${orderLine.quantity}",
                      style: pw.TextStyle(font: ttf, fontSize: 8),
                    ),
                  ),
                  // Nom du produit avec largeur limitée
                  pw.Container(
                    width: 100, // Largeur fixe pour le nom
                    child: pw.Text(
                      orderLine.productName ?? '',
                      style: pw.TextStyle(font: ttf, fontSize: 8),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                  // Prix unitaire
                  pw.Container(
                    width: 30, // Largeur fixe pour le prix
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                      style: pw.TextStyle(font: ttf, fontSize: 8),
                    ),
                  ),
                  // Montant total
                  pw.Container(
                    width: 30, // Largeur fixe pour le montant
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      "${(discountedPrice * orderLine.quantity).toStringAsFixed(2)} DT",
                      style: pw.TextStyle(font: ttf, fontSize: 8),
                    ),
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
            // Dans generateAndSavePDF, mettre à jour les sections de paiement :

// Espèces
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

// Carte
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

            pw.Text(
              "Caissier: ${user.username}",
              style: pw.TextStyle(font: ttf, fontSize: 8),
            ),

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
