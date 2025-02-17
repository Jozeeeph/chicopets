import 'dart:ui';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class TableCmd extends StatefulWidget {
  final double total;
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final Function(int) onDeleteProduct;
  final VoidCallback onAddProduct;
  final VoidCallback onSearchProduct;
  final VoidCallback onAddCategory;
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
    required this.onAddCategory,
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
        int index = widget.selectedProducts.indexWhere((p) => p.code == barcodeScanRes);
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
    return Column(
      children: [
        // Champ de saisie invisible pour le scanner USB
        TextField(
          controller: barcodeController,
          focusNode: barcodeFocusNode, // Keep focus on input
          decoration: const InputDecoration(
            labelText: "Scanner Code-Barres",
            border: InputBorder.none, // Hidden input
          ),
        ),

        const SizedBox(height: 10),

        // Total Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 1, 35, 8),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    '${calculateTotal().toStringAsFixed(2)} DT',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Caissier: foulen ben foulen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Time: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Order Section
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blueAccent,
                child: Row(
                  children: const [
                    Expanded(child: Text('Code', style: TextStyle(color: Colors.white))),
                    Expanded(child: Text('Désignation', style: TextStyle(color: Colors.white))),
                    Expanded(child: Text('Quantité', style: TextStyle(color: Colors.white))),
                    Expanded(child: Text('Prix U', style: TextStyle(color: Colors.white))),
                    Expanded(child: Text('Montant', style: TextStyle(color: Colors.white))),
                  ],
                ),
              ),
              Expanded(
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
                        print("Produit sélectionné : ${product.code}");
                      },
                      child: Container(
                        color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text(product.code)),
                            Expanded(child: Text(product.designation)),
                            Expanded(child: Text('${widget.quantityProducts[index]}')),
                            Expanded(child: Text('${product.prixTTC.toStringAsFixed(2)} DT')),
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
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: widget.onAddCategory,
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 190, 0, 248)),
              child: const Text('AJOUT CATEGORIE', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: widget.onAddProduct,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('AJOUT PRODUIT', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: selectedProductIndex != null
                  ? () {
                      widget.onDeleteProduct(selectedProductIndex!);
                      setState(() {
                        selectedProductIndex = null;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: widget.onSearchProduct,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('RECHERCHE PRODUIT', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => widget.onQuantityChange(selectedProductIndex!),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('QUANTITÉ', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: widget.onFetchOrders,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('CHARGER COMMANDES', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: widget.onPlaceOrder,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('VALIDER', style: TextStyle(color: Colors.white)),
            ),
          ],
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