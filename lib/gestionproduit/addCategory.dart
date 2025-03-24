import 'dart:io';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/gestionproduit/products_to_delete_screen.dart';
import 'package:caissechicopets/gallery_page.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddCategory extends StatefulWidget {
  const AddCategory({super.key});

  @override
  _AddCategoryState createState() => _AddCategoryState();
}

class _AddCategoryState extends State<AddCategory> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController subCategoryNameController =
      TextEditingController();
  File? selectedImage;
  final SqlDb sqldb = SqlDb();
  bool isVisible = false;
  int? selectedCategoryId;
  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  Category? categoryToEdit;
  final TextEditingController _editSubCategoryController =
      TextEditingController();
  int? selectedParentSubCategoryId;
  int _nextSubCategoryId = 1; // For generating unique IDs

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Category) {
      categoryToEdit = args;
      nameController.text = categoryToEdit!.name;
      selectedCategoryId = categoryToEdit!.id;
      selectedImage = File(categoryToEdit!.imagePath!);

      // Load subcategories for the category being edited
      if (selectedCategoryId != null) {
        fetchSubCategories(selectedCategoryId!);
      }
    }
  }

  Future<void> fetchCategories() async {
    try {
      List<Category> fetchedCategories = await sqldb.getCategories();
      setState(() {
        categories = fetchedCategories;
      });
    } catch (e) {
      _showMessage("Erreur lors du chargement des catégories !");
    }
  }

  Future<void> fetchSubCategories(int categoryId) async {
    try {
      List<Map<String, dynamic>> fetchedSubCategories =
          await sqldb.getSubCategoriesByCategory(categoryId);

      // Debugging: Print fetched subcategories
      print("Fetched subcategories: $fetchedSubCategories");

      setState(() {
        subCategories = fetchedSubCategories.map((map) {
          return SubCategory(
            id: map['id_sub_category'],
            name: map['sub_category_name'] ?? 'Unknown',
            parentId: map['parent_id'],
            categoryId: map['category_id'] ?? 0,
          );
        }).toList();
      });
    } catch (e) {
      print("Error fetching subcategories: $e");
      _showMessage("Erreur lors du chargement des sous-catégories !");
    }
  }

  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> pickImageFromGallery() async {
    final selectedImageFromGallery = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GalleryPage(),
      ),
    );

    if (selectedImageFromGallery != null && selectedImageFromGallery is File) {
      setState(() {
        selectedImage =
            selectedImageFromGallery; // Mettre à jour l'image sélectionnée
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Choisir la source de l'image"),
          content: const Text(
              "Voulez-vous choisir une image depuis la galerie ou depuis votre PC ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                pickImageFromGallery();
              },
              child: const Text("Galerie"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                pickImage();
              },
              child: const Text("PC"),
            ),
          ],
        );
      },
    );
  }

  void addCategory() async {
    if (nameController.text.isEmpty || selectedImage == null) {
      _showMessage("Veuillez remplir tous les champs !");
      return;
    }

    // Ajoute la catégorie
    int categoryId =
        await sqldb.addCategory(nameController.text, selectedImage!.path);
    if (categoryId > 0) {
      // Trie les sous-catégories pour enregistrer les parents avant les enfants
      List<SubCategory> sortedSubCategories =
          _sortSubCategoriesByParent(subCategories);

      // Map pour stocker les ID temporaires et les ID réels des sous-catégories
      Map<int, int> tempIdToRealId = {};

      // Enregistre les sous-catégories parentes d'abord
      for (var subCategory in sortedSubCategories) {
        if (subCategory.parentId == null) {
          int subCategoryId = await sqldb.addSubCategory(
            SubCategory(
              name: subCategory.name,
              parentId: subCategory.parentId,
              categoryId: categoryId,
            ),
          );

          // Stocke l'ID réel de la sous-catégorie parente
          tempIdToRealId[subCategory.id ?? -1] = subCategoryId;
        }
      }

      // Enregistre les sous-catégories filles avec les parent_id corrects
      for (var subCategory in sortedSubCategories) {
        if (subCategory.parentId != null) {
          int realParentId = tempIdToRealId[subCategory.parentId] ?? -1;
          if (realParentId != -1) {
            await sqldb.addSubCategory(
              SubCategory(
                name: subCategory.name,
                parentId: realParentId,
                categoryId: categoryId,
              ),
            );
          }
        }
      }

      _showMessageSuccess(
          "Catégorie et sous-catégories ajoutées avec succès !");
      setState(() {
        nameController.clear();
        selectedImage = null;
        subCategories.clear();
        fetchCategories();
      });
    } else {
      _showMessage("Échec de l'ajout de la catégorie !");
    }
  }

  List<SubCategory> _sortSubCategoriesByParent(
      List<SubCategory> subCategories) {
    List<SubCategory> sortedSubCategories = [];
    List<SubCategory> remainingSubCategories = List.from(subCategories);

    while (remainingSubCategories.isNotEmpty) {
      for (var subCategory in remainingSubCategories.toList()) {
        if (subCategory.parentId == null ||
            sortedSubCategories
                .any((subCat) => subCat.id == subCategory.parentId)) {
          sortedSubCategories.add(subCategory);
          remainingSubCategories.remove(subCategory);
        }
      }
    }

    return sortedSubCategories;
  }

  void updateCategory() async {
    if (nameController.text.isEmpty || selectedImage == null) {
      _showMessage("Veuillez remplir tous les champs !");
      return;
    }

    // Update the category
    int result = await sqldb.updateCategory(
      categoryToEdit!.id!,
      nameController.text,
      selectedImage!.path,
    );

    if (result > 0) {
      // Debugging: Print the subcategories before updating
      print("Subcategories before update: $subCategories");

      // Update subcategories
      for (var subCategory in subCategories) {
        if (subCategory.id == null) {
          // Add a new subcategory
          int newSubCategoryId = await sqldb.addSubCategory(
            SubCategory(
              name: subCategory.name,
              parentId: subCategory.parentId,
              categoryId: categoryToEdit!.id!,
            ),
          );
          print(
              "Added new subcategory: ${subCategory.name}, ID: $newSubCategoryId");
        } else {
          // Update an existing subcategory
          final updateResult = await sqldb.updateSubCategory(subCategory);
          if (updateResult <= 0) {
            _showMessage(
                "Échec de la mise à jour de la sous-catégorie : ${subCategory.name}");
          } else {
            print(
                "Updated subcategory: ${subCategory.name}, ID: ${subCategory.id}");
          }
        }
      }

      // Fetch the updated subcategories after updating the category
      await fetchSubCategories(categoryToEdit!.id!);

      // Debugging: Print the subcategories after updating
      print("Subcategories after update: $subCategories");

      _showMessageSuccess(
          "Catégorie et sous-catégories mises à jour avec succès !");
      Navigator.pop(context);
    } else {
      _showMessage("Échec de la mise à jour de la catégorie !");
    }
  }

  void addSubCategory() async {
    if (subCategoryNameController.text.isEmpty) {
      _showMessage("Veuillez entrez un nom de sous-catégorie !");
      return;
    }

    // Save the subcategory to the database
    int subCategoryId = await sqldb.addSubCategory(
      SubCategory(
        name: subCategoryNameController.text,
        parentId: selectedParentSubCategoryId,
        categoryId: selectedCategoryId ?? categoryToEdit?.id ?? 0,
      ),
    );

    if (subCategoryId > 0) {
      setState(() {
        subCategories.add(
          SubCategory(
            id: subCategoryId,
            name: subCategoryNameController.text,
            parentId: selectedParentSubCategoryId,
            categoryId: selectedCategoryId ?? categoryToEdit?.id ?? 0,
          ),
        );
        subCategoryNameController.clear();
        selectedParentSubCategoryId = null; // Reset the selected parent ID
      });

      // Debugging
      print("Added SubCategory: ${subCategories.last.name}");
      print("Parent ID: ${subCategories.last.parentId}");
      print("SubCategories: $subCategories");
    } else {
      _showMessage("Échec de l'ajout de la sous-catégorie !");
    }
  }

  void _confirmDeleteSubCategory(int subCategoryId) async {
    // Vérifier d'abord s'il y a des produits associés (directement ou dans les enfants)
    final productCodes = await sqldb.getProductsInSubCategory(subCategoryId);

    if (productCodes.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            title: Column(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 36, color: Colors.deepOrange),
                const SizedBox(height: 6),
                const Text(
                  "Suppression bloquée",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
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
                  "Cette sous-catégorie ou ses enfants contiennent des produits :",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.subdirectory_arrow_right,
                        size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Pour supprimer cette sous-catégorie, vous devez "
                        "d'abord supprimer tous les produits associés.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.orange[100]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 16, color: Colors.deepOrange),
                      const SizedBox(width: 6),
                      Text(
                        "${productCodes.length} produit(s) concerné(s)",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        onProductsDeleted: () {
                          if (selectedCategoryId != null) {
                            fetchSubCategories(selectedCategoryId!);
                          }
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text("Voir les produits"),
              ),
            ],
            actionsAlignment: MainAxisAlignment.end,
            actionsPadding: const EdgeInsets.all(12),
          );
        },
      );
      return;
    }

    // Si pas de produits, demander confirmation
    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                12), // Coins arrondis pour un look moderne
          ),
          title: const Text(
            "Confirmer la suppression",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18, // Augmentation de la taille du texte
            ),
          ),
          content: const Text(
            "Êtes-vous sûr de vouloir supprimer cette sous-catégorie ?",
            style: TextStyle(fontSize: 16), // Texte plus lisible
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor:
                    Colors.blue, // Couleur plus visible pour annuler
                textStyle: TextStyle(fontSize: 16), // Taille du texte améliorée
              ),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor:
                    Colors.red, // Couleur rouge pour indiquer danger
                textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold), // Texte plus lisible
              ),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      int result = await sqldb.deleteSubCategory(subCategoryId);
      if (result > 0) {
        _showMessageSuccess("Sous-catégorie supprimée avec succès !");
        if (selectedCategoryId != null) {
          fetchSubCategories(selectedCategoryId!); // Rafraîchir la liste
        }
      } else if (result == -2) {
        _showMessage("Cette sous-catégorie contient des produits !");
      } else {
        _showMessage("Échec de la suppression de la sous-catégorie !");
      }
    }
  }

  Future<void> deleteSubCategory(int subCategoryId) async {
    try {
      final result = await sqldb.deleteSubCategory(subCategoryId);
      if (result > 0) {
        _showMessageSuccess("Sous-catégorie supprimée avec succès !");
        setState(() {
          subCategories.removeWhere((subCat) => subCat.id == subCategoryId);
        });
      } else {
        _showMessage("Échec de la suppression de la sous-catégorie !");
      }
    } catch (e) {
      _showMessage("Erreur lors de la suppression de la sous-catégorie : $e");
    }
  }

  void _editSubCategory(SubCategory subCategory) async {
    _editSubCategoryController.text = subCategory.name;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Modifier la sous-catégorie"),
          content: TextFormField(
            controller: _editSubCategoryController,
            decoration:
                const InputDecoration(labelText: 'Nom de la sous-catégorie'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                if (_editSubCategoryController.text.isEmpty) {
                  _showMessage("Veuillez entrer un nom valide !");
                  return;
                }

                setState(() {
                  subCategories = subCategories.map((subCat) {
                    if (subCat.id == subCategory.id) {
                      return SubCategory(
                        id: subCat.id,
                        name: _editSubCategoryController.text,
                        parentId: subCat.parentId,
                        categoryId: subCat.categoryId,
                      );
                    }
                    return subCat;
                  }).toList();
                });

                Navigator.pop(context);
              },
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935), // Warm Red for error
      ),
    );
  }

  void _showMessageSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            const Color.fromARGB(255, 92, 216, 73), // Green for success
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryToEdit == null
            ? 'Ajouter une catégorie'
            : 'Modifier la catégorie'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextFormField(
              controller: nameController,
              label: 'Nom de la catégorie',
            ),
            const SizedBox(height: 16),
            selectedImage == null
                ? Text(
                    "Aucune image sélectionnée",
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : Image.file(selectedImage!, height: 100),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showImageSourceDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26A9E0), // Sky Blue
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Choisir une image",
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: categoryToEdit == null ? addCategory : updateCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688), // Teal Green
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                categoryToEdit == null ? "Ajouter" : "Mettre à jour",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const Divider(
              color: Color(0xFFE0E0E0), // Light Gray divider
              thickness: 2,
            ),
            const SizedBox(height: 16),

            // Ajout des sous-catégories
            const Text(
              "Ajouter des sous-catégories :",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0056A6)), // Deep Blue
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: subCategoryNameController,
                    label: 'Nom de la sous-catégorie',
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: selectedParentSubCategoryId,
                  hint: const Text('Select Parent'),
                  items: [
                    // Add a "No Parent" option
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('No Parent'),
                    ),
                    // Add all subcategories as options
                    ...subCategories.map((subCategory) {
                      return DropdownMenuItem<int>(
                        value: subCategory.id,
                        child: Text(subCategory.name),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedParentSubCategoryId = value;
                    });
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(
                    Icons.add,
                    color: Color(0xFF26A9E0), // Sky Blue icon
                  ),
                  onPressed: addSubCategory,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Affichage des sous-catégories
            if (subCategories.isNotEmpty) ...[
              const Text(
                "Sous-catégories :",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0056A6)), // Deep Blue
              ),
              const SizedBox(height: 8),
              SubCategoryTree(
                subCategories: subCategories,
                parentId: null, // Start with top-level subcategories
                onEdit: _editSubCategory, // Pass the edit method
                onDelete: _confirmDeleteSubCategory, // Pass the delete method
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(label),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: Color(0xFF0056A6)), // Deep Blue for label
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFFE0E0E0)), // Light Gray border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF26A9E0)), // Sky Blue on focus
      ),
    );
  }
}

// Recursive widget to display subcategory hierarchy
class SubCategoryTree extends StatelessWidget {
  final List<SubCategory> subCategories;
  final int? parentId;
  final Function(SubCategory) onEdit;
  final Function(int) onDelete;

  const SubCategoryTree({
    required this.subCategories,
    this.parentId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Filter subcategories by parentId
    final children =
        subCategories.where((subCat) => subCat.parentId == parentId).toList();

    // Debugging: Print the filtered children
    print("Filtered subcategories for parentId $parentId: $children");

    // If no children, return an empty widget
    if (children.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true, // Avoid infinite height issues
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling
      itemCount: children.length,
      itemBuilder: (context, index) {
        final subCat = children[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(subCat.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF009688)),
                    onPressed: () => onEdit(subCat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFE53935)),
                    onPressed: () => onDelete(subCat.id!),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: SubCategoryTree(
                subCategories: subCategories,
                parentId: subCat.id,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ],
        );
      },
    );
  }
}
