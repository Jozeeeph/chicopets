import 'package:flutter/material.dart';

class Applydiscount {
  static void showDiscountInput(
    BuildContext context,
    int productIndex,
    List<double> discounts,
    List<bool> typeDiscounts,
    VoidCallback onUpdate,
  ) {
    if (productIndex < 0 || productIndex >= discounts.length) {
      print("Error: Invalid product index ($productIndex)");
      return;
    }

    String enteredDiscount = "";
    bool isPercentage = true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choisir la remise'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("%"),
                      Switch(
                        value: isPercentage,
                        onChanged: (value) {
                          setDialogState(() {
                            isPercentage = value;
                          });
                        },
                      ),
                      const Text("DT"),
                    ],
                  ),
                  Text(
                    enteredDiscount.isEmpty
                        ? "0${isPercentage ? '%' : ' DT'}"
                        : "$enteredDiscount${isPercentage ? '%' : ' DT'}",
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
                                  enteredDiscount = "";
                                } else if (number == "OK") {
                                  if (enteredDiscount.isNotEmpty) {
                                    final discount =
                                        double.tryParse(enteredDiscount);
                                    if (discount != null && discount >= 0) {
                                      // ✅ Correction ici : s'assurer que c'est bien un booléen
                                      discounts[productIndex] = discount;
                                      typeDiscounts[productIndex] =
                                          isPercentage ? true : false;
                                      print("isPercentage: $isPercentage");
                                      onUpdate();
                                      Navigator.of(context).pop();
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Veuillez entrer une valeur valide.'),
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Veuillez entrer une valeur avant de valider.'),
                                      ),
                                    );
                                  }
                                } else {
                                  // ✅ Vérification pour éviter les entrées invalides
                                  if (!(number == "0" && enteredDiscount == "0")) {
                                    enteredDiscount += number;
                                  }
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
