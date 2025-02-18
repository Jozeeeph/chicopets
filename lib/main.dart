import 'package:caissechicopets/components/categorieetproduct.dart';
import 'package:caissechicopets/gestioncommande/addorder.dart';
import 'package:caissechicopets/gestioncommande/getorderlist.dart';
import 'package:caissechicopets/gestionproduit/addCategory.dart';
import 'package:caissechicopets/gestionproduit/addcategory.dart';
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/passagecommande/deleteline.dart';
import 'package:caissechicopets/passagecommande/modifyquantity.dart';
import 'package:caissechicopets/product.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caissechicopets/components/header.dart';
import 'package:caissechicopets/components/tableCmd.dart';
import 'package:caissechicopets/gestionproduit/addprod.dart';
import 'package:caissechicopets/gestionproduit/searchprod.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  // Initialize databaseFactory for desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory =
        databaseFactoryFfi; // Correctly initialize the database factory
  }
  // await SqlDb().copyDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(), // Appliquer Poppins globalement
      ),
      debugShowCheckedModeBanner: false,
      home: CashDeskPage(),
    );
  }
}

class CashDeskPage extends StatefulWidget {
  CashDeskPage({super.key});

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

  void handleAddProduct() {
    Addprod.showAddProductPopup(context);
  }

  void handleDeleteProduct(int index) {
    Deleteline.showDeleteConfirmation(
        index, context, selectedProducts, quantityProducts, () {
      setState(() {}); // Refresh UI after deletion
    });
  }

  // void handleAddCategory(){
  //   AddCategory(context);
  // }

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
              onAddProduct: handleAddProduct,
              onDeleteProduct: handleDeleteProduct,
              onSearchProduct: handleSearchProduct, // Ensure this is passed
              onQuantityChange: handleQuantityChange,
              onFetchOrders: handleFetchOrders,
              onPlaceOrder: handlePlaceOrder, 
              // onAddCategory: handleAddCategory, // Ensure this is passed
            ),

            const SizedBox(height: 10), // Add some spacing

            // Main Content (categories + Products)
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

  Widget buildNumberButton(String text) {
    return ElevatedButton(
      onPressed: () {},
      child: Text(text),
    );
  }

  // Helper Widgets for Clean Code
  // ignore: non_constant_identifier_names
  Widget TableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Widget TableDataCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.center,
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
