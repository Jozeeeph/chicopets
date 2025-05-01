import 'package:caissechicopets/models/product.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:intl/intl.dart';

class ManageCommand extends StatefulWidget {
  const ManageCommand({super.key});

  @override
  _ManageCommandState createState() => _ManageCommandState();
}

class _ManageCommandState extends State<ManageCommand> {
  late Future<List<Order>> futureOrders;
  final SqlDb sqlDb = SqlDb();

  @override
  void initState() {
    super.initState();
    refreshOrders();
  }

  void refreshOrders() {
    setState(() {
      futureOrders = sqlDb.getOrdersWithOrderLines().then((orders) {
        // Filter out cancelled orders and empty orders
        return orders
            .where((order) =>
                order.status != 'annulée' && order.orderLines.isNotEmpty)
            .toList();
      });
    });
  }

  Future<void> cancelOrder(BuildContext context, Order order) async {
    TextEditingController confirmController = TextEditingController();
    bool isConfirmed = false;

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

      // Restock products from the canceled order
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

      // Refresh the order list
      refreshOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gérer les Commandes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0056A6),
      ),
      body: FutureBuilder<List<Order>>(
        future: futureOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0056A6)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Aucune commande trouvée.',
                style: TextStyle(color: Color(0xFF0056A6), fontSize: 16),
              ),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                Order order = snapshot.data![index];

                print(
                    "Remaining amount when retrieving order: ${order.remainingAmount}");

                bool isCancelled = order.status == 'annulée';
                bool isSemiPaid = order.status == 'non payée';
                bool isPaid = order.status == 'payée';

                // Set the background color based on the status
                Color backgroundColor = isCancelled
                    ? Colors.red.shade100
                    : isSemiPaid
                        ? Colors.orange.shade100
                        : isPaid
                            ? Colors.green.shade100
                            : Colors.grey.shade100;

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    color: backgroundColor, // Apply background color
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex:
                                    2, // Adjust the flex value to control the space allocation
                                child: Text(
                                  'Commande #${order.idOrder} - ${formatDate(order.date)}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex:
                                    3, // Adjust the flex value to control the space allocation
                                child: Text(
                                  isCancelled
                                      ? 'Commande annulée - Total: ${order.total.toStringAsFixed(2)} DT'
                                      : isSemiPaid
                                          ? 'Semi-payée - Reste: ${order.remainingAmount.toStringAsFixed(2)} DT'
                                          : isPaid
                                              ? 'Payée - Total: ${order.total.toStringAsFixed(2)} DT'
                                              : 'Non payée - Total: ${order.total.toStringAsFixed(2)} DT',
                                  style: TextStyle(
                                    color: isCancelled
                                        ? Colors.red
                                        : isSemiPaid
                                            ? const Color.fromARGB(
                                                255, 188, 113, 0)
                                            : isPaid
                                                ? Colors.green
                                                : const Color(0xFF009688),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign
                                      .end, // Align the text to the end (right)
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                              height: 4), // Adds spacing between rows
                        ],
                      ),
                      children: [
                        const Divider(thickness: 1, color: Colors.grey),
                        ...order.orderLines.map((orderLine) {
                          return FutureBuilder<Product?>(
                            future: sqlDb.getProductById(orderLine.productId!),
                            builder: (context, productSnapshot) {
                              if (productSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const ListTile(
                                  title: Text(
                                    'Chargement...',
                                    style:
                                        TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                );
                              } else if (productSnapshot.hasError) {
                                return ListTile(
                                  title: Text(
                                    'Erreur: ${productSnapshot.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              } else if (!productSnapshot.hasData ||
                                  productSnapshot.data == null) {
                                return const ListTile(
                                  title: Text(
                                    'Produit introuvable',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              } else {
                                return ListTile(
                                  title: Text(
                                    'Produit: ${orderLine.productName}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Quantité: ${orderLine.quantity} - Prix: ${orderLine.isPercentage ? (orderLine.prixUnitaire * orderLine.quantity * (1 - orderLine.discount / 100)).toStringAsFixed(2) : (orderLine.prixUnitaire * orderLine.quantity - orderLine.discount).toStringAsFixed(2)} DT',
                                    style:
                                        const TextStyle(color: Colors.black87),
                                  ),
                                );
                              }
                            },
                          );
                        }),
                        if (!isCancelled)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextButton.icon(
                              onPressed: () => cancelOrder(context, order),
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text(
                                'Annuler la commande',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  static String formatDate(String date) {
    try {
      DateTime parsedDate = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
    } catch (e) {
      return 'Date invalide';
    }
  }
}
