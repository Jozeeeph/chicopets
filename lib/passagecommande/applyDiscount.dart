import 'package:flutter/material.dart';

class Applydiscount {
  static void showDiscountInput(
    BuildContext context,
    int productIndex,
    List<double> discounts,
    VoidCallback onUpdate,
  ) {
    if (productIndex < 0 || productIndex >= discounts.length) {
      print("Error: Invalid product index ($productIndex)");
      return;
    }

    String enteredDiscount = ""; // Start empty

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choisir le pourcentage de remise'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    enteredDiscount.isEmpty ? "0%" : "$enteredDiscount%",
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
                                  enteredDiscount = ""; // Clear input
                                } else if (number == "OK") {
                                  if (enteredDiscount.isNotEmpty) {
                                    final discount =
                                        double.tryParse(enteredDiscount);
                                    if (discount != null &&
                                        discount >= 0 &&
                                        discount <= 100) {
                                      discounts[productIndex] = discount;
                                      onUpdate(); // Callback to update UI
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Veuillez entrer un pourcentage valide (0-100).'),
                                        ),
                                      );
                                    }
                                  }
                                  Navigator.of(context).pop(); // Close dialog
                                } else {
                                  enteredDiscount += number; // Append number
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0056A6),
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
