import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';

class Addorder {
  static void showPlaceOrderPopup(BuildContext context, Order order,
      List<Product> selectedProducts, List<int> quantityProducts) async {
    print("seee ${selectedProducts.length}");

    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun produit sélectionné.")),
      );
      return;
    }

    double amountGiven = 0.0;
    double changeReturned = 0.0;
    TextEditingController amountGivenController = TextEditingController();
    TextEditingController changeReturnedController = TextEditingController();

    double total = calculateTotal(selectedProducts, quantityProducts);
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
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6)), // Deep Blue
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
                        border: Border.all(
                            color: Color(0xFFE0E0E0), // Light Gray
                            width: 1),
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
                                color: Color(0xFF0056A6), // Deep Blue
                              ),
                            ),
                          ),
                          Divider(
                              thickness: 1,
                              color: Color(0xFFE0E0E0)), // Light Gray

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
                                        color: Color(0xFF000000)), // Deep Blue
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Article",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF000000)), // Deep Blue
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "Prix U",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF000000)), // Deep Blue
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
                                        color: Color(0xFF000000)), // Deep Blue
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                              thickness: 1,
                              color: Color(0xFFE0E0E0)), // Light Gray

                          if (selectedProducts.isNotEmpty)
                            ...selectedProducts.map((product) {
                              int index = selectedProducts.indexOf(product);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
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
                                            color: Color(0xFF000000)), // Deep Blue
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        product.designation,
                                        style: TextStyle(
                                            fontSize: 16, 
                                            color: Color(0xFF000000)), // Deep Blue
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "${product.prixTTC.toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                            fontSize: 16, 
                                            color: Color(0xFF000000)), // Deep Blue
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "${(product.prixTTC * quantityProducts[index]).toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF000000)), // Deep Blue
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()
                          else
                            Center(child: Text("Aucun produit sélectionné.", style: TextStyle(color: Color(0xFF0056A6)))), // Deep Blue

                          Divider(
                              thickness: 1,
                              color: Color(0xFFE0E0E0)), // Light Gray

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total:",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0056A6)), // Deep Blue
                              ),
                              Text(
                                "${total.toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF000000)), // Deep Blue
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mode de Paiement:",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056A6))), // Deep Blue
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
                              activeColor: Color(0xFF009688), // Teal Green
                            ),
                            Text("Espèce", style: TextStyle(color: Color(0xFF000000))), // Deep Blue
                            Radio<String>(
                              value: "Carte Bancaire",
                              groupValue: selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentMethod = value!;
                                });
                              },
                              activeColor: Color(0xFF009688), // Teal Green
                            ),
                            Text("Carte Bancaire", style: TextStyle(color: Color(0xFF000000))), // Deep Blue
                            Radio<String>(
                              value: "Chèque",
                              groupValue: selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentMethod = value!;
                                });
                              },
                              activeColor: Color(0xFF009688), // Teal Green
                            ),
                            Text("Chèque", style: TextStyle(color: Color(0xFF000000))), // Deep Blue
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: amountGivenController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Donnée (DT)",
                            labelStyle: TextStyle(color: Color(0xFF0056A6)), // Deep Blue
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF26A9E0)), // Sky Blue
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              amountGiven = double.tryParse(value) ?? 0.0;
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
                            labelStyle: TextStyle(color: Color(0xFF0056A6)), // Deep Blue
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF26A9E0)), // Sky Blue
                            ),
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
                  child: Text("Annuler", style: TextStyle(color: Color(0xFFE53935))), // Warm Red
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _confirmPlaceOrder(
                        context, selectedProducts, quantityProducts);
                  },
                  child: Text("Confirmer", style: TextStyle(color: Color(0xFF009688))), // Teal Green
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _confirmPlaceOrder(BuildContext context,
      List<Product> selectedProducts, List<int> quantityProducts) async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun produit sélectionné.", style: TextStyle(color: Colors.white))),
      );
      return;
    }

    double total = calculateTotal(selectedProducts, quantityProducts);
    String date = DateTime.now().toIso8601String();
    String modePaiement = "Espèces";

    List<OrderLine> orderLines = selectedProducts.map((product) {
      int productIndex = selectedProducts.indexOf(product);

      return OrderLine(
        idOrder: 0,
        idProduct: product.code,
        quantite: quantityProducts[productIndex],
        prixUnitaire: product.prixTTC,
      );
    }).toList();

    Order order = Order(
      date: date,
      orderLines: orderLines,
      total: total,
      modePaiement: modePaiement,
    );

    int orderId = await SqlDb().addOrder(order);

    if (orderId > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Commande passée avec succès !", style: TextStyle(color: Colors.white))),
      );

      selectedProducts.clear();
      quantityProducts.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Erreur lors de l'enregistrement de la commande.", style: TextStyle(color: Colors.white))),
      );
    }
  }

  static double calculateTotal(
      List<Product> selectedProducts, List<int> quantityProducts) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      total += selectedProducts[i].prixTTC * quantityProducts[i];
    }
    return total;
  }
}