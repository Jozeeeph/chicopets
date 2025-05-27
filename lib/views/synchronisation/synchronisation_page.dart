import 'package:caissechicopets/services/api_service.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SynchronisationPage extends StatefulWidget {
  const SynchronisationPage({super.key});

  @override
  _SynchronisationPageState createState() => _SynchronisationPageState();
}

class _SynchronisationPageState extends State<SynchronisationPage> {
  String _syncStatus = 'Prêt à synchroniser';
  bool _isSyncing = false;
  double _progress = 0.0;
  String _errorMessage = '';
  int _syncedItems = 0;
  int _totalItems = 0;

  final SqlDb _sqlDb = SqlDb();
  final ApiService _apiService = ApiService(authToken: 'your-auth-token');

  Future<void> _startSync() async {
    setState(() {
      _syncStatus = 'Préparation de la synchronisation...';
      _isSyncing = true;
      _progress = 0.0;
      _errorMessage = '';
      _syncedItems = 0;
    });

    try {
      // First check total products
      final allProducts = await _sqlDb.getProducts();
      print('Total products in DB: ${allProducts.length}');

      final unsyncedStocks = await _sqlDb.getUnsyncedStocks();
      print('Unsynced products: ${unsyncedStocks.length}');
      setState(() {
        _totalItems = unsyncedStocks.length;
        _syncStatus = 'Début de la synchronisation de $_totalItems produits...';
      });

      if (unsyncedStocks.isEmpty) {
        setState(() {
          _syncStatus = 'Aucun stock à synchroniser';
          _isSyncing = false;
        });
        return;
      }

      for (final stock in unsyncedStocks) {
        if (!_isSyncing) break;

        try {
          print('Attempting to sync product ${stock.productId}');
          final success = await _apiService.syncStock(stock);
          print('Sync result for ${stock.productId}: $success');

          if (success) {
            await _sqlDb.markAsSynced(stock.productId);
            print('Successfully marked ${stock.productId} as synced');
          } else {
            print('Failed to sync ${stock.productId} - not marking as synced');
          }
        } catch (e) {
          print('Error syncing ${stock.productId}: $e');
          throw Exception('Échec pour le produit ${stock.productId}: $e');
        }
      }

      if (_isSyncing) {
        setState(() {
          _syncStatus =
              'Synchronisation terminée! $_syncedItems/$_totalItems produits synchronisés';
          _isSyncing = false;
        });
      }
    } catch (e) {
      setState(() {
        _syncStatus = 'Échec de la synchronisation';
        _errorMessage = e.toString();
        _isSyncing = false;
      });
    }
  }

  void _confirmCancelSync() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Annuler la synchronisation'),
          content:
              const Text('Voulez-vous vraiment annuler la synchronisation?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _isSyncing = false);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Oui'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: const Color(0xFF0056A6),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.sync,
                            size: 50, color: Color.fromARGB(255, 1, 166, 249)),
                        const SizedBox(height: 20),
                        Text(
                          'Synchronisation des stocks',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Synchronisez les stocks entre l'application et le serveur",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isSyncing ? null : _startSync,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 1, 166, 249),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          child: Text(
                            _isSyncing ? "Synchronisation..." : "Synchroniser",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (_isSyncing) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 1, 166, 249)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _syncStatus,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (_totalItems > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '$_syncedItems/$_totalItems produits',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _confirmCancelSync,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Annuler la synchronisation"),
                  ),
                ],
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!_isSyncing && _syncStatus != 'Prêt à synchroniser')
                  Column(
                    children: [
                      Text(
                        _syncStatus,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (_totalItems > 0)
                        Text(
                          '$_syncedItems/$_totalItems produits synchronisés',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
