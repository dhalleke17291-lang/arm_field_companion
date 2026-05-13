# Lane 2A Review Queue

This folder is for manually reviewed candidate photos only. Images here are not bundled into the app and are not seeded as Lane 2 references.

Source for Batch 1 candidates:

- Dryad Manitoba weed seedling dataset
- DOI: `10.5061/dryad.gtht76hhz`
- Required exact image-file license: `CC0`

Target species:

- `wild_oat`
- `canada_thistle`
- `wild_buckwheat`
- `volunteer_canola`
- `dandelion`

Selection target: 5 candidates per species. Parminder approves the final 3 per species.

Candidate quality rules:

- subject fills 55-80% of frame
- sharp focus
- clear leaf shape
- minimal clutter
- useful for field reference
- not overexposed
- not underexposed
- not misleading
- one top-down candidate if possible
- one angled candidate if possible
- one field-realistic candidate if possible

Approval flow:

1. Download the Dryad dataset locally.
2. Verify the exact image files are CC0.
3. Use `tool/lane2a_review_queue.dart` to copy selected candidates into this folder and generate `candidate_review_manifest.json`.
4. Parminder reviews candidates and moves approved files into `assets/reference_guides/lane2a/approved/<species>/`.
5. Add only approved files to `lib/features/reference_guides/lane2a_approved_photo_manifest.dart`.

Do not add severity, cover, control, or rating-percent labels to these photos. These are species/reference photos, not calibrated cover diagrams.
