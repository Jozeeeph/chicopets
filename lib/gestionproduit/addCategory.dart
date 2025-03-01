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
      if (categoryToEdit!.imagePath != null) {
        selectedImage = File(categoryToEdit!.imagePath!);
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

    int result =
        await sqldb.addCategory(nameController.text, selectedImage!.path);
    if (result > 0) {
      _showMessage("Catégorie ajoutée avec succès !");
      setState(() {
        isVisible = false;
        nameController.clear();
        selectedImage = null;
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

    int result = await sqldb.updateCategory(
      categoryToEdit!.id!,
      nameController.text,
      selectedImage!.path,
    );

    if (result > 0) {
      _showMessage("Catégorie mise à jour avec succès !");
      Navigator.pop(context);
    } else {
      _showMessage("Échec de la mise à jour de la catégorie !");
    }
  }

  void addSubCategory() async {
    if (subCategoryNameController.text.isEmpty || selectedCategoryId == null) {
      _showMessage("Veuillez remplir tous les champs !");
      return;
    }

    int result = await sqldb.addSubCategory(
      SubCategory(
        name: subCategoryNameController.text,
        categoryId: selectedCategoryId!,
      ),
    );

    if (result > 0) {
      _showMessage("Sous-catégorie ajoutée avec succès !");
      setState(() {
        subCategoryNameController.clear();
        fetchSubCategories(selectedCategoryId!);
      });
    } else {
      _showMessage("Échec de l'ajout de la sous-catégorie !");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935), // Warm Red for error
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

            // Category Dropdown
            DropdownButtonFormField<int>(
              value: selectedCategoryId,
              hint: const Text(
                "Sélectionner une catégorie",
                style: TextStyle(color: Color(0xFF0056A6)), // Deep Blue
              ),
              items: categories.map((category) {
                return DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(
                    category.name,
                    style: const TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0)), // Black text
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategoryId = value;
                  fetchSubCategories(value!);
                });
              },
              decoration: _inputDecoration('Catégorie'),
            ),
            const SizedBox(height: 16),

            // Subcategories List
            if (selectedCategoryId != null) ...[
              const Text(
                "Sous-catégories :",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0056A6)), // Deep Blue
              ),
              const SizedBox(height: 8),
              subCategories.isEmpty
                  ? Text(
                      "Aucune sous-catégorie trouvée",
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: subCategories.map((subCategory) {
                          return ListTile(
                            title: Text(
                              subCategory.name,
                              style: const TextStyle(
                                  color: Color.fromARGB(
                                      255, 0, 0, 0)), // Black text
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              const SizedBox(height: 16),
            ],

            // Add Subcategory
            if (selectedCategoryId != null) ...[
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
