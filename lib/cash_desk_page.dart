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
  int? selectedProductIndex;
  String enteredQuantity = "";

  void handleQuantityChange(int index) {
    if (index >= 0 && index < quantityProducts.length) {
      print("Changing quantity for product index: $index");
      ModifyQt.showQuantityInput(context, index, quantityProducts, () {
        setState(() {}); // Refresh UI after quantity update
      });
    } else {
      print("Invalid product index: $index");
    }
  }

  void handlePlaceOrder() {
    Order order = Order(
      date: DateTime.now().toIso8601String(),
      orderLines: [], // Empty list for orderLines
      total: calculateTotal(selectedProducts, quantityProducts),
      modePaiement: "Espèces", // Default payment method
    );
    Addorder.showPlaceOrderPopup(
        context, order, selectedProducts, quantityProducts);
  }

  void handleSearchProduct() {
    Searchprod.showProductSearchPopup(context);
  }

  void handleAddProduct(Function refreshData) {
    Addprod.showAddProductPopup(context, refreshData);
  }

  void handleDeleteProduct(int index) {
    Deleteline.showDeleteConfirmation(
        index, context, selectedProducts, quantityProducts, () {
      setState(() {}); // Refresh UI after deletion
    });
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
            // Table Command Section
            TableCmd(
              total: calculateTotal(selectedProducts, quantityProducts),
              selectedProducts: selectedProducts,
              quantityProducts: quantityProducts,
              calculateTotal: calculateTotal,
              onAddProduct: (refreshData) => handleAddProduct(refreshData),
              onDeleteProduct: handleDeleteProduct,
              onSearchProduct: handleSearchProduct, // Ensure this is passed
              onQuantityChange: handleQuantityChange,
              onFetchOrders: handleFetchOrders,
              onPlaceOrder: handlePlaceOrder, 
            ),

            const SizedBox(height: 10), // Add some spacing

            // Main Content (categories + Products)
            Categorieetproduct(
              selectedProducts: selectedProducts,
              quantityProducts: quantityProducts,
              onProductSelected: (Product product) {
                setState(() {
                  int index = selectedProducts
                      .indexWhere((p) => p.code == product.code);
                  if (index == -1) {
                    // Produit non encore sélectionné, on l'ajoute avec une quantité initiale de 1
                    selectedProducts.add(product);
                    quantityProducts.add(1);
                  } else {
                    // Produit déjà sélectionné, on incrémente la quantité
                    quantityProducts[index]++;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  double calculateTotal(
      List<Product> selectedProducts, List<int> quantityProducts) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      total += selectedProducts[i].prixTTC * quantityProducts[i];
    }
    return total;
  }
}