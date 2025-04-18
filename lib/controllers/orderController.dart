import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';

class OrderController {
  Future<int> addOrder(Order order, dbClient) async {
    // Insert the order details into the 'orders' table
    int orderId = await dbClient.insert(
      'orders',
      {
        'date': order.date,
        'total': order.total,
        'mode_paiement': order.modePaiement,
        'status': order.status,
        'remaining_amount': order.remainingAmount,
        'id_client': order.idClient,
        'global_discount': order.globalDiscount,
        'is_percentage_discount':
            order.isPercentageDiscount ? 1 : 0, // Added field
      },
    );

    // Insert each order line into the 'order_items' table
    for (var orderLine in order.orderLines) {
      await dbClient.insert(
        'order_items',
        {
          'id_order': orderId,
          'product_code': orderLine.idProduct,
          'quantity': orderLine.quantite,
          'prix_unitaire': orderLine.prixUnitaire,
          'discount': orderLine.discount,
          'isPercentage':
              orderLine.isPercentage ? 1 : 0, // Convert bool to int (1 or 0)
        },
      );
    }

    return orderId;
  }

  Future<void> updateOrderStatus(int idOrder, String status, dbClient) async {
    await dbClient.update(
      'orders',
      {'status': status},
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<List<Order>> getOrdersWithOrderLines(db1) async {
    // Fetch all orders
    List<Map<String, dynamic>> ordersData = await db1.query("orders");
    List<Order> orders = [];

    for (var orderMap in ordersData) {
      int orderId = orderMap['id_order'];
      double total = (orderMap['total'] ?? 0.0) as double;
      double remaining = (orderMap['remaining_amount'] ?? 0.0) as double;
      double globalDiscount = (orderMap['global_discount'] ?? 0.0) as double;
      bool isPercentageDiscount =
          (orderMap['is_percentage_discount'] as int?) == 1;
      int? idClient = orderMap['id_client'] as int?; // Récupérez l'ID client

      List<Map<String, dynamic>> orderLinesData = await db1.query(
        "order_items",
        where: "id_order = ?",
        whereArgs: [orderId],
      );

      List<OrderLine> orderLines = orderLinesData.map((line) {
        return OrderLine(
          idOrder: orderId,
          idProduct: line['product_code'].toString(),
          quantite: (line['quantity'] ?? 1) as int,
          prixUnitaire: (line['prix_unitaire'] ?? 0.0) as double,
          discount: (line['discount'] ?? 0.0) as double,
          isPercentage: (line['isPercentage'] as int?) == 1,
        );
      }).toList();

      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        total: total,
        modePaiement: orderMap['mode_paiement'] ?? "N/A",
        status: orderMap['status'],
        orderLines: orderLines,
        remainingAmount: remaining,
        globalDiscount: globalDiscount,
        isPercentageDiscount: isPercentageDiscount,
        idClient: idClient, // Passez l'ID client ici
      ));
    }

    return orders;
  }

  Future<void> deleteOrder(int idOrder, dbClient) async {
    await dbClient.delete(
      'orders',
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<int> cancelOrder(int idOrder, dbClient) async {
    // Update the status of the order to "Annulée"
    return await dbClient.update(
      'orders',
      {'status': 'Annulée'},
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<void> updateOrderInDatabase(Order order, dbClient) async {
    try {
      // Update the order with the new remaining amount and status
      await dbClient.update(
        'orders', // Table name
        {
          'remaining_amount': order.remainingAmount,
          'status': order.status,
        },
        where: 'id_order = ?',
        whereArgs: [order.idOrder], // The ID of the order to update
      );
    } catch (e) {
      // Handle any errors during the update
      print('Error updating order: $e');
      throw Exception('Error updating order');
    }
  }

  Future<List<Order>> getOrders(dbClient) async {
    List<Map<String, dynamic>> orderMaps = await dbClient.query('orders');

    List<Order> orders = [];
    for (var orderMap in orderMaps) {
      int orderId = orderMap['id_order'];

      // Fetch order lines from order_items
      List<Map<String, dynamic>> itemMaps = await dbClient.query(
        'order_items',
        where: 'id_order = ?',
        whereArgs: [orderId],
      );

      List<OrderLine> orderLines = [];

      for (var itemMap in itemMaps) {
        // Fetch the product details
        List<Map<String, dynamic>> productMaps = await dbClient.query(
          'products',
          where: 'code = ?',
          whereArgs: [itemMap['product_code']],
        );

        if (productMaps.isNotEmpty) {
          Product product = Product.fromMap(productMaps.first);

          // Create an OrderLine for each item, including isPercentage
          orderLines.add(OrderLine(
            idOrder: orderId,
            idProduct: itemMap['product_code'],
            quantite: itemMap['quantity'] ?? 1, // Default to 1 if null
            prixUnitaire: product.prixTTC, // TTC price from product
            discount: (itemMap['discount'] ?? 0.0).toDouble(), // Ensure double
            isPercentage:
                (itemMap['isPercentage'] ?? 1) == 1, // Convert 0/1 to bool
          ));
        }
      }

      // Create the Order object with the list of OrderLines
      orders.add(Order(
          idOrder: orderId,
          date: orderMap['date'],
          orderLines: orderLines,
          total: (orderMap['total'] ?? 0.0).toDouble(), // Ensure double
          modePaiement: orderMap['mode_paiement'] ?? "N/A",
          status: orderMap['status'] ?? "Pending",
          idClient: orderMap['id_client'],
          globalDiscount: orderMap['global_discount'].toDouble(),
          isPercentageDiscount: orderMap['is_percentage_discount']));
    }

    return orders;
  }

  Future<void> debugCheckOrder(int orderId,dbClient) async {
    final order = await dbClient.query(
      'orders',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    print('Order from DB: ${order.first}');

    if (order.first['id_client'] != null) {
      final client = await dbClient.query(
        'clients',
        where: 'id = ?',
        whereArgs: [order.first['id_client']],
      );
      print('Associated client: ${client.isNotEmpty ? client.first : 'None'}');
    }
  }
}
