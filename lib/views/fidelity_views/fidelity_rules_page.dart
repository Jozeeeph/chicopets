import 'package:flutter/material.dart';
import 'package:caissechicopets/models/fidelity_rules.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/controllers/fidelity_controller.dart';

class FidelityRulesPage extends StatefulWidget {
  @override
  _FidelityRulesPageState createState() => _FidelityRulesPageState();
}

class _FidelityRulesPageState extends State<FidelityRulesPage> {
  final _formKey = GlobalKey<FormState>();
  late FidelityRules _rules;
  bool _isLoading = true;

  // Palette de couleurs
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
    _loadRules();
  }

  Future<void> _loadRules() async {
    final db = await SqlDb().db;
    _rules = await FidelityController().getFidelityRules(db);
    setState(() => _isLoading = false);
  }

  Future<void> _saveRules() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    final db = await SqlDb().db;
    await FidelityController().updateFidelityRules(_rules, db);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Règles mises à jour avec succès'),
        backgroundColor: tealGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String initialValue,
    required IconData icon,
    required String helperText,
    required String? Function(String?) validator,
    required Function(String?) onSaved,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: deepBlue, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              initialValue: initialValue,
              decoration: InputDecoration(
                filled: true,
                fillColor: lightGray.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                helperText: helperText,
                suffixText: suffixText,
              ),
              keyboardType: keyboardType,
              validator: validator,
              onSaved: onSaved,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(deepBlue),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Règles de fidélité',
          style: TextStyle(color: white),
        ),
        backgroundColor: deepBlue,
        iconTheme: IconThemeData(color: white),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: white),
            onPressed: _saveRules,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: Container(
        color: lightGray.withOpacity(0.1),
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildInputField(
                label: 'Points par dinar dépensé',
                initialValue: _rules.pointsPerDinar.toString(),
                icon: Icons.attach_money,
                helperText: 'Ex: 0.1 = 1 point pour 10 dinars',
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Valeur invalide';
                  }
                  return null;
                },
                onSaved: (value) =>
                    _rules.pointsPerDinar = double.parse(value!),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              _buildInputField(
                label: 'Valeur d\'un point (en dinars)',
                initialValue: _rules.dinarPerPoint.toString(),
                icon: Icons.monetization_on,
                helperText: 'Ex: 1 = 1 point = 1 dinar de réduction',
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Valeur invalide';
                  }
                  return null;
                },
                onSaved: (value) => _rules.dinarPerPoint = double.parse(value!),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              _buildInputField(
                label: 'Points minimums pour utilisation',
                initialValue: _rules.minPointsToUse.toString(),
                icon: Icons.lock,
                helperText: 'Nombre de points minimums pour pouvoir utiliser',
                validator: (value) {
                  if (value == null || int.tryParse(value) == null) {
                    return 'Valeur invalide';
                  }
                  return null;
                },
                onSaved: (value) => _rules.minPointsToUse = int.parse(value!),
                keyboardType: TextInputType.number,
              ),
              _buildInputField(
                label: 'Pourcentage maximum payable avec points',
                initialValue: _rules.maxPercentageUse.toString(),
                icon: Icons.percent,
                helperText: 'Ex: 50 = maximum 50% du total en points',
                suffixText: '%',
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Valeur invalide';
                  }
                  final val = double.parse(value);
                  if (val < 0 || val > 100) return 'Entre 0 et 100';
                  return null;
                },
                onSaved: (value) =>
                    _rules.maxPercentageUse = double.parse(value!),
                keyboardType: TextInputType.number,
              ),
              _buildInputField(
                label: 'Validité des points (mois)',
                initialValue: _rules.pointsValidityMonths.toString(),
                icon: Icons.calendar_today,
                helperText: '0 = pas d\'expiration',
                suffixText: 'mois',
                validator: (value) {
                  if (value == null || int.tryParse(value) == null) {
                    return 'Valeur invalide';
                  }
                  return null;
                },
                onSaved: (value) =>
                    _rules.pointsValidityMonths = int.parse(value!),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveRules,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      tealGreen, // Changed from 'primary' to 'backgroundColor'
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, color: white),
                    SizedBox(width: 8),
                    Text(
                      'Enregistrer les règles',
                      style: TextStyle(
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
