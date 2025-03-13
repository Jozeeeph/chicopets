import 'package:caissechicopets/passagecommande/applyDiscount.dart';
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
  List<double> discounts = []; // Track discounts for each product
  double globalDiscount = 0.0; // Added global discount
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

  void handleApplyDiscount(int index) {
    if (index >= 0 && index < selectedProducts.length) {
      Applydiscount.showDiscountInput(
        context,
        index,
        discounts,
        typeDiscounts,
        () {
          setState(() {}); // Refresh UI after discount update
        },
      );
    } else {
      print("Invalid product index: $index");
    }
  }

  void handlePlaceOrder() {
    Order order = Order(
      date: DateTime.now().toIso8601String(),
      orderLines: [], // Empty list for orderLines
      total: calculateTotal(selectedProducts, quantityProducts, discounts,
          typeDiscounts, globalDiscount),
      modePaiement: "Espèces", // Default payment method
      globalDiscount: globalDiscount, // Added global discount
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
      discounts, // 5th argument
      typeDiscounts, // 6th argument
      () {
        setState(() {}); // 7th argument (callback)
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
    products?.then((productList) {
      print("Fetched products: $productList");
    });
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
              total: calculateTotal(selectedProducts, quantityProducts,
                  discounts, typeDiscounts, globalDiscount),
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
            ),

            const SizedBox(height: 10), // Add some spacing

            // Main Content (categories + Products)
            Categorieetproduct(
              selectedProducts: selectedProducts,
              quantityProducts: quantityProducts,
              discounts: discounts,
              onProductSelected: (Product product) {
                setState(() {
                  // Debugging: Print the product code being passed in and the codes in selectedProducts
                  print("List length: ${selectedProducts.length}");
                  print("List content: $selectedProducts");
                  print("Selected Product Code: '${product.code}'");
                  for (var p in selectedProducts) {
                    print("Existing Product Code: '${p.code}'");
                  }

                  // Ensuring no spaces or formatting issues
                  int index = selectedProducts.indexWhere(
                    (p) =>
                        p.code.trim().toLowerCase() ==
                        product.code.trim().toLowerCase(),
                  );
                  print("Index found: $index");

                  if (index == -1) {
                    // Product not selected yet, we add it with an initial quantity of 1
                    selectedProducts.add(product);
                    quantityProducts.add(1);
                    discounts
                        .add(0.0); // Add a discount value for the new product
                    typeDiscounts.add(true);
                    selectedProductIndex = selectedProducts.length - 1;
                  } else {
                    // Product already selected, we increment the quantity
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

  // Calculate the total price including discounts
  static double calculateTotal(
    List<Product> selectedProducts,
    List<int> quantityProducts,
    List<double> discounts,
    List<bool> typeDiscounts,
    double globalDiscount, // Added global discount
  ) {
    double total = 0.0;
    for (int i = 0; i < selectedProducts.length; i++) {
      double productTotal = selectedProducts[i].prixTTC * quantityProducts[i];

      if (typeDiscounts[i]) {
        // Percentage discount (applied to the total price)
        productTotal *= (1 - discounts[i] / 100);
      } else {
        // Fixed discount (subtract the discount from the total price)
        productTotal -= discounts[i];
      }

      // Ensure the product total is not negative
      if (productTotal < 0) {
        productTotal = 0.0; // Prevent negative prices
      }

      total += productTotal;

      // Debugging output
      print(
          'Product: ${selectedProducts[i].designation}, Quantity: ${quantityProducts[i]}, Discount: ${discounts[i]}, TypeDiscount: ${typeDiscounts[i]}');
      print('Product Total: $productTotal, Total so far: $total');
    }

    // Apply global discount
    total *= (1 - globalDiscount / 100);

    return total;
  }
}
