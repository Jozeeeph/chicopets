import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:sqflite/sqflite.dart';

class Clientcontroller {
  Future<int> addClient(Client client,dbClient) async {
    try {
      int id = await dbClient.insert(
        'clients',
        client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Client ajouté avec ID: $id'); // Debug
      return id;
    } catch (e) {
      print('Erreur lors de l\'ajout du client: $e');
      return -1; // Retourne -1 en cas d'erreur
    }
  }

  Future<List<Client>> getAllClients(dbClient) async {
    final List<Map<String, dynamic>> maps = await dbClient.query('clients');
    print('Clients from DB: $maps'); // Debug
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  Future<Client?> getClientById(int id,dbClient) async {
    final List<Map<String, dynamic>> result = await dbClient.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? Client.fromMap(result.first) : null;
  }

  Future<int> updateClient(Client client,dbClient) async {
    return await dbClient.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<int> deleteClient(int id,dbClient) async {
    return await dbClient.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Client>> searchClients(String query,dbClient) async {
    final List<Map<String, dynamic>> result = await dbClient.query(
      'clients',
      where: 'name LIKE ? OR first_name LIKE ? OR phone_number LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return result.map((map) => Client.fromMap(map)).toList();
  }

  Future<List<Order>> getClientOrders(int clientId, dbClient) async {
    final List<Map<String, dynamic>> orderMaps = await dbClient.query(
      'orders',
      where: 'id_client = ?',
      whereArgs: [clientId],
      orderBy: 'date DESC',
    );

    List<Order> orders = [];
    for (var orderMap in orderMaps) {
      int orderId = orderMap['id_order'];
      List<Map<String, dynamic>> itemMaps = await dbClient.query(
        'order_items',
        where: 'id_order = ?',
        whereArgs: [orderId],
      );

      List<OrderLine> orderLines = itemMaps.map((itemMap) {
        return OrderLine(
          idOrder: orderId,
          productCode: itemMap['product_code'],
          productId: itemMap['product_id'],
          quantity: itemMap['quantity'],
          prixUnitaire: itemMap['prix_unitaire'],
          discount: itemMap['discount'],
          isPercentage: itemMap['isPercentage'] == 1,
        );
      }).toList();

      orders.add(Order(
        idOrder: orderId,
        date: orderMap['date'],
        orderLines: orderLines,
        total: orderMap['total'],
        modePaiement: orderMap['mode_paiement'],
        status: orderMap['status'],
        remainingAmount: orderMap['remaining_amount'],
        globalDiscount: orderMap['global_discount'],
        isPercentageDiscount: orderMap['is_percentage_discount'] == 1,
        idClient: clientId,
      ));
    }

    return orders;
  }

  Future<void> addOrderToClient(int clientId, int orderId, dbClient) async {
    print('Adding order $orderId to client $clientId'); // Debug

    // Méthode 1: Mettre à jour la liste des commandes du client
    final client = await getClientById(clientId, dbClient);
    if (client != null) {
      client.idOrders.add(orderId);
      await dbClient.update(
        'clients',
        {'id_orders': client.idOrders.join(',')},
        where: 'id = ?',
        whereArgs: [clientId],
      );
      print('Updated client orders: ${client.idOrders}'); // Debug
    }

    // Méthode 2: Alternative plus simple
    await dbClient.update(
      'orders',
      {'id_client': clientId},
      where: 'id_order = ?',
      whereArgs: [orderId],
    );
    print('Updated order with client ID'); // Debug
  }
}
