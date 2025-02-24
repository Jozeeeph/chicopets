import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';

class ImportProductPage extends StatefulWidget {
  const ImportProductPage({super.key});

  @override
  _ImportProductPageState createState() => _ImportProductPageState();
}

class _ImportProductPageState extends State<ImportProductPage> {
  final SqlDb _sqlDb = SqlDb();

  Future<void> importProducts() async {
    try {
      // Sélectionner le fichier Excel
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String? filePath = file.path;

        if (filePath != null) {
          // Lire le fichier Excel
          var bytes = File(filePath).readAsBytesSync();
          var excel = Excel.decodeBytes(bytes);

          // Parcourir les feuilles du fichier Excel
          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table]!;
            for (var row in sheet.rows) {
              // Ignorer la première ligne (en-têtes)
              if (row == sheet.rows.first) continue;

              // Parser les données de la ligne
              String code = row[0]?.value.toString() ?? '';
              String designation = row[1]?.value.toString() ?? '';
              int stock = int.tryParse(row[2]?.value.toString() ?? '0') ?? 0;
              double prixHT = double.tryParse(row[3]?.value.toString() ?? '0.0') ?? 0.0;
              double taxe = double.tryParse(row[4]?.value.toString() ?? '0.0') ?? 0.0;
              double prixTTC = double.tryParse(row[5]?.value.toString() ?? '0.0') ?? 0.0;
              String dateExpiration = row[6]?.value.toString() ?? '';
              String categoryName = row[7]?.value.toString() ?? '';
              String subCategoryName = row[8]?.value.toString() ?? '';

              // Récupérer les IDs de catégorie et sous-catégorie
              int categoryId = await _getCategoryIdByName(categoryName);
              int subCategoryId = await _getSubCategoryIdByName(subCategoryName, categoryId);

              // Ajouter le produit à la base de données
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
              );
            }
          }

          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importation réussie!')),
          );
        }
      }
    } catch (e) {
      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'importation: $e')),
      );
    }
  }

  Future<int> _getCategoryIdByName(String categoryName) async {
    final dbClient = await _sqlDb.db;
    List<Map<String, dynamic>> result = await dbClient.query(
      'categories',
      where: 'category_name = ?',
      whereArgs: [categoryName],
    );
    if (result.isNotEmpty) {
      return result.first['id_category'];
    } else {
      // Si la catégorie n'existe pas, vous pouvez choisir de la créer ou de retourner une valeur par défaut
      return 0; // ou créer la catégorie et retourner son ID
    }
  }

  Future<int> _getSubCategoryIdByName(String subCategoryName, int categoryId) async {
    final dbClient = await _sqlDb.db;
    List<Map<String, dynamic>> result = await dbClient.query(
      'sub_categories',
      where: 'sub_category_name = ? AND category_id = ?',
      whereArgs: [subCategoryName, categoryId],
    );
    if (result.isNotEmpty) {
      return result.first['id_sub_category'];
    } else {
      // Si la sous-catégorie n'existe pas, vous pouvez choisir de la créer ou de retourner une valeur par défaut
      return 0; // ou créer la sous-catégorie et retourner son ID
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer des produits'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: importProducts,
          child: const Text('Importer un fichier Excel'),
        ),
      ),
    );
  }
}