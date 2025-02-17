import 'dart:io';

import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caissechicopets/category.dart';

class Addcategory {
  static void showAddCategoryPopUp(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    File? selectedImage;
    final SqlDb sqldb = SqlDb();

    Future<void> pickImage() async {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        selectedImage = File(pickedFile.path);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ajouter une Catégorie'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(nameController, 'Nom de la catégorie'),
                    const SizedBox(height: 10),
                    selectedImage == null
                        ? const Text("Aucune image sélectionnée")
                        : Image.file(selectedImage!, height: 100),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage();
                        setState(() {}); // Update the UI after image selection
                      },
                      child: const Text("Choisir une image"),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || selectedImage == null) {
                      _showMessage(
                          context, "Veuillez remplir tous les champs !");
                      return;
                    }

                    int result = await sqldb.addCategory(
                      nameController.text,
                      selectedImage!.path, // Save the image path
                    );
                    if (result > 0) {
                      _showMessage(context, "Catégorie ajoutée avec succès !");
                    } else {
                      _showMessage(
                          context, "Échec de l'ajout de la catégorie !");
                    }

                    Navigator.of(context).pop();
                  },
                  child: const Text('Ajouter'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      enabled: enabled,
    );
  }
}
