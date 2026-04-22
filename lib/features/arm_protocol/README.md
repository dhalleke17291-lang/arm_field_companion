# ARM Protocol feature

UI surfaces that exist **only for ARM-linked trials**. Code outside `arm*/` folders must not import from here.

See `docs/ARM_SEPARATION.md` for the full separation rule.

This folder will host the **ARM Protocol tab** — a dedicated destination on the trial detail screen that surfaces ARM-specific richness (assessment column metadata, formulation details, Applications descriptor view, Comments, shell round-trip status).

Core trial screens (`lib/features/trials/`, `lib/features/ratings/`, `lib/features/sessions/`, etc.) must stay protocol-agnostic: they may read core fields that ARM happens to populate (e.g. `treatment.productName`, `assessment.scheduledDate`), but must not reach into any `arm_*` extension table or widget in this folder.

## Current state

Phase 0a: folder established, separation rule enforced. No widgets yet.
Phase 6 (planned): ARM Protocol tab implementation.
