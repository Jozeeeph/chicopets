import 'package:flutter/material.dart';
import 'package:caissechicopets/home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import sqflite_ffi

void main() async {
  // Initialize FFI for desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit(); // Initialize FFI
    databaseFactory = databaseFactoryFfi; // Set the database factory
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(), // Apply Poppins globally
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(), // Use the new home page as the initial page
    );
  }
}