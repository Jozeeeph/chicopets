import 'dart:async';
import 'dart:io';
import 'package:caissechicopets/models/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/variant.dart';

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

  Timer? _refreshDebouncer;

  @override
  void initState() {
    super.initState();
    categories = _fetchCategories();
    products = _fetchProductsWithVariants();
  }

  @override
  void dispose() {
    _refreshDebouncer?.cancel();
    super.dispose();
  }

  void _loadData() {
    _refreshDebouncer?.cancel();
    _refreshDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          products = _fetchProductsWithVariants();
          categories = _fetchCategories();
        });
      }
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: product.variants.length,
                        itemBuilder: (context, index) {
                          final variant = product.variants[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            color: variant.stock > 0
                                ? Colors.white
                                : Colors.grey[200],
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
                                color:
                                    variant.stock > 0 ? Colors.green : warmRed,
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
                                      color: variant.stock > 0
                                          ? tealGreen
                                          : warmRed,
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
                                      widget.onProductSelected(
                                          product, variant);
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
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 3, vertical: 8), // Reduced vertical margin
      child: GestureDetector(
        onTap: () => _onCategorySelected(category.id),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important to prevent overflow
          children: [
            Container(
              width: 80, // Reduced from 90
              height: 80, // Reduced from 90
              decoration: BoxDecoration(
                color: selectedCategoryId == category.id
                    ? tealGreen.withOpacity(0.2)
                    : darkBlue.withOpacity(0.1),
                border: Border.all(
                  color:
                      selectedCategoryId == category.id ? tealGreen : deepBlue,
                  width: 1.5,
                ),
                borderRadius:
                    BorderRadius.circular(35), // Adjusted to match new size
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: _buildCategoryImage(category.imagePath),
              ),
            ),
            const SizedBox(height: 4), // Reduced spacing
            SizedBox(
              width: 70, // Match image width
              child: Text(
                category.name ?? 'Unnamed',
                style: TextStyle(
                  color: deepBlue,
                  fontSize: 12, // Slightly reduced
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
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
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultCategoryImage(),
        );
      } else if (File(effectivePath).existsSync()) {
        return Image.file(
          File(effectivePath),
          width: 70,
          height: 70,
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
    int totalStock = product.stock;
    if (product.hasVariants && product.variants.isNotEmpty) {
      totalStock =
          product.variants.fold(0, (sum, variant) => sum + variant.stock);
    }

    if (totalStock <= 0) return const SizedBox.shrink();

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
    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8), // Réduit vertical
    decoration: BoxDecoration(
      color: darkBlue,
      borderRadius: BorderRadius.circular(12), // Bord plus arrondi
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onProductSelected(product),
      child: Padding(
        padding: const EdgeInsets.all(6), // Padding réduit
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                product.designation,
                style: TextStyle(
                  color: white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12, // Réduit de 14 à 12
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Réduit de 3 à 2
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "${displayPrice.toStringAsFixed(2)} DT",
              style: TextStyle(
                color: softOrange,
                fontSize: 12, // Réduit de 14 à 12
                fontWeight: FontWeight.bold,
              ),
            ),
            if (variantName != null)
              Text(
                variantName,
                style: TextStyle(
                  color: white,
                  fontSize: 10, // Réduit de 14 à 10
                ),
                maxLines: 2, // Réduit de 3 à 1
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              "$displayStock",
              style: TextStyle(
                color: displayStock > 5
                    ? const Color.fromARGB(255, 60, 218, 65)
                    : warmRed,
                fontSize: 11, // Réduit de 14 à 11
              ),
            ),
            if (product.hasVariants)
              Text(
                "${product.variants.length}v",
                style: TextStyle(
                  color: const Color.fromARGB(255, 64, 204, 255),
                  fontSize: 10, // Réduit de 13 à 10
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categories column
                SizedBox(
                  width: constraints.maxWidth * 0.3,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _loadData();
                    },
                    child: FutureBuilder<List<Category>>(
                      future: categories,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No categories available'));
                        }

                        return Scrollbar(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  3, // Réduit de 3 à 2 pour plus d'espace
                              childAspectRatio:
                                  0.9, // Ajusté pour la nouvelle taille
                              mainAxisSpacing: 0.1,
                              crossAxisSpacing: 10,
                            ),
                            padding: const EdgeInsets.all(8),
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              return _buildCategoryButton(
                                  snapshot.data![index]);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                VerticalDivider(color: lightGray, thickness: 2, width: 5),

                // Products column
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _loadData();
                    },
                    child: FutureBuilder<List<Product>>(
                      future: products,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No products available'));
                        }

                        final productMap = <int, Product>{};
                        for (final product in snapshot.data!) {
                          if (product.id != null) {
                            int totalStock = product.stock;
                            if (product.hasVariants &&
                                product.variants.isNotEmpty) {
                              totalStock = product.variants
                                  .fold(0, (sum, v) => sum + v.stock);
                            }

                            if (totalStock > 0 &&
                                !productMap.containsKey(product.id!)) {
                              productMap[product.id!] = product;
                            }
                          }
                        }

                        final uniqueProducts = productMap.values.toList();
                        final filteredProducts = selectedCategoryId == null
                            ? uniqueProducts
                            : uniqueProducts
                                .where(
                                    (p) => p.categoryId == selectedCategoryId)
                                .toList();

                        if (filteredProducts.isEmpty) {
                          return Center(
                            child: Text(
                              selectedCategoryId == null
                                  ? 'No available products'
                                  : 'No products in this category',
                              style: TextStyle(color: darkBlue),
                            ),
                          );
                        }

                        final crossAxisCount =
                            constraints.maxWidth > 800 ? 8 : 5;

                        return Scrollbar(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 1.1,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            padding: const EdgeInsets.all(8),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(filteredProducts[index]);
                            },
                          ),
                        );
                      },
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
}
