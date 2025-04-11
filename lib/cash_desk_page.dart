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
import 'package:intl/intl.dart';

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
  String _currentUser = "Non connecté";
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
    _loadProducts();
  }

  Future<void> _loadSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('current_user') ?? "Non connecté";
      _sessionStartTime = DateTime.now();
    });
  }

  void _showSessionInfo() {
    final duration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informations de session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Utilisateur'),
                subtitle: Text(_currentUser),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Durée de session'),
                subtitle: Text(
                  '${duration.inHours}h ${duration.inMinutes.remainder(60)}min',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('Transactions en cours'),
                subtitle: Text('${selectedProducts.length} produits sélectionnés'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Fermer'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Déconnexion'),
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSalesReport() async {
    final salesData = await sqldb.getSalesByCategoryAndProduct();
    print(salesData);
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              AppBar(
                title: const Text('Rapport des ventes par article'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: _buildSalesReport(salesData),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Général: ${_calculateTotalSales(salesData).toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSalesReport(Map<String, Map<String, dynamic>> salesData) {
    List<Widget> widgets = [];
    double grandTotal = 0.0;

    salesData.forEach((category, data) {
      final products = data['products'] as Map<String, dynamic>;
      final categoryTotal = data['total'] as double;
      grandTotal += categoryTotal;

      widgets.add(
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  'Catégorie: $category',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                trailing: Text(
                  'Total: ${categoryTotal.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ...products.entries.map((productEntry) {
                final productName = productEntry.key;
                final productData = productEntry.value as Map<String, dynamic>;
                return ListTile(
                  title: Text(productName),
                  subtitle: Text('Quantité vendue: ${productData['quantity']}'),
                  trailing: Text(
                    'Total: ${productData['total'].toStringAsFixed(2)} €',
                  ),
                );
              }).toList(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    });

    return widgets;
  }

  double _calculateTotalSales(Map<String, Map<String, dynamic>> salesData) {
    return salesData.values.fold(0.0, (sum, categoryData) {
      return sum + (categoryData['total'] as double);
    });
  }

  Future<void> _showOrderDetails(Order order) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails Commande #${order.idOrder}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(order.date))}'),
              Text('Statut: ${order.status}'),
              Text('Mode Paiement: ${order.modePaiement}'),
              const SizedBox(height: 16),
              const Text('Articles:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.orderLines.map((line) => ListTile(
                title: Text(line.idProduct),
                subtitle: Text('${line.quantite} x ${line.prixUnitaire.toStringAsFixed(2)} €'),
                trailing: Text('${(line.finalPrice * line.quantite).toStringAsFixed(2)} €'),
              )).toList(),
              const Divider(),
              Text('Total: ${order.total.toStringAsFixed(2)} €', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Reste à payer: ${order.remainingAmount.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: order.remainingAmount > 0 ? Colors.red : Colors.green,
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

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

  void _loadProducts() {
    products = sqldb
        .getProductsWithCategory()
        .then((maps) => maps.map((map) => Product.fromMap(map)).toList());
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
            icon: const Icon(Icons.receipt),
            tooltip: 'Rapport des ventes',
            onPressed: _showSalesReport,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black),
            onPressed: _showSessionInfo,
          ),
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
              calculateTotal: calculateTotal,
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