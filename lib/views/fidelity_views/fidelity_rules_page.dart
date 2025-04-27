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

  // Variables pour la simulation
  double _exampleAmount = 100.0;
  int _examplePoints = 500;

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

  // Recharger les règles après enregistrement
  await _loadRules();

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

  Widget _buildExplanationCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      color: lightGray.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tealGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: darkBlue.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Function(double) onChanged,
    Color? activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: (max - min).toInt(),
                label: '${value.toStringAsFixed(unit == 'DT' ? 2 : 0)} $unit',
                activeColor: activeColor ?? tealGreen,
                inactiveColor: lightGray,
                onChanged: onChanged,
              ),
            ),
            SizedBox(width: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tealGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.toStringAsFixed(unit == 'DT' ? 2 : 0)} $unit',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimulationResultItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tealGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tealGreen),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: darkBlue,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simulation en direct',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            SizedBox(height: 16),
            _buildSimulationSlider(
              label: 'Montant de l\'achat',
              value: _exampleAmount,
              min: 10,
              max: 500,
              unit: 'DT',
              onChanged: (value) => setState(() => _exampleAmount = value),
              activeColor: deepBlue,
            ),
            _buildSimulationSlider(
              label: 'Points disponibles',
              value: _examplePoints.toDouble(),
              min: 0,
              max: 1000,
              unit: 'pts',
              onChanged: (value) => setState(() => _examplePoints = value.toInt()),
            ),
            Divider(height: 24, thickness: 1),
            Text(
              'Résultats de la simulation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            SizedBox(height: 12),
            _buildSimulationResultItem(
              'Points gagnés avec cet achat',
              '${(_exampleAmount * _rules.pointsPerDinar).toStringAsFixed(1)} pts',
              Icons.add_circle_outline,
            ),
            _buildSimulationResultItem(
              'Valeur totale des points',
              '${(_examplePoints * _rules.dinarPerPoint).toStringAsFixed(2)} DT',
              Icons.credit_card,
            ),
            _buildSimulationResultItem(
              'Points utilisables',
              _calculateUsage(_exampleAmount, _examplePoints),
              Icons.check_circle_outline,
            ),
            _buildSimulationResultItem(
              'Points restants après utilisation',
              _calculateRemainingPoints(_exampleAmount, _examplePoints),
              Icons.history,
            ),
          ],
        ),
      ),
    );
  }

  String _calculateUsage(double amount, int points) {
    double maxPointsValue = amount * (_rules.maxPercentageUse / 100);
    double pointsValue = points * _rules.dinarPerPoint;
    
    if (points < _rules.minPointsToUse) {
      return '${_rules.minPointsToUse} pts requis';
    }
    
    double usableValue = pointsValue > maxPointsValue ? maxPointsValue : pointsValue;
    return '${usableValue.toStringAsFixed(2)} DT';
  }

  String _calculateRemainingPoints(double amount, int points) {
    if (points < _rules.minPointsToUse) {
      return '$points pts (non utilisés)';
    }
    
    double maxPointsValue = amount * (_rules.maxPercentageUse / 100);
    double pointsValue = points * _rules.dinarPerPoint;
    
    if (pointsValue <= maxPointsValue) {
      return '0 pt';
    } else {
      int remaining = points - (maxPointsValue / _rules.dinarPerPoint).round();
      return '$remaining pts';
    }
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Partie gauche - Formulaire
            Expanded(
              flex: 1,
              child: Padding(
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
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
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
                        onSaved: (value) =>
                            _rules.dinarPerPoint = double.parse(value!),
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                      ),
                      _buildInputField(
                        label: 'Points minimums pour utilisation',
                        initialValue: _rules.minPointsToUse.toString(),
                        icon: Icons.lock,
                        helperText:
                            'Nombre de points minimums pour pouvoir utiliser',
                        validator: (value) {
                          if (value == null || int.tryParse(value) == null) {
                            return 'Valeur invalide';
                          }
                          return null;
                        },
                        onSaved: (value) =>
                            _rules.minPointsToUse = int.parse(value!),
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
                          backgroundColor: tealGreen,
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
            ),

            // Diviseur vertical
            Container(
              width: 1,
              margin: EdgeInsets.symmetric(vertical: 16),
              color: lightGray.withOpacity(0.5),
            ),

            // Partie droite - Simulation et explications
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _buildSimulationCard(),
                    SizedBox(height: 24),
                    Text(
                      'Explications des règles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildExplanationCard(
                      title: 'Points par dinar dépensé',
                      description:
                          'Détermine combien de points le client gagne pour chaque dinar dépensé. Ex: 0.1 = 1 point pour 10 dinars.',
                      icon: Icons.attach_money,
                    ),
                    _buildExplanationCard(
                      title: 'Valeur d\'un point',
                      description:
                          'Valeur en dinars d\'un point lors de son utilisation. Ex: 1 = 1 point = 1 dinar de réduction.',
                      icon: Icons.monetization_on,
                    ),
                    _buildExplanationCard(
                      title: 'Points minimums',
                      description:
                          'Points minimums requis avant utilisation. Le client ne peut pas utiliser ses points s\'il n\'atteint pas ce minimum.',
                      icon: Icons.lock,
                    ),
                    _buildExplanationCard(
                      title: 'Pourcentage maximum',
                      description:
                          'Pourcentage maximum du total payable avec points. Ex: 50% = maximum la moitié de la facture avec points.',
                      icon: Icons.percent,
                    ),
                    _buildExplanationCard(
                      title: 'Validité des points',
                      description:
                          'Durée en mois avant expiration des points. 0 = pas d\'expiration. Premier entré, premier sorti.',
                      icon: Icons.calendar_today,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}