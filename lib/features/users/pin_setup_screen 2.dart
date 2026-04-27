import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/pin_utils.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../shared/widgets/pin_keypad.dart';

enum _SetupStep { enter, confirm }

/// Set, change, or remove PIN for [userId]. Pops on success.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({
    super.key,
    required this.user,
  });

  final User user;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  _SetupStep _step = _SetupStep.enter;
  String _first = '';
  String _entry = '';
  String? _mismatch;
  static const int _kLen = 4;

  bool get _removing => widget.user.pinEnabled;

  void _onDigit(String d) {
    if (_entry.length >= _kLen) return;
    setState(() {
      _mismatch = null;
      _entry += d;
    });
    if (_entry.length == _kLen) {
      _onFourDigits();
    }
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() {
      _entry = _entry.substring(0, _entry.length - 1);
    });
  }

  Future<void> _onFourDigits() async {
    if (_step == _SetupStep.enter) {
      setState(() {
        _first = _entry;
        _entry = '';
        _step = _SetupStep.confirm;
      });
      return;
    }
    if (_entry != _first) {
      setState(() {
        _mismatch = "PINs don't match";
        _entry = '';
        _first = '';
        _step = _SetupStep.enter;
      });
      return;
    }
    final repo = ref.read(userRepositoryProvider);
    await repo.updateUser(
      widget.user.id,
      pinHash: hashPin(_entry),
      pinEnabled: true,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _removePin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text(
          'You will not be asked for a PIN for this profile until you set one again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(userRepositoryProvider).updateUser(
          widget.user.id,
          clearPin: true,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appTitle = _mismatch != null
        ? 'PIN'
        : (_step == _SetupStep.enter ? 'New PIN' : 'Confirm PIN');

    return Scaffold(
      backgroundColor: AppDesignTokens.bgWarm,
      appBar: GradientScreenHeader(title: appTitle),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (_removing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _removePin,
                  child: const Text('Remove PIN'),
                ),
              ],
              const SizedBox(height: 16),
              if (_mismatch != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _mismatch!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppDesignTokens.warningFg,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_kLen, (i) {
                  final filled = i < _entry.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppDesignTokens.primary
                            : AppDesignTokens.emptyBadgeBg,
                        border: Border.all(
                          color: AppDesignTokens.borderCrisp,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              PinKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
