import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/variant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../product.dart';

class Searchprod {
  static void showProductSearchPopup(BuildContext context) async {
    final SqlDb sqldb = SqlDb();
    final products = await sqldb.getProducts();
    print("Fetched Products: $products"); // Debugging print

    final TextEditingController searchController = TextEditingController();
    ValueNotifier<List<Product>> filteredProducts = ValueNotifier(products);

    searchController.addListener(() {
      String query = searchController.text.toLowerCase();
      List<Product> newFilteredProducts = products.where((product) {
        String code = product.code.toLowerCase();
        String designation = product.designation.toLowerCase();
        String category = (product.categoryName ?? '').toLowerCase();

        return code.contains(query) ||
            designation.contains(query) ||
            category.contains(query);
      }).toList();

      filteredProducts.value = newFilteredProducts;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Liste des Produits',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF0056A6)),
          ),
          content: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Recherche Produit (code ou designation)',
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFF0056A6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF26A9E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF26A9E0), width: 2),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<List<Product>>(
                    valueListenable: filteredProducts,
                    builder: (context, currentProducts, child) {
                      return Column(
                        children: [
                          Row(
                            children: const [
                              Expanded(
                                child: Text(
                                  'Code',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0056A6)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Désignation',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0056A6)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Catégorie',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0056A6)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Stock',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0056A6)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Prix HT',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0056A6)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Date Expiration',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0056A6)),
                                ),
                              ),
                            ],
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: currentProducts.length,
                            itemBuilder: (context, index) {
                              final product = currentProducts[index];

                              Future<String> subCategoryNameFuture = product.subCategoryId != null
                                  ? sqldb
                                      .getSubCategoryById(product.subCategoryId, product.categoryId)
                                      .then((subCategoryResult) {
                                        return subCategoryResult.isNotEmpty
                                            ? subCategoryResult.first['sub_category_name'] ?? 'Sans sous-catégorie'
                                            : 'Sans sous-catégorie';
                                      })
                                  : Future.value('Sans sous-catégorie');

                              return FutureBuilder(
                                future: subCategoryNameFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return Center(child: Text('Erreur: ${snapshot.error}'));
                                  } else {
                                    String subCategoryName = snapshot.data as String;

                                    List<String> formattedDatePatterns = [
                                      'yyyy-MM-dd',
                                      'yyyy-dd-MM',
                                      'yyyy/dd/MM',
                                      'dd/MM/yyyy',
                                      'MM/dd/yyyy',
                                      'yyyy/MM/dd',
                                      'dd-MM-yyyy',
                                      'MM-dd-yyyy'
                                    ];

                                    String formattedDate = 'Invalid Date';
                                    if (product.dateExpiration.isNotEmpty) {
                                      for (var pattern in formattedDatePatterns) {
                                        try {
                                          DateTime parsedDate = DateFormat(pattern).parseStrict(product.dateExpiration);
                                          formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);
                                          break;
                                        } catch (e) {
                                          continue;
                                        }
                                      }
                                    }

                                    return ExpansionTile(
                                      title: Row(
                                        children: [
                                          Expanded(child: Text(product.code)),
                                          Expanded(child: Text(product.designation)),
                                          Expanded(child: Text('${product.categoryName} / $subCategoryName')),
                                          Expanded(child: Text('${product.stock}')),
                                          Expanded(child: Text('${product.prixHT} DT')),
                                          Expanded(child: Text(formattedDate)),
                                        ],
                                      ),
                                      children: [
                                        FutureBuilder<List<Variant>>(
                                          future: sqldb.getVariantsByProductCode(product.code),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return const Center(child: CircularProgressIndicator());
                                            } else if (snapshot.hasError) {
                                              return Center(child: Text('Erreur: ${snapshot.error}'));
                                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                              return const Center(child: Text('Aucune variante disponible'));
                                            } else {
                                              final variants = snapshot.data!;
                                              return DataTable(
                                                columns: const [
                                                  DataColumn(label: Text('Combinaison')),
                                                  DataColumn(label: Text('Prix')),
                                                  DataColumn(label: Text('Stock')),
                                                  DataColumn(label: Text('Code à barre')),
                                                ],
                                                rows: variants.map((variant) {
                                                  return DataRow(cells: [
                                                    DataCell(Text(variant.combinationName)),
                                                    DataCell(Text(variant.price.toString())),
                                                    DataCell(Text(variant.stock.toString())),
                                                    DataCell(Text(variant.code)),
                                                  ]);
                                                }).toList(),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Fermer',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}