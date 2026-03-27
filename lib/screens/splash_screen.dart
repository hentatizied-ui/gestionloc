import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final user = context.read<UserService>();
    if (user.isConfigured) {
      _goHome();
    } else {
      user.addListener(_onUserReady);
    }
  }

  void _onUserReady() {
    final user = context.read<UserService>();
    if (user.isReady) {
      user.removeListener(_onUserReady);
      if (user.isConfigured && mounted) {
        _goHome();
      }
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserService>();
    if (!user.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!user.isConfigured) {
      return const WelcomeScreen();
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ─── Écran de bienvenue ────────────────────────────────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                const Text('Bienvenue !', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Entrez votre nom pour commencer.', style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5)),
                const Spacer(),
                TextFormField(
                  controller: _prenom,
                  decoration: InputDecoration(
                    labelText: 'Prénom',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nom,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<UserService>().saveUser(_prenom.text.trim(), _nom.text.trim());
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }
}
