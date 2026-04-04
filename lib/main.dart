import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/user_service.dart';
import 'services/sheets_service.dart';
import 'services/data_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const GestionLocativeApp());
}

class GestionLocativeApp extends StatelessWidget {
  const GestionLocativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserService()),
        ChangeNotifierProvider(create: (_) => SheetsService()),
        ChangeNotifierProxyProvider<SheetsService, DataService>(
          create: (_) => DataService(),
          update: (_, sheets, data) => data!..updateSheets(sheets),
        ),
      ],
      child: MaterialApp(
        title: 'Gestion Locative',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}

class AppTheme {
  static const Color primary = Color(0xFF1D9E75);
  static const Color primaryLight = Color(0xFFE1F5EE);
  static const Color primaryDark = Color(0xFF085041);
  static const Color warning = Color(0xFFEF9F27);
  static const Color danger = Color(0xFFE24B4A);
  static const Color blue = Color(0xFF378ADD);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
        ),
        color: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    const bg      = Color(0xFF121212);
    const surface = Color(0xFF1E1E1E);
    const surface2 = Color(0xFF2C2C2C);
    const border  = Color(0xFF3A3A3A);
    const textPrimary   = Color(0xFFEEEEEE);
    const textSecondary = Color(0xFFAAAAAA);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
      ),
      popupMenuTheme: const PopupMenuThemeData(color: surface2),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: textPrimary),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: textPrimary),
        bodyMedium:  TextStyle(color: textPrimary),
        bodySmall:   TextStyle(color: textSecondary),
        titleLarge:  TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall:  TextStyle(color: textSecondary),
        labelLarge:  TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.4) : border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surface2,
        labelStyle: TextStyle(color: textPrimary),
        side: BorderSide(color: border),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(surface2)),
      ),
    );
  }
}
