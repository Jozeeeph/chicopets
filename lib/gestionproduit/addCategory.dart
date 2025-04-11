import 'dart:io';
import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/gestionproduit/products_to_delete_screen.dart';
import 'package:caissechicopets/gallery_page.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:image_picker/image_picker.dart';

class AddCategory extends StatefulWidget {
  final Future<void> Function() onCategoryAdded;
  
  const AddCategory({Key? key, required this.onCategoryAdded}) : super(key: key);

  @override
  _AddCategoryState createState() => _AddCategoryState();
}

class _AddCategoryState extends State<AddCategory> {
  // Color palette
  static const Color deepBlue = Color(0xFF0056A6);
  static const Color darkBlue = Color.fromARGB(255, 1, 42, 79);
  static const Color white = Colors.white;
  static const Color lightGray = Color(0xFFE0E0E0);
  static const Color tealGreen = Color(0xFF009688);
  static const Color warmRed = Color(0xFFE53935);

  // Controllers and state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subCategoryNameController = TextEditingController();
  final TextEditingController _editSubCategoryController = TextEditingController();
  
  File? _selectedImage;
  final SqlDb _sqldb = SqlDb();
  bool _isVisible = false;
  int? _selectedCategoryId;
  List<Category> _categories = [];
  List<SubCategory> _subCategories = [];
  Category? _categoryToEdit;
  int? _selectedParentSubCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Category) {
      _categoryToEdit = args;
      _nameController.text = _categoryToEdit!.name;
      _selectedCategoryId = _categoryToEdit!.id;
      if (_categoryToEdit!.imagePath != null) {
        _selectedImage = File(_categoryToEdit!.imagePath!);
      }

      if (_selectedCategoryId != null) {
        _fetchSubCategories(_selectedCategoryId!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subCategoryNameController.dispose();
    _editSubCategoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final fetchedCategories = await _sqldb.getCategories();
      setState(() {
        _categories = fetchedCategories;
      });
    } catch (e) {
      _showMessage("Erreur lors du chargement des catégories");
    }
  }

  Future<void> _fetchSubCategories(int categoryId) async {
    try {
      final fetchedSubCategories = await _sqldb.getSubCategoriesByCategory(categoryId);
      
      setState(() {
        _subCategories = fetchedSubCategories.map((map) {
          return SubCategory(
            id: map['id_sub_category'],
            name: map['sub_category_name'] ?? 'Unknown',
            parentId: map['parent_id'],
            categoryId: map['category_id'] ?? 0,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint("Error fetching subcategories: $e");
      _showMessage("Erreur lors du chargement des sous-catégories");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final selectedImageFromGallery = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GalleryPage(isSelectionMode: true),
      ),
    );

    if (selectedImageFromGallery is File) {
      setState(() {
        _selectedImage = selectedImageFromGallery;
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Choisir la source de l'image"),
          content: const Text("Voulez-vous choisir une image depuis la galerie ou depuis votre appareil ?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
              child: const Text("Galerie"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage();
              },
              child: const Text("Appareil"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCategory() async {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      _showMessage("Veuillez remplir tous les champs");
      return;
    }

    try {
      final categoryId = await _sqldb.addCategory(_nameController.text, _selectedImage!.path);
      if (categoryId > 0) {
        final sortedSubCategories = _sortSubCategoriesByParent(_subCategories);
        final tempIdToRealId = <int, int>{};

        // Add parent subcategories first
        for (final subCategory in sortedSubCategories.where((sc) => sc.parentId == null)) {
          final subCategoryId = await _sqldb.addSubCategory(
            SubCategory(
              name: subCategory.name,
              parentId: subCategory.parentId,
              categoryId: categoryId,
            ),
          );
          tempIdToRealId[subCategory.id ?? -1] = subCategoryId;
        }

        // Then add child subcategories
        for (final subCategory in sortedSubCategories.where((sc) => sc.parentId != null)) {
          final realParentId = tempIdToRealId[subCategory.parentId] ?? -1;
          if (realParentId != -1) {
            await _sqldb.addSubCategory(
              SubCategory(
                name: subCategory.name,
                parentId: realParentId,
                categoryId: categoryId,
              ),
            );
          }
        }

        _showMessageSuccess("Catégorie ajoutée avec succès");
        await widget.onCategoryAdded();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showMessage("Échec de l'ajout de la catégorie");
      }
    } catch (e) {
      _showMessage("Erreur lors de l'ajout de la catégorie: $e");
    }
  }

  List<SubCategory> _sortSubCategoriesByParent(List<SubCategory> subCategories) {
    final sortedSubCategories = <SubCategory>[];
    final remainingSubCategories = List<SubCategory>.from(subCategories);

    while (remainingSubCategories.isNotEmpty) {
      for (final subCategory in remainingSubCategories.toList()) {
        if (subCategory.parentId == null || 
            sortedSubCategories.any((sc) => sc.id == subCategory.parentId)) {
          sortedSubCategories.add(subCategory);
          remainingSubCategories.remove(subCategory);
        }
      }
    }

    return sortedSubCategories;
  }

  Future<void> _updateCategory() async {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      _showMessage("Veuillez remplir tous les champs");
      return;
    }

    try {
      final result = await _sqldb.updateCategory(
        _categoryToEdit!.id!,
        _nameController.text,
        _selectedImage!.path,
      );

      if (result > 0) {
        for (final subCategory in _subCategories) {
          if (subCategory.id == null) {
            await _sqldb.addSubCategory(
              SubCategory(
                name: subCategory.name,
                parentId: subCategory.parentId,
                categoryId: _categoryToEdit!.id!,
              ),
            );
          } else {
            final updateResult = await _sqldb.updateSubCategory(subCategory);
            if (updateResult <= 0) {
              _showMessage("Échec de la mise à jour de la sous-catégorie: ${subCategory.name}");
            }
          }
        }

        _showMessageSuccess("Catégorie mise à jour avec succès");
        await widget.onCategoryAdded();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showMessage("Échec de la mise à jour de la catégorie");
      }
    } catch (e) {
      _showMessage("Erreur lors de la mise à jour: $e");
    }
  }

  Future<void> _addSubCategory() async {
    if (_subCategoryNameController.text.isEmpty) {
      _showMessage("Veuillez entrer un nom de sous-catégorie");
      return;
    }

    try {
      final subCategoryId = await _sqldb.addSubCategory(
        SubCategory(
          name: _subCategoryNameController.text,
          parentId: _selectedParentSubCategoryId,
          categoryId: _selectedCategoryId ?? _categoryToEdit?.id ?? 0,
        ),
      );

      if (subCategoryId > 0) {
        setState(() {
          _subCategories.add(
            SubCategory(
              id: subCategoryId,
              name: _subCategoryNameController.text,
              parentId: _selectedParentSubCategoryId,
              categoryId: _selectedCategoryId ?? _categoryToEdit?.id ?? 0,
            ),
          );
          _subCategoryNameController.clear();
          _selectedParentSubCategoryId = null;
        });
      } else {
        _showMessage("Échec de l'ajout de la sous-catégorie");
      }
    } catch (e) {
      _showMessage("Erreur lors de l'ajout: $e");
    }
  }

  Future<void> _confirmDeleteSubCategory(int subCategoryId) async {
    final productCodes = await _sqldb.getProductsInSubCategory(subCategoryId);

    if (productCodes.isNotEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => _buildDeleteBlockedDialog(context, productCodes),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDeleteDialog(context),
    ) ?? false;

    if (confirm) {
      final result = await _sqldb.deleteSubCategory(subCategoryId);
      if (result > 0) {
        _showMessageSuccess("Sous-catégorie supprimée avec succès");
        if (_selectedCategoryId != null) {
          await _fetchSubCategories(_selectedCategoryId!);
        }
      } else if (result == -2) {
        _showMessage("Cette sous-catégorie contient des produits");
      } else {
        _showMessage("Échec de la suppression");
      }
    }
  }

  Widget _buildDeleteBlockedDialog(BuildContext context, List<String> productCodes) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        children: const [
          Icon(Icons.error_outline, size: 36, color: Colors.deepOrange),
          SizedBox(height: 6),
          Text(
            "Suppression bloquée",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Cette sous-catégorie contient des produits:"),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.blueGrey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Pour supprimer cette sous-catégorie, vous devez "
                  "d'abord supprimer tous les produits associés.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Text(
                  "${productCodes.length} produit(s) concerné(s)",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: const BorderSide(color: Colors.grey),
          ),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductsToDeleteScreen(
                  productCodes: productCodes,
                  onProductsDeleted: () {
                    if (_selectedCategoryId != null) {
                      _fetchSubCategories(_selectedCategoryId!);
                    }
                  },
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
          child: const Text("Voir les produits"),
        ),
      ],
    );
  }

  Widget _buildConfirmDeleteDialog(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "Confirmer la suppression",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: const Text(
        "Êtes-vous sûr de vouloir supprimer cette sous-catégorie ?",
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text("Supprimer", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _editSubCategory(SubCategory subCategory) async {
    _editSubCategoryController.text = subCategory.name;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier la sous-catégorie"),
        content: TextFormField(
          controller: _editSubCategoryController,
          decoration: const InputDecoration(labelText: 'Nom de la sous-catégorie'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              if (_editSubCategoryController.text.isEmpty) {
                _showMessage("Veuillez entrer un nom valide");
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    ) ?? false;

    if (result && mounted) {
      setState(() {
        _subCategories = _subCategories.map((sc) {
          if (sc.id == subCategory.id) {
            return SubCategory(
              id: sc.id,
              name: _editSubCategoryController.text,
              parentId: sc.parentId,
              categoryId: sc.categoryId,
            );
          }
          return sc;
        }).toList();
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: warmRed,
      ),
    );
  }

  void _showMessageSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: tealGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _categoryToEdit == null ? 'Ajouter une catégorie' : 'Modifier la catégorie',
          style: const TextStyle(color: white),
        ),
        backgroundColor: deepBlue,
        iconTheme: const IconThemeData(color: white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryCard(),
                  const SizedBox(height: 20),
                  _buildSubCategoryCard(),
                ],
              ),
            ),
          ),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category, color: deepBlue),
                const SizedBox(width: 8),
                Text(
                  'Informations de la catégorie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _nameController,
              label: 'Nom de la catégorie',
              icon: Icons.text_fields,
            ),
            const SizedBox(height: 16),
            const Text(
              "Image de la catégorie",
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildImagePreview(),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 190,
                child: ElevatedButton.icon(
                  onPressed: _showImageSourceDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.image_search, color: white),
                  label: const Text(
                    "Choisir une image",
                    style: TextStyle(color: white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 220,
              minHeight: 70,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Image.file(_selectedImage!, fit: BoxFit.cover),
          ),
        ),
      );
    } else {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: lightGray),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 40, color: lightGray),
            const SizedBox(height: 8),
            const Text(
              "Aucune image sélectionnée",
              style: TextStyle(color: lightGray),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSubCategoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, color: deepBlue),
                const SizedBox(width: 8),
                Text(
                  'Gestion des sous-catégories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _subCategoryNameController,
                    label: 'Nom de la sous-catégorie',
                    icon: Icons.text_snippet,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: lightGray),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButton<int>(
                    value: _selectedParentSubCategoryId,
                    hint: const Text('Parent', style: TextStyle(color: darkBlue)),
                    icon: const Icon(Icons.arrow_drop_down, color: deepBlue),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.horizontal_rule, size: 20, color: darkBlue),
                            SizedBox(width: 4),
                            Text('Aucun parent'),
                          ],
                        ),
                      ),
                      ..._subCategories.map((subCategory) {
                        return DropdownMenuItem<int>(
                          value: subCategory.id,
                          child: Text(subCategory.name),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedParentSubCategoryId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: tealGreen,
                  child: IconButton(
                    icon: const Icon(Icons.add, color: white),
                    onPressed: _addSubCategory,
                  ),
                ),
              ],
            ),
            if (_subCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Liste des sous-catégories",
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: lightGray),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SubCategoryTree(
                  subCategories: _subCategories,
                  parentId: null,
                  onEdit: _editSubCategory,
                  onDelete: _confirmDeleteSubCategory,
                  deepBlue: deepBlue,
                  tealGreen: tealGreen,
                  warmRed: warmRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: 240,
      child: ElevatedButton.icon(
        onPressed: _categoryToEdit == null ? _addCategory : _updateCategory,
        style: ElevatedButton.styleFrom(
          backgroundColor: deepBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: Icon(
          _categoryToEdit == null ? Icons.add : Icons.save,
          color: white,
        ),
        label: Text(
          _categoryToEdit == null ? "Ajouter la catégorie" : "Mettre à jour",
          style: const TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: darkBlue),
        prefixIcon: icon != null ? Icon(icon, color: deepBlue) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: deepBlue),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}

class SubCategoryTree extends StatelessWidget {
  final List<SubCategory> subCategories;
  final int? parentId;
  final Function(SubCategory) onEdit;
  final Function(int) onDelete;
  final Color deepBlue;
  final Color tealGreen;
  final Color warmRed;

  const SubCategoryTree({
    required this.subCategories,
    this.parentId,
    required this.onEdit,
    required this.onDelete,
    required this.deepBlue,
    required this.tealGreen,
    required this.warmRed,
  });

  @override
  Widget build(BuildContext context) {
    final children = subCategories.where((sc) => sc.parentId == parentId).toList();
    if (children.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final subCat = children[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  parentId == null ? Icons.folder : Icons.subdirectory_arrow_right,
                  color: deepBlue,
                ),
                title: Text(
                  subCat.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: tealGreen),
                      onPressed: () => onEdit(subCat),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: warmRed),
                      onPressed: () => onDelete(subCat.id!),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: SubCategoryTree(
                subCategories: subCategories,
                parentId: subCat.id,
                onEdit: onEdit,
                onDelete: onDelete,
                deepBlue: deepBlue,
                tealGreen: tealGreen,
                warmRed: warmRed,
              ),
            ),
          ],
        );
      },
    );
  }
}