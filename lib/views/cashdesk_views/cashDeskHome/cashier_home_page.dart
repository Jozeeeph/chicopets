import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/views/user_views/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/services/cash_service.dart';
import 'package:caissechicopets/models/cash_state.dart';
import 'package:caissechicopets/views/cashdesk_views/placeOrder/cash_desk_page.dart';
import 'package:caissechicopets/views/cashdesk_views/cashDeskHome/cash_closure_report_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:caissechicopets/views/home_views/home_page.dart'; // Adaptez le chemin selon votre structure

class CashierHomePage extends StatefulWidget {
  const CashierHomePage({super.key});

  @override
  _CashierHomePageState createState() => _CashierHomePageState();
}

class _CashierHomePageState extends State<CashierHomePage>
    with SingleTickerProviderStateMixin {
  final CashService _cashService = CashService();
  CashState? _cashState;
  bool _isLoading = true;
  bool _needsInitialAmount = false;
  final TextEditingController _amountController = TextEditingController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkCashState();
  }

  Future<void> _checkCashState() async {
    final state = await _cashService.getCashState();
    setState(() {
      _cashState = state;
      _needsInitialAmount = state == null || state.isClosed;
      _isLoading = false;
    });
  }

  Future<void> _submitInitialAmount() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez saisir un montant valide'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    await _cashService.saveCashState(CashState(
      initialAmount: amount,
      openingTime: DateTime.now(),
      isClosed: false,
    ));

    setState(() {
      _needsInitialAmount = false;
      _cashState = CashState(
        initialAmount: amount,
        openingTime: DateTime.now(),
        isClosed: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        title: Text('Partie Caissier',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF0056A6),
        elevation: 10,
        shadowColor: Colors.blue.withOpacity(0.5),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_needsInitialAmount) _buildInitialAmountCard(),
                  SizedBox(height: 30),
                  _buildActionCards(),
                  SizedBox(height: 30),
                  _buildCashStatusCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAmountCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF26A9E0), Color(0xFF0056A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 30),
                SizedBox(width: 10),
                Text(
                  'Fond de caisse initial',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                labelText: 'Montant',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.euro, color: Colors.white),
                suffixIcon: IconButton(
                  icon: Icon(Icons.help_outline, color: Colors.white70),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Aide'),
                        content: Text(
                            'Saisissez le montant initial disponible dans la caisse.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitInitialAmount,
              icon: Icon(Icons.check_circle_outline),
              label: Text('Valider'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.6, // Même largeur relative
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 12, // Même espacement
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, // Même ratio
        children: [
          _buildActionCard(
            title: 'Passage\nde commande', // Saut de ligne comme dans home_page
            icon: Icons.shopping_cart,
            color: Color(0xFF4CAF50),
            onTap: _needsInitialAmount
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => CashDeskPage()),
                    );
                  },
          ),
          _buildActionCard(
            title: 'Clôturer\nla caisse', // Saut de ligne comme dans home_page
            icon: Icons.lock_clock,
            color: Colors.redAccent,
            onTap: _needsInitialAmount ? null : _closeCashRegister,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color, // Couleur unie ici
            borderRadius: BorderRadius.circular(50),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (onTap == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '(Fond initial requis)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashStatusCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF26A9E0), Color(0xFF0056A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'État de la caisse',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white70),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Statut:', style: TextStyle(color: Colors.white)),
                Chip(
                  label: Text(
                    _cashState == null || _cashState!.isClosed
                        ? 'Fermée'
                        : 'Ouverte',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _cashState == null || _cashState!.isClosed
                      ? Colors.red
                      : Colors.green,
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_cashState != null && !_cashState!.isClosed) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fond initial:', style: TextStyle(color: Colors.white)),
                  Text(
                    '${_cashState!.initialAmount.toStringAsFixed(2)} DT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ouverte depuis:',
                      style: TextStyle(color: Colors.white)),
                  Text(
                    DateFormat('HH:mm').format(_cashState!.openingTime!),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _closeCashRegister() async {
    final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirmer la clôture'),
            content: Text('Voulez-vous vraiment clôturer la caisse ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  // Create an instance and call printReport()
                  final reportPage = CashClosureReportPage(
                    cashState: _cashState ??
                        CashState(initialAmount: 0, isClosed: true),
                  );
                  reportPage.printReport(context);
                  _logout();
                },
                child: Text('Confirmer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldClose) {
      await _cashService.saveCashState(CashState(
        initialAmount: _cashState?.initialAmount ?? 0,
        openingTime: _cashState?.openingTime,
        closingTime: DateTime.now(),
        isClosed: true,
      ));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CashClosureReportPage(
            cashState:
                _cashState ?? CashState(initialAmount: 0, isClosed: true),
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (mounted) {
      setState(() {
        _currentUser = null;
      });
    }
  }
}
