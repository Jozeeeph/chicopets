import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'sqldb.dart';

class GalleryPage extends StatefulWidget {
  final bool isSelectionMode;

  const GalleryPage({super.key, this.isSelectionMode = false});

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final List<File> _images = [];
  final List<TextEditingController> _nameControllers = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  File? selectedImage;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isImporting = false;
  int _importedCount = 0;
  int _totalToImport = 0;

  @override
  void initState() {
    super.initState();
    _loadImagesFromDatabase();
  }

  @override
  void dispose() {
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadImagesFromDatabase() async {
    final imagesFromDb = await SqlDb().getGalleryImages();
    setState(() {
      _images.clear();
      _nameControllers.clear();
      _images.addAll(imagesFromDb.map((image) => File(image['image_path'])));
      _nameControllers.addAll(
        imagesFromDb
            .map((image) => TextEditingController(text: image['name'] ?? '')),
      );
    });
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _isImporting = true;
        _importedCount = 0;
        _totalToImport = pickedFiles.length;
      });

      for (var file in pickedFiles) {
        try {
          await SqlDb().insertImage(file.path, 'Nom image');
          setState(() {
            _importedCount++;
          });
        } catch (e) {
          debugPrint('Erreur lors de l\'importation: ${e.toString()}');
        }
      }

      await _loadImagesFromDatabase();
      setState(() {
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$_importedCount/$_totalToImport images importées'),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isImporting = true;
      });

      try {
        await SqlDb().insertImage(pickedFile.path,
            'Photo du ${DateTime.now().toString().split(' ')[0]}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo importée avec succès"),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'importation: ${e.toString()}"),
            duration: const Duration(seconds: 2),
          ),
        );
      } finally {
        setState(() {
          _isImporting = false;
        });
        await _loadImagesFromDatabase();
      }
    }
  }

  Future<void> _saveImageName(int index) async {
    if (_nameControllers[index].text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Le nom ne peut pas être vide"),
            duration: Duration(seconds: 1)),
      );
      return;
    }

    final imagePath = _images[index].path;
    final imageName = _nameControllers[index].text;

    final imagesFromDb = await SqlDb().getGalleryImages();
    final imageToUpdate =
        imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

    await SqlDb().updateImageName(imageToUpdate['id'], imageName);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Nom sauvegardé"), 
          duration: Duration(seconds: 1)),
    );
  }

  Future<void> _removeImage(int index) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content:
              const Text("Êtes-vous sûr de vouloir supprimer cette image ?"),
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
      final imagePath = _images[index].path;
      final imagesFromDb = await SqlDb().getGalleryImages();
      final imageToDelete =
          imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

      await SqlDb().deleteImage(imageToDelete['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image supprimée avec succès")),
      );

      await _loadImagesFromDatabase();
    }
  }

  void _selectImageAndReturn() {
    if (selectedImage != null) {
      Navigator.pop(context, selectedImage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner une image")),
      );
    }
  }

  Future<void> _searchImagesByName(String name) async {
    if (name.isEmpty) {
      await _loadImagesFromDatabase();
      return;
    }

    final results = await SqlDb().searchImagesByName(name);
    setState(() {
      _images.clear();
      _nameControllers.clear();
      _images.addAll(results.map((image) => File(image['image_path'])));
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
          if (widget.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _selectImageAndReturn,
            )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Rechercher par nom',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          _loadImagesFromDatabase();
                        },
                      ),
                    ),
                    onChanged: _searchImagesByName,
                  ),
                ),
                const SizedBox(height: 10),
                if (!widget.isSelectionMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text("Importer depuis votre PC"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 93, 212, 220),
                        ),
                      ),
                      
                    ],
                  ),
                const SizedBox(height: 10),
                _images.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          "Aucune image disponible\nAjoutez des images depuis votre galerie ou appareil photo",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              if (widget.isSelectionMode) {
                                setState(() {
                                  selectedImage = _images[index];
                                });
                              }
                            },
                            child: Card(
                              elevation: selectedImage == _images[index] ? 4 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: selectedImage == _images[index]
                                      ? Colors.blue
                                      : Colors.grey.withOpacity(0.2),
                                  width: selectedImage == _images[index] ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            image: DecorationImage(
                                              image: FileImage(_images[index]),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        if (selectedImage == _images[index])
                                          Container(
                                            color: Colors.black.withOpacity(0.3),
                                            child: const Center(
                                              child: Icon(Icons.check_circle,
                                                  color: Colors.white, size: 36),
                                            ),
                                          ),
                                        if (!widget.isSelectionMode)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(index),
                                              child: const CircleAvatar(
                                                backgroundColor: Colors.red,
                                                radius: 12,
                                                child: Icon(Icons.close,
                                                    size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0, vertical: 4),
                                    child: Text(
                                      _nameControllers[index].text,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: selectedImage == _images[index]
                                            ? Colors.blue
                                            : Colors.grey[700],
                                        fontWeight: selectedImage == _images[index]
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (!widget.isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: TextField(
                                        controller: _nameControllers[index],
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        maxLength: 20,
                                        decoration: InputDecoration(
                                          hintText: 'Nom de l\'image',
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 4),
                                          counterText: '',
                                          suffixIcon: _nameControllers[index]
                                                  .text
                                                  .isNotEmpty
                                              ? IconButton(
                                                  icon:
                                                      const Icon(Icons.save, size: 16),
                                                  onPressed: () =>
                                                      _saveImageName(index),
                                                )
                                              : null,
                                        ),
                                        onSubmitted: (value) => _saveImageName(index),
                                        onChanged: (value) {
                                          if (value.length == 20) {
                                            FocusScope.of(context).unfocus();
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
          if (_isImporting)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Importation en cours...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_importedCount/$_totalToImport',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}