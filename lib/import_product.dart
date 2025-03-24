import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caissechicopets/product.dart';

class ImportProductPage extends StatefulWidget {
  const ImportProductPage({super.key});

  @override
  _ImportProductPageState createState() => _ImportProductPageState();
}

class _ImportProductPageState extends State<ImportProductPage> {
  final SqlDb _sqlDb = SqlDb();
  String _importStatus = 'Prêt à importer';
  int _importedProductsCount = 0;
  String _errorMessage = '';
  bool _isImporting = false;
  double _progress = 0.0;
  Future<void> importProducts() async {
    setState(() {
      _importStatus = 'Importation en cours...';
      _importedProductsCount = 0;
      _errorMessage = '';
      _isImporting = true;
      _progress = 0.0;
    });

    try {

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        String? filePath = file.path;

        if (filePath == null) {
          throw Exception('Chemin du fichier non disponible');
        }

        var bytes = File(filePath).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        int totalRows = excel.tables.values.fold(
            0, (sum, table) => sum + table.rows.length - 1);
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          
          // Vérifier que le fichier a le bon format
          if (sheet.rows.isEmpty || sheet.rows.first.length < 9) {
            throw Exception('Format de fichier incorrect. Vérifiez les colonnes.');
          }

          for (var row in sheet.rows) {
            if (row == sheet.rows.first) continue;

            if (!_isImporting) break;

            try {
              String code = row[0]?.value?.toString() ?? '';
              String designation = row[1]?.value?.toString() ?? '';
              int stock = int.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
              double prixHT = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0.0;
              double taxe = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0;
              double prixTTC = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0.0;
              String dateExpiration = row[6]?.value?.toString() ?? '';
              String categoryName = row[7]?.value?.toString() ?? '';
              String subCategoryName = row[8]?.value?.toString() ?? '';

              // Validation des données obligatoires
              if (code.isEmpty || designation.isEmpty) {
                throw Exception('Code et désignation sont obligatoires');
              }

              int categoryId = await _getOrCreateCategoryIdByName(categoryName);
              int subCategoryId = await _getOrCreateSubCategoryIdByName(
                  subCategoryName, categoryId);

              // Création de l'objet Product
              final product = Product(
                code: code,
                designation: designation,
                stock: stock,
                prixHT: prixHT,
                taxe: taxe,
                prixTTC: prixTTC,
                dateExpiration: dateExpiration,
                categoryId: categoryId,
                subCategoryId: subCategoryId,
                marge: prixTTC - prixHT,
                remiseMax: 0.0,
                remiseValeurMax: 0.0,
              );

              // Insertion du produit
              await _sqlDb.addProduct(product);

              setState(() {
                _importedProductsCount++;
                _progress = _importedProductsCount / totalRows;
              });
            } catch (e) {
              debugPrint('Erreur lors du traitement de la ligne: $e');
              continue; // Passe à la ligne suivante en cas d'erreur
            }
          }
        }

        if (_isImporting) {
          setState(() {
            _importStatus = 'Importation réussie!';
            _isImporting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_importedProductsCount produits importés avec succès'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } 
    catch (e) {
      setState(() {
        _importStatus = 'Erreur lors de l\'importation';
        _errorMessage = e.toString();
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<int> _getOrCreateCategoryIdByName(String categoryName) async {
    final dbClient = await _sqlDb.db;
    List<Map<String, dynamic>> result = await dbClient.query(
      'categories',
      where: 'category_name = ?',
      whereArgs: [categoryName],
    );

    if (result.isNotEmpty) {
      return result.first['id_category'] as int;
    } else {
      return await dbClient.insert(
        'categories',
        {'category_name': categoryName},
      );

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
      return result.first['id_sub_category'] as int;
    } else {
      return await dbClient.insert(
        'sub_categories',
        {
          'sub_category_name': subCategoryName,
          'category_id': categoryId,
        },
      );

    }
  }
  
  void _confirmCancelImport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Interrompre l\'importation'),
          content: const Text('Êtes-vous sûr de vouloir interrompre l\'importation ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _isImporting = false);
                Navigator.of(context).pop();
              },
              child: const Text('Oui'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer des produits'),
        backgroundColor: const Color(0xFF0056A6),

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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.upload_file, size: 50, color: Colors.blue),
                        const SizedBox(height: 20),
                        Text(
                          'Importer des produits depuis Excel',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Format attendu: Code, Désignation, Stock, Prix HT, Taxe, Prix TTC, Date Expiration, Catégorie, Sous-catégorie',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isImporting ? null : importProducts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009688),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          child: Text(
                            _isImporting ? 'Importation en cours...' : 'Sélectionner un fichier',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (_isImporting) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}% complété',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_importedProductsCount produits importés',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _confirmCancelImport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Annuler l\'importation'),
                  ),
                ],
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Text(
                  _importStatus,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,

                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}