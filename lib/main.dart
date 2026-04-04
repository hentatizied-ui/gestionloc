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
  static const Color primary      = Color(0xFF1D9E75);
  static const Color primaryLight = Color(0xFFE1F5EE);
  static const Color primaryDark  = Color(0xFF085041);
  static const Color warning      = Color(0xFFEF9F27);
  static const Color danger       = Color(0xFFE24B4A);
  static const Color blue         = Color(0xFF378ADD);

  // ── Shared button style helper ────────────────────────────────────────────
  static ButtonStyle _btn(Color? bg, Color? fg) => ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
    backgroundColor: bg != null ? WidgetStatePropertyAll(bg) : null,
    foregroundColor: fg != null ? WidgetStatePropertyAll(fg) : null,
    elevation: const WidgetStatePropertyAll(0),
    overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) ? Colors.black.withValues(alpha: 0.06) : null),
  );

  static ThemeData light() {
    const scaffold = Color(0xFFF2F4F7);
    const cardBg   = Colors.white;
    const txtMain  = Color(0xFF111827);
    const txtSub   = Color(0xFF6B7280);
    const brd      = Color(0xFFE5E7EB);
    const inputFill = Color(0xFFF9FAFB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
      scaffoldBackgroundColor: scaffold,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x14000000),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: txtMain, letterSpacing: -0.3),
        iconTheme: IconThemeData(color: txtMain, size: 22),
        actionsIconTheme: IconThemeData(color: txtMain, size: 22),
        centerTitle: false,
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: brd, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: danger, width: 1.5)),
        labelStyle: const TextStyle(fontSize: 14, color: txtSub),
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB0B7C3)),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) ? primary : txtSub,
        ),
        suffixIconColor: txtSub,
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(style: _btn(null, null)),
      filledButtonTheme:   FilledButtonThemeData(style: _btn(primary, Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _btn(null, null).copyWith(
          side: const WidgetStatePropertyAll(BorderSide(color: brd, width: 1.2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        extendedPadding: EdgeInsets.symmetric(horizontal: 20),
        extendedTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),

      // ── NavigationBar (Material 3) ────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x14000000),
        indicatorColor: primary.withValues(alpha: 0.12),
        indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
            ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 0.1)
            : const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF9CA3AF))),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
            ? const IconThemeData(color: primary, size: 22)
            : const IconThemeData(color: Color(0xFF9CA3AF), size: 22)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── BottomNavBar legacy (fallback) ────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: const StadiumBorder(),
        side: const BorderSide(color: brd),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        backgroundColor: cardBg,
        selectedColor: primary.withValues(alpha: 0.12),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: brd, thickness: 1, space: 1),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: txtMain),
        contentTextStyle: const TextStyle(fontSize: 14, color: txtSub, height: 1.5),
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        modalBackgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        showDragHandle: false,
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── PopupMenu ────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        textStyle: const TextStyle(fontSize: 14, color: txtMain),
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, color: txtMain)),
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 0,
        iconColor: txtSub,
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.5) : brd,
        ),
      ),
    );
  }

  static ThemeData dark() {
    const bg       = Color(0xFF0F1117);
    const surface  = Color(0xFF1A1D27);
    const surface2 = Color(0xFF242836);
    const surface3 = Color(0xFF2E3347);
    const border   = Color(0xFF2E3347);
    const txtMain  = Color(0xFFF1F5F9);
    const txtSub   = Color(0xFF94A3B8);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
      scaffoldBackgroundColor: bg,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x28000000),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: txtMain, letterSpacing: -0.3),
        iconTheme: IconThemeData(color: txtMain, size: 22),
        actionsIconTheme: IconThemeData(color: txtMain, size: 22),
        centerTitle: false,
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: danger, width: 1.5)),
        labelStyle: const TextStyle(fontSize: 14, color: txtSub),
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) ? primary : txtSub,
        ),
        suffixIconColor: txtSub,
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(style: _btn(surface3, txtMain)),
      filledButtonTheme:   FilledButtonThemeData(style: _btn(primary, Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _btn(null, txtMain).copyWith(
          side: const WidgetStatePropertyAll(BorderSide(color: border, width: 1.2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          foregroundColor: const WidgetStatePropertyAll(primary),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        extendedPadding: EdgeInsets.symmetric(horizontal: 20),
        extendedTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),

      // ── NavigationBar ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.18),
        indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
            ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary)
            : const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: txtSub)),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
            ? const IconThemeData(color: primary, size: 22)
            : const IconThemeData(color: txtSub, size: 22)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── BottomNavBar legacy ────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: const ChipThemeData(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: StadiumBorder(),
        backgroundColor: surface2,
        labelStyle: TextStyle(color: txtMain, fontSize: 12, fontWeight: FontWeight.w500),
        side: BorderSide(color: border),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: txtMain),
        contentTextStyle: TextStyle(fontSize: 14, color: txtSub, height: 1.5),
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: const TextStyle(color: txtMain, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── PopupMenu ────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, color: txtMain)),
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        textColor: txtMain,
        iconColor: txtSub,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 0,
      ),

      // ── Text ─────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: txtMain),
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: txtMain),
        bodyMedium:  TextStyle(color: txtMain),
        bodySmall:   TextStyle(color: txtSub),
        titleLarge:  TextStyle(color: txtMain),
        titleMedium: TextStyle(color: txtMain),
        titleSmall:  TextStyle(color: txtSub),
        labelLarge:  TextStyle(color: txtMain),
        labelMedium: TextStyle(color: txtSub),
      ),

      // ── Switch / Checkbox ─────────────────────────────────────────────────
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
        side: const BorderSide(color: border, width: 1.5),
      ),

      // ── Dropdown ─────────────────────────────────────────────────────────
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(surface2)),
      ),
    );
  }
}
