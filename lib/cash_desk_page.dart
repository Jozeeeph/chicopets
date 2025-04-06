import 'package:caissechicopets/home_page.dart';
import 'package:caissechicopets/passagecommande/applyDiscount.dart';
import 'package:caissechicopets/variant.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/components/categorieetproduct.dart';
import 'package:caissechicopets/gestioncommande/addorder.dart';
import 'package:caissechicopets/gestioncommande/getorderlist.dart';
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/passagecommande/deleteline.dart';
import 'package:caissechicopets/passagecommande/modifyquantity.dart';
import 'package:caissechicopets/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/components/tableCmd.dart';
import 'package:caissechicopets/gestionproduit/addprod.dart';
import 'package:caissechicopets/gestionproduit/searchprod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashDeskPage extends StatefulWidget {
  const CashDeskPage({super.key});

  @override
  _CashDeskPageState createState() => _CashDeskPageState();
}

class _CashDeskPageState extends State<CashDeskPage> {
  final SqlDb sqldb = SqlDb();
  Future<List<Product>>? products;
  List<Product> selectedProducts = [];
  List<int> quantityProducts = [];
  List<bool> typeDiscounts = [];
  List<double> discounts = [];
  double globalDiscount = 0.0;
  int? selectedProductIndex;
  bool isPercentageDiscount = true;

  double calculateTotal(
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

      if (productTotal < 0) productTotal = 0.0;

      total += productTotal;
    }

    if (isPercentageDiscount) {
      total *= (1 - globalDiscount / 100);
    } else {
      total -= globalDiscount;
    }

    return total;
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _handleApplyDiscount(int index) {
    if (index >= 0 && index < selectedProducts.length) {
      Applydiscount.showDiscountInput(
        context,
        index,
        discounts,
        typeDiscounts,
        selectedProducts,
        () => setState(() {}),
      );
    }
  }

  void _handleQuantityChange(int index) {
    if (index >= 0 && index < quantityProducts.length) {
      ModifyQt.showQuantityInput(
        context,
        index,
        quantityProducts,
        () => setState(() {}),
      );
    }
  }

  void _handleDeleteProduct(int index) {
    if (index >= 0 && index < selectedProducts.length) {
      Deleteline.showDeleteConfirmation(
        index,
        context,
        selectedProducts,
        quantityProducts,
        discounts,
        typeDiscounts,
        () => setState(() {}),
      );
    }
  }

  void _handlePlaceOrder() {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun produit sélectionné")),
      );
      return;
    }

    final order = Order(
      date: DateTime.now().toIso8601String(),
      orderLines: [],
      total: _calculateTotal(),
      modePaiement: "Espèces",
      globalDiscount: globalDiscount,
      isPercentageDiscount: isPercentageDiscount,
    );

    Addorder.showPlaceOrderPopup(
      context,
      order,
      selectedProducts,
      quantityProducts,
      discounts,
      typeDiscounts,
    );
  }

  void _handleSearchProduct() {
    Searchprod.showProductSearchPopup(context);
  }

  void _handleAddProduct() {
    Addprod.showAddProductPopup(
      context: context,
      refreshData: () {
        setState(() {
          products = sqldb
              .getProductsWithCategory()
              .then((maps) => maps.map((map) => Product.fromMap(map)).toList());
        });
      },
    );
  }

  void _handleFetchOrders() {
    Getorderlist.showListOrdersPopUp(context);
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    products = sqldb
        .getProductsWithCategory()
        .then((maps) => maps.map((map) => Product.fromMap(map)).toList());
  }

  double _calculateTotalBeforeDiscount() {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      total += selectedProducts[i].prixTTC * quantityProducts[i];
    }
    return total;
  }

  double _calculateTotal() {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      double productTotal = selectedProducts[i].prixTTC * quantityProducts[i];

      if (typeDiscounts[i]) {
        productTotal *= (1 - discounts[i] / 100);
      } else {
        productTotal -= discounts[i];
      }

      total += productTotal.clamp(0, double.infinity);
    }

    if (isPercentageDiscount) {
      total *= (1 - globalDiscount / 100);
    } else {
      total -= globalDiscount;
    }

    return total.clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          ),
        ),
        title: const Text('Caisse de vente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TableCmd(
              total: calculateTotal(
                selectedProducts,
                quantityProducts,
                discounts,
                typeDiscounts,
                globalDiscount,
                isPercentageDiscount,
              ),
              selectedProducts: selectedProducts,
              quantityProducts: quantityProducts,
              discounts: discounts,
              globalDiscount: globalDiscount,
              typeDiscounts: typeDiscounts,
              onApplyDiscount: _handleApplyDiscount,
              onAddProduct: _handleAddProduct,
              onDeleteProduct: _handleDeleteProduct,
              onSearchProduct: _handleSearchProduct,
              onQuantityChange: _handleQuantityChange,
              onFetchOrders: _handleFetchOrders,
              onPlaceOrder: _handlePlaceOrder,
              isPercentageDiscount: isPercentageDiscount,
              selectedProductIndex: selectedProductIndex,
              onProductSelected: (index) {
                setState(() {
                  selectedProductIndex = index;
                });
              },
              calculateTotal: calculateTotal, // Add this required parameter
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Categorieetproduct(
                selectedProducts: selectedProducts,
                quantityProducts: quantityProducts,
                discounts: discounts,
                onProductSelected: (Product product, [Variant? variant]) {
                  setState(() {
                    int index = selectedProducts.indexWhere((p) {
                      if (p.code.trim().toLowerCase() !=
                          product.code.trim().toLowerCase()) {
                        return false;
                      }
                      if (variant != null && p.variants.isNotEmpty) {
                        return p.variants.any((v) => v.code == variant.code);
                      }
                      return variant == null;
                    });

                    if (index == -1) {
                      final productToAdd = variant != null
                          ? (Product.fromMap(product.toMap())
                            ..variants = [variant])
                          : product;

                      selectedProducts.add(productToAdd);
                      quantityProducts.add(1);
                      discounts.add(0.0);
                      typeDiscounts.add(true);
                      selectedProductIndex = selectedProducts.length - 1;
                    } else {
                      quantityProducts[index]++;
                      selectedProductIndex = index;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
