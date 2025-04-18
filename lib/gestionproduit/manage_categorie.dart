import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/gestionproduit/products_to_delete_screen.dart';

class ManageCategoriePage extends StatefulWidget {
  const ManageCategoriePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ManageCategoriePageState createState() => _ManageCategoriePageState();
}

class _ManageCategoriePageState extends State<ManageCategoriePage> {
  final SqlDb sqldb = SqlDb();
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  final TextEditingController _searchController = TextEditingController();
  List<Category> _selectedCategories = [];
  String _importStatus = 'Ready';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeDatabase() async {
    try {
      final db = await sqldb.db;
      // Verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('categories', 'sub_categories')",
      );
      if (tables.length < 2) {
        throw Exception('Required database tables not found');
      }
      await fetchCategories();
    } catch (e) {
      setState(() {
        _importStatus = 'Error';
        _errorMessage = 'Database initialization failed: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    setState(() {
      _importStatus = 'Loading';
      _errorMessage = '';
    });

    try {
      List<Category> fetchedCategories =
          await sqldb.getCategoriesWithSubcategories();

      // Filter out any invalid categories
      fetchedCategories = fetchedCategories.where((category) {
        return category.name.isNotEmpty && category.id != null;
      }).toList();

      setState(() {
        _categories = fetchedCategories;
        _filteredCategories = fetchedCategories;
        _importStatus = 'Ready';
      });
    } catch (e) {
      setState(() {
        _importStatus = 'Error';
        _errorMessage = 'Failed to load categories: ${e.toString()}';
      });
    }
  }

  Future<bool> _checkProductsBeforeDelete(List<Category> categories) async {
    try {
      for (var category in categories) {
        if (category.id == null) continue;

        bool hasProducts = await sqldb.hasProductsInCategory(category.id!);
        if (hasProducts) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking products: $e');
      return true; // Fail-safe - assume there are products
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories.where((category) {
        return category.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _navigateToAddCategory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategory(
          onCategoryAdded: () async {
            // This will be called when a new category is successfully added
            await fetchCategories();
          },
        ),
      ),
    );
    // Optional: Additional refresh after returning from the screen
    await fetchCategories();
  }

  void _editCategory(Category category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategory(
          onCategoryAdded: () async {
            // This callback will be executed when a category is added/updated
            await fetchCategories();
          },
        ),
        settings: RouteSettings(arguments: category),
      ),
    );
    await fetchCategories(); // Optional: Refresh again after returning
  }

  Future<void> _confirmDelete({Category? singleCategory}) async {
    List<Category> categoriesToDelete =
        singleCategory != null ? [singleCategory] : _selectedCategories;

    try {
      bool hasProducts = await _checkProductsBeforeDelete(categoriesToDelete);

      if (hasProducts) {
        List<String> productCodes = [];
        for (var category in categoriesToDelete) {
          if (category.id != null) {
            final codes = await sqldb.getProductsInCategory(category.id!);
            productCodes.addAll(codes);
          }
        }

        if (productCodes.isEmpty) {
          // This shouldn't happen but handle it gracefully
          await _deleteCategories(categoriesToDelete);
          return;
        }

        await _showProductsDeleteDialog(productCodes);
        return;
      }

      bool confirmed = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Confirm Delete"),
              content: Text(
                  "Are you sure you want to delete ${categoriesToDelete.length} category(ies)?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ) ??
          false;

      if (confirmed) {
        await _deleteCategories(categoriesToDelete);
      }
    } catch (e) {
      _showMessage("Error during deletion process: ${e.toString()}");
    }
  }

  Future<void> _showProductsDeleteDialog(List<String> productCodes) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Icon(Icons.warning, size: 40, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              "Cannot Delete Category",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "This category contains ${productCodes.length} product(s). "
              "You must delete these products first.",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Products: ${productCodes.take(5).join(', ')}${productCodes.length > 5 ? '...' : ''}",
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductsToDeleteScreen(
                    productIdentifiers: productCodes,
                    onProductsDeleted: fetchCategories,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text("View Products",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategories(List<Category> categories) async {
    try {
      int successCount = 0;
      final db = await sqldb.db;

      await db.transaction((txn) async {
        for (var category in categories) {
          // Delete subcategories first
          await txn.delete(
            'sub_categories',
            where: 'category_id = ?',
            whereArgs: [category.id],
          );

          // Then delete category
          int result = await txn.delete(
            'categories',
            where: 'id_category = ?',
            whereArgs: [category.id],
          );

          if (result > 0) successCount++;
        }
      });

      if (successCount > 0) {
        _showMessage("Deleted $successCount category(ies)");
        await fetchCategories();
      }
    } catch (e) {
      _showMessage("Error deleting categories: ${e.toString()}");
    }
  }

  void _toggleCategorySelection(Category category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedCategories.length == _filteredCategories.length) {
        _selectedCategories.clear();
      } else {
        _selectedCategories = List.from(_filteredCategories);
      }
    });
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Loading categories..."),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            "Error loading categories",
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchCategories,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No categories found",
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _navigateToAddCategory,
            child: const Text("Add your first category"),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        final isSelected = _selectedCategories.contains(category);
        final subcategoryCount = category.subCategories.length;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleCategorySelection(category),
            onLongPress: () => _editCategory(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleCategorySelection(category),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "$subcategoryCount ${subcategoryCount == 1 ? 'subcategory' : 'subcategories'}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit category',
                      onPressed: () => _editCategory(category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete category',
                      onPressed: () => _confirmDelete(singleCategory: category),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: const Color(0xFF0056A6),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAddCategory,
          ),
          if (_filteredCategories.isNotEmpty)
            IconButton(
              icon: Icon(
                _selectedCategories.length == _filteredCategories.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: _toggleSelectAll,
            ),
          if (_selectedCategories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(),
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
                labelText: 'Search categories',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _importStatus == 'Loading'
                ? _buildLoadingState()
                : _importStatus == 'Error'
                    ? _buildErrorState()
                    : _filteredCategories.isEmpty
                        ? _buildEmptyState()
                        : _buildCategoryList(),
          ),
        ],
      ),
    );
  }
}
