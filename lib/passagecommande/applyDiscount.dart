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
    double costPrice = product.prixHT; // Prix de revient (prixHT)
    double sellingPrice = product.prixTTC; // Prix de vente (prixTTC)
    double profit = (product.marge / 100) * costPrice; // Calcul du profit à partir de la marge

    // Vérification des limites de remise avec les valeurs définies par le produit
    double maxPercentageDiscount = (profit / sellingPrice) * 100; // Remise max basée sur le profit
    double maxFixedDiscount = profit; // Remise max en valeur

    // Application des limites du produit
    if (product.remiseMax != null) {
      maxPercentageDiscount = maxPercentageDiscount < product.remiseMax
          ? maxPercentageDiscount
          : product.remiseMax;
    }

    if (product.remiseValeurMax != null) {
      maxFixedDiscount = maxFixedDiscount < product.remiseValeurMax
          ? maxFixedDiscount
          : product.remiseValeurMax;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choisir la remise'),
          content: SizedBox(
            width: 400, // Ajustez la largeur selon vos besoins
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                double discountValue = enteredDiscount.isEmpty
                    ? 0
                    : double.tryParse(enteredDiscount) ?? 0;
                double discountedPrice = isPercentage
                    ? sellingPrice * (1 - discountValue / 100)
                    : sellingPrice - discountValue;
                double newProfit = (product.marge / 100) * costPrice - (sellingPrice - discountedPrice);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vous pouvez faire une remise de maximum ${maxPercentageDiscount.toStringAsFixed(2)}% (${maxFixedDiscount.toStringAsFixed(2)} DT)',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 10),
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
                    Text(
                      'Prix avant remise: ${sellingPrice.toStringAsFixed(2)} DT',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Prix après remise: ${discountedPrice.toStringAsFixed(2)} DT',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Nouveau profit: ${newProfit.toStringAsFixed(2)} DT',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    for (var row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['.', '0', 'C'], // Bouton "C" pour effacer
                      ['OK'] // Bouton "OK" pour valider
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
                                            discount > maxPercentageDiscount) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'La remise ne peut pas dépasser ${maxPercentageDiscount.toStringAsFixed(2)}%'),
                                            ),
                                          );
                                        } else if (!isPercentage &&
                                            discount > maxFixedDiscount) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'La remise ne peut pas dépasser ${maxFixedDiscount.toStringAsFixed(2)} DT'),
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
                                          const SnackBar(
                                            content: Text(
                                                'Veuillez entrer une valeur valide.'),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Veuillez entrer une valeur avant de valider.'),
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
                                      ? const Color(0xFFE53935) // Rouge pour "C"
                                      : number == "OK"
                                          ? const Color(0xFF009688) // Vert pour "OK"
                                          : const Color(0xFF0056A6), // Bleu pour les autres boutons
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
          ),
        );
      },
    );
  }
}