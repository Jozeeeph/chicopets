import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class ImportProductPage extends StatefulWidget {
  const ImportProductPage({super.key});

  @override
  _ImportProductPageState createState() => _ImportProductPageState();
}

class _ImportProductPageState extends State<ImportProductPage> {
  final SqlDb _sqlDb = SqlDb();
  String _importStatus = 'Prêt ?'; // État initial
  int _importedProductsCount = 0; // Nombre de produits importés
  String _errorMessage = ''; // Message d'erreur

  Future<void> importProducts() async {
    setState(() {
      _importStatus = 'Importation en cours...';
      _importedProductsCount = 0;
      _errorMessage = '';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String? filePath = file.path;

        var bytes = File(filePath!).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          for (var row in sheet.rows) {
            if (row == sheet.rows.first) continue;

            String code = row[0]?.value.toString() ?? '';
            String designation = row[1]?.value.toString() ?? '';
            int stock = int.tryParse(row[2]?.value.toString() ?? '0') ?? 0;
            double prixHT =
                double.tryParse(row[3]?.value.toString() ?? '0.0') ?? 0.0;
            double taxe =
                double.tryParse(row[4]?.value.toString() ?? '0.0') ?? 0.0;
            double prixTTC =
                double.tryParse(row[5]?.value.toString() ?? '0.0') ?? 0.0;
            String dateExpiration = row[6]?.value.toString() ?? '';
            String categoryName = row[7]?.value.toString() ?? '';
            String subCategoryName = row[8]?.value.toString() ?? '';
            String categoryImagePath =
                row[9]?.value.toString() ?? 'assets/images/default.jpg';

            int categoryId = await _getOrCreateCategoryIdByName(
                categoryName, categoryImagePath);
            int subCategoryId = await _getOrCreateSubCategoryIdByName(
                subCategoryName, categoryId);

            String generateProductReferenceId() {
              var uuid = Uuid();
              return uuid.v4(); // Génère un UUID de version 4 (aléatoire)
            }

            final productReferenceId = generateProductReferenceId();

            await _sqlDb.addProduct(
                code,
                designation,
                stock,
                prixHT,
                taxe,
                prixTTC,
                dateExpiration,
                categoryId,
                subCategoryId,
                prixTTC - prixHT,
                productReferenceId);

            setState(() {
              _importedProductsCount++;
            });
          }
        }

        setState(() {
          _importStatus = 'Importation réussie!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importation réussie!')),
        );
      }
    } catch (e) {
      setState(() {
        _importStatus = 'Erreur lors de l\'importation';
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'importation: $e')),
      );
    }
  }

  Future<int> _getOrCreateCategoryIdByName(
      String categoryName, String categoryImagePath) async {
    final dbClient = await _sqlDb.db;
    List<Map<String, dynamic>> result = await dbClient.query(
      'categories',
      where: 'category_name = ?',
      whereArgs: [categoryName],
    );

    if (result.isNotEmpty) {
      return result.first['id_category'];
    } else {
      int newCategoryId = await dbClient.insert(
        'categories',
        {'category_name': categoryName, 'image_path': categoryImagePath},
      );
      return newCategoryId;
    }
  }

  Future<int> _getOrCreateSubCategoryIdByName(
      String subCategoryName, int categoryId) async {
    final dbClient = await _sqlDb.db;
    List<Map<String, dynamic>> result = await dbClient.query(
      'sub_categories',
      where: 'sub_category_name = ? AND category_id = ?',
      whereArgs: [subCategoryName, categoryId],
    );

    if (result.isNotEmpty) {
      return result.first['id_sub_category'];
    } else {
      int newSubCategoryId = await dbClient.insert(
        'sub_categories',
        {'sub_category_name': subCategoryName, 'category_id': categoryId},
      );
      return newSubCategoryId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0056A6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Importer des produits',
            style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: importProducts,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: Text(
                  'Importer un fichier Excel',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _importStatus,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              if (_importedProductsCount > 0)
                Text(
                  'Produits importés: $_importedProductsCount',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              if (_errorMessage.isNotEmpty)
                Text(
                  'Erreur: $_errorMessage',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}