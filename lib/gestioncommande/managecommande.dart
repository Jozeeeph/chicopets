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
  TextEditingController _searchController = TextEditingController();
  List<Order> _allOrders = [];

  // Couleurs de la palette
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        refreshOrders();
      }
    });
    refreshOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void refreshOrders() {
    setState(() {
      futureOrders = sqlDb.getOrdersWithOrderLines().then((orders) {
        _allOrders =
            orders.where((order) => order.status != 'annulée').toList();
        return _allOrders;
      });
    });
  }

  void _filterOrders(String query) async {
    if (query.isEmpty) {
      setState(() {
        futureOrders = Future.value(_allOrders);
      });
      return;
    }

    final filtered = await Future.wait(_allOrders.map((order) async {
      if (order.idClient == null) return null;

      final client = await sqlDb.getClientById(order.idClient!);
      if (client == null) return null;

      final matches = client.name.toLowerCase().contains(query.toLowerCase()) ||
          client.firstName.toLowerCase().contains(query.toLowerCase()) ||
          client.phoneNumber.contains(query);

      return matches ? order : null;
    }));

    setState(() {
      futureOrders = Future.value(filtered.whereType<Order>().toList());
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
                children: [
                  Icon(Icons.warning, color: warmRed),
                  const SizedBox(width: 10),
                  Text(
                    'Confirmation',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: darkBlue),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tapez "Annuler" pour confirmer l\'annulation de cette commande.',
                    style: TextStyle(fontSize: 16, color: darkBlue),
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
                      fillColor: lightGray,
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
                  child: Text('Non', style: TextStyle(color: deepBlue)),
                ),
                ElevatedButton(
                  onPressed: isConfirmed
                      ? () async {
                          Navigator.of(context).pop(true);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmed ? warmRed : Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Annuler la commande',
                      style: TextStyle(color: Colors.white)),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande #${order.idOrder} annulée',
              style: TextStyle(color: white)),
          backgroundColor: warmRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text(
          'Gérer les Commandes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: deepBlue,
        iconTheme: IconThemeData(color: white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher par client',
                  labelStyle: TextStyle(color: darkBlue),
                  hintText: 'Nom, prénom ou téléphone',
                  prefixIcon: Icon(Icons.search, color: deepBlue),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: deepBlue),
                          onPressed: () {
                            _searchController.clear();
                            _filterOrders('');
                          },
                        )
                      : null,
                ),
                onChanged: _filterOrders,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: futureOrders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: deepBlue),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: warmRed, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(color: warmRed, fontSize: 18),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            color: deepBlue, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Aucune commande trouvée',
                          style: TextStyle(color: darkBlue, fontSize: 18),
                        ),
                      ],
                    ),
                  );
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      Order order = snapshot.data![index];

                      bool isCancelled = order.status == 'annulée';
                      bool isSemiPaid = order.status == 'non payée';
                      bool isPaid = order.status == 'payée';

                      Color statusColor = isCancelled
                          ? warmRed
                          : isSemiPaid
                              ? softOrange
                              : isPaid
                                  ? tealGreen
                                  : deepBlue;

                      IconData statusIcon = isCancelled
                          ? Icons.cancel
                          : isSemiPaid
                              ? Icons.payment
                              : isPaid
                                  ? Icons.check_circle
                                  : Icons.pending;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Material(
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: lightGray,
                                width: 1,
                              ),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(statusIcon, color: statusColor),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Commande #${order.idOrder}',
                                    style: TextStyle(
                                      color: darkBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    formatDate(order.date),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.attach_money,
                                          size: 16, color: statusColor),
                                      SizedBox(width: 4),
                                      Text(
                                        isCancelled
                                            ? 'Annulée'
                                            : isSemiPaid
                                                ? 'Reste: ${order.remainingAmount.toStringAsFixed(2)} DT'
                                                : isPaid
                                                    ? 'Payée: ${order.total.toStringAsFixed(2)} DT'
                                                    : 'À payer: ${order.total.toStringAsFixed(2)} DT',
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              children: [
                                Divider(thickness: 1, color: lightGray),
                                if (order.idClient != null)
                                  FutureBuilder(
                                    future:
                                        sqlDb.getClientById(order.idClient!),
                                    builder: (context, clientSnapshot) {
                                      if (clientSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return ListTile(
                                          leading: Icon(Icons.person,
                                              color: deepBlue),
                                          title: Text('Chargement client...',
                                              style:
                                                  TextStyle(color: darkBlue)),
                                        );
                                      }
                                      if (clientSnapshot.hasError ||
                                          !clientSnapshot.hasData) {
                                        return ListTile(
                                          leading: Icon(Icons.error_outline,
                                              color: warmRed),
                                          title: Text('Client non trouvé',
                                              style:
                                                  TextStyle(color: darkBlue)),
                                        );
                                      }
                                      final client = clientSnapshot.data!;
                                      return ListTile(
                                        leading:
                                            Icon(Icons.person, color: deepBlue),
                                        title: Text(
                                          '${client.firstName} ${client.name}',
                                          style: TextStyle(
                                              color: darkBlue,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(client.phoneNumber,
                                            style: TextStyle(color: darkBlue)),
                                      );
                                    },
                                  ),
                                if (order.orderLines.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning, color: softOrange),
                                        SizedBox(width: 8),
                                        Text(
                                          'Cette commande ne contient plus d\'articles',
                                          style: TextStyle(
                                              color: darkBlue,
                                              fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...order.orderLines.map((orderLine) {
                                    bool isCancelled =
                                        order.status == 'annulée';

                                    return FutureBuilder<Product?>(
                                      future: sqlDb
                                          .getProductById(orderLine.productId!),
                                      builder: (context, productSnapshot) {
                                        return ListTile(
                                          leading: Icon(
                                            isCancelled
                                                ? Icons.cancel
                                                : Icons.shopping_bag,
                                            color: isCancelled
                                                ? warmRed
                                                : tealGreen,
                                          ),
                                          title: Text(
                                            orderLine.productName ??
                                                'Nom de produit inconnu',
                                            style: TextStyle(
                                              color: isCancelled
                                                  ? Colors.grey
                                                  : darkBlue,
                                              fontWeight: FontWeight.bold,
                                              decoration: isCancelled
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .format_list_numbered,
                                                      size: 16,
                                                      color: isCancelled
                                                          ? Colors.grey
                                                          : softOrange),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Quantité: ${orderLine.quantity}',
                                                    style: TextStyle(
                                                      color: isCancelled
                                                          ? Colors.grey
                                                          : darkBlue,
                                                      decoration: isCancelled
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Icon(Icons.attach_money,
                                                      size: 16,
                                                      color: isCancelled
                                                          ? Colors.grey
                                                          : tealGreen),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Prix: ${orderLine.isPercentage ? (orderLine.prixUnitaire * orderLine.quantity * (1 - orderLine.discount / 100)).toStringAsFixed(2) : (orderLine.prixUnitaire * orderLine.quantity - orderLine.discount).toStringAsFixed(2)} DT',
                                                    style: TextStyle(
                                                      color: isCancelled
                                                          ? Colors.grey
                                                          : darkBlue,
                                                      decoration: isCancelled
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                if (!isCancelled)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          cancelOrder(context, order),
                                      icon: Icon(Icons.cancel, color: white),
                                      label: Text('Annuler la commande',
                                          style: TextStyle(color: white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: warmRed,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
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
