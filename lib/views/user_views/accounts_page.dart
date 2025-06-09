import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final SqlDb _sqlDb = SqlDb();
  List<User> _users = [];
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newCodeController = TextEditingController();
  final TextEditingController _confirmNewCodeController = TextEditingController();
  String _selectedRole = 'cashier';
  bool _isLoading = true;

  // Define the color palette
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
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await _sqlDb.getAllUsers();
    setState(() => _isLoading = false);
  }

  Future<void> _addUser() async {
    if (_usernameController.text.isEmpty || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
      );
      return;
    }

    try {
      final newUser = User(
        username: _usernameController.text,
        code: _codeController.text,
        role: _selectedRole,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
      );
      await _sqlDb.addUser(newUser);
      _usernameController.clear();
      _codeController.clear();
      _emailController.clear();
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Utilisateur ajouté avec succès'),
          backgroundColor: tealGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: warmRed,
        ),
      );
    }
  }

  Future<void> _showResetCodeDialog(User user) async {
    _newCodeController.clear();
    _confirmNewCodeController.clear();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Réinitialiser le code pour ${user.username}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newCodeController,
                decoration: InputDecoration(
                  labelText: 'Nouveau code',
                  labelStyle: TextStyle(color: darkBlue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: deepBlue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: deepBlue, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock, color: deepBlue),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmNewCodeController,
                decoration: InputDecoration(
                  labelText: 'Confirmer le nouveau code',
                  labelStyle: TextStyle(color: darkBlue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: deepBlue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: deepBlue, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: deepBlue),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(color: warmRed),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newCodeController.text.isEmpty ||
                    _confirmNewCodeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Veuillez remplir tous les champs')),
                  );
                  return;
                }

                if (_newCodeController.text != _confirmNewCodeController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Les codes ne correspondent pas')),
                  );
                  return;
                }

                try {
                  await _sqlDb.updateUserCode(
                      user.username, _newCodeController.text);
                  await _loadUsers();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Code mis à jour avec succès'),
                      backgroundColor: tealGreen,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: warmRed,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tealGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Valider',
                style: GoogleFonts.poppins(
                  color: white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser(int userId) async {
    try {
      await _sqlDb.deleteUser(userId);
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Utilisateur supprimé avec succès'),
          backgroundColor: tealGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: warmRed,
        ),
      );
    }
  }

  Future<File> _generatePdfReport() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0, 
                child: pw.Text(
                  'Rapport des Utilisateurs', 
                  style: pw.TextStyle(fontSize: 24)
                )
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: [
                  ['ID', 'Nom', 'Rôle', 'Email', 'Statut'],
                  ..._users.map((user) => [
                    user.id.toString(),
                    user.username,
                    user.role == 'admin' ? 'Administrateur' : 'Caissier',
                    user.email ?? 'N/A',
                    user.isActive ? 'Actif' : 'Inactif'
                  ]).toList()
                ],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
                cellStyle: const pw.TextStyle(),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Généré le ${DateTime.now().toLocal()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/user_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _sendReportToAdmins() async {
    try {
      setState(() => _isLoading = true);
      
      final adminUsers = _users.where((user) => 
        user.role == 'admin' && 
        user.email != null && 
        user.email!.isNotEmpty
      ).toList();
      
      if (adminUsers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aucun administrateur avec email valide trouvé'),
            backgroundColor: warmRed,
          ),
        );
        return;
      }

      final pdfFile = await _generatePdfReport();

      // Configure your SMTP server here
      final smtpServer = gmail('your.email@gmail.com', 'yourpassword');
      // For production, use environment variables or OAuth2

      final message = Message()
        ..from = Address('your.email@gmail.com', 'Caisse Chicopets')
        ..subject = 'Rapport des Utilisateurs - ${DateTime.now().toLocal().toString().substring(0, 10)}'
        ..text = '''
            Bonjour,

Veuillez trouver ci-joint le rapport des utilisateurs actuel.

Nombre total d'utilisateurs: ${_users.length}
Nombre d'administrateurs: ${_users.where((u) => u.role == 'admin').length}
Nombre de caissiers: ${_users.where((u) => u.role == 'cashier').length}

Cordialement,
L'équipe Caisse Chicopets
'''
        ..attachments = [FileAttachment(pdfFile)]
        ..recipients.addAll(adminUsers.map((user) => user.email!));

      await send(message, smtpServer);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rapport envoyé à ${adminUsers.length} administrateur(s)'),
          backgroundColor: tealGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } on MailerException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'envoi: ${e.message}'),
          backgroundColor: warmRed,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: warmRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _newCodeController.dispose();
    _confirmNewCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestion des Comptes',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: darkBlue,
        elevation: 10,
        iconTheme: IconThemeData(color: white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: white),
            onPressed: _loadUsers,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: Icon(Icons.email, color: white),
            onPressed: _sendReportToAdmins,
            tooltip: 'Envoyer le rapport aux admins',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightGray.withOpacity(0.9), white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_add, color: deepBlue, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Ajouter un Utilisateur',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nom d\'utilisateur',
                          labelStyle: TextStyle(color: darkBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue, width: 2),
                          ),
                          prefixIcon: Icon(Icons.person, color: deepBlue),
                          filled: true,
                          fillColor: lightGray.withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: 'Code d\'accès',
                          labelStyle: TextStyle(color: darkBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue, width: 2),
                          ),
                          prefixIcon: Icon(Icons.lock, color: deepBlue),
                          filled: true,
                          fillColor: lightGray.withOpacity(0.3),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email (optionnel)',
                          labelStyle: TextStyle(color: darkBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue, width: 2),
                          ),
                          prefixIcon: Icon(Icons.email, color: deepBlue),
                          filled: true,
                          fillColor: lightGray.withOpacity(0.3),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings,
                                    color: deepBlue),
                                const SizedBox(width: 10),
                                Text(
                                  'Administrateur',
                                  style: GoogleFonts.poppins(color: darkBlue),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'cashier',
                            child: Row(
                              children: [
                                Icon(Icons.point_of_sale, color: deepBlue),
                                const SizedBox(width: 10),
                                Text(
                                  'Caissier',
                                  style: GoogleFonts.poppins(color: darkBlue),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Rôle',
                          labelStyle: TextStyle(color: darkBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: deepBlue, width: 2),
                          ),
                          prefixIcon:
                              Icon(Icons.assignment_ind, color: deepBlue),
                          filled: true,
                          fillColor: lightGray.withOpacity(0.3),
                        ),
                        dropdownColor: white,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: IntrinsicWidth(
                          child: ElevatedButton(
                            onPressed: _addUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tealGreen,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: tealGreen.withOpacity(0.4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: white),
                                const SizedBox(width: 10),
                                Text(
                                  'Ajouter Utilisateur',
                                  style: GoogleFonts.poppins(
                                    color: white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Liste des Utilisateurs',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: deepBlue,
                          strokeWidth: 3,
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 60,
                                  color: lightGray,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun utilisateur trouvé',
                                  style: GoogleFonts.poppins(
                                    color: darkBlue.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: white,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: user.role == 'admin'
                                        ? deepBlue.withOpacity(0.2)
                                        : tealGreen.withOpacity(0.2),
                                    child: Icon(
                                      user.role == 'admin'
                                          ? Icons.admin_panel_settings
                                          : Icons.point_of_sale,
                                      color: user.role == 'admin'
                                          ? deepBlue
                                          : tealGreen,
                                    ),
                                  ),
                                  title: Text(
                                    user.username,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: darkBlue,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rôle: ${user.role == 'admin' ? 'Administrateur' : 'Caissier'}',
                                        style: GoogleFonts.poppins(
                                          color: darkBlue.withOpacity(0.7),
                                        ),
                                      ),
                                      if (user.email != null && user.email!.isNotEmpty)
                                        Text(
                                          'Email: ${user.email}',
                                          style: GoogleFonts.poppins(
                                            color: darkBlue.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.vpn_key,
                                            color: tealGreen),
                                        onPressed: () =>
                                            _showResetCodeDialog(user),
                                        tooltip: 'Réinitialiser le code',
                                      ),
                                      IconButton(
                                        icon:
                                            Icon(Icons.delete, color: warmRed),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                title: Text(
                                                  'Confirmer la suppression',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    color: darkBlue,
                                                  ),
                                                ),
                                                content: Text(
                                                  'Voulez-vous vraiment supprimer l\'utilisateur ${user.username} ?',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                    child: Text(
                                                      'Annuler',
                                                      style: TextStyle(
                                                          color: darkBlue),
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                      _deleteUser(user.id!);
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: warmRed,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Supprimer',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        tooltip: 'Supprimer l\'utilisateur',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}