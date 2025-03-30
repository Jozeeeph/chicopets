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
  // Palette de couleurs
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  // Contrôleurs et état
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
  int _nextSubCategoryId = 1;

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
        builder: (context) => const GalleryPage(isSelectionMode: true),
      ),
    );

    if (selectedImageFromGallery != null && selectedImageFromGallery is File) {
      setState(() {
        selectedImage = selectedImageFromGallery;
      });
    } else if (selectedImageFromGallery != null) {
      print("Unexpected return type from GalleryPage");
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

    int categoryId =
        await sqldb.addCategory(nameController.text, selectedImage!.path);
    if (categoryId > 0) {
      List<SubCategory> sortedSubCategories =
          _sortSubCategoriesByParent(subCategories);

      Map<int, int> tempIdToRealId = {};

      for (var subCategory in sortedSubCategories) {
        if (subCategory.parentId == null) {
          int subCategoryId = await sqldb.addSubCategory(
            SubCategory(
              name: subCategory.name,
              parentId: subCategory.parentId,
              categoryId: categoryId,
            ),
          );

          tempIdToRealId[subCategory.id ?? -1] = subCategoryId;
        }
      }

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

    int result = await sqldb.updateCategory(
      categoryToEdit!.id!,
      nameController.text,
      selectedImage!.path,
    );

    if (result > 0) {
      print("Subcategories before update: $subCategories");

      for (var subCategory in subCategories) {
        if (subCategory.id == null) {
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

      await fetchSubCategories(categoryToEdit!.id!);

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
        selectedParentSubCategoryId = null;
      });

      print("Added SubCategory: ${subCategories.last.name}");
      print("Parent ID: ${subCategories.last.parentId}");
      print("SubCategories: $subCategories");
    } else {
      _showMessage("Échec de l'ajout de la sous-catégorie !");
    }
  }

  void _confirmDeleteSubCategory(int subCategoryId) async {
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

    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Confirmer la suppression",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            "Êtes-vous sûr de vouloir supprimer cette sous-catégorie ?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                textStyle: TextStyle(fontSize: 16),
              ),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          fetchSubCategories(selectedCategoryId!);
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
        backgroundColor: warmRed,
      ),
    );
  }

  void _showMessageSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: tealGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryToEdit == null
              ? 'Ajouter une catégorie'
              : 'Modifier la catégorie',
          style: TextStyle(color: white),
        ),
        backgroundColor: deepBlue,
        iconTheme: IconThemeData(color: white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Catégorie
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, color: deepBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Informations de la catégorie',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            controller: nameController,
                            label: 'Nom de la catégorie',
                            icon: Icons.text_fields,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Image de la catégorie",
                            style: TextStyle(
                              color: darkBlue.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Icon(Icons.subdirectory_arrow_right, color: darkBlue.withOpacity(0.6)),
                          const SizedBox(height: 8),
                          if (selectedImage != null)
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 220,
                                    minHeight: 70,
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.9, // 90% de la largeur de l'écran
                                  ),
                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: lightGray),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, size: 40, color: lightGray),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Aucune image sélectionnée",
                                    style: TextStyle(color: lightGray),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: 190,
                              child: ElevatedButton.icon(
                                onPressed: _showImageSourceDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tealGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: Icon(Icons.image_search, color: white),
                                label: Text(
                                  "Choisir une image",
                                  style: TextStyle(color: white),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Sous-catégories
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.subdirectory_arrow_right,
                                  color: deepBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Gestion des sous-catégories',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextFormField(
                                  controller: subCategoryNameController,
                                  label: 'Nom de la sous-catégorie',
                                  icon: Icons.text_snippet,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: lightGray),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: DropdownButton<int>(
                                  value: selectedParentSubCategoryId,
                                  hint: Text('Parent',
                                      style: TextStyle(
                                          color: darkBlue.withOpacity(0.6))),
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: deepBlue),
                                  underline: const SizedBox(),
                                  items: [
                                    DropdownMenuItem<int>(
                                      value: null,
                                      child: Row(
                                        children: [
                                          Icon(Icons.horizontal_rule,
                                              size: 20, color: darkBlue),
                                          const SizedBox(width: 4),
                                          Text('Aucun parent'),
                                        ],
                                      ),
                                    ),
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
                              ),
                              const SizedBox(width: 10),
                              CircleAvatar(
                                backgroundColor: tealGreen,
                                child: IconButton(
                                  icon: Icon(Icons.add, color: white),
                                  onPressed: addSubCategory,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (subCategories.isNotEmpty) ...[
                            Text(
                              "Liste des sous-catégories",
                              style: TextStyle(
                                color: darkBlue.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: lightGray),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SubCategoryTree(
                                subCategories: subCategories,
                                parentId: null,
                                onEdit: _editSubCategory,
                                onDelete: _confirmDeleteSubCategory,
                                deepBlue: deepBlue,
                                tealGreen: tealGreen,
                                warmRed: warmRed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bouton principal en bas
          Container(
            padding: const EdgeInsets.all(16),
            width: 240,
            child: ElevatedButton.icon(
              onPressed: categoryToEdit == null ? addCategory : updateCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: deepBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: Icon(
                categoryToEdit == null ? Icons.add : Icons.save,
                color: white,
              ),
              label: Text(
                categoryToEdit == null
                    ? "Ajouter la catégorie"
                    : "Mettre à jour",
                style: TextStyle(
                  color: white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: darkBlue),
        prefixIcon: icon != null ? Icon(icon, color: deepBlue) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: deepBlue),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}

class SubCategoryTree extends StatelessWidget {
  final List<SubCategory> subCategories;
  final int? parentId;
  final Function(SubCategory) onEdit;
  final Function(int) onDelete;
  final Color deepBlue;
  final Color tealGreen;
  final Color warmRed;

  const SubCategoryTree({
    required this.subCategories,
    this.parentId,
    required this.onEdit,
    required this.onDelete,
    required this.deepBlue,
    required this.tealGreen,
    required this.warmRed,
  });

  @override
  Widget build(BuildContext context) {
    final children =
        subCategories.where((subCat) => subCat.parentId == parentId).toList();
    if (children.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final subCat = children[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  parentId == null
                      ? Icons.folder
                      : Icons.subdirectory_arrow_right,
                  color: deepBlue,
                ),
                title: Text(
                  subCat.name,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: tealGreen),
                      onPressed: () => onEdit(subCat),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: warmRed),
                      onPressed: () => onDelete(subCat.id!),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24.0),
              child: SubCategoryTree(
                subCategories: subCategories,
                parentId: subCat.id,
                onEdit: onEdit,
                onDelete: onDelete,
                deepBlue: deepBlue,
                tealGreen: tealGreen,
                warmRed: warmRed,
              ),
            ),
          ],
        );
      },
    );
  }
}
