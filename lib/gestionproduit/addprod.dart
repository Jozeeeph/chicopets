import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/variantprod.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart'; // Assurez-vous que l'import est correct
import 'package:caissechicopets/gestionproduit/addvariant.dart';

class Addprod {
  static void showAddProductPopup(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final SqlDb sqldb = SqlDb();

    int? selectedCategoryId;
    bool isCategoryFormVisible = false;
    bool hasVariants = false;
    List<VariantProd> variants = [];

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
                height: 600,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTextField(codeController, 'Code Barre'),
                            _buildTextField(designationController, 'Désignation'),
                            _buildTextField(stockController, 'Stock', keyboardType: TextInputType.number),
                            CheckboxListTile(
                              title: const Text('Ce produit a des variantes'),
                              value: hasVariants,
                              onChanged: (value) {
                                setState(() {
                                  hasVariants = value ?? false;
                                });
                              },
                            ),
                            if (!hasVariants) ...[
                              _buildTextField(priceHTController, 'Prix d\'achat', keyboardType: TextInputType.number),
                              _buildTextField(taxController, 'Taxe (%)', keyboardType: TextInputType.number),
                              _buildTextField(priceTTCController, 'Prix TTC', enabled: false),
                            ],
                            _buildTextField(dateController, 'Date Expiration'),
                            const SizedBox(height: 16),
                            if (hasVariants) ...[
                              ...variants.map((variant) {
                                return AddVariant.buildVariantFields(
                                  context,
                                  variant,
                                  (updatedVariant) {
                                    setState(() {
                                      variants[variants.indexOf(variant)] = updatedVariant;
                                    });
                                  },
                                );
                              }).toList(),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    variants.add(VariantProd(
                                      id: UniqueKey().toString(),
                                      productCode: codeController.text,
                                      size: '',
                                      prixHT: 0.0,
                                      taxe: 0.0,
                                      prixTTC: 0.0,
                                    ));
                                  });
                                },
                                child: const Text('Ajouter une variante'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: FutureBuilder<List<Category>>(
                                    future: sqldb.getCategories(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const CircularProgressIndicator();
                                      }
                                      List<Category> categories = snapshot.data!;
                                      if (categories.isEmpty) {
                                        return const Text("Aucune catégorie disponible");
                                      }
                                      return DropdownButtonFormField<int>(
                                        decoration: const InputDecoration(
                                          labelText: "Catégorie",
                                          border: OutlineInputBorder(),
                                        ),
                                        value: selectedCategoryId,
                                        items: categories.map((cat) {
                                          return DropdownMenuItem<int>(
                                            value: cat.id,
                                            child: Text(cat.name),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedCategoryId = val;
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
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 20, thickness: 2),
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
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (codeController.text.isEmpty ||
                        designationController.text.isEmpty ||
                        stockController.text.isEmpty ||
                        dateController.text.isEmpty ||
                        selectedCategoryId == null) {
                      _showMessage(context, "Veuillez remplir tous les champs !");
                      return;
                    }

                    if (!hasVariants &&
                        (priceHTController.text.isEmpty ||
                            taxController.text.isEmpty ||
                            priceTTCController.text.isEmpty)) {
                      _showMessage(context, "Veuillez remplir tous les champs !");
                      return;
                    }

                    try {
                      await sqldb.addProduct(
                        codeController.text,
                        designationController.text,
                        int.tryParse(stockController.text) ?? 0,
                        double.tryParse(priceHTController.text) ?? 0.0,
                        double.tryParse(taxController.text) ?? 0.0,
                        double.tryParse(priceTTCController.text) ?? 0.0,
                        dateController.text,
                        selectedCategoryId!,
                        hasVariants: hasVariants,
                      );

                      if (hasVariants) {
                        for (var variant in variants) {
                          await sqldb.addProductVariant(variant);
                        }
                        print(variants);
                      }

                      Navigator.of(context).pop();
                    } catch (e) {
                      _showMessage(context, "Erreur lors de l'ajout du produit: $e");
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

  static Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool enabled = true, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        enabled: enabled,
        onChanged: onChanged,
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
