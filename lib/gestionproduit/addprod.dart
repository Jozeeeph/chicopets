import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/product.dart';

class Addprod {
  static void showAddProductPopup(BuildContext context, Function refreshData) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController margeController = TextEditingController();
    final TextEditingController remiseMaxController = TextEditingController();
    final TextEditingController remiseValeurMaxController =
        TextEditingController();

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

        double marge = prixTTC - prixHT;
        margeController.text = marge.toStringAsFixed(2);
      } else {
        priceTTCController.clear();
        margeController.clear();
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
              backgroundColor: Colors.white,
              title: Text(
                'Ajouter un Produit',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0056A6),
                ),
              ),
              content: SizedBox(
                width: 800,
                height: 500,
                child: Form(
                  key: formKey,
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
                        _buildTextFormField(
                          controller: designationController,
                          label: 'Désignation',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Désignation" ne doit pas être vide.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: stockController,
                          label: 'Stock',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Stock" ne doit pas être vide.';
                            }
                            if (int.tryParse(value) == null ||
                                int.parse(value) < 0) {
                              return 'Le stock doit être un nombre entier positif.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: priceHTController,
                          label: 'Prix HT',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Prix HT" ne doit pas être vide.';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) <= 0) {
                              return 'Le prix doit être un nombre positif.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: taxController,
                          label: 'Taxe (%)',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Taxe" ne doit pas être vide.';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) < 0) {
                              return 'La taxe doit être un nombre positif.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: priceTTCController,
                          label: 'Prix TTC',
                          keyboardType: TextInputType.number,
                          enabled: false,
                        ),
                        _buildTextFormField(
                          controller: margeController,
                          label: 'Marge',
                          keyboardType: TextInputType.number,
                          enabled: false,
                        ),
                        _buildTextFormField(
                          controller: remiseMaxController,
                          label: 'Remise Max (%)',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Remise Max" ne doit pas être vide.';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) < 0 ||
                                double.parse(value) > 100) {
                              return 'La remise doit être entre 0 et 100%.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: remiseValeurMaxController,
                          label: 'Valeur Remise Max',
                          keyboardType: TextInputType.number,
                          enabled: false,
                        ),
                        _buildTextFormField(
                          controller: dateController,
                          label: 'Date d\'expiration',
                        ),
                        FutureBuilder<List<Category>>(
                          future: sqldb
                              .getCategories(), // This dynamically calls the method
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator(
                                color: Color(0xFF0056A6),
                              );
                            }

                            categories = snapshot
                                .data!; // Categories fetched from the database
                            return DropdownButtonFormField<int>(
                              decoration: _inputDecoration('Catégorie'),
                              value: selectedCategoryId,
                              items: categories.map((category) {
                                return DropdownMenuItem<int>(
                                  value: category.id,
                                  child: Text(
                                    category.name,
                                    style: const TextStyle(
                                        color: Color(0xFF0056A6)),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedCategoryId = val;
                                  selectedSubCategoryId = null;

                                  // Find the category matching the selected value
                                  var selectedCategory = categories.firstWhere(
                                    (cat) => cat.id == val,
                                    orElse: () => Category(
                                      id: -1,
                                      name: 'Unknown',
                                      imagePath: '',
                                      subCategories: [],
                                    ),
                                  );

                                  // If the category is found, update subCategories
                                  subCategoryItems = selectedCategory
                                          .subCategories.isNotEmpty
                                      ? selectedCategory.subCategories
                                          .map((subCat) {
                                          return DropdownMenuItem<int>(
                                            value: subCat.id,
                                            child: Text(
                                              subCat.name,
                                              style: const TextStyle(
                                                  color: Color(0xFF0056A6)),
                                            ),
                                          );
                                        }).toList()
                                      : []; // If no subCategories, return an empty list
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
                              style: TextStyle(color: Color(0xFF0056A6)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add,
                                  color: Color(0xFF26A9E0)),
                              onPressed: () {
                                setState(() {
                                  isCategoryFormVisible =
                                      !isCategoryFormVisible;
                                });
                              },
                            ),
                          ],
                        ),
                        if (isCategoryFormVisible) const AddCategory(),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: _buttonStyle(Color(0xFF009688)),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      if (selectedCategoryId == null ||
                          selectedSubCategoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Veuillez sélectionner une catégorie et sous-catégorie"),
                              backgroundColor: Color(0xFFE53935)),
                        );
                        return;
                      }

                      final newProduct = Product(
                        code: codeController.text,
                        designation: designationController.text,
                        stock: int.tryParse(stockController.text) ?? 0,
                        prixHT: double.tryParse(priceHTController.text) ?? 0.0,
                        taxe: double.tryParse(taxController.text) ?? 0.0,
                        prixTTC:
                            double.tryParse(priceTTCController.text) ?? 0.0,
                        dateExpiration: dateController.text,
                        categoryId: selectedCategoryId!,
                        subCategoryId: selectedSubCategoryId!,
                        marge: double.tryParse(margeController.text) ?? 0.0,
                        remiseMax:
                            double.tryParse(remiseMaxController.text) ?? 0.0,
                        remiseValeurMax:
                            double.tryParse(remiseValeurMaxController.text) ??
                                0.0,
                      );

                      final productId = await sqldb.addProduct(newProduct);
                      print('Nouveau produit créé avec ID: $productId');

                      refreshData();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Ajouter',
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style: _buttonStyle(Color(0xFFE53935)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annuler',
                      style: TextStyle(color: Colors.white)),
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
      labelStyle: const TextStyle(color: Color(0xFF0056A6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF26A9E0)),
      ),
    );
  }

  static ButtonStyle _buttonStyle(Color backgroundColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  static Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label),
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
    );
  }
}
