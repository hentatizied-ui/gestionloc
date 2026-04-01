import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../config/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _secretController = TextEditingController();
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec le secret actuel si disponible
    try {
      _secretController.text = AppConfig.sheetsSecret;
    } catch (e) {
      // Pas de secret configuré, c'est normal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration Google Sheets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entrez le secret de votre Google Apps Script pour connecter l\'application à vos feuilles Google.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretController,
              decoration: InputDecoration(
                labelText: 'Secret Sheets',
                border: const OutlineInputBorder(),
                helperText: 'Ex: AKfycb...',
                errorText: _message,
                prefixIcon: const Icon(Icons.key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer et recharger'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Comment obtenir le secret ?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const _HelpStep(
              number: 1,
              text: 'Créez un Google Apps Script qui expose votre Google Sheet',
            ),
            const _HelpStep(
              number: 2,
              text: 'Déployez-le en tant qu\'application web',
            ),
            const _HelpStep(
              number: 3,
              text: 'Copiez le script ID depuis l\'URL',
            ),
            const _HelpStep(
              number: 4,
              text: 'Le secret est le script ID (ou une clé API configurée)',
            ),
            const Spacer(),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Après avoir sauvegardé le secret, l\'application va automatiquement recharger les données.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
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

  Future<void> _save() async {
    if (_secretController.text.trim().isEmpty) {
      setState(() {
        _message = 'Le secret ne peut être vide';
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      // Sauvegarder le secret dans la configuration
      AppConfig.sheetsSecret = _secretController.text.trim();

      // Recharger les données
      await context.read<DataService>().loadAll();

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret enregistré et données rechargées !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = 'Erreur: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }
}

class _HelpStep extends StatelessWidget {
  final int number;
  final String text;

  const _HelpStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
