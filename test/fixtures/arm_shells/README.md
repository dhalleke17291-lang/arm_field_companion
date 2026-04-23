# ARM Rating Shell Fixtures

Real ARM Rating Shell `.xlsx` files, kept as **parser ground truth**. Every change to the ARM shell parser must keep these fixtures' expected outputs stable.

## Fixture index

| File | Source | Trial shape | Fills used |
|---|---|---|---|
| `AgQuest_RatingShell.xlsx` | ARM 2026.0 demo export | 4 treatments × 4 reps = 16 plots, RCBD randomized within rep, 6 assessment columns | Treatments sheet filled (types: CHK/FUNG/HERB, products, formulation, rates). Applications sheet blank (template). Plot Data column descriptors filled for rating date, SE name, part rated, rating type, unit, sample size, size unit, collect basis, reporting basis, rating timing codes (A1/A3/A4/A6/A9/AA), trt-eval interval, plant-eval interval, # subsamples. Crop stage, pest stage, density, equipment, assessed-by rows all blank in this demo. |

## Why fixtures matter

ARM is an annual subscription product with a single active version (currently ARM 2026.0). GDM auto-updates all users. That means the **shell format is a stable, standardized contract** — not a per-customer configuration.

These fixtures encode the contract. The parser must be deterministic against them. Annual version bumps (e.g. ARM 2027) may shift the format slightly; when that happens, add a new fixture alongside, do not replace.

## AgQuest_RatingShell.xlsx — sheet map

This file has **7 sheets**:

| Sheet | Purpose | Parsed today? |
|---|---|---|
| **Plot Data** | Assessment column metadata + plot layout + rating values | **Yes** — descriptor rows 9–47 (0-based 8–46) into [ArmColumnMap]; importer lands them on `arm_assessment_metadata` + normalises rating dates to `yyyy-MM-dd` on planned sessions |
| **Treatments** | Products, rates, formulations, rate units | **Yes** (Phase 2) |
| **Applications** | 79 descriptor fields: dates, weather, equipment, nozzles, carrier, mix | **Yes** (Phase 3b parser + Phase 3c importer) |
| **Comments** | Free-text trial notes (`ECM` row, column B) | **Yes** — parser → `ArmShellImport.commentsSheetText`; persisted on `arm_trial_metadata.shell_comments_sheet` |
| **Subsample Plot Data** | Mirror of Plot Data for subsample protocols | **Not parsed** |
| **Subsample Treatment Means** | Calculated means (Excel formulas) | Output-only, not ingested |
| **Treatment Means** | Calculated means per treatment (Excel formulas) | Output-only, not ingested |

## Plot Data sheet — row-by-row map (1-based rows, 1-based cols)

Header block:

| Row | Col A (code) | Col B (label) | Col C (value) | Notes |
|---|---|---|---|---|
| 2 | `TT` | Title | `AgQuest Demo Trial` | Trial name |
| 3 | `T#` | Trial ID | `AgQuest` | ARM trial identifier |
| 4 | `CN` | Cooperator | *(blank)* | Cooperator name |
| 5 | `CRA1` | Crop | `ALLSA` | Crop code |
| 6 | `XL` | ARM Pull Flag | *(blank)* | Set by ARM on pull |

Assessment-column descriptor rows (columns C+ hold per-column values; one column per assessment). Column C onwards uses **ARM Column ID** (integer) as identity:

| Row | Code | Field label | Example values (AgQuest) | Captured? |
|---|---|---|---|---|
| 8 | `001EID` | ARM Column ID | `3`, `6`, `7`, `8`, `9`, `16` | yes → `armColumnId` / `armColumnIdInteger` |
| 9 | `002E~P` | Pest Type | *(blank)* | yes → `ArmColumnMap.pestType` → AAM `shellPestType` |
| 10 | `003EPT` | Pest Code | *(blank)* | yes → `pestCodeFromSheet` → AAM `pestCode` |
| 11 | `004EPG` | Pest Name | *(blank)* | yes → AAM `shellPestName` |
| 12 | `005ECR` | Crop Code | *(blank)* | yes → AAM `shellCropCode` |
| 13 | `006ECG` | Crop Name | *(blank)* | yes → AAM `shellCropName` |
| 14 | `007ECV` | Crop Variety | *(blank)* | yes → AAM `shellCropVariety` |
| 15 | `008ECE` | Description | *(blank in AgQuest; typically SE description)* | yes → `seDescription` |
| 16 | `009EED` | Rating Date | ISO or `d-Mmm-yy` | yes → raw on AAM `armShellRatingDate`; **normalised `yyyy-MM-dd`** on `Sessions.sessionDateLocal`, `Sessions.startedAt` (UTC midnight when parseable), `ArmSessionMetadata.armRatingDate` |
| 17 | `010ETD` | Rating Time | *(blank)* | yes → AAM `shellRatingTime` |
| 18 | `011EEV` | SE Name | `W003`, `W001`, `CF013`, … | yes → `seName` |
| 19 | `012ECP` | Part Rated | `PLANT`, `LEAF3`, … | yes → `partRated` |
| 20 | `013ERF` | Crop or Pest | *(blank)* | yes → AAM `shellCropOrPest` |
| 21 | `014EDT` | Rating Type | `CONTRO`, `LODGIN`, … | yes → `ratingType` |
| 22 | `015ERU` | Rating Unit | `%` | yes → `ratingUnit` |
| 23 | `016EBS` | Sample Size | `1` | yes → AAM `shellSampleSize` |
| 24 | `017EBU` | Size Unit | `PLOT` | yes → AAM `shellSizeUnit` |
| 25 | `018EUS` | Collect. Basis | `1` | yes → `collectBasis` (core-style field on AAM) |
| 26 | `019EUU` | Basis Unit | `PLOT` | yes → AAM `shellCollectionBasisUnit` |
| 27 | `020ERS` | Report. Basis | `1` | yes → AAM `shellReportingBasis` |
| 28 | `021ERN` | Basis Unit | `PLOT` | yes → AAM `shellReportingBasisUnit` |
| 29 | `022ECN` | Stage Scale | *(blank)* | yes → AAM `shellStageScale` |
| 30 | `023ECS` | Crop Stage Maj. | *(blank)* | yes → `cropStageMaj` / AAM `shellCropStageMaj` |
| 31 | `024ECL` | Crop Stage Min. | *(blank)* | yes → AAM `shellCropStageMin` |
| 32 | `025ECX` | Crop Stage Max. | *(blank)* | yes → AAM `shellCropStageMax` |
| 33 | `026ECD` | Crop Density | *(blank)* | yes → AAM `shellCropDensity` |
| 34 | `027ECU` | Density Unit | *(blank)* | yes → AAM `shellCropDensityUnit` |
| 35 | `028EPS` | Pest Stage Maj. | *(blank)* | yes → AAM `shellPestStageMaj` |
| 36 | `029EPL` | Pest Stage Min. | *(blank)* | yes → AAM `shellPestStageMin` |
| 37 | `030EPX` | Pest Stage Max. | *(blank)* | yes → AAM `shellPestStageMax` |
| 38 | `031EPD` | Pest Density | *(blank)* | yes → AAM `shellPestDensity` |
| 39 | `032EPU` | Density Unit | *(blank)* | yes → AAM `shellPestDensityUnit` |
| 40 | `033EAB` | Assessed By | *(blank in AgQuest)* | yes → AAM `shellAssessedBy`; also `Sessions.raterName` + `ArmSessionMetadata.raterInitials` for planned sessions |
| 41 | `034EQP` | Equipment | *(blank)* | yes → AAM `shellEquipment` |
| 42 | `035EET` | Rating Timing | `A1`, `A3`, … | yes → `appTimingCode` + AAM `shellAppTimingCode` |
| 43 | `036ETI` | Trt-Eval Interval | `-28 DA-A`, … | yes → `trtEvalInterval` + AAM `shellTrtEvalInterval` |
| 44 | `037EPI` | Plant-Eval Interval | `-7 DP-1`, … | yes → `datInterval` + AAM `shellPlantEvalInterval` |
| 45 | `038EUT` | Untrt. Rating Type | *(blank)* | yes → AAM `shellUntreatedRatingType` |
| 46 | `039EDP` | ARM Actions | *(blank)* | yes → AAM `shellArmActions` |
| 47 | `040ENS` | # Subsamples | `1` | yes → `numSubsamples` |

Plot layout block (starting row 48):

| Row | Col A | Col B | Col C+ |
|---|---|---|---|
| 48 | `041TRT` | `Plot (Sub)` | *(header row)* |
| 49–64 | *(trt number)* | *(plot number)* | *(rating values per assessment column)* |

## Treatments sheet (sheet 7) map

Two header rows, then one data row per treatment:

| Col | R1 | R2 | Example R3 (Trt 1) | Example R4 (Trt 2) |
|---|---|---|---|---|
| A | `Trt` | `No.` | `1` | `2` |
| B | *(blank)* | `Type` | `CHK` | `FUNG` |
| C | `Treatment` | `Name` | *(blank)* | `APRON` |
| D | `Form` | `Conc` | *(blank)* | `25` |
| E | `Form` | `Unit` | *(blank)* | `%W/W` |
| F | `Form` | `Type` | *(blank)* | `W` |
| G | *(blank)* | `Rate` | *(blank)* | `5` |
| H | `Rate` | `Unit` | *(blank)* | `% w/v` |

## Applications sheet (sheet 5) map

Descriptor rows (one row per field; columns C+ per application event). AgQuest has 79 rows of descriptors, all unpopulated in the demo template. Full list:

- R1 `ADA` Application Date
- R2 `ATA` Start Time
- R3 `FIA` Stop Time
- R4 `IJA` Interval to Prev. Appl.
- R5 `IKA` Interval Unit
- R6 `AOA` Appl. Method
- R7 `ANA` Appl. Timing (**A1/A3/AA** codes live here — link to Plot Data row 42)
- R8 `AMA` Appl. Placement
- R9 `AEA` Applied By
- R10–R12 Air Temp Start/Stop + unit
- R13–R14 Relative Humidity Start/Stop
- R15–R20 Wind (Velocity Start/Stop/Max + Direction × 3)
- R21 `WUA` Wind Velocity Unit
- R22 `DPA` Wet Leaves (Y/N)
- R23–R24 Soil Temperature + unit
- R25 Soil Moisture
- R26 Soil Surface Condition
- R27 `CCA` % Cloud Cover
- R28–R34 Moisture block (next occurrence, time-to, 6hr after, 1wk after + units)
- R35 Weather Source
- R36–R37 Equipment + Type
- R38–R39 Spray Pressure + unit
- R40–R48 Nozzle block (Type, Size, Spacing + unit, Rows, Calibration + unit, Filter Mesh + unit)
- R49 Spray Quality
- R50–R51 Time to Treat 1 Plot + unit
- R52–R53 Band Width + unit
- R54 % Coverage
- R55 Row Sides Applied
- R56–R60 Boom block (ID, Length + unit, Height + unit)
- R61–R62 Boom Flow Rate + unit
- R63–R64 Ground Speed + unit
- R65–R68 Incorp. Equipment + Hours + Depth + unit
- R69 Carrier
- R70 Water Hardness
- R71–R72 Application Amount + unit
- R73–R76 Mix Overage + unit, Mix Size + unit
- R77 Spray pH
- R78 Propellant
- R79 `TMA` Tank Mix (Y/N)

## Comments sheet (sheet 6) map

Single free-text cell:

- R1 C2: "Enter all comments in cell below:"
- R2 C1: `ECM` code, free-text comment value

## Subsample Plot Data & Subsample Treatment Means

Only relevant when `# Subsamples > 1`. AgQuest uses subsamples = 1, so these sheets mirror the main plot data degenerately.

## Parser sanity checks

Things the parser must tolerate (proven by AgQuest):

- Assessment columns with `ARM Column ID` but **blank** Rating Date, Rating Timing, SE Name (column 9 in this file).
- Non-contiguous `ARM Column ID` values (`3, 6, 7, 8, 9, 16` — not `1..6`).
- Most stage/density/equipment rows blank.
- Treatments sheet uses two-row headers (A1+A2 merged concept).
- Empty-string cells (`<v></v>`) distinct from null; `_firstNonEmpty` helper handles this.
