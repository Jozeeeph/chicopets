import 'package:caissechicopets/views/home_views/home_page.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/applyDiscount.dart';
import 'package:caissechicopets/models/variant.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/views/cashdesk_views/cashDeskTable/categorieetproduct.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/addorder.dart';
import 'package:caissechicopets/views/cashdesk_views/cashDeskTable/getorderlist.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/deleteline.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/modifyquantity.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/views/cashdesk_views/cashDeskTable/tableCmd.dart';
import 'package:caissechicopets/views/product_views/addprod.dart';
import 'package:caissechicopets/views/product_views/searchprod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashDeskPage extends StatefulWidget {
  const CashDeskPage({super.key});

  @override
  State<CashDeskPage> createState() => _CashDeskPageState();
}

class _CashDeskPageState extends State<CashDeskPage> {
  final SqlDb _sqldb = SqlDb();
  Future<List<Product>>? _products;
  final List<Product> _selectedProducts = [];
  final List<int> _quantityProducts = [];
  final List<bool> _typeDiscounts = [];
  final List<double> _discounts = [];
  double _globalDiscount = 0.0;
  int? _selectedProductIndex;
  bool _isPercentageDiscount = true;
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
                subtitle: Text('${_selectedProducts.length} produits sélectionnés'),
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

  double _calculateTotal() {
    double total = 0.0;
    for (int i = 0; i < _selectedProducts.length; i++) {
      double productTotal = _selectedProducts[i].prixTTC * _quantityProducts[i];

      if (_typeDiscounts[i]) {
        productTotal *= (1 - _discounts[i] / 100);
      } else {
        productTotal -= _discounts[i];
      }

      total += productTotal.clamp(0, double.infinity);
    }

    if (_isPercentageDiscount) {
      total *= (1 - _globalDiscount / 100);
    } else {
      total -= _globalDiscount;
    }

    return total.clamp(0, double.infinity);
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
    if (index >= 0 && index < _selectedProducts.length) {
      Applydiscount.showDiscountInput(
        context,
        index,
        _discounts,
        _typeDiscounts,
        _selectedProducts,
        () => setState(() {}),
      );
    }
  }

  void _handleQuantityChange(int index) {
    if (index >= 0 && index < _quantityProducts.length) {
      ModifyQt.showQuantityInput(
        context,
        index,
        _quantityProducts,
        () => setState(() {}),
      );
    }
  }

  void _handleDeleteProduct(int index) {
    if (index >= 0 && index < _selectedProducts.length) {
      Deleteline.showDeleteConfirmation(
        index,
        context,
        _selectedProducts,
        _quantityProducts,
        _discounts,
        _typeDiscounts,
        () => setState(() {}),
      );
    }
  }

  void _handlePlaceOrder() {
    if (_selectedProducts.isEmpty) {
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
      globalDiscount: _globalDiscount,
      isPercentageDiscount: _isPercentageDiscount,
    );

    Addorder.showPlaceOrderPopup(
      context,
      order,
      _selectedProducts,
      _quantityProducts,
      _discounts,
      _typeDiscounts,
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
          _products = _sqldb
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
    _products = _sqldb
        .getProductsWithCategory()
        .then((maps) => maps.map((map) => Product.fromMap(map)).toList());
  }

  void _handleProductSelected(Product product, [Variant? variant]) {
    setState(() {
      // Create a unique identifier for this product+variant combination
      String uniqueId = '${product.id}';
      if (variant != null) {
        uniqueId += '_${variant.id}';
      }

      // Check if this exact combination already exists
      int existingIndex = -1;
      for (int i = 0; i < _selectedProducts.length; i++) {
        String currentId = '${_selectedProducts[i].id}';
        if (_selectedProducts[i].variants.isNotEmpty) {
          currentId += '_${_selectedProducts[i].variants.first.id}';
        }
        if (currentId == uniqueId) {
          existingIndex = i;
          break;
        }
      }

      if (existingIndex >= 0) {
        // Increment quantity if same product+variant exists
        _quantityProducts[existingIndex]++;
        _selectedProductIndex = existingIndex;
      } else {
        // Create a new product instance with only the selected variant
        final productToAdd = product.copyWith(
          variants: variant != null ? [variant] : [],
          prixTTC: variant?.finalPrice ?? product.prixTTC,
        );

        _selectedProducts.add(productToAdd);
        _quantityProducts.add(1);
        _discounts.add(0.0);
        _typeDiscounts.add(true);
        _selectedProductIndex = _selectedProducts.length - 1;
      }
    });
  }

  void _handleGlobalDiscountChange(double newValue) {
    setState(() {
      _globalDiscount = newValue;
    });
  }

  void _handleIsPercentageDiscountChange(bool newValue) {
    setState(() {
      _isPercentageDiscount = newValue;
    });
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
              total: _calculateTotal(),
              selectedProducts: _selectedProducts,
              quantityProducts: _quantityProducts,
              discounts: _discounts,
              globalDiscount: _globalDiscount,
              typeDiscounts: _typeDiscounts,
              onApplyDiscount: _handleApplyDiscount,
              onAddProduct: _handleAddProduct,
              onDeleteProduct: _handleDeleteProduct,
              onSearchProduct: _handleSearchProduct,
              onQuantityChange: _handleQuantityChange,
              onFetchOrders: _handleFetchOrders,
              onPlaceOrder: _handlePlaceOrder,
              isPercentageDiscount: _isPercentageDiscount,
              selectedProductIndex: _selectedProductIndex,
              onProductSelected: (index) {
                setState(() {
                  _selectedProductIndex = index;
                });
              },
              calculateTotal: (
                List<Product> products,
                List<int> quantities,
                List<double> discounts,
                List<bool> discountTypes,
                double globalDiscount,
                bool isPercentage,
              ) {
                double total = 0.0;
                for (int i = 0; i < products.length; i++) {
                  double productTotal = products[i].prixTTC * quantities[i];
                  if (discountTypes[i]) {
                    productTotal *= (1 - discounts[i] / 100);
                  } else {
                    productTotal -= discounts[i];
                  }
                  total += productTotal.clamp(0, double.infinity);
                }

                if (isPercentage) {
                  total *= (1 - globalDiscount / 100);
                } else {
                  total -= globalDiscount;
                }

                return total.clamp(0, double.infinity);
              },
              onGlobalDiscountChanged: _handleGlobalDiscountChange,
              onIsPercentageDiscountChanged: _handleIsPercentageDiscountChange,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Categorieetproduct(
                selectedProducts: _selectedProducts,
                quantityProducts: _quantityProducts,
                discounts: _discounts,
                onProductSelected: _handleProductSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}