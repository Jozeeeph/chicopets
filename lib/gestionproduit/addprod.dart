import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';

class Addprod {
  static void showAddProductPopup(BuildContext context, Function refreshData) {
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final SqlDb sqldb = SqlDb();

    int? selectedCategoryId;
    int? selectedSubCategoryId;
    bool isCategoryFormVisible = false;
    List<Category> categories = [];
    List<DropdownMenuItem<int>> subCategoryItems = [];

    void calculatePriceTTC() {
      if (priceHTController.text.isNotEmpty && taxController.text.isNotEmpty) {
        double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
        double taxe = double.tryParse(taxController.text) ?? 0.0;
        double prixTTC = prixHT + (prixHT * taxe / 100);
        priceTTCController.text = prixTTC.toStringAsFixed(2);
      } else {
        priceTTCController.clear();
      }
    }

    taxController.addListener(calculatePriceTTC);
    priceHTController.addListener(calculatePriceTTC);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: Colors.white, // White background for clarity
              title: const Text(
                'Ajouter un Produit',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0056A6), // Deep Blue for title
                ),
              ),
              content: SizedBox(
                width: 800,
                height: 500,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTextFormField(
                          controller: codeController,
                          label: 'Code à Barre',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Code à Barre" ne doit pas être vide.';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Le "Code à Barre" doit être un nombre.';
                            }
                            return null;
                          },
                        ),
                        FutureBuilder<List<Category>>(
                          future: sqldb.getCategories(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator(
                                color: Color(0xFF0056A6), // Deep Blue for loader
                            );
                            }

                            categories = snapshot.data!;
                            return DropdownButtonFormField<int>(
                              decoration: _inputDecoration('Catégorie'),
                              value: selectedCategoryId,
                              items: categories.map((category) {
                                return DropdownMenuItem<int>(
                                  value: category.id,
                                  child: Text(
                                    category.name,
                                    style: const TextStyle(color: Color(0xFF0056A6)), // Deep Blue text
                                ));
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedCategoryId = val;
                                  selectedSubCategoryId = null;
                                  subCategoryItems = categories
                                      .firstWhere((cat) => cat.id == val)
                                      .subCategories
                                      .map((subCat) => DropdownMenuItem<int>(
                                            value: subCat.id,
                                            child: Text(
                                              subCat.name,
                                              style: const TextStyle(color: Color(0xFF0056A6)), // Deep Blue text
                                            ),
                                          ))
                                      .toList();
                                });
                              },
                              validator: (value) => value == null
                                  ? "Veuillez sélectionner une catégorie"
                                  : null,
                            );
                          },
                        ),
                        Visibility(
                          visible: selectedCategoryId != null,
                          child: DropdownButtonFormField<int>(
                            decoration: _inputDecoration('Sous-catégorie'),
                            value: selectedSubCategoryId,
                            items: subCategoryItems,
                            onChanged: (val) {
                              setState(() {
                                selectedSubCategoryId = val;
                              });
                            },
                            validator: (value) => value == null
                                ? "Veuillez sélectionner une sous-catégorie"
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              "Ajouter une catégorie:",
                              style: TextStyle(color: Color(0xFF0056A6)), // Deep Blue text
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFF26A9E0)), // Sky Blue icon
                              onPressed: () {
                                setState(() {
                                  isCategoryFormVisible = !isCategoryFormVisible;
                                });
                              },
                            ),
                          ],
                        ),
                        if (isCategoryFormVisible) AddCategory(),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: _buttonStyle(const Color(0xFF009688)), // Teal Green for success
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (selectedSubCategoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Veuillez sélectionner une sous-catégorie"),
                            backgroundColor: Color(0xFFE53935), // Warm Red for error
                          ),
                        );
                        return;
                      }

                      await sqldb.addProduct(
                        codeController.text,
                        designationController.text,
                        int.tryParse(stockController.text) ?? 0,
                        double.tryParse(priceHTController.text) ?? 0.0,
                        double.tryParse(taxController.text) ?? 0.0,
                        double.tryParse(priceTTCController.text) ?? 0.0,
                        dateController.text,
                        selectedCategoryId!,
                        selectedSubCategoryId!,
                      );

                      refreshData();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
                    'Ajouter',
                    style: TextStyle(color: Colors.white), // White text for contrast
                  ),
                ),
                ElevatedButton(
                  style: _buttonStyle(const Color(0xFFE53935)), // Warm Red for cancel
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Colors.white), // White text for contrast
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF0056A6)), // Deep Blue for label
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)), // Light Gray border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF26A9E0)), // Sky Blue on focus
      ),
    );
  }

  static ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  static Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(label),
        keyboardType: keyboardType,
        enabled: enabled,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(color: Color(0xFF0056A6)), // Deep Blue text
      ),
    );
  }
}