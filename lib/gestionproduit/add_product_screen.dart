import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/variant.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;
  final Function refreshData;

  const AddProductScreen({
    super.key,
    this.product,
    required this.refreshData,
  });

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
  final TextEditingController attributeNameController = TextEditingController();
  final TextEditingController attributeValuesController =
      TextEditingController();

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
  Map<String, List<String>> attributes = {};

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
      selectedTax = widget.product?.taxe ?? 0.0; // Valeur par défaut : 0.0
      if (![0.0, 7.0, 12.0, 19.0].contains(selectedTax)) {
        selectedTax =
            0.0; // Forcer une valeur valide si la taxe n'est pas valide
      }
      // Charger les sous-catégories de la catégorie sélectionnée
      _loadSubCategories(selectedCategoryId!);

      double marge = ((widget.product!.prixTTC - widget.product!.prixHT) /
              widget.product!.prixHT) *
          100;
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
          value: subCat['id_sub_category'] as int,
          child: Text(subCat['sub_category_name'] as String),
        );
      }).toList();
    });
  }

  // Méthode pour charger les variantes
  void _loadVariants() async {
    if (widget.product != null) {
      final variantsFromDb = await sqldb
          .getVariantsByProductReferenceId(widget.product!.productReferenceId);
      setState(() {
        variants = variantsFromDb;
        hasVariants = variants.isNotEmpty;
        if (hasVariants) {
          // Récupérer les attributs des variantes
          for (var variant in variants) {
            for (var entry in variant.attributes.entries) {
              if (attributes.containsKey(entry.key)) {
                attributes[entry.key]!.add(entry.value);
              } else {
                attributes[entry.key] = [entry.value];
              }
            }
          }
        }
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
    } else if (priceHTController.text.isNotEmpty &&
        profitController.text.isNotEmpty) {
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

  void addAttribute() {
    String attributeName = attributeNameController.text.trim();
    String attributeValues = attributeValuesController.text.trim();

    if (attributeName.isNotEmpty && attributeValues.isNotEmpty) {
      // Normaliser le nom de l'attribut (en minuscules et sans espaces)
      String normalizedAttributeName =
          attributeName.toLowerCase().replaceAll(' ', '');

      // Vérifier si l'attribut existe déjà
      if (attributes.containsKey(normalizedAttributeName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('L\'attribut "$attributeName" existe déjà.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Sépare les valeurs par une virgule
      List<String> values =
          attributeValues.split(',').map((value) => value.trim()).toList();

      setState(() {
        attributes[normalizedAttributeName] = values;
        attributeNameController.clear();
        attributeValuesController.clear();
      });
    }
  }

  String generateProductReferenceId() {
    var uuid = Uuid();
    return uuid.v4(); // Génère un UUID de version 4 (aléatoire)
  }

  void generateVariants() {
    variants.clear();
    List<Map<String, String>> combinations = _generateCombinations(attributes);

    // Récupérer la valeur du prixTTC
    double prixTTC = double.tryParse(priceTTCController.text) ?? 0.0;

    for (var combination in combinations) {
      variants.add(Variant(
        code: '', // L'utilisateur saisira le code à barres
        combinationName: combination.values.join('-'),
        price: prixTTC, // Utiliser la valeur du prixTTC
        priceImpact: 0.0, // L'utilisateur saisira le prix d'impact
        stock: 0, // L'utilisateur saisira le stock
        attributes: combination,
        productReferenceId: '', // Sera mis à jour lors de la sauvegarde
      ));
    }
    setState(() {});
  }

  List<Map<String, String>> _generateCombinations(
      Map<String, List<String>> attributes) {
    List<Map<String, String>> combinations = [];
    List<String> attributeNames = attributes.keys.toList();
    List<List<String>> attributeValues = attributes.values.toList();

    _generateCombinationsHelper(
        attributeNames, attributeValues, 0, {}, combinations);

    return combinations;
  }

  void _generateCombinationsHelper(
      List<String> attributeNames,
      List<List<String>> attributeValues,
      int index,
      Map<String, String> currentCombination,
      List<Map<String, String>> combinations) {
    if (index == attributeNames.length) {
      combinations.add(Map.from(currentCombination));
      return;
    }

    String currentAttribute = attributeNames[index];
    for (String value in attributeValues[index]) {
      currentCombination[currentAttribute] = value;
      _generateCombinationsHelper(attributeNames, attributeValues, index + 1,
          currentCombination, combinations);
    }
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
                      ],
                      
                      _buildTextFormField(
                        controller: priceHTController,
                        label: 'Prix d\'achat',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le champ "Prix d\'achat" ne doit pas être vide.';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
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
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
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
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
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
                          if (value != null &&
                              [0.0, 7.0, 12.0, 19.0].contains(value)) {
                            setState(() {
                              selectedTax = value;
                              taxController.text = value.toString();
                            });
                            calculateValues();
                          } else {
                            // Gérer le cas où la valeur n'est pas valide
                            setState(() {
                              selectedTax = 0.0; // Valeur par défaut
                              taxController.text = '0.0';
                            });
                          }
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
                                          style: const TextStyle(
                                              color: Colors.black),
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
                            icon:
                                const Icon(Icons.add, color: Color(0xFF26A9E0)),
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
                      const SizedBox(height: 16),
                      if (hasVariants) ...[
                        _buildTextFormField(
                          controller: attributeNameController,
                          label: 'Nom de l\'attribut (ex: Taille)',
                        ),
                        _buildTextFormField(
                          controller: attributeValuesController,
                          label:
                              'Valeurs de l\'attribut (séparées par une virgule, ex: M,S,L)',
                          onFieldSubmitted: (value) {
                            addAttribute();
                          },
                        ),
                        ElevatedButton(
                          onPressed: addAttribute,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0056A6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Ajouter un attribut',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...attributes.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Wrap(
                                spacing: 8.0,
                                children: entry.value.map((value) {
                                  return Chip(
                                    label: Text(value),
                                    onDeleted: () {
                                      setState(() {
                                        entry.value.remove(value);
                                        if (entry.value.isEmpty) {
                                          attributes.remove(entry.key);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: generateVariants,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009688),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.autorenew, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Générer les variantes',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (variants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Variantes générées :',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DataTable(
                              columns: const [
                                DataColumn(
                                    label: Text('Combinaison',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Prix',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Prix d\'impact',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Prix total',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                // Toujours afficher les colonnes "Stock" et "Code à barre"
                                DataColumn(
                                    label: Text('Stock',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Code à barre',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                              ],
                              rows: variants.map((variant) {
                                return DataRow(cells: [
                                  DataCell(Text(variant.combinationName)),
                                  DataCell(TextFormField(
                                    initialValue: variant.price.toString(),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        variant.price =
                                            double.tryParse(value) ?? 0.0;
                                        variant.finalPrice =
                                            variant.price + variant.priceImpact;
                                      });
                                    },
                                  )),
                                  DataCell(TextFormField(
                                    initialValue:
                                        variant.priceImpact.toString(),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        variant.priceImpact =
                                            double.tryParse(value) ?? 0.0;
                                        variant.finalPrice =
                                            variant.price + variant.priceImpact;
                                      });
                                    },
                                  )),
                                  DataCell(Text(
                                      variant.finalPrice.toStringAsFixed(2))),
                                  // Toujours afficher les cellules "Stock" et "Code à barre"
                                  DataCell(TextFormField(
                                    initialValue: variant.stock.toString(),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        variant.stock =
                                            int.tryParse(value) ?? 0;
                                      });
                                    },
                                  )),
                                  DataCell(TextFormField(
                                    initialValue: variant.code,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        variant.code = value;
                                      });
                                    },
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const VerticalDivider(
                  width: 20, thickness: 2, color: Color(0xFFE0E0E0)),
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

            // Calcul automatique du stock et du prix HT en fonction des variantes
            int totalStock = hasVariants
                ? variants.fold(0, (sum, v) => sum + v.stock)
                : int.tryParse(stockController.text) ?? 0;
            double minPrixHT = hasVariants
                ? variants.map((v) => v.price).reduce((a, b) => a < b ? a : b)
                : double.tryParse(priceHTController.text) ?? 0.0;

            final productReferenceId = generateProductReferenceId();
            print(generateProductReferenceId());
            final updatedProduct = Product(
              code: codeController.text,
              designation: designationController.text,
              stock: totalStock,
              prixHT: minPrixHT,
              taxe: selectedTax ?? 0.0,
              prixTTC: double.tryParse(priceTTCController.text) ?? 0.0,
              dateExpiration: dateController.text,
              categoryId: selectedCategoryId!,
              subCategoryId: selectedSubCategoryId!,
              marge: double.tryParse(margeController.text) ?? 0.0,
              productReferenceId: productReferenceId, // Nouvel attribut
              variants: variants, // Liste des variantes
            );

            // Sauvegarder le produit
            if (widget.product == null) {
              // Ajout d'un nouveau produit
              await sqldb.addProduct(
                codeController.text,
                designationController.text,
                totalStock,
                minPrixHT,
                selectedTax ?? 0.0,
                double.tryParse(priceTTCController.text) ?? 0.0,
                dateController.text,
                selectedCategoryId!,
                selectedSubCategoryId!,
                double.tryParse(margeController.text) ?? 0.0,
                productReferenceId, // Nouvel attribut
              );

              // Ajouter les variantes du nouveau produit
              for (var variant in variants) {
                variant.productReferenceId = productReferenceId;
                await sqldb.addVariant(variant);
              }
            } else {
              // Mise à jour d'un produit existant
              await sqldb.updateProduct(updatedProduct);

              if (hasVariants) {
                // Supprimer uniquement les anciennes variantes du produit existant
                await sqldb.deleteVariantsByProductReferenceId(
                    updatedProduct.productReferenceId);

                // Ajouter les nouvelles variantes
                for (var variant in variants) {
                  variant.productReferenceId =
                      updatedProduct.productReferenceId;
                  await sqldb.addVariant(variant);
                }
              }
            }

            // Rafraîchir les données et fermer l'écran
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
