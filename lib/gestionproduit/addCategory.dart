import 'dart:io';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddCategory extends StatefulWidget {
  @override
  _AddCategoryState createState() => _AddCategoryState();
}

class _AddCategoryState extends State<AddCategory> {
  final TextEditingController nameController = TextEditingController();
  File? selectedImage;
  final SqlDb sqldb = SqlDb();
  bool isVisible = false;

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
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

    int result = await sqldb.addCategory(nameController.text, selectedImage!.path);
    if (result > 0) {
      _showMessage("Catégorie ajoutée avec succès !");
      setState(() {
        isVisible = false;
      });
    } else {
      _showMessage("Échec de l'ajout de la catégorie !");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: Icon(isVisible ? Icons.remove : Icons.add, color: Colors.blue),
          onPressed: () {
            setState(() {
              isVisible = !isVisible;
            });
          },
        ),
        if (isVisible) ...[
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'Nom de la catégorie', border: OutlineInputBorder()),
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
        ],
      ],
    );
  }
}
