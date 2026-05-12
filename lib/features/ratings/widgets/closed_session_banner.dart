import 'package:flutter/material.dart';

import '../../../core/session_lock.dart';

class ClosedSessionBanner extends StatelessWidget {
  const ClosedSessionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.lock,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kClosedSessionBlockedMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
