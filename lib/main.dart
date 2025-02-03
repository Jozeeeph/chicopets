import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
                color: Colors.white, // Set the background color here
                border: Border.all(color: Colors.blueAccent), // Border color
                borderRadius: BorderRadius.circular(12), // Rounded corners
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(
                        12), // Increased padding for header
                    decoration: BoxDecoration(
                      color: Colors.blueAccent, // Header background color
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                              12)), // Optional: Rounded top corners
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                            child: Text('Code Art',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        Expanded(
                            child: Text('Designation',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        Expanded(
                            child: Text('Quantité',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        Expanded(
                            child: Text('Remise',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        Expanded(
                            child: Text('Montant',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: selectedProducts.isEmpty
                        ? const Center(
                            child: Text('Aucune commande',
                                style: TextStyle(fontStyle: FontStyle.italic)))
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
                                  decoration: BoxDecoration(
                                    color: selectedProductIndex == index
                                        ? Colors.blue.withOpacity(
                                            0.2) // Highlight selected row
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors
                                            .grey.shade300), // Subtle border
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text(product['code'] ?? '',
                                              style: TextStyle(fontSize: 14))),
                                      Expanded(
                                          child: Text(
                                              product['designation'] ?? '',
                                              style: TextStyle(fontSize: 14))),
                                      Expanded(
                                        child: Text(
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
                                          child: Text('0',
                                              style: TextStyle(
                                                  color: Colors.grey))),
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
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (selectedProductIndex != null) {
                                _showQuantityInput(context);
                              } else {
                                _showMessage(context,
                                    'Veuillez sélectionner une ligne.');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'QUANTITÉ',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => _showAddProductPopup(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'AJOUT PRODUIT',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              _showProductSearchPopup(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'RECHERCHE PRODUIT',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10), // Small spacing between columns
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 188, 138, 0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'IMPR TICKET',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'REMISE %',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'VALIDER',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // Spacing before second row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedProductIndex != null) {
                            _showDeleteConfirmation(context);
                          } else {
                            _showMessage(context,
                                'Veuillez sélectionner une ligne à supprimer.');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'ANNULER',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
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
                  ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: filteredProducts,
                    builder: (context, currentProducts, child) {
                      return Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: const {
                          0: FixedColumnWidth(80), // Code column
                          1: FlexColumnWidth(), // Designation column
                          2: FixedColumnWidth(80), // Quantity column
                        },
                        children: [
                          // Header Row
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            children: [
                              TableHeaderCell('Code'),
                              TableHeaderCell('Désignation'),
                              TableHeaderCell('Quantité'),
                              TableHeaderCell('Prix HT'),
                              TableHeaderCell('Date Expiration'),
                            ],
                          ),

                          // Data Rows
                          if (currentProducts.isEmpty)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Aucun produit trouvé',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                                for (int i = 0; i < 4; i++)
                                  const SizedBox.shrink(),
                              ],
                            )
                          else
                            for (var i = 0; i < currentProducts.length; i++)
                              TableRow(
                                decoration: BoxDecoration(
                                  color: i.isEven
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                ),
                                children: [
                                  TableDataCell(
                                      currentProducts[i]['code'] ?? 'N/A'),
                                  TableDataCell(currentProducts[i]
                                          ['designation'] ??
                                      'N/A'),
                                  TableDataCell(
                                      currentProducts[i]['stock'].toString()),
                                  TableDataCell(
                                      currentProducts[i]['prix_ht'].toString()),
                                  TableDataCell(currentProducts[i]
                                          ['date_expiration']
                                      .toString()),
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
