import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/variant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  final Function refreshData;

  const EditProductScreen({
    super.key,
    required this.product,
    required this.refreshData,
  });

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController priceHTController = TextEditingController();
  final TextEditingController priceTTCController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController margeController = TextEditingController();
  final TextEditingController remiseMaxController = TextEditingController();
  final TextEditingController profitController = TextEditingController();
  final TextEditingController remiseValeurMaxController =
      TextEditingController();
  final TextEditingController attributeNameController = TextEditingController();
  final TextEditingController attributeValuesController =
      TextEditingController();

  final SqlDb sqldb = SqlDb();
  double? selectedTax;

  int? selectedCategoryId;
  int? selectedSubCategoryId;
  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  bool hasExpirationDate = false;
  bool hasVariants = false;
  List<Variant> variants = [];
  Map<String, List<String>> attributes = {};
  bool isLoadingVariants = false;

  @override
  void initState() {
    super.initState();
    // Initialize form fields with product data
    codeController.text = widget.product.code;
    designationController.text = widget.product.designation;
    stockController.text = widget.product.stock.toString();
    priceHTController.text = widget.product.prixHT.toString();
    taxController.text = widget.product.taxe.toString();
    priceTTCController.text = widget.product.prixTTC.toString();
    dateController.text = widget.product.dateExpiration;
    selectedCategoryId = widget.product.categoryId;
    selectedSubCategoryId = widget.product.subCategoryId;
    remiseMaxController.text = widget.product.remiseMax.toString();
    margeController.text = widget.product.marge.toString();
    selectedTax = widget.product.taxe;
    hasExpirationDate = widget.product.dateExpiration.isNotEmpty;
    hasVariants = widget.product.hasVariants;

    // Calculate initial values
    double prixHT = widget.product.prixHT;
    double marge = widget.product.marge;
    double remiseMax = widget.product.remiseMax;
    double profit = (prixHT * marge) / 100;
    double remiseValeurMax = (profit * remiseMax) / 100;
    remiseValeurMaxController.text = remiseValeurMax.toStringAsFixed(2);
    profitController.text = profit.toStringAsFixed(2);

    // Set up listeners
    priceHTController.addListener(calculateValues);
    taxController.addListener(calculateValues);
    margeController.addListener(calculateValues);
    profitController.addListener(calculateValues);
    remiseMaxController.addListener(calculerRemiseValeurMax);

    // Load subcategories
    if (selectedCategoryId != null) {
      _loadSubCategories(selectedCategoryId!);
    }

    // Load variants after UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVariants();
    });
  }

  Future<void> _loadVariants() async {
    if (widget.product.id == null) return;

    setState(() => isLoadingVariants = true);
    try {
      final variantsFromDb =
          await sqldb.getVariantsByProductId(widget.product.id!);

      setState(() {
        variants = variantsFromDb;
        hasVariants = variants.isNotEmpty;

        if (hasVariants) {
          attributes.clear();
          for (final variant in variants) {
            for (final entry in variant.attributes.entries) {
              attributes.update(
                entry.key,
                (values) => values..add(entry.value),
                ifAbsent: () => [entry.value],
              );
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading variants: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load variants: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingVariants = false);
      }
    }
  }

  void calculerRemiseValeurMax() {
    double profit = double.tryParse(profitController.text) ?? 0;
    double remiseMax = double.tryParse(remiseMaxController.text) ?? 0;
    double remiseValeurMax = (profit * remiseMax) / 100;
    remiseValeurMaxController.text = remiseValeurMax.toStringAsFixed(2);
  }

  @override
  void dispose() {
    remiseMaxController.dispose();
    profitController.dispose();
    remiseValeurMaxController.dispose();
    attributeNameController.dispose();
    attributeValuesController.dispose();
    super.dispose();
  }

  void _loadSubCategories(int categoryId) async {
    final dbClient = await sqldb.db;
    final subCategoriesData = await dbClient.query(
      'sub_categories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );

    setState(() {
      subCategories = subCategoriesData.map((subCat) {
        return SubCategory(
          id: subCat['id_sub_category'] as int,
          name: subCat['sub_category_name'] as String,
          parentId: subCat['parent_id'] as int?,
          categoryId: subCat['category_id'] as int,
        );
      }).toList();
    });
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
      setState(() {
        attributes[attributeName] =
            attributeValues.split(',').map((v) => v.trim()).toList();
        attributeNameController.clear();
        attributeValuesController.clear();
      });
    }
  }

  void generateVariants() {
    if (widget.product.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please save product before adding variants')),
      );
      return;
    }

    setState(() {
      variants = _generateCombinations(attributes).map((combination) {
        final basePrice = double.parse(priceTTCController.text);
        return Variant(
          code: '',
          combinationName: combination.values.join('-'),
          price: basePrice,
          priceImpact: 0.0,
          stock: 0,
          attributes: combination,
          productId: widget.product.id!,
        );
      }).toList();
    });
  }

  List<Map<String, String>> _generateCombinations(
      Map<String, List<String>> attributes) {
    List<Map<String, String>> combinations = [];
    List<String> attributeNames = attributes.keys.toList();

    _generateCombinationHelper(attributes, attributeNames, 0, {}, combinations);
    return combinations;
  }

  void _generateCombinationHelper(
      Map<String, List<String>> attributes,
      List<String> attributeNames,
      int currentIndex,
      Map<String, String> currentCombination,
      List<Map<String, String>> combinations) {
    if (currentIndex == attributeNames.length) {
      combinations.add(Map.from(currentCombination));
      return;
    }

    String currentAttribute = attributeNames[currentIndex];
    for (String value in attributes[currentAttribute]!) {
      currentCombination[currentAttribute] = value;
      _generateCombinationHelper(attributes, attributeNames, currentIndex + 1,
          currentCombination, combinations);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingVariants) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Modifier le Produit',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0056A6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Ce produit a-t-il des variantes ?'),
                  value: hasVariants,
                  onChanged: (value) {
                    setState(() {
                      hasVariants = value ?? false;
                      if (!hasVariants) {
                        variants.clear();
                        attributes.clear();
                      }
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
                      if (int.parse(value) < 0) {
                        return 'Le "Code à Barre" doit être un nombre positif.';
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
                      if (int.tryParse(value) == null || int.parse(value) < 0) {
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
                  controller: remiseMaxController,
                  label: 'Remise % Max',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le champ "Remise % Max" ne doit pas être vide.';
                    }
                    if (double.tryParse(value) == null ||
                        double.parse(value) < 0) {
                      return 'La remise % max doit être un nombre positif ou nul.';
                    }
                    if (double.parse(value) > 100) {
                      return 'La remise % max ne peut pas dépasser 100%.';
                    }
                    return null;
                  },
                ),
                _buildTextFormField(
                  controller: profitController,
                  label: 'Profit',
                  keyboardType: TextInputType.number,
                  enabled: false,
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
                _buildTextFormField(
                  controller: remiseValeurMaxController,
                  label: 'Remise Valeur Max',
                  keyboardType: TextInputType.number,
                  enabled: false,
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
                      setState(() {
                        selectedTax = 0.0;
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
                const SizedBox(height: 16),
                CheckboxListTile(
                  title:
                      const Text('Ce produit a-t-il une date d\'expiration ?'),
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
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: dateController,
                  label: 'Date Expiration',
                  validator: (value) {
                    if (hasExpirationDate) {
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
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Category>>(
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
                const SizedBox(height: 16),
                Visibility(
                  visible: selectedCategoryId != null,
                  child: SubCategoryTree(
                    subCategories: subCategories,
                    parentId: null,
                    onSelect: (subCategoryId) {
                      setState(() {
                        selectedSubCategoryId = subCategoryId;
                      });
                    },
                    selectedSubCategoryId: selectedSubCategoryId,
                  ),
                ),
                if (hasVariants) ...[
                  const SizedBox(height: 20),
                  _buildTextFormField(
                    controller: attributeNameController,
                    label: 'Nom de l\'attribut (ex: Taille)',
                  ),
                  _buildTextFormField(
                    controller: attributeValuesController,
                    label: 'Valeurs (séparées par virgule, ex: S,M,L)',
                  ),
                  ElevatedButton(
                    onPressed: addAttribute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056A6),
                    ),
                    child: const Text(
                      'Ajouter Attribut',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...attributes.entries.map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Wrap(
                            spacing: 8.0,
                            children: entry.value
                                .map((value) => Chip(
                                      label: Text(value),
                                      onDeleted: () {
                                        setState(() {
                                          entry.value.remove(value);
                                          if (entry.value.isEmpty) {
                                            attributes.remove(entry.key);
                                          }
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                        ],
                      )),
                  const SizedBox(height: 10),
                  if (attributes.isNotEmpty)
                    ElevatedButton(
                      onPressed: generateVariants,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                      ),
                      child: const Text(
                        'Générer Variantes',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  if (variants.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Variantes:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double columnSpacing = 8.0;
                        final double totalWidth = constraints.maxWidth;
                        final double columnWidth =
                            (totalWidth - (5 * columnSpacing)) / 6;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            width: totalWidth,
                            child: DataTable(
                              columnSpacing: columnSpacing,
                              columns: [
                                DataColumn(
                                  label: const Text('Combinaison'),
                                  numeric: false,
                                  tooltip: 'Combinaison de variantes',
                                  onSort: (columnIndex, ascending) {},
                                ),
                                DataColumn(
                                  label: const Text('Prix'),
                                  numeric: true,
                                  tooltip: 'Prix de base',
                                  onSort: (columnIndex, ascending) {},
                                ),
                                DataColumn(
                                  label: const Text('Impact Prix'),
                                  numeric: true,
                                  tooltip: 'Impact sur le prix',
                                  onSort: (columnIndex, ascending) {},
                                ),
                                DataColumn(
                                  label: const Text('Prix Final'),
                                  numeric: true,
                                  tooltip: 'Prix final',
                                  onSort: (columnIndex, ascending) {},
                                ),
                                DataColumn(
                                  label: const Text('Stock'),
                                  numeric: true,
                                  tooltip: 'Quantité en stock',
                                  onSort: (columnIndex, ascending) {},
                                ),
                                DataColumn(
                                  label: const Text('Code-barres'),
                                  numeric: false,
                                  tooltip: 'Code-barres unique',
                                  onSort: (columnIndex, ascending) {},
                                ),
                              ],
                              rows: variants.map((variant) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: columnWidth,
                                        child: Text(
                                          variant.combinationName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: columnWidth,
                                        child: TextFormField(
                                          initialValue:
                                              variant.price.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              variant.price =
                                                  double.tryParse(value) ?? 0.0;
                                              variant.finalPrice =
                                                  variant.price +
                                                      variant.priceImpact;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: columnWidth,
                                        child: TextFormField(
                                          initialValue:
                                              variant.priceImpact.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              variant.priceImpact =
                                                  double.tryParse(value) ?? 0.0;
                                              variant.finalPrice =
                                                  variant.price +
                                                      variant.priceImpact;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: columnWidth,
                                        child: Text(
                                          variant.finalPrice.toStringAsFixed(2),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: columnWidth,
                                        child: TextFormField(
                                          initialValue:
                                              variant.stock.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8),
                                          ),
                                          onChanged: (value) {
                                            variant.stock =
                                                int.tryParse(value) ?? 0;
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: columnWidth,
                                        child: TextFormField(
                                          initialValue: variant.code,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8),
                                          ),
                                          onChanged: (value) {
                                            variant.code = value;
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    )
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_formKey.currentState!.validate()) {
            if (selectedCategoryId == null || selectedSubCategoryId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Veuillez sélectionner une catégorie et une sous-catégorie.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Color(0xFFE53935),
                ),
              );
              return;
            }

            if (hasVariants) {
              if (variants.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Veuillez générer les variantes avant de sauvegarder.',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Color(0xFFE53935),
                  ),
                );
                return;
              }

              for (final variant in variants) {
                if (variant.code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Le variant "${variant.combinationName}" doit avoir un code-barres',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (variant.stock < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Stock invalide pour le variant "${variant.combinationName}"',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }
            }

            try {
              final categoryName =
                  await sqldb.getCategoryNameById(selectedCategoryId!);
              final subCategoryName =
                  await sqldb.getSubCategoryNameById(selectedSubCategoryId!);

              final updatedVariants = variants.map((v) {
                return Variant(
                  id: v.id,
                  code: v.code,
                  combinationName: v.combinationName,
                  price: v.price,
                  priceImpact: v.priceImpact,
                  stock: v.stock,
                  attributes: v.attributes,
                  productId: v.productId,
                );
              }).toList();

              final product = Product(
                id: widget.product.id,
                code: codeController.text.trim(),
                designation: designationController.text.trim(),
                stock: hasVariants
                    ? updatedVariants.fold(0, (sum, v) => sum + v.stock)
                    : int.parse(stockController.text),
                prixHT: double.parse(priceHTController.text),
                taxe: selectedTax ?? 0.0,
                prixTTC: double.parse(priceTTCController.text),
                dateExpiration:
                    hasExpirationDate ? dateController.text.trim() : '',
                categoryId: selectedCategoryId!,
                subCategoryId: selectedSubCategoryId!,
                categoryName: categoryName,
                subCategoryName: subCategoryName,
                marge: double.parse(margeController.text),
                remiseMax: double.parse(remiseMaxController.text),
                remiseValeurMax: double.parse(remiseValeurMaxController.text),
                hasVariants: hasVariants,
                variants: updatedVariants,
              );

              await sqldb.updateProductWithVariants(product);

              widget.refreshData();
              if (mounted) Navigator.pop(context);
            } catch (e) {
              debugPrint('Error updating product: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Erreur lors de la mise à jour: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
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
      padding: const EdgeInsets.only(bottom: 16.0),
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
    final children =
        subCategories.where((subCat) => subCat.parentId == parentId).toList();

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
              tileColor:
                  selectedSubCategoryId == subCat.id ? Colors.blue[50] : null,
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
