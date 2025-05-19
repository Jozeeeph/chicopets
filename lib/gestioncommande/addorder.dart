import 'dart:convert';
import 'dart:math';
import 'package:caissechicopets/controllers/fidelity_controller.dart';
import 'package:caissechicopets/models/fidelity_rules.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/paymentMode.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:caissechicopets/models/voucher.dart';
import 'package:caissechicopets/services/stock_movement_service.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/views/client_views/client_management.dart';
import 'package:caissechicopets/gestioncommande/getorderlist.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caissechicopets/models/stock_movement.dart';

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

    // Récupérer les modes de paiement activés
    List<PaymentMethod> paymentMethods =
        await SqlDb().getPaymentMethods(activeOnly: true);
    String? selectedPaymentMethod =
        paymentMethods.isNotEmpty ? paymentMethods.first.name : null;

    // Initialize selectedVariants with default variants for variant-based products
    List<Variant?> selectedVariants =
        List.generate(selectedProducts.length, (index) {
      Product product = selectedProducts[index];
      if (product.hasVariants && product.variants.isNotEmpty) {
        return product.variants.firstWhere(
          (v) => v.defaultVariant,
          orElse: () => product.variants.first,
        );
      }
      return null;
    });

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
      input = input.replaceAll(RegExp(r'[^0-9.]'), '');
      List<String> parts = input.split('.');
      if (parts.length > 2) {
        input = '${parts[0]}.${parts.sublist(1).join('')}';
      }
      if (input.startsWith('.')) {
        input = '0$input';
      }
      double? value = double.tryParse(input);
      if (value == null) return '';
      if (value < 0) return 'NEGATIVE';
      return input;
    }

    double amountGiven = 0.0;
    double changeReturned = 0.0;
    TextEditingController amountGivenController = TextEditingController();
    TextEditingController amountGivenTPEController = TextEditingController();
    TextEditingController amountGivenChequeController = TextEditingController();
    TextEditingController changeReturnedController = TextEditingController();

    double ticketRestaurantAmount = 0.0;
    int numberOfTicketsRestaurant = 1;
    double ticketValue = 0.0;
    double ticketTax = 0.0;
    double ticketCommission = 0.0;
    TextEditingController ticketValueController = TextEditingController();
    TextEditingController ticketTaxController = TextEditingController();
    TextEditingController ticketCommissionController = TextEditingController();

    // Ticket cadeau
    String giftTicketNumber = '';
    String giftTicketIssuer = '';
    double giftTicketAmount = 0.0;
    TextEditingController giftTicketAmountController = TextEditingController();

// Traite
    String traiteNumber = '';
    String traiteBank = '';
    String traiteBeneficiary = '';
    DateTime? traiteDate;
    double traiteAmount = 0.0;
    TextEditingController traiteAmountController = TextEditingController();

// Virement
    String virementReference = '';
    String virementBank = '';
    String virementSender = '';
    DateTime? virementDate;
    double virementAmount = 0.0;
    TextEditingController virementAmountController = TextEditingController();

    TextEditingController clientPhoneController = TextEditingController();
    List<Voucher> clientVouchers = [];
    Voucher? selectedVoucher;
    double voucherAmount = 0.0;
    bool showVoucherDropdown = false;

    String? checkNumber;
    String? cardTransactionId;
    DateTime? checkDate;
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
    double cashAmount = 0.0;
    double cardAmount = 0.0;
    double checkAmount = 0.0;

    TextEditingController globalDiscountController =
        TextEditingController(text: globalDiscount.toString());
    TextEditingController globalDiscountValueController =
        TextEditingController();

    double ticketTaxPercentage = 0.0;
    bool autoCalculateCommission = false;
    bool autoCalculateTax = false;
    double commissionRate = 0.1;
    double taxRate = 1.0;

    void calculateTicketTotal(void Function(void Function()) setState) {
      setState(() {
        ticketRestaurantAmount = numberOfTicketsRestaurant *
            (ticketValue +
                (ticketValue * (ticketTaxPercentage / 100)) +
                ticketCommission);
      });
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            double maxGlobalDiscountPercentage =
                _calculateMaxGlobalDiscountPercentage(
                    selectedProducts, quantityProducts);
            double maxGlobalDiscountValue = _calculateMaxGlobalDiscountValue(
                selectedProducts, quantityProducts);

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
                  width: MediaQuery.of(context).size.width * 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column - Order ticket
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
                                          fontSize: 18),
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
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        "Article",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "Prix U",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "Montant",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
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
                                  Variant? selectedVariant =
                                      selectedVariants[index];

                                  // Get default variant if none selected
                                  if (selectedVariant == null &&
                                      product.hasVariants &&
                                      product.variants.isNotEmpty) {
                                    selectedVariant =
                                        product.variants.firstWhere(
                                      (v) => v.defaultVariant,
                                      orElse: () => product.variants.first,
                                    );
                                    selectedVariants[index] = selectedVariant;
                                  }

                                  double basePrice =
                                      selectedVariant?.finalPrice ??
                                          product.prixTTC;
                                  double discountedPrice = typeDiscounts[index]
                                      ? basePrice * (1 - discounts[index] / 100)
                                      : basePrice - discounts[index];

                                  String productName = product.designation;
                                  if (selectedVariant != null) {
                                    productName +=
                                        " (${selectedVariant.combinationName})";
                                  }

                                  return Column(
                                    children: [
                                      Row(
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
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  productName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (product.hasVariants &&
                                                    product.variants.isNotEmpty)
                                                  DropdownButton<Variant>(
                                                    value: selectedVariant,
                                                    hint:
                                                        Text("Select Variant"),
                                                    items: product.variants
                                                        .map((variant) {
                                                      return DropdownMenuItem<
                                                          Variant>(
                                                        value: variant,
                                                        child: Text(variant
                                                            .combinationName),
                                                      );
                                                    }).toList(),
                                                    onChanged:
                                                        (Variant? newVariant) {
                                                      setState(() {
                                                        selectedVariants[
                                                            index] = newVariant;
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
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
                                      Divider(height: 1, color: Colors.grey),
                                    ],
                                  );
                                }).toList()
                              else
                                Center(
                                    child: Text("Aucun produit sélectionné.")),

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
                                        fontWeight: FontWeight.bold),
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
                                        style: TextStyle(color: Colors.green)),
                                    Text(
                                        "-${pointsDiscount.toStringAsFixed(2)} DT",
                                        style: TextStyle(color: Colors.green)),
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
                                if (bankName != null) Text("Banque: $bankName"),
                                if (checkDate != null)
                                  Text(
                                      "Date: ${DateFormat('dd/MM/yyyy').format(checkDate!)}"),
                              ],

                              if (selectedPaymentMethod ==
                                  "Ticket Restaurant") ...[
                                Text("Mode: Ticket Restaurant"),
                                Text(
                                    "Nombre de tickets: $numberOfTicketsRestaurant"),
                                Text(
                                    "Valeur d'un ticket: ${ticketValue.toStringAsFixed(2)} DT"),
                                Text(
                                    "Taxe par ticket: ${ticketTax.toStringAsFixed(2)} DT"),
                                Text(
                                    "Commission par ticket: ${ticketCommission.toStringAsFixed(2)} DT"),
                                Text(
                                    "Montant total: ${ticketRestaurantAmount.toStringAsFixed(2)} DT",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],

                              if (selectedPaymentMethod == "Ticket cadeau") ...[
                                Text("Mode: Ticket cadeau"),
                                Text(
                                    "Montant: ${giftTicketAmount.toStringAsFixed(2)} DT"),
                                Text("N°: $giftTicketNumber"),
                                Text("Émetteur: $giftTicketIssuer"),
                              ],

                              if (selectedPaymentMethod == "Traite") ...[
                                Text("Mode: Traite"),
                                Text(
                                    "Montant: ${traiteAmount.toStringAsFixed(2)} DT"),
                                Text("N°: $traiteNumber"),
                                Text("Banque: $traiteBank"),
                                Text("Bénéficiaire: $traiteBeneficiary"),
                                if (traiteDate != null)
                                  Text(
                                      "Date d'échéance: ${DateFormat('dd/MM/yyyy').format(traiteDate!)}"),
                              ],

                              if (selectedPaymentMethod == "Virement") ...[
                                Text("Mode: Virement"),
                                Text(
                                    "Montant: ${virementAmount.toStringAsFixed(2)} DT"),
                                Text("Référence: $virementReference"),
                                Text("Banque: $virementBank"),
                                Text("Émetteur: $virementSender"),
                                if (virementDate != null)
                                  Text(
                                      "Date: ${DateFormat('dd/MM/yyyy').format(virementDate!)}"),
                              ],

                              if (selectedPaymentMethod == "Bon d'achat") ...[
                                Text("Mode: Bon d'achat"),
                                Text(
                                    "Montant: ${voucherAmount.toStringAsFixed(2)} DT"),
                                if (selectedVoucher != null)
                                  Text("N°: ${selectedVoucher?.id}"),
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
                                if ((ticketRestaurantAmount) > 0) ...[
                                  Text(
                                      "- Ticket Restaurant: ${ticketRestaurantAmount.toStringAsFixed(2)} DT"),
                                  Text("  Nombre: $numberOfTicketsRestaurant"),
                                ],
                                if ((giftTicketAmount) > 0) ...[
                                  Text(
                                      "- Ticket cadeau: ${giftTicketAmount.toStringAsFixed(2)} DT"),
                                  Text("  N°: $giftTicketNumber"),
                                ],
                                if ((traiteAmount) > 0) ...[
                                  Text(
                                      "- Traite: ${traiteAmount.toStringAsFixed(2)} DT"),
                                  Text("  N°: $traiteNumber"),
                                ],
                                if ((virementAmount) > 0) ...[
                                  Text(
                                      "- Virement: ${virementAmount.toStringAsFixed(2)} DT"),
                                  Text("  Référence: $virementReference"),
                                ],
                                if ((voucherAmount ) > 0) ...[
                                  Text(
                                      "- Bon d'achat: ${voucherAmount.toStringAsFixed(2)} DT"),
                                  if (selectedVoucher != null)
                                    Text("  N°: ${selectedVoucher?.id}"),
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
                          ),
                        ),
                      ),

                      SizedBox(width: 16),

                      // Right column - Payment options
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            // Client selection
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
                                              color: Colors.grey[600]),
                                        ),
                                        Text(
                                          selectedClient != null
                                              ? '${selectedClient!.name} ${selectedClient!.firstName}'
                                              : 'Non spécifié',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
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

                            // Loyalty points
                            if (selectedClient != null)
                              FutureBuilder<FidelityRules>(
                                future: SqlDb().db.then((db) =>
                                    FidelityController().getFidelityRules(db)),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return SizedBox();
                                  final rules = snapshot.data!;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                            db);

                                                if (!canUse) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Points insuffisants ou expirés (min: ${rules.minPointsToUse})'),
                                                    ),
                                                  );
                                                  return;
                                                }
                                              }
                                              setState(() => useLoyaltyPoints =
                                                  value ?? false);
                                            },
                                          ),
                                          Text(
                                              'Utiliser les points de fidélité'),
                                          IconButton(
                                            icon: Icon(Icons.info_outline),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: Text(
                                                      'Points de fidélité'),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
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
                                                          Navigator.pop(
                                                              context),
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

                                              final maxDiscount =
                                                  totalBeforeDiscount *
                                                      (rules.maxPercentageUse /
                                                          100);
                                              if (pointsDiscount >
                                                  maxDiscount) {
                                                pointsDiscount = maxDiscount;
                                                pointsToUse = (pointsDiscount /
                                                        rules.dinarPerPoint)
                                                    .round();
                                              }

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

                            SizedBox(height: 16),

                            // Global discount (if no product discounts)
                            if (!discounts.any((discount) => discount > 0))
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Remise Globale:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  Text("Type de Remise:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      Radio(
                                        value: true,
                                        groupValue: isPercentageDiscount,
                                        onChanged: (value) {
                                          setState(() {
                                            isPercentageDiscount =
                                                value as bool;
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
                                            isPercentageDiscount =
                                                value as bool;
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
                                              color: Colors.grey, fontSize: 14),
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
                                              color: Colors.grey, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                ],
                              ),

                            SizedBox(height: 16),

                            // Payment options
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Mode de Paiement:",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                if (paymentMethods.isEmpty)
                                  Text("Aucun mode de paiement configuré",
                                      style: TextStyle(color: Colors.red)),
                                Row(
                                  children: paymentMethods.map((method) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: method.name,
                                          groupValue: selectedPaymentMethod,
                                          onChanged: (value) {
                                            setState(() {
                                              selectedPaymentMethod = value;
                                            });
                                          },
                                        ),
                                        Text(method.name),
                                        SizedBox(
                                            width:
                                                8), // Espacement entre les options
                                      ],
                                    );
                                  }).toList(),
                                ),

                                // Espèce payment fields
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
                                        amountGivenController.text =
                                            cleanedValue;
                                        amountGivenController.selection =
                                            TextSelection.fromPosition(
                                                TextPosition(
                                                    offset:
                                                        cleanedValue.length));
                                        cashAmount =
                                            double.tryParse(cleanedValue) ??
                                                0.0;
                                        changeReturned = cashAmount - total;
                                        changeReturnedController.text =
                                            changeReturned.toStringAsFixed(2);
                                      });
                                    },
                                  ),

                                // TPE payment fields
                                if (selectedPaymentMethod == "TPE")
                                  Column(
                                    children: [
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
                                        onChanged: (value) =>
                                            cardTransactionId = value,
                                        decoration: InputDecoration(
                                          labelText: "ID de transaction TPE",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Chèque payment fields
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
                                            checkNumber = value,
                                        decoration: InputDecoration(
                                          labelText: "Numéro du chèque",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) => bankName = value,
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
                                    ],
                                  ),

                                // Ticket Restaurant payment fields
                                if (selectedPaymentMethod ==
                                    "Ticket Restaurant")
                                  Column(
                                    children: [
                                      // Number of tickets
                                      TextField(
                                        controller: TextEditingController(
                                            text: numberOfTicketsRestaurant
                                                .toString()),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Nombre de tickets",
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            numberOfTicketsRestaurant =
                                                int.tryParse(value) ?? 1;
                                            if (numberOfTicketsRestaurant < 1)
                                              numberOfTicketsRestaurant = 1;
                                            calculateTicketTotal(setState);
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),

                                      // Ticket value
                                      TextField(
                                        controller: ticketValueController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: InputDecoration(
                                          labelText: "Valeur d'un ticket (DT)",
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            ticketValue =
                                                double.tryParse(value) ?? 0.0;
                                            if (autoCalculateCommission) {
                                              ticketCommission = ticketValue *
                                                  (ticketTaxPercentage / 100) *
                                                  commissionRate;
                                            }
                                            if (autoCalculateTax &&
                                                ticketValue > 0) {
                                              ticketTaxPercentage =
                                                  (ticketCommission /
                                                          ticketValue) *
                                                      taxRate *
                                                      100;
                                            }
                                            calculateTicketTotal(setState);
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),

                                      // Tax percentage
                                      TextField(
                                        controller: TextEditingController(
                                            text:
                                                ticketTaxPercentage.toString()),
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: InputDecoration(
                                          labelText: "Taxe par ticket (%)",
                                          border: OutlineInputBorder(),
                                          suffixText: '%',
                                          hintText:
                                              "Peut être positif ou négatif",
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            ticketTaxPercentage =
                                                double.tryParse(value) ?? 0.0;
                                            if (autoCalculateCommission) {
                                              ticketCommission = ticketValue *
                                                  (ticketTaxPercentage / 100) *
                                                  commissionRate;
                                            }
                                            calculateTicketTotal(setState);
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),

                                      // Commission
                                      TextField(
                                        controller: TextEditingController(
                                            text: ticketCommission.toString()),
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: InputDecoration(
                                          labelText:
                                              "Commission par ticket (DT)",
                                          border: OutlineInputBorder(),
                                          suffixText: 'DT',
                                          hintText:
                                              "Peut être positif ou négatif",
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            ticketCommission =
                                                double.tryParse(value) ?? 0.0;
                                            if (autoCalculateTax &&
                                                ticketValue > 0) {
                                              ticketTaxPercentage =
                                                  (ticketCommission /
                                                          ticketValue) *
                                                      taxRate *
                                                      100;
                                            }
                                            calculateTicketTotal(setState);
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),

                                      // Auto-calculation toggles
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: autoCalculateCommission,
                                            onChanged: (value) {
                                              setState(() {
                                                autoCalculateCommission =
                                                    value ?? false;
                                                if (autoCalculateCommission) {
                                                  autoCalculateTax = false;
                                                  ticketCommission =
                                                      ticketValue *
                                                          (ticketTaxPercentage /
                                                              100) *
                                                          commissionRate;
                                                }
                                                calculateTicketTotal(setState);
                                              });
                                            },
                                          ),
                                          Text(
                                              "Calculer commission depuis taxe"),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: autoCalculateTax,
                                            onChanged: (value) {
                                              setState(() {
                                                autoCalculateTax =
                                                    value ?? false;
                                                if (autoCalculateTax) {
                                                  autoCalculateCommission =
                                                      false;
                                                  if (ticketValue > 0) {
                                                    ticketTaxPercentage =
                                                        (ticketCommission /
                                                                ticketValue) *
                                                            taxRate *
                                                            100;
                                                  }
                                                }
                                                calculateTicketTotal(setState);
                                              });
                                            },
                                          ),
                                          Text(
                                              "Calculer taxe depuis commission"),
                                        ],
                                      ),

                                      // Rate sliders
                                      if (autoCalculateCommission) ...[
                                        SizedBox(height: 10),
                                        Text(
                                            "Taux de commission: ${(commissionRate * 100).toStringAsFixed(1)}% du montant de la taxe"),
                                        Slider(
                                          min: 0,
                                          max: 1,
                                          divisions: 20,
                                          value: commissionRate,
                                          onChanged: (value) {
                                            setState(() {
                                              commissionRate = value;
                                              ticketCommission = ticketValue *
                                                  (ticketTaxPercentage / 100) *
                                                  commissionRate;
                                              calculateTicketTotal(setState);
                                            });
                                          },
                                        ),
                                      ],
                                      if (autoCalculateTax) ...[
                                        SizedBox(height: 10),
                                        Text(
                                            "Taux de taxe: ${taxRate.toStringAsFixed(1)}x la commission"),
                                        Slider(
                                          min: 0.1,
                                          max: 2,
                                          divisions: 19,
                                          value: taxRate,
                                          onChanged: (value) {
                                            setState(() {
                                              taxRate = value;
                                              if (ticketValue > 0) {
                                                ticketTaxPercentage =
                                                    (ticketCommission /
                                                            ticketValue) *
                                                        taxRate *
                                                        100;
                                              }
                                              calculateTicketTotal(setState);
                                            });
                                          },
                                        ),
                                      ],

                                      SizedBox(height: 20),

                                      // Detailed breakdown
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text("Détails:",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            SizedBox(height: 5),
                                            Text(
                                                "- Valeur ticket: ${ticketValue.toStringAsFixed(2)} DT"),
                                            autoCalculateTax
                                                ? Text(
                                                    "- Taxe (calculée): ${ticketTaxPercentage.toStringAsFixed(2)}% = ${(ticketValue * (ticketTaxPercentage / 100)).toStringAsFixed(2)} DT")
                                                : Text(
                                                    "- Taxe: ${ticketTaxPercentage.toStringAsFixed(2)}% = ${(ticketValue * (ticketTaxPercentage / 100)).toStringAsFixed(2)} DT"),
                                            autoCalculateCommission
                                                ? Text(
                                                    "- Commission (calculée): ${ticketCommission.toStringAsFixed(2)} DT")
                                                : Text(
                                                    "- Commission: ${ticketCommission.toStringAsFixed(2)} DT"),
                                            Divider(height: 20),
                                            Text(
                                                "- Total par ticket: ${(ticketValue + (ticketValue * (ticketTaxPercentage / 100)) + ticketCommission).toStringAsFixed(2)} DT"),
                                            SizedBox(height: 5),
                                            Text(
                                              "Montant total pour $numberOfTicketsRestaurant tickets: ${ticketRestaurantAmount.toStringAsFixed(2)} DT",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                if (selectedPaymentMethod == "Bon d'achat")
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: clientPhoneController,
                                              keyboardType: TextInputType.phone,
                                              decoration: InputDecoration(
                                                labelText:
                                                    "Numéro de téléphone client",
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () async {
                                              String phoneInput =
                                                  clientPhoneController.text
                                                      .trim();

                                              if (phoneInput.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Veuillez entrer un numéro de téléphone")),
                                                );
                                                return;
                                              }

                                              int? clientId = await SqlDb()
                                                  .getClientIdByPhone(
                                                      phoneInput);
                                              print(
                                                  "Client ID found: $clientId for phone: $phoneInput");

                                              if (clientId == null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Aucun client trouvé avec ce numéro")),
                                                );
                                                return;
                                              }

                                              List<Voucher> vouchers =
                                                  await SqlDb()
                                                      .fetchClientVouchers(
                                                          clientId);
                                              setState(() {
                                                clientVouchers = vouchers;
                                                showVoucherDropdown = true;
                                              });
                                            },
                                            child: Text("Rechercher"),
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 15, horizontal: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      if (showVoucherDropdown)
                                        Column(
                                          children: [
                                            if (clientVouchers.isEmpty)
                                              Text(
                                                "Aucun bon d'achat disponible pour ce client",
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              )
                                            else
                                              DropdownButtonFormField<Voucher>(
                                                decoration: InputDecoration(
                                                  labelText:
                                                      "Sélectionner un bon d'achat",
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: clientVouchers
                                                    .map((Voucher voucher) {
                                                  return DropdownMenuItem<
                                                      Voucher>(
                                                    value: voucher,
                                                    child: Text(
                                                      "Bon #${voucher.id} - ${voucher.amount} DT (${voucher.isUsed ? 'Utilisé' : 'Disponible'})",
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (Voucher? selected) {
                                                  setState(() {
                                                    selectedVoucher = selected;
                                                    voucherAmount =
                                                        selected?.amount ?? 0.0;
                                                  });
                                                },
                                                validator: (value) => value ==
                                                        null
                                                    ? 'Veuillez sélectionner un bon'
                                                    : null,
                                              ),
                                            SizedBox(height: 10),
                                            if (selectedVoucher != null)
                                              Text(
                                                "Montant du bon: ${selectedVoucher!.amount.toStringAsFixed(2)} DT",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),

                                if (selectedPaymentMethod == "Ticket cadeau")
                                  Column(
                                    children: [
                                      TextField(
                                        controller: giftTicketAmountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              "Montant du ticket cadeau (DT)",
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
                                            giftTicketAmount =
                                                double.tryParse(cleanedValue) ??
                                                    0.0;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            giftTicketNumber = value,
                                        decoration: InputDecoration(
                                          labelText: "Numéro du ticket cadeau",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            giftTicketIssuer = value,
                                        decoration: InputDecoration(
                                          labelText: "Émetteur du ticket",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Traite payment fields
                                if (selectedPaymentMethod == "Traite")
                                  Column(
                                    children: [
                                      TextField(
                                        controller: traiteAmountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              "Montant de la traite (DT)",
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
                                            traiteAmount =
                                                double.tryParse(cleanedValue) ??
                                                    0.0;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            traiteNumber = value,
                                        decoration: InputDecoration(
                                          labelText: "Numéro de la traite",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            traiteBank = value,
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
                                              traiteDate = selectedDate;
                                            });
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: "Date d'échéance",
                                            border: OutlineInputBorder(),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(traiteDate != null
                                                  ? "${traiteDate!.day}/${traiteDate!.month}/${traiteDate!.year}"
                                                  : "Sélectionner une date"),
                                              Icon(Icons.calendar_today),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            traiteBeneficiary = value,
                                        decoration: InputDecoration(
                                          labelText: "Bénéficiaire",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Virement payment fields
                                if (selectedPaymentMethod == "Virement")
                                  Column(
                                    children: [
                                      TextField(
                                        controller: virementAmountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Montant du virement (DT)",
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
                                            virementAmount =
                                                double.tryParse(cleanedValue) ??
                                                    0.0;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            virementReference = value,
                                        decoration: InputDecoration(
                                          labelText: "Référence du virement",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            virementBank = value,
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
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime.now(),
                                          );
                                          if (selectedDate != null) {
                                            setState(() {
                                              virementDate = selectedDate;
                                            });
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: "Date du virement",
                                            border: OutlineInputBorder(),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(virementDate != null
                                                  ? "${virementDate!.day}/${virementDate!.month}/${virementDate!.year}"
                                                  : "Sélectionner une date"),
                                              Icon(Icons.calendar_today),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        onChanged: (value) =>
                                            virementSender = value,
                                        decoration: InputDecoration(
                                          labelText: "Nom de l'émetteur",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Mixte payment fields
                                if (selectedPaymentMethod == "Mixte")
                                  Column(
                                    children: [
                                      // Cash
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
                                      SizedBox(height: 10),

                                      // Card (TPE)
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
                                      SizedBox(height: 10),

                                      // Check
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
                                      SizedBox(height: 10),

                                      // Restaurant Tickets
                                      Text("Ticket Restaurant:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      TextField(
                                        controller: TextEditingController(
                                            text: numberOfTicketsRestaurant
                                                .toString()),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Nombre de tickets",
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            numberOfTicketsRestaurant =
                                                int.tryParse(value) ?? 1;
                                            if (numberOfTicketsRestaurant < 1) {
                                              numberOfTicketsRestaurant = 1;
                                            }
                                            ticketRestaurantAmount =
                                                numberOfTicketsRestaurant *
                                                    ticketValue;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),
                                      TextField(
                                        controller: ticketValueController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Valeur d'un ticket (DT)",
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            ticketValue =
                                                double.tryParse(value) ?? 0.0;
                                            ticketRestaurantAmount =
                                                numberOfTicketsRestaurant *
                                                    ticketValue;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 10),

                                      // Vouchers
                                      Text("Bon d'achat:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: clientPhoneController,
                                              keyboardType: TextInputType.phone,
                                              decoration: InputDecoration(
                                                labelText:
                                                    "Numéro de téléphone client",
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () async {
                                              String phoneInput =
                                                  clientPhoneController.text
                                                      .trim();

                                              if (phoneInput.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Veuillez entrer un numéro de téléphone")),
                                                );
                                                return;
                                              }

                                              int? clientId = await SqlDb()
                                                  .getClientIdByPhone(
                                                      phoneInput);
                                              print(
                                                  "Client ID found: $clientId for phone: $phoneInput");

                                              if (clientId == null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Aucun client trouvé avec ce numéro")),
                                                );
                                                return;
                                              }

                                              List<Voucher> vouchers =
                                                  await SqlDb()
                                                      .fetchClientVouchers(
                                                          clientId);
                                              setState(() {
                                                clientVouchers = vouchers;
                                                showVoucherDropdown = true;
                                              });
                                            },
                                            child: Text("Rechercher"),
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 15, horizontal: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      if (showVoucherDropdown)
                                        Column(
                                          children: [
                                            if (clientVouchers.isEmpty)
                                              Text(
                                                "Aucun bon d'achat disponible pour ce client",
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              )
                                            else
                                              DropdownButtonFormField<Voucher>(
                                                decoration: InputDecoration(
                                                  labelText:
                                                      "Sélectionner un bon d'achat",
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: clientVouchers
                                                    .map((Voucher voucher) {
                                                  return DropdownMenuItem<
                                                      Voucher>(
                                                    value: voucher,
                                                    child: Text(
                                                      "Bon #${voucher.id} - ${voucher.amount} DT (${voucher.isUsed ? 'Utilisé' : 'Disponible'})",
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (Voucher? selected) {
                                                  setState(() {
                                                    selectedVoucher = selected;
                                                    voucherAmount =
                                                        selected?.amount ?? 0.0;
                                                  });
                                                },
                                                validator: (value) => value ==
                                                        null
                                                    ? 'Veuillez sélectionner un bon'
                                                    : null,
                                              ),
                                            SizedBox(height: 10),
                                            if (selectedVoucher != null)
                                              Text(
                                                "Montant du bon: ${selectedVoucher!.amount.toStringAsFixed(2)} DT",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                          ],
                                        ),

                                      SizedBox(height: 10),
                                      Text(
                                        "Total saisi: ${(cashAmount + cardAmount + checkAmount + (ticketRestaurantAmount ?? 0) + (voucherAmount ?? 0)).toStringAsFixed(2)} DT / ${total.toStringAsFixed(2)} DT",
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
                                      width: 40,
                                      height: 35,
                                      child: TextField(
                                        controller: TextEditingController(
                                            text: numberOfTickets.toString()),
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(fontSize: 14),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
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
                          ],
                        ),
                      ),
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
                        discounts,
                        typeDiscounts,
                        isPercentageDiscount
                            ? globalDiscount
                            : globalDiscountValue,
                        isPercentageDiscount,
                        selectedClient,
                        numberOfTickets,
                        selectedPaymentMethod!,
                        cashAmount,
                        cardAmount,
                        checkAmount,
                        checkNumber,
                        cardTransactionId,
                        checkDate,
                        bankName,
                        ticketRestaurantAmount,
                        numberOfTicketsRestaurant,
                        ticketValue,
                        ticketTax,
                        ticketCommission,
                        selectedVoucher,
                        voucherAmount,
                        giftTicketNumber,
                        giftTicketIssuer,
                        giftTicketAmount,
                        traiteNumber,
                        traiteBank,
                        traiteBeneficiary,
                        traiteDate,
                        traiteAmount,
                        virementReference,
                        virementBank,
                        virementSender,
                        virementDate,
                        virementAmount,
                        useLoyaltyPoints,
                        pointsToUse,
                        pointsDiscount,
                        selectedVariants);
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
      double? ticketRestaurantAmount,
      int? numberOfTicketsRestaurant, // Add this
      double? ticketValue, // Add this
      double? ticketTax, // Add this
      double? ticketCommission, // Add this
      Voucher? selectedVoucher, // Add this
      double voucherAmount,
      String giftTicketNumber,
      String giftTicketIssuer,
      double giftTicketAmount,
      String traiteNumber,
      String traiteBank,
      String traiteBeneficiary,
      DateTime? traiteDate,
      double traiteAmount,
      String virementReference,
      String virementBank,
      String virementSender,
      DateTime? virementDate,
      double virementAmount,
      bool useLoyaltyPoints,
      int pointsToUse,
      double pointsDiscount,
      List<Variant?> selectedVariants) async {
    // Validate discount limits
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

    // Calculate totals
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

    // Apply loyalty points discount if used
    if (useLoyaltyPoints && pointsToUse > 0) {
      total = max(0, total - pointsDiscount);
    }

    // Determine payment status and remaining amount
    double totalAmountPaid = 0.0;
    String status;
    double remainingAmount;

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
      case "Ticket Restaurant":
        totalAmountPaid = ticketRestaurantAmount ?? 0;
        status =
            (ticketRestaurantAmount ?? 0) >= total ? "payée" : "semi-payée";
        remainingAmount = (ticketRestaurantAmount ?? 0) >= total
            ? 0.0
            : total - (ticketRestaurantAmount ?? 0);
        break;
      case "Ticket cadeau":
        totalAmountPaid = giftTicketAmount;
        status = giftTicketAmount >= total ? "payée" : "semi-payée";
        remainingAmount =
            giftTicketAmount >= total ? 0.0 : total - giftTicketAmount;
        break;
      case "Traite":
        totalAmountPaid = traiteAmount;
        status = traiteAmount >= total ? "payée" : "semi-payée";
        remainingAmount = traiteAmount >= total ? 0.0 : total - traiteAmount;
        break;
      case "Virement":
        totalAmountPaid = virementAmount;
        status = virementAmount >= total ? "payée" : "semi-payée";
        remainingAmount =
            virementAmount >= total ? 0.0 : total - virementAmount;
        break;
      case "Mixte":
        totalAmountPaid = cashAmount +
            cardAmount +
            checkAmount +
            (ticketRestaurantAmount ?? 0) +
            (voucherAmount) +
            giftTicketAmount +
            traiteAmount +
            virementAmount;
        status = totalAmountPaid >= total ? "payée" : "semi-payée";
        remainingAmount =
            totalAmountPaid >= total ? 0.0 : total - totalAmountPaid;
        break;
      default:
        status = "non payée";
        remainingAmount = total;
    }

    // Validate payment amounts
    if ((selectedPaymentMethod == "TPE" && cardAmount <= 0) ||
        (selectedPaymentMethod == "Chèque" && checkAmount <= 0) ||
        (selectedPaymentMethod == "Espèce" && cashAmount <= 0) ||
        (selectedPaymentMethod == "Ticket Restaurant" &&
            (ticketRestaurantAmount == null || ticketRestaurantAmount <= 0)) ||
        (selectedPaymentMethod == "Ticket cadeau" && giftTicketAmount <= 0) ||
        (selectedPaymentMethod == "Traite" && traiteAmount <= 0) ||
        (selectedPaymentMethod == "Virement" && virementAmount <= 0) ||
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

    // Create order lines with proper variant handling
    // Dans la méthode _confirmPlaceOrder, lors de la création des OrderLines
    List<OrderLine> orderLines = [];
    for (int i = 0; i < selectedProducts.length; i++) {
      Product product = selectedProducts[i];
      Variant? variant = selectedVariants[i];

      String productName = product.designation;
      double price = product.prixTTC;
      if (variant != null) {
        productName += " (${variant.combinationName})";
        price = variant.finalPrice;
      }

      orderLines.add(OrderLine(
        idOrder: 0,
        productCode: product.code ?? 'PROD_${product.id}',
        productName: productName,
        productId: product.id,
        variantId: variant?.id,
        variantCode: variant?.code,
        variantName: variant?.combinationName,
        quantity: quantityProducts[i],
        prixUnitaire: price,
        discount: discounts[i],
        isPercentage: typeDiscounts[i],
        productData: product.toMap(), // Sauvegarde des données du produit
      ));
    }

    // Get current user
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    final user = userJson != null ? User.fromMap(jsonDecode(userJson)) : null;

    // Create order
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

      // Payment amounts
      cashAmount: ["Espèce", "Mixte"].contains(selectedPaymentMethod)
          ? cashAmount
          : null,
      cardAmount:
          ["TPE", "Mixte"].contains(selectedPaymentMethod) ? cardAmount : null,
      checkAmount: ["Chèque", "Mixte"].contains(selectedPaymentMethod)
          ? checkAmount
          : null,
      ticketRestaurantAmount:
          ["Ticket Restaurant", "Mixte"].contains(selectedPaymentMethod)
              ? ticketRestaurantAmount
              : null,
      voucherAmount: ["Bon d'achat", "Mixte"].contains(selectedPaymentMethod)
          ? voucherAmount
          : null,
      giftTicketAmount:
          ["Ticket cadeau", "Mixte"].contains(selectedPaymentMethod)
              ? giftTicketAmount
              : null,
      traiteAmount: ["Traite", "Mixte"].contains(selectedPaymentMethod)
          ? traiteAmount
          : null,
      virementAmount: ["Virement", "Mixte"].contains(selectedPaymentMethod)
          ? virementAmount
          : null,

      // Payment details
      checkNumber: ["Chèque", "Mixte"].contains(selectedPaymentMethod)
          ? checkNumber
          : null,
      cardTransactionId: ["TPE", "Mixte"].contains(selectedPaymentMethod)
          ? cardTransactionId
          : null,
      checkDate: ["Chèque", "Mixte"].contains(selectedPaymentMethod)
          ? checkDate
          : null,
      bankName:
          ["Chèque", "Mixte"].contains(selectedPaymentMethod) ? bankName : null,
      giftTicketNumber:
          ["Ticket cadeau", "Mixte"].contains(selectedPaymentMethod)
              ? giftTicketNumber
              : null,
      giftTicketIssuer:
          ["Ticket cadeau", "Mixte"].contains(selectedPaymentMethod)
              ? giftTicketIssuer
              : null,
      traiteNumber: ["Traite", "Mixte"].contains(selectedPaymentMethod)
          ? traiteNumber
          : null,
      traiteBank: ["Traite", "Mixte"].contains(selectedPaymentMethod)
          ? traiteBank
          : null,
      traiteBeneficiary: ["Traite", "Mixte"].contains(selectedPaymentMethod)
          ? traiteBeneficiary
          : null,
      traiteDate: ["Traite", "Mixte"].contains(selectedPaymentMethod)
          ? traiteDate
          : null,
      virementReference: ["Virement", "Mixte"].contains(selectedPaymentMethod)
          ? virementReference
          : null,
      virementBank: ["Virement", "Mixte"].contains(selectedPaymentMethod)
          ? virementBank
          : null,
      virementSender: ["Virement", "Mixte"].contains(selectedPaymentMethod)
          ? virementSender
          : null,
      virementDate: ["Virement", "Mixte"].contains(selectedPaymentMethod)
          ? virementDate
          : null,

      // Ticket restaurant details
      numberOfTicketsRestaurant:
          ["Ticket Restaurant", "Mixte"].contains(selectedPaymentMethod)
              ? numberOfTicketsRestaurant
              : null,
      ticketValue: ticketValue,
      ticketTax: ticketTax,
      ticketCommission: ticketCommission,

      // Voucher details
      voucherIds: selectedVoucher != null ? [selectedVoucher.id] : null,

      // Loyalty points
      pointsUsed: useLoyaltyPoints ? pointsToUse : null,
      pointsDiscount: useLoyaltyPoints ? pointsDiscount : null,
    );

    try {
      // Save order to database
      int orderId = await SqlDb().addOrder(order);
      // Dans la méthode _confirmPlaceOrder, après la validation de la commande
      final stockMovementService = StockMovementService(SqlDb());

      for (int i = 0; i < selectedProducts.length; i++) {
        final product = selectedProducts[i];
        final quantity = quantityProducts[i];
        final variant = selectedVariants[i];

        if (product.hasVariants && variant != null) {
          // Enregistrer le mouvement pour la variante
          await stockMovementService.recordMovement(StockMovement(
            productId: product.id!,
            variantId: variant.id,
            movementType: 'sale',
            quantity: quantity,
            previousStock: variant.stock,
            newStock: variant.stock - quantity,
            movementDate: DateTime.now(),
            referenceId: orderId.toString(),
            userId: user?.id,
          ));
        } else {
          // Enregistrer le mouvement pour le produit
          await stockMovementService.recordMovement(StockMovement(
            productId: product.id!,
            movementType: 'sale',
            quantity: quantity,
            previousStock: product.stock,
            newStock: product.stock - quantity,
            movementDate: DateTime.now(),
            referenceId: orderId.toString(),
            userId: user?.id,
          ));
        }
      }

      if (orderId <= 0) {
        throw Exception("Failed to save order");
      }

      // Update client debt if needed
      if (selectedClient != null && remainingAmount > 0) {
        try {
          final db = await SqlDb().db;
          double newDebt = selectedClient.debt + remainingAmount;

          await db.update(
            'clients',
            {'debt': newDebt},
            where: 'id = ?',
            whereArgs: [selectedClient.id],
          );

          selectedClient = selectedClient.copyWith(
            debt: newDebt,
            lastPurchaseDate: DateTime.now(),
          );
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

      // Handle loyalty points
      if (selectedClient != null) {
        final db = await SqlDb().db;
        final fidelityController = FidelityController();

        if (useLoyaltyPoints && pointsToUse > 0) {
          await fidelityController.applyPointsToOrder(
              order, selectedClient, pointsToUse, db);
        }

        await fidelityController.addPointsFromOrder(order, db);
      }

      // Update stock
      bool isValidOrder = true;
      for (int i = 0; i < selectedProducts.length; i++) {
        final product = selectedProducts[i];
        final quantity = quantityProducts[i];
        final variant = selectedVariants[i];

        print(
            "Updating stock for product ${product.designation}, variant: $variant");

        if (product.hasVariants && variant != null) {
          if (variant.stock - quantity < 0) {
            isValidOrder = false;
            Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(variant.stock == 0
                    ? "${product.designation} (${variant.combinationName}) est en rupture de stock !"
                    : "Stock insuffisant pour ${product.designation} (${variant.combinationName}) (reste: ${variant.stock})"),
                backgroundColor:
                    variant.stock == 0 ? Colors.red : Colors.orange,
              ),
            );
          } else {
            print(
                "Updating variant stock: id=${variant.id}, new stock=${variant.stock - quantity}");
            await SqlDb()
                .updateVariantStock(variant.id!, variant.stock - quantity);
          }
        } else if (product.stock - quantity < 0) {
          isValidOrder = false;
          Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(product.stock == 0
                  ? "${product.designation} est en rupture de stock !"
                  : "Stock insuffisant pour ${product.designation} (reste: ${product.stock})"),
              backgroundColor: product.stock == 0 ? Colors.red : Colors.orange,
            ),
          );
        } else {
          print(
              "Updating product stock: id=${product.id}, new stock=${product.stock - quantity}");
          await SqlDb()
              .updateProductStock(product.id!, product.stock - quantity);
        }
      }

      // Generate PDF tickets if order is valid
      if (isValidOrder) {
        Order completeOrder = order.copyWith(idOrder: orderId);
        for (int i = 0; i < numberOfTickets; i++) {
          await Getorderlist.generateAndSavePDF(completeOrder);
        }

        Addorder.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
                "Commande #$orderId confirmée et ${numberOfTickets > 1 ? '$numberOfTickets tickets' : '1 ticket'} généré(s)"),
            backgroundColor: Colors.green,
          ),
        );

        // Clear the order data
        selectedProducts.clear();
        quantityProducts.clear();
        discounts.clear();
        typeDiscounts.clear();
        selectedVariants.clear();
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

      // Add to total without applying discounts
      total += basePrice * quantity;
    }

    return total;
  }
}
