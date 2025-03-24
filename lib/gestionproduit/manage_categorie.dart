import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/gestionproduit/products_to_delete_screen.dart';

class ManageCategoriePage extends StatefulWidget {
  const ManageCategoriePage({super.key});

  @override
  _ManageCategoriePageState createState() => _ManageCategoriePageState();
}

class _ManageCategoriePageState extends State<ManageCategoriePage> {
  final SqlDb sqldb = SqlDb();
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  final TextEditingController _searchController = TextEditingController();
  List<Category> _selectedCategories =
      []; // Pour stocker les catégories sélectionnées

  @override
  void initState() {
    super.initState();
    fetchCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    try {
      List<Category> fetchedCategories = await sqldb.getCategories();
      setState(() {
        _categories = fetchedCategories;
        _filteredCategories = fetchedCategories;
      });
    } catch (e) {
      _showMessage("Erreur lors du chargement des catégories !");
    }
  }

  Future<bool> _checkProductsBeforeDelete(List<Category> categories) async {
    for (var category in categories) {
      bool hasProducts = await sqldb.hasProductsInCategory(category.id!);
      if (hasProducts) {
        return true; // Il y a des produits associés
      }
    }
    return false; // Aucun produit associé
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
      MaterialPageRoute(builder: (context) => const AddCategory()),
    );
    fetchCategories(); // Rafraîchir la liste après l'ajout d'une catégorie
  }

  void _editCategory(Category category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategory(),
        settings: RouteSettings(arguments: category),
      ),
    );
    fetchCategories(); // Rafraîchir la liste après la modification d'une catégorie
  }

  Future<void> _confirmDelete({Category? singleCategory}) async {
    // Créer une liste des catégories à supprimer
    List<Category> categoriesToDelete =
        singleCategory != null ? [singleCategory] : _selectedCategories;

    // Récupérer les produits concernés
    List<String> productCodes = [];
    for (var category in categoriesToDelete) {
      productCodes.addAll(await sqldb.getProductsInCategory(category.id!));
    }

    if (productCodes.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            title: Column(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 40, color: Colors.orange),
                const SizedBox(height: 8),
                Text(
                  "Action impossible",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  singleCategory != null
                      ? "Cette catégorie contient des produits associés :"
                      : "Les catégories sélectionnées contiennent des produits :",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12), // Correction ici
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.info_outline,
                          size: 16, color: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Vous devez d'abord supprimer ces produits\n"
                        "avant de pouvoir supprimer la catégorie.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${productCodes.length} produit(s) concerné(s)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ], // Correction : fermeture correcte du children
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductsToDeleteScreen(
                        productCodes: productCodes,
                        onProductsDeleted: fetchCategories,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  "Voir les produits",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            actionsPadding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          );
        },
      );
      return;
    }

    // Si pas de produits, demander confirmation
    final TextEditingController confirmController = TextEditingController();
    bool isConfirmed = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 10),
                  const Text(
                    'Confirmation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    singleCategory != null
                        ? 'Tapez "confirmer" pour supprimer cette catégorie :'
                        : 'Tapez "confirmer" pour supprimer les catégories sélectionnées :',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmController,
                    onChanged: (value) {
                      setState(() {
                        isConfirmed =
                            (value.trim().toLowerCase() == "confirmer");
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'confirmer',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isConfirmed
                      ? () async {
                          Navigator.of(context).pop();
                          await _deleteCategories(categoriesToDelete);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isConfirmed ? Colors.red : Colors.grey[400],
                  ),
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategories(List<Category> categories) async {
    try {
      int successCount = 0;

      for (var category in categories) {
        int result = await sqldb.deleteCategory(category.id!);
        if (result > 0) {
          successCount++;
        } else if (result == -2) {
          // Code spécial pour catégorie avec produits
          _showMessage(
              "La catégorie '${category.name}' n'a pas pu être supprimée car elle contient des produits");
        }
      }

      if (successCount > 0) {
        _showMessage("$successCount catégorie(s) supprimée(s) avec succès !");
      }

      _selectedCategories
          .clear(); // Vider la liste des catégories sélectionnées
      fetchCategories(); // Rafraîchir la liste
    } catch (e) {
      _showMessage(
          "Erreur lors de la suppression des catégories : ${e.toString()}");
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
        _selectedCategories.clear(); // Désélectionner tout
      } else {
        _selectedCategories =
            List.from(_filteredCategories); // Sélectionner tout
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Catégories'),
        backgroundColor: const Color(0xFF0056A6),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToAddCategory,
          ),
          if (_filteredCategories.isNotEmpty)
            IconButton(
              icon: Icon(
                _selectedCategories.length == _filteredCategories.length
                    ? Icons.deselect
                    : Icons.select_all,
                color: Colors.white,
              ),
              onPressed:
                  _toggleSelectAll, // Sélectionner ou désélectionner tout
            ),
          if (_selectedCategories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
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
                labelText: 'Rechercher une catégorie',
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
            child: _filteredCategories.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune catégorie trouvée',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = _filteredCategories[index];
                      final isSelected = _selectedCategories.contains(category);
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              _toggleCategorySelection(category);
                            },
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${category.subCategories.length} sous-catégories',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF009688)),
                                onPressed: () {
                                  _editCategory(category);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Color(0xFFE53935)),
                                onPressed: () =>
                                    _confirmDelete(singleCategory: category),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
