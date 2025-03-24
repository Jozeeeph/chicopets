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
  final List<File> _images = [];
  final List<TextEditingController> _nameControllers = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  File? selectedImage; // Variable pour stocker l'image sélectionnée

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
        await SqlDb().insertImage(imagePath, '');
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
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final imagePath = pickedFile.path;
      await SqlDb().insertImage(imagePath, '');
      setState(() {
        _images.add(File(pickedFile.path));
        _nameControllers.add(TextEditingController());
      });
    }
  }

  Future<void> _saveImageName(int index) async {
    final imagePath = _images[index].path;
    final imageName = _nameControllers[index].text;

    final imagesFromDb = await SqlDb().getGalleryImages();
    final imageToUpdate =
        imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

    await SqlDb().updateImageName(imageToUpdate['id'], imageName);
  }

  void _removeImage(int index) async {
    final imagePath = _images[index].path;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: const Text("Êtes-vous sûr de vouloir supprimer cette image ?"),
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

    if (confirmDelete == true) {
      final imagesFromDb = await SqlDb().getGalleryImages();
      final imageToDelete =
          imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

      await SqlDb().deleteImage(imageToDelete['id']);

      setState(() {
        _images.removeAt(index);
        _nameControllers.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image supprimée avec succès")),
      );
    }
  }

  void _selectImages() async {
    if (selectedImage != null) {
      // Retourner l'image sélectionnée à AddCategory
      Navigator.pop(context, selectedImage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner une image")),
      );
    }
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
            onPressed: _selectImages,
          )
        ],
      ),
      body: SingleChildScrollView(
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
                  _searchImagesByName(value);
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
                  label: const Text("Importer depuis votre PC"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 93, 212, 220)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _images.isEmpty
                ? const Center(child: Text("Aucune image sélectionnée"))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(5),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedImage = _images[index]; // Sélectionner l'image
                          });
                        },
                        child: Column(
                          children: [
                            Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: selectedImage == _images[index]
                                      ? Colors.blue // Bordure bleue si sélectionnée
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                image: DecorationImage(
                                  image: FileImage(_images[index]),
                                  fit: BoxFit.cover,
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
                                  _saveImageName(index);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}