import 'dart:io';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';

class Categorieetproduct extends StatefulWidget {
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final List<double> discounts;
  final Function(Product) onProductSelected;

  const Categorieetproduct({
    super.key,
    required this.selectedProducts,
    required this.quantityProducts,
    required this.discounts,
    required this.onProductSelected,
  });

  @override
  State<Categorieetproduct> createState() => _CategorieetproductState();
}

class _CategorieetproductState extends State<Categorieetproduct> {
  final SqlDb sqldb = SqlDb();
  late Future<List<Category>> categories;
  late Future<List<Product>> products;
  int? selectedCategoryId; // Track the selected category ID

  // Define the color palette
  final Color deepBlue = const Color(0xFF0056A6); // Primary deep blue
  final Color darkBlue =
      const Color.fromARGB(255, 1, 42, 79); // Accent sky blue
  final Color white = Colors.white; // White
  final Color lightGray = const Color(0xFFE0E0E0); // Light gray
  final Color tealGreen = const Color(0xFF009688); // Accent teal green
  final Color softOrange = const Color(0xFFFF9800); // Accent soft orange
  final Color warmRed = const Color(0xFFE53935); // Accent warm red

  @override
  void initState() {
    super.initState();
    categories = _fetchCategories();
    products = _fetchProducts();
  }

  void refreshData() {
    setState(() {
      categories = _fetchCategories();
      products = _fetchProducts();
    });
  }

  Future<List<Category>> _fetchCategories() async {
    try {
      // Fetch categories from the database
      final categoriesMap = await sqldb.getCategories();
      List<Category> categoriesList = [];

      for (var category in categoriesMap) {
        var subCategoryMaps =
            await sqldb.getSubCategoriesByCategory(category.id!);
        List<SubCategory> subCategories = subCategoryMaps
            .map((subCategoryMap) => SubCategory.fromMap(subCategoryMap))
            .toList();

        Category categoryWithSubCategories = Category.fromMap(
          category.toMap(),
          subCategories: subCategories,
        );
        categoriesList.add(categoryWithSubCategories);
      }

      return categoriesList;
    } catch (e) {
      print("Error fetching categories: $e");
      return [];
    }
  }

  void updateStock(Product product, int quantity) {
  setState(() {
    product.stock -= quantity;
  });
}


  Future<List<Product>> _fetchProducts() async {
    try {
      final productsMap = await sqldb.getProducts();
      print("Fetched products: $productsMap");
      // Filter out products with stock = 0
      return productsMap.where((product) => product.stock > 0).toList();
    } catch (e) {
      print("Error fetching products: $e");
      return [];
    }
  }

  void _onCategorySelected(int categoryId) {
    setState(() {
      selectedCategoryId = categoryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          // Colonne des catégories (1/4 de l'espace)
          Expanded(
            flex: 2, // 1 part sur 4
            child: RefreshIndicator(
              onRefresh: () async {
                refreshData();
              },
              child: FutureBuilder<List<Category>>(
                future: categories,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text('Erreur de chargement: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('Aucune catégorie disponible'));
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio:
                          1.0, // Ajusté pour des conteneurs plus grands
                      mainAxisSpacing: 5.0, // Espacement vertical réduit
                      crossAxisSpacing: 5.0, // Espacement horizontal réduit
                    ),
                    padding: const EdgeInsets.all(1.0),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final category = snapshot.data![index];
                      return buildCategoryButton(
                        category.name,
                        category.imagePath,
                        category.id!,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          VerticalDivider(
            color: lightGray,
            thickness: 2,
          ),
          // Colonne des produits (3/4 de l'espace)
          Expanded(
            flex: 4, // 3 parts sur 4
            child: RefreshIndicator(
              onRefresh: () async {
                refreshData();
              },
              child: FutureBuilder<List<Product>>(
                future: products,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text('Erreur de chargement: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('Aucun produit disponible'));
                  }

                  // Filter products based on the selected category
                  final filteredProducts = selectedCategoryId == null
                      ? snapshot.data!
                      : snapshot.data!
                          .where((product) =>
                              product.categoryId == selectedCategoryId)
                          .toList();

                  return GridView.count(
                    crossAxisCount: 6,
                    childAspectRatio:
                        1.26, // Ajusté pour correspondre à la forme désirée
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    children: filteredProducts.map((product) {
                      return InkWell(
                        onTap: () {
                          widget.onProductSelected(product);
                        },
                        child: Container(
                          width: 160, // Largeur ajustée
                          height: 90, // Hauteur ajustée
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius:
                                BorderRadius.circular(20), // Bords arrondis
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Nom du produit + catégorie
                              Text(
                                "${product.designation}",
                                style: TextStyle(
                                  color: white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4), // Espacement réduit

                              // Prix
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${product.prixTTC.toStringAsFixed(2)} DT",
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 4), // Espacement réduit

                              // Stock
                              Text(
                                "Stock: ${product.stock}",
                                style: TextStyle(
                                  color: product.stock > 5
                                      ? const Color.fromARGB(255, 55, 231, 61)
                                      : warmRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCategoryButton(String? name, String? imagePath, int categoryId) {
    final categoryName = name ?? 'Catégorie inconnue';
    final defaultImage = 'assets/images/categorie.png';

    final isLocalFile = imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('assets/');
    final categoryImagePath = (isLocalFile && File(imagePath).existsSync())
        ? imagePath
        : defaultImage;

    return GestureDetector(
      onTap: () {
        _onCategorySelected(categoryId);
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
        width: 140,
        height: 180, // Augmenter la hauteur (par exemple, 180 au lieu de 160)
        decoration: BoxDecoration(
          color: darkBlue.withOpacity(0.1),
          border: Border.all(color: deepBlue, width: 1.5),
          borderRadius: BorderRadius.circular(80),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: categoryImagePath.startsWith('assets/')
                  ? Image.asset(
                      categoryImagePath,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(categoryImagePath),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              child: Text(
                categoryName,
                style: TextStyle(
                  color: deepBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
