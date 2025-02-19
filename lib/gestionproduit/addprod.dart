import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart'; // Ensure correct import

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
                height: 400,
                child: Row(
                  children: [
                    // Left Side: Product Form
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTextField(codeController, 'Code Barre'),
                            _buildTextField(designationController, 'Désignation'),
                            _buildTextField(stockController, 'Stock',
                                keyboardType: TextInputType.number),
                            _buildTextField(priceHTController, 'Prix dachat',
                                keyboardType: TextInputType.number),
                            _buildTextField(taxController, 'Taxe (%)',
                                keyboardType: TextInputType.number),
                            _buildTextField(priceTTCController, 'Prix TTC',
                                enabled: false),
                            _buildTextField(dateController, 'Date Expiration'),
                            const SizedBox(height: 16),

                            // Category Selection with Add Button
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
                                // Add category button
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
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (codeController.text.isEmpty ||
                        designationController.text.isEmpty ||
                        stockController.text.isEmpty ||
                        priceHTController.text.isEmpty ||
                        taxController.text.isEmpty ||
                        priceTTCController.text.isEmpty ||
                        dateController.text.isEmpty ||
                        selectedCategoryId == null) {
                      _showMessage(context, "Veuillez remplir tous les champs !");
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
                    );

                    Navigator.of(context).pop();
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
      {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
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
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}