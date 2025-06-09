import 'dart:convert';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/warehouse.dart';
import 'package:caissechicopets/models/order.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  final SqlDb _sqlDb = SqlDb();
  List<Warehouse> warehouses = [];
  List<Order> orders = [];
  Warehouse? selectedWarehouse;
  bool isLoading = true;
  bool isSyncing = false;
  int unsyncedCount = 0;

  @override
  void initState() {
    super.initState();
    fetchWarehouses();
    loadUnsyncedOrders();
  }

  Future<void> loadUnsyncedOrders() async {
    final unsynced = await _sqlDb.getOrdersToSynch();
    setState(() {
      orders = unsynced;
      unsyncedCount = unsynced.length;
    });
  }

  Future<void> fetchWarehouses() async {
    final url = Uri.parse('http://127.0.0.1:8000/pos/warehouse/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          warehouses = data.map((json) => Warehouse.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load warehouses');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: warmRed,
        ),
      );
    }
  }

  Future<void> synchroniseStock() async {
    if (selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez choisir un entrepôt'),
          backgroundColor: warmRed,
        ),
      );
      return;
    }

    final unsyncedOrders =
        orders.where((order) => order.isSync == false).toList();

    if (unsyncedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucune commande à synchroniser'),
          backgroundColor: softOrange,
        ),
      );
      return;
    }

    List<Map<String, dynamic>> productData = [];

    for (var order in unsyncedOrders) {
      for (var line in order.orderLines) {
        if (line.productId == null) continue;
        Product? pr = await _sqlDb.getProductById(line.productId!);
        if (pr == null) continue;

        final isVariant = pr.hasVariants == true;
        int quantity = 0;

        if (isVariant && line.variantCode != null) {
          quantity = await _sqlDb.getVariantStock(pr.id!, line.variantCode!);
        } else if (!isVariant) {
          quantity = pr.stock;
        } else {
          continue; // Skip invalid variant without code
        }

        productData.add({
          'product_id': pr.id,
          'designation': line.productName?.trim().toLowerCase(),
          'quantity': quantity,
          'variant_code': line.variantCode?.trim().toLowerCase(),
        });
      }
    }

    setState(() {
      isSyncing = true;
    });

    try {
      // Send POST request to sync stock
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/pos/sync-stock/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warehouse_id': selectedWarehouse!.id,
          'products': productData,
        }),
      );

      if (response.statusCode == 200) {
        // Update stock items via PATCH requests
        for (var product in productData) {
          final patchUrl = Uri.parse('http://127.0.0.1:8000/pos/stockitem/');
          final patchPayload = jsonEncode({
            'warehouse_id': selectedWarehouse!.id,
            'quantity': product['quantity'],
            'designation': product['designation'],
            if (product['variant_code'] != null)
              'variant_code': product['variant_code'],
          });
          print('PATCH Payload: $patchPayload');

          try {
            final patchResponse = await http.patch(
              patchUrl,
              headers: {'Content-Type': 'application/json'},
              body: patchPayload,
            );

            if (patchResponse.statusCode >= 400) {
              debugPrint('PATCH failed: ${patchResponse.body}');
              throw Exception(
                  'Failed to update stock item: ${patchResponse.body}');
            }
          } catch (e) {
            debugPrint('Erreur PATCH: $e');
            throw Exception('PATCH request failed: $e');
          }
        }

        // Mark orders as synced only after all PATCH requests succeed
        for (var order in unsyncedOrders) {
          order.isSync = true;
          if (order.idOrder != null) {
            await _sqlDb.updateSynchOrder(order.idOrder!);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Synchronisation réussie pour ${selectedWarehouse!.name}'),
            backgroundColor: tealGreen,
          ),
        );

        await loadUnsyncedOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur lors de la synchronisation: ${response.body}'),
            backgroundColor: warmRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: warmRed,
        ),
      );
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: deepBlue),
              const SizedBox(height: 20),
              Text(
                'Chargement des entrepôts...',
                style: TextStyle(color: darkBlue),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: deepBlue,
        foregroundColor: white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synchronisation des stocks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cette fonctionnalité permet de synchroniser vos commandes locales avec le stock central. '
                      'Sélectionnez un entrepôt et cliquez sur "Synchroniser" pour mettre à jour les quantités en stock '
                      'pour toutes les commandes non synchronisées.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightGray.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: softOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$unsyncedCount commande(s) en attente de synchronisation',
                              style: TextStyle(
                                color: darkBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Entrepôt de destination',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: lightGray),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: DropdownButtonFormField<Warehouse>(
                decoration: InputDecoration(
                  labelText: 'Sélectionner un entrepôt',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: white,
                ),
                items: warehouses
                    .map((w) => DropdownMenuItem(
                          value: w,
                          child: Text(
                            w.name,
                            style: TextStyle(color: darkBlue),
                          ),
                        ))
                    .toList(),
                value: selectedWarehouse,
                onChanged: (w) {
                  setState(() {
                    selectedWarehouse = w;
                  });
                },
                dropdownColor: white,
                icon: Icon(Icons.arrow_drop_down, color: deepBlue),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isSyncing ? null : synchroniseStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealGreen,
                  foregroundColor: white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSyncing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: white,
                        ),
                      )
                    else
                      Icon(Icons.sync, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isSyncing
                          ? 'Synchronisation en cours...'
                          : 'Synchroniser',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            if (isSyncing) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                backgroundColor: lightGray,
                color: tealGreen,
                minHeight: 6,
              ),
              const SizedBox(height: 10),
              Text(
                'Ne quittez pas cette page pendant la synchronisation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
