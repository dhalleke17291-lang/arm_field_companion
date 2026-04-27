import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/pin_utils.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../shared/widgets/pin_keypad.dart';

/// Full-screen PIN verification. Pops with `true` on success, `false` on cancel.
class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key, required this.user});

  final User user;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen>
    with SingleTickerProviderStateMixin {
  String _entry = '';
  int _failedAttempts = 0;
  int? _cooldownUntilMs;
  late AnimationController _shakeController;
  Timer? _cooldownTimer;
  static const int _kPinLen = 4;
  static const int _kMaxAttempts = 3;
  static const int _kCooldownSec = 30;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  bool get _inCooldown {
    final until = _cooldownUntilMs;
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  int get _cooldownSecondsLeft {
    final until = _cooldownUntilMs;
    if (until == null) return 0;
    final left =
        (until - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return left.clamp(0, _kCooldownSec);
  }

  void _onDigit(String d) {
    if (_inCooldown) return;
    if (_entry.length >= _kPinLen) return;
    setState(() {
      _entry += d;
    });
    if (_entry.length == _kPinLen) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_inCooldown) return;
    if (_entry.isEmpty) return;
    setState(() {
      _entry = _entry.substring(0, _entry.length - 1);
    });
  }

  Future<void> _submit() async {
    final hash = widget.user.pinHash;
    if (hash == null || hash.isEmpty) {
      if (mounted) Navigator.pop(context, true);
      return;
    }
    if (verifyPin(_entry, hash)) {
      if (mounted) Navigator.pop(context, true);
      return;
    }
    HapticFeedback.heavyImpact();
    await _shakeController.forward(from: 0);
    _failedAttempts += 1;
    setState(() {
      _entry = '';
    });
    if (_failedAttempts >= _kMaxAttempts) {
      setState(() {
        _cooldownUntilMs = DateTime.now()
            .add(const Duration(seconds: _kCooldownSec))
            .millisecondsSinceEpoch;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!_inCooldown) {
          _cooldownTimer?.cancel();
        }
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.bgWarm,
      appBar: GradientScreenHeader(
        title: 'Enter PIN',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  (widget.user.initials?.isNotEmpty == true)
                      ? widget.user.initials!.toUpperCase()
                      : widget.user.displayName.isNotEmpty
                          ? widget.user.displayName
                              .substring(0, 1)
                              .toUpperCase()
                          : '?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.user.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 32),
              if (_inCooldown)
                Text(
                  'Try again in $_cooldownSecondsLeft s',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppDesignTokens.warningFg,
                  ),
                )
              else
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final t = _shakeController.value;
                    final dx = (t * 6 * (1 - t) * 4) * 8;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_kPinLen, (i) {
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
                ),
              const Spacer(),
              PinKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                enabled: !_inCooldown,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
