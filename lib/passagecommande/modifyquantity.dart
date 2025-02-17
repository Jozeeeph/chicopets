import 'package:flutter/material.dart';

class ModifyQt {
  static void showQuantityInput(BuildContext context, int productIndex, List<int> quantityProducts, VoidCallback onUpdate) {
    if (productIndex < 0 || productIndex >= quantityProducts.length) {
      print("Error: Invalid product index ($productIndex)");
      return;
    }

    String enteredQuantity = ""; // Start empty instead of showing default value

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Changer la quantité'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    enteredQuantity.isEmpty ? "0" : enteredQuantity,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  for (var row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['C', '0', 'OK']
                  ])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((number) {
                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (number == "C") {
                                  enteredQuantity = ""; // Clear input
                                } else if (number == "OK") {
                                  if (enteredQuantity.isNotEmpty) {
                                    quantityProducts[productIndex] = int.parse(enteredQuantity);
                                    onUpdate(); // Callback to update UI
                                  }
                                  Navigator.of(context).pop(); // Close dialog
                                } else {
                                  enteredQuantity += number; // Append number
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  number,
                                  style: const TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
