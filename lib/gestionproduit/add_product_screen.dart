import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/variant.dart';
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
  final TextEditingController margeController = TextEditingController();
  final TextEditingController profitController = TextEditingController();
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  final SqlDb sqldb = SqlDb();
  double? selectedTax;

  int? selectedCategoryId;
  int? selectedSubCategoryId;
  bool isCategoryFormVisible = false;
  List<Category> categories = [];
  List<DropdownMenuItem<int>> subCategoryItems = [];

  // Variables pour la gestion des variantes
  bool hasVariants = false;
  List<Variant> variants = [];
  List<String> selectedSizes = [];
  List<String> selectedColors = [];
  List<String> selectedWeights = [];

  @override
  void initState() {
    super.initState();
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

      // Charger les sous-catégories de la catégorie sélectionnée
      _loadSubCategories(selectedCategoryId!);

      double marge = ((widget.product!.prixTTC - widget.product!.prixHT) / widget.product!.prixHT) * 100;
      margeController.text = marge.toStringAsFixed(2);

      double profit = widget.product!.prixTTC - widget.product!.prixHT;
      profitController.text = profit.toStringAsFixed(2);

      // Récupérer les variantes du produit
      _loadVariants();
    }

    priceHTController.addListener(calculateValues);
    taxController.addListener(calculateValues);
    margeController.addListener(calculateValues);
    profitController.addListener(calculateValues);
  }

  // Méthode pour charger les sous-catégories
 void _loadSubCategories(int categoryId) async {
  final dbClient = await sqldb.db;
  final subCategories = await dbClient.query(
    'sub_categories',
    where: 'category_id = ?',
    whereArgs: [categoryId],
  );

  setState(() {
    subCategoryItems = subCategories.map((subCat) {
      return DropdownMenuItem<int>(
        value: subCat['id_sub_category'] as int, // Cast to int
        child: Text(subCat['sub_category_name'] as String), // Cast to String
      );
    }).toList();
  });
}

  // Méthode pour charger les variantes
  void _loadVariants() async {
    if (widget.product != null) {
      final variantsFromDb = await sqldb.getVariantsByProductCode(widget.product!.code);
      setState(() {
        variants = variantsFromDb;
        hasVariants = variants.isNotEmpty;
      });
    }
  }

  void calculateValues() {
    double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
    double taxe = double.tryParse(taxController.text) ?? 0.0;
    double marge = double.tryParse(margeController.text) ?? 0.0;
    double profit = double.tryParse(profitController.text) ?? 0.0;

    if (priceHTController.text.isNotEmpty && margeController.text.isNotEmpty) {
      double prixTTC = prixHT * (1 + marge / 100);
      priceTTCController.text = prixTTC.toStringAsFixed(2);
      profitController.text = (prixTTC - prixHT).toStringAsFixed(2);
    } else if (priceHTController.text.isNotEmpty && profitController.text.isNotEmpty) {
      double prixTTC = prixHT + profit;
      priceTTCController.text = prixTTC.toStringAsFixed(2);
      margeController.text = ((profit / prixHT) * 100).toStringAsFixed(2);
    }

    if (taxController.text.isNotEmpty) {
      double prixTTC = double.tryParse(priceTTCController.text) ?? 0.0;
      double prixTTCWithTax = prixTTC * (1 + taxe / 100);
      priceTTCController.text = prixTTCWithTax.toStringAsFixed(2);
    }
  }

  void generateVariants() {
    variants.clear();
    if (selectedSizes.isNotEmpty && selectedColors.isNotEmpty) {
      // Générer des variantes avec taille et couleur
      for (var size in selectedSizes) {
        for (var color in selectedColors) {
          variants.add(Variant(
            code: '', // L'utilisateur saisira le code à barres
            productCode: codeController.text,
            combinationName: '$size-$color',
            price: 0.0, // L'utilisateur saisira le prix
            stock: 0, // L'utilisateur saisira le stock
            attributes: {'size': size, 'color': color},
          ));
        }
      }
    } else if (selectedSizes.isNotEmpty) {
      // Générer des variantes avec uniquement la taille
      for (var size in selectedSizes) {
        variants.add(Variant(
          code: '', // L'utilisateur saisira le code à barres
          productCode: codeController.text,
          combinationName: size,
          price: 0.0, // L'utilisateur saisira le prix
          stock: 0, // L'utilisateur saisira le stock
          attributes: {'size': size},
        ));
      }
    } else if (selectedColors.isNotEmpty) {
      // Générer des variantes avec uniquement la couleur
      for (var color in selectedColors) {
        variants.add(Variant(
          code: '', // L'utilisateur saisira le code à barres
          productCode: codeController.text,
          combinationName: color,
          price: 0.0, // L'utilisateur saisira le prix
          stock: 0, // L'utilisateur saisira le stock
          attributes: {'color': color},
        ));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.product == null
            ? const Text(
                'Ajouter un Produit',
                style: TextStyle(color: Colors.white),
              )
            : const Text(
                'Modifier le Produit',
                style: TextStyle(color: Colors.white),
              ),
        backgroundColor: const Color(0xFF0056A6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Checkbox pour les variantes
                      CheckboxListTile(
                        title: const Text('Ce produit a-t-il des variantes ?'),
                        value: hasVariants,
                        onChanged: (value) {
                          setState(() {
                            hasVariants = value ?? false;
                          });
                        },
                      ),
                      if (!hasVariants) ...[
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
                      ],
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
                      if (!hasVariants) ...[
                        _buildTextFormField(
                          controller: stockController,
                          label: 'Stock',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Stock" ne doit pas être vide.';
                            }
                            if (int.tryParse(value) == null || int.parse(value) <= 0) {
                              return 'Le stock doit être un nombre entier positif.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: priceHTController,
                          label: 'Prix d\'achat',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Prix d\'achat" ne doit pas être vide.';
                            }
                            if (double.tryParse(value) == null || double.parse(value) <= 0) {
                              return 'Le prix doit être un nombre positif.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: margeController,
                          label: 'Marge (%)',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Marge (%)" ne doit pas être vide.';
                            }
                            if (double.tryParse(value) == null || double.parse(value) <= 0) {
                              return 'La marge doit être un nombre positif.';
                            }
                            return null;
                          },
                        ),
                        _buildTextFormField(
                          controller: profitController,
                          label: 'Profit',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le champ "Profit" ne doit pas être vide.';
                            }
                            if (double.tryParse(value) == null || double.parse(value) <= 0) {
                              return 'Le profit doit être un nombre positif.';
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<double>(
                          decoration: _inputDecoration('Taxe (%)'),
                          value: selectedTax,
                          items: const [
                            DropdownMenuItem(value: 0.0, child: Text('0%')),
                            DropdownMenuItem(value: 7.0, child: Text('7%')),
                            DropdownMenuItem(value: 12.0, child: Text('12%')),
                            DropdownMenuItem(value: 19.0, child: Text('19%')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedTax = value;
                              taxController.text = value.toString();
                            });
                            calculateValues();
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Veuillez sélectionner une taxe.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: priceTTCController,
                          label: 'Prix TTC',
                        ),
                      ],
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
                              break;
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
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<List<Category>>(
                              future: sqldb.getCategories(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator(
                                    color: Color(0xFF0056A6),
                                  );
                                }
                                categories = snapshot.data!;
                                if (categories.isEmpty) {
                                  return const Text(
                                    "Aucune catégorie disponible",
                                    style: TextStyle(color: Color(0xFF0056A6)),
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
                                          style: const TextStyle(color: Colors.black),
                                        ));
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      selectedCategoryId = val;
                                      selectedSubCategoryId = null;
                                      _loadSubCategories(val!);
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
                            icon: const Icon(Icons.add, color: Color(0xFF26A9E0)),
                            onPressed: () {
                              setState(() {
                                isCategoryFormVisible = !isCategoryFormVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                      if (hasVariants) ...[
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: sizeController,
                          label: 'Ajouter une taille',
                          onFieldSubmitted: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                selectedSizes.add(value);
                                sizeController.clear();
                              });
                            }
                          },
                        ),
                        Wrap(
                          spacing: 8.0,
                          children: selectedSizes.map((size) {
                            return Chip(
                              label: Text(size),
                              onDeleted: () {
                                setState(() {
                                  selectedSizes.remove(size);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: colorController,
                          label: 'Ajouter une couleur',
                          onFieldSubmitted: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                selectedColors.add(value);
                                colorController.clear();
                              });
                            }
                          },
                        ),
                        Wrap(
                          spacing: 8.0,
                          children: selectedColors.map((color) {
                            return Chip(
                              label: Text(color),
                              onDeleted: () {
                                setState(() {
                                  selectedColors.remove(color);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: weightController,
                          label: 'Ajouter un poids',
                          onFieldSubmitted: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                selectedWeights.add(value);
                                weightController.clear();
                              });
                            }
                          },
                        ),
                        Wrap(
                          spacing: 8.0,
                          children: selectedWeights.map((weight) {
                            return Chip(
                              label: Text(weight),
                              onDeleted: () {
                                setState(() {
                                  selectedSizes.remove(weight);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: generateVariants,
                          child: const Text('Générer les variantes'),
                        ),
                        if (variants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Variantes générées :'),
                          DataTable(
                            columns: const [
                              DataColumn(label: Text('Combinaison')),
                              DataColumn(label: Text('Prix')),
                              DataColumn(label: Text('Stock')),
                              DataColumn(label: Text('Code à barre')),
                            ],
                            rows: variants.map((variant) {
                              return DataRow(cells: [
                                DataCell(Text(variant.combinationName)),
                                DataCell(TextFormField(
                                  initialValue: variant.price.toString(),
                                  onChanged: (value) {
                                    variant.price = double.tryParse(value) ?? 0.0;
                                  },
                                )),
                                DataCell(TextFormField(
                                  initialValue: variant.stock.toString(),
                                  onChanged: (value) {
                                    variant.stock = int.tryParse(value) ?? 0;
                                  },
                                )),
                                DataCell(TextFormField(
                                  initialValue: variant.code,
                                  onChanged: (value) {
                                    variant.code = value;
                                  },
                                )),
                              ]);
                            }).toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 20, thickness: 2, color: Color(0xFFE0E0E0)),
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
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFE53935),
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
              marge: double.tryParse(margeController.text) ?? 0.0,
            );

            if (widget.product == null) {
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
                double.tryParse(margeController.text) ?? 0.0,
              );
            } else {
              await sqldb.updateProduct(updatedProduct);
              print("update product done");
            }

            if (hasVariants) {
              // Supprimer les anciennes variantes
              await sqldb.deleteVariantsByProductCode(updatedProduct.code);

              // Ajouter les nouvelles variantes
              for (var variant in variants) {
                await sqldb.addVariant(variant);
              }
            }

            widget.refreshData();
            Navigator.of(context).pop();
          }
        },
        backgroundColor: const Color(0xFF009688),
        child: const Icon(Icons.save, color: Colors.white),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(label),
        keyboardType: keyboardType,
        enabled: enabled,
        validator: validator,
        style: const TextStyle(color: Colors.black),
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF0056A6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF26A9E0)),
      ),
    );
  }
}