import 'package:flutter/material.dart';
import 'package:caissechicopets/product.dart';

class Applydiscount {
  static void showDiscountInput(
    BuildContext context,
    int productIndex,
    List<double> discounts,
    List<bool> typeDiscounts,
    List<Product> selectedProducts,
    VoidCallback onUpdate,
  ) {
    if (productIndex < 0 || productIndex >= discounts.length) {
      print("Error: Invalid product index ($productIndex)");
      return;
    }

    String enteredDiscount = "";
    bool isPercentage = true;
    Product product = selectedProducts[productIndex];

    // Prix et profit initiaux
    double prixTTC = product.prixTTC;
    double prixAchat = product.prixHT; // Prix d'achat (coût)
    double profitAvantRemise = (product.marge / 100) * prixAchat;

    // Calculer la remise max en pourcentage, basé sur la marge
    double remiseMaxPourcentage = product.remiseMax;
    double remiseMaxValeur = product.remiseValeurMax;

    // Calculate the maximum discount value based on the profit
    double maxDiscountValue = (remiseMaxPourcentage / 100) * profitAvantRemise;

    // Convert this discount value to a percentage of the total price
    double remiseMaxPourcentageOnPrice = (maxDiscountValue / prixTTC) * 100;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Choisir la remise',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                double discountValue = enteredDiscount.isEmpty
                    ? 0
                    : double.tryParse(enteredDiscount) ?? 0;
                double discountedPrice = isPercentage
                    ? prixTTC * (1 - discountValue / 100)
                    : prixTTC - discountValue;
                double profitApresRemise =
                    profitAvantRemise - (prixTTC - discountedPrice);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Remise max: ${remiseMaxPourcentageOnPrice.toStringAsFixed(2)}% '
                      '(${remiseMaxValeur.toStringAsFixed(2)} DT)',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "DT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: isPercentage,
                          onChanged: (value) {
                            setDialogState(() {
                              isPercentage = value;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                        const Text(
                          "%",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      enteredDiscount.isEmpty
                          ? "0${isPercentage ? '%' : ' DT'}"
                          : "$enteredDiscount${isPercentage ? '%' : ' DT'}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Prix avant remise: ${prixTTC.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Prix après remise: ${discountedPrice.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Profit avant remise: ${profitAvantRemise.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Profit après remise: ${profitApresRemise.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 16,
                        color: profitApresRemise >= 0
                            ? Colors.green
                            : Colors.red, // Rouge si perte
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['.', '0', 'C'],
                      ['OK']
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
                                        if (isPercentage &&
                                            discount >
                                                remiseMaxPourcentageOnPrice) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.warning,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'La remise ne peut pas dépasser ${remiseMaxPourcentageOnPrice.toStringAsFixed(2)}% du prix total.',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.orange,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        } else if (!isPercentage &&
                                            discount > remiseMaxValeur) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.warning,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'La remise ne peut pas dépasser ${remiseMaxValeur.toStringAsFixed(2)} DT',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.orange,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        } else {
                                          discounts[productIndex] = discount;
                                          typeDiscounts[productIndex] =
                                              isPercentage;
                                          onUpdate();
                                          Navigator.of(context).pop();
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Veuillez entrer une valeur valide.',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Veuillez entrer une valeur avant de valider.',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  } else if (number == ".") {
                                    if (!enteredDiscount.contains(".")) {
                                      enteredDiscount += number;
                                    }
                                  } else {
                                    if (!(number == "0" &&
                                        enteredDiscount == "0")) {
                                      enteredDiscount += number;
                                    }
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(4.0),
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: number == "C"
                                      ? const Color(0xFFE53935)
                                      : number == "OK"
                                          ? const Color(0xFF009688)
                                          : const Color(0xFF0056A6),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    number,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
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
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 10,
        );
      },
    );
  }
}