import 'dart:math';

import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/fidelity_rules.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite/sqflite.dart';

class FidelityController {
  static const String _pointsTable = 'client_points';
  static const String _rulesTable = 'fidelity_rules';
  static const String _clientsTable = 'clients';

  Future<FidelityRules> getFidelityRules(Database db) async {
    try {
      final List<Map<String, dynamic>> maps =
          await db.query(_rulesTable, limit: 1);

      if (maps.isEmpty) {
        final defaultRules = FidelityRules();
        await db.insert(_rulesTable, defaultRules.toMap());
        return defaultRules;
      }

      return FidelityRules.fromMap(maps.first);
    } catch (e) {
      print('Error getting fidelity rules: $e');
      return FidelityRules(); // Return default rules on error
    }
  }

  Future<int> updateFidelityRules(FidelityRules rules, Database db) async {
    try {
      final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM $_rulesTable')) ??
          0;

      if (count == 0) {
        return await db.insert(_rulesTable, rules.toMap());
      } else {
        return await db.update(
          _rulesTable,
          rules.toMap(),
          where: 'id = ?',
          whereArgs: [1],
        );
      }
    } catch (e) {
      print('Error updating fidelity rules: $e');
      return 0;
    }
  }

  Future<void> addPointsToClient({
    required int clientId,
    required int points,
    required Database db,
    required int orderId,
    required String reason,
  }) async {
    try {
      await db.insert(_pointsTable, {
        'client_id': clientId,
        'points': points,
        'order_id': orderId,
        'reason': reason,
        'date_earned': DateTime.now().toIso8601String(),
        'expiry_date':
            DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'is_used': 0,
      });

      await db.rawUpdate('''
        UPDATE $_clientsTable 
        SET loyalty_points = loyalty_points + ? 
        WHERE id = ?
      ''', [points, clientId]);
    } catch (e) {
      print('Error adding points to client: $e');
      rethrow;
    }
  }

  Future<void> addPointsFromOrder(Order order, Database db) async {
    if (order.idClient == null) return;

    try {
      final rules = await getFidelityRules(db);
      final client = await _getClientById(order.idClient!, db);
      if (client == null) return;

      double orderTotal = order.orderLines
          .fold(0, (sum, line) => sum + (line.prixUnitaire * line.quantity));

      int pointsEarned = (orderTotal * rules.pointsPerDinar).round();
      if (pointsEarned <= 0) return;

      await db.update(
        _clientsTable,
        {
          'loyalty_points': client.loyaltyPoints + pointsEarned,
          'last_purchase_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [order.idClient],
      );
    } catch (e) {
      print('Error adding points from order: $e');
    }
  }

  Future<bool> canUsePoints(
      Client client, double orderTotal, Database db) async {
    try {
      final rules = await getFidelityRules(db);

      if (client.loyaltyPoints < rules.minPointsToUse) {
        return false;
      }

      if (rules.pointsValidityMonths > 0 && client.lastPurchaseDate != null) {
        final expirationDate = client.lastPurchaseDate!.add(
          Duration(days: 30 * rules.pointsValidityMonths),
        );
        if (DateTime.now().isAfter(expirationDate)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking if points can be used: $e');
      return false;
    }
  }

  Future<double> calculateMaxPointsUsage(
      Client client, double orderTotal, Database db) async {
    try {
      final rules = await getFidelityRules(db);
      double maxPointsValue = orderTotal * (rules.maxPercentageUse / 100);
      double maxPoints = maxPointsValue / rules.dinarPerPoint;

      return min(maxPoints, client.loyaltyPoints.toDouble());
    } catch (e) {
      print('Error calculating max points usage: $e');
      return 0.0;
    }
  }

  Future<int> calculateLoyaltyPoints({
    required OrderLine orderLine,
    required FidelityRules rules,
    required Database db,
  }) async {
    try {
      Product? product;

      // 1. Récupérer les informations du produit
      if (orderLine.productData != null) {
        product = Product.fromMap(orderLine.productData!);
      } else if (orderLine.productId != null) {
        product = await SqlDb().getProductById(orderLine.productId!);
      }

      // 2. Si le produit n'existe pas ou n'accumule pas de points, retourner 0
      if (product == null || !product.earnsFidelityPoints) {
        return 0;
      }

      // 3. Si le produit a des points prédéfinis, les utiliser
      if (product.fidelityPointsEarned != null &&
          product.fidelityPointsEarned! > 0) {
        return product.fidelityPointsEarned! * orderLine.quantity;
      }

      // 4. Sinon, calculer selon les règles de fidélité
      final points =
          (orderLine.finalPrice * orderLine.quantity * rules.pointsPerDinar)
              .round();
      return points > 0 ? points : 0;
    } catch (e) {
      print('Erreur dans le calcul des points de fidélité: $e');
      return 0;
    }
  }

  Future<void> usePoints(Client client, int pointsUsed, Database db) async {
    if (pointsUsed <= 0) return;

    try {
      await db.update(
        _clientsTable,
        {
          'loyalty_points': client.loyaltyPoints - pointsUsed,
          'last_purchase_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [client.id],
      );
    } catch (e) {
      print('Error using points: $e');
      rethrow;
    }
  }

  Future<void> cleanExpiredPoints(Database db) async {
    try {
      final rules = await getFidelityRules(db);
      if (rules.pointsValidityMonths == 0) return;

      final thresholdDate = DateTime.now().subtract(
        Duration(days: 30 * rules.pointsValidityMonths),
      );

      await db.update(
        _clientsTable,
        {'loyalty_points': 0},
        where: 'last_purchase_date < ? AND loyalty_points > 0',
        whereArgs: [thresholdDate.toIso8601String()],
      );
    } catch (e) {
      print('Error cleaning expired points: $e');
    }
  }

  Future<double> calculateMaxPointsDiscount(
      Client client, double orderTotal, Database db) async {
    try {
      final rules = await getFidelityRules(db);
      double maxDinars = orderTotal * (rules.maxPercentageUse / 100);
      double maxPoints = maxDinars / rules.dinarPerPoint;

      return min(maxPoints, client.loyaltyPoints.toDouble());
    } catch (e) {
      print('Error calculating max points discount: $e');
      return 0.0;
    }
  }

  Future<void> applyPointsToOrder(
      Order order, Client client, int pointsUsed, Database db) async {
    try {
      final rules = await getFidelityRules(db);
      double discountAmount = pointsUsed * rules.dinarPerPoint;

      order.total = max(0, order.total - discountAmount);

      if (order.total <= 0) {
        order.status = "payée";
        order.remainingAmount = 0.0;
      }

      await usePoints(client, pointsUsed, db);
      await addPointsFromOrder(order, db);
    } catch (e) {
      print('Error applying points to order: $e');
      rethrow;
    }
  }

  Future<Client?> _getClientById(int clientId, Database db) async {
    try {
      final clientMaps = await db.query(
        _clientsTable,
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );

      if (clientMaps.isEmpty) return null;
      return Client.fromMap(clientMaps.first);
    } catch (e) {
      print('Error getting client by ID: $e');
      return null;
    }
  }
}
