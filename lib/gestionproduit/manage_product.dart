import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/gestionproduit/add_product_screen.dart';
import 'package:caissechicopets/product.dart';

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
    setState(() {
      _products = products;
      _filteredProducts = products;
    });
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.code.toLowerCase().contains(query) ||
            product.designation.toLowerCase().contains(query) ||
            (product.categoryName ?? '').toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _confirmDeleteProduct(String productCode) async {
    TextEditingController _confirmController = TextEditingController();
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
                  const Text(
                    'Tapez "confirmer" pour supprimer ce produit :',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _confirmController,
                    onChanged: (value) {
                      setState(() {
                        isConfirmed = (value.toLowerCase().trim() == "confirmer");
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
                          await _deleteProduct(productCode);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmed ? Colors.red : Colors.grey[400],
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

  Future<void> _deleteProduct(String productCode) async {
    await sqldb.deleteProduct(productCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Produit $productCode supprimé avec succès"),
        backgroundColor: Colors.green,
      ),
    );
    _loadProducts(); // Recharge directement la liste des produits
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher un produit',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF26A9E0)),
                filled: true,
                fillColor: const Color(0xFFE0E0E0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun produit trouvé',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF26A9E0),
                            child: Text(
                              product.designation[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            product.designation,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Code: ${product.code} - Stock: ${product.stock}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF009688)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddProductScreen(
                                        product: product,
                                        refreshData: _loadProducts,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Color(0xFFE53935)),
                                onPressed: () {
                                  _confirmDeleteProduct(product.code);
                                },
                              ),
                            ],
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
