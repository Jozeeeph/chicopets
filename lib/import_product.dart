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

        // First pass: group all rows by product code
        Map<String, List<List<Data?>>> productRows = {};
        for (var row in sheet.rows.skip(1)) {
          String code = row[0]?.value?.toString() ?? '';
          if (code.isNotEmpty) {
            productRows.putIfAbsent(code, () => []).add(row);
          }
        }

        // Process each product with all its variants
        int totalProducts = productRows.length;
        int processedProducts = 0;

        for (var entry in productRows.entries) {
          if (!_isImporting) break;

          String code = entry.key;
          List<List<Data?>> rows = entry.value;

          try {
            // Use first row for product details
            var firstRow = rows.first;

            String designation = firstRow[1]?.value?.toString() ?? '';
            double prixHT = _parseDouble(firstRow[2]?.value?.toString() ?? '0');
            double taxe = _parseDouble(firstRow[3]?.value?.toString() ?? '0');
            String categoryName = (firstRow[4]?.value?.toString() ?? '').trim();
            String subCategoryName =
                (firstRow[5]?.value?.toString() ?? '').trim();
            String imagePath = firstRow[6]?.value?.toString() ?? '';
            double marge = _parseDouble(firstRow[7]?.value?.toString() ?? '0');
            double remiseMax =
                _parseDouble(firstRow[8]?.value?.toString() ?? '0');
            bool hasVariants =
                (firstRow[9]?.value?.toString() ?? 'false').toLowerCase() ==
                    'true';

            // Validate required fields
            if (designation.isEmpty) {
              throw Exception('Missing designation for product $code');
            }

            // Handle empty category names
            if (categoryName.isEmpty) categoryName = 'Default';
            if (subCategoryName.isEmpty) subCategoryName = 'Default';

            // Get or create category IDs
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
              // Collect all variants from all rows for this product
              List<Variant> allVariants = [];

              for (var row in rows) {
                String variantCodesStr = row[10]?.value?.toString() ?? '';
                String attributesStr = row[11]?.value?.toString() ?? '';
                double variantPrice =
                    _parseDouble(row[12]?.value?.toString() ?? '0');
                double priceImpact =
                    _parseDouble(row[13]?.value?.toString() ?? '0');
                int variantStock =
                    int.tryParse(row[14]?.value?.toString() ?? '0') ?? 0;

                if (variantCodesStr.isEmpty || attributesStr.isEmpty) {
                  throw Exception(
                      'Missing variant codes or attributes for product $code');
                }

                // Parse variant codes (comma-separated)
                List<String> variantCodes =
                    variantCodesStr.split(',').map((v) => v.trim()).toList();

                // Parse attributes
                Map<String, List<String>> attributeValues = {};
                if (attributesStr.isNotEmpty) {
                  List<String> attributePairs = attributesStr.split('/');
                  for (String pair in attributePairs) {
                    List<String> parts = pair.split(':');
                    if (parts.length == 2) {
                      String attributeName = parts[0].trim();
                      List<String> values =
                          parts[1].split(',').map((v) => v.trim()).toList();
                      attributeValues[attributeName] = values;
                    }
                  }
                }

                // Generate all combinations of attributes
                List<Map<String, String>> variantsAttributes =
                    _generateAttributeCombinations(attributeValues);

                // Verify we have matching counts
                if (variantCodes.length != variantsAttributes.length) {
                  throw Exception(
                      'Number of variant codes (${variantCodes.length}) does not match number of attribute combinations (${variantsAttributes.length}) for product $code');
                }

                // Create variants for this row
                for (int i = 0; i < variantsAttributes.length; i++) {
                  final variant = Variant(
                    code: variantCodes[i],
                    combinationName: variantsAttributes[i]
                        .entries
                        .map((e) => '${e.key}:${e.value}')
                        .join(' - '),
                    price: variantPrice,
                    priceImpact: priceImpact,
                    stock: variantStock,
                    attributes: variantsAttributes[i],
                    productId:
                        product.id ?? 0, // Will be set after product insert
                  );
                  allVariants.add(variant);
                }
              }

              // Insert product first
              product.id = await _sqlDb.addProduct(product);

              // Then insert all variants
              for (var variant in allVariants) {
                variant.productId = product.id!;
                variant.id = await _sqlDb.addVariant(variant);
                product.variants.add(variant);
                setState(() {
                  _importedVariantsCount++;
                });
              }
            } else {
              // For non-variant products, use the stock value from first row
              product.stock =
                  int.tryParse(firstRow[14]?.value?.toString() ?? '0') ?? 0;
              product.id = await _sqlDb.addProduct(product);
            }

            setState(() {
              _importedProductsCount++;
              processedProducts++;
              _progress = processedProducts / totalProducts;
            });
          } catch (e) {
            debugPrint('Error processing product $code: ${e.toString()}');
            processedProducts++;
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

  // Helper function to generate all combinations of attributes
  List<Map<String, String>> _generateAttributeCombinations(
      Map<String, List<String>> attributeValues) {
    List<Map<String, String>> combinations = [{}];

    attributeValues.forEach((attribute, values) {
      List<Map<String, String>> newCombinations = [];

      for (var combination in combinations) {
        for (var value in values) {
          var newCombination = Map<String, String>.from(combination);
          newCombination[attribute] = value;
          newCombinations.add(newCombination);
        }
      }

      combinations = newCombinations;
    });

    print("Generated combinations: $combinations"); // Ajout du log

    return combinations;
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
                          'Expected format: Code, Designation, PrixHT, Taxe, Category, SubCategory, ImagePath, Marge, RemiseMax, HasVariants, VariantCodes, Attributes, VariantPrice, PriceImpact, VariantStock',
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
