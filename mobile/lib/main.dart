import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BazaarChecklistApp());
}

class BazaarChecklistApp extends StatelessWidget {
  const BazaarChecklistApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Bazaar-inspired palette: deep near-black surfaces + warm gold accents.
    const background = Color(0xFF120A0B);
    const surface = Color(0xFF1B1112);
    const surfaceAlt = Color(0xFF241516);
    const accent = Color(0xFFF0A223);
    const accentSoft = Color(0xFFE2B569);
    const muted = Color(0xFFC3B5A0);

    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'BazaarChecklist',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accentSoft,
          surface: surface,
          onPrimary: Color(0xFF1A1106),
          onSecondary: Color(0xFF1A1106),
          onSurface: Color(0xFFF5E9D8),
        ),
        scaffoldBackgroundColor: background,
        canvasColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: Color(0xFFF5E9D8),
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surfaceAlt,
          indicatorColor: const Color(0xCCF0A223),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF1A1106)
                  : const Color(0xFFD7C7B0),
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFFF5E9D8)
                  : const Color(0xFFD7C7B0),
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : null,
            ),
          ),
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: const Color(0xFFF5E9D8),
          displayColor: const Color(0xFFF5E9D8),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF5B3A1F)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF62401F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF62401F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.2),
          ),
          hintStyle: const TextStyle(color: muted),
          labelStyle: const TextStyle(color: Color(0xFFEED9BA)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: const Color(0xFF2A1807),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: const Color(0xFFF5E9D8),
            side: const BorderSide(color: Color(0xFF7E5328)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accentSoft),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
