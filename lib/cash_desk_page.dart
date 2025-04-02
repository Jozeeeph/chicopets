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
import 'package:caissechicopets/components/header.dart';
import 'package:caissechicopets/components/tableCmd.dart';
import 'package:caissechicopets/gestionproduit/addprod.dart';
import 'package:caissechicopets/gestionproduit/searchprod.dart';

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
  String enteredQuantity = "";
  bool isPercentageDiscount = true;

  void handleQuantityChange(int index) {
    if (index >= 0 && index < quantityProducts.length) {
      ModifyQt.showQuantityInput(context, index, quantityProducts, () {
        setState(() {});
      });
    }
  }

  void handleApplyDiscount(int index) {
    if (index >= 0 && index < selectedProducts.length) {
      Applydiscount.showDiscountInput(
        context,
        selectedProductIndex!,
        discounts,
        typeDiscounts,
        selectedProducts,
        () => setState(() {}),
      );
    }
  }

  void handlePlaceOrder() {
    Order order = Order(
      date: DateTime.now().toIso8601String(),
      orderLines: [],
      total: calculateTotal(
          selectedProducts,
          quantityProducts,
          discounts,
          typeDiscounts,
          globalDiscount,
          isPercentageDiscount),
      modePaiement: "Cash",
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

  void handleSearchProduct() {
    Searchprod.showProductSearchPopup(context);
  }

  void handleAddProduct(Function refreshData) {
    Addprod.showAddProductPopup(context, refreshData);
  }

  void handleDeleteProduct(int index) {
    Deleteline.showDeleteConfirmation(
      index,
      context,
      selectedProducts,
      quantityProducts,
      discounts,
      typeDiscounts,
      () {
        setState(() {});
      },
    );
  }

  void handleFetchOrders() {
    Getorderlist.showListOrdersPopUp(context);
  }

  @override
  void initState() {
    super.initState();
    products = sqldb
        .getProductsWithCategory()
        .then((maps) => maps.map((map) => Product.fromMap(map)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(),
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
                  isPercentageDiscount),
              selectedProducts: selectedProducts,
              quantityProducts: quantityProducts,
              discounts: discounts,
              globalDiscount: globalDiscount,
              typeDiscounts: typeDiscounts,
              onApplyDiscount: handleApplyDiscount,
              calculateTotal: calculateTotal,
              onAddProduct: (refreshData) => handleAddProduct(refreshData),
              onDeleteProduct: handleDeleteProduct,
              onSearchProduct: handleSearchProduct,
              onQuantityChange: handleQuantityChange,
              onFetchOrders: handleFetchOrders,
              onPlaceOrder: handlePlaceOrder,
              isPercentageDiscount: isPercentageDiscount,
            ),

            const SizedBox(height: 10),

            Categorieetproduct(
              selectedProducts: selectedProducts,
              quantityProducts: quantityProducts,
              discounts: discounts,
              onProductSelected: (Product product, [Variant? variant]) {
                setState(() {
                  int index = selectedProducts.indexWhere((p) {
                    if (p.code.trim().toLowerCase() == product.code.trim().toLowerCase()) {
                      if (variant != null && p.variants.isNotEmpty) {
                        return p.variants.any((v) => v.code == variant.code);
                      }
                      return true;
                    }
                    return false;
                  });

                  if (index == -1) {
                    Product productToAdd = product;
                    if (variant != null) {
                      productToAdd = Product.fromMap(product.toMap())..variants = [variant];
                    }
                    
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
          ],
        ),
      ),
    );
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
      double price = selectedProducts[i].hasVariants && selectedProducts[i].variants.isNotEmpty
        ? selectedProducts[i].variants.first.price
        : selectedProducts[i].prixTTC;
      
      double productTotal = price * quantityProducts[i];

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
}