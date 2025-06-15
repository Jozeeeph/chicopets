import 'package:caissechicopets/models/variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:caissechicopets/services/sqldb.dart';
import '../../models/product.dart';

class Searchprod {
  static void showProductSearchPopup(BuildContext context,
      {required Function(Product, [Variant?]) onProductSelected}) async {
    final SqlDb sqldb = SqlDb();
    final categories = await sqldb.getCategories();
    final TextEditingController searchController = TextEditingController();
    ValueNotifier<List<Product>> filteredProducts = ValueNotifier([]);
    final Map<int, bool> expandedProducts = {};

    Future<void> searchProducts(String? selectedCategory,
        {bool lowStock = false}) async {
      List<Product> results = await sqldb.searchProducts(
        category: selectedCategory,
        query: searchController.text,
        lowStock: lowStock,
      );

      // Charger les variantes pour chaque produit
      for (var product in results) {
        if (product.id != null) {
          product.variants = await sqldb.getVariantsByProductId(product.id!);
          expandedProducts[product.id!] = false;
        }
      }

      filteredProducts.value = results;
    }

    Future<void> scanBarcode() async {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          "#0056A6", "Annuler", true, ScanMode.BARCODE);

      if (barcodeScanRes != "-1") {
        searchController.text = barcodeScanRes;
        searchProducts(null);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? selectedCategory;
            bool showLowStock = false;

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recherche Produits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0056A6),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),

                    // Search Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: 'Rechercher...',
                              hintText: 'Code, désignation ou référence',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                            ),
                            onChanged: (value) =>
                                searchProducts(selectedCategory),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0056A6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.qr_code_scanner,
                                color: Colors.white, size: 20),
                            onPressed: scanBarcode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filters Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Category Dropdown
                        SizedBox(
                          width: 300,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Catégorie',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            value: selectedCategory,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Toutes catégories'),
                              ),
                              ...categories.map((category) {
                                return DropdownMenuItem(
                                  value: category.id.toString(),
                                  child: Text(
                                    category.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                              searchProducts(selectedCategory,
                                  lowStock: showLowStock);
                            },
                          ),
                        ),

                        // Low Stock Filter
                        FilterChip(
                          label: const Text('Stock <10'),
                          selected: showLowStock,
                          onSelected: (selected) {
                            setState(() {
                              showLowStock = selected;
                            });
                            searchProducts(selectedCategory,
                                lowStock: showLowStock);
                          },
                          selectedColor: Colors.orange[100],
                          checkmarkColor: Colors.orange,
                          labelStyle: TextStyle(
                            color: showLowStock
                                // ignore: dead_code
                                ? Colors.orange[800]
                                : Colors.grey[700],
                          ),
                          avatar: showLowStock
                              // ignore: dead_code
                              ? const Icon(Icons.warning,
                                  size: 16, color: Colors.orange)
                              : null,
                        ),

                        // Reset Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Réinitialiser'),
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              selectedCategory = null;
                              showLowStock = false;
                            });
                            filteredProducts.value = [];
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Results
                    Expanded(
                      child: ValueListenableBuilder<List<Product>>(
                        valueListenable: filteredProducts,
                        builder: (context, products, child) {
                          if (products.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 40, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Aucun produit trouvé',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final hasVariants = product.variants.isNotEmpty;
                              final isExpanded =
                                  expandedProducts[product.id] ?? false;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    // Ligne principale du produit
                                    ListTile(
                                      title: Text(
                                        product.designation,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(product.code ?? ''),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${product.prixTTC.toStringAsFixed(2)} TND',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (hasVariants)
                                            IconButton(
                                              icon: Icon(
                                                isExpanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                color: const Color(0xFF0056A6),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  expandedProducts[product
                                                      .id!] = !isExpanded;
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                      onTap: () {
                                        if (!hasVariants) {
                                          onProductSelected(product);
                                          Navigator.pop(context);
                                        } else {
                                          setState(() {
                                            expandedProducts[product.id!] =
                                                !isExpanded;
                                          });
                                        }
                                      },
                                    ),

                                    // Affichage des variantes si développé
                                    if (hasVariants && isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 16, right: 16, bottom: 8),
                                        child: Column(
                                          children:
                                              product.variants.map((variant) {
                                            return ListTile(
                                              contentPadding:
                                                  const EdgeInsets.only(
                                                      left: 32),
                                              title: Text(
                                                variant.combinationName,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              subtitle:
                                                  Text('Code: ${variant.code}'),
                                              trailing: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${variant.finalPrice.toStringAsFixed(2)} TND',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Text(
                                                    'Stock: ${variant.stock}',
                                                    style: TextStyle(
                                                      color: variant.stock < 10
                                                          ? Colors.red
                                                          : Colors.green,
                                                      fontWeight:
                                                          variant.stock < 10
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap: () {
                                                onProductSelected(
                                                    product, variant);
                                                Navigator.pop(context);
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
