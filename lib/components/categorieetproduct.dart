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
      final productsMap = await sqldb.getProductsWithCategory();
      print("Fetched products: $productsMap"); // Log the fetched products
      return productsMap.map((map) => Product.fromMap(map)).toList();
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
          // Categories Column
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
                      childAspectRatio: 1,
                      mainAxisSpacing: 8.0,
                      crossAxisSpacing: 8.0,
                    ),
                    padding: const EdgeInsets.all(8.0),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final category = snapshot.data![index];
                      print(
                          "Category Name: ${category.name}, Image Path: ${category.imagePath}");
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
          // Products Column
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
                    crossAxisCount: 4,
                    children: snapshot.data!.map((product) {
                      return InkWell(
                        onTap: () {
                          widget.onProductSelected(product);
                        },
                        child: buildProductButton(
                            "${product.designation} (${product.categoryName ?? 'Sans catégorie'})"),
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
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Category button uses deep blue border with a light blue background.
  Widget buildCategoryButton(String? name, String? imagePath) {
    final categoryName = name ?? 'Unknown Category';
    final categoryImagePath = imagePath ?? 'assets/images/default.jpg';

    return GestureDetector(
      onTap: () {
        print("Category Selected: $categoryName");
      },
      child: Container(
        margin: const EdgeInsets.all(6.0),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: skyBlue.withOpacity(0.1), // light sky blue background
          border: Border.all(color: deepBlue, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: categoryImagePath.startsWith('assets/')
                  ? Image.asset(
                      categoryImagePath,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error, size: 60, color: lightGray);
                      },
                    )
                  : (File(categoryImagePath).existsSync()
                      ? Image.file(
                          File(categoryImagePath),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.error, size: 60, color: lightGray)),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 60,
              child: Text(
                categoryName,
                style: TextStyle(
                  color: deepBlue,
                  fontSize: 12,
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
