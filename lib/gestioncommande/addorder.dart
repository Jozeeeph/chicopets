import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';

class Addorder {
  static void showPlaceOrderPopup(
    BuildContext context,
    Order order,
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
  ) async {
    print("seee ${selectedProducts.length}");

    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Aucun produit sélectionné.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: "OK",
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      return;
    }

    String cleanInput(String input) {
      // Supprime tous les caractères non numériques sauf '.'
      input = input.replaceAll(RegExp(r'[^0-9.]'), '');

      // Évite d'avoir plusieurs points décimaux
      List<String> parts = input.split('.');
      if (parts.length > 2) {
        input = parts[0] + '.' + parts.sublist(1).join('');
      }

      // Empêche l'entrée de '.' seul au début
      if (input.startsWith('.')) {
        input = '0$input';
      }

      // Vérifie si la valeur est négative
      double? value = double.tryParse(input);
      if (value == null)
        return ''; // Retourne une chaîne vide pour éviter les erreurs
      if (value < 0) return 'NEGATIVE';

      return input;
    }

    double amountGiven = 0.0;
    double changeReturned = 0.0;
    TextEditingController amountGivenController = TextEditingController();
    TextEditingController changeReturnedController = TextEditingController();

    double globalDiscount = order.globalDiscount;
    double globalDiscountValue = 0.0;
    bool isPercentageDiscount = order.isPercentageDiscount;
    double totalBeforeDiscount = calculateTotalBeforeDiscount(
        selectedProducts, quantityProducts, discounts, typeDiscounts);
    double total = calculateTotal(
        selectedProducts,
        quantityProducts,
        discounts,
        typeDiscounts,
        isPercentageDiscount ? globalDiscount : globalDiscountValue,
        isPercentageDiscount);
    String selectedPaymentMethod = "Espèce";

    TextEditingController globalDiscountController =
        TextEditingController(text: globalDiscount.toString());
    TextEditingController globalDiscountValueController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculer la limite de remise globale
            double maxGlobalDiscountPercentage =
                _calculateMaxGlobalDiscountPercentage(
                    selectedProducts, quantityProducts);
            double maxGlobalDiscountValue = _calculateMaxGlobalDiscountValue(
                selectedProducts, quantityProducts);

            // Texte à afficher pour la limite de remise
            String discountLimitText = isPercentageDiscount
                ? "La remise globale ne peut pas dépasser ${maxGlobalDiscountPercentage.toStringAsFixed(2)}%"
                : "La remise globale ne peut pas dépasser ${maxGlobalDiscountValue.toStringAsFixed(2)} DT";
            void updateTotalAndChange() {
              setState(() {
                totalBeforeDiscount = calculateTotalBeforeDiscount(
                    selectedProducts,
                    quantityProducts,
                    discounts,
                    typeDiscounts);
                total = calculateTotal(
                    selectedProducts,
                    quantityProducts,
                    discounts,
                    typeDiscounts,
                    isPercentageDiscount ? globalDiscount : globalDiscountValue,
                    isPercentageDiscount);
                changeReturned = amountGiven - total;
                changeReturnedController.text =
                    changeReturned.toStringAsFixed(2);
              });
            }

            bool validateDiscounts() {
              for (int i = 0; i < selectedProducts.length; i++) {
                double discount = discounts[i];
                bool isPercentage = typeDiscounts[i];
                double remiseMax = selectedProducts[i].remiseMax;
                double remiseValeurMax = selectedProducts[i].remiseValeurMax;

                if (isPercentage && discount > remiseMax) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "La remise sur ${selectedProducts[i].designation} ne peut pas dépasser ${remiseMax}%."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return false;
                } else if (!isPercentage && discount > remiseValeurMax) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "La remise sur ${selectedProducts[i].designation} ne peut pas dépasser ${remiseValeurMax} DT."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return false;
                }
              }

              // Vérification de la remise globale
              double globalDiscountValue = isPercentageDiscount
                  ? globalDiscount
                  : globalDiscountValueController.text.isEmpty
                      ? 0.0
                      : double.tryParse(globalDiscountValueController.text) ??
                          0.0;

              if (isPercentageDiscount &&
                  globalDiscount >
                      _calculateMaxGlobalDiscountPercentage(
                          selectedProducts, quantityProducts)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "La remise globale ne peut pas dépasser ${_calculateMaxGlobalDiscountPercentage(selectedProducts, quantityProducts)}%."),
                    backgroundColor: Colors.red,
                  ),
                );
                return false;
              } else if (!isPercentageDiscount &&
                  globalDiscountValue >
                      _calculateMaxGlobalDiscountValue(
                          selectedProducts, quantityProducts)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "La remise globale ne peut pas dépasser ${_calculateMaxGlobalDiscountValue(selectedProducts, quantityProducts)} DT."),
                    backgroundColor: Colors.red,
                  ),
                );
                return false;
              }

              return true;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                "Confirmer la commande",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0056A6),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt, size: 24), // Icône Material
                                SizedBox(width: 8),
                                Text(
                                  "Ticket de Commande",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            thickness: 1,
                            color: Colors.black,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Qt",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Article",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Prix U",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Montant",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            thickness: 1,
                            color: Colors.black,
                          ),
                          if (selectedProducts.isNotEmpty)
                            ...selectedProducts.map((product) {
                              int index = selectedProducts.indexOf(product);
                              double discountedPrice = typeDiscounts[index]
                                  ? product.prixTTC *
                                      (1 - discounts[index] / 100)
                                  : product.prixTTC - discounts[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "${quantityProducts[index]}X",
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        product.designation,
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "${discountedPrice.toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "${(discountedPrice * quantityProducts[index]).toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()
                          else
                            Center(child: Text("Aucun produit sélectionné.")),
                          Divider(
                            thickness: 1,
                            color: Colors.black,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total avant remise:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${totalBeforeDiscount.toStringAsFixed(2)} DT",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total après remise:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isPercentageDiscount && globalDiscount > 0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Remise: ${globalDiscount.toStringAsFixed(2)} %",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "${total.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              else if (!isPercentageDiscount &&
                                  globalDiscountValue > 0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Remise: ${globalDiscountValue.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "${total.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  "${total.toStringAsFixed(2)} DT",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Remise Globale
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Type de Remise:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Radio(
                              value: true,
                              groupValue: isPercentageDiscount,
                              onChanged: (value) {
                                setState(() {
                                  isPercentageDiscount = value as bool;
                                  globalDiscountController.text = '';
                                  globalDiscountValueController.text = '';
                                  updateTotalAndChange();
                                });
                              },
                            ),
                            Text("Pourcentage"),
                            Radio(
                              value: false,
                              groupValue: isPercentageDiscount,
                              onChanged: (value) {
                                setState(() {
                                  isPercentageDiscount = value as bool;
                                  globalDiscountController.text = '';
                                  globalDiscountValueController.text = '';
                                  updateTotalAndChange();
                                });
                              },
                            ),
                            Text("Valeur (DT)"),
                          ],
                        ),
                        SizedBox(height: 16),
                        if (isPercentageDiscount)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: globalDiscountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Remise Globale (%)",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    globalDiscount =
                                        double.tryParse(value) ?? 0.0;
                                    updateTotalAndChange();
                                  });
                                },
                              ),
                              SizedBox(height: 8),
                              Text(
                                discountLimitText,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        if (!isPercentageDiscount)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: globalDiscountValueController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Remise Globale (DT)",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    globalDiscountValue =
                                        double.tryParse(value) ?? 0.0;
                                    updateTotalAndChange();
                                  });
                                },
                              ),
                              SizedBox(height: 8),
                              Text(
                                discountLimitText,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Payment Method Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mode de Paiement:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Radio<String>(
                              value: "Espèce",
                              groupValue: selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentMethod = value!;
                                });
                              },
                            ),
                            Text("Espèce"),
                            Radio<String>(
                              value: "Carte Bancaire",
                              groupValue: selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentMethod = value!;
                                });
                              },
                            ),
                            Text("Carte Bancaire"),
                            Radio<String>(
                              value: "Chèque",
                              groupValue: selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentMethod = value!;
                                });
                              },
                            ),
                            Text("Chèque"),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Total Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: amountGivenController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Donnée (Exp:12.50 DT)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                String cleanedValue = cleanInput(value);

                                if (cleanedValue == 'NEGATIVE') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Veuillez entrer un nombre positif.",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  amountGivenController.text = '';
                                  return;
                                }

                                if (cleanedValue == 'USE_DOT') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Utilisez un point (.) au lieu d'une virgule (,).",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                amountGivenController.text = cleanedValue;
                                amountGivenController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: cleanedValue.length),
                                );
                                amountGiven =
                                    double.tryParse(cleanedValue) ?? 0.0;
                                changeReturned = amountGiven - total;
                                changeReturnedController.text =
                                    changeReturned.toStringAsFixed(2);
                              });
                            }),
                        SizedBox(height: 10),
                        TextField(
                          controller: changeReturnedController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Rendu (DT)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "Annuler",
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (!validateDiscounts()) {
                      return;
                    }
                    Navigator.of(context).pop();
                    _confirmPlaceOrder(
                        context,
                        selectedProducts,
                        quantityProducts,
                        amountGiven,
                        discounts,
                        typeDiscounts,
                        isPercentageDiscount
                            ? globalDiscount
                            : globalDiscountValue,
                        isPercentageDiscount);
                  },
                  child: Text(
                    "Confirmer",
                    style: TextStyle(color: Color(0xFF009688)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static double _calculateMaxGlobalDiscountPercentage(
      List<Product> products, List<int> quantities) {
    double maxDiscount = double.infinity;
    for (int i = 0; i < products.length; i++) {
      double productMaxDiscount = products[i].remiseMax;
      if (productMaxDiscount < maxDiscount) {
        maxDiscount = productMaxDiscount;
      }
    }
    return maxDiscount;
  }

  static double _calculateMaxGlobalDiscountValue(
      List<Product> products, List<int> quantities) {
    double maxDiscountValue = 0.0;
    for (int i = 0; i < products.length; i++) {
      double productMaxDiscount = products[i].remiseMax;
      double productPrice = products[i].prixTTC;
      int quantity = quantities[i];
      maxDiscountValue += productPrice * quantity * (productMaxDiscount / 100);
    }
    return maxDiscountValue;
  }

  static void _confirmPlaceOrder(
    BuildContext context,
    List<Product> selectedProducts,
    List<int> quantityProducts,
    double amountGiven,
    List<double> discounts,
    List<bool> typeDiscounts,
    double globalDiscount,
    bool isPercentageDiscount,
  ) async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun produit sélectionné.")),
      );
      return;
    }

    double totalBeforeDiscount = calculateTotalBeforeDiscount(
        selectedProducts, quantityProducts, discounts, typeDiscounts);
    double total = calculateTotal(
      selectedProducts,
      quantityProducts,
      discounts,
      typeDiscounts,
      globalDiscount,
      isPercentageDiscount,
    );

    String status;
    double remainingAmount;

    if (amountGiven >= total) {
      status = "payée";
      remainingAmount = 0.0;
    } else {
      status = "semi-payée";
      remainingAmount = total - amountGiven;
    }

    print("Total avant remise: $totalBeforeDiscount");
    print("Total après remise: $total");
    print("Montant donné: $amountGiven");
    print("Statut de la commande: $status");
    print("Montant restant: $remainingAmount");

    List<OrderLine> orderLines = selectedProducts.map((product) {
      int productIndex = selectedProducts.indexOf(product);
      return OrderLine(
        idOrder: 0,
        idProduct: product.code,
        quantite: quantityProducts[productIndex],
        prixUnitaire: product.prixTTC,
        discount: discounts[productIndex],
        isPercentage: typeDiscounts[productIndex],
      );
    }).toList();

    Order order = Order(
      date: DateTime.now().toIso8601String(),
      orderLines: orderLines,
      total: total,
      modePaiement: "Espèces",
      status: status,
      remainingAmount: remainingAmount,
      globalDiscount: globalDiscount,
      isPercentageDiscount: isPercentageDiscount,
    );

    print("Order to be saved: ${order.toMap()}");

    try {
      int orderId = await SqlDb().addOrder(order);
      if (orderId > 0) {
        print("Order saved successfully with ID: $orderId");

        bool isValidOrder = true;
        for (int i = 0; i < selectedProducts.length; i++) {
          if (selectedProducts[i].stock == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "${selectedProducts[i].designation} est en rupture de stock !"),
                backgroundColor: Colors.red,
              ),
            );
            isValidOrder = false;
          } else if (selectedProducts[i].stock - quantityProducts[i] < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Stock insuffisant ! Il ne reste que ${selectedProducts[i].stock} de ${selectedProducts[i].designation}."),
                backgroundColor: Colors.orange,
              ),
            );
            isValidOrder = false;
          }
        }

        if (!isValidOrder) {
          return;
        }

        for (int i = 0; i < selectedProducts.length; i++) {
          selectedProducts[i].stock -= quantityProducts[i];
          await SqlDb().updateProductStock(
              selectedProducts[i].code, selectedProducts[i].stock);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Commande passée avec succès !"),
            backgroundColor: Colors.green,
          ),
        );

        selectedProducts.clear();
        quantityProducts.clear();
        discounts.clear();
        typeDiscounts.clear();
      } else {
        print("Failed to save order.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'enregistrement de la commande."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error saving order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'enregistrement de la commande: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static double calculateTotal(
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
    double globalDiscount,
    bool isPercentageDiscount,
  ) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      double productTotal = selectedProducts[i].prixTTC * quantityProducts[i];

      if (typeDiscounts[i]) {
        productTotal *= (1 - discounts[i] / 100);
      } else {
        productTotal -= discounts[i];
      }

      if (productTotal < 0) {
        productTotal = 0.0;
      }

      total += productTotal;
    }

    if (isPercentageDiscount) {
      total *= (1 - globalDiscount / 100);
    } else {
      total -= globalDiscount;
    }

    return total;
  }

  static double calculateTotalBeforeDiscount(
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
  ) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      double productTotal = selectedProducts[i].prixTTC * quantityProducts[i];
      total += productTotal;
    }
    return total;
  }
}
