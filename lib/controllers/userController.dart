import 'package:sqflite/sqflite.dart';
import 'package:caissechicopets/models/user.dart';

class UserController {
  Future<int> addUser(User user,dbClient) async {
    return await dbClient.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<User?> getUserByUsername(String username,dbClient) async {
    final List<Map<String, dynamic>> result = await dbClient.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<List<User>> getAllUsers(dbClient) async {
    final List<Map<String, dynamic>> result = await dbClient.query('users');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<bool> hasAdminAccount(dbClient) async {
    final count = Sqflite.firstIntValue(
      await dbClient
          .rawQuery('SELECT COUNT(*) FROM users WHERE role = "admin"'),
    );
    return count != null && count > 0;
  }

  Future<bool> verifyCode(String code,dbClient) async {
    final count = Sqflite.firstIntValue(
      await dbClient
          .rawQuery('SELECT COUNT(*) FROM users WHERE code = ?', [code]),
    );
    return count != null && count > 0;
  }

  Future<User?> getUserByCode(String code,dbClient) async {
    final List<Map<String, dynamic>> result = await dbClient.query(
      'users',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<int> updateUserCode(String username, String newCode,dbClient) async {
    return await dbClient.update(
      'users',
      {'code': newCode},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  Future<int> deleteUser(int userId,dbClient) async {
    return await dbClient.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
