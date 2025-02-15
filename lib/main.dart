import 'dart:io';
import 'package:caissechicopets/order.dart';
import 'package:caissechicopets/orderline.dart';
import 'package:caissechicopets/product.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caissechicopets/components/header.dart';
import 'package:caissechicopets/components/tableCmd.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

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
      _showQuantityInput(context, index);
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
    _showPlaceOrderPopup(context, order);
  }

  void handleSearchProduct() {
    _showProductSearchPopup(context);
  }

  void handleAddProduct() {
    _showAddProductPopup(context); // Open the popup
  }

  void handleDeleteProduct(int index) {
    _showDeleteConfirmation(index, context);
  }

  void handleFetchOrders() {
    _showListOrdersPopUp(context);
  }

  @override
  void initState() {
    super.initState();
    products = sqldb
        .getProducts(); // Modifier getProducts() pour renvoyer List<Product>
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
              onPlaceOrder: handlePlaceOrder, // Ensure this is passed
            ),

            const SizedBox(height: 10), // Add some spacing

            // Main Content (Images + Products)
            Expanded(
              child: Row(
                children: [
                  // Images Section
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3, // Adjust as needed
                      childAspectRatio: 1,
                      padding: const EdgeInsets.all(8.0),
                      children: [
                        buildCategoryButton(
                            'Poisson', 'assets/images/poison.jpg'),
                        buildCategoryButton(
                            'Oiseaux', 'assets/images/oiseau.jpg'),
                        buildCategoryButton('Chien', 'assets/images/chien.jpg'),
                        buildCategoryButton('Chat', 'assets/images/chat.jpg'),
                        buildCategoryButton(
                            'Collier Laiss', 'assets/images/collier.jpg'),
                        buildCategoryButton(
                            'Brosse', 'assets/images/brosse.jpg'),
                      ],
                    ),
                  ),

                  // Divider
                  VerticalDivider(
                    width: 1,
                    color: Colors.grey.shade400,
                    thickness: 1,
                  ),

                  // Product List Section
                  Expanded(
                    child: FutureBuilder<List<Product>>(
                      future: sqldb.getProducts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No products available'));
                        } else {
                          List<Product> products = snapshot.data!;
                          return GridView.count(
                            crossAxisCount: 4, // Number of columns
                            children: products.map((product) {
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    int index = selectedProducts.indexWhere(
                                        (p) => p.code == product.code);
                                    if (index == -1) {
                                      // Product not in the list, add it
                                      selectedProducts.add(product);
                                      quantityProducts.add(1);
                                    } else {
                                      // Product is already in the list, increase quantity
                                      quantityProducts[index]++;
                                    }
                                    // Keep track of the selected product index
                                    selectedProductIndex =
                                        selectedProducts.length - 1;
                                    print(
                                        "Selected Products: $selectedProducts");
                                    print("Quantities : $quantityProducts");
                                  });
                                },
                                child: buildProductButton(
                                    product.designation ?? 'Unknown Product'),
                              );
                            }).toList(),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
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

  Widget buildProductButton(String text) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildCategoryButton(String label, String imagePath) {
    return Container(
      margin: const EdgeInsets.all(6.0),
      width: 80, // Adjust size for smaller buttons
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle, // Makes the button circular
        color: Colors.blue.withOpacity(0.1),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              imagePath,
              width: 80, // Adjust image size
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 60, // Ensure text fits inside the circle
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets for Clean Code
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

  void _showPlaceOrderPopup(BuildContext context, Order order) async {
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
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
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
                              fontFamily:
                                  'Courier', // Monospace for receipt style
                            ),
                          ),
                        ),
                        Divider(
                            thickness: 1,
                            color: Colors.black), // Separator line

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
                                      fontFamily: 'Courier'),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  "Article",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Courier'),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  "Prix U",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Courier'),
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
                                      fontFamily: 'Courier'),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                            thickness: 1,
                            color: Colors.black), // Separator line

                        // Product List from OrderLine
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
                                          fontSize: 16, fontFamily: 'Courier'),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      product.designation,
                                      style: TextStyle(
                                          fontSize: 16, fontFamily: 'Courier'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "${product.prixTTC.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                          fontSize: 16, fontFamily: 'Courier'),
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
                                          fontFamily: 'Courier'),
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
                            color: Colors.black), // Bottom separator

                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total:",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier'),
                            ),
                            Text(
                              "${total.toStringAsFixed(2)} DT", // Display total from order
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier'),
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
                            // This ensures UI updates
                            amountGiven = double.tryParse(value) ?? 0.0;
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
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Annuler"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close popup
                    _confirmPlaceOrder();
                  },
                  child: Text("Confirmer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmPlaceOrder() async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aucun produit sélectionné.")),
      );
      return;
    }

    double total = calculateTotal(selectedProducts, quantityProducts);
    String date = DateTime.now().toIso8601String();
    String modePaiement = "Espèces"; // You can change this if needed

    // Prepare order lines with correct quantities
    List<OrderLine> orderLines = selectedProducts.map((product) {
      int productIndex =
          selectedProducts.indexOf(product); // Find correct index

      return OrderLine(
        idOrder: 0, // Temporary ID
        idProduct: product.code,
        quantite:
            quantityProducts[productIndex], // Correct quantity for this product
        prixUnitaire: product.prixTTC,
      );
    }).toList();

    // Create an Order object
    Order order = Order(
      date: date,
      orderLines: orderLines,
      total: total,
      modePaiement: modePaiement,
    );

    // Save order to database
    int orderId = await SqlDb().addOrder(order);

    if (orderId > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Commande passée avec succès !")),
      );

      setState(() {
        selectedProducts.clear();
        quantityProducts.clear(); // Clear quantities after order
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Erreur lors de l'enregistrement de la commande.")),
      );
    }
  }

  void _showListOrdersPopUp(BuildContext context) async {
    List<Order> orders =
        await sqldb.getOrdersWithOrderLines(); // Récupération des commandes

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Liste des Commandes",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: orders.isEmpty
              ? const Text("Aucune commande disponible.")
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      Order order = orders[index];
                      return ExpansionTile(
                        title: Text(
                          "Commande #${order.idOrder} - ${_formatDate(order.date)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: [
                          ...order.orderLines.map((orderLine) {
                            return FutureBuilder<Product?>(
                              future:
                                  sqldb.getProductByCode(orderLine.idProduct),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data == null) {
                                  return const ListTile(
                                      title: Text("Produit introuvable"));
                                }

                                Product product = snapshot.data!;
                                return ListTile(
                                  title: Text(product.designation),
                                  subtitle:
                                      Text("Quantité: ${orderLine.quantite}"),
                                  trailing: Text(
                                    "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                            );
                          }).toList(),

                          // 🔹 Bouton "Imprimer Ticket"
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showOrderTicketPopup(context, order);
                              },
                              icon: Icon(Icons.print),
                              label: Text("Imprimer Ticket"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  void _showOrderTicketPopup(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Center(
            child: Text(
              "🧾 Ticket de Commande",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Courier'),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(thickness: 1, color: Colors.black),

                // Numéro de commande et date
                Text(
                  "Commande #${order.idOrder}\nDate: ${_formatDate(order.date)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier'),
                ),

                Divider(thickness: 1, color: Colors.black),

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
                              fontFamily: 'Courier'),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Article",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier'),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "Prix U",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier'),
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
                              fontFamily: 'Courier'),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(thickness: 1, color: Colors.black),

                // Liste des produits
                ...order.orderLines.map((orderLine) {
                  return FutureBuilder<Product?>(
                    future: sqldb.getProductByCode(orderLine.idProduct),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        return const ListTile(
                            title: Text("Produit introuvable"));
                      }

                      Product product = snapshot.data!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                "x${orderLine.quantite}",
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Courier'),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                product.designation,
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Courier'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${orderLine.prixUnitaire.toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Courier'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier'),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),

                Divider(thickness: 1, color: Colors.black),

                // Total et Mode de paiement
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total:",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier'),
                    ),
                    Text(
                      "${order.total.toStringAsFixed(2)} DT",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier'),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                Text(
                  "Mode de Paiement: ${order.modePaiement}",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Fermer"),
            ),
            TextButton(
              onPressed: () {
                generateAndSavePDF(context, order);
              },
              child: Text("Imprimer"),
            ),
          ],
        );
      },
    );
  }

//Convert to PDF
  Future<void> generateAndSavePDF(BuildContext context, Order order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text("Ticket de Commande",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 18)),
            ),
            pw.Divider(),

            // Numéro de commande et date
            pw.Text("Commande #${order.idOrder}"),
            pw.Text("Date: ${_formatDate(order.date)}"),
            pw.Divider(),

            // Header de la liste des articles
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Qt",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Article",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Prix U",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Montant",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(),

            // Liste des produits
            ...order.orderLines.map((orderLine) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("x${orderLine.quantite}"),
                  pw.Text(orderLine.idProduct),
                  pw.Text("${orderLine.prixUnitaire.toStringAsFixed(2)} DT"),
                  pw.Text(
                      "${(orderLine.prixUnitaire * orderLine.quantite).toStringAsFixed(2)} DT"),
                ],
              );
            }).toList(),

            pw.Divider(),

            // Total et mode de paiement
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total:",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("${order.total.toStringAsFixed(2)} DT",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text("Mode de Paiement: ${order.modePaiement}"),
          ],
        ),
      ),
    );

    // Obtenir le répertoire de téléchargement
    final directory = await getDownloadsDirectory();
    final filePath = "${directory!.path}/ticket_commande_${order.idOrder}.pdf";

    // Sauvegarde du fichier
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Afficher une notification de succès
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF enregistré dans: $filePath")),
    );
  }

  String _formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
  }

  void _showProductSearchPopup(BuildContext context) async {
    final products =
        await sqldb.getProducts(); // Fetch products from the database
    final TextEditingController searchController = TextEditingController();
    ValueNotifier<List<Product>> filteredProducts = ValueNotifier(products);

    // Filtering logic for search
    searchController.addListener(() {
      String query = searchController.text.toLowerCase();
      filteredProducts.value = products
          .where((product) =>
              (product.code?.contains(query) ?? false) ||
              (product.designation?.toLowerCase().contains(query) ?? false))
          .toList();
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Rounded corners
          ),
          title: const Text(
            'Liste des Produits',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SizedBox(
            width: 600, // Set the popup width
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Search Bar with Styling
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Recherche Produit',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  // Product Table
                  ValueListenableBuilder<List<Product>>(
                    valueListenable: filteredProducts,
                    builder: (context, currentProducts, child) {
                      return Column(
                        children: [
                          // Header Row (only once)
                          Row(
                            children: [
                              Expanded(
                                  child: Text('Code',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                  child: Text('Désignation',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                  child: Text('Stock',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                  child: Text('Prix HT',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                  child: Text('Date Expiration',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                            ],
                          ),
                          // Product Data Rows
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: currentProducts.length,
                            itemBuilder: (context, index) {
                              final product = currentProducts[index];
                              // Date format handling

                              List<String> formattedDatePatterns = [
                                'yyyy-MM-dd',
                                'dd/MM/yyyy',
                                'MM/dd/yyyy',
                                'yyyy/MM/dd',
                                'dd-MM-yyyy',
                                'MM-dd-yyyy'
                              ];

                              String formattedDate =
                                  'Invalid Date'; // Default value in case of an invalid date

                              if (product.dateExpiration?.isNotEmpty ?? false) {
                                for (var pattern in formattedDatePatterns) {
                                  try {
                                    // Try parsing the date with the current pattern
                                    DateTime parsedDate = DateFormat(pattern)
                                        .parseStrict(product.dateExpiration!);

                                    // If parsing is successful, format it in 'dd/MM/yyyy' and break the loop
                                    formattedDate = DateFormat('dd/MM/yyyy')
                                        .format(parsedDate);
                                    break; // Stop looping once a valid format is found
                                  } catch (e) {
                                    // If parsing fails, continue to the next pattern
                                    continue;
                                  }
                                }
                              }

                              return InkWell(
                                child: Container(
                                  color: index.isEven
                                      ? Colors.grey.shade200
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text(product.code ?? 'N/A')),
                                      Expanded(
                                          child: Text(
                                              product.designation ?? 'N/A')),
                                      Expanded(child: Text('${product.stock}')),
                                      Expanded(
                                          child: Text('${product.prixHT} DT')),
                                      Expanded(child: Text(formattedDate)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Popup Buttons
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close popup
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red for cancel
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Fermer',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showQuantityInput(BuildContext context, int productIndex) {
    if (productIndex < 0 || productIndex >= quantityProducts.length) {
      print("Error: Invalid product index ($productIndex)");
      return;
    }

    String enteredQuantity = ""; // Start empty instead of showing default value

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Changer la quantité'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    enteredQuantity.isEmpty ? "0" : enteredQuantity,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  for (var row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['C', '0', 'OK']
                  ])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((number) {
                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (number == "C") {
                                  enteredQuantity = ""; // Clear input
                                } else if (number == "OK") {
                                  if (enteredQuantity.isNotEmpty) {
                                    setState(() {
                                      quantityProducts[productIndex] =
                                          int.parse(enteredQuantity);
                                      print(
                                          "Updated quantity: $enteredQuantity for index: $productIndex");
                                    });
                                  }
                                  Navigator.of(context).pop(); // Close dialog
                                } else {
                                  enteredQuantity += number; // Append number
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  number,
                                  style: const TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        );
      },
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

  Widget _buildNumberButton(BuildContext context, String number) {
    return ElevatedButton(
      onPressed: () {
        // Assuming you need to append this number somewhere, update state
        setState(() {
          // Example: If you have a controller for input, append the number
          // myNumberController.text += number;
        });
        Navigator.of(context).pop(); // Close the dialog
      },
      child: Text(number),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddProductPopup(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();

    // Function to update Price TTC dynamically
    void calculatePriceTTC() {
      if (priceHTController.text.isNotEmpty && taxController.text.isNotEmpty) {
        double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
        double taxe = double.tryParse(taxController.text) ?? 0.0;
        double prixTTC = prixHT + (prixHT * taxe / 100);
        priceTTCController.text = prixTTC.toStringAsFixed(2);
      } else {
        priceTTCController.clear();
      }
    }

    taxController.addListener(calculatePriceTTC);
    priceHTController.addListener(calculatePriceTTC);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un Produit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(codeController, 'Code Barre'),
                _buildTextField(designationController, 'Désignation'),
                _buildTextField(stockController, 'Stock',
                    keyboardType: TextInputType.number),
                _buildTextField(priceHTController, 'Prix HT',
                    keyboardType: TextInputType.number),
                _buildTextField(taxController, 'Taxe (%)',
                    keyboardType: TextInputType.number),
                _buildTextField(priceTTCController, 'Prix TTC', enabled: false),
                _buildTextField(dateController, 'Date Expiration'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Validate input before adding product
                if (codeController.text.isEmpty ||
                    designationController.text.isEmpty ||
                    stockController.text.isEmpty ||
                    priceHTController.text.isEmpty ||
                    taxController.text.isEmpty ||
                    priceTTCController.text.isEmpty ||
                    dateController.text.isEmpty) {
                  _showMessage(context, "Veuillez remplir tous les champs !");
                  return;
                }

                await sqldb.addProduct(
                  codeController.text,
                  designationController.text,
                  int.tryParse(stockController.text) ?? 0,
                  double.tryParse(priceHTController.text) ?? 0.0,
                  double.tryParse(taxController.text) ?? 0.0,
                  double.tryParse(priceTTCController.text) ?? 0.0,
                  dateController.text,
                );

                Navigator.of(context).pop(); // Close popup
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Green for confirmation
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ajouter',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            const SizedBox(width: 20), // Space between buttons
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close popup
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Red for cancel
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      enabled: enabled,
    );
  }

  void _showDeleteConfirmation(int index, BuildContext context) {
    if (index == null || index! < 0) {
      _showMessage(context, "Aucun produit sélectionné !");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette ligne de la commande ?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (index != null && index! < selectedProducts.length) {
                    selectedProducts.removeAt(index!);
                    quantityProducts.removeAt(index!);
                    index = 0; // Reset selection
                  }
                });
                Navigator.of(context).pop(); // Close popup
              },
              child: const Text('Oui'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close popup
              },
              child: const Text('Non'),
            ),
          ],
        );
      },
    );
  }
}
