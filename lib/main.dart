import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ArmFieldCompanionApp(),
    ),
  );
}

class ArmFieldCompanionApp extends StatelessWidget {
  const ArmFieldCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARM Field Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
