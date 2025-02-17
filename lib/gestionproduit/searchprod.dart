import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Searchprod {
  
  static void showProductSearchPopup(BuildContext context) async {
  final SqlDb sqldb = SqlDb();
  final products = await sqldb.getProducts(); // Fetch products from the database
  final TextEditingController searchController = TextEditingController();
  ValueNotifier<List<Product>> filteredProducts = ValueNotifier(products);

  // Filtering logic for search
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
          borderRadius: BorderRadius.circular(12), // Rounded corners
        ),
        title: const Text(
          'Liste des Produits',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: SizedBox(
          width: 600, // Set the popup width
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Search Bar with Styling
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Recherche Produit',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // Product Table
                ValueListenableBuilder<List<Product>>(
                  valueListenable: filteredProducts,
                  builder: (context, currentProducts, child) {
                    return Column(
                      children: [
                        // Header Row (only once)
                        Row(
                          children: const [
                            Expanded(
                              child: Text('Code',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Text('Désignation',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Text('Catégorie',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Text('Stock',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Text('Prix HT',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Text('Date Expiration',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        // Product Data Rows
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: currentProducts.length,
                          itemBuilder: (context, index) {
                            final product = currentProducts[index];

                            // Date format handling
                            List<String> formattedDatePatterns = [
                              'yyyy-MM-dd',
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
                                  // Try parsing the date with the current pattern
                                  DateTime parsedDate =
                                      DateFormat(pattern).parseStrict(product.dateExpiration);
                                  // Format it in 'dd/MM/yyyy'
                                  formattedDate =
                                      DateFormat('dd/MM/yyyy').format(parsedDate);
                                  break;
                                } catch (e) {
                                  continue;
                                }
                              }
                            }

                            return InkWell(
                              child: Container(
                                color: index.isEven ? Colors.grey.shade200 : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
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
        // Popup Buttons
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close popup
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Red for cancel
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Fermer',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}
}