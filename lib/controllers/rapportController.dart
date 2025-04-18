class Rapportcontroller {
  Future<Map<String, Map<String, dynamic>>> getSalesByCategoryAndProduct({
    String? dateFilter,db
  }) async {

    final salesData = <String, Map<String, dynamic>>{};

    try {
      String query = '''
      SELECT 
        COALESCE(c.category_name, 'Uncategorized') AS category_name,
        p.designation AS product_name,
        SUM(oi.quantity) AS total_quantity,
        SUM(
          CASE 
            WHEN oi.isPercentage = 1 THEN 
              oi.quantity * (oi.prix_unitaire * (1 - oi.discount/100))
            ELSE 
              oi.quantity * (oi.prix_unitaire - oi.discount)
          END
        ) AS total_sales,
        MAX(oi.discount) AS discount,
        MAX(oi.isPercentage) AS is_percentage,
        MAX(oi.prix_unitaire) AS unit_price
      FROM 
        order_items oi
      JOIN 
        products p ON oi.product_code = p.code
      LEFT JOIN
        categories c ON p.category_id = c.id_category
      JOIN 
        orders o ON oi.id_order = o.id_order
      WHERE 
        o.status IN ('completed', 'paid', 'semi-payée')
        AND p.is_deleted = 0
    ''';

      if (dateFilter != null && dateFilter.isNotEmpty) {
        query += ' $dateFilter';
      }

      query += '''
      GROUP BY 
        COALESCE(c.category_name, 'Uncategorized'), 
        p.designation
      ORDER BY 
        category_name, total_sales DESC
    ''';

      final result = await db.rawQuery(query);
      print('Query executed. Result count: ${result.length}');

      for (final row in result) {
        final category = row['category_name']?.toString() ?? 'Uncategorized';
        final productName =
            row['product_name']?.toString() ?? 'Unknown Product';
        final quantity = row['total_quantity'] as int? ?? 0;
        final total = row['total_sales'] as double? ?? 0.0;
        final discount = row['discount'] as double? ?? 0.0;
        final isPercentage = (row['is_percentage'] as int?) == 1;
        final unitPrice = row['unit_price'] as double? ?? 0.0;

        print(
            'Processing: $category - $productName (Qty: $quantity, Total: $total)');

        salesData.putIfAbsent(
          category,
          () => {
            'products': <String, dynamic>{},
            'total': 0.0,
          },
        );

        salesData[category]!['products'][productName] = {
          'quantity': quantity,
          'total': total,
          'discount': discount,
          'isPercentage': isPercentage,
          'unitPrice': unitPrice,
        };

        salesData[category]!['total'] =
            (salesData[category]!['total'] as double) + total;
      }

      print('Final sales data: ${salesData.keys.toList()}');
      return salesData;
    } catch (e) {
      print('Error getting sales by category and product: $e');
      return {};
    }
  }
}
