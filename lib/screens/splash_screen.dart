import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
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
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final auth = context.read<AuthService>();
    if (auth.isSignedIn) {
      _goHome();
    } else {
      // Attendre que le service finisse de vérifier la session silencieuse
      auth.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    final auth = context.read<AuthService>();
    if (!auth.isLoading) {
      auth.removeListener(_onAuthChanged);
      if (auth.isSignedIn && mounted) _goHome();
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
    final auth = context.watch<AuthService>();
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const LoginScreen();
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Gestion Locative',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Gérez vos biens, locataires et finances\nen toute simplicité.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
              ),
              const Spacer(),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Bouton Google
              ElevatedButton.icon(
                onPressed: auth.isLoading ? null : () async {
                  final ok = await auth.signIn();
                  if (ok && context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
                },
                icon: auth.isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 18, height: 18,
                        errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 18),
                      ),
                label: Text(
                  auth.isLoading ? 'Connexion…' : 'Continuer avec Google',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vos données sont stockées dans votre Google Drive personnel.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
