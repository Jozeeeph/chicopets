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
        'user_id' : order.userId,
        'global_discount': order.globalDiscount,
        'is_percentage_discount': order.isPercentageDiscount ? 1 : 0,
      },
    );

    // Insert each order line into the 'order_items' table
    for (var orderLine in order.orderLines) {
      await dbClient.insert(
        'order_items',
        {
          'id_order': orderId,
          'product_code': orderLine.productCode,
          'product_id': orderLine.productId,
          'quantity': orderLine.quantity,
          'prix_unitaire': orderLine.prixUnitaire,
          'discount': orderLine.discount,
          'isPercentage': orderLine.isPercentage ? 1 : 0,
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

  Future<List<Order>> getOrdersWithOrderLines(dbClient) async {
    final ordersData = await dbClient.query("orders");
    final orders = <Order>[];

    for (final orderMap in ordersData) {
      final orderId = orderMap['id_order'] as int;
      
      // Fetch order lines
      final orderLinesData = await dbClient.query(
        "order_items",
        where: "id_order = ?",
        whereArgs: [orderId],
      );

      final orderLines = await _buildOrderLines(dbClient, orderLinesData);

      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        total: (orderMap['total'] as num).toDouble(),
        modePaiement: orderMap['mode_paiement'] as String,
        status: orderMap['status'] as String,
        orderLines: orderLines,
        remainingAmount: (orderMap['remaining_amount'] as num).toDouble(),
        globalDiscount: (orderMap['global_discount'] as num).toDouble(),
        isPercentageDiscount: (orderMap['is_percentage_discount'] as int) == 1,
        idClient: orderMap['id_client'] as int?,
      ));
    }

    return orders;
  }

  Future<List<OrderLine>> _buildOrderLines(dbClient, List<Map<String, dynamic>> orderLinesData) async {
    final orderLines = <OrderLine>[];

    for (final line in orderLinesData) {
      Product? product;
      
      // Try to fetch product by ID first, then by code
      if (line['product_id'] != null) {
        final productMaps = await dbClient.query(
          'products',
          where: 'id = ?',
          whereArgs: [line['product_id']],
        );
        if (productMaps.isNotEmpty) {
          product = Product.fromMap(productMaps.first);
        }
      }

      if (product == null && line['product_code'] != null) {
        final productMaps = await dbClient.query(
          'products',
          where: 'code = ?',
          whereArgs: [line['product_code']],
        );
        if (productMaps.isNotEmpty) {
          product = Product.fromMap(productMaps.first);
        }
      }

      orderLines.add(OrderLine(
        idOrder: line['id_order'] as int,
        productCode: line['product_code']?.toString(),
        productId: line['product_id'] as int?,
        quantity: line['quantity'] as int,
        prixUnitaire: product?.prixTTC ?? (line['prix_unitaire'] as num).toDouble(),
        discount: (line['discount'] as num).toDouble(),
        isPercentage: (line['isPercentage'] as int) == 1,
      ));
    }

    return orderLines;
  }

  Future<void> deleteOrder(int idOrder, dbClient) async {
    await dbClient.delete(
      'orders',
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<int> cancelOrder(int idOrder, dbClient) async {
    return await dbClient.update(
      'orders',
      {'status': 'Annulée'},
      where: 'id_order = ?',
      whereArgs: [idOrder],
    );
  }

  Future<void> updateOrderInDatabase(Order order, dbClient) async {
    try {
      await dbClient.update(
        'orders',
        {
          'remaining_amount': order.remainingAmount,
          'status': order.status,
          'global_discount': order.globalDiscount,
          'is_percentage_discount': order.isPercentageDiscount ? 1 : 0,
        },
        where: 'id_order = ?',
        whereArgs: [order.idOrder],
      );

      // Update order lines if needed
      await _updateOrderLines(order, dbClient);
    } catch (e) {
      print('Error updating order: $e');
      throw Exception('Error updating order');
    }
  }

  Future<void> _updateOrderLines(Order order, dbClient) async {
    // First delete existing order lines
    await dbClient.delete(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    // Then insert the updated ones
    for (final orderLine in order.orderLines) {
      await dbClient.insert(
        'order_items',
        {
          'id_order': order.idOrder,
          'product_code': orderLine.productCode,
          'product_id': orderLine.productId,
          'quantity': orderLine.quantity,
          'prix_unitaire': orderLine.prixUnitaire,
          'discount': orderLine.discount,
          'isPercentage': orderLine.isPercentage ? 1 : 0,
        },
      );
    }
  }

  Future<List<Order>> getOrders(dbClient) async {
    final orderMaps = await dbClient.query('orders');
    final orders = <Order>[];

    for (final orderMap in orderMaps) {
      final orderId = orderMap['id_order'] as int;
      final orderLinesData = await dbClient.query(
        'order_items',
        where: 'id_order = ?',
        whereArgs: [orderId],
      );

      final orderLines = await _buildOrderLines(dbClient, orderLinesData);

      orders.add(Order(
        date: orderMap['date'],
        total: (orderMap['total'] as num).toDouble(),
        modePaiement: orderMap['mode_paiement'] as String,
        status: orderMap['status'] as String,
        orderLines: orderLines,
        remainingAmount: (orderMap['remaining_amount'] as num).toDouble(),
        globalDiscount: (orderMap['global_discount'] as num).toDouble(),
        isPercentageDiscount: (orderMap['is_percentage_discount'] as int) == 1,
        idClient: orderMap['id_client'] as int?,
        userId: orderMap ['user_id'] as int?
      ));
    }

    return orders;
  }

  Future<void> debugCheckOrder(int orderId, dbClient) async {
    final order = await dbClient.query(
      'orders',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    
    if (order.isEmpty) {
      print('Order not found');
      return;
    }

    print('Order from DB: ${order.first}');

    if (order.first['id_client'] != null) {
      final client = await dbClient.query(
        'clients',
        where: 'id = ?',
        whereArgs: [order.first['id_client']],
      );
      print('Associated client: ${client.isNotEmpty ? client.first : 'None'}');
    }

    // Print order lines
    final orderLines = await dbClient.query(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    print('Order lines: $orderLines');
  }
}