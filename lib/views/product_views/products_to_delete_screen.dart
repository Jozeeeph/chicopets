import 'package:flutter/material.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/models/variant.dart';

class ProductsToDeleteScreen extends StatefulWidget {
  final List<String> productIdentifiers;
  final Function() onProductsDeleted;

  const ProductsToDeleteScreen({
    super.key,
    required this.productIdentifiers,
    required this.onProductsDeleted,
  });

  @override
  _ProductsToDeleteScreenState createState() => _ProductsToDeleteScreenState();
}

class _ProductsToDeleteScreenState extends State<ProductsToDeleteScreen> {
  final SqlDb sqldb = SqlDb();
  List<Product> _products = [];
  List<Product> _selectedProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Add palette colors as class fields inside _ProductsToDeleteScreenState
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      List<Product> products = [];
      for (var identifier in widget.productIdentifiers) {
        Product? product = await sqldb.getProductByCode(identifier);
        if (product == null) {
          product = await sqldb.getProductByDesignation(identifier);
        }
        if (product != null) {
          // Load variants for each product
          product.variants =
              await sqldb.getVariantsByProductId(product.id ?? 0);
          products.add(product);
        }
      }
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: $e')),
      );
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.designation.toLowerCase().contains(query) ||
            (product.code?.toLowerCase() ?? '').contains(query);
      }).toList();
    });
  }

  Future<void> _showVariantsPopup(Product product) async {
    List<Variant> selectedVariants = [];
    bool deleteProductAfter = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${product.designation} - Variantes'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ce produit a des variantes. Vous devez supprimer toutes ses variantes avant de pouvoir le supprimer.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Variantes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: product.variants.length,
                        itemBuilder: (context, index) {
                          final variant = product.variants[index];
                          final isSelected = selectedVariants.contains(variant);
                          return CheckboxListTile(
                            title: Text(
                              variant.combinationName,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              'Code: ${variant.code} | Stock: ${variant.stock}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedVariants.add(variant);
                                } else {
                                  selectedVariants.remove(variant);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: selectedVariants.length ==
                              product.variants.length,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedVariants = List.from(product.variants);
                              } else {
                                selectedVariants.clear();
                              }
                            });
                          },
                        ),
                        const Text('Sélectionner tout'),
                      ],
                    ),
                    if (selectedVariants.length == product.variants.length) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: deleteProductAfter,
                            onChanged: (value) {
                              setState(() {
                                deleteProductAfter = value ?? false;
                              });
                            },
                          ),
                          const Text('Supprimer le produit après'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: selectedVariants.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _deleteVariants(selectedVariants);
                          if (deleteProductAfter) {
                            await _deleteProducts([product]);
                          } else {
                            await _loadProducts(); // Refresh the list
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Supprimer les variantes sélectionnées'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteVariants(List<Variant> variants) async {
    try {
      for (var variant in variants) {
        await sqldb.deleteVariant(variant.id ?? 0);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("${variants.length} variante(s) supprimée(s) avec succès"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la suppression: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete({Product? singleProduct}) async {
    if (singleProduct != null &&
        singleProduct.hasVariants &&
        singleProduct.variants.isNotEmpty) {
      await _showVariantsPopup(singleProduct);
      return;
    }

    final TextEditingController confirmController = TextEditingController();
    bool isConfirmed = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 10),
                  const Text(
                    'Confirmation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    singleProduct != null
                        ? 'Tapez "confirmer" pour supprimer ce produit :'
                        : 'Tapez "confirmer" pour supprimer les produits sélectionnés :',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmController,
                    onChanged: (value) {
                      setState(() {
                        isConfirmed =
                            (value.toLowerCase().trim() == "confirmer");
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'confirmer',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isConfirmed
                      ? () async {
                          Navigator.of(context).pop();
                          if (singleProduct != null) {
                            await _deleteProducts([singleProduct]);
                          } else {
                            await _deleteProducts(_selectedProducts);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isConfirmed ? Colors.red : Colors.grey[400],
                  ),
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProducts(List<Product> products) async {
    try {
      for (var product in products) {
        // First delete all variants of the product
        if (product.hasVariants && product.variants.isNotEmpty) {
          for (var variant in product.variants) {
            await sqldb.deleteVariant(variant.id ?? 0);
          }
        }

        // Then delete the product itself by ID
        await sqldb.deleteProductById(product.id ?? 0);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("${products.length} produit(s) supprimé(s) avec succès"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _products.removeWhere((p) => products.any((dp) => dp.id == p.id));
        _filteredProducts
            .removeWhere((p) => products.any((dp) => dp.id == p.id));
        _selectedProducts
            .removeWhere((p) => products.any((dp) => dp.id == p.id));
      });

      if (_products.isEmpty) {
        widget.onProductsDeleted();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la suppression: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleProductSelection(Product product) {
    setState(() {
      if (_selectedProducts.contains(product)) {
        _selectedProducts.remove(product);
      } else {
        _selectedProducts.add(product);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedProducts.length == _filteredProducts.length) {
        _selectedProducts.clear();
      } else {
        _selectedProducts = List.from(_filteredProducts);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: deepBlue,
        title: const Text('Produits à supprimer'),
        actions: [
          if (_filteredProducts.isNotEmpty)
            IconButton(
              icon: Icon(
                _selectedProducts.length == _filteredProducts.length
                    ? Icons.deselect
                    : Icons.select_all,
                color: white,
              ),
              tooltip: _selectedProducts.length == _filteredProducts.length
                  ? 'Désélectionner tout'
                  : 'Tout sélectionner',
              onPressed: _toggleSelectAll,
            ),
          if (_selectedProducts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Supprimer la sélection',
              color: warmRed,
              onPressed: () => _confirmDelete(),
            ),
        ],
        elevation: 6,
        shadowColor: darkBlue.withOpacity(0.5),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher des produits',
                labelStyle: TextStyle(color: darkBlue),
                prefixIcon: Icon(Icons.search, color: deepBlue),
                filled: true,
                fillColor: lightGray,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: deepBlue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: lightGray),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              cursorColor: deepBlue,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun produit trouvé',
                          style: TextStyle(
                            color: darkBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final isSelected =
                              _selectedProducts.contains(product);
                          return Card(
                            color: white,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: tealGreen.withOpacity(0.3),
                            child: ListTile(
                              leading: Checkbox(
                                activeColor: tealGreen,
                                value: isSelected,
                                onChanged: (value) {
                                  _toggleProductSelection(product);
                                },
                              ),
                              title: Text(
                                product.designation,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.code != null
                                        ? 'Code: ${product.code}'
                                        : 'Pas de code',
                                    style: TextStyle(color: darkBlue),
                                  ),
                                  if (product.hasVariants)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${product.variants.length} variante(s)',
                                        style: TextStyle(
                                          color: softOrange,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                color: warmRed,
                                tooltip: 'Supprimer ce produit',
                                onPressed: () =>
                                    _confirmDelete(singleProduct: product),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
