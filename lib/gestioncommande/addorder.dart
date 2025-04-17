import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/views/client_views/client_management.dart';
import 'package:caissechicopets/gestioncommande/getorderlist.dart'; // Add this import

class Addorder {
  static void _showClientSelection(
      BuildContext context, Function(Client) onClientSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sélectionner un client'),
        content: SizedBox(
          width: double.maxFinite,
          child: ClientManagementWidget(
            onClientSelected: (client) {
              onClientSelected(client);
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  static void showPlaceOrderPopup(
    BuildContext context,
    Order order,
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
  ) async {
    Client? selectedClient;
    int numberOfTickets = 1;

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
              bool hasProductDiscount =
                  discounts.any((discount) => discount > 0);

              // Vérification des limites de remise par produit
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

              // Vérification des limites de remise globale (même si cachée)
              if (!hasProductDiscount) {
                double currentGlobalDiscount =
                    isPercentageDiscount ? globalDiscount : globalDiscountValue;

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
                child: Container(
                  width: MediaQuery.of(context).size.width *
                      0.65, // Prend 65% de la largeur de l'écran
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Colonne de gauche - Ticket de commande
                      // Colonne de gauche - Ticket de commande
                      Expanded(
                        flex: 5,
                        child: Container(
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
                                    Icon(Icons.receipt, size: 24),
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
                              Divider(thickness: 1, color: Colors.black),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                              Divider(thickness: 1, color: Colors.black),
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
                                Center(
                                    child: Text("Aucun produit sélectionné.")),
                              Divider(thickness: 1, color: Colors.black),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              // Section Client ajoutée ici
                              Divider(thickness: 1, color: Colors.black),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Client:",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    selectedClient != null
                                        ? "${selectedClient!.name} ${selectedClient!.firstName}"
                                        : "Non spécifié",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: selectedClient == null
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(thickness: 1, color: Colors.black),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total après remise:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isPercentageDiscount &&
                                      globalDiscount > 0)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                      ),

                      SizedBox(width: 16),

                      // Colonne de droite - Options de paiement
                      Expanded(
                        flex: 5, // 40% de l'espace
                        child: Column(children: [
                          // Sélection du client
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person,
                                    color: Colors.blue, size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Client',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        selectedClient != null
                                            ? '${selectedClient!.name} ${selectedClient!.firstName}'
                                            : 'Non spécifié',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                      selectedClient != null
                                          ? Icons.edit
                                          : Icons.add_circle_outline,
                                      color: Colors.blue),
                                  onPressed: () {
                                    _showClientSelection(context, (client) {
                                      setState(() {
                                        selectedClient = client;
                                      });
                                    });
                                  },
                                  tooltip: 'Sélectionner un client',
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // Remise Globale (si aucune remise produit)
                          if (!discounts.any((discount) => discount > 0))
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Remise Globale:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text("Type de Remise:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Radio(
                                      value: true,
                                      groupValue: isPercentageDiscount,
                                      onChanged: (value) {
                                        setState(() {
                                          isPercentageDiscount = value as bool;
                                          globalDiscountController.text = '';
                                          globalDiscountValueController.text =
                                              '';
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
                                          globalDiscountValueController.text =
                                              '';
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        "La remise globale ne peut pas dépasser ${_calculateMaxGlobalDiscountPercentage(selectedProducts, quantityProducts).toStringAsFixed(2)}%",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!isPercentageDiscount)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller:
                                            globalDiscountValueController,
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
                                        "La remise globale ne peut pas dépasser ${_calculateMaxGlobalDiscountValue(selectedProducts, quantityProducts).toStringAsFixed(2)} DT",
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

                          // Mode de paiement
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Mode de Paiement:",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
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
                                    value: "TPE",
                                    groupValue: selectedPaymentMethod,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedPaymentMethod = value!;
                                      });
                                    },
                                  ),
                                  Text("TPE"),
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

                          // Montant donné et rendu
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: amountGivenController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Montant donné (DT)",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    String cleanedValue = cleanInput(value);
                                    if (cleanedValue == 'NEGATIVE') {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Veuillez entrer un nombre positif.",
                                            style:
                                                TextStyle(color: Colors.white),
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
                                  labelText: "Monnaie rendue (DT)",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Text("Nombre de tickets à imprimer:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(width: 10),
                                  Container(
                                    width: 40, // réduit la largeur
                                    height: 35,
                                    child: TextField(
                                      controller: TextEditingController(
                                          text: numberOfTickets.toString()),
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                          fontSize:
                                              14), // réduit la taille du texte
                                      decoration: InputDecoration(
                                        isDense:
                                            true, // rend le champ plus compact
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical:
                                                6), // réduit les marges internes
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          numberOfTickets =
                                              int.tryParse(value) ?? 1;
                                          if (numberOfTickets < 1)
                                            numberOfTickets = 1;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ]),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Fermer",
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (!validateDiscounts()) return;
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
                      isPercentageDiscount,
                      selectedClient,
                      numberOfTickets, // Ajout du paramètre
                    );
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
      double productMaxDiscount = products[i].remiseValeurMax;
      int quantity = quantities[i];
      maxDiscountValue += quantity * productMaxDiscount;
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
    Client? selectedClient,
    int numberOfTickets, // Nouveau paramètre
  ) async {
    if (!isPercentageDiscount &&
        globalDiscount >
            _calculateMaxGlobalDiscountValue(
                selectedProducts, quantityProducts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "La remise globale ne peut pas dépasser ${_calculateMaxGlobalDiscountValue(selectedProducts, quantityProducts)} DT."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      return;
    }
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
      idClient: selectedClient?.id, // Ajout du client associé
    );

    print("Order to be saved: ${order.toMap()}");

    try {
      int orderId = await SqlDb().addOrder(order);
      // Associer la commande au client si un client est sélectionné
      if (selectedClient != null && orderId > 0) {
        await SqlDb().addOrderToClient(selectedClient.id!, orderId);
      }
      if (orderId > 0) {
        print("Order saved successfully with ID: $orderId");

        // Créer la commande complète avec son ID
        Order completeOrder = Order(
          idOrder: orderId,
          date: order.date,
          orderLines: order.orderLines,
          total: order.total,
          modePaiement: order.modePaiement,
          status: order.status,
          remainingAmount: order.remainingAmount,
          globalDiscount: order.globalDiscount,
          isPercentageDiscount: order.isPercentageDiscount,
          idClient: order.idClient,
        );

        // Générer les tickets PDF
        for (int i = 0; i < numberOfTickets; i++) {
          await Getorderlist.generateAndSavePDF(context, completeOrder);
        }

        // Afficher notification de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Commande #$orderId confirmée et ${numberOfTickets > 1 ? '$numberOfTickets tickets' : '1 ticket'} généré(s)"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

        // Vérification du stock
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
                    "Stock insuffisant pour ${selectedProducts[i].designation} (reste: ${selectedProducts[i].stock})"),
                backgroundColor: Colors.orange,
              ),
            );
            isValidOrder = false;
          }
        }

        if (isValidOrder) {
          // Mettre à jour les stocks
          for (int i = 0; i < selectedProducts.length; i++) {
            selectedProducts[i].stock -= quantityProducts[i];
            await SqlDb().updateProductStock(
                selectedProducts[i].code ?? '', selectedProducts[i].stock);
          }
        }

        // Vider les listes
        selectedProducts.clear();
        quantityProducts.clear();
        discounts.clear();
        typeDiscounts.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Échec de l'enregistrement de la commande"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("Error saving order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
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
