import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';

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
                          if (singleCategory != null) {
                            await _deleteCategories([singleCategory]);
                          } else {
                            await _deleteCategories(_selectedCategories);
                          }
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
      for (var category in categories) {
        await sqldb.deleteCategory(category.id!);
      }
      _showMessage("${categories.length} catégories supprimées avec succès !");
      _selectedCategories
          .clear(); // Vider la liste des catégories sélectionnées
      fetchCategories(); // Rafraîchir la liste
    } catch (e) {
      _showMessage("Erreur lors de la suppression des catégories !");
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