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
  late Future<List<Product>> _productsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _productsFuture = sqldb.getProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterProducts(_searchController.text);
  }

  Future<void> _filterProducts(String query) async {
    final products = await _productsFuture;
    setState(() {
      _filteredProducts = products
          .where((product) =>
              product.code.toLowerCase().contains(query.toLowerCase()) ||
              product.designation.toLowerCase().contains(query.toLowerCase()) ||
              (product.categoryName ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = sqldb.getProducts();
    });
  }

  Future<void> _confirmDeleteProduct(String productCode) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Voulez-vous vraiment supprimer ce produit ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteProduct(productCode);
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(String productCode) async {
    await sqldb.deleteProduct(productCode);
    _refreshProducts();
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
                    refreshData: _refreshProducts,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche stylisée
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher un produit',
                labelStyle: const TextStyle(color: Colors.black54),
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
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun produit trouvé',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  );
                } else {
                  final products = _searchController.text.isEmpty
                      ? snapshot.data!
                      : _filteredProducts;
                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
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
                                        refreshData: _refreshProducts,
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
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
