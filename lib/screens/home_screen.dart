import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'dashboard_screen.dart';
import 'biens_screen.dart';
import 'locataires_screen.dart';
import 'finances_screen.dart';
import 'maintenance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BiensScreen(),
    LocatairesScreen(),
    FinancesScreen(),
    MaintenanceScreen(),
  ];

  final List<String> _titles = [
    'Tableau de bord',
    'Mes Biens',
    'Locataires',
    'Finances',
    'Maintenance',
  ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
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
            icon: const CircleAvatar(
              backgroundColor: Color(0xFFB5D4F4),
              radius: 16,
              child: Text('SB', style: TextStyle(fontSize: 11, color: Color(0xFF042C53), fontWeight: FontWeight.w500)),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.sync, size: 18), SizedBox(width: 8), Text('Synchroniser')])),
              const PopupMenuItem(value: 'signout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Déconnexion')])),
            ],
            onSelected: (v) async {
              if (v == 'refresh') {
                context.read<DataService>().loadAll();
              } else if (v == 'signout') {
                await context.read<AuthService>().signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), label: 'Biens'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Locataires'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Finances'),
            BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: 'Travaux'),
          ],
        ),
      ),
    );
  }
}
