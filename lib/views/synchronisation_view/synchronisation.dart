import 'dart:convert';
import 'package:caissechicopets/models/product.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/warehouse.dart';
import 'package:caissechicopets/models/order.dart'; // make sure this exists

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final SqlDb _sqlDb = SqlDb();
  List<Warehouse> warehouses = [];
  List<Order> orders = [];
  Warehouse? selectedWarehouse;
  bool isLoading = true;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    fetchWarehouses();
    loadUnsyncedOrders(); // 👈 Add this
  }

  Future<void> loadUnsyncedOrders() async {
    final unsynced = await _sqlDb.getOrdersToSynch();
    setState(() {
      orders = unsynced;
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
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> synchroniseStock() async {
    if (selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un entrepôt')),
      );
      return;
    }

    // Filter unsynced orders
    final unsyncedOrders =
        orders.where((order) => order.isSync == false).toList();
    print('Unsynced orders count: ${unsyncedOrders.length}');

    if (unsyncedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande à synchroniser')),
      );
      return;
    }

    // Extract product info
    List<Map<String, dynamic>> productData = [];
    for (var order in unsyncedOrders) {
      for (var line in order.orderLines) {
        final Map<String, dynamic> productMap = {
          'designation': line.productName,
          'variant_code': line.variantCode,
          'quantity': line.quantity,
        };

        productData.add(productMap);
      }
    }

    setState(() {
      isSyncing = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/pos/sync-stock/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warehouse_id': selectedWarehouse!.id,
          'products': productData,
        }),
      );

      if (response.statusCode == 200) {
        for (var order in unsyncedOrders) {
          order.isSync = true;

          // Update in local DB
          await _sqlDb.updateSynchOrder(order.idOrder!);

          // Now update stock per product
          for (var line in order.orderLines) {
            final patchUrl = Uri.parse('http://127.0.0.1:8000/pos/stockitem/');
            Product? pr = await _sqlDb.getProductById(line.productId!);         
            final patchPayload = jsonEncode({
              'warehouse_id': selectedWarehouse!.id,
              'designation': line.productName,
              'variant_code': line.variantCode,
              'quantity': pr?.stock ?? 0,
            });

            try {
              final patchResponse = await http.patch(
                patchUrl,
                headers: {'Content-Type': 'application/json'},
                body: patchPayload,
              );

              if (patchResponse.statusCode == 200) {
                print('Stock mis à jour pour le produit ${line.productId}');
              } else {
                print(
                    'Erreur lors de la mise à jour du stock: ${patchResponse.body}');
              }
            } catch (e) {
              print('Erreur PATCH: $e');
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synchronisation réussie pour ${selectedWarehouse!.name}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la synchronisation')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
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
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButtonFormField<Warehouse>(
              decoration: const InputDecoration(
                labelText: 'Choisissez un entrepôt',
                border: OutlineInputBorder(),
              ),
              items: warehouses
                  .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text(w.name),
                      ))
                  .toList(),
              value: selectedWarehouse,
              onChanged: (w) {
                setState(() {
                  selectedWarehouse = w;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: isSyncing ? null : synchroniseStock,
              icon: isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
              label: Text(isSyncing ? 'Synchronisation...' : 'Synchroniser'),
            )
          ],
        ),
      ),
    );
  }
}
