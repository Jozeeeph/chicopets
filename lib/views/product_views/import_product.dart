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
  String _importStatus = 'Prêt à importer';
  int _importedProductsCount = 0;
  int _importedVariantsCount = 0;
  String _errorMessage = '';
  bool _isImporting = false;
  double _progress = 0.0;
  List<Map<String, dynamic>> productsJson = [];
  int _rejectedProductsCount = 0;
  final List<String> _rejectionReasons = [];
  DateTime? _importStartTime;
  Duration? _importDuration;

  // Colors
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  Future<void> importProductsWithVariants() async {
    _importStartTime = DateTime.now();
    setState(() {
      _importStatus = 'Importation en cours...';
      _importedProductsCount = 0;
      _importedVariantsCount = 0;
      _rejectedProductsCount = 0;
      _rejectionReasons.clear();
      _errorMessage = '';
      _isImporting = true;
      _progress = 0.0;
      _importDuration = null;
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

        var sheet = excel.tables.values.first;
        var headers = sheet.rows.first
            .map((cell) => cell?.value?.toString().trim())
            .toList();
        if (!_verifyHeaders(headers)) {
          throw Exception(
              'Format Excel invalide. Veuillez utiliser le bon modèle.');
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
              final codeExists =
                  await _sqlDb.doesProductWithCodeExist(reference);
              if (codeExists) {
                setState(() {
                  _rejectedProductsCount++;
                  _rejectionReasons.add(
                      'Produit "$productName" rejeté: Code dupliqué "$reference"');
                });
                processedProducts++;
                continue;
              }
            }

            // Check for duplicate designation
            final designationExists = await _sqlDb
                .doesProductWithDesignationExist(productName.toLowerCase());
            if (designationExists) {
              setState(() {
                _rejectedProductsCount++;
                _rejectionReasons.add(
                    'Produit "$productName" rejeté: Désignation dupliquée');
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
                _rejectionReasons.add(
                    'Groupe de produits $groupKey rejeté: Nom de produit manquant');
              });
              processedProducts++;
              continue;
            }

            if (categoryName.isEmpty) categoryName = 'Défaut';

            int categoryId = await _getOrCreateCategoryWithRetry(categoryName,
                imagePath: imagePath);
            int subCategoryId =
                await _getOrCreateSubCategoryWithRetry('Défaut', categoryId);

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
                String variantCode = row[16]?.value?.toString() ?? '';
                print("variaant coode : $variantCode");
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
                  code: variantCode,
                  combinationName: variantName,
                  price: prixHT + priceImpact,
                  priceImpact: priceImpact,
                  stock: variantStock,
                  defaultVariant: defaultVariant,
                  attributes: attributes,
                  productId: product.id ?? 0,
                );
                print("variant : $variant");
                allVariants.add(variant);
              }

              // Update product with total variant stock before inserting
              product.id = await _sqlDb.addProduct(product.copyWith(stock: totalVariantStock));

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
            debugPrint(
                'Erreur lors du traitement du groupe de produits $groupKey: ${e.toString()}');
            setState(() {
              _rejectedProductsCount++;
              _rejectionReasons
                  .add('Groupe de produits $groupKey rejeté: ${e.toString()}');
            });
            processedProducts++;
            continue;
          }
        }

        if (_isImporting) {
          _importDuration = DateTime.now().difference(_importStartTime!);
          setState(() {
            _importStatus = 'Importation terminée';
            _isImporting = false;
          });

          _showImportSummary();
        }
      }
    } catch (e) {
      setState(() {
        _importStatus = 'Échec de l\'importation';
        _errorMessage = e.toString();
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $_errorMessage'),
          backgroundColor: warmRed,
        ),
      );
    }
  }

  void _showImportSummary() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: SizedBox(
            width: 400, // 👈 largeur réduite
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Résumé de l\'importation',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: deepBlue,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: darkBlue),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: darkBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer, color: darkBlue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Durée: ${_importDuration?.inSeconds ?? 0} secondes',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: tealGreen, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Importés avec succès:',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 26, top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '   - $_importedProductsCount produits',
                                  style: GoogleFonts.poppins(
                                      color: Colors.black87),
                                ),
                                Text(
                                  '   - $_importedVariantsCount variantes',
                                  style: GoogleFonts.poppins(
                                      color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          if (_rejectedProductsCount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.error, color: warmRed, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Produits rejetés: $_rejectedProductsCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _rejectionReasons
                                      .map((reason) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4.0),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text('• ',
                                                    style: TextStyle(
                                                        color: Colors.black87)),
                                                Expanded(
                                                  child: Text(
                                                    reason,
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.black87,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        "Exemple de produit simple",
        "PROD001",
        "Exemple de catégorie",
        "Exemple de marque",
        "Description du produit",
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
        "Exemple de produit avec variantes",
        "PROD002",
        "Exemple de catégorie",
        "Exemple de marque",
        "Description du produit avec variantes",
        10.0,
        15.0,
        19.0,
        17.85,
        0,
        "TRUE",
        "FALSE",
        "Couleur:Rouge-Taille:L",
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
        "Couleur:Bleu-Taille:M",
        "FALSE",
        "variant_blue.jpg",
        1.5,
        30
      ]);

      var instructionsSheet = excel['Instructions'];
      instructionsSheet.appendRow(["Instructions d'importation"]);
      instructionsSheet.appendRow([""]);
      instructionsSheet.appendRow(["1. Champs obligatoires:"]);
      instructionsSheet
          .appendRow(["   - PRODUCTNAME: Nom du produit (obligatoire)"]);
      instructionsSheet
          .appendRow(["   - CATEGORY: Catégorie du produit (obligatoire)"]);
      instructionsSheet.appendRow(
          ["   - SELLPRICETAXEXCLUDE: Prix hors taxes (obligatoire)"]);
      instructionsSheet.appendRow([""]);
      instructionsSheet.appendRow(["2. Pour les produits avec variantes:"]);
      instructionsSheet.appendRow(["   - Mettre SIMPLEPRODUCT à FALSE"]);
      instructionsSheet.appendRow(["   - Ajouter une ligne par variante"]);
      instructionsSheet.appendRow(
          ["   - Format VARIANTNAME: Attribut1:Valeur1-Attribut2:Valeur2"]);
      instructionsSheet.appendRow(
          ["   - Mettre DEFAULTVARIANT à TRUE pour une variante par produit"]);

      var fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Échec de la génération du fichier Excel');
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception(
            'Impossible d\'accéder au répertoire de téléchargement');
      }

      final filePath = '${directory.path}/modele_import_produits.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modèle téléchargé dans: $filePath'),
            backgroundColor: tealGreen,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'exportation du modèle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur lors de l\'exportation du modèle: ${e.toString()}'),
            backgroundColor: warmRed,
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
      "VARIANTCODE",
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
              'Retour à la catégorie par défaut après $retryCount tentatives');
          return await _getOrCreateCategoryIdByName('Défaut',
              imagePath: imagePath);
        }
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
    return await _getOrCreateCategoryIdByName('Défaut', imagePath: imagePath);
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
              'Retour à la sous-catégorie par défaut après $retryCount tentatives');
          return await _getOrCreateSubCategoryIdByName('Défaut', categoryId);
        }
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
    return await _getOrCreateSubCategoryIdByName('Défaut', categoryId);
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [deepBlue, darkBlue],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Annuler l\'importation',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Êtes-vous sûr de vouloir annuler l\'importation?',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: lightGray,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Non',
                          style: GoogleFonts.poppins(
                            color: darkBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _isImporting = false);
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: warmRed,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Oui',
                          style: GoogleFonts.poppins(
                            color: white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer des Produits'),
        backgroundColor: deepBlue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [deepBlue, darkBlue],
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
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, lightGray],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                            'Importer/Exporter des Produits',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Importer des produits depuis un fichier Excel ou télécharger le modèle",
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
                                  backgroundColor: tealGreen,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  _isImporting
                                      ? "Importation en cours..."
                                      : "Importer depuis Excel",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: white,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _exportExcelTemplate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: softOrange,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Télécharger le modèle',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                    '${(_progress * 100).toStringAsFixed(1)}% Terminé',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_importedProductsCount produits importés',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_importedVariantsCount variantes importées',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_rejectedProductsCount produits rejetés',
                    style: GoogleFonts.poppins(
                      color: warmRed,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _confirmCancelImport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: warmRed,
                      side: BorderSide(color: warmRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Annuler l'importation",
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: warmRed,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Text(
                  _importStatus,
                  style: GoogleFonts.poppins(
                    color: white,
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
