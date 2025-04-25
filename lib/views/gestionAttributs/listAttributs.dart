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

  // Couleurs
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

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
        title: Text(
          'Liste des Attributs',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: white,
          ),
        ),
        backgroundColor: deepBlue,
        iconTheme: IconThemeData(color: white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAttributes,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [deepBlue, darkBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildContent(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAttributeDialog,
        backgroundColor: tealGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 50, color: warmRed),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                style: GoogleFonts.poppins(color: white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _refreshAttributes,
                child: Text(
                  'Réessayer',
                  style: GoogleFonts.poppins(color: white),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_attributes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 60, color: lightGray.withOpacity(0.7)),
            const SizedBox(height: 20),
            Text(
              'Aucun attribut trouvé',
              style: GoogleFonts.poppins(
                color: lightGray,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Appuyez sur le bouton + pour en ajouter un',
              style: GoogleFonts.poppins(
                color: lightGray.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      backgroundColor: deepBlue,
      color: tealGreen,
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
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Icon(Icons.label_important_outline,
                          color: deepBlue, size: 24),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          attribute.name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: darkBlue),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: deepBlue),
                          const SizedBox(width: 10),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: warmRed),
                          const SizedBox(width: 10),
                          Text('Supprimer'),
                        ],
                      ),
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
            const SizedBox(height: 12),
            Divider(color: lightGray.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'Valeurs disponibles:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: darkBlue.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attribute.values
                  .map((value) => Chip(
                        label: Text(
                          value,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: deepBlue,
                          ),
                        ),
                        backgroundColor: lightGray,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 28, color: tealGreen),
                    const SizedBox(width: 10),
                    Text(
                      'Ajouter un Attribut',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Nom de l\'attribut',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: darkBlue.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lightGray.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    hintText: 'Ex: Couleur, Taille...',
                    hintStyle:
                        GoogleFonts.poppins(color: darkBlue.withOpacity(0.4)),
                  ),
                  style: GoogleFonts.poppins(color: darkBlue),
                ),
                const SizedBox(height: 20),
                Text(
                  'Valeurs possibles',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: darkBlue.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Séparez les valeurs par des virgules',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: darkBlue.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valuesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lightGray.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    hintText: 'Ex: Rouge, Bleu, Vert...',
                    hintStyle:
                        GoogleFonts.poppins(color: darkBlue.withOpacity(0.4)),
                  ),
                  style: GoogleFonts.poppins(color: darkBlue),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(
                          color: warmRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final values = valuesController.text
                            .split(',')
                            .map((v) => v.trim())
                            .where((v) => v.isNotEmpty)
                            .toSet();

                        if (name.isEmpty || values.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le nom et les valeurs sont obligatoires',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: warmRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                            SnackBar(
                              content: Text(
                                'Attribut ajouté avec succès',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: tealGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur: ${e.toString()}',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: warmRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Ajouter',
                        style: GoogleFonts.poppins(
                          color: white,
                          fontWeight: FontWeight.w500,
                        ),
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

  void _showEditAttributeDialog(Attribut attribute) {
    final nameController = TextEditingController(text: attribute.name);
    final valuesController =
        TextEditingController(text: attribute.values.join(', '));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, size: 28, color: softOrange),
                    const SizedBox(width: 10),
                    Text(
                      'Modifier l\'Attribut',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Nom de l\'attribut',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: darkBlue.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lightGray.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.poppins(color: darkBlue),
                ),
                const SizedBox(height: 20),
                Text(
                  'Valeurs possibles',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: darkBlue.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valuesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lightGray.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.poppins(color: darkBlue),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(
                          color: warmRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: softOrange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        final newValues = valuesController.text
                            .split(',')
                            .map((v) => v.trim())
                            .where((v) => v.isNotEmpty)
                            .toSet();

                        if (newName.isEmpty || newValues.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le nom et les valeurs sont obligatoires',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: warmRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                            SnackBar(
                              content: Text(
                                'Attribut modifié avec succès',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: tealGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur: ${e.toString()}',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: warmRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Enregistrer',
                        style: GoogleFonts.poppins(
                          color: white,
                          fontWeight: FontWeight.w500,
                        ),
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

  void _confirmDeleteAttribute(Attribut attribute) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 60, color: warmRed),
              const SizedBox(height: 20),
              Text(
                'Confirmer la suppression',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Êtes-vous sûr de vouloir supprimer définitivement "${attribute.name}"?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: darkBlue.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: lightGray),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.poppins(
                          color: darkBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: warmRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final db = await _sqlDb.db;
                          await _sqlDb.attributController
                              .deleteAttribute(attribute.id!, db);
                          _refreshAttributes();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"${attribute.name}" supprimé avec succès',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: tealGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur: ${e.toString()}',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: warmRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Supprimer',
                        style: GoogleFonts.poppins(
                          color: white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
