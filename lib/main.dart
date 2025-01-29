import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize databaseFactory for desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory =
        databaseFactoryFfi; // Correctly initialize the database factory
  }
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
  Future<List<Map<String, dynamic>>>? products;
  List<Map<String, dynamic>> selectedProducts = [];
  int? selectedProductIndex;
  String enteredQuantity = "";

  @override
  void initState() {
    super.initState();
    products = sqldb.getProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash-Desk'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Caissier : foulen ben foulen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text(
                  'Avec Ticket : Vrai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: ${calculateTotal().toStringAsFixed(2)} DT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(DateTime.now()), // Get system time
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 10),
            // Order Section
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue,
                    child: Row(
                      children: const [
                        Expanded(child: Text('Code Art')),
                        Expanded(child: Text('Designation')),
                        Expanded(child: Text('Quantité')),
                        Expanded(child: Text('Remise')),
                        Expanded(child: Text('Montant')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: selectedProducts.isEmpty
                        ? const Center(child: Text('Aucune commande'))
                        : ListView.builder(
                            itemCount: selectedProducts.length,
                            itemBuilder: (context, index) {
                              final product = selectedProducts[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedProductIndex = index;
                                  });
                                },
                                child: Container(
                                  color: selectedProductIndex == index
                                      ? Colors.blue.withOpacity(0.3)
                                      : null,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text(product['code'] ?? '')),
                                      Expanded(
                                          child: Text(
                                              product['designation'] ?? '')),
                                      Expanded(
                                        child: Text(
                                          // Ensure we show the updated quantity
                                          selectedProductIndex != null &&
                                                  selectedProductIndex == index
                                              ? selectedProducts[
                                                          selectedProductIndex!]
                                                      ['quantity']
                                                  .toString()
                                              : product['quantity'].toString(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(
                                          child:
                                              Text('0')), // Remise placeholder
                                      Expanded(
                                        child: Text(
                                          (product['prix_ttc'] *
                                                  (product['quantity'] ?? 1))
                                              .toStringAsFixed(2),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Button Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          if (selectedProductIndex != null) {
                            _showQuantityInput(context);
                          } else {
                            _showMessage(
                                context, 'Veuillez sélectionner une ligne.');
                          }
                        },
                        child: const Text('Quantité'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showAddProductPopup(context),
                        child: const Text('Ajout Produit'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _showProductSearchPopup(context);
                        },
                        child: const Text('Recherche Produit'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Impr Ticket'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Remise %'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 59, 249, 66)),
                        child: const Text('Valider'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedProductIndex != null) {
                            _showDeleteConfirmation(context);
                          } else {
                            _showMessage(context,
                                'Veuillez sélectionner une ligne à supprimer.');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 255, 89, 77)),
                        child: const Text('Annuler'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

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
                  // Divider between sections
                  VerticalDivider(
                    width: 1,
                    color: Colors.grey.shade400,
                    thickness: 1,
                  ),
                  // Product List Section
                  VerticalDivider(
                    width: 1,
                    color: Colors.grey.shade400,
                    thickness: 1,
                  ),
                  // Product List Section
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
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
                          List<Map<String, dynamic>> products = snapshot.data!;
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
                                    product['designation'] ??
                                        'Unknown Product'),
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
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showProductSearchPopup(BuildContext context) async {
    final products =
        await sqldb.getProducts(); // Fetch products from the database
    final TextEditingController searchController = TextEditingController();
    ValueNotifier<List<Map<String, dynamic>>> filteredProducts =
        ValueNotifier(products);

    searchController.addListener(() {
      String query = searchController.text.toLowerCase();
      filteredProducts.value = products
          .where((product) =>
              (product['code']?.toLowerCase().contains(query) ?? false) ||
              (product['designation']?.toLowerCase().contains(query) ?? false))
          .toList();
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Liste des Produits'),
          content: Container(
            width: 600, // Set the width of the popup
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration:
                        const InputDecoration(labelText: 'Recherche Produit'),
                  ),
                  ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: filteredProducts,
                    builder: (context, currentProducts, child) {
                      return Table(
                        border: TableBorder.all(color: Colors.grey),
                        columnWidths: const {
                          0: FixedColumnWidth(80), // Code column
                          1: FlexColumnWidth(), // Designation column
                          2: FixedColumnWidth(80), // Quantity column
                        },
                        children: [
                          // Header row
                          TableRow(
                            decoration:
                                const BoxDecoration(color: Colors.blueAccent),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Code',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Désignation',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Quantité',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Prix HT',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Date Expiration',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          // Data rows
                          if (currentProducts.isEmpty)
                            TableRow(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Aucun produit trouvé',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic)),
                                ),
                                const SizedBox.shrink(),
                                const SizedBox.shrink(),
                                const SizedBox.shrink(),
                                const SizedBox.shrink(),
                              ],
                            )
                          else
                            for (var product in currentProducts)
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(product['code'] ?? 'N/A'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child:
                                        Text(product['designation'] ?? 'N/A'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(product['stock'].toString()),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(product['prix_ht'].toString()),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        product['date_expiration'].toString()),
                                  ),
                                ],
                              ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the popup
              },
              child: const Text('Fermer'),
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

                                    setState(() {
                                      selectedProducts[selectedProductIndex!]
                                          ['quantity'] = newQuantity;
                                    });

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
        0, (sum, product) => sum + (product['prix_ttc'] * product['quantity']));
  }

  Widget _buildNumberButton(BuildContext context, String number) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          if (selectedProductIndex != null) {
            // Ensure the selected product is mutable
            selectedProducts[selectedProductIndex!]['quantity'] =
                int.tryParse(number) ?? 1;
          }
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
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();

    // Listeners for tax and price calculation
    void calculatePriceTTC() {
      if (priceHTController.text.isNotEmpty && taxController.text.isNotEmpty) {
        double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
        double taxe = double.tryParse(taxController.text) ?? 0.0;
        double prixTTC = prixHT + (prixHT * taxe / 100);
        priceTTCController.text = prixTTC.toStringAsFixed(2);
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
              children: [
                _buildTextField(codeController, 'Code Barre'),
                _buildTextField(designationController, 'Désignation'),
                _buildTextField(stockController, 'Stock',
                    keyboardType: TextInputType.number),
                _buildTextField(quantityController, 'Quantité',
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
                await sqldb.addProduct(
                  codeController.text,
                  designationController.text,
                  int.tryParse(stockController.text) ?? 0,
                  int.tryParse(quantityController.text) ?? 0,
                  double.tryParse(priceHTController.text) ?? 0.0,
                  double.tryParse(taxController.text) ?? 0.0,
                  double.tryParse(priceTTCController.text) ?? 0.0,
                  dateController.text,
                );
                Navigator.of(context).pop(); // Close popup
              },
              child: const Text('Ajouter'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close popup
              },
              child: const Text('Annuler'),
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

  void _showDeleteConfirmation(BuildContext context) {
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
                  selectedProducts.removeAt(selectedProductIndex!);
                  selectedProductIndex = null; // Reset selection
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
