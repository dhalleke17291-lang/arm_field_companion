import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/workspace/workspace_config.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../shared/layout/responsive_layout.dart';
import '../trial_review/blocks/audit_disclosure.dart';
import '../trial_review/blocks/cautions_block.dart';
import '../trial_review/blocks/required_block.dart';
import '../trial_review/blocks/verdict_block.dart';

/// Read-only Trial Review tab.
/// Each block handles its own loading/error/empty state independently.
class TrialOverviewTab extends StatelessWidget {
  const TrialOverviewTab({
    super.key,
    required this.trial,
    this.onSwitchTab,
  });

  final Trial trial;
  final void Function(TrialTab)? onSwitchTab;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: AppDesignTokens.spacing8,
          bottom: AppDesignTokens.spacing32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TrialReviewBlockFrame(child: VerdictBlock(trial: trial)),
            _TrialReviewBlockFrame(
              child: RequiredBlock(
                trial: trial,
                // No-op when parent doesn't wire a tab switch handler
                // (test/standalone). In production, the parent
                // (trial_detail_screen.dart) always supplies one.
                onSwitchTab: onSwitchTab ?? (_) {},
              ),
            ),
            _TrialReviewBlockFrame(child: CautionsBlock(trial: trial)),
            _TrialReviewBlockFrame(child: AuditDisclosure(trial: trial)),
          ],
        ),
      ),
    );
  }
}

class _TrialReviewBlockFrame extends StatelessWidget {
  const _TrialReviewBlockFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing12,
      ),
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: child,
    );
  }
}
