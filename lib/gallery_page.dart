import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'sqldb.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final List<File> _images = []; // Liste des images sélectionnées
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadImagesFromDatabase();
  }

  Future<void> _loadImagesFromDatabase() async {
    final imagesFromDb = await SqlDb().getGalleryImages();
    setState(() {
      _images.addAll(imagesFromDb.map((image) => File(image['image_path'])));
    });
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      for (var file in pickedFiles) {
        final imagePath = file.path;
        await SqlDb().insertImage(imagePath); // Stocker l'image dans la base de données
      }
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final imagePath = pickedFile.path;
      await SqlDb().insertImage(imagePath); // Stocker l'image dans la base de données
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  void _removeImage(int index) async {
    final imagePath = _images[index].path;

    // Afficher une boîte de dialogue de confirmation
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: const Text("Êtes-vous sûr de vouloir supprimer cette image ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Retourne `false` pour annuler
              },
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Retourne `true` pour confirmer
              },
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );

    // Si l'utilisateur confirme la suppression
    if (confirmDelete == true) {
      final imagesFromDb = await SqlDb().getGalleryImages();
      final imageToDelete = imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

      await SqlDb().deleteImage(imageToDelete['id']); // Supprimer l'image de la base de données

      setState(() {
        _images.removeAt(index); // Supprimer l'image de la liste
      });

      // Optionnel : Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image supprimée avec succès")),
      );
    }
  }

  void _selectImages() {
    Navigator.pop(context, _images);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Galerie d'images"),
        backgroundColor: const Color(0xFF0056A6),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectImages, // Valider la sélection
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text("Depuis la galerie"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.camera),
                label: const Text("Prendre une photo"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text("Aucune image sélectionnée"))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Affichage en 3 colonnes
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Image.file(
                              _images[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: const CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 12,
                                child: Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}