import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize databaseFactory for desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; // Correctly initialize the database factory
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
              children: const [
                Text('Caissier : foulen ben foulen'),
                Text('Avec Ticket : Vrai'),
                Text('17/01/2025 15:08'),
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
                        ? const Center(
                            child: Text('Aucune commande'),
                          )
                        : ListView.builder(
                            itemCount: selectedProducts.length,
                            itemBuilder: (context, index) {
                              final product = selectedProducts[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(product['code'] ?? '')),
                                    Expanded(
                                        child: Text(product['designation'] ?? '')),
                                    Expanded(
                                        child: Text(product['quantity']
                                                .toString() ??
                                            '1')),
                                    Expanded(child: Text('0')), // Remise placeholder
                                    Expanded(
                                        child: Text(product['prix_ht']
                                            .toString())), // Amount placeholder
                                  ],
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
                        onPressed: () {},
                        child: const Text('Clients'),
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
                  flex: 2,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('1')),
                          Expanded(child: buildNumberButton('2')),
                          Expanded(child: buildNumberButton('3')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('4')),
                          Expanded(child: buildNumberButton('5')),
                          Expanded(child: buildNumberButton('6')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('7')),
                          Expanded(child: buildNumberButton('8')),
                          Expanded(child: buildNumberButton('9')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('0')),
                          Expanded(child: buildNumberButton('X')),
                        ],
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
                            backgroundColor: Colors.green),
                        child: const Text('Valider'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            buildCategoryButton('Poisson', 'assets/images/poison.jpg'),
            buildCategoryButton('Oiseaux', 'assets/images/oiseau.jpg'),
            buildCategoryButton('Chien', 'assets/images/chien.jpg'),
            buildCategoryButton('Chat', 'assets/images/chat.jpg'),
            buildCategoryButton('Collier Laiss', 'assets/images/collier.jpg'),
            buildCategoryButton('Brosse', 'assets/images/brosse.jpg'),
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
                                    product['designation'] ?? 'Unknown Product'),
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
  final products = await sqldb.getProducts();// Fetch products from the database
  final TextEditingController SearchController = TextEditingController();
  ValueNotifier<List<Map<String, dynamic>>> filteredProducts = ValueNotifier(products);

  SearchController.addListener(() {
    String query = SearchController.text.toLowerCase();
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
                  controller: SearchController,
                  decoration: const InputDecoration(labelText: 'Recherche Produit'),
                ),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: filteredProducts,
                  builder: (context, currentProducts, child) {
                    return Table(
                      border: TableBorder.all(color: Colors.grey),
                      columnWidths: const {
                        0: FixedColumnWidth(80), // Code column
                        1: FlexColumnWidth(),    // Designation column
                        2: FixedColumnWidth(80), // Quantity column
                      },
                      children: [
                        // Header row
                        TableRow(
                          decoration: const BoxDecoration(color: Colors.blueAccent),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Désignation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Quantité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Prix HT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Date Expiration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        // Data rows
                        if (currentProducts.isEmpty)
                          TableRow(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Aucun produit trouvé', textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic)),
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
                                  child: Text(product['designation'] ?? 'N/A'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(product['quantity'].toString()),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(product['prix_ht'].toString()),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(product['date_expiration'].toString()),
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



  void _showAddProductPopup(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController taxController = TextEditingController();
    final TextEditingController dateController = TextEditingController();

    taxController.addListener(() {
      if (priceHTController.text.isNotEmpty && taxController.text.isNotEmpty) {
        double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
        double taxe = double.tryParse(taxController.text) ?? 0.0;
        double prixTTC = prixHT + (prixHT * taxe / 100);
        priceTTCController.text = prixTTC.toStringAsFixed(2);
      }
    });

    priceHTController.addListener(() {
      if (priceHTController.text.isNotEmpty && taxController.text.isNotEmpty) {
        double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
        double taxe = double.tryParse(taxController.text) ?? 0.0;
        double prixTTC = prixHT + (prixHT * taxe / 100);
        priceTTCController.text = prixTTC.toStringAsFixed(2);
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un Produit'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code Barre'),
                ),
                TextField(
                  controller: designationController,
                  decoration: const InputDecoration(labelText: 'Désignation'),
                ),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceHTController,
                  decoration: const InputDecoration(labelText: 'Prix HT'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: taxController,
                  decoration: const InputDecoration(labelText: 'Taxe (%)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceTTCController,
                  decoration: const InputDecoration(labelText: 'Prix TTC'),
                  enabled: false, // Make the TTC field read-only
                ),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date Expiration'),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Retrieve values from controllers
                String code = codeController.text;
                String designation = designationController.text;
                int quantity = int.tryParse(quantityController.text) ?? 0;
                double prixHT = double.tryParse(priceHTController.text) ?? 0.0;
                double prixTTC = double.tryParse(priceTTCController.text) ?? 0.0;
                double taxe = double.tryParse(taxController.text) ?? 0.0;
                String date = dateController.text;

                // Save to the database
                await sqldb.addProduct(code, designation, quantity, prixHT, taxe, prixTTC, date);
                Navigator.of(context).pop();
              },
              child: const Text('Ajouter'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }
}
