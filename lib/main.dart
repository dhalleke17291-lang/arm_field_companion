import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AgQuestApp(),
    ),
  );
}

class AgQuestApp extends StatelessWidget {
  const AgQuestApp({super.key});

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
    // Sophisticated sage green palette
    const primaryGreen = Color(0xFF2D5A40);
    const surfaceWarm = Color(0xFFF8F6F2);
    const surfaceCard = Color(0xFFFFFFFF);
    const onSurfaceWarm = Color(0xFF1C1C1E);
    const subtleGrey = Color(0xFF8A8A8E);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD4E8DC),
      onPrimaryContainer: primaryGreen,
      secondary: const Color(0xFF5C8A6A),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0EDE5),
      onSecondaryContainer: primaryGreen,
      tertiary: const Color(0xFF8A7A5C),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFEDE8DC),
      onTertiaryContainer: const Color(0xFF3C3020),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFF9DEDC),
      onErrorContainer: const Color(0xFF410E0B),
      surface: surfaceWarm,
      onSurface: onSurfaceWarm,
      surfaceContainerHighest: const Color(0xFFEEEBE6),
      outline: const Color(0xFFCCC8C0),
      outlineVariant: const Color(0xFFE5E2DC),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF313131),
      onInverseSurface: const Color(0xFFF4F0EB),
      inversePrimary: const Color(0xFF90C9A5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Scaffold background — warm off-white
      scaffoldBackgroundColor: surfaceWarm,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE8E4DE), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Chips
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

      // Input fields
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
        hintStyle: TextStyle(color: subtleGrey.withOpacity(0.7)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Elevated buttons
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

      // Filled buttons
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

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: StadiumBorder(),
      ),

      // List tiles
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

      // Tab bar
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

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E4DE),
        thickness: 1,
        space: 1,
      ),

      // Text theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: onSurfaceWarm,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: onSurfaceWarm,
        ),
        titleLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: onSurfaceWarm,
        ),
        titleMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurfaceWarm,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurfaceWarm,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: subtleGrey,
        ),
        labelLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
