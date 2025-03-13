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
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79); // Accent sky blue
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
          // Colonne des catégories
          Expanded(
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
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 30.0,
                      crossAxisSpacing: 30.0,
                    ),
                    padding: const EdgeInsets.all(8.0),
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
            thickness: 1,
          ),
          // Colonne des produits
          Expanded(
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
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 6.0,
                    crossAxisSpacing: 6.0,
                    children: filteredProducts.map((product) {
                      return InkWell(
                        onTap: () {
                          widget.onProductSelected(product);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Center(
                            child: Text(
                              "${product.designation} (${product.categoryName ?? 'Sans catégorie'})",
                              style: TextStyle(
                                color: white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: darkBlue.withOpacity(0.1),
          border: Border.all(color: deepBlue, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: categoryImagePath.startsWith('assets/')
                  ? Image.asset(
                      categoryImagePath,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(categoryImagePath),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              child: Text(
                categoryName,
                style: TextStyle(
                  color: deepBlue,
                  fontSize: 15,
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
