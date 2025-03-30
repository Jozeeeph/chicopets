import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/variant.dart';
import 'package:sqflite/sqflite.dart';

class ImportProductPage extends StatefulWidget {
  const ImportProductPage({super.key});

  @override
  _ImportProductPageState createState() => _ImportProductPageState();
}

class _ImportProductPageState extends State<ImportProductPage> {
  final SqlDb _sqlDb = SqlDb();
  String _importStatus = 'Ready to import';
  int _importedProductsCount = 0;
  int _importedVariantsCount = 0;
  String _errorMessage = '';
  bool _isImporting = false;
  double _progress = 0.0;

  Future<void> importProductsWithVariants() async {
    setState(() {
      _importStatus = 'Importing...';
      _importedProductsCount = 0;
      _importedVariantsCount = 0;
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
          throw Exception('File path not available');
        }

        var bytes = File(filePath).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // Use the first sheet
        var sheet = excel.tables.values.first;
        if (sheet == null) {
          throw Exception('No sheet found in Excel file');
        }

        // Process each row (skip header)
        int totalRows = sheet.rows.length - 1;
        int processedRows = 0;

        for (var row in sheet.rows.skip(1)) {
          if (!_isImporting) break;

          try {
            // Parse product data with null checks
            String code = row[0]?.value?.toString() ?? '';
            String designation = row[1]?.value?.toString() ?? '';
            double prixHT = _parseDouble(row[2]?.value?.toString() ?? '0');
            double taxe = _parseDouble(row[3]?.value?.toString() ?? '0');
            String categoryName = (row[4]?.value?.toString() ?? '').trim();
            String subCategoryName = (row[5]?.value?.toString() ?? '').trim();
            String imagePath = row[6]?.value?.toString() ?? '';
            double marge = _parseDouble(row[7]?.value?.toString() ?? '0');
            double remiseMax = _parseDouble(row[8]?.value?.toString() ?? '0');
            bool hasVariants =
                (row[9]?.value?.toString() ?? 'false').toLowerCase() == 'true';

            // Validate required fields
            if (code.isEmpty || designation.isEmpty) {
              throw Exception('Missing required fields for product');
            }

            // Handle empty category names
            if (categoryName.isEmpty) categoryName = 'Default';
            if (subCategoryName.isEmpty) subCategoryName = 'Default';

            // Get or create category IDs with retry logic
            int categoryId = await _getOrCreateCategoryWithRetry(categoryName,
                imagePath: imagePath.isNotEmpty ? imagePath : null);
            int subCategoryId = await _getOrCreateSubCategoryWithRetry(
                subCategoryName, categoryId);

            // Calculate derived values
            double prixTTC = prixHT * (1 + marge / 100);
            double remiseValeurMax = (marge * remiseMax) / 100;

            // Create product
            final product = Product(
              code: code,
              designation: designation,
              stock: 0, // Will be set from variant or directly
              prixHT: prixHT,
              taxe: taxe,
              prixTTC: prixTTC,
              dateExpiration: '',
              categoryId: categoryId,
              subCategoryId: subCategoryId,
              marge: marge,
              remiseMax: remiseMax,
              remiseValeurMax: remiseValeurMax,
              hasVariants: hasVariants,
              variants: [],
            );

            // Handle variants if exists
            if (hasVariants) {
              String variantCode = row[10]?.value?.toString() ?? '';
              String attributesStr = row[11]?.value?.toString() ?? '';
              double variantPrice =
                  _parseDouble(row[12]?.value?.toString() ?? '0');
              double priceImpact =
                  _parseDouble(row[13]?.value?.toString() ?? '0');
              int variantStock =
                  int.tryParse(row[14]?.value?.toString() ?? '0') ?? 0;

              if (variantCode.isEmpty) {
                throw Exception('Variant code missing for product $code');
              }

              // Parse attributes
              Map<String, String> attributes = {};
              if (attributesStr.isNotEmpty) {
                attributesStr.split(',').forEach((attrPair) {
                  var parts = attrPair.split(':');
                  if (parts.length == 2) {
                    attributes[parts[0].trim()] = parts[1].trim();
                  }
                });
              }

              // Insert product first
              product.id = await _sqlDb.addProduct(product);

              // Create variant
              final variant = Variant(
                code: variantCode,
                combinationName: attributes.values.join('-'),
                price: variantPrice,
                priceImpact: priceImpact,
                stock: variantStock,
                attributes: attributes,
                productId: product.id!,
              );

              // Insert variant
              variant.id = await _sqlDb.addVariant(variant);
              product.variants.add(variant);

              setState(() {
                _importedVariantsCount++;
              });
            } else {
              // For non-variant products, use the stock value directly
              product.stock =
                  int.tryParse(row[14]?.value?.toString() ?? '0') ?? 0;
              product.id = await _sqlDb.addProduct(product);
            }

            setState(() {
              _importedProductsCount++;
              processedRows++;
              _progress = processedRows / totalRows;
            });
          } catch (e) {
            debugPrint(
                'Error processing row ${processedRows + 1}: ${e.toString()}');
            processedRows++;
            continue;
          }
        }

        if (_isImporting) {
          setState(() {
            _importStatus = 'Import successful!';
            _isImporting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Successfully imported $_importedProductsCount products and $_importedVariantsCount variants'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _importStatus = 'Import failed';
        _errorMessage = e.toString();
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<int> _getOrCreateCategoryWithRetry(String categoryName,
      {String? imagePath, int retryCount = 3}) async {
    int attempt = 0;
    while (attempt < retryCount) {
      try {
        return await _getOrCreateCategoryIdByName(categoryName,
            imagePath: imagePath);
      } catch (e) {
        attempt++;
        if (attempt >= retryCount) {
          debugPrint(
              'Falling back to default category after $retryCount attempts');
          return await _getOrCreateCategoryIdByName('Default',
              imagePath: imagePath);
        }
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
    return await _getOrCreateCategoryIdByName('Default', imagePath: imagePath);
  }

  Future<int> _getOrCreateSubCategoryWithRetry(
      String subCategoryName, int categoryId,
      {int retryCount = 3}) async {
    int attempt = 0;
    while (attempt < retryCount) {
      try {
        return await _getOrCreateSubCategoryIdByName(
            subCategoryName, categoryId);
      } catch (e) {
        attempt++;
        if (attempt >= retryCount) {
          debugPrint(
              'Falling back to default subcategory after $retryCount attempts');
          return await _getOrCreateSubCategoryIdByName('Default', categoryId);
        }
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
    return await _getOrCreateSubCategoryIdByName('Default', categoryId);
  }

  Future<int> _getOrCreateCategoryIdByName(String categoryName,
      {String? imagePath}) async {
    final db = await _sqlDb.db;

    return await db.transaction((txn) async {
      // Try to find existing category
      var result = await txn.query(
        'categories',
        where: 'category_name = ? COLLATE NOCASE',
        whereArgs: [categoryName.trim()],
      );

      if (result.isNotEmpty) {
        // Update image path if it's provided and different from existing
        if (imagePath != null &&
            imagePath.isNotEmpty &&
            result.first['image_path'] != imagePath) {
          await txn.update(
            'categories',
            {'image_path': imagePath},
            where: 'id_category = ?',
            whereArgs: [result.first['id_category']],
          );
        }
        return result.first['id_category'] as int;
      }

      // Create new category if not found
      return await txn.insert(
        'categories',
        {
          'category_name': categoryName.trim(),
          'image_path': imagePath?.isNotEmpty == true ? imagePath : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<int> _getOrCreateSubCategoryIdByName(
      String subCategoryName, int categoryId) async {
    final db = await _sqlDb.db;

    return await db.transaction((txn) async {
      // Try to find existing subcategory
      var result = await txn.query(
        'sub_categories',
        where: 'sub_category_name = ? COLLATE NOCASE AND category_id = ?',
        whereArgs: [subCategoryName.trim(), categoryId],
      );

      if (result.isNotEmpty) {
        return result.first['id_sub_category'] as int;
      }

      // Create new subcategory if not found
      return await txn.insert(
        'sub_categories',
        {
          'sub_category_name': subCategoryName.trim(),
          'category_id': categoryId,
          'parent_id': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  double _parseDouble(String value) {
    // Handle both comma and dot decimal separators
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  void _confirmCancelImport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Import'),
          content: const Text('Are you sure you want to cancel the import?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _isImporting = false);
                Navigator.of(context).pop();
              },
              child: const Text('Yes'),
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
        title: const Text('Import Products'),
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
                        const Icon(Icons.upload_file,
                            size: 50, color: Colors.blue),
                        const SizedBox(height: 20),
                        Text(
                          'Import Products with Variants',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Expected format: Code, Designation, PrixHT, Taxe, Category, SubCategory, ImagePath, Marge, RemiseMax, HasVariants, VariantCode, Attributes, VariantPrice, PriceImpact, VariantStock',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed:
                              _isImporting ? null : importProductsWithVariants,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009688),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          child: Text(
                            _isImporting ? 'Importing...' : 'Select File',
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
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}% completed',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_importedProductsCount products imported',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_importedVariantsCount variants imported',
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
                    child: const Text('Cancel Import'),
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
