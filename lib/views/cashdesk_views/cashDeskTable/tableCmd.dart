import 'dart:convert';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/views/client_views/client_management.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef RefreshCallback = void Function();

class TableCmd extends StatefulWidget {
  final double total;
  final List<Product> selectedProducts;
  final List<int> quantityProducts;
  final List<double> discounts;
  final List<bool> typeDiscounts;
  final Function(int) onApplyDiscount;
  final Function(int) onDeleteProduct;
  final RefreshCallback onAddProduct;
  final VoidCallback onSearchProduct;
  final double globalDiscount;
  final bool isPercentageDiscount;
  final Function(int) onQuantityChange;
  final double Function(List<Product>, List<int>, List<double>, List<bool>,
      double globalDiscount, bool isPercentageDiscount) calculateTotal;
  final VoidCallback onFetchOrders;
  final VoidCallback onPlaceOrder;
  final int? selectedProductIndex;
  final Function(int) onProductSelected;
  final Function(double) onGlobalDiscountChanged;
  final Function(bool) onIsPercentageDiscountChanged;

  const TableCmd({
    super.key,
    required this.total,
    required this.selectedProducts,
    required this.quantityProducts,
    required this.discounts,
    required this.globalDiscount,
    required this.typeDiscounts,
    required this.onApplyDiscount,
    required this.onDeleteProduct,
    required this.onAddProduct,
    required this.onSearchProduct,
    required this.onQuantityChange,
    required this.calculateTotal,
    required this.onFetchOrders,
    required this.onPlaceOrder,
    required this.isPercentageDiscount,
    this.selectedProductIndex,
    required this.onProductSelected,
    required this.onGlobalDiscountChanged,
    required this.onIsPercentageDiscountChanged,
  });

  @override
  _TableCmdState createState() => _TableCmdState();
}

class _TableCmdState extends State<TableCmd> {
  final SqlDb _sqldb = SqlDb();
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  int? _selectedProductIndex;
  String _scannedBarcode = "";

  // Pending order state
  List<Product> _pendingSelectedProducts = [];
  List<int> _pendingQuantityProducts = [];
  List<double> _pendingDiscounts = [];
  List<bool> _pendingTypeDiscounts = [];
  double _pendingGlobalDiscount = 0.0;
  bool _pendingIsPercentageDiscount = false;

  @override
  void initState() {
    super.initState();
    _barcodeFocusNode.requestFocus();
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    _barcodeFocusNode.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _handleBarcodeScan(_scannedBarcode);
        _scannedBarcode = "";
      } else {
        _scannedBarcode += event.character ?? "";
      }
    }
  }

  Future<void> _handleBarcodeScan(String barcodeScanRes) async {
    if (barcodeScanRes.isEmpty) return;

    final Product? scannedProduct =
        await _sqldb.getProductByCode(barcodeScanRes);

    if (scannedProduct != null) {
      setState(() {
        final bool isVariant = scannedProduct.hasVariants &&
            scannedProduct.variants.any((v) => v.code == barcodeScanRes);

        final int index = widget.selectedProducts.indexWhere((p) {
          if (isVariant) {
            return p.hasVariants &&
                p.variants.any((v) => v.code == barcodeScanRes);
          }
          return p.code == barcodeScanRes;
        });

        if (index != -1) {
          widget.quantityProducts[index]++;
        } else {
          widget.selectedProducts.add(scannedProduct);
          widget.quantityProducts.add(1);
          widget.discounts.add(0.0);
          widget.typeDiscounts.add(true);
        }
      });
    } else {
      _showSnackBar("Produit non trouvé!");
    }
    _barcodeController.clear();
  }

  void _handleManualBarcodeInput() {
    final manualBarcode = _barcodeController.text.trim();
    if (manualBarcode.isNotEmpty) {
      _handleBarcodeScan(manualBarcode);
    } else {
      _showSnackBar("Veuillez saisir un code-barres!");
    }
  }

  void _saveAsPendingOrder() {
    if (widget.selectedProducts.isEmpty) {
      _showSnackBar("Aucun produit à mettre en attente!");
      return;
    }

    setState(() {
      _pendingSelectedProducts = List.from(widget.selectedProducts);
      _pendingQuantityProducts = List.from(widget.quantityProducts);
      _pendingDiscounts = List.from(widget.discounts);
      _pendingTypeDiscounts = List.from(widget.typeDiscounts);
      _pendingGlobalDiscount = widget.globalDiscount;
      _pendingIsPercentageDiscount = widget.isPercentageDiscount;

      widget.selectedProducts.clear();
      widget.quantityProducts.clear();
      widget.discounts.clear();
      widget.typeDiscounts.clear();
    });

    _showSnackBar("Commande mise en attente!");
  }

  void _restorePendingOrder() {
    if (_pendingSelectedProducts.isEmpty) {
      _showSnackBar("Aucune commande en attente!");
      return;
    }

    setState(() {
      widget.selectedProducts.addAll(_pendingSelectedProducts);
      widget.quantityProducts.addAll(_pendingQuantityProducts);
      widget.discounts.addAll(_pendingDiscounts);
      widget.typeDiscounts.addAll(_pendingTypeDiscounts);

      // Use the callbacks instead of direct assignment
      widget.onGlobalDiscountChanged(_pendingGlobalDiscount);
      widget.onIsPercentageDiscountChanged(_pendingIsPercentageDiscount);

      _pendingSelectedProducts.clear();
      _pendingQuantityProducts.clear();
      _pendingDiscounts.clear();
      _pendingTypeDiscounts.clear();
      _pendingGlobalDiscount = 0.0;
      _pendingIsPercentageDiscount = false;
    });

    _showSnackBar("Commande restaurée depuis l'attente!");
  }

  Future<User?> _getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      return userJson != null ? User.fromMap(jsonDecode(userJson)) : null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  void _showClientManagement(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gestion des clients'),
        content: SizedBox(
          width: double.maxFinite,
          child: ClientManagementWidget(
            onClientSelected: (client) => Navigator.pop(context),
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        color: isDisabled ? Colors.grey : color,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: isDisabled ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Products table
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Header with total
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 1, 42, 79),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.calculateTotal(widget.selectedProducts, widget.quantityProducts, widget.discounts, widget.typeDiscounts, widget.globalDiscount, widget.isPercentageDiscount).toStringAsFixed(2)} DT',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 27, 229, 67),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FutureBuilder<User?>(
                          future: _getCurrentUser(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                'Caissier: ${snapshot.data!.username}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }
                            return const Text(
                              'Caissier: ...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        StreamBuilder<DateTime>(
                          stream: Stream.periodic(
                            const Duration(seconds: 1),
                            (_) => DateTime.now(),
                          ),
                          builder: (context, snapshot) {
                            final now = snapshot.data ?? DateTime.now();
                            return Text(
                              'Le ${DateFormat('dd/MM/yyyy').format(now)} à ${DateFormat('HH:mm:ss').format(now)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Barcode input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeController,
                      focusNode: _barcodeFocusNode,
                      decoration: const InputDecoration(
                        labelText: "Scanner ou saisir code-barres",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleManualBarcodeInput(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: _handleManualBarcodeInput,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Products table
              Container(
                height: 270,
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color.fromARGB(255, 1, 42, 79)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Table header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 1, 42, 79),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                              child: Text('Code',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Désignation',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Qté',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Remise',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Prix U',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          Expanded(
                              child: Text('Montant',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                        ],
                      ),
                    ),

                    // Table body
                    Expanded(
                      child: RawScrollbar(
                        thumbColor: const Color.fromARGB(255, 132, 132, 132),
                        radius: const Radius.circular(10),
                        thickness: 7,
                        thumbVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.right,
                        child: widget.selectedProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aucun produit sélectionné',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: widget.selectedProducts.length,
                                itemBuilder: (context, index) {
                                  final product =
                                      widget.selectedProducts[index];
                                  final isSelected =
                                      _selectedProductIndex == index;
                                  final hasVariants = product.hasVariants &&
                                      product.variants.isNotEmpty;
                                  final variant = hasVariants
                                      ? product.variants.first
                                      : null;

                                  return GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedProductIndex = index),
                                    child: Container(
                                      color: isSelected
                                          ? const Color.fromARGB(
                                              255, 166, 196, 222)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: Text(product.code ?? '')),
                                          Expanded(
                                            child: Text(
                                              hasVariants
                                                  ? '${product.designation} (${variant!.combinationName})'
                                                  : product.designation,
                                            ),
                                          ),
                                          Expanded(
                                              child: Text(
                                                  '${widget.quantityProducts[index]}')),
                                          Expanded(
                                            child: Text(
                                              '${widget.discounts[index]} ${widget.typeDiscounts[index] ? '%' : 'DT'}',
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              hasVariants
                                                  ? '${variant!.finalPrice.toStringAsFixed(2)} DT'
                                                  : '${product.prixTTC.toStringAsFixed(2)} DT',
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${_calculateLineTotal(
                                                          product, index)
                                                      .toStringAsFixed(2)} DT',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 15),

        // Action buttons
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 150),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.delete,
                    label: 'SUPPRIMER PRODUIT',
                    color: const Color(0xFFE53935),
                    onPressed: () {
                      widget.onDeleteProduct(_selectedProductIndex!);
                      setState(() => _selectedProductIndex = null);
                    },
                    isDisabled: _selectedProductIndex == null,
                  ),
                  _buildActionButton(
                    icon: Icons.discount,
                    label: 'REMISE PAR LIGNE',
                    color: const Color(0xFF0056A6),
                    onPressed: () =>
                        widget.onApplyDiscount(_selectedProductIndex!),
                    isDisabled: _selectedProductIndex == null,
                  ),
                  _buildActionButton(
                    icon: _pendingSelectedProducts.isEmpty
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    label: _pendingSelectedProducts.isEmpty
                        ? 'EN ATTENTE'
                        : 'RESTAURER',
                    color: const Color(0xFF0056A6),
                    onPressed: _pendingSelectedProducts.isEmpty
                        ? _saveAsPendingOrder
                        : _restorePendingOrder,
                  ),
                  _buildActionButton(
                    icon: Icons.edit,
                    label: 'CHANGER QUANTITÉ',
                    color: const Color(0xFF0056A6),
                    onPressed: () =>
                        widget.onQuantityChange(_selectedProductIndex!),
                    isDisabled: _selectedProductIndex == null,
                  ),
                  _buildActionButton(
                    icon: Icons.person,
                    label: 'COMPTES CLIENTS',
                    color: const Color(0xFF0056A6),
                    onPressed: () => _showClientManagement(context),
                  ),
                  _buildActionButton(
                    icon: Icons.list,
                    label: 'LISTE COMMANDES',
                    color: const Color(0xFF0056A6),
                    onPressed: widget.onFetchOrders,
                  ),
                  _buildActionButton(
                    icon: Icons.check_circle,
                    label: 'VALIDER COMMANDE',
                    color: const Color(0xFF009688),
                    onPressed: widget.onPlaceOrder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateLineTotal(Product product, int index) {
    final hasVariants = product.hasVariants && product.variants.isNotEmpty;
    final variant = hasVariants ? product.variants.first : null;
    final price = hasVariants ? variant!.finalPrice : product.prixTTC;
    final quantity = widget.quantityProducts[index];
    final discount = widget.discounts[index];

    return widget.typeDiscounts[index]
        ? price * quantity * (1 - discount / 100)
        : (price * quantity) - discount;
  }
}
