import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/product.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:intl/intl.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;
  final Function refreshData;

  const AddProductScreen({
    Key? key,
    this.product,
    required this.refreshData,
  }) : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
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

  @override
  void initState() {
    super.initState();
    // If a product is passed, populate the fields with the product data
    if (widget.product != null) {
      codeController.text = widget.product!.code;
      designationController.text = widget.product!.designation;
      stockController.text = widget.product!.stock.toString();
      priceHTController.text = widget.product!.prixHT.toString();
      taxController.text = widget.product!.taxe.toString();
      priceTTCController.text = widget.product!.prixTTC.toString();
      dateController.text = widget.product!.dateExpiration;
      selectedCategoryId = widget.product!.categoryId;
      selectedSubCategoryId = widget.product!.subCategoryId;
    }

    taxController.addListener(calculatePriceTTC);
    priceHTController.addListener(calculatePriceTTC);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.product == null
            ? const Text(
                'Ajouter un Produit',
                style: TextStyle(color: Colors.white), // White text for contrast
              )
            : const Text(
                'Modifier le Produit',
                style: TextStyle(color: Colors.white), // White text for contrast
              ),
        backgroundColor: const Color(0xFF0056A6), // Deep Blue for app bar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Row(
            children: [
              // Left Side: Product Form
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextFormField(
                        controller: codeController,
                        label: 'Code à Barre',
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
                              int.parse(value) <= 0) {
                            return 'Le stock doit être un nombre entier positif.';
                          }
                          return null;
                        },
                      ),
                      _buildTextFormField(
                        controller: priceHTController,
                        label: 'Prix dachat',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le champ "Prix dachat" ne doit pas être vide.';
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
                            return 'Le champ "Taxe (%)" ne doit pas être vide.';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'La taxe doit être un nombre positif.';
                          }
                          return null;
                        },
                      ),
                      _buildTextFormField(
                        controller: priceTTCController,
                        label: 'Prix TTC',
                        enabled: false,
                      ),
                      _buildTextFormField(
                        controller: dateController,
                        label: 'Date Expiration',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le champ "Date Expiration" ne doit pas être vide.';
                          }

                          List<String> possibleFormats = [
                            "dd-MM-yyyy",
                            "MM-dd-yyyy",
                            "yyyy-MM-dd",
                            "dd/MM/yyyy",
                            "MM/dd/yyyy"
                          ];

                          DateTime? date;

                          for (String format in possibleFormats) {
                            try {
                              date = DateFormat(format).parseStrict(value);
                              break; // Dès qu'un format fonctionne, on arrête la boucle
                            } catch (e) {
                              continue;
                            }
                          }

                          if (date == null) {
                            return 'Format de date invalide. Utilisez un format correct (ex: JJ-MM-AAAA).';
                          }

                          if (!date.isAfter(DateTime.now())) {
                            return 'La date doit être dans le futur.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category Selection with Add Button
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<List<Category>>(
                              future: sqldb.getCategories(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator(
                                    color: Color(0xFF0056A6), // Deep Blue for loader
                                  );
                                }
                                categories = snapshot.data!;
                                if (categories.isEmpty) {
                                  return const Text(
                                    "Aucune catégorie disponible",
                                    style: TextStyle(color: Color(0xFF0056A6)), // Deep Blue text
                                  );
                                }
                                return DropdownButtonFormField<int>(
                                  decoration: _inputDecoration('Catégorie'),
                                  value: selectedCategoryId,
                                  items: categories.map((cat) {
                                    return DropdownMenuItem<int>(
                                      value: cat.id,
                                      child: Text(
                                        cat.name,
                                        style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)), // Deep Blue text
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
                                                  style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)), // Deep Blue text
                                                ),
                                              ))
                                          .toList();
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return "Veuillez sélectionner une catégorie";
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Add category button
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
                      const SizedBox(height: 16),
                      // Subcategory Dropdown (Visible when a category is selected)
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
                          validator: (value) {
                            if (value == null) {
                              return "Veuillez sélectionner une sous-catégorie";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const VerticalDivider(width: 20, thickness: 2, color: Color(0xFFE0E0E0)), // Light Gray divider

              // Right Side: Category Form (Visible on "+" Click)
              Expanded(
                flex: 1,
                child: isCategoryFormVisible
                    ? AddCategory()
                    : Center(
                        child: Text(
                          "Cliquez sur '+' pour ajouter une catégorie",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_formKey.currentState!.validate()) {
            if (selectedCategoryId == null || selectedSubCategoryId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Veuillez sélectionner une catégorie et une sous-catégorie.',
                    style: TextStyle(color: Colors.white), // White text for contrast
                  ),
                  backgroundColor: const Color(0xFFE53935), // Warm Red for error
                ),
              );
              return;
            }

            final updatedProduct = Product(
              code: codeController.text,
              designation: designationController.text,
              stock: int.tryParse(stockController.text) ?? 0,
              prixHT: double.tryParse(priceHTController.text) ?? 0.0,
              taxe: double.tryParse(taxController.text) ?? 0.0,
              prixTTC: double.tryParse(priceTTCController.text) ?? 0.0,
              dateExpiration: dateController.text,
              categoryId: selectedCategoryId!,
              subCategoryId: selectedSubCategoryId!,
            );

            if (widget.product == null) {
              // Adding a new product
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
            } else {
              // Editing the existing product
              await sqldb.updateProduct(updatedProduct);
              print("update product done");
            }

            widget.refreshData(); // Refresh the product list after saving
            Navigator.of(context).pop();
          }
        },
        backgroundColor: const Color(0xFF009688), // Teal Green for FAB
        child: const Icon(Icons.save, color: Colors.white), // White icon for contrast
      ),
    );
  }

  Widget _buildTextFormField({
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
        decoration: _inputDecoration(label),
        keyboardType: keyboardType,
        enabled: enabled,
        validator: validator,
        style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)), // Deep Blue text
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
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
}