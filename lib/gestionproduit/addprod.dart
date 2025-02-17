import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';

class Addprod{
  static void showAddProductPopup(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final SqlDb sqldb = SqlDb();

    // Variable pour stocker l'ID de la catégorie sélectionnée
    int? selectedCategoryId;

    // Fonction pour mettre à jour le prix TTC dynamiquement
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
        // Utilisation de StatefulBuilder pour pouvoir mettre à jour l'état (ex. sélection de la catégorie)
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ajouter un Produit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(codeController, 'Code Barre'),
                    _buildTextField(designationController, 'Désignation'),
                    _buildTextField(stockController, 'Stock',
                        keyboardType: TextInputType.number),
                    _buildTextField(priceHTController, 'Prix HT',
                        keyboardType: TextInputType.number),
                    _buildTextField(taxController, 'Taxe (%)',
                        keyboardType: TextInputType.number),
                    _buildTextField(priceTTCController, 'Prix TTC',
                        enabled: false),
                    _buildTextField(dateController, 'Date Expiration'),
                    const SizedBox(height: 16),
                    // Menu déroulant pour choisir la catégorie
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: sqldb.getCategories(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        List<Map<String, dynamic>> categories = snapshot.data!;
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
                              value: cat['id_category'],
                              child: Text(cat['category_name']),
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
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    // Validation des champs obligatoires
                    if (codeController.text.isEmpty ||
                        designationController.text.isEmpty ||
                        stockController.text.isEmpty ||
                        priceHTController.text.isEmpty ||
                        taxController.text.isEmpty ||
                        priceTTCController.text.isEmpty ||
                        dateController.text.isEmpty ||
                        selectedCategoryId == null) {
                      _showMessage(
                          context, "Veuillez remplir tous les champs !");
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
                      selectedCategoryId!, // Utilisation de l'ID de la catégorie sélectionnée
                    );

                    Navigator.of(context).pop(); // Fermer la popup
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ajouter',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Fermer la popup
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
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
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(); // This widget is not meant to be displayed
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
