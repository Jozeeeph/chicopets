import 'dart:convert';
import 'package:caissechicopets/passagecommande/applyDiscount.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caissechicopets/views/client_views/client_management.dart'; // Add this import

typedef RefreshCallback = void Function();

class TableCmd extends StatefulWidget {
  final double total;
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final List<double> discounts;
  final List<bool> typeDiscounts;
  final Function(int) onApplyDiscount;
  final Function(int) onDeleteProduct;
  final RefreshCallback onAddProduct;
  final VoidCallback onSearchProduct;
  final double globalDiscount;
  final bool isPercentageDiscount;
  final Function(int) onQuantityChange;
  final double Function(List<Product>, List<int>, List<double>, List<bool>,
      double globalDiscount, bool isPercentageDiscount) calculateTotal;
  final VoidCallback onFetchOrders;
  final VoidCallback onPlaceOrder;
  final int? selectedProductIndex;
  final Function(int) onProductSelected;

  const TableCmd({
    super.key,
    required this.total,
    required this.selectedProducts,
    required this.quantityProducts,
    required this.discounts,
    required this.globalDiscount,
    required this.typeDiscounts,
    required this.onApplyDiscount,
    required this.onDeleteProduct,
    required this.onAddProduct,
    required this.onSearchProduct,
    required this.onQuantityChange,
    required this.calculateTotal,
    required this.onFetchOrders,
    required this.onPlaceOrder,
    required this.isPercentageDiscount,
    this.selectedProductIndex,
    required this.onProductSelected,
  });

  @override
  _TableCmdState createState() => _TableCmdState();
}

class _TableCmdState extends State<TableCmd> {
  final SqlDb sqldb = SqlDb();
  int? selectedProductIndex;
  TextEditingController barcodeController = TextEditingController();
  FocusNode barcodeFocusNode = FocusNode();
  String scannedBarcode = "";

  @override
  void initState() {
    super.initState();
    barcodeFocusNode.requestFocus();
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    barcodeFocusNode.dispose();
    barcodeController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        handleBarcodeScan(scannedBarcode);
        scannedBarcode = "";
      } else {
        scannedBarcode += event.character ?? "";
      }
    }
  }

  void handleBarcodeScan(String barcodeScanRes) async {
    print("Scanned or entered barcode: $barcodeScanRes");

    if (barcodeScanRes.isEmpty) return;

    Product? scannedProduct = await sqldb.getProductByCode(barcodeScanRes);

    if (scannedProduct != null) {
      setState(() {
        int index =
            widget.selectedProducts.indexWhere((p) => p.code == barcodeScanRes);
        if (index != -1) {
          widget.quantityProducts[index]++;
        } else {
          widget.selectedProducts.add(scannedProduct);
          widget.quantityProducts.add(1);
          widget.discounts.add(0.0);
          widget.typeDiscounts.add(true);
        }
      });
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product not found!")),
      );
    }
    barcodeController.clear();
  }

  void _handleManualBarcodeInput() {
    final manualBarcode = barcodeController.text.trim();
    if (manualBarcode.isNotEmpty) {
      handleBarcodeScan(manualBarcode);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a barcode!")),
      );
    }
  }

  Future<User?> _getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        return User.fromMap(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  void _showClientManagement(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gestion des clients'),
        content: SizedBox(
          width: double.maxFinite,
          child: ClientManagementWidget(
            onClientSelected: (client) {
              // Vous pouvez utiliser ce callback pour associer un client à une commande
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tableau des produits à gauche
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // En-tête avec le total
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 1, 42, 79),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL:',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          '${widget.calculateTotal(widget.selectedProducts, widget.quantityProducts, widget.discounts, widget.typeDiscounts, widget.globalDiscount, widget.isPercentageDiscount).toStringAsFixed(2)} DT',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 27, 229, 67)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FutureBuilder<User?>(
                          future: _getCurrentUser(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              if (snapshot.hasData) {
                                return Text(
                                  'Caissier: ${snapshot.data!.username}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }
                            }
                            return const Text(
                              'Caissier: ...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        // Ajout de la date et heure avec mise à jour en temps réel
                        StreamBuilder<DateTime>(
                          stream: Stream.periodic(const Duration(seconds: 1),
                              (_) => DateTime.now()),
                          builder: (context, snapshot) {
                            return Text(
                              'Le ${DateFormat('dd/MM/yyyy').format(snapshot.data ?? DateTime.now())} à ${DateFormat('HH:mm:ss').format(snapshot.data ?? DateTime.now())}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Champ de saisie code-barres
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: barcodeController,
                      focusNode: barcodeFocusNode,
                      decoration: const InputDecoration(
                        labelText: "Scanner ou saisir code-barres",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) {
                        _handleManualBarcodeInput();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: _handleManualBarcodeInput,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Tableau des produits sélectionnés
              Container(
                height: 270,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color.fromARGB(255, 1, 42, 79)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // En-tête du tableau
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 1, 42, 79),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                              child: Text('Code',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Désignation',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Qté',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Remise',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Prix U',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Montant',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                        ],
                      ),
                    ),

                    // Corps du tableau
                    Expanded(
                      child: RawScrollbar(
                        thumbColor: const Color.fromARGB(255, 132, 132, 132),
                        radius: const Radius.circular(10),
                        thickness: 7,
                        thumbVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.right,
                        child: widget.selectedProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aucun produit sélectionné',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: widget.selectedProducts.length,
                                itemBuilder: (context, index) {
                                  final product =
                                      widget.selectedProducts[index];
                                  bool isSelected =
                                      selectedProductIndex == index;
                                  final hasVariants = product.hasVariants &&
                                      product.variants.isNotEmpty;
                                  final variant = hasVariants
                                      ? product.variants.first
                                      : null;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedProductIndex = index;
                                      });
                                    },
                                    child: Container(
                                      color: isSelected
                                          ? const Color.fromARGB(
                                              255, 166, 196, 222)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(product.code ?? '')),
                                          Expanded(
                                            child: Text(
                                              hasVariants
                                                  ? '${product.designation} (${variant!.combinationName})'
                                                  : product.designation,
                                            ),
                                          ),
                                          Expanded(
                                              child: Text(
                                                  '${widget.quantityProducts[index]}')),
                                          Expanded(
                                            child: Text(
                                              '${widget.discounts[index]} ${widget.typeDiscounts[index] ? '%' : 'DT'}',
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              hasVariants
                                                  ? '${variant!.price.toStringAsFixed(2)} DT'
                                                  : '${product.prixTTC.toStringAsFixed(2)} DT',
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              widget.typeDiscounts[index]
                                                  ? hasVariants
                                                      ? "${(variant!.finalPrice * widget.quantityProducts[index] * (1 - widget.discounts[index] / 100)).toStringAsFixed(2)} DT"
                                                      : "${(product.prixTTC * widget.quantityProducts[index] * (1 - widget.discounts[index] / 100)).toStringAsFixed(2)} DT"
                                                  : hasVariants
                                                      ? "${(variant!.finalPrice * widget.quantityProducts[index] - widget.discounts[index]).toStringAsFixed(2)} DT"
                                                      : "${(product.prixTTC * widget.quantityProducts[index] - widget.discounts[index]).toStringAsFixed(2)} DT",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 15),

// Boutons d'action à droite - Version Cards corrigée
Expanded(
  flex: 1,
  child: SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(top: 150),
      child: Wrap(
        spacing: 10, // Espacement horizontal entre les cards
        runSpacing: 10, // Espacement vertical entre les cards
        alignment: WrapAlignment.center,
        children: [
          // Bouton SUPPRIMER
          SizedBox(
            width: 160, // Largeur fixe pour chaque card
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: selectedProductIndex != null
                  ? const Color(0xFFE53935)
                  : Colors.grey,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: selectedProductIndex != null
                    ? () {
                        widget.onDeleteProduct(selectedProductIndex!);
                        setState(() {
                          selectedProductIndex = null;
                        });
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('SUPPRIMER PRODUIT',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bouton REMISE
          SizedBox(
            width: 160,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: selectedProductIndex != null
                  ? const Color(0xFF0056A6)
                  : Colors.grey,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: selectedProductIndex != null
                    ? () {
                        widget.onApplyDiscount(selectedProductIndex!);
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.discount, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('REMISE PAR LIGNE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bouton QUANTITÉ
          SizedBox(
            width: 160,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: selectedProductIndex != null
                  ? const Color(0xFF0056A6)
                  : Colors.grey,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: selectedProductIndex != null
                    ? () => widget.onQuantityChange(selectedProductIndex!)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('CHANGER QUANTITÉ',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bouton RECHERCHER
          SizedBox(
            width: 160,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: const Color(0xFF0056A6),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: widget.onSearchProduct,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('LISTE PRODUITS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bouton CLIENTS
          SizedBox(
            width: 160,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: const Color(0xFF0056A6),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  _showClientManagement(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('COMPTES CLIENTS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bouton COMMANDES
          SizedBox(
            width: 160,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: const Color(0xFF0056A6),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: widget.onFetchOrders,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.list, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('LISTE COMMANDES',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bouton VALIDER
          SizedBox(
            width: 160,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              color: const Color(0xFF009688),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: widget.onPlaceOrder,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      const Text('VALIDER COMMANDE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
      ],
    );
  }
}
