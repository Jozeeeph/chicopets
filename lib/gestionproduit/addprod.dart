import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
              title: const Text('Ajouter un Produit'),
              content: SizedBox(
                width: 800,
                height: 500,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextFormField(controller: codeController, label: 'Code à Barre', validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le champ "Code à Barre" ne doit pas être vide.';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Le "Code à Barre" doit être un nombre.';
                        }
                        return null;
                      }),
                      
                      FutureBuilder<List<Category>>(
                        future: sqldb.getCategories(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          categories = snapshot.data!;
                          return DropdownButtonFormField<int>(
                            decoration: const InputDecoration(labelText: "Catégorie", border: OutlineInputBorder()),
                            value: selectedCategoryId,
                            items: categories.map((category) {
                              return DropdownMenuItem<int>(
                                value: category.id,
                                child: Text(category.name),
                              );
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
                                          child: Text(subCat.name),
                                        ))
                                    .toList();
                              });
                            },
                            validator: (value) => value == null ? "Veuillez sélectionner une catégorie" : null,
                          );
                        },
                      ),
                      
                      Visibility(
                        visible: selectedCategoryId != null,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: "Sous-catégorie", border: OutlineInputBorder()),
                          value: selectedSubCategoryId,
                          items: subCategoryItems,
                          onChanged: (val) {
                            setState(() {
                              selectedSubCategoryId = val;
                            });
                          },
                          validator: (value) => value == null ? "Veuillez sélectionner une sous-catégorie" : null,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text("Ajouter une catégorie:"),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.blue),
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
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
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

  static Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        keyboardType: keyboardType,
        enabled: enabled,
        validator: validator,
      ),
    );
  }
}