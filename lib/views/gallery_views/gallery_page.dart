import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/sqldb.dart';

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
        imagesFromDb.map((image) => TextEditingController(
            text: image['name'] ?? _generateDefaultName(image['image_path']))),
      );
    });
  }

  String _generateDefaultName(String path) {
    final fileName = path.split('/').last;
    return 'Image_${fileName.hashCode.toString().substring(0, 4)}';
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
          await SqlDb().insertImage(file.path, _generateDefaultName(file.path));
          setState(() => _importedCount++);
        } catch (e) {
          debugPrint('Erreur lors de l\'importation: $e');
        }
      }

      await _loadImagesFromDatabase();
      setState(() => _isImporting = false);

      _showImportResultSnackbar();
    }
  }

  void _showImportResultSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                _importedCount == _totalToImport
                    ? Icons.check_circle
                    : Icons.warning,
                color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _importedCount == _totalToImport
                    ? 'Toutes les images ($_importedCount) ont été importées'
                    : '$_importedCount/$_totalToImport images importées',
              ),
            ),
          ],
        ),
        backgroundColor:
            _importedCount == _totalToImport ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  void _showSnackbar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveImageName(int index) async {
    final name = _nameControllers[index].text.trim();

    if (name.isEmpty) {
      _showSnackbar(
          "Le nom ne peut pas être vide", Colors.orange, Icons.warning);
      return;
    }

    final imagePath = _images[index].path;
    final imagesFromDb = await SqlDb().getGalleryImages();
    final imageToUpdate =
        imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

    await SqlDb().updateImageName(imageToUpdate['id'], name);

    _showSnackbar("Nom sauvegardé", Colors.green, Icons.check_circle);

    // Perte le focus après sauvegarde
    FocusScope.of(context).unfocus();
  }

  Future<void> _removeImage(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Êtes-vous sûr de vouloir supprimer cette image ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final imagePath = _images[index].path;
      final imagesFromDb = await SqlDb().getGalleryImages();
      final imageToDelete =
          imagesFromDb.firstWhere((image) => image['image_path'] == imagePath);

      await SqlDb().deleteImage(imageToDelete['id']);

      _showSnackbar(
          "Image supprimée avec succès", Colors.green, Icons.check_circle);

      await _loadImagesFromDatabase();
    }
  }

 void _selectImageAndReturn() {
  if (selectedImage != null) {
    // Retourner le fichier avec son chemin absolu
    Navigator.pop(context, File(selectedImage!.path));
  } else {
    _showSnackbar(
        "Veuillez sélectionner une image", Colors.orange, Icons.warning);
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

  Widget _buildImageCard(int index) {
    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          setState(() => selectedImage = _images[index]);
        }
      },
      child: Card(
        elevation: selectedImage == _images[index] ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selectedImage == _images[index]
                ? Theme.of(context).primaryColor
                : Colors.grey.withOpacity(0.2),
            width: selectedImage == _images[index] ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  if (selectedImage == _images[index])
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  if (!widget.isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeImage(index),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Text(
                _nameControllers[index].text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selectedImage == _images[index]
                      ? Theme.of(context).primaryColor
                      : Colors.grey[700],
                  fontWeight: selectedImage == _images[index]
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (!widget.isSelectionMode)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                child: TextFormField(
                  controller: _nameControllers[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  maxLength: 30,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.edit,
                        size: 18, color: Colors.grey), // <-- Ajouté ici
                    hintText: 'Nom de l\'image',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Theme.of(context).primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    suffixIcon: _nameControllers[index].text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.check, size: 18),
                            tooltip: "Sauvegarder le nom de l'image",
                            onPressed: () => _saveImageName(index),
                          )
                        : null,
                  ),
                  onFieldSubmitted: (value) => _saveImageName(index),
                  onChanged: (value) {
                    if (value.length == 30) {
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Rechercher par nom',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          _loadImagesFromDatabase();
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onChanged: _searchImagesByName,
                  ),
                ),
                if (!widget.isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 250,
                      child: ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text(
                          "Importer depuis la galerie",
                          style: TextStyle(color: Colors.blue),
                        ),
                        style: ElevatedButton.styleFrom(
                          iconColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _images.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.photo_library,
                                size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              "Aucune image disponible",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Ajoutez des images depuis votre galerie\nou prenez une nouvelle photo",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) => _buildImageCard(index),
                      ),
              ],
            ),
          ),
          if (_isImporting)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Importation en cours...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_importedCount/$_totalToImport',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_importedCount > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _importedCount / _totalToImport,
                        backgroundColor: Colors.grey[600],
                        color: Colors.lightBlueAccent,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
