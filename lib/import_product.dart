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

  // Variables d'état
  String _importStatus = 'Prêt ?'; // État initial
  int _importedProductsCount = 0; // Nombre de produits importés
  String _errorMessage = ''; // Message d'erreur
  bool _isImporting = false; // Indicateur d'importation en cours
  double _progress = 0.0; // Progression de l'importation

  // Fonction pour importer les produits
  Future<void> importProducts() async {
    setState(() {
      _importStatus = 'Importation en cours...';
      _importedProductsCount = 0;
      _errorMessage = '';
      _isImporting = true;
      _progress = 0.0;
    });

    try {
      // Sélection du fichier Excel
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String? filePath = file.path;

        var bytes = File(filePath!).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // Calcul du nombre total de lignes à importer
        int totalRows = excel.tables.values.fold(0, (sum, table) => sum + table.rows.length - 1);

        // Parcours des tables et des lignes du fichier Excel
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;

          for (var row in sheet.rows) {
            if (row == sheet.rows.first) continue; // Ignorer la première ligne (en-têtes)

            // Arrêter l'importation si l'utilisateur a interrompu
            if (!_isImporting) break;

            // Extraction des données de la ligne
            String code = row[0]?.value.toString() ?? '';
            String designation = row[1]?.value.toString() ?? '';
            int stock = int.tryParse(row[2]?.value.toString() ?? '0') ?? 0;
            double prixHT = double.tryParse(row[3]?.value.toString() ?? '0.0') ?? 0.0;
            double taxe = double.tryParse(row[4]?.value.toString() ?? '0.0') ?? 0.0;
            double prixTTC = double.tryParse(row[5]?.value.toString() ?? '0.0') ?? 0.0;
            String dateExpiration = row[6]?.value.toString() ?? '';
            String categoryName = row[7]?.value.toString() ?? '';
            String subCategoryName = row[8]?.value.toString() ?? '';
            String categoryImagePath = row[9]?.value.toString() ?? 'assets/images/default.jpg';

            // Gestion des catégories et sous-catégories
            int categoryId = await _getOrCreateCategoryIdByName(categoryName, categoryImagePath);
            int subCategoryId = await _getOrCreateSubCategoryIdByName(subCategoryName, categoryId);

            // Génération d'un ID unique pour le produit
            String generateProductReferenceId() {
              var uuid = Uuid();
              return uuid.v4(); // Génère un UUID de version 4 (aléatoire)
            }

            final productReferenceId = generateProductReferenceId();

            // Ajout du produit à la base de données
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
              productReferenceId,
            );

            // Mise à jour de la progression
            setState(() {
              _importedProductsCount++;
              _progress = _importedProductsCount / totalRows;
            });
          }
        }

        // Si l'importation est terminée avec succès
        if (_isImporting) {
          setState(() {
            _importStatus = 'Importation réussie!';
            _isImporting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importation réussie!')),
          );
        }
      }
    } catch (e) {
      // Gestion des erreurs
      setState(() {
        _importStatus = 'Erreur lors de l\'importation';
        _errorMessage = e.toString();
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'importation: $e')),
      );
    }
  }

  // Fonction pour obtenir ou créer une catégorie par son nom
  Future<int> _getOrCreateCategoryIdByName(String categoryName, String categoryImagePath) async {
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

  // Fonction pour obtenir ou créer une sous-catégorie par son nom
  Future<int> _getOrCreateSubCategoryIdByName(String subCategoryName, int categoryId) async {
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

  // Fonction pour confirmer l'interruption de l'importation
  void _confirmCancelImport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Interrompre l\'importation'),
          content: const Text('Êtes-vous sûr de vouloir interrompre l\'importation ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isImporting = false;
                });
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
        backgroundColor: const Color(0xFF0056A6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Importer des produits', style: TextStyle(color: Colors.white)),
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
              // Bouton pour importer un fichier Excel
              ElevatedButton.icon(
                onPressed: _isImporting ? null : importProducts,
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

              // Affichage de la progression
              if (_isImporting)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _confirmCancelImport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Interrompre l\'importation'),
                    ),
                  ],
                ),

              // Affichage du statut de l'importation
              Text(
                _importStatus,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),

              // Affichage du nombre de produits importés
              if (_importedProductsCount > 0)
                Text(
                  'Produits importés: $_importedProductsCount',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),

              // Affichage des erreurs
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