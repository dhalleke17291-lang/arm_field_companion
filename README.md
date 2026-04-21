# Agnexis

Agnexis is an offline-first field trial execution app for agricultural research teams. It is built to help researchers and technicians run protocol-driven trials, capture field observations, preserve auditability, and export clean, traceable results.

## What the app does

- Manage trials, plots, treatments, assignments, and assessments
- Run field sessions for ratings, seeding, applications, notes, flags, and photos
- Import structured trial data, including ARM-linked workflows
- Export trial and session outputs, including CSV, PDF, ZIP bundles, and ARM-related handoff flows
- Preserve recovery, diagnostics, and audit history for research-grade traceability

## Product focus

The app is designed around a simple principle:

`Protocol defines structure. Execution records reality.`

That means the app separates protocol data from field execution data, keeps workflows usable offline, and preserves lineage from trial setup through export.

## Technical stack

- Flutter
- Riverpod
- Drift / SQLite
- Native mobile integrations for files, sharing, photos, geolocation, and secure storage

## Codebase shape

- `lib/core`: app shell, providers, database, diagnostics, design system
- `lib/features`: trial workflows, sessions, ratings, import/export, recovery, diagnostics, weather, users
- `lib/data`: repositories and services
- `lib/domain`: models and domain logic
- `test`: unit, feature, integration-style, and stress coverage

## Quality signals

- Large automated test suite with stress coverage for high-volume import and export paths
- Offline-first workflow design
- Recovery and diagnostics tooling built into the product
- ARM import/export support under active hardening

## Docs

Key internal docs:

- `docs/MASTER_CHARTER.md`
- `docs/PRODUCT_ROADMAP_AND_SYSTEM_MAP.md`
- `docs/DEVELOPMENT_CRITERIA.md`
- `docs/EXPORT.md`

## Development

Common commands:

```bash
flutter analyze
flutter test
flutter run
```

## Status

This is an actively developed vertical product codebase, not a starter template. Current work is focused on import reliability, field workflow speed, export trust, and overall release hardening.
