import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import 'section_1_identity.dart';
import 'section_2_design.dart';
import 'section_3_arc.dart';
import 'section_4_ctq.dart';
import 'section_5_endpoint.dart';
import 'section_6_comparison.dart';
import 'section_7_coherence.dart';
import 'section_8_environmental.dart';
import 'section_9_decisions.dart';
import 'section_10_readiness.dart';

/// Read-only ten-section Trial Overview tab.
/// Each section handles its own loading/error/empty state independently.
class TrialOverviewTab extends StatelessWidget {
  const TrialOverviewTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: AppDesignTokens.spacing8,
        bottom: AppDesignTokens.spacing32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Section1Identity(trial: trial),
          Section2Design(trial: trial),
          Section3Arc(trial: trial),
          Section4Ctq(trial: trial),
          Section5Endpoint(trial: trial),
          Section6Comparison(trial: trial),
          Section7Coherence(trial: trial),
          Section8Environmental(trial: trial),
          Section9Decisions(trial: trial),
          Section10Readiness(trial: trial),
        ],
      ),
    );
  }
}
