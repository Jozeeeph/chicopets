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
    _loadData();
  }

  void _loadData() {
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
        var subCategoryMaps =
            await sqldb.getSubCategoriesByCategory(category.id!);
        List<SubCategory> subCategories = subCategoryMaps
            .map((subCategoryMap) => SubCategory.fromMap(subCategoryMap))
            .toList();

        categoriesList.add(Category.fromMap(
          category.toMap(),
          subCategories: subCategories,
        ));
      }

      print('Loaded ${categoriesList.length} categories');
      return categoriesList;
    } catch (e) {
      print("Error fetching categories: $e");
      return [];
    }
  }

  Future<List<Product>> _fetchProductsWithVariants() async {
    try {
      final productsMap = await sqldb.getProducts();
      print('Fetched ${productsMap.length} products from database');

      List<Product> validProducts = [];

      for (var product in productsMap) {
        try {
          if (product.id != null) {
            product.variants = await sqldb.getVariantsByProductId(product.id!);
            print(
                'Product ${product.designation} has ${product.variants.length} variants');
            validProducts.add(product);
          }
        } catch (e) {
          print('Error processing product ${product.id}: $e');
        }
      }

      print('Returning ${validProducts.length} products');
      return validProducts;
    } catch (e) {
      print("Error fetching products with variants: $e");
      return [];
    }
  }

  void _showVariantSelectionDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tealGreen, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Variant for ${product.designation}',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: product.variants.length,
                    itemBuilder: (context, index) {
                      final variant = product.variants[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        color:
                            variant.stock > 0 ? Colors.white : Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: variant.stock > 0 ? tealGreen : warmRed,
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 8),
                          leading: Icon(
                            variant.stock > 0
                                ? Icons.check_circle
                                : Icons.remove_circle,
                            color: variant.stock > 0 ? Colors.green : warmRed,
                            size: 30,
                          ),
                          title: Text(
                            variant.combinationName,
                            style: TextStyle(
                              color: darkBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Price: ${variant.finalPrice} DT',
                                style: TextStyle(
                                  color: darkBlue,
                                ),
                              ),
                              Text(
                                'Stock: ${variant.stock}',
                                style: TextStyle(
                                  color:
                                      variant.stock > 0 ? tealGreen : warmRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (variant.defaultVariant)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tealGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: TextStyle(
                                      color: tealGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: darkBlue,
                            size: 16,
                          ),
                          onTap: variant.stock > 0
                              ? () {
                                  Navigator.pop(context);
                                  widget.onProductSelected(product, variant);
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onProductSelected(Product product) {
    if (product.hasVariants && product.variants.isNotEmpty) {
      final defaultVariant = product.variants.firstWhere(
        (v) => v.defaultVariant,
        orElse: () => product.variants.first,
      );
      
      if (product.variants.length == 1) {
        widget.onProductSelected(product, defaultVariant);
      } else {
        _showVariantSelectionDialog(context, product);
      }
    } else {
      widget.onProductSelected(product);
    }
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      selectedCategoryId = categoryId;
    });
  }

  Widget _buildCategoryButton(Category category) {
    return GestureDetector(
      onTap: () => _onCategorySelected(category.id),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: selectedCategoryId == category.id
              ? tealGreen.withOpacity(0.2)
              : darkBlue.withOpacity(0.1),
          border: Border.all(
            color: selectedCategoryId == category.id ? tealGreen : deepBlue,
            width: 1.8,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SizedBox(
                width: 80,
                height: 80,
                child: _buildCategoryImage(category.imagePath),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name ?? 'Unnamed',
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

  Widget _buildCategoryImage(String? imagePath) {
    const defaultImage = 'assets/images/categorie.png';
    final effectivePath =
        imagePath?.isNotEmpty == true ? imagePath! : defaultImage;

    try {
      if (effectivePath.startsWith('assets/')) {
        return Image.asset(
          effectivePath,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultCategoryImage(),
        );
      } else if (File(effectivePath).existsSync()) {
        return Image.file(
          File(effectivePath),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultCategoryImage(),
        );
      }
    } catch (e) {
      print('Error loading category image: $e');
    }

    return _buildDefaultCategoryImage();
  }

  Widget _buildDefaultCategoryImage() {
    return Container(
      width: 100,
      height: 100,
      color: lightGray,
      child: Icon(Icons.category, size: 50, color: deepBlue),
    );
  }

  Widget _buildProductCard(Product product) {
    // Find default variant or use first variant if none marked as default
    Variant? defaultVariant;
    if (product.hasVariants && product.variants.isNotEmpty) {
      defaultVariant = product.variants.firstWhere(
        (v) => v.defaultVariant,
        orElse: () => product.variants.first,
      );
    }

    final displayPrice = defaultVariant?.price ?? product.prixTTC;
    final displayStock = defaultVariant?.stock ?? product.stock;
    final variantName = defaultVariant?.combinationName;

    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(17),
      ),
      child: InkWell(
        onTap: () => _onProductSelected(product),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                child: Column(
                  children: [
                    Text(
                      "${displayPrice.toStringAsFixed(2)} DT",
                      style: TextStyle(
                        color: softOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (variantName != null)
                      Text(
                        variantName,
                        style: TextStyle(
                          color: white,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (defaultVariant?.defaultVariant ?? false)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: tealGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            color: white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Stock: $displayStock",
                style: TextStyle(
                  color: displayStock > 5
                      ? const Color.fromARGB(255, 60, 218, 65)
                      : warmRed,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.hasVariants)
                Text(
                  "${product.variants.length} variante(s)",
                  style: TextStyle(
                    color: const Color.fromARGB(255, 64, 204, 255),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
              onRefresh: () async {
                _loadData();
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
                      mainAxisSpacing: 28.0,
                      crossAxisSpacing: 40.0,
                    ),
                    padding: const EdgeInsets.all(8.0),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return _buildCategoryButton(snapshot.data![index]);
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
          // Products column
          Expanded(
            flex: 4,
            child: RefreshIndicator(
              onRefresh: () async {
                _loadData();
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

                  // Remove duplicate products
                  final uniqueProducts = snapshot.data!
                      .fold<Map<String, Product>>({}, (map, product) {
                        if (!map.containsKey(product.code)) {
                          map[product.code] = product;
                        }
                        return map;
                      })
                      .values
                      .toList();

                  // Filter by category if selected
                  final filteredProducts = selectedCategoryId == null
                      ? uniqueProducts
                      : uniqueProducts
                          .where((p) => p.categoryId == selectedCategoryId)
                          .toList();

                  return GridView.count(
                    crossAxisCount: 6,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 6.0,
                    crossAxisSpacing: 6.0,
                    children: filteredProducts.map((product) {
                      return _buildProductCard(product);
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
}