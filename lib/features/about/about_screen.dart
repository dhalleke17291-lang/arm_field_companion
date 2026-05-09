import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
  String? _deviceLabel;
  String? _osLabel;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadDeviceInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  Future<void> _loadDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    String? device;
    String? os;
    try {
      if (Platform.isIOS) {
        final ios = await plugin.iosInfo;
        // utsname.machine → e.g. "iPhone16,2"; model/name are more readable.
        device = ios.name.isNotEmpty ? ios.name : ios.model;
        os = '${ios.systemName} ${ios.systemVersion}';
      } else if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        device = '${a.manufacturer} ${a.model}';
        os = 'Android ${a.version.release} (API ${a.version.sdkInt})';
      } else if (Platform.isMacOS) {
        final m = await plugin.macOsInfo;
        device = m.model;
        os = 'macOS ${m.osRelease}';
      } else {
        os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } catch (_) {
      os ??= '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }
    if (!mounted) return;
    setState(() {
      _deviceLabel = device;
      _osLabel = os;
    });
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
    if (_deviceLabel != null) text.writeln('Device: $_deviceLabel');
    if (_osLabel != null) text.writeln('OS: $_osLabel');
    text
      ..writeln('Schema: v$schema')
      ..writeln('Dart: ${Platform.version.split(' ').first}');
    if (user != null) text.writeln('User: ${user.displayName}');

    await Share.share(text.toString(),
        subject: '${AppInfo.appName} Device Info');
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            const _BrandCard(),
            const SizedBox(height: AppDesignTokens.spacing16),
            const _SectionLabel(
              title: 'FIELD CONTEXT',
              subtitle:
                  'Used for session, rating, edit, and export attribution',
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            _InfoCard(
              children: [
                userAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, __) => AppErrorHint(error: e),
                  data: (user) {
                    if (user == null) {
                      return _ActionRow(
                        icon: Icons.person_add_outlined,
                        label: 'Choose current user',
                        detail: 'Set the field profile for new work',
                        onTap: () => _openUserSelection(context),
                      );
                    }
                    return _ActionRow(
                      icon: Icons.assignment_ind_outlined,
                      label: user.displayName,
                      detail: 'Current user for work attribution',
                      onTap: () => _openUserSelection(context),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDesignTokens.spacing20),
            const _SectionLabel(
              title: 'DEVICE DETAILS',
              subtitle: 'Useful when sharing a support snapshot',
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Version',
                  value: pkg != null
                      ? '${pkg.version} (build ${pkg.buildNumber})'
                      : AppInfo.appVersion,
                ),
                if (AppInfo.hasBuildMetadata)
                  _InfoRow(label: 'Build', value: AppInfo.buildIdentity),
                if (_deviceLabel != null)
                  _InfoRow(label: 'Device', value: _deviceLabel!),
                if (_osLabel != null) _InfoRow(label: 'OS', value: _osLabel!),
                _InfoRow(label: 'Schema', value: 'v$schema'),
              ],
            ),
            const SizedBox(height: AppDesignTokens.spacing20),
            const _SectionLabel(
              title: 'SUPPORT TOOLS',
              subtitle:
                  'Copy support contact, share details, or inspect app health',
            ),
            const SizedBox(height: AppDesignTokens.spacing8),
            _InfoCard(
              children: [
                _ActionRow(
                  icon: Icons.email_outlined,
                  label: 'Support email',
                  detail: 'dhalleke17291@gmail.com',
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
                  detail: 'Version, device, OS, schema, and current user',
                  onTap: _shareDeviceInfo,
                ),
                const Divider(height: 1, color: AppDesignTokens.borderCrisp),
                _ActionRow(
                  icon: Icons.bug_report_outlined,
                  label: 'Diagnostics',
                  detail: 'Support report, checks, and recent app errors',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Agnexis · © ${DateTime.now().year}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.secondaryText.withValues(alpha: 0.62),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Developed by Parminder Singh',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppDesignTokens.secondaryText.withValues(alpha: 0.36),
                letterSpacing: 0.2,
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
        builder: (_) => const UserSelectionScreen(popOnSelect: true),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: ClipOval(
              child: Image.asset(
                'assets/Branding/splash_logo.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                semanticLabel: 'App logo',
              ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppInfo.appName.toUpperCase(),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w300,
                color: AppDesignTokens.primaryText,
                letterSpacing: 5.8,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          SizedBox(
            width: 86,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppDesignTokens.flagColor.withValues(alpha: 0.62),
              ),
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            'Professional field trial data collection\nand execution platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: AppDesignTokens.secondaryText.withValues(alpha: 0.82),
              letterSpacing: 0.3,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppDesignTokens.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
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
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppDesignTokens.sectionHeaderBg,
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusSmall),
              ),
              child: Icon(icon, size: 21, color: AppDesignTokens.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ],
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
