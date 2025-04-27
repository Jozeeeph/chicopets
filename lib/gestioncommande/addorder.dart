import 'dart:convert';
import 'dart:math';
import 'package:caissechicopets/controllers/fidelity_controller.dart';
import 'package:caissechicopets/models/fidelity_rules.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/views/client_views/client_management.dart';
import 'package:caissechicopets/gestioncommande/getorderlist.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class Addorder {
  static late final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Future<bool> processCardPayment(double amount, String currency) async {
    try {
      bool connected = await _connectToPaymentTerminal();
      if (!connected) {
        throw Exception("Impossible de se connecter au terminal de paiement");
      }

      // Envoyer la demande de paiement
      final transactionResult = await _sendPaymentRequest(amount, currency);

      // Vérifier si le paiement a été accepté
      if (transactionResult['status'] == 'approved') {
        return true;
      } else {
        throw Exception(transactionResult['message'] ?? "Paiement refusé");
      }
    } catch (e) {
      print("Erreur lors du paiement par carte: $e");
      rethrow;
    }
  }

  Future<bool> _connectToPaymentTerminal() async {
    // Implémentez la connexion au terminal
    return true; // Simuler une connexion réussie
  }

  Future<Map<String, dynamic>> _sendPaymentRequest(
      double amount, String currency) async {
    // Implémentez l'envoi de la demande de paiement
    await Future.delayed(
        Duration(seconds: 2)); // Simuler un délai de traitement

    // Simuler une réponse réussie
    return {
      'status': 'approved',
      'transaction_id': 'TRX-${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'currency': currency,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

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
    bool useLoyaltyPoints = false;
    int pointsToUse = 0;
    double pointsDiscount = 0.0;

    print("seee ${selectedProducts.length}");

    if (selectedProducts.isEmpty) {
      Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
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
    TextEditingController amountGivenTPEController = TextEditingController();
    TextEditingController amountGivenChequeController = TextEditingController();

    TextEditingController changeReturnedController = TextEditingController();

    String? checkNumber; // For cheque number
    String? cardTransactionId; // For TPE transaction ID
    DateTime? checkDate; // For cheque date
    String? bankName;

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
    double cashAmount = 0.0;
    double cardAmount = 0.0;
    double checkAmount = 0.0;

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
                  Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(
                          "La remise sur ${selectedProducts[i].designation} ne peut pas dépasser ${remiseMax}%."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return false;
                } else if (!isPercentage && discount > remiseValeurMax) {
                  Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
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
                  Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
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
                  Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
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
                                // Header
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

                                // Column Headers
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
                                        flex: 3,
                                        child: Text(
                                          "Article",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
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
                                        flex: 2,
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
                                    int index =
                                        selectedProducts.indexOf(product);

                                    // Get default or first variant
                                    Variant? selectedVariant =
                                        product.hasVariants &&
                                                product.variants.isNotEmpty
                                            ? product.variants.firstWhere(
                                                (v) => v.defaultVariant,
                                                orElse: () =>
                                                    product.variants.first,
                                              )
                                            : null;

                                    double basePrice =
                                        selectedVariant?.finalPrice ??
                                            product.prixTTC;
                                    double discountedPrice =
                                        typeDiscounts[index]
                                            ? basePrice *
                                                (1 - discounts[index] / 100)
                                            : basePrice - discounts[index];

                                    String productName = product.designation;
                                    if (selectedVariant != null) {
                                      productName +=
                                          " (${selectedVariant.combinationName.isNotEmpty ? selectedVariant.combinationName : selectedVariant.code})";
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                                "${quantityProducts[index]}X"),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(productName,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              "${discountedPrice.toStringAsFixed(2)} DT",
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              "${(discountedPrice * quantityProducts[index]).toStringAsFixed(2)} DT",
                                              textAlign: TextAlign.end,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList()
                                else
                                  Center(
                                      child:
                                          Text("Aucun produit sélectionné.")),

                                // Client Section
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

                                if (pointsDiscount > 0)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Réduction points:",
                                          style:
                                              TextStyle(color: Colors.green)),
                                      Text(
                                          "-${pointsDiscount.toStringAsFixed(2)} DT",
                                          style:
                                              TextStyle(color: Colors.green)),
                                    ],
                                  ),

                                if (globalDiscount > 0 ||
                                    discounts.any((d) => d > 0))
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Total avant remise:"),
                                      Text(
                                          "${totalBeforeDiscount.toStringAsFixed(2)} DT"),
                                    ],
                                  ),

                                if (globalDiscount > 0)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Remise:",
                                          style: TextStyle(color: Colors.red)),
                                      Text(
                                        isPercentageDiscount
                                            ? "-${globalDiscount.toStringAsFixed(2)}%"
                                            : "-${globalDiscount.toStringAsFixed(2)} DT",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Total:",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text("${total.toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),

                                Divider(thickness: 1, color: Colors.black),
                                Text("Détails de paiement:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),

                                if (selectedPaymentMethod == "Espèce") ...[
                                  Text("Mode: Espèces"),
                                  Text(
                                      "Montant donné: ${cashAmount.toStringAsFixed(2)} DT"),
                                  if (changeReturned > 0)
                                    Text(
                                        "Monnaie rendue: ${changeReturned.toStringAsFixed(2)} DT"),
                                ],

                                if (selectedPaymentMethod == "TPE") ...[
                                  Text("Mode: Carte"),
                                  Text(
                                      "Montant: ${cardAmount.toStringAsFixed(2)} DT"),
                                  if (cardTransactionId != null)
                                    Text("Transaction: $cardTransactionId"),
                                ],

                                if (selectedPaymentMethod == "Chèque") ...[
                                  Text("Mode: Chèque"),
                                  Text(
                                      "Montant: ${checkAmount.toStringAsFixed(2)} DT"),
                                  if (checkNumber != null)
                                    Text("N°: $checkNumber"),
                                  if (bankName != null)
                                    Text("Banque: $bankName"),
                                  if (checkDate != null)
                                    Text(
                                        "Date: ${DateFormat('dd/MM/yyyy').format(checkDate!)}"),
                                ],

                                if (selectedPaymentMethod == "Mixte") ...[
                                  Text("Mode: Paiement mixte"),
                                  if (cashAmount > 0)
                                    Text(
                                        "- Espèces: ${cashAmount.toStringAsFixed(2)} DT"),
                                  if (cardAmount > 0) ...[
                                    Text(
                                        "- Carte: ${cardAmount.toStringAsFixed(2)} DT"),
                                    if (cardTransactionId != null)
                                      Text("  Transaction: $cardTransactionId"),
                                  ],
                                  if (checkAmount > 0) ...[
                                    Text(
                                        "- Chèque: ${checkAmount.toStringAsFixed(2)} DT"),
                                    if (checkNumber != null)
                                      Text("  N°: $checkNumber"),
                                    if (bankName != null)
                                      Text("  Banque: $bankName"),
                                    if (checkDate != null)
                                      Text(
                                          "  Date: ${DateFormat('dd/MM/yyyy').format(checkDate!)}"),
                                  ],
                                ],

                                Divider(thickness: 1, color: Colors.black),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Total payé:",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      "${(cashAmount + cardAmount + checkAmount).toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),

                                if ((cashAmount + cardAmount + checkAmount) <
                                    total)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Reste à payer:",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red),
                                      ),
                                      Text(
                                        "${(total - (cashAmount + cardAmount + checkAmount)).toStringAsFixed(2)} DT",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red),
                                      ),
                                    ],
                                  ),
                              ],
                            )),
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
                          SizedBox(height: 16),

                          // --- AJOUTEZ ICI LE WIDGET DE POINTS DE FIDÉLITÉ ---
                          if (selectedClient != null)
                            FutureBuilder<FidelityRules>(
                              future: SqlDb().db.then((db) =>
                                  FidelityController().getFidelityRules(db)),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return SizedBox();
                                final rules = snapshot.data!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: useLoyaltyPoints,
                                          onChanged: (value) async {
                                            if (value == true) {
                                              final db = await SqlDb().db;
                                              final canUse =
                                                  await FidelityController()
                                                      .canUsePoints(
                                                selectedClient!,
                                                total,
                                                db,
                                              );

                                              if (!canUse) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Points insuffisants ou expirés (min: ${rules.minPointsToUse})',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                            }
                                            setState(() => useLoyaltyPoints =
                                                value ?? false);
                                          },
                                        ),
                                        Text('Utiliser les points de fidélité'),
                                        IconButton(
                                          icon: Icon(Icons.info_outline),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title:
                                                    Text('Points de fidélité'),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        'Solde: ${selectedClient!.loyaltyPoints} points'),
                                                    Text(
                                                        '1 point = ${rules.dinarPerPoint} DT'),
                                                    Text(
                                                        '${rules.pointsPerDinar} point(s) par dinar dépensé'),
                                                    Text(
                                                        'Minimum ${rules.minPointsToUse} points pour utiliser'),
                                                    if (rules
                                                            .pointsValidityMonths >
                                                        0)
                                                      Text(
                                                          'Validité: ${rules.pointsValidityMonths} mois'),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    if (useLoyaltyPoints) ...[
                                      Slider(
                                        min: 0,
                                        max: selectedClient!.loyaltyPoints
                                            .toDouble(),
                                        divisions:
                                            selectedClient!.loyaltyPoints,
                                        value: pointsToUse.toDouble(),
                                        onChanged: (value) {
                                          setState(() {
                                            pointsToUse = value.toInt();
                                            pointsDiscount = pointsToUse *
                                                rules.dinarPerPoint;

                                            // Ne pas dépasser le pourcentage maximum
                                            final maxDiscount =
                                                totalBeforeDiscount *
                                                    (rules.maxPercentageUse /
                                                        100);
                                            if (pointsDiscount > maxDiscount) {
                                              pointsDiscount = maxDiscount;
                                              pointsToUse = (pointsDiscount /
                                                      rules.dinarPerPoint)
                                                  .round();
                                            }

                                            // Mettre à jour le total affiché
                                            total = calculateTotal(
                                                  selectedProducts,
                                                  quantityProducts,
                                                  discounts,
                                                  typeDiscounts,
                                                  isPercentageDiscount
                                                      ? globalDiscount
                                                      : globalDiscountValue,
                                                  isPercentageDiscount,
                                                ) -
                                                pointsDiscount;

                                            if (total < 0) total = 0;
                                          });
                                        },
                                      ),
                                      Text(
                                          'Utiliser $pointsToUse points (${pointsDiscount.toStringAsFixed(2)} DT)'),
                                      Text(
                                          'Nouveau solde: ${selectedClient!.loyaltyPoints - pointsToUse} points'),
                                    ],
                                  ],
                                );
                              },
                            ),
                          // ---------------------------------------------------

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

                          SizedBox(height: 16),

                          // Montant donné et rendu
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
                                  Radio<String>(
                                    value: "Mixte",
                                    groupValue: selectedPaymentMethod,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedPaymentMethod = value!;
                                      });
                                    },
                                  ),
                                  Text("Mixte"),
                                ],
                              ),

                              // Ajoutez ces champs conditionnels
                              if (selectedPaymentMethod == "Espèce")
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
                                                "Veuillez entrer un nombre positif."),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        amountGivenController.text = '';
                                        return;
                                      }
                                      amountGivenController.text = cleanedValue;
                                      amountGivenController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset: cleanedValue.length),
                                      );
                                      cashAmount =
                                          double.tryParse(cleanedValue) ?? 0.0;
                                      changeReturned = cashAmount - total;
                                      changeReturnedController.text =
                                          changeReturned.toStringAsFixed(2);
                                    });
                                  },
                                ),
                              if (selectedPaymentMethod == "TPE")
                                Column(
                                  children: [
                                    TextField(
                                      controller:
                                          amountGivenTPEController, // Vide au début
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: "Montant par carte (DT)",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          String cleanedValue =
                                              cleanInput(value);
                                          if (cleanedValue == 'NEGATIVE') {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Veuillez entrer un nombre positif.")),
                                            );
                                            return;
                                          }
                                          cardAmount =
                                              double.tryParse(cleanedValue) ??
                                                  0.0;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      onChanged: (value) => cardTransactionId =
                                          value, // Add this line
                                      decoration: InputDecoration(
                                        labelText: "ID de transaction TPE",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),

                              if (selectedPaymentMethod == "Chèque")
                                Column(
                                  children: [
                                    TextField(
                                      controller: amountGivenChequeController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: "Montant par chèque (DT)",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          String cleanedValue =
                                              cleanInput(value);
                                          if (cleanedValue == 'NEGATIVE') {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Veuillez entrer un nombre positif.")),
                                            );
                                            return;
                                          }
                                          checkAmount =
                                              double.tryParse(cleanedValue) ??
                                                  0.0;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      onChanged: (value) =>
                                          checkNumber = value, // Add this line
                                      decoration: InputDecoration(
                                        labelText: "Numéro du chèque",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      onChanged: (value) =>
                                          bankName = value, // Add this line
                                      decoration: InputDecoration(
                                        labelText: "Banque émettrice",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    InkWell(
                                      onTap: () async {
                                        final selectedDate =
                                            await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(Duration(days: 365)),
                                        );
                                        if (selectedDate != null) {
                                          setState(() {
                                            checkDate =
                                                selectedDate; // Add this line
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: "Date du chèque",
                                          border: OutlineInputBorder(),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(checkDate != null
                                                ? "${checkDate!.day}/${checkDate!.month}/${checkDate!.year}"
                                                : "Sélectionner une date"),
                                            Icon(Icons.calendar_today),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              if (selectedPaymentMethod == "Mixte")
                                Column(
                                  children: [
                                    // Section Espèces
                                    Text("Espèces:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextField(
                                      controller: amountGivenController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: "Montant en espèces (DT)",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          String cleanedValue =
                                              cleanInput(value);
                                          if (cleanedValue == 'NEGATIVE') {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Veuillez entrer un nombre positif.")),
                                            );
                                            return;
                                          }
                                          cashAmount =
                                              double.tryParse(cleanedValue) ??
                                                  0.0;
                                        });
                                      },
                                    ),

                                    // Section TPE
                                    SizedBox(height: 10),
                                    Text("TPE:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextField(
                                      controller: amountGivenTPEController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: "Montant par carte (DT)",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          String cleanedValue =
                                              cleanInput(value);
                                          if (cleanedValue == 'NEGATIVE') {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Veuillez entrer un nombre positif.")),
                                            );
                                            return;
                                          }
                                          cardAmount =
                                              double.tryParse(cleanedValue) ??
                                                  0.0;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      controller: TextEditingController(
                                          text: cardTransactionId ?? ''),
                                      decoration: InputDecoration(
                                        labelText: "ID de transaction TPE",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          cardTransactionId = value;
                                        });
                                      },
                                    ),

                                    // Section Chèque
                                    SizedBox(height: 10),
                                    Text("Chèque:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextField(
                                      controller: amountGivenChequeController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: "Montant par chèque (DT)",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          String cleanedValue =
                                              cleanInput(value);
                                          if (cleanedValue == 'NEGATIVE') {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Veuillez entrer un nombre positif.")),
                                            );
                                            return;
                                          }
                                          checkAmount =
                                              double.tryParse(cleanedValue) ??
                                                  0.0;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      controller: TextEditingController(
                                          text: checkNumber ?? ''),
                                      decoration: InputDecoration(
                                        labelText: "Numéro du chèque",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          checkNumber = value;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      controller: TextEditingController(
                                          text: bankName ?? ''),
                                      decoration: InputDecoration(
                                        labelText: "Banque émettrice",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          bankName = value;
                                        });
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    InkWell(
                                      onTap: () async {
                                        final selectedDate =
                                            await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(Duration(days: 365)),
                                        );
                                        if (selectedDate != null) {
                                          setState(() {
                                            checkDate = selectedDate;
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: "Date du chèque",
                                          border: OutlineInputBorder(),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(checkDate != null
                                                ? "${checkDate!.day}/${checkDate!.month}/${checkDate!.year}"
                                                : "Sélectionner une date"),
                                            Icon(Icons.calendar_today),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Total saisi
                                    SizedBox(height: 10),
                                    Text(
                                      "Total saisi: ${(cashAmount + cardAmount + checkAmount).toStringAsFixed(2)} DT / ${total.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),

                              SizedBox(height: 10),
                              if (selectedPaymentMethod == "Espèce")
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
                                          if (numberOfTickets < 1) {
                                            numberOfTickets = 1;
                                          }
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
                  onPressed: () async {
                    if (!validateDiscounts()) return;
                    Navigator.of(context).pop();
                    await _confirmPlaceOrder(
                        selectedProducts,
                        quantityProducts,
                        discounts, // Changed from amountGiven to discounts
                        typeDiscounts,
                        isPercentageDiscount
                            ? globalDiscount
                            : globalDiscountValue,
                        isPercentageDiscount,
                        selectedClient,
                        numberOfTickets,
                        selectedPaymentMethod,
                        cashAmount,
                        cardAmount,
                        checkAmount,
                        checkNumber,
                        cardTransactionId,
                        checkDate,
                        bankName,
                        useLoyaltyPoints,
                        pointsToUse,
                        pointsDiscount);
                  },
                  child: Text(
                    "Confirmer",
                    style: TextStyle(color: Color(0xFF009688)),
                  ),
                )
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

  static Future<void> _confirmPlaceOrder(
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
    double globalDiscount,
    bool isPercentageDiscount,
    Client? selectedClient,
    int numberOfTickets,
    String selectedPaymentMethod,
    double cashAmount,
    double cardAmount,
    double checkAmount,
    String? checkNumber,
    String? cardTransactionId,
    DateTime? checkDate,
    String? bankName,
    bool useLoyaltyPoints,
    int pointsToUse,
    double pointsDiscount,
  ) async {
    if (!isPercentageDiscount &&
        globalDiscount >
            _calculateMaxGlobalDiscountValue(
                selectedProducts, quantityProducts)) {
      Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
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
      Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
              "La remise globale ne peut pas dépasser ${_calculateMaxGlobalDiscountPercentage(selectedProducts, quantityProducts)}%."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedProducts.isEmpty) {
      Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
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

    if (useLoyaltyPoints && pointsToUse > 0) {
      total = max(0, total - pointsDiscount);
    }

    double totalAmountPaid = 0.0;
    String status;
    double remainingAmount = max(0, total - totalAmountPaid - pointsDiscount);
    switch (selectedPaymentMethod) {
      case "Espèce":
        totalAmountPaid = cashAmount;
        status = (cashAmount + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
            ? "payée"
            : "semi-payée";
        remainingAmount =
            (cashAmount + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
                ? 0.0
                : total - cashAmount - (useLoyaltyPoints ? pointsDiscount : 0);
        break;
      case "TPE":
        totalAmountPaid = cardAmount;
        status = (cardAmount + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
            ? "payée"
            : "semi-payée";
        remainingAmount =
            (cardAmount + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
                ? 0.0
                : total - cardAmount - (useLoyaltyPoints ? pointsDiscount : 0);
        break;
      case "Chèque":
        totalAmountPaid = checkAmount;
        status =
            (checkAmount + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
                ? "payée"
                : "semi-payée";
        remainingAmount =
            (checkAmount + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
                ? 0.0
                : total - checkAmount - (useLoyaltyPoints ? pointsDiscount : 0);
        break;
      case "Mixte":
        totalAmountPaid = cashAmount + cardAmount + checkAmount;
        status =
            (totalAmountPaid + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
                ? "payée"
                : "semi-payée";
        remainingAmount =
            (totalAmountPaid + (useLoyaltyPoints ? pointsDiscount : 0)) >= total
                ? 0.0
                : total -
                    totalAmountPaid -
                    (useLoyaltyPoints ? pointsDiscount : 0);
        break;
      default:
        status = "non payée";
        remainingAmount = total;
    }

    switch (selectedPaymentMethod) {
      case "Espèce":
        totalAmountPaid = cashAmount;
        if (cashAmount >= total) {
          status = "payée";
          remainingAmount = 0.0;
        } else {
          status = "semi-payée";
          remainingAmount = total - cashAmount;
        }
        break;
      case "TPE":
        totalAmountPaid = cardAmount;
        status = cardAmount >= total ? "payée" : "semi-payée";
        remainingAmount = cardAmount >= total ? 0.0 : total - cardAmount;
        break;
      case "Chèque":
        totalAmountPaid = checkAmount;
        status = checkAmount >= total ? "payée" : "semi-payée";
        remainingAmount = checkAmount >= total ? 0.0 : total - checkAmount;
        break;
      case "Mixte":
        totalAmountPaid = cashAmount + cardAmount + checkAmount;
        status = totalAmountPaid >= total ? "payée" : "semi-payée";
        remainingAmount =
            totalAmountPaid >= total ? 0.0 : total - totalAmountPaid;
        break;
      default:
        status = "non payée";
        remainingAmount = total;
    }

    switch (selectedPaymentMethod) {
      case "Espèce":
        totalAmountPaid = cashAmount;
        status = cashAmount >= total ? "payée" : "semi-payée";
        remainingAmount = cashAmount >= total ? 0.0 : total - cashAmount;
        break;
      case "TPE":
        totalAmountPaid = cardAmount;
        status = cardAmount >= total ? "payée" : "semi-payée";
        remainingAmount = cardAmount >= total ? 0.0 : total - cardAmount;
        break;
      case "Chèque":
        totalAmountPaid = checkAmount;
        status = checkAmount >= total ? "payée" : "semi-payée";
        remainingAmount = checkAmount >= total ? 0.0 : total - checkAmount;
        break;
      case "Mixte":
        totalAmountPaid = cashAmount + cardAmount + checkAmount;
        status = (totalAmountPaid >= total) ? "payée" : "semi-payée";
        remainingAmount =
            (totalAmountPaid >= total) ? 0.0 : total - totalAmountPaid;
        break;
      default:
        status = "non payée";
        remainingAmount = total;
    }

    if ((selectedPaymentMethod == "TPE" && cardAmount <= 0) ||
        (selectedPaymentMethod == "Chèque" && checkAmount <= 0) ||
        (selectedPaymentMethod == "Espèce" && cashAmount <= 0) ||
        (selectedPaymentMethod == "Mixte" &&
            (cashAmount + cardAmount + checkAmount) <= 0)) {
      Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Veuillez entrer un montant valide pour le paiement."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print("Total avant remise: $totalBeforeDiscount");
    print("Total après remise: $total");
    print("Statut de la commande: $status");
    print("Montant restant: $remainingAmount");

    List<OrderLine> orderLines = selectedProducts.map((product) {
      int productIndex = selectedProducts.indexOf(product);
      return OrderLine(
        idOrder: 0,
        productCode: product.code,
        productId: product.id,
        quantity: quantityProducts[productIndex],
        prixUnitaire: product.prixTTC,
        discount: discounts[productIndex],
        isPercentage: typeDiscounts[productIndex],
      );
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    final user = userJson != null ? User.fromMap(jsonDecode(userJson)) : null;
    Order order = Order(
      date: DateTime.now().toIso8601String(),
      orderLines: orderLines,
      total: total,
      modePaiement: selectedPaymentMethod,
      status: status,
      remainingAmount: remainingAmount,
      globalDiscount: globalDiscount,
      isPercentageDiscount: isPercentageDiscount,
      userId: user?.id,
      idClient: selectedClient?.id,
      cashAmount:
          selectedPaymentMethod == "Espèce" || selectedPaymentMethod == "Mixte"
              ? cashAmount
              : null,
      cardAmount:
          selectedPaymentMethod == "TPE" || selectedPaymentMethod == "Mixte"
              ? cardAmount
              : null,
      checkAmount:
          selectedPaymentMethod == "Chèque" || selectedPaymentMethod == "Mixte"
              ? checkAmount
              : null,
      checkNumber:
          selectedPaymentMethod == "Chèque" || selectedPaymentMethod == "Mixte"
              ? checkNumber
              : null,
      cardTransactionId:
          selectedPaymentMethod == "TPE" || selectedPaymentMethod == "Mixte"
              ? cardTransactionId
              : null,
      checkDate:
          selectedPaymentMethod == "Chèque" || selectedPaymentMethod == "Mixte"
              ? checkDate
              : null,
      bankName:
          selectedPaymentMethod == "Chèque" || selectedPaymentMethod == "Mixte"
              ? bankName
              : null,
    );

    print("Order to be saved: ${order.toMap()}");

    try {
      double totalBeforePoints = calculateTotal(
        selectedProducts,
        quantityProducts,
        discounts,
        typeDiscounts,
        globalDiscount,
        isPercentageDiscount,
      );

      // Apply points discount if used
      if (useLoyaltyPoints && pointsToUse > 0) {
        totalBeforePoints -= pointsDiscount;
        if (totalBeforePoints < 0) totalBeforePoints = 0;
      }

      // Create order lines with variant information
      List<OrderLine> orderLines = selectedProducts.map((product) {
        int productIndex = selectedProducts.indexOf(product);
        Variant? variant = product.hasVariants && product.variants.isNotEmpty
            ? product.variants.first
            : null;

        return OrderLine(
          idOrder: 0,
          productCode: product.code,
          productId: product.id,
          variantId: variant?.id,
          variantCode: variant?.code,
          variantName: variant?.combinationName,
          quantity: quantityProducts[productIndex],
          prixUnitaire: variant?.finalPrice ?? product.prixTTC,
          discount: discounts[productIndex],
          isPercentage: typeDiscounts[productIndex],
        );
      }).toList();

      Order order = Order(
        date: DateTime.now().toIso8601String(),
        orderLines: orderLines,
        total: totalBeforePoints, // Use the total after points discount
        modePaiement: selectedPaymentMethod,
        status: status,
        remainingAmount: remainingAmount,
        globalDiscount: globalDiscount,
        isPercentageDiscount: isPercentageDiscount,
        idClient: selectedClient?.id,
        cashAmount: selectedPaymentMethod == "Espèce" ||
                selectedPaymentMethod == "Mixte"
            ? cashAmount
            : null,
        cardAmount:
            selectedPaymentMethod == "TPE" || selectedPaymentMethod == "Mixte"
                ? cardAmount
                : null,
        checkAmount: selectedPaymentMethod == "Chèque" ||
                selectedPaymentMethod == "Mixte"
            ? checkAmount
            : null,
        checkNumber: selectedPaymentMethod == "Chèque" ||
                selectedPaymentMethod == "Mixte"
            ? checkNumber
            : null,
        cardTransactionId:
            selectedPaymentMethod == "TPE" || selectedPaymentMethod == "Mixte"
                ? cardTransactionId
                : null,
        checkDate: selectedPaymentMethod == "Chèque" ||
                selectedPaymentMethod == "Mixte"
            ? checkDate
            : null,
        bankName: selectedPaymentMethod == "Chèque" ||
                selectedPaymentMethod == "Mixte"
            ? bankName
            : null,
        pointsUsed: useLoyaltyPoints ? pointsToUse : 0,
        pointsDiscount: useLoyaltyPoints ? pointsDiscount : 0,
      );

      int orderId = await SqlDb().addOrder(order);

      if (selectedClient != null && remainingAmount > 0) {
        try {
          final db = await SqlDb().db;

          // Calculate new debt
          double newDebt = selectedClient!.debt + remainingAmount;

          // Update client debt in database
          await db.update(
            'clients',
            {'debt': newDebt},
            where: 'id = ?',
            whereArgs: [selectedClient!.id],
          );

          // Update the selectedClient object locally
          selectedClient = selectedClient!.copyWith(
            debt: newDebt,
            lastPurchaseDate: DateTime.now(),
          );

          print("La dette ajoutée au client: ${selectedClient.debt} DT");
        } catch (e) {
          print("Error updating client debt: $e");
          Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text("Erreur lors de la mise à jour de la dette client"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      if (selectedClient != null && orderId > 0) {
        final db = await SqlDb().db;
        final fidelityController = FidelityController();

        // 1. Apply points discount if used
        if (useLoyaltyPoints && pointsToUse > 0) {
          await fidelityController.applyPointsToOrder(
              order, selectedClient, pointsToUse, db);
        }

        // 2. Add earned points (even if we used points)
        await fidelityController.addPointsFromOrder(order, db);
      }

      if (orderId > 0) {
        print("Order saved successfully with ID: $orderId");

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

        // Generate PDF tickets
        for (int i = 0; i < numberOfTickets; i++) {
          await Getorderlist.generateAndSavePDF(completeOrder);
        }

        // Show success notification
        Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
                "Commande #$orderId confirmée et ${numberOfTickets > 1 ? '$numberOfTickets tickets' : '1 ticket'} généré(s)"),
            backgroundColor: Colors.green,
          ),
        );

        // Stock validation and update
        bool isValidOrder = true;
        for (int i = 0; i < selectedProducts.length; i++) {
          final product = selectedProducts[i];
          final quantity = quantityProducts[i];

          if (product.hasVariants && product.variants.isNotEmpty) {
            // Handle variant stock
            final variant = product.variants.first;
            if (variant.stock == 0) {
              Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                      "${product.designation} (${variant.combinationName}) est en rupture de stock !"),
                  backgroundColor: Colors.red,
                ),
              );
              isValidOrder = false;
            } else if (variant.stock - quantity < 0) {
              Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                      "Stock insuffisant pour ${product.designation} (${variant.combinationName}) (reste: ${variant.stock})"),
                  backgroundColor: Colors.orange,
                ),
              );
              isValidOrder = false;
            }
          } else {
            // Handle regular product stock
            if (product.stock == 0) {
              Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content:
                      Text("${product.designation} est en rupture de stock !"),
                  backgroundColor: Colors.red,
                ),
              );
              isValidOrder = false;
            } else if (product.stock - quantity < 0) {
              Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                      "Stock insuffisant pour ${product.designation} (reste: ${product.stock})"),
                  backgroundColor: Colors.orange,
                ),
              );
              isValidOrder = false;
            }
          }
        }

        if (isValidOrder) {
          // Update stocks
          for (int i = 0; i < selectedProducts.length; i++) {
            final product = selectedProducts[i];
            final quantity = quantityProducts[i];

            final newStock = product.stock - quantity;

            if (product.hasVariants && product.variants.isNotEmpty) {
              // Update variant stock
              final variant = product.variants.first;
              final newStockV = variant.stock - quantity;

              await SqlDb().updateVariantStock(variant.id!, newStockV);
              print("new stock variant $newStockV");

              // Also update the product's total stock if needed
              await SqlDb().updateProductStock(product.id!, newStock);
            } else {
              // Update regular product stock
              await SqlDb().updateProductStock(product.id!, newStock);
            }
          }
        }

        // Clear the order
        selectedProducts.clear();
        quantityProducts.clear();
        discounts.clear();
        typeDiscounts.clear();
      } else {
        Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("Échec de l'enregistrement de la commande"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error saving order: $e");
      Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
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
      final product = selectedProducts[i];
      final quantity = quantityProducts[i];
      final discount = discounts[i];
      final isPercentage = typeDiscounts[i];

      // Get base price (variant price if exists)
      double basePrice = product.hasVariants && product.variants.isNotEmpty
          ? product.variants
              .firstWhere(
                (v) => v.defaultVariant,
                orElse: () => product.variants.first,
              )
              .finalPrice
          : product.prixTTC;

      // Calculate product total with individual discount
      double productTotal = basePrice * quantity;

      if (isPercentage) {
        productTotal *= (1 - discount / 100);
      } else {
        productTotal -= discount;
      }

      // Ensure price doesn't go negative
      if (productTotal < 0) productTotal = 0.0;

      total += productTotal;
    }

    // Apply global discount
    if (isPercentageDiscount) {
      total *= (1 - globalDiscount / 100);
    } else {
      total -= globalDiscount;
    }

    // Ensure final total doesn't go negative
    return total < 0 ? 0.0 : total;
  }

  static double calculateTotalBeforeDiscount(
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
  ) {
    double total = 0.0;

    for (int i = 0; i < selectedProducts.length; i++) {
      final product = selectedProducts[i];
      final quantity = quantityProducts[i];

      // Determine the base price (variant price if exists, otherwise product price)
      double basePrice;

      if (product.hasVariants && product.variants.isNotEmpty) {
        // Try to find selected variant first, then default variant, then first variant
        final selectedVariant = product.variants.firstWhere(
          (v) => v.defaultVariant,
          orElse: () => product.variants.first,
        );
        basePrice = selectedVariant.finalPrice;
      } else {
        basePrice = product.prixTTC;
      }

      // Add to total without applying discounts (this is BEFORE discount calculation)
      total += basePrice * quantity;
    }

    return total;
  }
}
