# Lane 2A Photo Review Workflow

Lane 2A photos are species/reference photos. They are not calibrated severity, control, or cover references, so do not assign rating values such as 10%, 25%, 50%, 75%, 90%, or 100%.

## Source

- Dataset: Dryad Manitoba weed seedling dataset
- DOI: `10.5061/dryad.gtht76hhz`
- Required image-file license: `CC0`
- Dataset authors: Beck, Liu, Bidinosti, Henry, Godee, Ajmani

Only use exact image files after confirming that CC0 applies to the image file, not just dataset metadata.

## Target Batch 1 Species

| Species code | Common name | Scientific name | Category |
| --- | --- | --- | --- |
| `wild_oat` | Wild oat | Avena fatua | `weed_seedling_reference` |
| `canada_thistle` | Canada thistle | Cirsium arvense | `weed_seedling_reference` |
| `wild_buckwheat` | Wild buckwheat | Fallopia convolvulus | `weed_seedling_reference` |
| `volunteer_canola` | Volunteer canola | Brassica napus | `volunteer_crop_as_weed` |
| `dandelion` | Dandelion | Taraxacum officinale | `weed_seedling_reference` |

## Candidate Selection Rules

Pick 5 candidates per species for review. Parminder approves the final 3 per species.

Good candidates should have:

- subject fills 55-80% of frame
- sharp focus
- clear leaf shape
- minimal clutter
- useful field-reference appearance
- no misleading symptoms, crop context, or mixed species
- no overexposure or underexposure
- at least one top-down candidate if possible
- at least one angled candidate if possible
- at least one field-realistic candidate if possible

## Folder Flow

Candidate review only:

```text
assets/reference_guides/lane2a/review_queue/<species>/
```

Approved bundled photos only:

```text
assets/reference_guides/lane2a/approved/<species>/
```

The app seeds only files listed in:

```text
lib/features/reference_guides/lane2a_approved_photo_manifest.dart
```

Files in `review_queue` are never seeded.

## Tooling

Prepare a selection file from a local Dryad download:

```bash
dart run tool/lane2a_review_queue.dart init-selection --output /tmp/lane2a_selection.json
```

Edit `/tmp/lane2a_selection.json` so each species has up to 5 selected source files and quality notes.

Copy selected candidates into the review queue and generate the pending manifest:

```bash
dart run tool/lane2a_review_queue.dart copy --selection /tmp/lane2a_selection.json --source /path/to/dryad_download
```

The generated review manifest is:

```text
assets/reference_guides/lane2a/review_queue/candidate_review_manifest.json
```

## Approval Steps

1. Parminder reviews the images in `review_queue/<species>/`.
2. Parminder chooses the final approved files.
3. Move approved files into `approved/<species>/`.
4. Add exact entries to `lane2a_approved_photo_manifest.dart`.
5. Run `flutter pub get` if asset paths changed.
6. Run `flutter analyze`.
7. Run `flutter test test/features/reference_guides`.

Do not edit the approved manifest from the review tool. Approval is intentionally manual.
