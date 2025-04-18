class Orderlinecontroller {
  Future<void> cancelOrderLine(int idOrder, String idProduct, dbClient) async {
    await dbClient.delete(
      'order_items',
      where: 'id_order = ? AND product_code = ?',
      whereArgs: [idOrder, idProduct],
    );
  }

  Future<void> deleteOrderLine(int idOrder, String idProduct,dbClient) async {
    await dbClient.delete(
      'order_items',
      where: 'id_order = ? AND product_code = ?',
      whereArgs: [idOrder, idProduct],
    );
  }
}
