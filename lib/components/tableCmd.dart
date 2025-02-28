import 'dart:ui';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

typedef RefreshCallback = void Function(Function refreshData);

class TableCmd extends StatefulWidget {
  final double total;
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final Function(int) onDeleteProduct;
  final RefreshCallback onAddProduct;
  final VoidCallback onSearchProduct;
  // final VoidCallback onAddCategory;
  final Function(int) onQuantityChange;
  final double Function(List<Product>, List<int>) calculateTotal;
  final VoidCallback onFetchOrders;
  final VoidCallback onPlaceOrder;

  const TableCmd({
    super.key,
    required this.total,
    required this.selectedProducts,
    required this.quantityProducts,
    required this.onDeleteProduct,
    required this.onAddProduct,
    required this.onSearchProduct,
    required this.onQuantityChange,
    required this.calculateTotal,
    required this.onFetchOrders,
    required this.onPlaceOrder,
    // required this.onAddCategory,
  });

  @override
  _TableCmdState createState() => _TableCmdState();
}

class _TableCmdState extends State<TableCmd> {
  final SqlDb sqldb = SqlDb();
  int? selectedProductIndex;
  TextEditingController barcodeController = TextEditingController();
  FocusNode barcodeFocusNode = FocusNode(); // To keep focus on the input field
  String scannedBarcode = ""; // Store scanned barcode temporarily

  @override
  void initState() {
    super.initState();
    barcodeFocusNode.requestFocus(); // Keep focus on input field
    // Listen for barcode scanner input
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
        // If Enter key is detected, process the barcode
        handleBarcodeScan(scannedBarcode);
        scannedBarcode = ""; // Reset the barcode buffer
      } else {
        // Append characters to scannedBarcode
        scannedBarcode += event.character ?? "";
      }
    }
  }

  void handleBarcodeScan(String barcodeScanRes) async {
    print("Code scanné : $barcodeScanRes");

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
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Produit introuvable !")),
      );
    }
    barcodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
      children: [
        // Table on the left
        Expanded(
          flex: 2, // Adjust the size of the table
          child: Column(
            children: [
              // Scanner (invisible)
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
                          '${calculateTotal().toStringAsFixed(2)} DT',
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
                        const Text(
                          'Caissier: foulen ben foulen',
                          style: TextStyle(
                              fontSize:18 ,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          'Time: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const TextStyle(
                              fontSize:18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: barcodeController,
                focusNode: barcodeFocusNode,
                decoration: const InputDecoration(
                  labelText: "Scanner Code-Barres",
                  border: InputBorder.none,
                ),
              ),

              const SizedBox(height: 10),

              // Total

              // Product table
              Container(
                height: 270,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF26A9E0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26A9E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                              child: Text('Code',
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Désignation',
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Quantité',
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Prix U',
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Montant',
                                  style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RawScrollbar(
                        thumbColor: const Color.fromARGB(
                            255, 132, 132, 132)!, // Gris sombre
                        radius: const Radius.circular(10), // Coins arrondis
                        thickness: 7, // Épaisseur de la barre
                        thumbVisibility: true, // Toujours visible
                        scrollbarOrientation:
                            ScrollbarOrientation.right, // À droite
                        child: ListView.builder(
                          itemCount: widget.selectedProducts.length,
                          itemBuilder: (context, index) {
                            final product = widget.selectedProducts[index];
                            bool isSelected = selectedProductIndex == index;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedProductIndex = index;
                                });
                              },
                              child: Container(
                                color: isSelected
                                    ? const Color(0xFF26A9E0).withOpacity(0.2)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(product.code)),
                                    Expanded(child: Text(product.designation)),
                                    Expanded(
                                        child: Text(
                                            '${widget.quantityProducts[index]}')),
                                    Expanded(
                                        child: Text(
                                            '${product.prixTTC.toStringAsFixed(2)} DT')),
                                    Expanded(
                                      child: Text(
                                        "${(product.prixTTC * widget.quantityProducts[index]).toStringAsFixed(2)} DT",
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

        // Buttons on the right
        Expanded(
          flex: 1, // Colonne plus petite pour les boutons
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Alignement en haut
            children: [
              const SizedBox(height: 170), // Espacement en haut

              GestureDetector(
                onTap: selectedProductIndex != null
                    ? () {
                        widget.onDeleteProduct(selectedProductIndex!);
                        setState(() {
                          selectedProductIndex = null;
                        });
                      }
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10), // Réduction du padding
                  decoration: BoxDecoration(
                    color: selectedProductIndex != null
                        ? const Color(0xFFE53935)
                        : Colors.grey,
                    borderRadius:
                        BorderRadius.circular(8), // Légèrement plus arrondi
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete,
                          color: Colors.white,
                          size: 18), // Taille icône réduite
                      SizedBox(width: 8),
                      Text('SUPPRIMER LIGNE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8), // Réduction de l'espacement
              GestureDetector(
                onTap: selectedProductIndex != null
                    ? () => widget.onQuantityChange(selectedProductIndex!)
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedProductIndex != null
                        ? const Color(0xFF0056A6)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('CHANGER QUANTITÉ',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: widget.onSearchProduct,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056A6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('RECHERCHER PRODUITS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              

              GestureDetector(
                onTap: widget.onFetchOrders,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056A6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('AFFICHER COMMANDES',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: widget.onPlaceOrder,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009688),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('VALIDER COMMANDE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double calculateTotal() {
    double total = 0.0;
    for (int i = 0; i < widget.selectedProducts.length; i++) {
      total += widget.selectedProducts[i].prixTTC * widget.quantityProducts[i];
    }
    return total;
  }
}
