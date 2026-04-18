/// Pre-configured trial templates for common trial types.
///
/// Each template provides default treatments, assessments (referencing
/// [AssessmentLibrary] IDs), design settings, and suggested timings.
/// Templates pre-fill the wizard — every field remains editable.
library;

import 'package:flutter/material.dart';

import 'plot_generation_engine.dart';

/// A single assessment within a template, referencing a curated library entry.
class TemplateAssessment {
  const TemplateAssessment({
    required this.libraryId,
    this.suggestedTimings = const [],
  });

  /// ID matching [LibraryAssessment.id] in assessment_library.dart.
  final String libraryId;

  /// Suggested rating timings, e.g. ['Pre', '7 DAT', '14 DAT', '28 DAT'].
  /// Displayed as guidance in the wizard; not enforced.
  final List<String> suggestedTimings;
}

/// A default treatment row in a template.
class TemplateTreatment {
  const TemplateTreatment({
    required this.code,
    this.name = '',
    this.type,
  });

  final String code;
  final String name;

  /// One of: CHK, HERB, FUNG, INSEC, PGR, OTHER.
  final String? type;
}

/// Full trial template definition.
class TrialTemplate {
  const TrialTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.treatments,
    required this.assessments,
    this.design = PlotGenerationEngine.designRcbd,
    this.reps = 4,
    this.guardRowsPerEnd = 0,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;

  /// Short label shown as a chip, e.g. 'Herbicide', 'Fungicide'.
  final String category;

  final List<TemplateTreatment> treatments;
  final List<TemplateAssessment> assessments;
  final String design;
  final int reps;
  final int guardRowsPerEnd;
}

/// All available trial templates.
const List<TrialTemplate> trialTemplates = [
  // ── Herbicide Efficacy ──────────────────────────────────────────
  TrialTemplate(
    id: 'herbicide_efficacy',
    name: 'Herbicide Efficacy',
    description:
        'Weed control, crop safety, and vigor assessments at standard '
        'post-application timings.',
    icon: Icons.grass,
    category: 'Herbicide',
    treatments: [
      TemplateTreatment(code: 'CHK', name: 'Untreated check', type: 'CHK'),
      TemplateTreatment(code: 'T2', type: 'HERB'),
      TemplateTreatment(code: 'T3', type: 'HERB'),
      TemplateTreatment(code: 'T4', type: 'HERB'),
    ],
    assessments: [
      TemplateAssessment(
        libraryId: 'herb_weed_control',
        suggestedTimings: ['Pre', '7 DAT', '14 DAT', '28 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'herb_broadleaf_control',
        suggestedTimings: ['14 DAT', '28 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'herb_grass_control',
        suggestedTimings: ['14 DAT', '28 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'phyto_phytotoxicity',
        suggestedTimings: ['7 DAT', '14 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'phyto_vigor',
        suggestedTimings: ['14 DAT', '28 DAT'],
      ),
    ],
  ),

  // ── Fungicide Efficacy ──────────────────────────────────────────
  TrialTemplate(
    id: 'fungicide_efficacy',
    name: 'Fungicide Efficacy',
    description:
        'Disease severity, incidence, and control with yield measurement. '
        'Standard foliar fungicide trial.',
    icon: Icons.bug_report_outlined,
    category: 'Fungicide',
    treatments: [
      TemplateTreatment(code: 'CHK', name: 'Untreated check', type: 'CHK'),
      TemplateTreatment(code: 'T2', type: 'FUNG'),
      TemplateTreatment(code: 'T3', type: 'FUNG'),
      TemplateTreatment(code: 'T4', type: 'FUNG'),
    ],
    assessments: [
      TemplateAssessment(
        libraryId: 'fung_disease_severity',
        suggestedTimings: ['Pre', '14 DAT', '28 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'fung_disease_incidence',
        suggestedTimings: ['14 DAT', '28 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'fung_disease_control',
        suggestedTimings: ['14 DAT', '28 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'phyto_phytotoxicity',
        suggestedTimings: ['7 DAT', '14 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'yield_grain_kg',
        suggestedTimings: ['Harvest'],
      ),
    ],
  ),

  // ── Insecticide Efficacy ────────────────────────────────────────
  TrialTemplate(
    id: 'insecticide_efficacy',
    name: 'Insecticide Efficacy',
    description:
        'Insect counts, damage ratings, and pest control percentages '
        'with crop injury monitoring.',
    icon: Icons.pest_control_outlined,
    category: 'Insecticide',
    treatments: [
      TemplateTreatment(code: 'CHK', name: 'Untreated check', type: 'CHK'),
      TemplateTreatment(code: 'T2', type: 'INSEC'),
      TemplateTreatment(code: 'T3', type: 'INSEC'),
      TemplateTreatment(code: 'T4', type: 'INSEC'),
    ],
    assessments: [
      TemplateAssessment(
        libraryId: 'insec_insect_count',
        suggestedTimings: ['Pre', '3 DAT', '7 DAT', '14 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'insec_insect_damage',
        suggestedTimings: ['7 DAT', '14 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'insec_pest_control',
        suggestedTimings: ['7 DAT', '14 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'phyto_crop_injury',
        suggestedTimings: ['7 DAT'],
      ),
      TemplateAssessment(
        libraryId: 'yield_grain_kg',
        suggestedTimings: ['Harvest'],
      ),
    ],
  ),

  // ── Variety Comparison ──────────────────────────────────────────
  TrialTemplate(
    id: 'variety_comparison',
    name: 'Variety Comparison',
    description:
        'Agronomic trait evaluation: height, stand, lodging, maturity, '
        'and yield across varieties.',
    icon: Icons.compare_arrows,
    category: 'Agronomy',
    treatments: [
      TemplateTreatment(code: 'VAR1', name: 'Variety 1', type: 'CHK'),
      TemplateTreatment(code: 'VAR2', name: 'Variety 2'),
      TemplateTreatment(code: 'VAR3', name: 'Variety 3'),
      TemplateTreatment(code: 'VAR4', name: 'Variety 4'),
    ],
    assessments: [
      TemplateAssessment(
        libraryId: 'growth_plant_height',
        suggestedTimings: ['Mid-season', 'Pre-harvest'],
      ),
      TemplateAssessment(
        libraryId: 'growth_stand_count',
        suggestedTimings: ['Emergence', 'Mid-season'],
      ),
      TemplateAssessment(
        libraryId: 'growth_lodging',
        suggestedTimings: ['Pre-harvest'],
      ),
      TemplateAssessment(
        libraryId: 'growth_days_maturity',
        suggestedTimings: ['Maturity'],
      ),
      TemplateAssessment(
        libraryId: 'yield_grain_kg',
        suggestedTimings: ['Harvest'],
      ),
    ],
  ),

  // ── Seed Treatment ──────────────────────────────────────────────
  TrialTemplate(
    id: 'seed_treatment',
    name: 'Seed Treatment',
    description:
        'Emergence, seedling health, damping off, and establishment '
        'monitoring for seed-applied products.',
    icon: Icons.spa_outlined,
    category: 'Seed',
    treatments: [
      TemplateTreatment(code: 'CHK', name: 'Untreated seed', type: 'CHK'),
      TemplateTreatment(code: 'T2'),
      TemplateTreatment(code: 'T3'),
      TemplateTreatment(code: 'T4'),
    ],
    assessments: [
      TemplateAssessment(
        libraryId: 'seed_germination',
        suggestedTimings: ['7 DAP'],
      ),
      TemplateAssessment(
        libraryId: 'seed_vigor',
        suggestedTimings: ['14 DAP'],
      ),
      TemplateAssessment(
        libraryId: 'growth_emergence',
        suggestedTimings: ['7 DAP', '14 DAP', '21 DAP'],
      ),
      TemplateAssessment(
        libraryId: 'growth_stand_count',
        suggestedTimings: ['21 DAP'],
      ),
      TemplateAssessment(
        libraryId: 'seed_damping_off',
        suggestedTimings: ['14 DAP', '21 DAP'],
      ),
      TemplateAssessment(
        libraryId: 'yield_grain_kg',
        suggestedTimings: ['Harvest'],
      ),
    ],
  ),
];
