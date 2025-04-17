import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/gestionproduit/editProduct.dart'; // Make sure to import your EditProductScreen
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/subcategory.dart';
import 'package:caissechicopets/category.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AddProductScreen extends StatefulWidget {
  final Function refreshData;

  const AddProductScreen({
    super.key,
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
  final TextEditingController remiseMaxController = TextEditingController();
  final TextEditingController profitController = TextEditingController();
  final TextEditingController remiseValeurMaxController =
      TextEditingController();
  final TextEditingController priceVenteHTController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final SqlDb sqldb = SqlDb();
  double? selectedTax = 0.0;

  int? selectedCategoryId;
  int? selectedSubCategoryId;
  bool isCategoryFormVisible = false;
  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  bool hasExpirationDate = false;
  bool sellable = true;
  bool hasVariants = false;

  bool get areRequiredFieldsFilled {
    return designationController.text.isNotEmpty &&
        stockController.text.isNotEmpty &&
        priceHTController.text.isNotEmpty &&
        margeController.text.isNotEmpty &&
        selectedCategoryId != null;
  }

  @override
  void initState() {
    super.initState();

    // Initialize default values for new product
    remiseMaxController.text = '0.0';
    remiseValeurMaxController.text = '0.0';
    taxController.text = '0.0';

    priceHTController.addListener(calculateValues);
    taxController.addListener(calculateValues);
    margeController.addListener(calculateValues);
    profitController.addListener(calculateValues);
    remiseMaxController.addListener(calculerRemiseValeurMax);
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
    descriptionController.dispose();
    priceHTController.dispose();
    super.dispose();
  }

  Future<int?> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      if (selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Veuillez sélectionner une catégorie.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFFE53935),
        ));
        return null;
      }

      try {
        final categoryName =
            await sqldb.getCategoryNameById(selectedCategoryId!);
        final subCategoryName = selectedSubCategoryId != null
            ? await sqldb.getSubCategoryNameById(selectedSubCategoryId!)
            : '';

        final product = Product(
          code: codeController.text.trim().isNotEmpty
              ? codeController.text.trim()
              : null,
          designation: designationController.text.trim(),
          description: descriptionController.text.trim(),
          stock: int.parse(stockController.text),
          prixHT: double.parse(priceHTController.text),
          taxe: selectedTax ?? 0.0,
          prixTTC: double.parse(priceTTCController.text),
          dateExpiration: hasExpirationDate ? dateController.text.trim() : '',
          categoryId: selectedCategoryId!,
          subCategoryId: selectedSubCategoryId,
          categoryName: categoryName,
          subCategoryName: subCategoryName,
          marge: double.parse(margeController.text),
          remiseMax: double.parse(remiseMaxController.text),
          remiseValeurMax: double.parse(remiseValeurMaxController.text),
          sellable: sellable,
          hasVariants: hasVariants,
        );

        final db = await sqldb.db;
        product.id = await db.insert('products', product.toMap());
        widget.refreshData();
        return product.id;
      } catch (e) {
        debugPrint('Error saving product: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajouter un Produit',
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
                      // Add Variant Button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: areRequiredFieldsFilled
                              ? () async {
                                  if (!hasVariants) {
                                    setState(() {
                                      hasVariants = !hasVariants;
                                    });
                                  } else {
                                    // Save product and navigate to edit screen
                                    final productId = await _saveProduct();
                                    if (productId != null && mounted) {
                                      // Fetch the newly created product
                                      final db = await sqldb.db;
                                      final productData = await db.query(
                                        'products',
                                        where: 'id = ?',
                                        whereArgs: [productId],
                                      );

                                      if (productData.isNotEmpty) {
                                        final product =
                                            Product.fromMap(productData.first);
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditProductScreen(
                                              product: product,
                                              refreshData: widget.refreshData,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasVariants
                                ? const Color(0xFF0056A6)
                                : Colors.grey,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            hasVariants
                                ? 'Enregistrer et ajouter des variantes'
                                : 'Ce produit a des variantes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      if (hasVariants)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Les variantes seront ajoutées après la création du produit de base',
                            style: TextStyle(
                              color: Colors.blue,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      _buildTextFormField(
                        controller: codeController,
                        label: 'Code à Barre', // Ajouté (optionnel)
                        // validator: (value) {
                        //   if (value != null && value.isNotEmpty) {
                        //     // Seulement valider si non vide
                        //     if (int.tryParse(value) == null) {
                        //       return 'Le "Code à Barre" doit être un nombre.';
                        //     }
                        //     if (int.parse(value) < 0) {
                        //       return 'Le "Code à Barre" doit être un nombre positif.';
                        //     }
                        //   }
                        //   return null; // Accepte null ou vide
                        // },
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
                        label:
                            'Description (optionnelle)', // Ajouté (optionnelle)
                        validator: (value) {
                          // Retirer complètement la validation, car le champ est optionnel
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

                      // Price HT and TTC aligned
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
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildTextFormField(
                              controller: priceVenteHTController,
                              label: 'Prix Vente HT',
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ce champ est obligatoire';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Nombre invalide';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (value.isNotEmpty &&
                                    double.tryParse(value) != null) {
                                  calculateValues(changedField: 'prixVenteHT');
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 10),
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

                      // Margin and Profit aligned
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
                              onChanged: (value) {
                                if (value.isNotEmpty &&
                                    double.tryParse(value) != null) {
                                  calculateValues(changedField: 'marge');
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildTextFormField(
                              controller: profitController,
                              label: 'Profit',
                              keyboardType: TextInputType.number,
                              enabled:
                                  false, // Champ désactivé car calculé automatiquement
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Discount % and Value aligned (like Price TTC)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: remiseMaxController,
                              label: 'Remise % Max',
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
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
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  final profit =
                                      double.tryParse(profitController.text) ??
                                          0;
                                  final percentage =
                                      double.tryParse(value) ?? 0;
                                  final discountValue =
                                      (profit * percentage) / 100;
                                  remiseValeurMaxController.text =
                                      discountValue.toStringAsFixed(2);
                                } else {
                                  remiseValeurMaxController.clear();
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: remiseValeurMaxController,
                              decoration: _inputDecoration('Remise Valeur Max'),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Le champ "Remise Valeur Max" ne doit pas être vide.';
                                }
                                final discountValue = double.tryParse(value);
                                if (discountValue == null ||
                                    discountValue < 0) {
                                  return 'La remise valeur max doit être un nombre positif ou nul.';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  final profit =
                                      double.tryParse(profitController.text) ??
                                          0;
                                  final discountValue =
                                      double.tryParse(value) ?? 0;
                                  if (profit > 0) {
                                    final percentage =
                                        (discountValue / profit) * 100;
                                    remiseMaxController.text =
                                        percentage.toStringAsFixed(2);
                                  }
                                } else {
                                  remiseMaxController.clear();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

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
                      CheckboxListTile(
                        title: const Text(
                            'Ce produit a-t-il une date d\'expiration ?'),
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
                    ],
                  ),
                ),
              ),
              const VerticalDivider(
                  width: 20, thickness: 2, color: Color(0xFFE0E0E0)),
              Expanded(
                flex: 1,
                child: isCategoryFormVisible
                    ? AddCategory(
                        onCategoryAdded: () async {
                          // Refresh categories after adding a new one
                          setState(() async {
                            categories = await sqldb.getCategories();
                            isCategoryFormVisible = false;
                          });
                        },
                      )
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
          final productId = await _saveProduct();
          if (productId != null && mounted) {
            Navigator.pop(context);
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
    void Function(String)? onChanged,
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
