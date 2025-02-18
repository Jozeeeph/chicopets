import 'dart:io';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddCategory extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      // This will now return a list of Category objects correctly mapped
      List<Category> fetchedCategories = await sqldb.getCategories();
      setState(() {
        categories =
            fetchedCategories; // Update the state with the fetched categories
      });
    } catch (e) {
      _showMessage("Erreur lors du chargement des catégories !");
    }
  }

  Future<void> fetchSubCategories(int categoryId) async {
  try {
    List<Map<String, dynamic>> fetchedSubCategories =
        await sqldb.getSubCategoriesByCategory(categoryId);

    print('Fetched subcategories: $fetchedSubCategories');

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
        fetchCategories(); // Rafraîchir les catégories
      });
    } else {
      _showMessage("Échec de l'ajout de la catégorie !");
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon:
                Icon(isVisible ? Icons.remove : Icons.add, color: Colors.blue),
            onPressed: () {
              setState(() {
                isVisible = !isVisible;
              });
            },
          ),
          if (isVisible) ...[
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                  labelText: 'Nom de la catégorie',
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 10),
            selectedImage == null
                ? Text("Aucune image sélectionnée")
                : Image.file(selectedImage!, height: 100),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickImage,
              child: Text("Choisir une image"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: addCategory,
              child: Text("Ajouter"),
            ),
            Divider(),

            // Sélection de la catégorie
            DropdownButtonFormField<int>(
              value: selectedCategoryId,
              hint: Text("Sélectionner une catégorie"),
              items: categories.map((category) {
                return DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategoryId = value;
                  fetchSubCategories(value!);
                });
              },
              decoration: InputDecoration(border: OutlineInputBorder()),
            ),
            SizedBox(height: 10),

            // Liste des sous-catégories (with scrolling)
            if (selectedCategoryId != null) ...[
              Text("Sous-catégories :",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subCategories.isEmpty
                  ? Text("Aucune sous-catégorie trouvée")
                  : SingleChildScrollView(
                      child: Column(
                        children: subCategories.map((subCategory) {
                          return ListTile(
                            title: Text(subCategory.name),
                          );
                        }).toList(),
                      ),
                    ),
              SizedBox(height: 10),
            ],

            // Ajout d'une sous-catégorie
            if (selectedCategoryId != null) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: subCategoryNameController,
                      decoration: InputDecoration(
                          labelText: 'Nom de la sous-catégorie',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.green),
                    onPressed: addSubCategory,
                  ),
                ],
              ),
              SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}
