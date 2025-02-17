import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Searchprod {
  
  static void showProductSearchPopup(BuildContext context) async {
    final SqlDb sqldb = SqlDb();
    final products = await sqldb.getProducts();
    final TextEditingController searchController = TextEditingController();
    ValueNotifier<List<Product>> filteredProducts = ValueNotifier(products);

    searchController.addListener(() {
      String query = searchController.text.toLowerCase();
      filteredProducts.value = products
          .where((product) =>
              (product.code.toLowerCase().contains(query)) ||
              (product.designation.toLowerCase().contains(query)) ||
              ((product.categoryName ?? '').toLowerCase().contains(query)))
          .toList();
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
              color: Color(0xFF0056A6) // Deep Blue
            ),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Recherche Produit',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0056A6)), // Deep Blue
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF26A9E0)), // Sky Blue
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF26A9E0), width: 2), // Sky Blue
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
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Désignation',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Catégorie',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Stock',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Prix HT',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Date Expiration',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
                                ),
                              ),
                            ],
                          ),
                          
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: currentProducts.length,
                            itemBuilder: (context, index) {
                              final product = currentProducts[index];

                              List<String> formattedDatePatterns = [
                                'yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy',
                                'yyyy/MM/dd', 'dd-MM-yyyy', 'MM-dd-yyyy'
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

                              return InkWell(
                                child: Container(
                                  color: index.isEven ? Color(0xFFE0E0E0) : Colors.white, // Light Gray and White alternation
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(product.code)),
                                      Expanded(child: Text(product.designation)),
                                      Expanded(child: Text(product.categoryName ?? 'Sans catégorie')),
                                      Expanded(child: Text('${product.stock}')),
                                      Expanded(child: Text('${product.prixHT} DT')),
                                      Expanded(child: Text(formattedDate)),
                                    ],
                                  ),
                                ),
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
                backgroundColor: Color(0xFFE53935), // Warm Red for cancel
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Fermer',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
