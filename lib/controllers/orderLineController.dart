class Orderlinecontroller {
  Future<void> cancelOrderLine(int idOrder, String idProduct, dbClient) async {
    await dbClient.delete(
      'order_items',
      where: 'id_order = ? AND product_code = ?',
      whereArgs: [idOrder, idProduct],
    );
  }

  Future<void> deleteOrderLine(
      int idOrder, String idProduct, int? variantId, dbClient) async {
    if (variantId != null) {
      // Delete variant order line
      await dbClient.delete(
        'order_items',
        where:
            'id_order = ? AND (product_code = ? OR product_id = ?) AND variant_id = ?',
        whereArgs: [idOrder, idProduct, idProduct, variantId],
      );
    } else {
      // Delete regular product order line
      await dbClient.delete(
        'order_items',
        where:
            'id_order = ? AND (product_code = ? OR product_id = ?) AND variant_id IS NULL',
        whereArgs: [idOrder, idProduct, idProduct],
      );
    }
  }
}
