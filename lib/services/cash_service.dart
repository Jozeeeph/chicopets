// services/cash_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:caissechicopets/models/cash_state.dart';

class CashService {
  static const String _cashStateKey = 'cash_state';

  Future<void> saveCashState(CashState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cashStateKey, jsonEncode(state.toMap()));
  }

  Future<CashState?> getCashState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_cashStateKey);
    if (stateJson != null) {
      return CashState.fromMap(jsonDecode(stateJson));
    }
    return null;
  }

  Future<void> clearCashState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cashStateKey);
  }
}