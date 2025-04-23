import 'package:sqflite/sqflite.dart';

// ignore: camel_case_types
class rapportController {
  Future<Map<String, Map<String, dynamic>>> getSalesByCategoryAndProduct({
    String? dateFilter,
    required Database db,
  }) async {
    final salesData = <String, Map<String, dynamic>>{};

    try {
      // 1. Check if variant_id column exists
      bool hasVariantColumn =
          await _checkColumnExists(db, 'order_items', 'variant_id');
      print('[DEBUG] order_items has variant_id column: $hasVariantColumn');

      // 2. Get orders with basic filter
      String orderQuery = '''
      SELECT 
        o.id_order,
        o.date
      FROM 
        orders o
      WHERE 
        o.total > 0
      ''';

      if (dateFilter != null && dateFilter.isNotEmpty) {
        orderQuery += ' AND $dateFilter';
      }

      print('[DEBUG] Order query: $orderQuery');
      final orders = await db.rawQuery(orderQuery);
      print('[DEBUG] Found ${orders.length} orders');

      if (orders.isEmpty) return {};

      // 3. Get order items - dynamic query based on schema
      final orderIds = orders.map((o) => o['id_order'].toString()).join(',');
      final orderItemsQuery = '''
      SELECT 
        oi.id_order,
        oi.product_code,
        oi.product_id,
        oi.quantity,
        oi.prix_unitaire,
        oi.discount,
        oi.isPercentage
        ${hasVariantColumn ? ', oi.variant_id' : ''}
      FROM 
        order_items oi
      WHERE 
        oi.id_order IN ($orderIds)
      ''';

      print('[DEBUG] Order items query: $orderItemsQuery');
      final orderItems = await db.rawQuery(orderItemsQuery);
      print('[DEBUG] Found ${orderItems.length} order items');

      if (orderItems.isEmpty) return {};

      // 4. Get product info - including variants if available
      final productCodes = orderItems
          .map((oi) => oi['product_code']?.toString())
          .where((code) => code != null && code.isNotEmpty)
          .toSet();

      final productIds = orderItems
          .map((oi) => oi['product_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      String productsQuery = '''
      SELECT 
        p.id,
        p.code,
        p.designation AS product_name,
        COALESCE(p.category_name, c.category_name, 'Uncategorized') AS category_name,
        p.has_variants
      FROM 
        products p
      LEFT JOIN
        categories c ON p.category_id = c.id_category
      WHERE 
        p.is_deleted = 0
        AND (
          ${productCodes.isNotEmpty ? "p.code IN (${productCodes.map((c) => "'$c'").join(',')})" : "1=0"}
          ${productIds.isNotEmpty ? "OR p.id IN (${productIds.join(',')})" : ""}
        )
      ''';

      print('[DEBUG] Products query: $productsQuery');
      final products = await db.rawQuery(productsQuery);
      print('[DEBUG] Found ${products.length} products');

      // 5. Create lookup maps
      final productCodeMap = <String, Map<String, dynamic>>{};
      final productIdMap = <int, Map<String, dynamic>>{};

      for (final p in products) {
        final id = p['id'] as int?;
        final code = p['code']?.toString();

        if (id != null) {
          productIdMap[id] = {
            'name': p['product_name']?.toString() ?? 'Unknown Product',
            'category': p['category_name']?.toString() ?? 'Uncategorized',
            'hasVariants': (p['has_variants'] as int?) == 1,
          };

          if (code != null) {
            productCodeMap[code] = productIdMap[id]!;
          }
        }
      }

      // 6. Process order items
      for (final oi in orderItems) {
        try {
          final productCode = oi['product_code']?.toString();
          final productId = oi['product_id'] as int?;

          Map<String, dynamic>? productInfo;

          // Lookup priority: product_id > product_code
          if (productId != null && productIdMap.containsKey(productId)) {
            productInfo = productIdMap[productId]!;
          } else if (productCode != null &&
              productCodeMap.containsKey(productCode)) {
            productInfo = productCodeMap[productCode]!;
          }

          if (productInfo == null) {
            print(
                '[WARNING] Missing product info for item: ${oi['id_order']}-${oi['product_code']}');
            continue;
          }

          final category = productInfo['category']!;
          final productName = productInfo['name']!;
          final quantity = oi['quantity'] as int? ?? 0;
          final unitPrice = oi['prix_unitaire'] as double? ?? 0.0;
          final discount = oi['discount'] as double? ?? 0.0;
          final isPercentage = (oi['isPercentage'] as int?) == 1;

          // Calculate total
          final total = isPercentage
              ? quantity * (unitPrice * (1 - discount / 100))
              : quantity * (unitPrice - discount);

          // Initialize data structures
          salesData.putIfAbsent(
            category,
            () => {'products': {}, 'total': 0.0},
          );

          salesData[category]!['products'].putIfAbsent(
            productName,
            () => {
              'quantity': 0,
              'total': 0.0,
              'discount': discount,
              'isPercentage': isPercentage,
              'unitPrice': unitPrice,
              'hasVariants': productInfo?['hasVariants'],
            },
          );

          // Update values
          final productData = salesData[category]!['products'][productName]!;
          productData['quantity'] += quantity;
          productData['total'] += total;
          salesData[category]!['total'] += total;
        } catch (e) {
          print('[ERROR] Processing order item failed: $e');
          continue;
        }
      }

      print(
          '[SUCCESS] Generated sales report with ${salesData.length} categories');
      return salesData;
    } catch (e, stackTrace) {
      print('[CRITICAL ERROR] Failed to generate sales report: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  Future<bool> _checkColumnExists(
      Database db, String table, String column) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      return columns.any((col) => col['name'] == column);
    } catch (e) {
      print('[WARNING] Could not check for column $column: $e');
      return false;
    }
  }
}
