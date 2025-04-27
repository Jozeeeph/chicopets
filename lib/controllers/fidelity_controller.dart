import 'dart:math';

import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/models/fidelity_rules.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:sqflite/sqflite.dart';

class FidelityController {
  Future<FidelityRules> getFidelityRules(Database db) async {
  final List<Map<String, dynamic>> maps = 
      await db.query('fidelity_rules', limit: 1);
  
  if (maps.isEmpty) {
    // Créer des règles par défaut si la table est vide
    final defaultRules = FidelityRules();
    await db.insert('fidelity_rules', defaultRules.toMap());
    return defaultRules;
  }
  
  return FidelityRules.fromMap(maps.first);
}

 Future<int> updateFidelityRules(FidelityRules rules, Database db) async {
  // Vérifier d'abord si des règles existent
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM fidelity_rules')
  ) ?? 0;

  if (count == 0) {
    // Insérer si aucune règle n'existe
    return await db.insert('fidelity_rules', rules.toMap());
  } else {
    // Mettre à jour si des règles existent déjà
    return await db.update(
      'fidelity_rules',
      rules.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}

  Future<void> addPointsFromOrder(Order order, Database db) async {
    if (order.idClient == null) return;

    final rules = await getFidelityRules(db);

    // Récupérer le client directement depuis la base
    final clientMaps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [order.idClient],
      limit: 1,
    );

    if (clientMaps.isEmpty) return;

    // Calcul des points gagnés (sur le total AVANT remise)
    double orderTotal = order.orderLines
        .fold(0, (sum, line) => sum + (line.prixUnitaire * line.quantity));

    int pointsEarned = (orderTotal * rules.pointsPerDinar).round();

    if (pointsEarned <= 0) return;

    // Mise à jour du client
    await db.update(
      'clients',
      {
        'loyalty_points':
            (clientMaps.first['loyalty_points'] as int) + pointsEarned,
        'last_purchase_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [order.idClient],
    );
  }

  Future<bool> canUsePoints(
      Client client, double orderTotal, Database db) async {
    final rules = await getFidelityRules(db);

    // Vérifier si le client a assez de points
    if (client.loyaltyPoints < rules.minPointsToUse) {
      return false;
    }

    // Vérifier si les points sont expirés
    if (rules.pointsValidityMonths > 0 && client.lastPurchaseDate != null) {
      final expirationDate = client.lastPurchaseDate!.add(
        Duration(days: 30 * rules.pointsValidityMonths),
      );
      if (DateTime.now().isAfter(expirationDate)) {
        return false;
      }
    }

    return true;
  }

  Future<double> calculateMaxPointsUsage(
      Client client, double orderTotal, Database db) async {
    final rules = await getFidelityRules(db);

    // Calculer le maximum en points
    double maxPointsValue = orderTotal * (rules.maxPercentageUse / 100);
    double maxPoints = maxPointsValue / rules.dinarPerPoint;

    // Ne pas dépasser les points disponibles
    if (maxPoints > client.loyaltyPoints) {
      maxPoints = client.loyaltyPoints.toDouble();
    }

    return maxPoints;
  }

  Future<void> usePoints(Client client, int pointsUsed, Database db) async {
    if (pointsUsed <= 0) return;

    await db.update(
      'clients',
      {
        'loyalty_points': client.loyaltyPoints - pointsUsed,
        'last_purchase_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<void> cleanExpiredPoints(Database db) async {
    final rules = await getFidelityRules(db);
    if (rules.pointsValidityMonths == 0) return;

    final thresholdDate = DateTime.now().subtract(
      Duration(days: 30 * rules.pointsValidityMonths),
    );

    await db.update(
      'clients',
      {'loyalty_points': 0},
      where: 'last_purchase_date < ? AND loyalty_points > 0',
      whereArgs: [thresholdDate.toIso8601String()],
    );
  }

  Future<double> calculateMaxPointsDiscount(
      Client client, double orderTotal, Database db) async {
    final rules = await getFidelityRules(db);

    // Calculer la valeur max en dinars qu'on peut utiliser
    double maxDinars = orderTotal * (rules.maxPercentageUse / 100);

    // Convertir en points
    double maxPoints = maxDinars / rules.dinarPerPoint;

    // Ne pas dépasser les points disponibles
    if (maxPoints > client.loyaltyPoints) {
      maxPoints = client.loyaltyPoints.toDouble();
    }

    return maxPoints;
  }

  Future<void> applyPointsToOrder(
      Order order, Client client, int pointsUsed, Database db) async {
    final rules = await getFidelityRules(db);
    double discountAmount = pointsUsed * rules.dinarPerPoint;

    // Appliquer la réduction au total
    order.total = max(0, order.total - discountAmount);

    // Mettre à jour le statut si le total est complètement payé
    if (order.total <= 0) {
      order.status = "payée";
      order.remainingAmount = 0.0;
    }

    // Mettre à jour le client
    await usePoints(client, pointsUsed, db);

    // Ajouter les points gagnés sur cette commande
    await addPointsFromOrder(order, db);
  }
}
