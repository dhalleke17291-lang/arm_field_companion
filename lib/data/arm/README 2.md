# ARM-only data layer

Repositories, services, and persistence helpers that exist **only for ARM round-trip**. Code outside `arm*/` folders must not import from here.

See `docs/ARM_SEPARATION.md` for the full separation rule.

New ARM-specific extension tables (`arm_trial_metadata`, `arm_assessment_metadata`, `arm_treatment_metadata`, `arm_applications`, `arm_comments`) and their repositories live here when they land in Phase 0b.

The existing `lib/data/services/arm_shell_parser.dart` will move under this folder as part of that cleanup.
