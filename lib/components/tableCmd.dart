import 'dart:ui';
import 'package:caissechicopets/product.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TableCmd extends StatefulWidget {
  final double total;
  final List<Product> selectedProducts;
  final Function(int) onDeleteProduct;
  final VoidCallback onAddProduct;
  final VoidCallback onSearchProduct;
  final VoidCallback onQuantityChange;

  const TableCmd({
    super.key,
    required this.total,
    required this.selectedProducts,
    required this.onDeleteProduct,
    required this.onAddProduct,
    required this.onSearchProduct,
    required this.onQuantityChange,
  });

  @override
  _TableCmdState createState() => _TableCmdState();
}

class _TableCmdState extends State<TableCmd> {
  int? selectedProductIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),

        // Total Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 47, 208, 80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total label and amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL:',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 230, 229, 234)),
                  ),
                  Text(
                    '${widget.total.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                ],
              ),

              // Cashier and Time information
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Caissier: foulen ben foulen', // Cashier name
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    'Time: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', // Current DateTime
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Order Section
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blueAccent,
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
                        child: Text('Prix',
                            style: TextStyle(color: Colors.white))),
                  ],
                ),
              ),
              // Table Content
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
                      },
                      child: Container(
                        color: isSelected
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text(product.code)),
                            Expanded(child: Text(product.designation)),
                            Expanded(child: Text("1")), // Example Quantity
                            Expanded(
                                child: Text(
                                    '${product.prixTTC.toStringAsFixed(2)} DT')),
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
              onPressed: widget.onAddProduct,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('AJOUT PRODUIT',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: selectedProductIndex != null
                  ? () {
                      widget.onDeleteProduct(selectedProductIndex!);
                      setState(() {
                        selectedProductIndex = null; // Reset selection
                      });
                    }
                  : null, // Disable if no row is selected
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('SUPPRIMER',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: widget.onSearchProduct,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('RECHERCHE PRODUIT',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: widget.onQuantityChange,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child:
                  const Text('QUANTITÉ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}
