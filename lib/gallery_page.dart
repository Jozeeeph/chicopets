import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'sqldb.dart'; // Assurez-vous que ce fichier existe et est correctement configuré

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final List<File> _images = []; // Liste des images sélectionnées
  final List<TextEditingController> _nameControllers =
      []; // Contrôleurs pour les noms des images
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController =
      TextEditingController(); // Contrôleur pour la barre de recherche

  @override
  void initState() {
    super.initState();
    _loadImagesFromDatabase();
  }

  Future<void> _loadImagesFromDatabase() async {
    final imagesFromDb = await SqlDb().getGalleryImages();
    setState(() {
      _images.addAll(imagesFromDb.map((image) => File(image['image_path'])));
      _nameControllers.addAll(
        imagesFromDb.map((image) => TextEditingController(text: image['name'])),
      );
    });
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      for (var file in pickedFiles) {
        final imagePath = file.path;
        await SqlDb()
            .insertImage(imagePath, ''); // Ajouter l'image sans nom initial
      }
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)));
        _nameControllers.addAll(
          List.generate(pickedFiles.length, (index) => TextEditingController()),
        );
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final imagePath = pickedFile.path;
      await SqlDb()
          .insertImage(imagePath, ''); // Ajouter l'image sans nom initial
      setState(() {
        _images.add(File(pickedFile.path));
        _nameControllers.add(TextEditingController());
      });
    }
  }

  Future<void> _saveImageName(int index) async {
    final imagePath = _images[index].path;
    final imageName = _nameControllers[index].text;

    // Récupérer l'ID de l'image à partir de la base de données
    final imagesFromDb = await SqlDb().getGalleryImages();
    final imageToUpdate =
        imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

    // Mettre à jour le nom de l'image dans la base de données
    await SqlDb().updateImageName(imageToUpdate['id'], imageName);
  }

  void _removeImage(int index) async {
    final imagePath = _images[index].path;

    // Afficher une boîte de dialogue de confirmation
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content:
              const Text("Êtes-vous sûr de vouloir supprimer cette image ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Retourne false pour annuler
              },
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Retourne true pour confirmer
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
      final imageToDelete =
          imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

      await SqlDb().deleteImage(
          imageToDelete['id']); // Supprimer l'image de la base de données

      setState(() {
        _images.removeAt(index); // Supprimer l'image de la liste
        _nameControllers.removeAt(index); // Supprimer le contrôleur associé
      });

      // Optionnel : Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image supprimée avec succès")),
      );
    }
  }

  void _selectImages() async {
    // Sauvegarder tous les noms des images avant de naviguer
    for (int i = 0; i < _images.length; i++) {
      await _saveImageName(i);
    }

    // Afficher un message de succès une seule fois
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Noms des images mis à jour")),
    );

    // Naviguer vers la page précédente
    Navigator.pop(context, _images);
  }

  Future<void> _searchImagesByName(String name) async {
    final results = await SqlDb().searchImagesByName(name);
    setState(() {
      _images.clear();
      _images.addAll(results.map((image) => File(image['image_path'])));
      _nameControllers.clear();
      _nameControllers.addAll(
        results.map((image) => TextEditingController(text: image['name'])),
      );
    });
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
      body: SingleChildScrollView(
        // Ajout d'un SingleChildScrollView pour permettre le défilement
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Rechercher par nom',
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  _searchImagesByName(value); // Rechercher des images par nom
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Importer depuis la galerie"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 93, 212, 220)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _images.isEmpty
                ? const Center(child: Text("Aucune image sélectionnée"))
                : GridView.builder(
                    shrinkWrap:
                        true, // Permet au GridView de s'adapter à son contenu
                    physics:
                        const NeverScrollableScrollPhysics(), // Désactive le défilement du GridView
                    padding: const EdgeInsets.all(5), // Réduire l'espacement
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          3, // 3 images par ligne (ajustez selon vos besoins)
                      crossAxisSpacing: 2, // Espacement horizontal réduit
                      mainAxisSpacing: 2, // Espacement vertical réduit
                      childAspectRatio: 1, // Ratio carré pour les images
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Container(
                            height: 120, // Réduire la hauteur de l'image
                            width: 120, // Réduire la largeur de l'image
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              image: DecorationImage(
                                image: FileImage(_images[index]),
                                fit: BoxFit
                                    .cover, // Ajuster l'image pour couvrir l'espace
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: const CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 10,
                                      child: Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _nameControllers[index],
                              decoration: const InputDecoration(
                                hintText: 'Nom',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 5),
                              ),
                              onSubmitted: (value) {
                                _saveImageName(
                                    index); // Sauvegarder le nom lors de la soumission
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
