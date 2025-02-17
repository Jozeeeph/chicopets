import 'dart:io';
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

  @override
  void initState() {
    super.initState();
    categories = _fetchCategories();
    products = _fetchProducts();
  }

  Future<List<Category>> _fetchCategories() async {
    final categoriesMap = await sqldb.getCategories();
    return categoriesMap.map((map) => Category.fromMap(map)).toList();
  }

  Future<List<Product>> _fetchProducts() async {
    final productsMap = await sqldb.getProductsWithCategory();
    return productsMap.map((map) => Product.fromMap(map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<List<Category>>(
              future: categories,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aucune catégorie disponible'));
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                  ),
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final category = snapshot.data![index];
                    return buildCategoryButton(category.name, category.imagePath);
                  },
                );
              },
            ),
          ),
          VerticalDivider(color: Colors.grey.shade400, thickness: 1),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: products,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aucun produit disponible'));
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
        ],
      ),
    );
  }

  Widget buildProductButton(String text) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

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
          color: Colors.blue.withOpacity(0.1),
          border: Border.all(color: Colors.blue, width: 2),
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
                        return Icon(Icons.error, size: 60, color: Colors.grey);
                      },
                    )
                  : (File(categoryImagePath).existsSync()
                      ? Image.file(
                          File(categoryImagePath),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.error, size: 60, color: Colors.grey)),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 60,
              child: Text(
                categoryName,
                style: const TextStyle(
                    color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
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
