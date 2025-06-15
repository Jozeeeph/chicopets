import 'dart:convert';

import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class OrderController {
  Future<int> addOrder(Order order, dbClient) async {
    try {
      int orderId = await dbClient.insert(
        'orders',
        {
          'date': order.date,
          'total': order.total,
          'mode_paiement': order.modePaiement,
          'status': order.status,
          'remaining_amount': order.remainingAmount,
          'id_client': order.idClient,
          'user_id': order.userId,
          'global_discount': order.globalDiscount,
          'is_percentage_discount': order.isPercentageDiscount ? 1 : 0,
        },
      );

      // Insert order lines with product data
      for (var orderLine in order.orderLines) {
        // Get product data if product exists
        Map<String, dynamic>? productData;
        if (orderLine.productId != null) {
          final product = await dbClient.query(
            'products',
            where: 'id = ?',
            whereArgs: [orderLine.productId],
          );
          if (product.isNotEmpty) {
            productData = product.first;
          }
        }

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
            'variant_code': orderLine.variantCode,
            'variant_name': orderLine.variantName,
            'product_data':
                productData != null ? jsonEncode(productData) : null,
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

      // Debug print to verify data
      print('Order ID: $orderId, User ID: ${orderMap['user_id']}');

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
        userId: orderMap['user_id'] as int?, // Make sure this line is included
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
          variantCode: line['variant_code'] as String?,
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
        variantCode: line['variant_code'] as String?,
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

  Future<int> updateSynchOrder(int orderId, dbClient) async {
    return await dbClient.update(
      'orders',
      {'is_sync': 1}, // set to true (1)
      where: 'id_order = ?',
      whereArgs: [orderId], // assuming your Order has an `id` field
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
    debugPrint('''[updateOrderInDatabase] 
    Order ID: ${order.idOrder}
    Order toString: ${order.toString()}
    Stack trace: ${StackTrace.current}''');
    // Validate order ID exists
    if (order.idOrder == null) {
      throw ArgumentError('Order ID cannot be null when updating');
    }

    // Use transaction for atomic operations
    return await db.transaction((txn) async {
      // Update the order
      final updated = await txn.update(
        'orders',
        order.toMap(),
        where: 'id_order = ?',
        whereArgs: [order.idOrder],
      );

      if (updated == 0) {
        throw Exception('Order not found with ID: ${order.idOrder}');
      }

      // Update order items
      await _updateOrderItems(order, txn);

      return order.idOrder!;
    });
  }

  Future<void> _updateOrderItems(Order order, DatabaseExecutor db) async {
    print(
        'Updating items for order ${order.idOrder} with ${order.orderLines.length} items');
    // First delete existing order items
    await db.delete(
      'order_items',
      where: 'id_order = ?',
      whereArgs: [order.idOrder],
    );

    // Then insert the updated ones
    for (final orderLine in order.orderLines) {
      // Validate required fields
      if (orderLine.productCode == null && orderLine.productId == null) {
        throw ArgumentError(
            'Order line must have either productCode or productId');
      }

      await db.insert(
        'order_items',
        {
          'id_order': order.idOrder, // This should never be null here
          'product_code': orderLine.productCode,
          'product_name': orderLine.productName,
          'product_id': orderLine.productId,
          'variant_id': orderLine.variantId,
          'variant_code': orderLine.variantCode,
          'variant_name': orderLine.variantName,
          'quantity': orderLine.quantity, // Default if null
          'prix_unitaire': orderLine.prixUnitaire, // Default if null
          'discount': orderLine.discount, // Default if null
          'isPercentage': (orderLine.isPercentage) ? 1 : 0,
          'product_data': orderLine.productData != null
              ? jsonEncode(orderLine.productData)
              : null,
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
          isPercentageDiscount:
              (orderMap['is_percentage_discount'] as int) == 1,
          idClient: orderMap['id_client'] as int?,
          userId: orderMap['user_id'] as int?));
    }

    return orders;
  }

  Future<List<Order>> getOrdersToSynch(dbClient) async {
    final orderMaps = await dbClient.query(
      'orders',
      where: 'is_sync = ?',
      whereArgs: [0], // Only unsynced orders (false)
    );

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
        isSync: false, // Marked unsynced explicitly
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
