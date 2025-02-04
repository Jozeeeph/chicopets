import 'package:caissechicopets/product.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caissechicopets/components/header.dart';
import 'package:caissechicopets/components/tableCmd.dart';

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
  int? selectedProductIndex;
  String enteredQuantity = "";
  void handleQuantityChange() {}
  void handleSearchProduct() {
    _showProductSearchPopup(context);
  }

  void handleAddProduct() {
    _showAddProductPopup(context); // Open the popup
  }

  void handleDeleteProduct(int index) {
    _showDeleteConfirmation(index,context);
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
              total: calculateTotal(),
              selectedProducts: selectedProducts,
              onAddProduct: handleAddProduct,
              onDeleteProduct: handleDeleteProduct,
              onSearchProduct: handleSearchProduct, // Ensure this is passed
              onQuantityChange: handleQuantityChange, // Ensure this is passed
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
                                    selectedProducts.add(product);
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
                              String formattedDate = 'N/A';
                              if (product.dateExpiration != null) {
                                try {
                                  formattedDate = DateFormat('dd/MM/yyyy')
                                      .format(DateFormat('yyyy-MM-dd')
                                          .parse(product.dateExpiration!));
                                } catch (e) {
                                  formattedDate = 'Invalid Date';
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

  void _showQuantityInput(BuildContext context) {
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
                                  // Only update if there's a valid selectedProductIndex and enteredQuantity
                                  if (selectedProductIndex != null &&
                                      enteredQuantity.isNotEmpty) {
                                    // Parse the entered quantity
                                    final newQuantity =
                                        int.tryParse(enteredQuantity) ?? 1;

                                    setState(() {});

                                    Navigator.of(context)
                                        .pop(); // Close the dialog
                                  }
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
                                child: Text(number,
                                    style: const TextStyle(
                                        fontSize: 18, color: Colors.white)),
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

  double calculateTotal() {
    return selectedProducts.fold(
        0, (sum, product) => sum + (product.prixTTC * 1));
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

  void _showDeleteConfirmation(int index,BuildContext context) {
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
                  if (index != null &&
                      index! < selectedProducts.length) {
                    selectedProducts.removeAt(index!);
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
