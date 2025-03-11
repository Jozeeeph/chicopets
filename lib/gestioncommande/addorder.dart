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
        input = parts[0] + '.' + parts.sublist(1).join('');
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

    double globalDiscount =
        order.globalDiscount; // Récupération de la remise globale
    double total = calculateTotal(
        selectedProducts, quantityProducts, discounts, globalDiscount);
    String selectedPaymentMethod = "Espèce"; // Default payment method

    TextEditingController globalDiscountController =
        TextEditingController(text: globalDiscount.toString());
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
                              ),
                            ),
                          ),
                          Divider(
                            thickness: 1,
                            color: Colors.black,
                          ), // Separator line

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
                            color: Colors.black,
                          ), // Separator line

                          // Product List from OrderLine
                          if (selectedProducts.isNotEmpty)
                            ...selectedProducts.map((product) {
                              int index = selectedProducts.indexOf(product);
                              double discountedPrice = product.prixTTC *
                                  (1 -
                                      discounts[index] / 100); // Apply discount
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
                          ), // Bottom separator

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
                              if (globalDiscount >
                                  0) // Si une remise globale est appliquée
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Remise: ${globalDiscount.toStringAsFixed(2)} %",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors
                                            .red, // Couleur pour mettre en évidence la remise
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            4), // Espace entre les deux lignes
                                    Text(
                                      "Total après remise: ${order.total.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              else // Si aucune remise globale n'est appliquée
                                Text(
                                  "${order.total.toStringAsFixed(2)} DT",
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
                        SizedBox(height: 10),
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
                              order.globalDiscount = globalDiscount;
                              order.total = calculateTotal(selectedProducts,
                                  quantityProducts, discounts, globalDiscount);
                            });
                          },
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
                        globalDiscount);
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
        selectedProducts, quantityProducts, discounts, globalDiscount);
    String date = DateTime.now().toIso8601String();
    String modePaiement = "Espèces"; // Vous pouvez changer cela si nécessaire

    // Déterminer le statut en fonction du montant donné
    String status = (amountGiven >= total) ? "payée" : "non payée";

    // Calculer le montant restant
    double remainingAmount = (amountGiven < total) ? total - amountGiven : 0.0;
    print("Calculated remainingAmount: $remainingAmount");

    // Préparer les lignes de commande avec les quantités correctes
    List<OrderLine> orderLines = selectedProducts.map((product) {
      int productIndex =
          selectedProducts.indexOf(product); // Trouver l'index correct

      return OrderLine(
        idOrder: 0, // ID temporaire
        idProduct: product.code,
        quantite: quantityProducts[productIndex], // Quantité correcte
        prixUnitaire: product.prixTTC,
        discount: discounts[productIndex], // Quantité correcte
      );
    }).toList();

    // Créer un objet Order
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

    // Sauvegarder la commande dans la base de données
    try {
      int orderId = await SqlDb().addOrder(order);
      if (orderId > 0) {
        print("Order saved successfully with ID: $orderId");
        bool isValidOrder = true; // Pour vérifier la validité de la commande

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
          return; // Arrêter le traitement de la commande si un produit a un stock insuffisant
        }

        // Procéder à la commande si les conditions de stock sont remplies
        for (int i = 0; i < selectedProducts.length; i++) {
          selectedProducts[i].stock -= quantityProducts[i]; // Diminuer le stock
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
    double globalDiscount, // Ajout de la remise globale
  ) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      double discountedPrice = selectedProducts[i].prixTTC *
          (1 - discounts[i] / 100); // Apply discount
      total += discountedPrice * quantityProducts[i];
    }
    double totalAfterGlobalDiscount = total * (1 - globalDiscount / 100);

    return totalAfterGlobalDiscount;
  }
}
