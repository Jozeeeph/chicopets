import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Addprod {
  static void showAddProductPopup({
    required BuildContext context,
    required VoidCallback refreshData,
  }) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController margeController = TextEditingController();
    final TextEditingController remiseMaxController = TextEditingController();
    final TextEditingController remiseValeurMaxController = TextEditingController();
    final TextEditingController priceVenteHTController = TextEditingController();
    final TextEditingController profitController = TextEditingController();

    final SqlDb sqldb = SqlDb();

    int? selectedCategoryId;
    int? selectedSubCategoryId;
    bool isCategoryFormVisible = false;
    List<Category> categories = [];
    List<SubCategory> subCategories = [];
    bool hasExpirationDate = false;
    bool sellable = true;
    double? selectedTax = 0.0;

    void calculateValues() {
      double prixAchatHT = double.tryParse(priceHTController.text) ?? 0.0;
      double marge = double.tryParse(margeController.text) ?? 0.0;
      double taxe = double.tryParse(taxController.text) ?? 0.0;
      double profit = double.tryParse(profitController.text) ?? 0.0;

      if (priceHTController.text.isNotEmpty) {
        if (margeController.text.isNotEmpty) {
          double prixVenteHT = prixAchatHT * (1 + marge / 100);
          priceVenteHTController.text = prixVenteHT.toStringAsFixed(2);
          profitController.text = (prixVenteHT - prixAchatHT).toStringAsFixed(2);
          double prixTTC = prixVenteHT * (1 + taxe / 100);
          priceTTCController.text = prixTTC.toStringAsFixed(2);
        } else if (profitController.text.isNotEmpty) {
          double prixVenteHT = prixAchatHT + profit;
          priceVenteHTController.text = prixVenteHT.toStringAsFixed(2);
          margeController.text = ((profit / prixAchatHT) * 100).toStringAsFixed(2);
          double prixTTC = prixVenteHT * (1 + taxe / 100);
          priceTTCController.text = prixTTC.toStringAsFixed(2);
        }
      }
      if (taxController.text.isNotEmpty && priceVenteHTController.text.isNotEmpty) {
        double prixVenteHT = double.tryParse(priceVenteHTController.text) ?? 0.0;
        double prixTTC = prixVenteHT * (1 + taxe / 100);
        priceTTCController.text = prixTTC.toStringAsFixed(2);
      }
    }

    void calculerRemiseValeurMax() {
      double profit = double.tryParse(profitController.text) ?? 0;
      double remiseMax = double.tryParse(remiseMaxController.text) ?? 0;
      double remiseValeurMax = (profit * remiseMax) / 100;
      remiseValeurMaxController.text = remiseValeurMax.toStringAsFixed(2);
    }

    void _loadSubCategories(int categoryId) async {
      final dbClient = await sqldb.db;
      final subCategoriesData = await dbClient.query(
        'sub_categories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      subCategories = subCategoriesData.map((subCat) {
        return SubCategory(
          id: subCat['id_sub_category'] as int,
          name: subCat['sub_category_name'] as String,
          parentId: subCat['parent_id'] as int?,
          categoryId: subCat['category_id'] as int,
        );
      }).toList();
    }

    void initListeners() {
      priceHTController.addListener(calculateValues);
      taxController.addListener(calculateValues);
      margeController.addListener(calculateValues);
      profitController.addListener(calculateValues);
      remiseMaxController.addListener(calculerRemiseValeurMax);
    }

    void disposeListeners() {
      priceHTController.removeListener(calculateValues);
      taxController.removeListener(calculateValues);
      margeController.removeListener(calculateValues);
      profitController.removeListener(calculateValues);
      remiseMaxController.removeListener(calculerRemiseValeurMax);
    }

    initListeners();

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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0056A6),
                ),
              ),
              content: SizedBox(
                width: 800,
                height: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTextFormField(
                          controller: codeController,
                          label: 'Code à Barre',
                          keyboardType: TextInputType.text,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ce champ est obligatoire';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: designationController,
                          label: 'Désignation',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ce champ est obligatoire';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: descriptionController,
                          label: 'Description',
                          maxLines: 2,
                        ),
                        _buildTextFormField(
                          controller: stockController,
                          label: 'Stock',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ce champ est obligatoire';
                            }
                            if (int.tryParse(value) == null || int.parse(value) < 0) {
                              return 'Valeur invalide';
                            }
                            return null;
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: priceHTController,
                                label: 'Prix d\'achat HT',
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ce champ est obligatoire';
                                  }
                                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                    return 'Doit être > 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: priceVenteHTController,
                                decoration: _inputDecoration('Prix Vente HT'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                enabled: false,
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: margeController,
                                label: 'Marge (%)',
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ce champ est obligatoire';
                                  }
                                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                    return 'Doit être > 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: profitController,
                                decoration: _inputDecoration('Profit'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<double>(
                                decoration: _inputDecoration('Taxe (%)'),
                                value: selectedTax,
                                items: const [
                                  DropdownMenuItem(value: 0.0, child: Text('0%')),
                                  DropdownMenuItem(value: 7.0, child: Text('7%')),
                                  DropdownMenuItem(value: 12.0, child: Text('12%')),
                                  DropdownMenuItem(value: 19.0, child: Text('19%')),
                                ],
                                onChanged: (value) {
                                  if (value != null && [0.0, 7.0, 12.0, 19.0].contains(value)) {
                                    setState(() {
                                      selectedTax = value;
                                      taxController.text = value.toString();
                                    });
                                    calculateValues();
                                  } else {
                                    setState(() {
                                      selectedTax = 0.0;
                                      taxController.text = '0.0';
                                    });
                                  }
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Veuillez sélectionner une taxe';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: priceTTCController,
                                decoration: _inputDecoration('Prix TTC'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: remiseMaxController,
                                label: 'Remise Max (%)',
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final remise = double.tryParse(value) ?? 0.0;
                                    if (remise < 0 || remise > 100) {
                                      return 'Doit être entre 0 et 100';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: remiseValeurMaxController,
                                decoration: _inputDecoration('Valeur Remise Max'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        CheckboxListTile(
                          title: const Text('Ce produit a-t-il une date d\'expiration ?'),
                          value: hasExpirationDate,
                          onChanged: (value) {
                            setState(() {
                              hasExpirationDate = value ?? false;
                              if (!hasExpirationDate) {
                                dateController.clear();
                              }
                            });
                          },
                        ),
                        Visibility(
                          visible: hasExpirationDate,
                          child: _buildTextFormField(
                            controller: dateController,
                            label: 'Date d\'expiration',
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                dateController.text = DateFormat('dd-MM-yyyy').format(date);
                              }
                            },
                          ),
                        ),
                        Row(
                          children: [
                            const Text('Vendable: ', style: TextStyle(color: Color(0xFF0056A6))),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: sellable,
                                  onChanged: (value) {
                                    setState(() {
                                      sellable = value ?? true;
                                    });
                                  },
                                  activeColor: const Color(0xFF0056A6),
                                ),
                                const Text('Oui'),
                                const SizedBox(width: 16),
                                Radio<bool>(
                                  value: false,
                                  groupValue: sellable,
                                  onChanged: (value) {
                                    setState(() {
                                      sellable = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF0056A6),
                                ),
                                const Text('Non'),
                              ],
                            ),
                          ],
                        ),
                        FutureBuilder<List<Category>>(
                          future: sqldb.getCategories(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator(color: Color(0xFF0056A6));
                            }
                            if (snapshot.hasError) {
                              return Text('Erreur: ${snapshot.error}');
                            }

                            categories = snapshot.data ?? [];
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        decoration: _inputDecoration('Catégorie'),
                                        value: selectedCategoryId,
                                        items: categories.map((category) {
                                          return DropdownMenuItem<int>(
                                            value: category.id,
                                            child: Text(
                                              category.name,
                                              style: const TextStyle(color: Color(0xFF0056A6)),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedCategoryId = val;
                                            selectedSubCategoryId = null;
                                            if (val != null) {
                                              _loadSubCategories(val);
                                            }
                                          });
                                        },
                                        validator: (value) => value == null ? "Sélectionnez une catégorie" : null,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Color(0xFF26A9E0)),
                                      onPressed: () {
                                        setState(() {
                                          isCategoryFormVisible = !isCategoryFormVisible;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                if (selectedCategoryId != null && subCategories.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Sous-catégorie (optionnelle)',
                                        style: TextStyle(color: Color(0xFF0056A6)),
                                      ),
                                      SubCategoryTree(
                                        subCategories: subCategories,
                                        parentId: null,
                                        onSelect: (subCategoryId) {
                                          setState(() {
                                            selectedSubCategoryId = subCategoryId;
                                          });
                                        },
                                        selectedSubCategoryId: selectedSubCategoryId,
                                      ),
                                    ],
                                  ),
                              ],
                            );
                          },
                        ),
                        if (isCategoryFormVisible)
                          AddCategory(
                            onCategoryAdded: () async {
                              categories = await sqldb.getCategories();
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  style: _buttonStyle(const Color(0xFFE53935)),
                  onPressed: () {
                    disposeListeners();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annuler', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: _buttonStyle(const Color(0xFF009688)),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      if (selectedCategoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sélectionnez une catégorie'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final categoryName = await sqldb.getCategoryNameById(selectedCategoryId!);
                      final subCategoryName = selectedSubCategoryId != null
                          ? await sqldb.getSubCategoryNameById(selectedSubCategoryId!)
                          : '';

                      final newProduct = Product(
                        code: codeController.text,
                        designation: designationController.text,
                        description: descriptionController.text,
                        stock: int.parse(stockController.text),
                        prixHT: double.parse(priceHTController.text),
                        taxe: selectedTax ?? 0.0,
                        prixTTC: double.parse(priceTTCController.text),
                        dateExpiration: hasExpirationDate ? dateController.text : '',
                        categoryId: selectedCategoryId!,
                        subCategoryId: selectedSubCategoryId,
                        categoryName: categoryName,
                        subCategoryName: subCategoryName,
                        marge: double.parse(margeController.text),
                        remiseMax: double.tryParse(remiseMaxController.text) ?? 0.0,
                        remiseValeurMax: double.tryParse(remiseValeurMaxController.text) ?? 0.0,
                        hasVariants: false,
                        sellable: sellable,
                      );

                      try {
                        final productId = await sqldb.addProduct(newProduct);
                        debugPrint('Produit ajouté avec ID: $productId');
                        disposeListeners();
                        refreshData();
                        Navigator.of(context).pop();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => disposeListeners());
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF0056A6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF26A9E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0056A6), width: 2),
      ),
    );
  }

  static ButtonStyle _buttonStyle(Color backgroundColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
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
    FormFieldValidator<String>? validator,
    bool enabled = true,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(label),
        keyboardType: keyboardType,
        enabled: enabled,
        validator: validator,
        maxLines: maxLines,
        onTap: onTap,
      ),
    );
  }
}

class SubCategoryTree extends StatelessWidget {
  final List<SubCategory> subCategories;
  final int? parentId;
  final int? selectedSubCategoryId;
  final Function(int) onSelect;

  const SubCategoryTree({
    required this.subCategories,
    this.parentId,
    required this.onSelect,
    this.selectedSubCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    final children = subCategories.where((subCat) => subCat.parentId == parentId).toList();

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final subCat = children[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(subCat.name),
              onTap: () => onSelect(subCat.id!),
              tileColor: selectedSubCategoryId == subCat.id ? Colors.blue[50] : null,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: SubCategoryTree(
                subCategories: subCategories,
                parentId: subCat.id,
                onSelect: onSelect,
                selectedSubCategoryId: selectedSubCategoryId,
              ),
            ),
          ],
        );
      },
    );
  }
}