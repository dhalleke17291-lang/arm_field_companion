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

  /// Demo build expires after this date.
  static final DateTime expiryDate = DateTime(2026, 5, 13);

  static bool get isExpired => DateTime.now().isAfter(expiryDate);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agnexis',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: isExpired ? const _ExpiredScreen() : const SplashScreen(),
    );
  }

  static String get expiryLabel =>
      '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';

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
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          side: const BorderSide(color: Color(0xFFEAECF0), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEEBE6),
        selectedColor: const Color(0xFFD4E8DC),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurfaceWarm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
          borderSide: const BorderSide(color: Color(0xFFD8D4CE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
          borderSide: const BorderSide(color: Color(0xFFD8D4CE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurfaceWarm,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: subtleGrey,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: Color(0xFFEAECF0)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        dragHandleColor: AppDesignTokens.dragHandle,
        dragHandleSize: Size(48, 5),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: AppDesignTokens.headerTitleStyle(
          fontSize: 20,
          color: onSurfaceWarm,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: subtleGrey,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
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

class _ExpiredScreen extends StatelessWidget {
  const _ExpiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off_rounded, size: 64, color: Color(0xFF8A8A8E)),
              const SizedBox(height: 24),
              Text(
                'Demo Expired',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'This demo build expired on ${ArmFieldCompanionApp.expiryLabel}.\nPlease contact the developer for an updated build.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
