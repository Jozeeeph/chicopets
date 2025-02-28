import 'package:flutter/material.dart';
import 'package:caissechicopets/order.dart';
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
      futureOrders = sqlDb.getOrdersWithOrderLines();
    });
  }

  Future<void> cancelOrder(BuildContext context, Order order) async {
    TextEditingController _confirmController = TextEditingController();
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
                child: CircularProgressIndicator(color: Color(0xFF0056A6)));
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16)),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Aucune commande trouvée.',
                  style: TextStyle(color: Color(0xFF0056A6), fontSize: 16)),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                Order order = snapshot.data![index];
                bool isCancelled = order.status == 'annulée';

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: isCancelled ? Colors.red.shade100 : Colors.white,
                  child: ExpansionTile(
                    title: Text(
                      'Commande #${order.idOrder} - ${formatDate(order.date)}',
                      style: TextStyle(
                        color: isCancelled ? Colors.red : const Color(0xFF0056A6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      isCancelled
                          ? 'Commande annulée'
                          : 'Total: \$${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: isCancelled
                              ? Colors.red
                              : const Color(0xFF009688),
                          fontSize: 14),
                    ),
                    children: [
                      ...order.orderLines.map((orderLine) {
                        return ListTile(
                          title: Text('Produit: ${orderLine.idProduct}',
                              style: const TextStyle(color: Color(0xFF0056A6))),
                          subtitle: Text(
                            'Quantité: ${orderLine.quantite} - Prix: \$${orderLine.prixUnitaire.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF26A9E0)),
                          ),
                        );
                      }).toList(),
                      if (!isCancelled)
                        TextButton.icon(
                          onPressed: () => cancelOrder(context, order),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Annuler la commande',
                              style: TextStyle(color: Colors.red)),
                        ),
                    ],
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