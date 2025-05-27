import 'dart:convert';
import 'package:caissechicopets/models/stock.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/pos';
  static String? _token;
  static const String stockEndpoint = '/stocks/';

  final String? authToken;

  ApiService({this.authToken});

  // Initialize or get the token
  static Future<String?> getToken() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  // Set the token (call this after successful login)
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear the token (call this on logout)
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, dynamic>> sendProductsToDjango(
      List<Map<String, dynamic>> products) async {
    try {
      // Get the token
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Authentication token not available',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/product/import'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'products': products}),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'created_products': responseData['created_products'] ?? 0,
          'created_variants': responseData['created_variants'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    return {
      'Authorization': 'Token $authToken',
      'Content-Type': 'application/json',
    };
  }

  // In your ApiService.syncStock():
  Future<bool> syncStock(Stock stock) async {
    try {
      final jsonData = stock.toJson();

      print('Attempting to sync product ${stock.productId}');
      print('Request payload: ${jsonEncode(jsonData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/sync-stock'),
        body: jsonEncode(jsonData),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      print('API Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('Successfully synced ${stock.productId}');
        return true;
      } else {
        print('Failed to sync ${stock.productId}');
        return false;
      }
    } catch (e) {
      print('API Call Exception for ${stock.productId}: $e');
      return false;
    }
  }
}
