import 'package:caissechicopets/passagecommande/applyDiscount.dart';
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
  final List<double> discounts;
  final List<bool> typeDiscounts;
  final Function(int) onApplyDiscount;
  final Function(int) onDeleteProduct;
  final RefreshCallback onAddProduct;
  final VoidCallback onSearchProduct;
  final double globalDiscount;

  final Function(int) onQuantityChange;
  final double Function(List<Product>, List<int>, List<double>, List<bool>, double globalDiscount)
      calculateTotal;
  final VoidCallback onFetchOrders;
  final VoidCallback onPlaceOrder;

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
          widget.discounts.add(0.0); // Add a discount value for the new product
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table on the left
        Expanded(
          flex: 2,
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
                          '${widget.calculateTotal(widget.selectedProducts, widget.quantityProducts, widget.discounts, widget.typeDiscounts,widget.globalDiscount).toStringAsFixed(2)} DT',
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          'Time: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const TextStyle(
                              fontSize: 18,
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

              // Product table
              Container(
                height: 270,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color.fromARGB(255, 1, 42, 79)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Table Header
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
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Désignation',
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Quantité',
                                  style: TextStyle(color: Colors.white))),
                          Expanded(
                              child: Text('Remise',
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

                    // Table Body
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

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedProductIndex = index;
                                      });
                                    },
                                    child: Container(
                                      color: isSelected
                                          ? const Color(0xFF26A9E0)
                                              .withOpacity(0.2)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(product.code)),
                                          Expanded(
                                              child: Text(product.designation)),
                                          Expanded(
                                              child: Text(
                                                  '${widget.quantityProducts[index]}')),
                                          Expanded(
                                              child: Text(
                                                  '${widget.discounts[index]} ${widget.typeDiscounts[index] ? '%' : 'DT'}')),
                                          Expanded(
                                              child: Text(
                                                  '${product.prixTTC.toStringAsFixed(2)} DT')),
                                          Expanded(
                                            child: Text(
                                              widget.typeDiscounts[
                                                      index] // Check if the discount is a percentage
                                                  ? "${(product.prixTTC * widget.quantityProducts[index] * (1 - widget.discounts[index] / 100)).toStringAsFixed(2)} DT" // Percentage discount
                                                  : "${(product.prixTTC * widget.quantityProducts[index] - widget.discounts[index]).toStringAsFixed(2)} DT", // Fixed value discount
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
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 170),
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedProductIndex != null
                        ? const Color(0xFFE53935)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 18),
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
              const SizedBox(height: 8),
              GestureDetector(
                onTap: selectedProductIndex != null
                    ? () {
                        Applydiscount.showDiscountInput(
                          context,
                          selectedProductIndex!,
                          widget.discounts,
                          widget.typeDiscounts,
                          () => setState(() {}),
                        );
                      }
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
                      Icon(Icons.discount, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('REMISE PAR LIGNE',
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
                      Text('CHANGER QUANTITE',
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
}
