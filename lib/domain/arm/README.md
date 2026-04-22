# ARM-only domain models

Models that exist **only for ARM round-trip**. Code outside `arm*/` folders must not import from here.

See `docs/ARM_SEPARATION.md` for the full separation rule.

A field belongs here if it encodes an ARM-specific code, unit convention, row position, or schema quirk that only makes sense inside the shell round-trip (e.g. `CONTRO` rating type code, `%W/W` formulation concentration, `-7 DA-A` interval string, 79-field Applications descriptor block).

Universal concepts (product name, rate, rating date, grower name, growth stage label) live in `lib/domain/models/`, not here.
