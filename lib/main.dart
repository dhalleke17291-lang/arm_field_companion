import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/design/app_design_tokens.dart';
import 'core/diagnostics/diagnostics_store.dart';
import 'core/providers.dart';
import 'splash_screen.dart';

void main() {
  final diagnosticsStore = DiagnosticsStore(maxErrors: 50);

  FlutterError.onError = (FlutterErrorDetails details) {
    diagnosticsStore.recordError(
      details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
      code: 'flutter_error',
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    diagnosticsStore.recordError(
      error.toString(),
      stackTrace: stackTrace.toString(),
      code: 'zone_error',
    );
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [
        diagnosticsStoreProvider.overrideWithValue(diagnosticsStore),
      ],
      child: const ArmFieldCompanionApp(),
    ),
  );
}

class ArmFieldCompanionApp extends StatelessWidget {
  const ArmFieldCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ag-Quest Field Companion',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    const primaryGreen = Color(0xFF2D5A40);
    const surfaceWarm = Color(0xFFF8F6F2);
    const surfaceCard = Color(0xFFFFFFFF);
    const onSurfaceWarm = Color(0xFF1C1C1E);
    const subtleGrey = Color(0xFF8A8A8E);

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD4E8DC),
      onPrimaryContainer: primaryGreen,
      secondary: Color(0xFF5C8A6A),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE0EDE5),
      onSecondaryContainer: primaryGreen,
      tertiary: Color(0xFF8A7A5C),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEDE8DC),
      onTertiaryContainer: Color(0xFF3C3020),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: surfaceWarm,
      onSurface: onSurfaceWarm,
      surfaceContainerHighest: Color(0xFFEEEBE6),
      outline: Color(0xFFCCC8C0),
      outlineVariant: Color(0xFFE5E2DC),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF313131),
      onInverseSurface: Color(0xFFF4F0EB),
      inversePrimary: Color(0xFF90C9A5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceWarm,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppDesignTokens.headerTitleStyle(
          fontSize: 22,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEAECF0), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEEBE6),
        selectedColor: const Color(0xFFD4E8DC),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurfaceWarm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD8D4CE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD8D4CE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: const TextStyle(color: subtleGrey),
        hintStyle: TextStyle(color: subtleGrey.withValues(alpha: 0.7)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: StadiumBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: onSurfaceWarm,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: subtleGrey,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E4DE),
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: onSurfaceWarm,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: onSurfaceWarm,
          letterSpacing: -0.25,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: onSurfaceWarm,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurfaceWarm,
          letterSpacing: 0,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurfaceWarm,
          letterSpacing: 0.15,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: subtleGrey,
          letterSpacing: 0.15,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}