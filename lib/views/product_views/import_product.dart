import 'dart:io';
import 'package:caissechicopets/models/attribute.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class ImportProductPage extends StatefulWidget {
  const ImportProductPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
  List<Map<String, dynamic>> productsJson = [];
  int _rejectedProductsCount = 0;
  final List<String> _rejectionReasons = [];

  Future<void> importProductsWithVariants() async {
    setState(() {
      _importStatus = 'Importing...';
      _importedProductsCount = 0;
      _importedVariantsCount = 0;
      _rejectedProductsCount = 0;
      _rejectionReasons.clear();
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

        var sheet = excel.tables.values.first;
        var headers = sheet.rows.first
            .map((cell) => cell?.value?.toString().trim())
            .toList();
        if (!_verifyHeaders(headers)) {
          throw Exception(
              'Invalid Excel format. Please use the correct template.');
        }

        Map<String, List<List<Data?>>> productGroups = {};
        for (var row in sheet.rows.skip(1)) {
          String productReference = row[3]?.value?.toString() ?? '';
          String productName = row[2]?.value?.toString() ?? '';

          if (productName.isEmpty) continue;

          String groupKey =
              productReference.isNotEmpty ? productReference : productName;
          productGroups.putIfAbsent(groupKey, () => []).add(row);
        }

        int totalProducts = productGroups.length;
        int processedProducts = 0;
        final db = await _sqlDb.db;

        for (var entry in productGroups.entries) {
          if (!_isImporting) break;

          String groupKey = entry.key;
          List<List<Data?>> rows = entry.value;

          try {
            var firstRow = rows.first;

            String imagePath = firstRow[1]?.value?.toString() ?? '';
            String productName = firstRow[2]?.value?.toString() ?? '';
            String reference = firstRow[3]?.value?.toString() ?? '';
            
            // Check for duplicate code if provided
            if (reference.isNotEmpty) {
              final codeExists = await _sqlDb.doesProductWithCodeExist(reference);
              if (codeExists) {
                setState(() {
                  _rejectedProductsCount++;
                  _rejectionReasons.add('Product "$productName" rejected: Duplicate code "$reference"');
                });
                processedProducts++;
                continue;
              }
            }
            
            // Check for duplicate designation
            final designationExists = await _sqlDb.doesProductWithDesignationExist(productName.toLowerCase());
            if (designationExists) {
              setState(() {
                _rejectedProductsCount++;
                _rejectionReasons.add('Product "$productName" rejected: Duplicate designation');
              });
              processedProducts++;
              continue;
            }

            String categoryName = (firstRow[4]?.value?.toString() ?? '').trim();
            String brand = (firstRow[5]?.value?.toString() ?? '').trim();
            String description = firstRow[6]?.value?.toString() ?? '';
            double costPrice =
                _parseDouble(firstRow[7]?.value?.toString() ?? '0');
            double prixHT = _parseDouble(firstRow[8]?.value?.toString() ?? '0');
            double taxe = _parseDouble(firstRow[9]?.value?.toString() ?? '0');
            double prixTTC =
                _parseDouble(firstRow[10]?.value?.toString() ?? '0');
            bool sellable =
                (firstRow[12]?.value?.toString() ?? 'TRUE').toUpperCase() ==
                    'TRUE';
            bool simpleProduct =
                (firstRow[13]?.value?.toString() ?? 'TRUE').toUpperCase() ==
                    'TRUE';

            if (productName.isEmpty) {
              setState(() {
                _rejectedProductsCount++;
                _rejectionReasons.add('Product group $groupKey rejected: Missing product name');
              });
              processedProducts++;
              continue;
            }

            if (categoryName.isEmpty) categoryName = 'Default';

            int categoryId = await _getOrCreateCategoryWithRetry(categoryName,
                imagePath: imagePath);
            int subCategoryId =
                await _getOrCreateSubCategoryWithRetry('Default', categoryId);

            // Create product with initial stock 0 (will be updated for variants)
            final product = Product(
              code: reference,
              designation: productName,
              description: description,
              stock: 0,
              prixHT: prixHT,
              taxe: taxe,
              prixTTC: prixTTC,
              dateExpiration: '',
              categoryId: categoryId,
              subCategoryId: subCategoryId,
              marge: (prixHT) - (costPrice),
              remiseMax: 0,
              remiseValeurMax: 0,
              hasVariants: !simpleProduct,
              sellable: sellable,
              brand: brand.isNotEmpty ? brand : null,
              image: imagePath.isNotEmpty ? imagePath : null,
              variants: [],
            );

            if (!simpleProduct) {
              List<Variant> allVariants = [];
              final attributesMap = <String, Set<String>>{};
              int totalVariantStock = 0;

              for (var row in rows) {
                String variantName = row[14]?.value?.toString() ?? '';
                bool defaultVariant =
                    (row[15]?.value?.toString() ?? 'FALSE').toUpperCase() ==
                        'TRUE';
                double priceImpact =
                    _parseDouble(row[17]?.value?.toString() ?? '0');
                int variantStock =
                    int.tryParse(row[18]?.value?.toString() ?? '0') ?? 0;

                totalVariantStock += variantStock;

                Map<String, String> attributes = {};
                if (variantName.contains('-')) {
                  List<String> attributePairs = variantName.split('-');
                  for (String pair in attributePairs) {
                    List<String> parts = pair.split(':');
                    if (parts.length == 2) {
                      final attrName = parts[0].trim();
                      final attrValue = parts[1].trim();
                      attributes[attrName] = attrValue;
                      attributesMap.putIfAbsent(attrName, () => <String>{});
                      attributesMap[attrName]!.add(attrValue);
                    }
                  }
                }

                final variant = Variant(
                  code: '',
                  combinationName: variantName,
                  price: prixHT + priceImpact,
                  priceImpact: priceImpact,
                  stock: variantStock,
                  defaultVariant: defaultVariant,
                  attributes: attributes,
                  productId: product.id ?? 0,
                );
                allVariants.add(variant);
              }

              // Update product with total variant stock before inserting
              product.id = await _sqlDb
                  .addProduct(product.copyWith(stock: totalVariantStock));

              for (final entry in attributesMap.entries) {
                final attribut = Attribut(
                  name: entry.key,
                  values: entry.value,
                );
                await _sqlDb.addAttribute(attribut);
              }

              for (var variant in allVariants) {
                variant.productId = product.id!;
                variant.id = await _sqlDb.addVariant(variant);
                product.variants.add(variant);
                setState(() {
                  _importedVariantsCount++;
                });
              }
            } else {
              // For simple products, use the quantity from the sheet
              int productStock =
                  int.tryParse(firstRow[11]?.value?.toString() ?? '0') ?? 0;
              product.id = await _sqlDb
                  .addProduct(product.copyWith(stock: productStock));
            }

            setState(() {
              _importedProductsCount++;
              processedProducts++;
              _progress = processedProducts / totalProducts;
            });
          } catch (e) {
            debugPrint('Error processing product group $groupKey: ${e.toString()}');
            setState(() {
              _rejectedProductsCount++;
              _rejectionReasons.add('Product group $groupKey rejected: ${e.toString()}');
            });
            processedProducts++;
            continue;
          }
        }

        if (_isImporting) {
          setState(() {
            _importStatus = 'Import completed';
            _isImporting = false;
          });

          _showImportSummary();
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


  void _showImportSummary() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Summary'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ Successfully imported:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('   - $_importedProductsCount products'),
                Text('   - $_importedVariantsCount variants'),
                SizedBox(height: 16),
                if (_rejectedProductsCount > 0) ...[
                  Text('❌ Rejected products: $_rejectedProductsCount',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  SizedBox(height: 8),
                  Text('Rejection reasons:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _rejectionReasons
                        .map((reason) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('- $reason'),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportExcelTemplate() async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Sheet1'];

      List<String> headers = [
        "ACTION",
        "IMAGE",
        "PRODUCTNAME",
        "REFERENCE",
        "CATEGORY",
        "BRAND",
        "DESCRIPTION",
        "COSTPRICE",
        "SELLPRICETAXEXCLUDE",
        "VAT",
        "SELLPRICETAXINCLUDE",
        "QUANTITY",
        "SELLABLE",
        "SIMPLEPRODUCT",
        "VARIANTNAME",
        "DEFAULTVARIANT",
        "VARIANTIMAGE",
        "IMPACTPRICE",
        "QUANTITYVARIANT"
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + i)}1'))
          ..value = headers[i]
          ..cellStyle = CellStyle(
            backgroundColorHex: "FF4472C4",
            fontColorHex: "FFFFFFFF",
            bold: true,
          );
      }

      sheet.appendRow([
        "CREATE",
        "product_image.jpg",
        "Example Simple Product",
        "PROD001",
        "Example Category",
        "Example Brand",
        "Product description",
        10.0,
        15.0,
        19.0,
        17.85,
        100,
        "TRUE",
        "TRUE",
        "",
        "",
        "",
        "",
        ""
      ]);

      sheet.appendRow([
        "CREATE",
        "product_with_variants.jpg",
        "Example Product with Variants",
        "PROD002",
        "Example Category",
        "Example Brand",
        "Product with variants description",
        10.0,
        15.0,
        19.0,
        17.85,
        0,
        "TRUE",
        "FALSE",
        "Color:Red-Size:L",
        "TRUE",
        "variant_red.jpg",
        2.0,
        50
      ]);

      sheet.appendRow([
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "Color:Blue-Size:M",
        "FALSE",
        "variant_blue.jpg",
        1.5,
        30
      ]);

      var instructionsSheet = excel['Instructions'];
      instructionsSheet.appendRow(["Import Instructions"]);
      instructionsSheet.appendRow([""]);
      instructionsSheet.appendRow(["1. Required Fields:"]);
      instructionsSheet
          .appendRow(["   - PRODUCTNAME: Product name (required)"]);
      instructionsSheet
          .appendRow(["   - CATEGORY: Product category (required)"]);
      instructionsSheet.appendRow(
          ["   - SELLPRICETAXEXCLUDE: Price without tax (required)"]);
      instructionsSheet.appendRow([""]);
      instructionsSheet.appendRow(["2. For products with variants:"]);
      instructionsSheet.appendRow(["   - Set SIMPLEPRODUCT to FALSE"]);
      instructionsSheet.appendRow(["   - Add one row per variant"]);
      instructionsSheet.appendRow(
          ["   - VARIANTNAME format: Attribute1:Value1-Attribute2:Value2"]);
      instructionsSheet.appendRow(
          ["   - Set DEFAULTVARIANT to TRUE for one variant per product"]);

      var fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }

      final filePath = '${directory.path}/product_import_template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template downloaded to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting template: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _verifyHeaders(List<String?> headers) {
    List<String> expectedHeaders = [
      "ACTION",
      "IMAGE",
      "PRODUCTNAME",
      "REFERENCE",
      "CATEGORY",
      "BRAND",
      "DESCRIPTION",
      "COSTPRICE",
      "SELLPRICETAXEXCLUDE",
      "VAT",
      "SELLPRICETAXINCLUDE",
      "QUANTITY",
      "SELLABLE",
      "SIMPLEPRODUCT",
      "VARIANTNAME",
      "DEFAULTVARIANT",
      "VARIANTIMAGE",
      "IMPACTPRICE",
      "QUANTITYVARIANT"
    ];

    if (headers.length < expectedHeaders.length) {
      return false;
    }

    for (int i = 0; i < expectedHeaders.length; i++) {
      if (headers[i]?.toUpperCase() != expectedHeaders[i].toUpperCase()) {
        return false;
      }
    }

    return true;
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
      var result = await txn.query(
        'categories',
        where: 'category_name = ? COLLATE NOCASE',
        whereArgs: [categoryName.trim()],
      );

      if (result.isNotEmpty) {
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
      var result = await txn.query(
        'sub_categories',
        where: 'sub_category_name = ? COLLATE NOCASE AND category_id = ?',
        whereArgs: [subCategoryName.trim(), categoryId],
      );

      if (result.isNotEmpty) {
        return result.first['id_sub_category'] as int;
      }

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
                          'Produit Importer/Exporter',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Importer des produits d'un fichier Excel ou télécharger le format",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: _isImporting
                                  ? null
                                  : importProductsWithVariants,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF009688),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 15),
                              ),
                              child: Text(
                                _isImporting
                                    ? "Entrain d'importer"
                                    : "Importer d'un fichier Excel",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _exportExcelTemplate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 15),
                              ),
                              child: Text(
                                'Télécharger le format',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
                    '${(_progress * 100).toStringAsFixed(1)}% Complet',
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
                  Text(
                    '$_importedVariantsCount variantes importées',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_rejectedProductsCount produits rejetés',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
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
                    child: const Text("annuler l'import"),
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