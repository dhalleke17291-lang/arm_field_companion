# Protocol Import CSV Format (Charter PART 15–16)

Protocol import allows loading **trial + treatments + plots** (and plot→treatment assignment) from one CSV.

## Required structure

- **First row:** Column headers.
- **One column** must be named `section` or `type` with values: `TRIAL`, `TREATMENT`, `PLOT` (case-insensitive).

## Sections

### TRIAL (0 or 1 row)

- **When creating a new trial from file:** Exactly one row with `section=TRIAL`.
- **When adding to an existing trial:** TRIAL section is ignored; 0 rows is OK.

| Column       | Required | Notes                    |
|-------------|----------|--------------------------|
| trial_name  | Yes      | Name of the trial        |
| crop        | No       |                          |
| location    | No       |                          |
| season      | No       |                          |

### TREATMENT (0+ rows)

| Column      | Required | Notes                    |
|-------------|----------|--------------------------|
| code        | Yes      | Unique within file       |
| name        | Yes      |                          |
| description | No       |                          |

### PLOT (0+ rows)

| Column          | Required | Notes                                      |
|-----------------|----------|--------------------------------------------|
| plot_id         | Yes      | Unique within file (or alias: plot, Plot)   |
| rep             | No       | Integer                                    |
| row             | No       |                                            |
| column          | No       |                                            |
| plot_sort_index | No       | Integer; defaults to row order             |
| treatment_code  | No       | Must match a TREATMENT code (for assignment)|

## Example CSV

```csv
section,trial_name,crop,location,season,code,name,description,plot_id,rep,row,column,plot_sort_index,treatment_code
TRIAL,Wheat 2024,Wheat,North Farm,2024,,,,,,,,
TREATMENT,,,,,T1,Control,,,,,,,
TREATMENT,,,,,T2,Fungicide,,,,,,,
PLOT,,,,,,,101,1,1,1,1,T1
PLOT,,,,,,,102,1,1,2,2,T1
PLOT,,,,,,,103,1,1,3,3,T2
```

## Flow (Charter PART 16)

1. **Source detection** — CSV with `section` column.
2. **Structural scan** — Rows grouped by section.
3. **Mapping** — Column aliases (e.g. Plot → plot_id, treatment → treatment_code).
4. **Validation** — Required fields, unique keys, treatment_code in TREATMENT section.
5. **Import review** — Four categories (Matched, Auto-handled, Needs review, Must fix) shown per section.
6. **User approval** — “Approve and Import” runs only when there are no Must fix errors.
7. **Protocol model integration** — Create trial (if new), insert treatments, insert plots, set plot assignments by treatment_code.

## Entry points

- **Trial list (app bar):** “Import protocol” → create **new trial** from file (TRIAL section required).
- **Trial detail (Plots tab):** “Import Protocol (Treatments + Plots)” → add to **existing trial** (TRIAL section ignored).
