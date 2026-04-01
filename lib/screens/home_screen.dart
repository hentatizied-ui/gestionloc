import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../services/data_service.dart';
import 'dashboard_screen.dart';
import 'biens_screen.dart';
import 'locataires_screen.dart';
import 'finances_screen.dart';
import 'compta_screen.dart';
import 'simulation_screen.dart';
import 'splash_screen.dart';
import 'settings_screen.dart';

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

  final List<String> _titles = ['Tableau de bord', 'Mes Biens', 'Locataires', 'Finances', 'Comptabilité', 'Simulation'];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final user = context.watch<UserService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (data.loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: const Color(0xFFB5D4F4),
              radius: 16,
              child: Text(user.initiales, style: const TextStyle(fontSize: 11, color: Color(0xFF042C53), fontWeight: FontWeight.w500)),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'name', child: Row(children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Text(user.displayName),
              ])),
              const PopupMenuItem(value: 'refresh', child: Row(children: [
                Icon(Icons.sync, size: 18), SizedBox(width: 8), Text('Synchroniser'),
              ])),
              const PopupMenuItem(value: 'settings', child: Row(children: [
                Icon(Icons.settings, size: 18), SizedBox(width: 8), Text('Paramètres'),
              ])),
              const PopupMenuItem(value: 'logout', child: Row(children: [
                Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Changer d\'utilisateur'),
              ])),
            ],
            onSelected: (v) async {
              if (v == 'refresh') {
                context.read<DataService>().loadAll();
              } else if (v == 'settings') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (v == 'logout') {
                await context.read<UserService>().clearUser();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5))),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), label: 'Biens'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Locataires'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Finances'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Compta'),
            BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), label: 'Simulation'),
          ],
        ),
      ),
    );
  }
}
