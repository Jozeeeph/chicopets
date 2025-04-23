import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/attribut.dart';
import 'package:google_fonts/google_fonts.dart';

class ListAttributs extends StatefulWidget {
  const ListAttributs({super.key});

  @override
  _ListAttributsState createState() => _ListAttributsState();
}

class _ListAttributsState extends State<ListAttributs> {
  final SqlDb _sqlDb = SqlDb();
  List<Attribut> _attributes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAttributes();
  }

  Future<void> _loadAttributes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final db = await _sqlDb.db;
      final attributes = await _sqlDb.attributController.getAllAttributes(db);
      setState(() {
        _attributes = attributes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attributes: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAttributes() async {
    await _loadAttributes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Attributs'),
        backgroundColor: const Color(0xFF0056A6),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAttributes,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _buildContent(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAttributeDialog,
        backgroundColor: const Color(0xFF009688),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    }

    if (_attributes.isEmpty) {
      return Center(
        child: Text(
          'Aucun attribut trouvé',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAttributes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _attributes.length,
        itemBuilder: (context, index) {
          final attribute = _attributes[index];
          return _buildAttributeCard(attribute);
        },
      ),
    );
  }

  Widget _buildAttributeCard(Attribut attribute) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  attribute.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Modifier'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditAttributeDialog(attribute);
                    } else if (value == 'delete') {
                      _confirmDeleteAttribute(attribute);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Valeurs:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attribute.values
                  .map((value) => Chip(
                        label: Text(value),
                        backgroundColor: Colors.blue[50],
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAttributeDialog() {
    final nameController = TextEditingController();
    final valuesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Attribut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'attribut',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valuesController,
              decoration: const InputDecoration(
                labelText: 'Valeurs (séparées par des virgules)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final values = valuesController.text
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toSet();

              if (name.isEmpty || values.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le nom et les valeurs sont obligatoires'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final db = await _sqlDb.db;
                await _sqlDb.attributController.addAttribute(
                  Attribut(name: name, values: values),
                  db,
                );
                Navigator.pop(context);
                _refreshAttributes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attribut ajouté avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditAttributeDialog(Attribut attribute) {
    final nameController = TextEditingController(text: attribute.name);
    final valuesController = TextEditingController(
        text: attribute.values.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'Attribut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'attribut',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valuesController,
              decoration: const InputDecoration(
                labelText: 'Valeurs (séparées par des virgules)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newValues = valuesController.text
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toSet();

              if (newName.isEmpty || newValues.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le nom et les valeurs sont obligatoires'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final db = await _sqlDb.db;
                await _sqlDb.attributController.updateAttribute(
                  Attribut(
                    id: attribute.id,
                    name: newName,
                    values: newValues,
                  ),
                  db,
                );
                Navigator.pop(context);
                _refreshAttributes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attribut modifié avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAttribute(Attribut attribute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${attribute.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final db = await _sqlDb.db;
                await _sqlDb.attributController.deleteAttribute(attribute.id!, db);
                _refreshAttributes();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${attribute.name}" supprimé avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}