import 'dart:io';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';

class Categorieetproduct extends StatefulWidget {
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final Function(Product) onProductSelected;

  const Categorieetproduct({
    Key? key,
    required this.selectedProducts,
    required this.quantityProducts,
    required this.onProductSelected,
  }) : super(key: key);

  @override
  State<Categorieetproduct> createState() => _CategorieetproductState();
}

class _CategorieetproductState extends State<Categorieetproduct> {
  final SqlDb sqldb = SqlDb();
  late Future<List<Category>> categories;
  late Future<List<Product>> products;

  // Define the color palette
  final Color deepBlue = const Color(0xFF0056A6); // Primary deep blue
  final Color skyBlue = const Color(0xFF26A9E0); // Accent sky blue
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
      final categoriesMap =
          await sqldb.getCategories(); // Assuming it gets categories only
      List<Category> categoriesList = [];

      // Iterate through each category (map is now a Category object)
      for (var category in categoriesMap) {
        // Fetch subcategories for this category using the 'id_category' property of the Category object
        var subCategoryMaps = await sqldb.getSubCategoriesByCategory(
            category.id!); // Use category.id or category.id_category

        // Map the subcategories from the map into SubCategory objects
        List<SubCategory> subCategories = subCategoryMaps
            .map((subCategoryMap) => SubCategory.fromMap(subCategoryMap))
            .toList();

        // Create a Category object with its subcategories
        Category categoryWithSubCategories = Category.fromMap(
          category
              .toMap(), // Convert the category object back to a map if needed
          subCategories: subCategories,
        );
        categoriesList.add(categoryWithSubCategories);
      }

      return categoriesList;
    } catch (e) {
      print("Error fetching categories: $e");
      return []; // Return empty list in case of error
    }
  }

  Future<List<Product>> _fetchProducts() async {
    try {
      final productsMap = await sqldb.getProducts();
      print("Fetched products: $productsMap"); // Log the fetched products
      return productsMap.toList();
    } catch (e) {
      print("Error fetching products: $e");
      return []; // Return an empty list in case of error
    }
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
                      childAspectRatio:
                          1.5, 
                      mainAxisSpacing: 30.0,
                      crossAxisSpacing: 30.0,
                    ),
                    padding: const EdgeInsets.all(8.0),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final category = snapshot.data![index];
                      return buildCategoryButton(
                          category.name, category.imagePath);
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

                  return GridView.count(
                    crossAxisCount: 6, 
                    
                    childAspectRatio:
                        1.2, 
                    mainAxisSpacing: 6.0,   
                    crossAxisSpacing: 6.0, 
                    children: snapshot.data!.map((product) {
                      return InkWell(
                        onTap: () {
                          widget.onProductSelected(product);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            color: skyBlue,
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

  // Product button uses sky blue background and white text.
  Widget buildProductButton(String text) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      padding: const EdgeInsets.all(8.0), // Ajouter du padding
      decoration: BoxDecoration(
        color: skyBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
            fontSize: 14, // Augmenter la taille du texte
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Category button uses deep blue border with a light blue background.
  Widget buildCategoryButton(String? name, String? imagePath) {
    final categoryName = name ?? 'Catégorie inconnue';
    final defaultImage = 'assets/images/categorie.png';

    final isLocalFile = imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('assets/');
    final categoryImagePath = (isLocalFile && File(imagePath!).existsSync())
        ? imagePath
        : defaultImage;

    return GestureDetector(
      onTap: () {
        print("Category Selected: $categoryName");
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
        width: 80, // Taille plus petite
        height: 80, // Taille plus petite
        decoration: BoxDecoration(
          color: skyBlue.withOpacity(0.1),
          border:
              Border.all(color: deepBlue, width: 1.5), // Réduire l'épaisseur
          borderRadius:
              BorderRadius.circular(30), // Coins arrondis au lieu de cercle
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: categoryImagePath.startsWith('assets/')
                  ? Image.asset(
                      categoryImagePath,
                      width: 100, // Réduire la taille de l'image
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(categoryImagePath),
                      width: 100, // Réduire la taille de l'image
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
                  fontSize: 15, // Réduire la taille du texte
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
