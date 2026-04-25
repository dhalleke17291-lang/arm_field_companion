import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';

/// Stateless 3×4 keypad: 1–9, blank, 0, backspace. Caller owns the PIN buffer.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  static const double _keySize = 64;

  @override
  Widget build(BuildContext context) {
    Widget keyCell(Widget child) {
      return SizedBox(
        width: _keySize,
        height: _keySize,
        child: child,
      );
    }

    Widget digitKey(String d) {
      return keyCell(
        GestureDetector(
          onTap: enabled ? () => onDigit(d) : null,
          child: Container(
            width: _keySize,
            height: _keySize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignTokens.cardSurface,
              border: Border.all(
                color: AppDesignTokens.borderCrisp,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              d,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        ),
      );
    }

    Widget backspaceKey() {
      return keyCell(
        GestureDetector(
          onTap: enabled ? onBackspace : null,
          child: Container(
            width: _keySize,
            height: _keySize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppDesignTokens.cardSurface,
              border: Border.all(
                color: AppDesignTokens.borderCrisp,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.backspace_outlined,
              size: 24,
              color: AppDesignTokens.secondaryText,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [digitKey('1'), digitKey('2'), digitKey('3')],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [digitKey('4'), digitKey('5'), digitKey('6')],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [digitKey('7'), digitKey('8'), digitKey('9')],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: _keySize, height: _keySize),
            digitKey('0'),
            backspaceKey(),
          ],
        ),
      ],
    );
  }
}
