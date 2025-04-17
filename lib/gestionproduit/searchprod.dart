import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:caissechicopets/sqldb.dart';
import '../product.dart';

class Searchprod {
  static void showProductSearchPopup(BuildContext context) async {
    final SqlDb sqldb = SqlDb();
    final categories = await sqldb.getCategories();
    final TextEditingController searchController = TextEditingController();
    ValueNotifier<List<Product>> filteredProducts = ValueNotifier([]);

    Future<void> searchProducts(String? selectedCategory, {bool lowStock = false}) async {
      filteredProducts.notifyListeners(); // Met à jour l'état du chargement

      List<Product> results = await sqldb.searchProducts(
        category: selectedCategory,
        query: searchController.text,
        lowStock: lowStock,
      );
      filteredProducts.value = results;

      filteredProducts.notifyListeners();
    }

    Future<void> scanBarcode() async {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Annuler", true, ScanMode.BARCODE);

      if (barcodeScanRes != "-1") {
        searchController.text = barcodeScanRes;
        searchProducts(null); // Pass null to reset category
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? selectedCategory;
            bool showLowStock = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Recherche Avancée',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF0056A6)),
              ),
              content: SizedBox(
                width: 800,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Champ de recherche avec scanner
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: 'Recherche Produit (code ou désignation)',
                              prefixIcon: const Icon(Icons.search,
                                  color: Color(0xFF0056A6)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0056A6), width: 1)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0056A6), width: 2)),
                            ),
                            onChanged: (value) => searchProducts(selectedCategory),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Colors.blue, size: 32),
                          onPressed: scanBarcode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Filtres de recherche (catégorie + stock faible)
                    Row(
                      children: [
                        // Sélecteur de catégorie
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0056A6), width: 1)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0056A6), width: 2)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            hint: const Text("Sélectionner une catégorie"),
                            value: selectedCategory,
                            items: categories.map((category) {
                              return DropdownMenuItem(
                                value: category.id.toString(),
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                              searchProducts(selectedCategory, lowStock: showLowStock);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        // Bouton pour les produits en rupture de stock
                        ElevatedButton.icon(
                          icon: const Icon(Icons.warning, color: Colors.white),
                          label: const Text('Stock < 10'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showLowStock ? Colors.orange : Colors.grey,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                          ),
                          ),
                          onPressed: () {
                            setState(() {
                              showLowStock = !showLowStock;
                            });
                            searchProducts(selectedCategory, lowStock: showLowStock);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // Affichage des résultats dans un tableau défilable
                    Expanded(
                      child: ValueListenableBuilder<List<Product>>(
                        valueListenable: filteredProducts,
                        builder: (context, currentProducts, child) {
                          return currentProducts.isEmpty
                              ? const Text("Aucun produit trouvé",
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w500))
                              : Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection:
                                        Axis.horizontal, // Défilement horizontal
                                    child: SingleChildScrollView(
                                      scrollDirection:
                                          Axis.vertical, // Défilement vertical
                                      child: DataTable(
                                        columnSpacing: 20,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        columns: const [
                                          DataColumn(
                                              label: Text('Désignation',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold))),
                                          DataColumn(
                                              label: Text('Code',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold))),
                                          DataColumn(
                                              label: Text('Stock',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold))),
                                          DataColumn(
                                              label: Text('Prix TTC',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold))),
                                          DataColumn(
                                              label: Text('Date Expiration',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold))),
                                        ],
                                        rows: currentProducts.map((product) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(product.designation)),
                                              DataCell(Text(product.code ?? '')),
                                              DataCell(Text(
                                                  product.stock.toString(),
                                                  style: TextStyle(
                                                    color: product.stock < 10 
                                                        ? Colors.red 
                                                        : Colors.black,
                                                    fontWeight: product.stock < 10
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ))),
                                              DataCell(Text(
                                                  "${product.prixTTC.toStringAsFixed(2)} TND")),
                                              DataCell(Text(
                                                  product.dateExpiration ?? "N/A")),
                                            ],
                                            color: MaterialStateProperty.resolveWith<
                                                Color>((states) {
                                              // Alternating row colors
                                              return currentProducts.indexOf(product) %
                                                          2 ==
                                                      0
                                                  ? Colors.grey.shade50
                                                  : Colors.white;
                                            }),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // Bouton Réinitialiser (bleu)
                TextButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      selectedCategory = null; // Reset selected category
                      showLowStock = false; // Reset low stock filter
                    });
                    filteredProducts.value = [];
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF0056A6), // Couleur bleue
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      const Text('Réinitialiser', style: TextStyle(fontSize: 16)),
                ),

                // Bouton Fermer (rouge)
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Couleur rouge
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      },
    );
  }
}