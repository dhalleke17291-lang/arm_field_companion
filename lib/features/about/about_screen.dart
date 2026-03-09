import 'package:flutter/material.dart';
import '../../core/app_info.dart';
import '../diagnostics/diagnostics_screen.dart';

/// Minimal About / App Info screen.
/// Developer credit lives here only — not on splash.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appName = 'Ag-Quest Field Companion';
  static const String developerCredit = 'Developed by Parminder Singh';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version $kAppVersion',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                developerCredit,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Diagnostics'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
