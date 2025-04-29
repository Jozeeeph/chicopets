import 'package:caissechicopets/models/variant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/models/category.dart';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/models/order.dart';

class SalesReportPage extends StatefulWidget {
  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  // Couleurs
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  DateTime? _selectedStartDate = DateTime.now();
  DateTime? _selectedEndDate = DateTime.now();
  List<User> _users = [];
  User? _selectedUser;
  bool _groupByUser = false;
  List<Map<String, dynamic>> _salesData = [];
  bool _isLoading = false;
  bool _showDateRange = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final db = SqlDb();
    _users = await db.getAllUsers();
    print(
        "Loaded users: ${_users.map((u) => '${u.id}: ${u.username}').join(', ')}"); // Debug
    setState(() {});
  }

  Future<void> _generateReport() async {
    if (_selectedStartDate == null) return;

    if (_groupByUser && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez sélectionner un utilisateur'),
          backgroundColor: warmRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print(
          'Generating report for dates: ${_selectedStartDate} to ${_selectedEndDate}');

      if (_groupByUser) {
        print('Generating user report for user ID: ${_selectedUser!.id}');
        _salesData = await _getSalesReportByUser(_selectedUser!.id!);
      } else {
        print('Generating category report');
        _salesData = await _getSalesReportByCategory();
      }

      print('Report generated with ${_salesData.length} categories');
    } catch (e, stack) {
      print('Error generating report: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du rapport: $e'),
          backgroundColor: warmRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getSalesReportByCategory() async {
    final db = SqlDb();
    final orders = await db.getOrders();

    // Filter orders by date range
    final filteredOrders = orders.where((order) {
      final orderDate = DateTime.parse(order.date).toLocal();
      return _isDateInRange(orderDate, _selectedStartDate!, _selectedEndDate!);
    }).toList();

    final Map<String, Map<String, dynamic>> reportData = {};

    for (final order in filteredOrders) {
      for (final line in order.orderLines) {
        final product = await db.getProductById(line.productId ?? 0);
        if (product == null) continue;

        final category = await db.getCategoryNameById(product.categoryId);
        final categoryName = category ?? 'Non catégorisé';

        if (!reportData.containsKey(categoryName)) {
          reportData[categoryName] = {
            'total': 0.0,
            'totalDiscount': 0.0,
            'totalBeforeDiscount': 0.0,
            'products': <String, Map<String, dynamic>>{},
          };
        }

        // Get variant details if available
        Variant? variant;
        if (line.variantId != null) {
          variant = await db.getVariantById(line.variantId!);
        }

        // Use variant price if available, otherwise use product price
        final unitPrice = variant?.finalPrice ?? line.prixUnitaire;

        // Calculate line total before discount
        final lineTotalBeforeDiscount = unitPrice * line.quantity;

        // Calculate discount amount
        double discountAmount = 0;
        if (line.isPercentage) {
          discountAmount = lineTotalBeforeDiscount * (line.discount / 100);
        } else {
          discountAmount = line.discount * line.quantity;
        }

        // Calculate final line total
        final lineTotal = lineTotalBeforeDiscount - discountAmount;

        final productsMap = reportData[categoryName]!['products']
            as Map<String, Map<String, dynamic>>;

        // Create a unique key for the product with variant
        final variantName =
            variant?.combinationName ?? line.variantName ?? 'Standard';
        final productKey = '${product.designation} ($variantName)';

        if (!productsMap.containsKey(productKey)) {
          productsMap[productKey] = {
            'quantity': 0,
            'total': 0.0,
            'totalBeforeDiscount': 0.0,
            'discount': 0.0,
            'isPercentage': line.isPercentage,
            'variant': variantName,
            'unitPrice': unitPrice,
          };
        }

        productsMap[productKey]!['quantity'] += line.quantity;
        productsMap[productKey]!['total'] += lineTotal;
        productsMap[productKey]!['totalBeforeDiscount'] +=
            lineTotalBeforeDiscount;
        productsMap[productKey]!['discount'] += discountAmount;

        reportData[categoryName]!['total'] += lineTotal;
        reportData[categoryName]!['totalDiscount'] += discountAmount;
        reportData[categoryName]!['totalBeforeDiscount'] +=
            lineTotalBeforeDiscount;
      }
    }

    return reportData.entries.map((entry) {
      return <String, dynamic>{
        'category': entry.key,
        'total': entry.value['total'],
        'totalDiscount': entry.value['totalDiscount'],
        'totalBeforeDiscount': entry.value['totalBeforeDiscount'],
        'products': (entry.value['products'] as Map<String, dynamic>)
            .entries
            .map((product) {
          return <String, dynamic>{
            'name': product.key.split(' (')[0],
            'quantity': product.value['quantity'],
            'total': product.value['total'],
            'totalBeforeDiscount': product.value['totalBeforeDiscount'],
            'discount': product.value['discount'],
            'isPercentage': product.value['isPercentage'],
            'variant': product.value['variant'],
            'unitPrice': product.value['unitPrice'],
          };
        }).toList(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getSalesReportByUser(int userId) async {
    final db = SqlDb();
    final orders = await db.getOrders();

    // Filter orders by user and date range
    final filteredOrders = orders.where((order) {
      if (order.userId != userId) return false;
      final orderDate = DateTime.parse(order.date).toLocal();
      return _isDateInRange(orderDate, _selectedStartDate!, _selectedEndDate!);
    }).toList();

    final Map<String, Map<String, dynamic>> reportData = {};

    for (final order in filteredOrders) {
      for (final line in order.orderLines) {
        final product = await db.getProductById(line.productId ?? 0);
        if (product == null) continue;

        final category = await db.getCategoryNameById(product.categoryId);
        final categoryName = category;

        if (!reportData.containsKey(categoryName)) {
          reportData[categoryName] = {
            'total': 0.0,
            'totalDiscount': 0.0,
            'totalBeforeDiscount': 0.0,
            'products': <String, Map<String, dynamic>>{},
          };
        }

        // Get variant details if available
        Variant? variant;
        if (line.variantId != null) {
          variant = await db.getVariantById(line.variantId!);
        }

        // Use variant price if available, otherwise use product price
        final unitPrice = variant?.finalPrice ?? line.prixUnitaire;

        // Calculate line total before discount
        final lineTotalBeforeDiscount = unitPrice * line.quantity;

        // Calculate discount amount
        double discountAmount = 0;
        if (line.isPercentage) {
          discountAmount = lineTotalBeforeDiscount * (line.discount / 100);
        } else {
          discountAmount = line.discount * line.quantity;
        }

        // Calculate final line total
        final lineTotal = lineTotalBeforeDiscount - discountAmount;

        final productsMap = reportData[categoryName]!['products']
            as Map<String, Map<String, dynamic>>;

        // Create a unique key for the product with variant
        final variantName =
            variant?.combinationName ?? line.variantName ?? 'Standard';
        final productKey = '${product.designation} ($variantName)';

        if (!productsMap.containsKey(productKey)) {
          productsMap[productKey] = {
            'quantity': 0,
            'total': 0.0,
            'totalBeforeDiscount': 0.0,
            'discount': 0.0,
            'isPercentage': line.isPercentage,
            'variant': variantName,
            'unitPrice': unitPrice,
          };
        }

        productsMap[productKey]!['quantity'] += line.quantity;
        productsMap[productKey]!['total'] += lineTotal;
        productsMap[productKey]!['totalBeforeDiscount'] +=
            lineTotalBeforeDiscount;
        productsMap[productKey]!['discount'] += discountAmount;

        reportData[categoryName]!['total'] += lineTotal;
        reportData[categoryName]!['totalDiscount'] += discountAmount;
        reportData[categoryName]!['totalBeforeDiscount'] +=
            lineTotalBeforeDiscount;
      }
    }

    return reportData.entries.map((entry) {
      return <String, dynamic>{
        'category': entry.key,
        'total': entry.value['total'],
        'totalDiscount': entry.value['totalDiscount'],
        'totalBeforeDiscount': entry.value['totalBeforeDiscount'],
        'products': (entry.value['products'] as Map<String, dynamic>)
            .entries
            .map((product) {
          return <String, dynamic>{
            'name': product.key.split(' (')[0],
            'quantity': product.value['quantity'],
            'total': product.value['total'],
            'totalBeforeDiscount': product.value['totalBeforeDiscount'],
            'discount': product.value['discount'],
            'isPercentage': product.value['isPercentage'],
            'variant': product.value['variant'],
            'unitPrice': product.value['unitPrice'],
          };
        }).toList(),
      };
    }).toList();
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    // Normalize dates by removing time components
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);

    print(
        'Checking date: $normalizedDate between $normalizedStart and $normalizedEnd');

    return normalizedDate.isAtSameMomentAs(normalizedStart) ||
        normalizedDate.isAtSameMomentAs(normalizedEnd) ||
        (normalizedDate.isAfter(normalizedStart) &&
            normalizedDate.isBefore(normalizedEnd));
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _selectedStartDate ?? DateTime.now()
          : _selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: deepBlue,
              onPrimary: white,
              onSurface: darkBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
            _selectedEndDate = picked;
          }
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rapports des ventes', style: TextStyle(color: white)),
        backgroundColor: deepBlue,
        iconTheme: IconThemeData(color: white),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Aide'),
                  content: Text(
                      'Générez des rapports de vente par période et par utilisateur.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK', style: TextStyle(color: deepBlue)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightGray.withOpacity(0.1), white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            // Sélecteur de période
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Période du rapport',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: darkBlue)),
                        IconButton(
                          icon: Icon(_showDateRange
                              ? Icons.calendar_today
                              : Icons.date_range),
                          onPressed: () =>
                              setState(() => _showDateRange = !_showDateRange),
                          color: deepBlue,
                        ),
                      ],
                    ),
                    if (!_showDateRange) ...[
                      ListTile(
                        leading: Icon(Icons.calendar_today, color: tealGreen),
                        title: Text('Date unique'),
                        subtitle: Text(_selectedStartDate != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(_selectedStartDate!)
                            : 'Non sélectionnée'),
                        trailing: IconButton(
                          icon: Icon(Icons.edit, color: softOrange),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                    ] else ...[
                      ListTile(
                        leading: Icon(Icons.date_range, color: tealGreen),
                        title: Text('Du'),
                        subtitle: Text(_selectedStartDate != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(_selectedStartDate!)
                            : 'Non sélectionnée'),
                        trailing: IconButton(
                          icon: Icon(Icons.edit, color: softOrange),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.date_range, color: tealGreen),
                        title: Text('Au'),
                        subtitle: Text(_selectedEndDate != null
                            ? DateFormat('dd/MM/yyyy').format(_selectedEndDate!)
                            : 'Non sélectionnée'),
                        trailing: IconButton(
                          icon: Icon(Icons.edit, color: softOrange),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Options de rapport
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Grouper par utilisateur',
                          style: TextStyle(color: darkBlue)),
                      subtitle: Text(_groupByUser
                          ? 'Rapport filtré par utilisateur'
                          : 'Rapport global'),
                      value: _groupByUser,
                      onChanged: (value) =>
                          setState(() => _groupByUser = value),
                      activeColor: tealGreen,
                      secondary: Icon(Icons.group,
                          color: _groupByUser ? tealGreen : lightGray),
                    ),
                    if (_groupByUser) ...[
                      DropdownButtonFormField<User>(
                        value: _selectedUser,
                        onChanged: (user) {
                          setState(() {
                            _selectedUser = user;
                            print(
                                'Selected user: ${user?.username} (ID: ${user?.id})');
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Sélectionner un utilisateur',
                          border: OutlineInputBorder(),
                        ),
                        items: _users.map((user) {
                          return DropdownMenuItem<User>(
                            value: user,
                            child: Text(user.username),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Bouton pour générer le rapport
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepBlue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: white),
                          SizedBox(width: 10),
                          Text('Génération en cours...',
                              style: TextStyle(color: white)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, color: white),
                          SizedBox(width: 10),
                          Text('Générer le rapport',
                              style: TextStyle(color: white, fontSize: 16)),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 16),

// Résultats
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: deepBlue))
                  : _salesData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.insert_chart_outlined,
                                  size: 60, color: lightGray),
                              SizedBox(height: 16),
                              Text('Aucune donnée à afficher',
                                  style:
                                      TextStyle(color: darkBlue, fontSize: 18)),
                              Text(
                                  'Sélectionnez une période et générez un rapport',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _salesData.length,
                          itemBuilder: (context, index) {
                            final categoryData = _salesData[index];
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ExpansionTile(
                                leading: Icon(Icons.category, color: tealGreen),
                                title: Text(
                                  categoryData['category'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total: ${categoryData['total'].toStringAsFixed(2)} DT',
                                      style: TextStyle(
                                        color: deepBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Remise totale: ${categoryData['totalDiscount'].toStringAsFixed(2)} DT',
                                      style: TextStyle(
                                        color: warmRed,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  ...(categoryData['products'] as List)
                                      .map((product) {
                                    return ListTile(
                                      leading: Icon(Icons.shopping_bag,
                                          color: softOrange.withOpacity(0.7)),
                                      title: Text(
                                        '${product['name']} (${product['variant']})',
                                        style: TextStyle(color: darkBlue),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Quantité: ${product['quantity']}'),
                                          Text(
                                            'Prix avant remise: ${product['totalBeforeDiscount'].toStringAsFixed(2)} DT',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${product['total'].toStringAsFixed(2)} DT',
                                            style: TextStyle(
                                              color: deepBlue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Remise: ${product['discount'].toStringAsFixed(2)} DT',
                                            style: TextStyle(
                                              color: warmRed,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
