import 'package:caissechicopets/models/order.dart';
import 'package:caissechicopets/models/orderline.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/views/cashdesk_views/components/tableCmd.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderEditPage extends StatefulWidget {
  final Order order;
  final List<Product> products;
  final List<int> quantities;
  final List<double> discounts;
  final List<bool> discountTypes;
  final double globalDiscount;
  final bool isPercentageDiscount;

  const OrderEditPage({
    Key? key,
    required this.order,
    required this.products,
    required this.quantities,
    required this.discounts,
    required this.discountTypes,
    required this.globalDiscount,
    required this.isPercentageDiscount,
  }) : super(key: key);

  @override
  _OrderEditPageState createState() => _OrderEditPageState();
}

class _OrderEditPageState extends State<OrderEditPage> {
  late List<Product> _selectedProducts;
  late List<int> _quantityProducts;
  late List<double> _discounts;
  late List<bool> _typeDiscounts;
  late double _globalDiscount;
  late bool _isPercentageDiscount;
  late Order _originalOrder;
  int? _selectedProductIndex;

  final SqlDb _sqldb = SqlDb();
  final TextEditingController _barcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedProducts = List.from(widget.products);
    _quantityProducts = List.from(widget.quantities);
    _discounts = List.from(widget.discounts);
    _typeDiscounts = List.from(widget.discountTypes);
    _globalDiscount = widget.globalDiscount;
    _isPercentageDiscount = widget.isPercentageDiscount;
    _originalOrder = widget.order;
  }

  double calculateTotal() {
    double total = 0.0;

    for (int i = 0; i < _selectedProducts.length; i++) {
      double price = _selectedProducts[i].hasVariants &&
              _selectedProducts[i].variants.isNotEmpty
          ? _selectedProducts[i].variants.first.finalPrice
          : _selectedProducts[i].prixTTC;

      double lineTotal = _typeDiscounts[i]
          ? price * _quantityProducts[i] * (1 - _discounts[i] / 100)
          : (price * _quantityProducts[i]) - _discounts[i];

      total += lineTotal;
    }

    // Apply global discount
    total = _isPercentageDiscount
        ? total * (1 - _globalDiscount / 100)
        : total - _globalDiscount;

    return total;
  }

  Future<void> _saveEditedOrder() async {
    double newTotal = calculateTotal();

    // Update the order in database
    await _sqldb.updateOrderInDatabase(Order(
      idOrder: _originalOrder.idOrder,
      idClient: _originalOrder.idClient,
      date: _originalOrder.date,
      total: newTotal,
      status: _originalOrder.status,
      modePaiement: _originalOrder.modePaiement,
      cashAmount: _originalOrder.cashAmount,
      cardAmount: _originalOrder.cardAmount,
      cardTransactionId: _originalOrder.cardTransactionId,
      checkAmount: _originalOrder.checkAmount,
      checkNumber: _originalOrder.checkNumber,
      bankName: _originalOrder.bankName,
      checkDate: _originalOrder.checkDate,
      globalDiscount: _globalDiscount,
      isPercentageDiscount: _isPercentageDiscount,
      remainingAmount: _originalOrder.remainingAmount,
      orderLines: [],
    ));

    // Delete all existing order lines
    await _sqldb.deleteOrderLines(_originalOrder.idOrder!);

    // Add new order lines
    for (int i = 0; i < _selectedProducts.length; i++) {
      final product = _selectedProducts[i];
      final variant = product.hasVariants && product.variants.isNotEmpty
          ? product.variants.first
          : null;

      await _sqldb.insertOrderLine(OrderLine(
        idOrder: _originalOrder.idOrder!,
        productId: product.id,
        productCode: product.code,
        productName: product.designation,
        variantId: variant?.id,
        variantName: variant?.combinationName,
        quantity: _quantityProducts[i],
        prixUnitaire: variant?.finalPrice ?? product.prixTTC,
        discount: _discounts[i],
        isPercentage: _typeDiscounts[i],
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Commande modifiée avec succès'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  void _applyLineDiscount(int index) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController discountController = TextEditingController(
          text: _discounts[index].toString(),
        );
        bool isPercentage = _typeDiscounts[index];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Appliquer une remise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Type:'),
                      Radio<bool>(
                        value: true,
                        groupValue: isPercentage,
                        onChanged: (value) {
                          setState(() {
                            isPercentage = true;
                          });
                        },
                      ),
                      const Text('%'),
                      Radio<bool>(
                        value: false,
                        groupValue: isPercentage,
                        onChanged: (value) {
                          setState(() {
                            isPercentage = false;
                          });
                        },
                      ),
                      const Text('DT'),
                    ],
                  ),
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Montant de la remise',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    double discount =
                        double.tryParse(discountController.text) ?? 0;
                    setState(() {
                      _discounts[index] = discount;
                      _typeDiscounts[index] = isPercentage;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Appliquer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _changeQuantity(int index) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController quantityController = TextEditingController(
          text: _quantityProducts[index].toString(),
        );

        return AlertDialog(
          title: const Text('Modifier la quantité'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nouvelle quantité',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                int newQuantity = int.tryParse(quantityController.text) ??
                    _quantityProducts[index];
                setState(() {
                  _quantityProducts[index] = newQuantity;
                });
                Navigator.pop(context);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Modifier Commande #${_originalOrder.idOrder}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveEditedOrder,
          ),
        ],
      ),
      body: Row(
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
                            '${calculateTotal().toStringAsFixed(2)} DT',
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
                          Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_originalOrder.date))}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Barcode input (optional for editing)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: "Rechercher produit (optionnel)",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.blue),
                      onPressed: () {
                        // Implement product search if needed
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Products table
                Container(
                  height: 400,
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
                          child: _selectedProducts.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Aucun produit sélectionné',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _selectedProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = _selectedProducts[index];
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
                                                child:
                                                    Text(product.code ?? '')),
                                            Expanded(
                                              child: Text(
                                                hasVariants
                                                    ? '${product.designation} (${variant!.combinationName})'
                                                    : product.designation,
                                              ),
                                            ),
                                            Expanded(
                                                child: Text(
                                                    '${_quantityProducts[index]}')),
                                            Expanded(
                                              child: Text(
                                                '${_discounts[index]} ${_typeDiscounts[index] ? '%' : 'DT'}',
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
                                                '${_calculateLineTotal(product, index).toStringAsFixed(2)} DT',
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
                        setState(() {
                          _selectedProducts.removeAt(_selectedProductIndex!);
                          _quantityProducts.removeAt(_selectedProductIndex!);
                          _discounts.removeAt(_selectedProductIndex!);
                          _typeDiscounts.removeAt(_selectedProductIndex!);
                          _selectedProductIndex = null;
                        });
                      },
                      isDisabled: _selectedProductIndex == null,
                    ),
                    _buildActionButton(
                      icon: Icons.discount,
                      label: 'REMISE PAR LIGNE',
                      color: const Color(0xFF0056A6),
                      onPressed: () =>
                          _applyLineDiscount(_selectedProductIndex!),
                      isDisabled: _selectedProductIndex == null,
                    ),
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'CHANGER QUANTITÉ',
                      color: const Color(0xFF0056A6),
                      onPressed: () => _changeQuantity(_selectedProductIndex!),
                      isDisabled: _selectedProductIndex == null,
                    ),
                    _buildActionButton(
                      icon: Icons.check_circle,
                      label: 'SAUVEGARDER',
                      color: const Color(0xFF009688),
                      onPressed: _saveEditedOrder,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateLineTotal(Product product, int index) {
    final hasVariants = product.hasVariants && product.variants.isNotEmpty;
    final variant = hasVariants ? product.variants.first : null;
    final price = hasVariants ? variant!.finalPrice : product.prixTTC;
    final quantity = _quantityProducts[index];
    final discount = _discounts[index];

    return _typeDiscounts[index]
        ? price * quantity * (1 - discount / 100)
        : (price * quantity) - discount;
  }
}
