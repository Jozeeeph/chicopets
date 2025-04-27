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

    // Filtrer les commandes par période
    final filteredOrders = orders.where((order) {
      final orderDate = DateTime.parse(order.date).toLocal();
      return (_isDateInRange(
          orderDate, _selectedStartDate!, _selectedEndDate!));
    }).toList();

    // Grouper les produits par catégorie
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
            'products': <String, Map<String, dynamic>>{},
          };
        }

        final productTotal = line.prixUnitaire *
            line.quantity *
            (1 - (line.isPercentage ? line.discount / 100 : 0));

        final productsMap = reportData[categoryName]!['products']
            as Map<String, Map<String, dynamic>>;

        if (!productsMap.containsKey(product.designation)) {
          productsMap[product.designation] = {
            'quantity': 0,
            'total': 0.0,
            'discount': line.discount,
            'isPercentage': line.isPercentage,
            'variant': line.variantName ?? 'Standard',
          };
        }

        productsMap[product.designation]!['quantity'] += line.quantity;
        productsMap[product.designation]!['total'] += productTotal;
        reportData[categoryName]!['total'] += productTotal;
      }
    }

    return reportData.entries.map((entry) {
      return <String, dynamic>{
        'category': entry.key,
        'total': entry.value['total'],
        'products': (entry.value['products'] as Map<String, dynamic>)
            .entries
            .map((product) {
          return <String, dynamic>{
            'name': product.key,
            'quantity': product.value['quantity'],
            'total': product.value['total'],
            'discount': product.value['discount'],
            'isPercentage': product.value['isPercentage'],
            'variant': product.value['variant'],
          };
        }).toList(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getSalesReportByUser(int userId) async {
    final db = SqlDb();

    try {
      // 1. DATE HANDLING
      final startDate = _selectedStartDate ?? DateTime.now();
      final endDate = _selectedEndDate ?? DateTime.now();

      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      debugPrint(
          'Report for user $userId from ${DateFormat('yyyy-MM-dd').format(normalizedStart)} to ${DateFormat('yyyy-MM-dd').format(normalizedEnd)}');

      // 2. GET ORDERS WITH ORDER LINES
      final allOrders = await db.getOrdersWithOrderLines();
      print('all orders : $allOrders');

      // Filter orders by user and date range
      final filteredOrders = allOrders.where((order) {
        if (order.userId != userId) return false;

        try {
          if (order.date == null) return false;
          final orderDate = DateTime.parse(order.date!).toLocal();
          return orderDate.isAtSameMomentAs(normalizedStart) ||
              orderDate.isAtSameMomentAs(normalizedEnd) ||
              (orderDate.isAfter(normalizedStart) &&
                  orderDate.isBefore(normalizedEnd));
        } catch (e) {
          debugPrint(
              'Error parsing date for order ${order.idOrder}: ${order.date}');
          return false;
        }
      }).toList();

      if (filteredOrders.isEmpty) {
        debugPrint('No orders found for user $userId in date range');
        return [];
      }

      // 3. PRE-FETCH PRODUCTS AND CATEGORIES
      final productIds = filteredOrders
          .expand(
              (order) => order.orderLines.map((line) => line.productId ?? 0))
          .where((id) => id > 0)
          .toSet();

      final products = <int, Product>{};
      for (final id in productIds) {
        final product = await db.getProductById(id);
        if (product != null) products[id] = product;
      }

      // 4. AGGREGATE DATA
      final reportData = <String, Map<String, dynamic>>{};

      for (final order in filteredOrders) {
        for (final line in order.orderLines) {
          final product = products[line.productId ?? 0];
          if (product == null) continue;

          final category = await db.getCategoryNameById(product.categoryId);
          final categoryName = category ?? 'Non catégorisé';

          // Initialize category if not exists
          reportData.putIfAbsent(
              categoryName,
              () => {
                    'total': 0.0,
                    'products': <String, Map<String, dynamic>>{},
                  });

          // Calculate line total
          double lineTotal = line.isPercentage
              ? line.prixUnitaire * line.quantity * (1 - line.discount / 100)
              : (line.prixUnitaire - line.discount) * line.quantity;

          // Create product key with variant
          final variant = line.variantName?.isNotEmpty == true
              ? line.variantName
              : 'Standard';
          final productKey = '${product.designation} ($variant)';

          // Initialize product if not exists
          reportData[categoryName]!['products'].putIfAbsent(
              productKey,
              () => {
                    'quantity': 0,
                    'total': 0.0,
                    'discount': line.discount,
                    'isPercentage': line.isPercentage,
                    'variant': variant,
                  });

          // Update aggregates
          reportData[categoryName]!['products'][productKey]!['quantity'] +=
              line.quantity;
          reportData[categoryName]!['products'][productKey]!['total'] +=
              lineTotal;
          reportData[categoryName]!['total'] += lineTotal;
        }
      }

      // 5. CONVERT TO REPORT FORMAT
      return reportData.entries.map((entry) {
        return <String, dynamic>{
          'category': entry.key,
          'total': entry.value['total'],
          'products': (entry.value['products'] as Map<String, dynamic>)
              .entries
              .map((product) {
            return <String, dynamic>{
              'name': product.key.split(' (')[0],
              'quantity': product.value['quantity'],
              'total': product.value['total'],
              'discount': product.value['discount'],
              'isPercentage': product.value['isPercentage'],
              'variant': product.value['variant'],
            };
          }).toList(),
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('Error generating report: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: ${e.toString()}')),
      );
      return [];
    }
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
                                subtitle: Text(
                                  'Total: ${categoryData['total'].toStringAsFixed(2)} DT',
                                  style: TextStyle(
                                    color: deepBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                                      subtitle: Text(
                                        'Quantité: ${product['quantity']}',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
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
                                            'Remise: ${product['discount']}${product['isPercentage'] ? '%' : 'DT'}',
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
