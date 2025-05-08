import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/models/attribut.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/subcategory.dart';
import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController priceHTController = TextEditingController();
  final TextEditingController priceTTCController = TextEditingController();
  final TextEditingController priceVenteHTController = TextEditingController();
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
  bool isCategoryFormVisible = false;
  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  bool hasExpirationDate = false;
  bool sellable = true;
  bool hasVariants = false;
  List<Variant> variants = [];
  Map<String, List<String>> attributes = {};
  bool isLoadingVariants = false;
  String? selectedDefaultVariant;

  List<Map<String, dynamic>> availableAttributes = [];
  String? selectedAttributeName;
  Map<String, Set<String>> selectedAttributeValues = {};
  Set<String> selectedValues = Set();

  @override
  void initState() {
    super.initState();
    // Initialize form fields with product data
    _initializeFormFields();
    _setupListeners();
    _loadInitialData();
  }

  void _initializeFormFields() {
    codeController.text = widget.product.code ?? '';
    designationController.text = widget.product.designation;
    descriptionController.text = widget.product.description ?? '';
    stockController.text = widget.product.hasVariants
        ? widget.product.variants
            .fold(0, (sum, variant) => sum + variant.stock)
            .toString()
        : widget.product.stock.toString();
    priceHTController.text = widget.product.prixHT.toString();
    priceVenteHTController.text =
        (widget.product.prixHT * (1 + widget.product.marge / 100))
            .toStringAsFixed(2);
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
    sellable = widget.product.sellable;

    // Calculate initial values
    double profit = (widget.product.prixHT * widget.product.marge) / 100;
    double remiseValeurMax = (profit * widget.product.remiseMax) / 100;
    remiseValeurMaxController.text = remiseValeurMax.toStringAsFixed(2);
    profitController.text = profit.toStringAsFixed(2);
  }

  void _setupListeners() {
    priceHTController.addListener(calculateValues);
    taxController.addListener(calculateValues);
    margeController.addListener(calculateValues);
    profitController.addListener(calculateValues);
    remiseMaxController.addListener(calculerRemiseValeurMax);
    priceVenteHTController.addListener(() {
      if (priceVenteHTController.text.isNotEmpty &&
          priceHTController.text.isNotEmpty) {
        calculateValues(changedField: 'prixVenteHT');
      }
    });
  }

  void calculerRemiseValeurMax() {
    double profit = double.tryParse(profitController.text) ?? 0;
    double remiseMax = double.tryParse(remiseMaxController.text) ?? 0;
    double remiseValeurMax = (profit * remiseMax) / 100;
    remiseValeurMaxController.text = remiseValeurMax.toStringAsFixed(2);
  }

  void calculateValues({String? changedField}) {
    double prixAchatHT = double.tryParse(priceHTController.text) ?? 0.0;
    double marge = double.tryParse(margeController.text) ?? 0.0;
    double prixVenteHT = double.tryParse(priceVenteHTController.text) ?? 0.0;
    double taxe = double.tryParse(taxController.text) ?? 0.0;

    if (prixAchatHT <= 0)
      return; // On a besoin du prix d'achat pour tous les calculs

    if (changedField == 'marge') {
      // Calcul basé sur la marge (%)
      prixVenteHT = prixAchatHT * (1 + marge / 100);
      priceVenteHTController.text = prixVenteHT.toStringAsFixed(2);
    } else if (changedField == 'prixVenteHT') {
      // Calcul basé sur le prix de vente HT
      marge = ((prixVenteHT - prixAchatHT) / prixAchatHT) * 100;
      margeController.text = marge.toStringAsFixed(2);
    }

    // Calcul du profit (identique dans les deux cas)
    double profit = prixVenteHT - prixAchatHT;
    profitController.text = profit.toStringAsFixed(2);

    // Calcul du prix TTC
    double prixTTC = prixVenteHT * (1 + taxe / 100);
    priceTTCController.text = prixTTC.toStringAsFixed(2);
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

  void _loadInitialData() {
    // Load subcategories
    if (selectedCategoryId != null) {
      _loadSubCategories(selectedCategoryId!);
    }

    // Initialize with existing variants if any
    if (widget.product.variants.isNotEmpty) {
      variants = widget.product.variants;
      hasVariants = true;

      // Find and set the default variant
      final defaultVariant = variants.firstWhere(
        (v) => v.defaultVariant,
        orElse: () => variants.first,
      );
      selectedDefaultVariant = defaultVariant.combinationName;

      // Extract attributes from variants
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

    // Load variants after UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVariants();
      _loadAvailableAttributes();
    });
  }

  Future<void> _loadAvailableAttributes() async {
    try {
      final List<Attribut> attributs = await sqldb.getAllAttributes();
      debugPrint("Loaded attributes: $attributs");

      setState(() {
        availableAttributes = attributs.map((attr) {
          return {
            'name': attr.name,
            'attribute_values': attr.values.toList(), // Convert Set to List
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading attributes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attributes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          // Calculer le stock total
          final totalStock =
              variants.fold(0, (sum, variant) => sum + variant.stock);
          stockController.text = totalStock.toString();

          // Find and set the default variant
          final defaultVariant = variants.firstWhere(
            (v) => v.defaultVariant,
            orElse: () => variants.first,
          );
          selectedDefaultVariant = defaultVariant.combinationName;

          // Extract attributes from variants
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use a column layout for small screens
              if (constraints.maxWidth < 1000) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProductForm(),
                      const SizedBox(height: 20),
                      if (isCategoryFormVisible) _buildCategorySection(),
                    ],
                  ),
                );
              }
              // Use row layout for larger screens
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: _buildProductForm(),
                    ),
                  ),
                  const VerticalDivider(
                    width: 20,
                    thickness: 2,
                    color: Color(0xFFE0E0E0),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildCategorySection(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveProduct,
        backgroundColor: const Color(0xFF009688),
        child: const Icon(Icons.save, color: Colors.white),
      ),
    );
  }

  Widget _buildProductForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Variant toggle
        CheckboxListTile(
          title: const Text('Ce produit a-t-il des variantes ?'),
          value: hasVariants,
          onChanged: (value) {
            setState(() {
              hasVariants = value ?? false;
              if (!hasVariants) {
                variants.clear();
                attributes.clear();
                selectedDefaultVariant = null;
              }
            });
          },
        ),

        if (!hasVariants) ...[
          _buildTextFormField(
            controller: codeController,
            label: 'Code à Barre',
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
            controller: descriptionController,
            label: 'Description (optionnelle)',
            maxLines: 3,
            keyboardType: TextInputType.multiline,
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

        // Price section
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                controller: priceVenteHTController,
                label: 'Prix Vente HT',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ce champ est obligatoire';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Nombre invalide';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                controller: priceTTCController,
                label: 'Prix TTC',
                enabled: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Margin and Profit
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: margeController,
                label: 'Marge (%)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ce champ est obligatoire';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Nombre invalide';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                controller: profitController,
                label: 'Profit',
                keyboardType: TextInputType.number,
                enabled: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Discount section
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: remiseMaxController,
                label: 'Remise % Max',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le champ "Remise % Max" ne doit pas être vide.';
                  }
                  final percentage = double.tryParse(value);
                  if (percentage == null || percentage < 0) {
                    return 'La remise % max doit être un nombre positif ou nul.';
                  }
                  if (percentage > 100) {
                    return 'La remise % max ne peut pas dépasser 100%.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextFormField(
                controller: remiseValeurMaxController,
                label: 'Remise Valeur Max',
                keyboardType: TextInputType.number,
                enabled: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tax dropdown
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
              return 'Veuillez sélectionner une taxe.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Expiration date
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
        const SizedBox(height: 16),
        Visibility(
          visible: hasExpirationDate,
          child: _buildTextFormField(
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
        ),
        const SizedBox(height: 16),

        // Sellable radio buttons
        Row(
          children: [
            const Text(
              'Vendable: ',
              style: TextStyle(color: Color(0xFF0056A6)),
            ),
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
        const SizedBox(height: 16),

        // Category dropdown
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
                        ),
                      );
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
          child: Column(
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
        ),

        // Variant management section
        if (hasVariants) _buildVariantSection(),
      ],
    );
  }

  Widget _buildVariantSection() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Gestion des Variantes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Attribute selection
        Column(
          children: [
            const Text(
              'Sélection des attributs:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                title: const Text('Choisir des attributs'),
                children: availableAttributes.map((attr) {
                  final attributeName = attr['name'] as String;
                  final values =
                      (attr['attribute_values'] as List).cast<String>();

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ExpansionTile(
                      title: Text(attributeName),
                      children: values.map((value) {
                        final fullValue = '$attributeName:$value';
                        return CheckboxListTile(
                          title: Text(value),
                          value: selectedValues.contains(fullValue),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                selectedValues.add(fullValue);
                                selectedAttributeValues.update(
                                  attributeName,
                                  (set) => set..add(value),
                                  ifAbsent: () => {value},
                                );
                              } else {
                                selectedValues.remove(fullValue);
                                selectedAttributeValues[attributeName]
                                    ?.remove(value);
                                if (selectedAttributeValues[attributeName]
                                        ?.isEmpty ??
                                    false) {
                                  selectedAttributeValues.remove(attributeName);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        // Selected attributes preview
        if (selectedAttributeValues.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Attributs sélectionnés:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: selectedAttributeValues.entries.expand((entry) {
              return entry.value.map((value) {
                return Chip(
                  label: Text('${entry.key}: $value'),
                  onDeleted: () {
                    setState(() {
                      selectedValues.remove('${entry.key}:$value');
                      selectedAttributeValues[entry.key]?.remove(value);
                      if (selectedAttributeValues[entry.key]?.isEmpty ??
                          false) {
                        selectedAttributeValues.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList();
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                selectedAttributeValues.forEach((name, values) {
                  attributes.update(
                    name,
                    (existing) => [...existing, ...values.toList()],
                    ifAbsent: () => values.toList(),
                  );
                });
                selectedValues.clear();
                selectedAttributeValues.clear();
              });
            },
            child: const Text('Ajouter aux combinaisons'),
          ),
        ],

        // Manual attribute addition
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

        // Combined attributes display
        if (attributes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Attributs combinés:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: attributes.entries.expand((entry) {
              return entry.value.map((value) {
                return Chip(
                  label: Text('${entry.key}: $value'),
                  onDeleted: () {
                    setState(() {
                      entry.value.remove(value);
                      if (entry.value.isEmpty) {
                        attributes.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList();
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Generate variants button
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

        // Variants table
        if (variants.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Variantes:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildVariantsTable(),
        ],
      ],
    );
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
          content: Text(
              'Veuillez sauvegarder le produit avant d\'ajouter des variantes'),
        ),
      );
      return;
    }

    final totalStock = int.tryParse(stockController.text) ?? 0;
    final combinations = _generateCombinations(attributes);

    if (combinations.isEmpty) return;

    // Calculate base stock per variant
    final baseStock = (totalStock / combinations.length).floor();
    final remainder = totalStock % combinations.length;

    setState(() {
      variants = combinations.asMap().entries.map((entry) {
        final index = entry.key;
        final combination = entry.value;

        // Distribute stock evenly, with remainder added to first variant
        final variantStock = index == 0 ? baseStock + remainder : baseStock;

        final basePrice = double.parse(priceHTController.text);
        return Variant(
          code: '',
          combinationName: combination.values.join('-'),
          price: basePrice,
          priceImpact: 0.0,
          stock: variantStock,
          defaultVariant: variants.isEmpty && index == 0,
          attributes: combination,
          productId: widget.product.id!,
        );
      }).toList();

      // Update total stock (should match exactly)
      updateTotalStock();

      if (variants.isNotEmpty && selectedDefaultVariant == null) {
        selectedDefaultVariant = variants.first.combinationName;
        variants.first.defaultVariant = true;
      }
    });
  }

  void updateTotalStock() {
    if (hasVariants) {
      final totalStock =
          variants.fold(0, (sum, variant) => sum + variant.stock);
      stockController.text = totalStock.toString();
    }
  }

  void _generateCombinationHelper(
    Map<String, List<String>> attributes,
    List<String> attributeNames,
    int currentIndex,
    Map<String, String> currentCombination,
    List<Map<String, String>> combinations,
  ) {
    if (currentIndex == attributeNames.length) {
      combinations.add(Map.from(currentCombination));
      return;
    }

    String currentAttribute = attributeNames[currentIndex];
    for (String value in attributes[currentAttribute]!) {
      currentCombination[currentAttribute] = value;
      _generateCombinationHelper(
        attributes,
        attributeNames,
        currentIndex + 1,
        currentCombination,
        combinations,
      );
    }
  }

  List<Map<String, String>> _generateCombinations(
      Map<String, List<String>> attributes) {
    List<Map<String, String>> combinations = [];
    List<String> attributeNames = attributes.keys.toList();

    _generateCombinationHelper(attributes, attributeNames, 0, {}, combinations);
    return combinations;
  }

  Widget _buildVariantsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: DataTable(
              columnSpacing: 8,
              horizontalMargin: 12,
              dividerThickness: 1,
              dataRowHeight: 60,
              headingRowHeight: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
                fontSize: 14,
              ),
              dataTextStyle: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13,
              ),
              columns: const [
                DataColumn(label: Text('Défaut')),
                DataColumn(label: Text('Combinaison')),
                DataColumn(label: Text('Prix'), numeric: true),
                DataColumn(label: Text('Impact Prix'), numeric: true),
                DataColumn(label: Text('Prix Final'), numeric: true),
                DataColumn(label: Text('Stock'), numeric: true),
                DataColumn(label: Text('Code-barres')),
              ],
              rows: variants.map((variant) {
                return DataRow(
                  color: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                      if (variant.defaultVariant) {
                        return Colors.blue.shade50;
                      }
                      return states.contains(MaterialState.selected)
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08)
                          : Colors.transparent;
                    },
                  ),
                  cells: [
                    DataCell(
                      Radio<String>(
                        value: variant.combinationName,
                        groupValue: selectedDefaultVariant,
                        onChanged: (value) {
                          setState(() {
                            selectedDefaultVariant = value;
                            for (var v in variants) {
                              v.defaultVariant = (v.combinationName == value);
                            }
                          });
                        },
                      ),
                    ),
                    DataCell(Text(variant.combinationName)),
                    DataCell(
                      TextFormField(
                        initialValue: variant.price.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            variant.price = double.tryParse(value) ?? 0.0;
                            variant.finalPrice =
                                variant.price + variant.priceImpact;
                          });
                        },
                      ),
                    ),
                    DataCell(
                      TextFormField(
                        initialValue: variant.priceImpact.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            variant.priceImpact = double.tryParse(value) ?? 0.0;
                            variant.finalPrice =
                                variant.price + variant.priceImpact;
                          });
                        },
                      ),
                    ),
                    DataCell(
                      Text(
                        variant.finalPrice.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    DataCell(
                      TextFormField(
                        initialValue: variant.stock.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            variant.stock = int.tryParse(value) ?? 0;
                            updateTotalStock();
                          });
                        },
                      ),
                    ),
                    DataCell(
                      TextFormField(
                        initialValue: variant.code,
                        onChanged: (value) {
                          variant.code = value;
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySection() {
    return isCategoryFormVisible
        ? AddCategory(
            onCategoryAdded: () async {
              final updatedCategories = await sqldb.getCategories();
              setState(() {
                categories = updatedCategories;
                isCategoryFormVisible = false;
              });
            },
            hideAppBar: true,
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Cliquez sur '+' pour ajouter une catégorie",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
  }

  // ... [Keep all your existing methods like calculateValues, addAttribute, etc.]

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final product = Product(
          id: widget.product.id,
          code: codeController.text.trim(),
          designation: designationController.text.trim(),
          description: descriptionController.text.trim(),
          stock: hasVariants
              ? variants.fold(0, (sum, variant) => sum + variant.stock)
              : int.parse(stockController.text),
          prixHT: double.parse(priceHTController.text),
          taxe: selectedTax ?? 0.0,
          prixTTC: double.parse(priceTTCController.text),
          dateExpiration: hasExpirationDate ? dateController.text.trim() : '',
          categoryId: selectedCategoryId!,
          subCategoryId: selectedSubCategoryId,
          categoryName: await sqldb.getCategoryNameById(selectedCategoryId!),
          subCategoryName: selectedSubCategoryId != null
              ? await sqldb.getSubCategoryNameById(selectedSubCategoryId!)
              : '',
          marge: double.parse(margeController.text),
          remiseMax: double.parse(remiseMaxController.text),
          remiseValeurMax: double.parse(remiseValeurMaxController.text),
          hasVariants: hasVariants,
          variants: variants,
          sellable: sellable,
        );

        final db = await sqldb.db;
        await db.transaction((txn) async {
          // Update product
          await txn.update(
            'products',
            product.toMap(),
            where: 'id = ?',
            whereArgs: [product.id],
          );

          // Delete existing variants
          await txn.delete(
            'variants',
            where: 'product_id = ?',
            whereArgs: [product.id],
          );

          // Insert new variants
          for (final variant in variants) {
            await txn.insert('variants', variant.toMap());
          }
        });

        widget.refreshData();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint('Error updating product: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la mise à jour: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(label),
        keyboardType: keyboardType,
        enabled: enabled,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(color: Colors.black),
        onChanged: onChanged,
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
