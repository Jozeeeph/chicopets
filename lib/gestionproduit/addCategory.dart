import 'dart:io';
import 'package:caissechicopets/category.dart';
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
    
      // Charger les sous-catégories associées à la catégorie en cours de modification
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

  void addCategory() async {
    if (nameController.text.isEmpty || selectedImage == null) {
      _showMessage("Veuillez remplir tous les champs !");
      return;
    }

    // Ajouter la catégorie
    int categoryId =
        await sqldb.addCategory(nameController.text, selectedImage!.path);
    if (categoryId > 0) {
      // Ajouter les sous-catégories
      for (var subCategory in subCategories) {
        await sqldb.addSubCategory(
          SubCategory(
            name: subCategory.name,
            categoryId: categoryId,
          ),
        );
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

  void updateCategory() async {
    if (nameController.text.isEmpty || selectedImage == null) {
      _showMessage("Veuillez remplir tous les champs !");
      return;
    }

    // Mettre à jour la catégorie
    int result = await sqldb.updateCategory(
      categoryToEdit!.id!,
      nameController.text,
      selectedImage!.path,
    );

    if (result > 0) {
      // Mettre à jour les sous-catégories
      for (var subCategory in subCategories) {
        if (subCategory.id == null) {
          // Ajouter une nouvelle sous-catégorie
          await sqldb.addSubCategory(
            SubCategory(
              name: subCategory.name,
              categoryId: categoryToEdit!.id!,
            ),
          );
        } else {
          // Mettre à jour une sous-catégorie existante
          print("Mise à jour de la sous-catégorie : ${subCategory.name}");
          print(
              "Données de la sous-catégorie à mettre à jour : ${subCategory.toMap()}");
          final updateResult = await sqldb.updateSubCategory(subCategory);
          print("Résultat de la mise à jour : $updateResult");
          if (updateResult <= 0) {
            _showMessage(
                "Échec de la mise à jour de la sous-catégorie : ${subCategory.name}");
          }
        }
      }

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
    setState(() {
      subCategories.add(
        SubCategory(
          name: subCategoryNameController.text,
          categoryId: selectedCategoryId ?? categoryToEdit?.id ?? 0,
        ),
      );
      subCategoryNameController.clear();
    });
  }

  void _confirmDeleteSubCategory(int subCategoryId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: const Text(
              "Êtes-vous sûr de vouloir supprimer cette sous-catégorie ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await deleteSubCategory(subCategoryId);
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
              onPressed: pickImage,
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subCategories.length,
                itemBuilder: (context, index) {
                  final subCategory = subCategories[index];
                  return ListTile(
                    title: Text(
                      subCategory.name,
                      style: const TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0)), // Black text
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Color(0xFF009688)), // Teal Green
                          onPressed: () => _editSubCategory(subCategory),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Color(0xFFE53935)), // Warm Red
                          onPressed: () =>
                              _confirmDeleteSubCategory(subCategory.id!),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
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
        style:
            const TextStyle(color: Color.fromARGB(255, 0, 0, 0)), // Black text
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
