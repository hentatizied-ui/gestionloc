import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/data_service.dart';
import '../main.dart' show AppTheme;
import 'dashboard_screen.dart';
import 'biens_screen.dart';
import 'locataires_screen.dart';
import 'finances_screen.dart';
import 'compta_screen.dart';
import 'simulation_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(), BiensScreen(), LocatairesScreen(),
    FinancesScreen(), ComptaScreen(), SimulationScreen(),
  ];

  static const _titles = [
    'Tableau de bord', 'Mes Biens', 'Locataires',
    'Finances', 'Comptabilité', 'Simulation',
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.home_work_outlined),
      selectedIcon: Icon(Icons.home_work_rounded),
      label: 'Biens',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: 'Locataires',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
      label: 'Finances',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics_rounded),
      label: 'Compta',
    ),
    NavigationDestination(
      icon: Icon(Icons.calculate_outlined),
      selectedIcon: Icon(Icons.calculate_rounded),
      label: 'Simulation',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final user = context.watch<UserService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          // Sync loading indicator
          if (data.loading)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),

          // User avatar menu
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: _UserAvatar(initiales: user.initiales),
              itemBuilder: (_) => <PopupMenuEntry>[
                PopupMenuItem(
                  value: 'name',
                  enabled: false,
                  child: _MenuHeader(name: user.displayName),
                ),
                const PopupMenuDivider(height: 1),
                _menuItem(Icons.sync_rounded, 'Synchroniser', 'refresh'),
                const PopupMenuDivider(height: 1),
                _menuItem(Icons.logout_rounded, 'Changer d\'utilisateur', 'logout',
                    color: AppTheme.danger),
              ],
              onSelected: (v) async {
                if (v == 'refresh') {
                  context.read<DataService>().loadAll();
                } else if (v == 'logout') {
                  await context.read<UserService>().clearUser();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),

      body: IndexedStack(index: _currentIndex, children: _screens),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                ? const Color(0xFF2E3347)
                : const Color(0xFFE5E7EB),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: _destinations,
        ),
      ),
    );
  }

  PopupMenuItem _menuItem(IconData icon, String label, String value, {Color? color}) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ]),
    );
  }
}

// ── User avatar ──────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final String initiales;
  const _UserAvatar({required this.initiales});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D9E75), Color(0xFF16C181)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initiales.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Menu header ──────────────────────────────────────────────────────────────

class _MenuHeader extends StatelessWidget {
  final String name;
  const _MenuHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.person_rounded, size: 16, color: AppTheme.primary),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
        Text('Connecté', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    ]);
  }
}
