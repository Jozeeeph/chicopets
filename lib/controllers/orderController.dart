import 'dart:convert';

import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/paymentDetails.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:sqflite/sqflite.dart';

class OrderController {
  Future<int> addOrder(Order order, dbClient) async {
    try {
      // First insert the order with payment details
      int orderId = await dbClient.insert(
        'orders',
        order.toMap(), // Use the Order's toMap method which includes payment details
      );

      // Insert order lines with product data
      for (var orderLine in order.orderLines) {
        await dbClient.insert(
          'order_items',
          {
            'id_order': orderId,
            'product_code': orderLine.productCode,
            'product_id': orderLine.productId,
            'product_name': orderLine.productName,
            'quantity': orderLine.quantity,
            'prix_unitaire': orderLine.prixUnitaire,
            'discount': orderLine.discount,
            'isPercentage': orderLine.isPercentage ? 1 : 0,
            'variant_id': orderLine.variantId,
            'variant_name': orderLine.variantName,
            'product_data': orderLine.productData != null 
                ? jsonEncode(orderLine.productData) 
                : null,
          },
        );
      }

      return orderId;
    } catch (e) {
      print('Error in addOrder: $e');
      rethrow;
    }
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

      // Create PaymentDetails from the order map
      final paymentDetails = PaymentDetails.fromMap(orderMap);

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
        userId: orderMap['user_id'] as int?,
        paymentDetails: paymentDetails, // Add payment details
      ));
    }

    return orders;
  }

  Future<List<OrderLine>> _buildOrderLines(
      dbClient, List<Map<String, dynamic>> orderLinesData) async {
    final orderLines = <OrderLine>[];

    for (final line in orderLinesData) {
      // Try to use product_data first if available
      if (line['product_data'] != null) {
        final productData = jsonDecode(line['product_data'] as String);
        orderLines.add(OrderLine(
          idOrder: line['id_order'] as int,
          productCode: line['product_code']?.toString() ?? productData['code'],
          productName:
              line['product_name']?.toString() ?? productData['designation'],
          productId: line['product_id'] as int?,
          variantId: line['variant_id'] as int?,
          variantName: line['variant_name'] as String?,
          quantity: line['quantity'] as int,
          prixUnitaire: (line['prix_unitaire'] as num).toDouble(),
          discount: (line['discount'] as num).toDouble(),
          isPercentage: (line['isPercentage'] as int) == 1,
          productData: productData,
        ));
        continue;
      }

      // Fallback to querying product if product_data not available
      Product? product;
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
        productName: line['product_name']?.toString() ?? product?.designation,
        productId: line['product_id'] as int?,
        variantId: line['variant_id'] as int?,
        variantName: line['variant_name'] as String?,
        quantity: line['quantity'] as int,
        prixUnitaire: (line['prix_unitaire'] as num).toDouble(),
        discount: (line['discount'] as num).toDouble(),
        isPercentage: (line['isPercentage'] as int) == 1,
        productData: product?.toMap(),
      ));
    }

    return orderLines;
  }

  Future<int> deleteOrder(int orderId, dbClient) async {
    // First delete all order items
    await dbClient.delete(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );

    // Then delete the order itself
    return await dbClient.delete(
      'orders',
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> updateOrderTotal(int orderId, double newTotal, dbClient) async {
    return await dbClient.update(
      'orders',
      {'total': newTotal},
      where: 'id_order = ?',
      whereArgs: [orderId],
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

    Future<int> updateOrderInDatabase(Order order, Database db) async {
    // First update the order itself including payment details
    await db.update(
      'orders',
      order.toMap(), // Use the Order's toMap method which includes payment details
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    // Then update the order items
    await _updateOrderItems(order, db);

    return order.idOrder!;
  }

  Future<void> _updateOrderItems(Order order, Database db) async {
    // First delete existing order items
    await db.delete(
      'order_items', // Matches your schema
      where: 'id_order = ?', // Matches your schema
      whereArgs: [order.idOrder],
    );

    // Then insert the updated ones
    for (final orderLine in order.orderLines) {
      await db.insert(
        'order_items', // Matches your schema
        {
          'id_order': order.idOrder,
          'product_code': orderLine.productCode,
          'product_name': orderLine.productName,
          'product_id': orderLine.productId,
          'variant_id': orderLine.variantId,
          'variant_code': orderLine.variantCode,
          'variant_name': orderLine.variantName,
          'quantity': orderLine.quantity,
          'prix_unitaire': orderLine.prixUnitaire,
          'discount': orderLine.discount,
          'isPercentage': orderLine.isPercentage ? 1 : 0, // Matches your schema
          'product_data': orderLine.productData != null
              ? jsonEncode(orderLine.productData)
              : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
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
    
    // Create PaymentDetails from the order map
    final paymentDetails = PaymentDetails.fromMap(orderMap);

    orders.add(Order(
      idOrder: orderId,
      date: orderMap['date'] as String,
      total: (orderMap['total'] as num).toDouble(),
      modePaiement: orderMap['mode_paiement'] as String,
      status: orderMap['status'] as String,
      orderLines: orderLines,
      remainingAmount: (orderMap['remaining_amount'] as num).toDouble(),
      globalDiscount: (orderMap['global_discount'] as num).toDouble(),
      isPercentageDiscount: (orderMap['is_percentage_discount'] as int) == 1,
      idClient: orderMap['id_client'] as int?,
      userId: orderMap['user_id'] as int?,
      paymentDetails: paymentDetails, // Add payment details here
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
