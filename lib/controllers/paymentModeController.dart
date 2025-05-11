// import 'package:caissechicopets/models/paymentMode.dart';
// import 'package:sqflite/sqflite.dart';

// class PaymentModeController {
//   Future<int> addPaymentMode(PaymentMode paymentMode, Database dbClient) async {
//     return await dbClient.insert(
//       'payment_modes',
//       paymentMode.toMap(),
//       conflictAlgorithm: ConflictAlgorithm.fail,
//     );
//   }

//   Future<PaymentMode?> getPaymentModeById(int id, Database dbClient) async {
//     final List<Map<String, dynamic>> result = await dbClient.query(
//       'payment_modes',
//       where: 'id = ?',
//       whereArgs: [id],
//       limit: 1,
//     );
//     return result.isNotEmpty ? PaymentMode.fromMap(result.first) : null;
//   }

//   Future<List<PaymentMode>> getAllPaymentModes(Database dbClient) async {
//     final List<Map<String, dynamic>> result = 
//       await dbClient.query('payment_modes');
//     return result.map((map) => PaymentMode.fromMap(map)).toList();
//   }

//   Future<int> updatePaymentMode(
//       PaymentMode paymentMode, Database dbClient) async {
//     return await dbClient.update(
//       'payment_modes',
//       paymentMode.toMap(),
//       where: 'id = ?',
//       whereArgs: [paymentMode.id],
//     );
//   }

//   Future<int> deletePaymentMode(int id, Database dbClient) async {
//     return await dbClient.delete(
//       'payment_modes',
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//   }

//   // Custom method example: Get payment modes above certain amount
//   Future<List<PaymentMode>> getPaymentModesAboveAmount(
//       double minAmount, Database dbClient) async {
//     final List<Map<String, dynamic>> result = await dbClient.query(
//       'payment_modes',
//       where: 'amount > ?',
//       whereArgs: [minAmount],
//     );
//     return result.map((map) => PaymentMode.fromMap(map)).toList();
//   }

//   // Custom method example: Calculate total commissions
//   Future<double> getTotalCommissions(Database dbClient) async {
//     final result = await dbClient
//         .rawQuery('SELECT SUM(commission) AS total FROM payment_modes');
//     return result.first['total'] as double;
//   }
// }