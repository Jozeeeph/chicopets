import 'dart:io';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/variant.dart';

class Categorieetproduct extends StatefulWidget {
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final List<double> discounts;
  final Function(Product, [Variant?]) onProductSelected;

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
  int? selectedCategoryId;

  // Define the color palette
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
    categories = _fetchCategories();
    products = _fetchProductsWithVariants();
  }

  void refreshData() {
    setState(() {
      categories = _fetchCategories();
      products = _fetchProductsWithVariants();
    });
  }

  Future<List<Category>> _fetchCategories() async {
    try {
      final categoriesMap = await sqldb.getCategories();
      List<Category> categoriesList = [];

      for (var category in categoriesMap) {
        var subCategoryMaps = await sqldb.getSubCategoriesByCategory(category.id!);
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

  Future<List<Product>> _fetchProductsWithVariants() async {
    try {
      final productsMap = await sqldb.getProducts();
      
      // Load variants for each product
      for (var product in productsMap) {
        if (product.id != null) {
          product.variants = await sqldb.getVariantsByProductId(product.id!);
        }
      }

      print("Fetched products with variants: $productsMap");
      // Filter out products with no stock (including variants)
      return productsMap.where((product) {
        if (product.hasVariants) {
          // For products with variants, check if any variant has stock
          return product.variants.any((variant) => variant.stock > 0);
        } else {
          // For products without variants, check the product stock
          return product.stock > 0;
        }
      }).toList();
    } catch (e) {
      print("Error fetching products with variants: $e");
      return [];
    }
  }

  void _showVariantSelectionDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Variant for ${product.designation}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: product.variants.length,
              itemBuilder: (context, index) {
                final variant = product.variants[index];
                return ListTile(
                  title: Text(variant.combinationName),
                  subtitle: Text(
                    'Stock: ${variant.stock} - Price: ${variant.finalPrice} DT',
                    style: TextStyle(
                      color: variant.stock > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  onTap: variant.stock > 0
                      ? () {
                          Navigator.pop(context);
                          widget.onProductSelected(product, variant);
                        }
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _onProductSelected(Product product) {
    if (product.hasVariants && product.variants.isNotEmpty) {
      if (product.variants.length == 1) {
        // If only one variant, select it automatically
        widget.onProductSelected(product, product.variants.first);
      } else {
        // Show variant selection dialog for multiple variants
        _showVariantSelectionDialog(context, product);
      }
    } else {
      // Product without variants
      widget.onProductSelected(product);
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
          // Categories column
          Expanded(
            flex: 2,
            child: RefreshIndicator(
              onRefresh: () async => refreshData(),
              child: FutureBuilder<List<Category>>(
                future: categories,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No categories available'));
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 5.0,
                      crossAxisSpacing: 5.0,
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
          VerticalDivider(color: lightGray, thickness: 2),
          // Products column
          Expanded(
            flex: 4,
            child: RefreshIndicator(
              onRefresh: () async => refreshData(),
              child: FutureBuilder<List<Product>>(
                future: products,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No products available'));
                  }

                  final filteredProducts = selectedCategoryId == null
                      ? snapshot.data!
                      : snapshot.data!
                          .where((product) => product.categoryId == selectedCategoryId)
                          .toList();

                  return GridView.count(
                    crossAxisCount: 6,
                    childAspectRatio: 1.26,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    children: filteredProducts.map((product) {
                      // Calculate total stock (product stock + variants stock)
                      final totalStock = product.hasVariants
                          ? product.variants.fold(0, (sum, variant) => sum + variant.stock)
                          : product.stock;

                      return InkWell(
                        onTap: () => _onProductSelected(product),
                        child: Container(
                          width: 160,
                          height: 90,
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                product.designation,
                                style: TextStyle(
                                  color: white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  product.hasVariants && product.variants.isNotEmpty
                                      ? "Prix : ${product.variants.map((v) => v.finalPrice).reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} DT"
                                      : "${product.prixTTC.toStringAsFixed(2)} DT",
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Stock: $totalStock",
                                style: TextStyle(
                                  color: totalStock > 5
                                      ? const Color.fromARGB(255, 55, 231, 61)
                                      : warmRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (product.hasVariants)
                                Text(
                                  "${product.variants.length} variants",
                                  style: TextStyle(
                                    color: white,
                                    fontSize: 10,
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
    final categoryName = name ?? 'Unknown category';
    final defaultImage = 'assets/images/categorie.png';

    final isLocalFile = imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('assets/');
    final categoryImagePath = (isLocalFile && File(imagePath).existsSync())
        ? imagePath
        : defaultImage;

    return GestureDetector(
      onTap: () => _onCategorySelected(categoryId),
      child: Container(
        margin: const EdgeInsets.all(4.0),
        width: 140,
        height: 180,
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