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
      input = input.replaceAll(RegExp(r'[^0-9.]'), '');
      List<String> parts = input.split('.');
      if (parts.length > 2) {
        input = parts[0] + '.' + parts.sublist(1).join('');
      }
      double? value = double.tryParse(input);
      if (value != null && value < 0) {
        return 'NEGATIVE';
      }
      return input;
    }

    double amountGiven = 0.0;
    double changeReturned = 0.0;
    TextEditingController amountGivenController = TextEditingController();
    TextEditingController changeReturnedController = TextEditingController();

    double globalDiscount = order.globalDiscount;
    double globalDiscountValue = 0.0;
    bool isPercentageDiscount = true;
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
            void updateTotalAndChange() {
              setState(() {
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
                            child: Text(
                              "🧾 Ticket de Commande",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
                                  ? product.prixTTC * (1 - discounts[index] / 100)
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
                                "Total:",
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
                                      "Total après remise: ${total.toStringAsFixed(2)} DT",
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
                                      "Total après remise: ${total.toStringAsFixed(2)} DT",
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
                          TextField(
                            controller: globalDiscountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Remise Globale (%)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                globalDiscount = double.tryParse(value) ?? 0.0;
                                updateTotalAndChange();
                              });
                            },
                          ),
                        if (!isPercentageDiscount)
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
                            labelText: "Donnée (DT)",
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
                          },
                        ),
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
                            : globalDiscountValue);
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

  static void _confirmPlaceOrder(
    BuildContext context,
    List<Product> selectedProducts,
    List<int> quantityProducts,
    double amountGiven,
    List<double> discounts,
    List<bool> typeDiscounts,
    double globalDiscount,
  ) async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun produit sélectionné.")),
      );
      return;
    }

    print("saving ....");

    double total = calculateTotal(
        selectedProducts, quantityProducts, discounts, typeDiscounts, globalDiscount, true);
    String date = DateTime.now().toIso8601String();
    String modePaiement = "Espèces";

    String status = (amountGiven >= total) ? "payée" : "non payée";
    double remainingAmount = (amountGiven < total) ? total - amountGiven : 0.0;
    print("Calculated remainingAmount: $remainingAmount");

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
      date: date,
      orderLines: orderLines,
      total: total,
      modePaiement: modePaiement,
      status: status,
      remainingAmount: remainingAmount,
      globalDiscount: globalDiscount,
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
      total = total * (1 - globalDiscount / 100);
    } else {
      total = total - globalDiscount;
    }

    return total;
  }
}