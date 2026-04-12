import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../core/app_info.dart';
import '../../core/config/app_info.dart';
import '../../core/providers.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../users/user_selection_screen.dart';

/// Minimal About / App Info screen.
/// Shows current user and developer credit.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String developerCredit = 'Developed by Parminder Singh';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: const GradientScreenHeader(title: 'About'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppInfo.appName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Professional field trial data collection and execution platform',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Version $kAppVersion',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                developerCredit,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),
              userAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, __) => AppErrorHint(error: e),
                data: (user) {
                  if (user == null) {
                    return OutlinedButton.icon(
                      onPressed: () => _openUserSelection(context),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Select User'),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in as ${user.displayName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openUserSelection(context),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Change User'),
                      ),
                    ],
                  );
                },
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

  void _openUserSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const UserSelectionScreen(),
      ),
    );
  }
}
