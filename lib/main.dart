import 'dart:convert';
import 'package:caissechicopets/gestioncommande/addorder.dart';
import 'package:caissechicopets/gestioncommande/getorderlist.dart';
import 'package:caissechicopets/views/cashdesk_views/cash_desk_page.dart';
import 'package:caissechicopets/views/dashboard_views/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/home_page.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize database
  final sqlDb = SqlDb();
  await sqlDb.initDb();

  // Check for existing user session
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('current_user');
  User? currentUser;

  if (userJson != null) {
    currentUser = User.fromMap(jsonDecode(userJson));
  }

  runApp(MyApp(currentUser: currentUser));
}

class MyApp extends StatelessWidget {
  final User? currentUser;

  const MyApp({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: Addorder.scaffoldMessengerKey, // Use Addorder's key
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: currentUser != null
          ? currentUser!.role == 'admin'
              ? const DashboardPage()
              : const CashDeskPage()
          : const HomePage(),
    );
  }
}
