import 'package:caissechicopets/views/product_views/editProduct.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/views/product_views/add_product_screen.dart';
import 'package:caissechicopets/models/product.dart';

class ManageProductPage extends StatefulWidget {
  const ManageProductPage({super.key});

  @override
  _ManageProductPageState createState() => _ManageProductPageState();
}

class _ManageProductPageState extends State<ManageProductPage> {
  final SqlDb sqldb = SqlDb();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  List<Product> _selectedProducts = [];
  final Map<int, bool> _expandedProducts = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    List<Product> products = await sqldb.getProducts();

    // Load variants for each product
    for (var product in products) {
      if (product.id != null) {
        product.variants = await sqldb.getVariantsByProductId(product.id!);
      }
    }

    setState(() {
      _products = products;
      _filteredProducts = products;
      // Initialize expanded state for each product
      for (var product in products) {
        _expandedProducts[product.id ?? 0] = false;
      }
    });
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        return (product.code?.toLowerCase() ?? '').contains(query) ||
            product.designation.toLowerCase().contains(query) ||
            (product.categoryName ?? '').toLowerCase().contains(query);
      }).toList();
    });
  }



  Future<void> _confirmDelete({Product? singleProduct}) async {
    TextEditingController confirmController = TextEditingController();
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
    for (var product in products) {
      await sqldb.deleteProductById(product.id ?? 0);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${products.length} produits supprimés avec succès"),
        backgroundColor: Colors.green,
      ),
    );
    _selectedProducts.clear();
    _loadProducts(); // Recharge directement la liste des produits
  }



  void _toggleSelectAll() {
    setState(() {
      if (_selectedProducts.length == _filteredProducts.length) {
        _selectedProducts.clear(); // Désélectionner tout
      } else {
        _selectedProducts = List.from(_filteredProducts); // Sélectionner tout
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Produits'),
        backgroundColor: const Color(0xFF0056A6),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProductScreen(
                    refreshData: _loadProducts,
                  ),
                ),
              );
            },
          ),
          if (_filteredProducts.isNotEmpty)
            IconButton(
              icon: Icon(
                _selectedProducts.length == _filteredProducts.length
                    ? Icons.deselect
                    : Icons.select_all,
                color: Colors.white,
              ),
              onPressed: _toggleSelectAll,
            ),
          if (_selectedProducts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher...',
                  hintText: 'Code, désignation ou catégorie',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF0056A6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductTable(context), // <== CONTEXT ajouté ici
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2,
              size: 60, color: const Color(0xFF0056A6).withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0056A6),
            ),
          ),
        ],
      ),
    );
  }

// ==> CONTEXT passé en paramètre ici aussi
  Widget _buildProductTable(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // En-têtes du tableau sous forme de ligne (optionnel)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0056A6).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 40), // Espace pour la checkbox
                  Expanded(
                      flex: 2, child: Text('Code', style: _headerTextStyle())),
                  Expanded(
                      flex: 3,
                      child: Text('Désignation', style: _headerTextStyle())),
                  Expanded(
                      flex: 2, child: Text('Stock', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Prix HT', style: _headerTextStyle())),
                  Expanded(
                      flex: 2, child: Text('TVA', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Prix TTC', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Variantes', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Actions', style: _headerTextStyle())),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Contenu sous forme de cartes
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final isSelected = _selectedProducts.contains(product);
                final totalStock = product.variants.isNotEmpty
                    ? product.variants
                        .fold(0, (sum, variant) => sum + variant.stock)
                    : product.stock;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProducts.remove(product);
                        } else {
                          _selectedProducts.add(product);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected != null) {
                                  if (selected) {
                                    _selectedProducts.add(product);
                                  } else {
                                    _selectedProducts.remove(product);
                                  }
                                }
                              });
                            },
                          ),
                          Expanded(
                              flex: 2,
                              child: Text(product.code ?? '',
                                  style: _cellTextStyle())),
                          Expanded(
                              flex: 3,
                              child: Text(product.designation,
                                  style: _cellTextStyle())),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '$totalStock',
                              style: _cellTextStyle().copyWith(
                                color: totalStock <= 0
                                    ? const Color(0xFFE53935)
                                    : totalStock < 5
                                        ? const Color(0xFFFF9800)
                                        : const Color(0xFF009688),
                              ),
                            ),
                          ),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  '${product.prixHT.toStringAsFixed(2)} DT',
                                  style: _cellTextStyle())),
                          Expanded(
                              flex: 2,
                              child: Text('${product.taxe}%',
                                  style: _cellTextStyle())),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  '${product.prixTTC.toStringAsFixed(2)} DT',
                                  style: _cellTextStyle())),
                          Expanded(
                            flex: 2,
                            child: product.variants.isNotEmpty
                                ? Tooltip(
                                    message: product.variants
                                        .map((v) =>
                                            '${v.combinationName} (${v.stock})')
                                        .join('\n'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF009688)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.list_alt,
                                              size: 16,
                                              color: Color(0xFF009688)),
                                          const SizedBox(width: 4),
                                          Text(
                                              '      ${product.variants.length} variantes'),
                                        ],
                                      ),
                                    ),
                                  )
                                : const Text('-',
                                    style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  color: const Color(0xFF009688),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProductScreen(
                                          product: product,
                                          refreshData: _loadProducts,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: const Color(0xFFE53935),
                                  onPressed: () =>
                                      _confirmDelete(singleProduct: product),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _headerTextStyle() {
    return const TextStyle(
      fontWeight: FontWeight.bold,
      color: Color(0xFF0056A6),
      fontSize: 14,
    );
  }

  TextStyle _cellTextStyle() {
    return const TextStyle(
      fontWeight: FontWeight.bold,
      color: Color.fromARGB(255, 1, 42, 79),
      fontSize: 14,
    );
  }
}
