import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../core/config/app_info.dart';
import '../../core/providers.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../users/user_selection_screen.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  String _deviceInfo() {
    final parts = <String>[];
    parts.add('${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    if (Platform.isAndroid || Platform.isIOS) {
      parts.add(Platform.localHostname);
    }
    return parts.join(' · ');
  }

  Future<void> _shareDeviceInfo() async {
    final db = ref.read(databaseProvider);
    final schema = db.schemaVersion;
    final pkg = _packageInfo;
    final user = await ref.read(currentUserProvider.future);

    final text = StringBuffer()
      ..writeln('${AppInfo.appName} Device Report')
      ..writeln(
          'Version: ${pkg?.version ?? '?'} (build ${pkg?.buildNumber ?? '?'})');
    if (AppInfo.hasBuildMetadata) {
      text.writeln('Build: ${AppInfo.buildIdentity}');
    }
    text
      ..writeln('Schema: v$schema')
      ..writeln('Platform: ${_deviceInfo()}')
      ..writeln('Dart: ${Platform.version.split(' ').first}');
    if (user != null) text.writeln('User: ${user.displayName}');

    await Share.share(text.toString(), subject: '${AppInfo.appName} Device Info');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final db = ref.watch(databaseProvider);
    final schema = db.schemaVersion;
    final pkg = _packageInfo;

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: const GradientScreenHeader(title: 'About'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // App identity
            Text(
              AppInfo.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Professional field trial data collection and execution platform',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppDesignTokens.secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),

            // Version + build + schema
            _InfoCard(children: [
              _InfoRow(
                label: 'Version',
                value: pkg != null
                    ? '${pkg.version} (build ${pkg.buildNumber})'
                    : AppInfo.appVersion,
              ),
              if (AppInfo.hasBuildMetadata)
                _InfoRow(label: 'Build', value: AppInfo.buildIdentity),
              _InfoRow(label: 'Schema', value: 'v$schema'),
              _InfoRow(label: 'Platform', value: _deviceInfo()),
              _InfoRow(
                label: 'Dart',
                value: Platform.version.split(' ').first,
              ),
            ]),
            const SizedBox(height: 16),

            // Current user
            _InfoCard(children: [
              userAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, __) => AppErrorHint(error: e),
                data: (user) {
                  if (user == null) {
                    return _ActionRow(
                      icon: Icons.person_add_outlined,
                      label: 'Select User',
                      onTap: () => _openUserSelection(context),
                    );
                  }
                  return _ActionRow(
                    icon: Icons.swap_horiz,
                    label: 'Signed in as ${user.displayName}',
                    onTap: () => _openUserSelection(context),
                  );
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Support + diagnostics
            _InfoCard(children: [
              _ActionRow(
                icon: Icons.email_outlined,
                label: 'Support: dhalleke17291@gmail.com',
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'dhalleke17291@gmail.com'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email copied')),
                  );
                },
              ),
              const Divider(height: 1, color: AppDesignTokens.borderCrisp),
              _ActionRow(
                icon: Icons.share_outlined,
                label: 'Share device info',
                onTap: _shareDeviceInfo,
              ),
              const Divider(height: 1, color: AppDesignTokens.borderCrisp),
              _ActionRow(
                icon: Icons.bug_report_outlined,
                label: 'Diagnostics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticsScreen(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Developer credit
            Text(
              'Developed by Parminder Singh',
              style: TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppDesignTokens.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppDesignTokens.iconSubtle),
          ],
        ),
      ),
    );
  }
}
