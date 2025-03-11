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
            style: TextStyle(color: Colors.white), // White text for contrast
          ),
          backgroundColor: Color(0xFFE53935), // Warm Red for error
          behavior: SnackBarBehavior.floating, // Floating style
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Rounded corners
          ),
          action: SnackBarAction(
            label: "OK",
            textColor: Colors.white, // White text for contrast
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      return;
    }

    String cleanInput(String input) {
      // Remplace tout ce qui n'est pas un chiffre ou un point décimal
      input = input.replaceAll(RegExp(r'[^0-9.]'), '');

      // Empêcher plusieurs points décimaux
      List<String> parts = input.split('.');
      if (parts.length > 2) {
        input = '${parts[0]}.${parts.sublist(1).join('')}';
      }

      // Vérifier si le nombre est positif
      double? value = double.tryParse(input);
      if (value != null && value < 0) {
        return 'NEGATIVE'; // Code spécial pour signaler un nombre négatif
      }

      return input;
    }

    double amountGiven = 0.0;
    double changeReturned = 0.0;
    TextEditingController amountGivenController = TextEditingController();
    TextEditingController changeReturnedController = TextEditingController();

    double total = calculateTotal(
        selectedProducts, quantityProducts, discounts, typeDiscounts);
    String selectedPaymentMethod = "Espèce"; // Default payment method

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                "Confirmer la commande",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0056A6), // Deep Blue for title
                ),
              ),
              content: SingleChildScrollView(
                // Wrap the content in SingleChildScrollView
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Static list of products and quantities
                    // Styled product list (receipt look)
                    Container(
                      width: double.infinity, // Ensure full width
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.black,
                            width: 1), // Border for ticket feel
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
                          // Title
                          Center(
                            child: Text(
                              "🧾 Ticket de Commande",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                // Monospace for receipt style
                              ),
                            ),
                          ),
                          Divider(
                              thickness: 1,
                              color: Colors.black), // Separator line

                          // Header Row
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
                              color: Colors.black), // Separator line

                          // Product List from OrderLine
                          if (selectedProducts.isNotEmpty)
                            ...selectedProducts.map((product) {
                              int index = selectedProducts.indexOf(product);
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
                                        "${product.prixTTC.toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        typeDiscounts[index]
                                            ? "${(product.prixTTC * quantityProducts[index] * (1 - discounts[index] / 100)).toStringAsFixed(2)} DT" // Percentage discount
                                            : "${(product.prixTTC * quantityProducts[index] - discounts[index]).toStringAsFixed(2)} DT",
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
                            })
                          else
                            Center(child: Text("Aucun produit sélectionné.")),

                          Divider(
                              thickness: 1,
                              color: Colors.black), // Bottom separator

                          // Total
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
                              Text(
                                "${total.toStringAsFixed(2)} DT", // Display total from order
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
                        // Input for "Donnée" (Amount Given)
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

                              // Vérifier si le nombre est négatif
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

                              // Appliquer la valeur nettoyée
                              amountGivenController.text = cleanedValue;
                              amountGivenController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: cleanedValue.length),
                              );

                              // Calcul du rendu de monnaie
                              amountGiven =
                                  double.tryParse(cleanedValue) ?? 0.0;
                              changeReturned = amountGiven - total;
                              changeReturnedController.text =
                                  changeReturned.toStringAsFixed(2);
                            });
                          },
                        ),

                        SizedBox(height: 10),

                        // "Rendu" (Change Returned) - Readonly
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
                    style: TextStyle(
                        color: Color(0xFFE53935)), // Warm Red for cancel
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close popup
                    _confirmPlaceOrder(
                        context,
                        selectedProducts,
                        quantityProducts,
                        amountGiven,
                        discounts,
                        typeDiscounts);
                  },
                  child: Text(
                    "Confirmer",
                    style: TextStyle(
                        color: Color(0xFF009688)), // Teal Green for confirm
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
  ) async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun produit sélectionné.")),
      );
      return;
    }

    print("saving ....");

    double total = calculateTotal(
        selectedProducts, quantityProducts, discounts, typeDiscounts);
    String date = DateTime.now().toIso8601String();
    String modePaiement = "Espèces"; // You can change this if needed

    // Determine the status based on the amount given
    String status = (amountGiven >= total) ? "payée" : "non payée";

    // Calculate the remaining amount
    double remainingAmount = (amountGiven < total) ? total - amountGiven : 0.0;
    print("Calculated remainingAmount: $remainingAmount");

    // Prepare order lines with correct quantities
    List<OrderLine> orderLines = selectedProducts.map((product) {
      int productIndex =
          selectedProducts.indexOf(product); // Find correct index

      return OrderLine(
        idOrder: 0, // Temporary ID
        idProduct: product.code,
        quantite: quantityProducts[productIndex], // Correct quantity
        prixUnitaire: product.prixTTC,
        discount: discounts[productIndex], // Correct discount
        isPercentage: typeDiscounts[productIndex], // Correct discount type
      );
    }).toList();

    // Create an Order object
    Order order = Order(
      date: date,
      orderLines: orderLines,
      total: total,
      modePaiement: modePaiement,
      status: status,
      remainingAmount: remainingAmount,
    );
    print(order.remainingAmount);

    // Save order to database
    int orderId = await SqlDb().addOrder(order);
    if (orderId > 0) {
      bool isValidOrder = true; // To check order validity

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
                " Stock insuffisant ! Il ne reste que ${selectedProducts[i].stock} de ${selectedProducts[i].designation}.",
              ),
              backgroundColor: Colors.orange,
            ),
          );
          isValidOrder = false;
        }
      }

      if (!isValidOrder) {
        return; // Stop order processing if any product has insufficient stock
      }

      // Proceed with order if stock conditions are met
      for (int i = 0; i < selectedProducts.length; i++) {
        selectedProducts[i].stock -= quantityProducts[i]; // Decrease stock
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'enregistrement de la commande."),
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
  ) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      double discountedPrice;

      if (typeDiscounts[i]) {
        // If the discount is a percentage
        discountedPrice =
            selectedProducts[i].prixTTC * (1 - discounts[i] / 100);
      } else {
        // If the discount is a fixed value (DT)
        discountedPrice = selectedProducts[i].prixTTC - discounts[i];
      }

      total += discountedPrice * quantityProducts[i];
      print(total);
    }
    return total;
  }
}
