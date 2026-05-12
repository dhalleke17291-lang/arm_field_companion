# Export Surface Audit

**Investigation date:** 2026-04-23 (extended with **Export Flow Design Issues** section same date)  
**Scope:** Read-only code and git history; no fixes applied.  
**Runtime reproduction (Part 2D):** Not executed in this pass (no simulator/device session with the specified ARM trial). Findings for 2D are limited to code-path analysis and test inventory.

---

## Part 1: Export path inventory

### Summary table (quick reference)

| # | Screen / surface | UI label (user sees) | Primary format(s) |
|---|------------------|----------------------|-------------------|
| 1 | `TrialDetailScreen` | Export formats from bottom sheet (`ExportFormat.label`) | CSV bundle, ZIP/handoff, PDFs, JSON, Rating Sheet (Excel) |
| 2 | `TrialDetailScreen` (portfolio header menu) | `Closed Sessions (CSV ZIP)`, `Closed Sessions (XML ZIP)` | ZIP of session CSVs / ZIP of session XML |
| 3 | `TrialListScreen` | Toolbar: “Export closed sessions (ZIP per trial)” | ZIP per trial (closed session CSVs) |
| 4 | `ArmExportPreflightScreen` | Flow title: `Export Rating Sheet` | `.xlsx` (filled rating shell) |
| 5 | `SessionDetailScreen` | App bar menu: `Session Data (CSV)`, `Session (XML)` | `.csv`, `.xml` |
| 6 | `PlotQueueScreen` | Session export control (after trust flow) | Session `.csv` |
| 7 | `SessionSummaryScreen` | Share menu: `Share session grid (PDF)`, `Share ratings (CSV)`, `Copy ratings to clipboard`; dialog `Share session summary?` | PDF, CSV, TSV (clipboard), plain text |
| 8 | `AuditLogScreen` | PDF export action | `.pdf` |
| 9 | `DiagnosticsScreen` | Share diagnostics report | Plain text (share sheet) |
| 10 | `RecoveryScreen` | Recovery export actions | Recovery `.zip` |
| 11 | `MoreScreen` / backup flow | `Backup` → encrypted file | `.agnexis` (share) |

Additional formats appear as `ExportFormat` enum values (`lib/features/export/export_format.dart`): `flatCsv`, `armHandoff`, `pdfReport`, `evidenceReport`, `trialReport`, `armRatingShell` — surfaced on the trial export sheet where workspace rules allow (`exportFormatsForTrialSheet` in `lib/core/workspace/workspace_config.dart`).

---

### 1 — Trial-level export sheet (`TrialDetailScreen`)

1. **Entry point:** `TrialDetailScreen` → user taps export (e.g. readiness flow then `_showExportSheet`). Format labels/descriptions from `ExportFormatDetails` (`lib/features/export/export_format.dart` lines 21–61).
2. **Code path:**
   - `_runExport` / `_onExportTapped` (`lib/features/trials/trial_detail_screen.dart` ~352–600, 562+).
   - `ExportFormat.armRatingShell` → `Navigator.push` to `ArmExportPreflightScreen` (~386–406).
   - `ExportFormat.pdfReport` → `exportTrialPdfReportUseCaseProvider` → `ExportTrialPdfReportUseCase.execute` (~417–424).
   - `ExportFormat.evidenceReport` → `ExportEvidenceReportUseCase.execute` (~427–434).
   - `ExportFormat.trialReport` → `ExportTrialReportUseCase.execute` (~437–444).
   - Other formats → `ExportTrialUseCase.execute` (~447–454); flat CSV branch writes multiple files then `Share.shareXFiles` (~456–501).
3. **Output formats:** Per selected `ExportFormat` (CSV multi-file, ZIP, PDF variants, xlsx for rating shell).
4. **Output filenames:** See Part 2A (trial PDF `AGQ_…`, flat CSV `${safeBase}_export_$timestamp_${name}.csv` at lines 460–488, etc.).
5. **Output structure:**
   - **Flat CSV:** Nine files listed in `trial_detail_screen.dart` lines 465–485 (`observations` … `data_dictionary`); schemas defined in `ExportTrialUseCase` data dictionary builder (`lib/features/export/export_trial_usecase.dart`, extensive `data_dictionary.csv` rows ~685+).
   - **ZIP / handoff:** See `_buildArmHandoffPackage` (`export_trial_usecase.dart` ~1752–1916): `README.txt`, CSV set, `arm_mapping.csv`, `import_guide.csv`, `validation_report.csv`, optional `statistics.csv`, `weather.csv`, `photos/…`.
   - **Field Report PDF:** `ReportPdfBuilderService._buildResearch` (`lib/features/export/report_pdf_builder_service.dart` ~584–619): cover, then sections Site Description, Treatments, Plot Layout, Seeding, Applications, Sessions, Assessment Results, Photos.
   - **Evidence / Trial Report PDF:** Separate builders (`export_evidence_report_usecase.dart`, `export_trial_report_usecase.dart`, `trial_report_pdf_builder.dart`).
   - **Rating shell xlsx:** Written by `ExportArmRatingShellUseCase` + `ArmValueInjector` (see entry 4).
6. **User-facing options:** Readiness sheet / precheck dialogs before export; ARM rating shell uses full preflight + optional enrichment dialog (see Part 2B); `ExportFormat.armRatingShell` blocked with snackbar if not ARM-linked (`trial_detail_screen.dart` ~374–382).
7. **Output location:** Mostly `getTemporaryDirectory()` for share-first artifacts (PDF, JSON, flat CSV in trial detail, rating shell); ZIP handoff uses temp (`export_trial_usecase.dart` ~1913–1914).
8. **Post-export handoff:** `Share.shareXFiles` or `Share.share` with snackbars (`Export ready to share`, format-specific strings).
9. **Error handling:** `ExportBlockedByValidationException` / `ExportBlockedByReadinessException` → snackbars with `Export blocked — …` (~508–536). Generic catch → `'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.'` (~538–548). `ExportBlockedByConfidenceException` from PDF use case follows same pattern when not caught earlier (PDF path uses `throw` in `export_trial_pdf_report_usecase.dart` ~47–49).

---

### 2 — Trial portfolio: closed-session batch (`TrialDetailScreen` header)

1. **Entry point:** `PopupMenuButton` with items `Closed Sessions (CSV ZIP)` and `Closed Sessions (XML ZIP)` (`trial_detail_screen.dart` ~3146–3218).
2. **Code path:** `exportTrialClosedSessionsUsecaseProvider` or `exportTrialClosedSessionsArmXmlUsecaseProvider` → `Share.shareXFiles` (~3178–3187).
3. **Output:** ZIP (`BatchExportResult`).
4. **Filenames:** Inner CSV/XML from session use cases; outer ZIP `AFC_trial_${safeName}_closed_${epoch}.zip` (`export_trial_closed_sessions_usecase.dart` ~93–97) or `AFC_trial_${safeName}_arm_xml_${epoch}.zip` (`export_trial_closed_sessions_arm_xml_usecase.dart` ~70–74).
5. **Structure:** ZIP of per-session exports (CSV or XML files named per session use case).
6. **Options:** None beyond menu choice.
7. **Location:** `getApplicationDocumentsDirectory()` for constituent files; ZIP path same dir.
8. **Handoff:** Share sheet; snackbar `Exported N sessions` on success (~3189–3192).
9. **Errors:** `result.errorMessage` in snackbar (~3195–3203); messages include `No closed sessions to export. Close sessions first.` from use cases.

---

### 3 — Trial list: export all trials’ closed sessions (`TrialListScreen`)

1. **Entry point:** `_PortfolioHeaderActions` tooltip `Export closed sessions (ZIP per trial)` (`trial_list_screen.dart` ~1003–1004); `_exportAllTrials` (~293+).
2. **Code path:** Iterates trials; `ExportTrialClosedSessionsUsecase` per trial; collects `XFile`s; `Share.shareXFiles` (~338).
3. **Output:** Multiple ZIP files (one per trial with closed sessions) in one share action.
4. **Filename:** Same as per-trial closed session ZIP inside use case.
5. **Structure:** Same as entry 2 (CSV path).
6. **Options:** None.
7. **Location:** Documents dir for each ZIP.
8. **Handoff:** Share sheet.
9. **Errors:** `No trials to export`, `No closed sessions…`, generic export failed string (`trial_list_screen.dart` ~298–358).

---

### 4 — ARM Rating Shell export (`ArmExportPreflightScreen` + use case)

1. **Entry point:** From trial detail when user picks `Rating Sheet (Excel)` → `ArmExportPreflightScreen` (`trial_detail_screen.dart` ~386–392). App bar title `Export Rating Sheet` (`arm_export_preflight_screen.dart` ~273–280).
2. **Code path:** Preflight UI → `_runExportCore` (~73–254) → optional enrichment dialog (~122–206) → `exportArmRatingShellUseCaseProvider.execute` (~208–214) → `ExportArmRatingShellUseCase.execute` (`lib/features/export/domain/export_arm_rating_shell_usecase.dart`) → `ArmValueInjector.inject` (~666–676).
3. **Output format:** `.xlsx`.
4. **Filename:** `${tempDir.path}/${safeName}_RatingShell.xlsx` (`export_arm_rating_shell_usecase.dart` ~658–664). `safeName` from trial name (~658–662).
5. **Output structure:** Copy of source shell ZIP with XML patches per `ArmValueInjector` (`lib/data/services/arm_value_injector.dart` ~61–67): **Plot Data** (required); optional **Applications**, **Treatments**, **Comments**, **Subsample Plot Data** when present and data supplied. Other workbook parts copied without decode (comment ~67).
6. **User-facing options:** File picker if no internal shell; `Export with warnings?` / `Export Anyway` for positional fallback (`arm_export_preflight_screen.dart` ~34–68); enrichment dialog (Part 2B); preflight findings on screen.
7. **Output location:** System temp (`getTemporaryDirectory()`).
8. **Handoff:** `Share.shareXFiles` with text `'${trial.name} – Excel Rating Sheet'` (~233–241); or use case shares when `suppressShare` false (`export_arm_rating_shell_usecase.dart` ~707–714).
9. **Error handling:** `ArmRatingShellResult.failure` messages (many; see Part 2E); preflight `_exportError` including generic catch string (~245–251) matching session export wording.

---

### 5 — Session detail: CSV and ARM XML (`SessionDetailScreen`)

1. **Entry point:** App bar `PopupMenuButton` tooltip `Export session` — items `Session Data (CSV)`, `Session (XML)` (`session_detail_screen.dart` ~297–321).
2. **Code path:** Trust confirm → `_exportCsv` (~576+) or `_exportArmXml` (~713+).
3. **Formats:** `.csv`, `.xml`.
4. **Filenames:** `AFC_export_${safeTrial}_${safeSession}_session_${sessionId}_$timestamp.csv` and `_audit_` variant (`export_session_csv_usecase.dart` ~193–214); XML `AFC_arm_export_…xml` (`export_session_arm_xml_usecase.dart` ~205–207).
5. **Structure:** CSV: dynamic headers from `ExportRepository.buildSessionExportRows` + metadata columns (`export_session_csv_usecase.dart` ~78–117). XML: custom `arm_export` element tree (`export_session_arm_xml_usecase.dart` ~64–174).
6. **Options:** `confirmSessionExportTrust` before export (~302–307).
7. **Location:** `getApplicationDocumentsDirectory()`.
8. **Handoff:** Dialog `Export Complete` / `XML Export Complete` with path + Share button (~622–689, ~754–795).
9. **Errors:** `Export Failed` dialog with `result.errorMessage` (~606–618, ~739–751); catch snackbars with generic “try again / check … records” (~690–703, ~797–808).

---

### 6 — Plot queue quick session CSV (`PlotQueueScreen`)

1. **Entry point:** Export button in session-complete / export UI (~880+).
2. **Code path:** `exportSessionCsvUsecaseProvider.exportSessionToCsv` (~893–905) → `Share.shareXFiles` (~934–938).
3. **Format / filename / location:** Same as session CSV use case; may pass `isSessionClosed` from session state (~903–904).
4. **Options:** Session export trust confirm before guard (~880–885).
5. **Errors:** SnackBar with `result.errorMessage` or generic export failed (~915–947).

---

### 7 — Session summary: PDF grid, CSV, TSV, text (`SessionSummaryScreen`)

1. **Entry point:** Popup menu tooltip `Share` — `Share session grid (PDF)`, `Share ratings (CSV)`, `Copy ratings to clipboard` (`session_summary_screen.dart` ~1097–1179). Plain text: dialog `Share session summary?` (~607–627) → `Share.share` (~664).
2. **Code path:** PDF: `SessionGridPdfExport.build` → temp `grid_$sanitizedName.pdf` (~697–728). CSV: `ExportTrialRatingsShareUseCase.buildCsv` → `${sanitizedTrial}_ratings.csv` (~754–762). TSV: `buildTsv` → clipboard (~789–794). Text: `composeSessionSummary` (~650–661).
3. **Formats:** PDF, CSV, TSV (clipboard), plain text.
4. **Filenames:** As above (~725–727, ~760–762).
5. **Structure:** Grid PDF internal to `session_grid_pdf_export.dart`; CSV/TSV from `export_trial_ratings_share_usecase.dart`; text from `session_summary_share.dart`.
6. **Options:** Dialog for text summary; menu for file formats.
7. **Location:** Temp for PDF/CSV.
8. **Handoff:** `Share.shareXFiles` or `Share.share` / `Clipboard`.
9. **Errors:** `Export failed: $e`, `CSV export failed: $e`, `Share failed: $e`, `Copy failed: $e` (~667–668, ~746–747, ~779–780, ~804–805) — **exception text can leak to UI**.

---

### 8 — Audit log PDF (`AuditLogScreen`)

1. **Entry point:** Export control that builds `AuditLogPdfExport` (`audit_log_screen.dart` ~145–188).
2. **Code path:** Query `auditEvents` → `AuditLogPdfExport.build` → write file → `Share.shareXFiles`.
3. **Format:** PDF.
4. **Filename:** `trial_${trialId}_audit_$safeStamp.pdf` or `agnexis_audit_$safeStamp.pdf` (~175–179).
5. **Structure:** PDF from `audit_log_pdf_export.dart` (not fully expanded here).
6. **Options:** Scoped to trial vs all (`trialId` filter ~148–151).
7. **Location:** `getTemporaryDirectory()`.
8. **Handoff:** Share + snackbar `Exported N events as PDF` (~190–194).
9. **Errors:** `Nothing to export.` (~159); `Export failed: $e` (~199–204).

---

### 9 — Diagnostics text report (`DiagnosticsScreen`)

1. **Entry point:** `_exportReport` (~101+).
2. **Code path:** Builds string buffer → `Share.share` (~124–128).
3. **Format:** Plain text (not a file path shown).
4. **Filename:** N/A (share text).
5. **Structure:** Header + integrity summary + recent errors.
6. **Options:** None.
7. **Location:** N/A.
8. **Handoff:** System share; snackbar `Export opened` (~130–132).
9. **Errors:** Generic export failed snackbar (~136–144) — wording references “trial data” though this is diagnostics.

---

### 10 — Recovery ZIPs (`RecoveryScreen`)

1. **Entry point:** Actions invoking `exportDeletedSessionRecoveryZipUsecaseProvider` / `exportDeletedTrialRecoveryZipUsecaseProvider` (`recovery_screen.dart` ~500+).
2. **Code path:** Use cases build ZIP with `sessions.csv`, `trials.csv`, `rating_records.csv`, `manifest.csv`, `README.txt` (session path: `export_deleted_session_recovery_zip_usecase.dart` ~225–230).
3. **Format:** ZIP.
4. **Filename:** `${prefix}_recovery_deleted_session_${sessionId}_${epoch}.zip` (~238–239); trial variant in `export_deleted_trial_recovery_zip_usecase.dart`.
5. **Structure:** Documented in README inside ZIP (~205–223).
6. **Options:** None beyond choosing deleted entity.
7. **Location:** `getApplicationDocumentsDirectory()`.
8. **Handoff:** Dialog with path + Share (~521–571, ~628–678).
9. **Errors:** `Export Failed` dialog with `result.errorMessage` (~503–517, ~610–624).

---

### 11 — Backup (`more_backup_actions.dart`)

1. **Entry point:** More → Backup flow.
2. **Code path:** `backupServiceProvider.createBackup` → `Share.shareXFiles` with `.agnexis` (~132–158).
3. **Format:** Encrypted backup (octet-stream MIME ~153).
4. **Filename:** Determined inside `BackupService` (not traced line-by-line in this audit).
5. **Structure:** ZIP payload encrypted per `backup_encryption.dart`.
6. **Options:** Passphrase, clear-audit preference, reminder store.
7. **Location:** File path from service; share sheet.
8. **Handoff:** Share; snackbars for dismiss / complete (~163–187).
9. **Errors:** `Backup Failed` dialog (~194+).

---

## Part 2: Specific investigations

### 2A: Filename construction sites

**Centralization:** Filename patterns are **scattered** per use case; there is no single export filename utility (contrast with shared helpers like `_safeFilePart` only within some use cases).

**Literal / pattern index (non-exhaustive but covers primary exports):**

| Pattern / extension | File | Line(s) | Construction |
|---------------------|------|---------|--------------|
| `_RatingShell.xlsx` | `lib/features/export/domain/export_arm_rating_shell_usecase.dart` | 658–664 | `'$tempDir/${safeName}_RatingShell.xlsx'` |
| `AGQ_${safeName}_$timestamp.pdf` | `lib/features/export/export_trial_pdf_report_usecase.dart` | 60–64 | Field Report PDF |
| `AGQ_${safeName}_$timestamp.zip` | `lib/features/export/export_trial_usecase.dart` | 1911–1914 | Handoff / photo ZIP |
| `${safeBase}_export_$timestamp_${name}.csv` | `lib/features/trials/trial_detail_screen.dart` | 460–488 | Flat CSV bundle |
| `Evidence_${safeName}_$timestamp.pdf` | `lib/features/export/export_evidence_report_usecase.dart` | 28–32 | Evidence PDF |
| `TrialReport_${safeName}_$timestamp.pdf` | `lib/features/export/export_trial_report_usecase.dart` | 95 | Trial Report PDF |
| `AFC_export_…session_….csv` | `lib/features/export/domain/export_session_csv_usecase.dart` | 193–195 | Session CSV |
| `…_audit_….csv` | same | 212–214 | Session audit CSV |
| `AFC_arm_export_….xml` | `lib/features/export/domain/export_session_arm_xml_usecase.dart` | 205–207 | Session XML |
| `AFC_trial_${safeName}_closed_….zip` | `lib/features/export/domain/export_trial_closed_sessions_usecase.dart` | 93–97 | Batch CSV ZIP |
| `AFC_trial_${safeName}_arm_xml_….zip` | `lib/features/export/domain/export_trial_closed_sessions_arm_xml_usecase.dart` | 70–74 | Batch XML ZIP |
| `grid_$sanitizedName.pdf` | `lib/features/sessions/session_summary_screen.dart` | 725–727 | Session grid PDF |
| `${sanitizedTrial}_ratings.csv` | same | 760–762 | Trial ratings CSV |
| `trial_${id}_audit_$stamp.pdf` / `agnexis_audit_…` | `lib/features/diagnostics/audit_log_screen.dart` | 175–179 | Audit PDF |
| Recovery ZIP | `lib/features/export/domain/export_deleted_session_recovery_zip_usecase.dart` | 238–239 | `_recoveryZipNamePrefix()_recovery_deleted_session_…` |
| `shell_import_….xlsx` | `lib/features/import/ui/import_trial_sheet.dart` | 91 | **Import** (not export; listed for symmetry with rating shell) |
| `filled_*.xlsx` (tests) | `test/data/arm_value_injector_test.dart` | 43, 71, 100 | Test temp files only |

**Note:** `safeName` / `safeBase` sanitizers **differ** between files (e.g. PDF use case `[^a-zA-Z0-9_-]` vs rating shell `[^\w\s-]` then spaces → underscores) — inconsistency risk for the same trial name across formats.

---

### 2B: “Enrichment” branch (ARM rating shell export)

- **Where in UI:** `ArmExportPreflightScreen._runExportCore` (`arm_export_preflight_screen.dart` ~122–157). Dialog title `Rating Sheet Data`, body `Rating sheet data available. Enrich trial before export?` Actions: `Cancel`, `Export Without Enriching`, `Enrich & Export`.
- **What “enriched” means in code:** If user chooses `Enrich & Export`, `ArmShellLinkUseCase.apply(trial.id, shellPath)` runs (~165–166). That applies `ShellLinkPreview` changes to the **database** (trial setup fields, assessment fields, column mappings, etc.) inside a transaction (`arm_shell_link_usecase.dart` ~82+). It does **not** change the Excel export algorithm itself.
- **What “non-enriched” means:** `apply` is skipped; export proceeds with current DB state relative to the selected shell file.
- **ARM-compatible output:** Both branches invoke the same `ExportArmRatingShellUseCase.execute` and `ArmValueInjector` on the chosen shell path. Compatibility is a function of shell file + DB state, not a separate workbook template for “enriched.”
- **Git history:** `git log -S 'Enrich' -- lib/features/export/arm_export_preflight_screen.dart` shows introduction in commit `213cc3e` (“feat: Agnexis v1 — complete field trial execution platform”, 2026-04-12). Dialog text is not explained in code comments beyond `shouldOfferShellMetadataEnrichmentBeforeExport` (`arm_shell_metadata_enrichment.dart` ~11–31): offer when preview can apply, has changes, and trial is not already linked to the **same** shell path.
- **Would users understand from UI alone:** The dialog does **not** state that “enrich” updates **trial and assessment records in the app** from the spreadsheet. A reader may infer spreadsheet-only behavior. **No speculation** on intent beyond what the code does.

---

### 2C: File `AgQuest_Demo_Trial_RatingShell.xlsx`

- **Producing path:** Only `ExportArmRatingShellUseCase` builds the `_RatingShell` suffix (`export_arm_rating_shell_usecase.dart` ~658–664). Entry: trial export → `ArmExportPreflightScreen` → use case (see Part 1 entry 4).
- **Filename history:** The initial platform commit `213cc3e` emitted `_RatingShell_filled.xlsx`; the `_filled` token was removed to match ARM's `*_RatingShell.xls*` file-picker pattern (see **H**). Current production output is `${safeName}_RatingShell.xlsx`.
- **Natural workflow:** Yes for ARM-linked trials: user selects **Rating Sheet (Excel)** on the trial export sheet, completes preflight, shares file.
- **Sibling filename variants:** Other exports use `AGQ_…`, `AFC_…`, `TrialExport_…`, `Evidence_…`, etc. (Part 2A). No second rating-shell filename pattern in production code besides `${safeName}_RatingShell.xlsx`.

---

### 2D: Field Report PDF failure on ARM-imported trial

**Not reproduced** in this investigation (no runtime session).

**Code basis for narrowing future reproduction:**

- **Use case:** `ExportTrialPdfReportUseCase.execute` (`export_trial_pdf_report_usecase.dart` ~43–75): gates on ARM compatibility profile (`ExportGate.block` → `ExportBlockedByConfidenceException` ~47–49); then `ReportDataAssemblyService.assembleForTrial` ~56; then `ReportPdfBuilderService.build` ~57.
- **Field Report PDF sections (research profile):** Order in `_buildResearch` (`report_pdf_builder_service.dart` ~597–615):  
  1) Cover (`_buildCover` ~599)  
  2) Site Description (~601)  
  3) Treatments (~603)  
  4) Plot Layout (~605)  
  5) Seeding (~607)  
  6) Applications (~609)  
  7) Sessions (~611)  
  8) Assessment Results (~613)  
  9) Photos (~615)  

  **Note:** The brief’s “13 sections” matches **Evidence Report** (`evidence_report_pdf_builder.dart` ~58–139: Completeness + sections 1–13), **not** the Field Report PDF builder.

- **Empty ratings:** `_buildAssessmentSection` handles empty `data.ratings` with a note (`report_pdf_builder_service.dart` ~1137–1138), so “no ratings” alone does not imply a throw from that branch.
- **User-visible error on failure:** `TrialDetailScreen` catch-all replaces the exception with the generic snackbar (~538–548); the **actual** exception type/message is **not** shown.

**Observed automated tests:** `test/features/export/export_trial_pdf_report_usecase_test.dart`, `test/features/export/report_pdf_builder_service_test.dart` exist — **not re-run as part of this audit document**; they can support regression once a failure is captured.

**States tested in this audit:** None (device/simulator).

---

### 2E: Error message inventory (export-related)

**Categories:**

- **Blocked / validation:** `Export blocked — resolve these issues first:\n${e.message}` (`trial_detail_screen.dart` ~515); `Export blocked — ${e.message}` (~530); `Export blocked — data needs review before rating sheet round-trip.` (`export_confidence_policy.dart` ~23–24) and composed message (~31–34); rating shell strict blocks (`arm_rating_shell_export_block_policy.dart` ~86–124).
- **Generic retry:** `'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.'` appears in `trial_detail_screen.dart` ~545, `session_detail_screen.dart` ~697, `plot_queue_screen.dart` ~944, `arm_export_preflight_screen.dart` ~249–250, `export_session_csv_usecase.dart` ~175, `trial_list_screen.dart` ~358, `diagnostics_screen.dart` ~140 (misleading context: diagnostics, not trial).
- **Session closed:** `'Session must be closed before export. Close the session first.'` (`export_session_csv_usecase.dart` ~73–74, `export_session_arm_xml_usecase.dart` ~50–51).
- **Rating shell specific:** `ArmRatingShellResult.failure` strings including `No plots found for trial.`, `No assessments found for trial.`, `No assessment columns could be determined.`, `Export cancelled.`, strict block messages, `No rating values could be written…` (`export_arm_rating_shell_usecase.dart` ~192, ~206, ~278–279, ~306, ~701–703, etc.).
- **Recovery / ZIP:** `ZIP encoding failed.`, `Recovery export failed: …` (`export_deleted_session_recovery_zip_usecase.dart` ~234, ~244–245).
- **XML export failure:** Dialog may show `XML export failed: ${e.toString()}\n…` from use case (`export_session_arm_xml_usecase.dart` ~187–189) — **technical detail surfaced**.
- **Leaked exceptions:** `Export failed: $e`, `CSV export failed: $e`, `Share failed: $e`, `Export failed: $e` audit log (`session_summary_screen.dart`, `audit_log_screen.dart`).

**Flagged for rewrite (severity heuristic):**

1. **High:** Generic “try again / check trial data” used when the real failure is confidence block, strict structural block, or PDF assembly — hides root cause (`trial_detail_screen`, `arm_export_preflight_screen`, `export_session_csv_usecase` catch-all).
2. **High:** Diagnostics export uses trial-data wording (`diagnostics_screen.dart` ~140).
3. **Medium:** `$e` in SnackBars (`session_summary_screen`, `audit_log_screen`) — technical leakage.
4. **Medium:** XML failure message includes stack fragments (`export_session_arm_xml_usecase.dart` ~189).

Sorted frequency: the long generic “Export failed — please try again…” string is duplicated across **many** call sites (grep in repo).

---

## Part 3: Redundancy and legacy check

| Item | Observation | Candidate |
|------|-------------|-----------|
| Session CSV | Implemented in `SessionDetailScreen` (dialog + share) and `PlotQueueScreen` (direct share) | Consolidate UX only; same use case |
| Closed sessions ZIP | Available from **trial list**, **trial detail portfolio menu**, same `ExportTrialClosedSessionsUsecase` | Redundant entry points (intentional?) |
| Flat CSV vs ZIP handoff | Overlapping tabular data; handoff adds mapping, validation, photos | Design: keep both vs document difference only |
| `ReportProfile` stubs | `_buildStubPage` for interim/glpAudit/cooperator (`report_pdf_builder_service.dart` ~74–81, ~567–581) | Partially implemented profiles |
| Trial Report PDF vs Field Report | Different products (`trial_report_pdf_builder.dart` vs `report_pdf_builder_service.dart`) | Not redundant; naming easily confused |
| Session grid PDF vs Field Report PDF | Different scope (one session grid vs full trial) | Not redundant |
| Diagnostics “export” | Text share, not file export | Naming only |

**Orphaned code:** Not exhaustively proven; `ReportProfile` non-research paths are stubbed but still reachable if `build` is called with those enums.

---

## Part 4: Round-trip and data integrity (ARM rating shell)

**Verified from code (not binary diff of files):**

- **Sheets preserved:** `ArmValueInjector` copies the xlsx archive and replaces selected worksheet XML entries (`arm_value_injector.dart` ~61–67, ~93–95). Sheets **not** listed there are copied as part of the ZIP without XML rewrite.
- **Sheets written:** Plot Data (required); Applications, Treatments, Comments, Subsample Plot Data when present and inputs non-empty; injector logs skip reasons when sheets missing (`~176–181`, `~219–226`, `~257–263`, `~316–322`).
- **Treatment Means / Subsample Treatment Means:** **Not** referenced in `ArmValueInjector` or `ArmShellImport` field names — parser/import model covers Plot Data, Subsample Plot Data, Treatments sheet rows, Applications, Comments (`arm_shell_import.dart` ~28–52). **No code path** in this audit writes “Treatment Means” or “Subsample Treatment Means” worksheets.
- **Column ID addressing:** Plot Data uses `armColumnId` → column index map from parsed shell (`arm_value_injector.dart` ~115–119) with positional fallback when shell columns empty (see use case `effectiveColumns` ~371–385).
- **Empty cells:** `armRatingShellCellValueFromRating` drives cell text; empty values typically skipped or written as empty per injector logic (see tests `test/data/arm_value_injector_test.dart` — cited as test evidence, not re-run here).
- **UTF-8 BOM / XML:** Session CSV/XML use `writeAsString`; handoff ZIP uses `utf8.encode` without BOM for embedded CSV. **xlsx** is ZIP of XML; injector re-encodes modified sheets — **byte-for-byte identity** for unmodified parts is design intent (~67); **not** verified with hex diff in this audit.

**Gaps:** Round-trip **loss** or **misalignment** scenarios are documented in strict block / warning paths (`arm_rating_shell_export_block_policy`, positional fallback warnings) — empirical verification needs fixture trials.

---

## Part 5: Summary and Proposed Action Plan

### 1. Confirmed bugs / risks (severity)

- **Pilot-blocking (pending repro):** Field Report PDF failure on specific ARM trials — **not confirmed in code** without stack trace (Part 2D).
- **Serious:** Filename sanitization **inconsistent** across exports (Part 2A); users may not recognize related exports as same trial.
- **Serious:** Generic export error strings **hide** `ExportBlockedByConfidenceException` and PDF/assembly failures (`trial_detail_screen` catch-all).
- **Minor:** Diagnostics export error text references “trial data” (`diagnostics_screen.dart` ~140).

### 2. Design decisions needed

- **Enrichment dialog:** Keep both options but **rename/explain** that “Enrich” updates **app trial/assessment data** from the sheet (based on code behavior in Part 2B).
- **Field Report vs Evidence Report:** Clarify internally that “13 sections” applies to **Evidence** PDF, not **Field Report** (8 content blocks after cover in research profile).
- **Treatment Means sheets:** Whether export should ever write ARM “Treatment Means” / “Subsample Treatment Means” — **currently absent** from injector (Part 4).

### 3. Paths to remove or consolidate (candidates only)

- Duplicate **session CSV** UX (plot queue vs session detail).
- Multiple **closed-session ZIP** entry points — keep if intentional for discoverability.

### 4. Error messages to rewrite (priority)

1. Generic `Export failed — please try again…` (trial detail, preflight, session export catch, plot queue, trial list).
2. Diagnostics share failure message (wrong domain).
3. `Export failed: $e` / `Share failed: $e` style leakage.

### 5. Proposed fix order (rough estimates; for review only)

1. Reproduce Field Report PDF on ARM trial + capture stack (2–4h).
2. Unify or document filename sanitization rules (2–4h).
3. Map catch blocks to typed failures with user-facing copy (4–8h).
4. Enrichment dialog copy + optional telemetry (1–2h).
5. Decide Treatment Means sheet scope + implement or document omission (TBD).

### 6. Open questions for Parminder

1. Should **Field Report PDF** enforce the same ARM confidence **block** as rating shell export, or is PDF intentionally allowed when confidence is `blocked`? (Currently **PDF use case checks profile** `export_trial_pdf_report_usecase.dart` ~44–49.)
2. Is **omission** of Treatment Means / Subsample Treatment Means sheets acceptable for pilot, or required for ARM parity?
3. Preferred **single source of truth** for export filename sanitization?

---

## Export Flow Design Issues and Proposed Redesign

**Nature of this section:** Design investigation and proposals only — **no implementation** in this pass. Each subsection cites current code behavior, states the user-visible problem, proposes a change, estimates effort, and notes dependencies.

---

### A. Rating Sheet export and the external file picker

#### Current behavior (code)

- On export, `ArmExportPreflightScreen._runExportCore` resolves `shellPath` as follows (`lib/features/export/arm_export_preflight_screen.dart` ~82–100):
  - If `arm_trial_metadata.shellInternalPath` is non-empty **and** `File(internalPath).existsSync()`, that path is used — **no picker**.
  - Otherwise **`FilePicker.pickFiles`** runs with `dialogTitle: 'Select Excel Rating Sheet for ${widget.trial.name}'`.
- The app **does** persist a copy of the imported shell: `ShellStorageService.storeShell` writes `{appDocuments}/shells/{trialId}.xlsx` (`lib/data/services/shell_storage_service.dart` ~10–21). Import links `shellInternalPath` and `armLinkedShellPath` on `arm_trial_metadata` (`import_arm_rating_shell_usecase.dart` ~637–638 context per prior audit).
- **`ExportArmRatingShellUseCase`** always needs a **filesystem path** to an existing `.xlsx`: it constructs `ArmShellParser(shellPath)` and reads bytes; `ArmValueInjector` reads the shell file from disk (`lib/data/services/arm_value_injector.dart` ~93–95). Bridge tables (`arm_column_mappings`, `arm_assessment_metadata`, etc.) hold **structural metadata**, not the full Open XML workbook.

#### User-facing problem

Researchers see a file picker even when they already imported a shell, if `shellInternalPath` is null, points at a missing file (reinstall, cache clear, failed copy), or predates internal storage. That feels like the app “forgot” the protocol file.

#### Design proposal

1. **Primary path:** Treat **internal stored shell** as mandatory for ARM-linked trials after successful import. If `shellInternalPath` is missing but `ShellStorageService.resolveShellPath(trialId)` returns a path, **repair** the DB pointer (separate small migration/repair task). Only show picker when **no** internal file can be resolved.
2. **Transparency:** When using internal path, show read-only UI: “Using rating sheet stored with this trial” + optional filename from `armLinkedShellPath` basename — so users know no external file is required.
3. **Reconstruct-from-DB-only:** **Not supported today.** Producing an ARM-compatible `.xlsx` from mappings + ratings alone would require a **new generator** (worksheet layout, shared strings, styles, ARM-specific headers). That is **not** `ArmValueInjector` (which patches an existing workbook). Effort: **multi-week** if ARM layout fidelity is required; depends on ARM template contracts.

#### Standalone trials

- `ExportArmRatingShellUseCase` **rejects** non–ARM-linked trials (`export_arm_rating_shell_usecase.dart` ~111–115: `StateError`). The trial export sheet adds `armRatingShell` only when ARM-linked (`workspace_config.dart` / `exportFormatsForTrialSheet`).
- **Conclusion:** There is **no** current path to emit a rating shell for standalone trials. A generator would lack ARM vocabulary from a protocol import; “ARM-compatible” output would be undefined without product spec.

#### Effort & dependencies

| Item | Estimate | Depends on |
|------|----------|------------|
| Picker only when internal file truly absent + repair pointer | **0.5–1 day** | QA on fresh import, restore-from-backup, edge cases |
| UI copy for “using stored sheet” | **few hours** | None |
| Full xlsx generation from DB (standalone or ARM) | **weeks** | ARM layout spec, legal/compliance sign-off |

---

### B. “Enrich & Export” semantics and UI

#### Current behavior (code)

- Dialog title `Rating Sheet Data`, body `Rating sheet data available. Enrich trial before export?` (`arm_export_preflight_screen.dart` ~131–135).
- **Enrich & Export** calls `ArmShellLinkUseCase.apply` (`~165–166`), which writes trial/assessment/column metadata from the **parsed shell** into the **database** (`arm_shell_link_usecase.dart` ~82+). Export then runs the same `ExportArmRatingShellUseCase` as “export without enriching.”

#### User-facing problem

Users are not told that **Enrich** changes **in-app trial and assessment records**, not just the Excel file. “Rating sheet data” sounds like spreadsheet-only behavior.

#### Proposed replacement copy (for review)

**Title:** `Update trial from this sheet?`

**Body:**  
`The selected rating sheet has site or assessment details that differ from what is saved in the app. You can update the trial in the app to match the sheet before exporting, or export using the data already in the app without updating.`

**Buttons:** `Cancel` · `Export without updating` · `Update app, then export`

*(Tone: researcher-facing; avoids “enrich”; states mutation explicitly.)*

#### Separate action vs. branch of export

| Approach | Pros | Cons |
|----------|------|------|
| **Keep in export flow** | One place to discover; fewer navigation changes | Conflates “sync metadata” with “ship file”; easy to tap wrong button |
| **Separate “Sync from sheet…” under trial / ARM Protocol** | Deliberate maintenance action; export stays “export only” | Discovery; must still pick shell file if internal missing |

**Proposal:** Medium-term, add a **dedicated “Apply sheet metadata”** (or reuse link preview) on ARM protocol / trial setup; keep a **shortened** export-time prompt only when `shouldOfferShellMetadataEnrichmentBeforeExport` is true and internal shell differs from last linked path (`arm_shell_metadata_enrichment.dart` ~16–31). **Dependency:** Product decision on discoverability vs. simplicity.

#### Effort

- Copy + button labels only: **0.5 day**
- Separate entry point + navigation: **2–4 days** (plus QA)

---

### C. Warning quality, “Export Anyway,” and positional matching

#### Current behavior (code)

- Preflight merges findings from: import confidence gate, **trial readiness** checks, **round-trip diagnostics**, strict block, **export validation** (`arm_export_preflight_usecase.dart` ~148–223). Items split into blockers / warnings / infos by `DiagnosticSeverity` (~227–232).
- If **`warningCount > 0`**, `_ActionBar` shows **Export Anyway** as the primary CTA and **hides** the normal **Export** button (`arm_export_preflight_screen.dart` ~739–761). **Export Anyway** calls `_runExportAnyway` → confirmation dialog (`~34–68`) whose text is **fixed**: *“This export may use positional column matching…”* — even when warnings are unrelated (e.g. import confidence, `arm_import_session_id`, readiness).
- Actual **positional fallback** is determined **during** `ExportArmRatingShellUseCase` when the matcher uses positional columns (`export_arm_rating_shell_usecase.dart` ~529–576); it is **not** fully knowable from preflight alone for all cases.

#### User-facing problem

Any warning forces a scary, **positional-specific** confirmation. Users learn to dismiss it — **alert fatigue** and loss of trust when a real positional risk exists.

#### Per-warning-type guidance (rating shell / preflight pipeline)

| Source | Trigger (code) | Always-on? | Proposal |
|--------|------------------|------------|----------|
| Import confidence `low` | `gate == ExportGate.warn` → `kWarnExportMessage` (`arm_export_preflight_usecase.dart` ~158–163) | Conditional on profile | Keep conditional; **do not** chain to positional dialog; use separate copy |
| Round-trip: `armImportSessionId` missing | `pinned == null` (`compute_arm_round_trip_diagnostics_usecase.dart` ~196–207) | Conditional | **Downgrade to info** when export session still resolves; plain language (see D) |
| Round-trip: invalid pinned session | `pinned != null && resolved != pinned` (~210–223) | Conditional | Keep warning; actionable: “Choose session” or fix metadata |
| Round-trip: duplicate/missing plot or column indexes | `_applyPlotRules` / `_applyAssessmentColumnRules` (~82–183) | Conditional | Keep; strict gate may already block export |
| Readiness / validation warnings | `TrialReadinessService`, `ExportValidationService` (~166–222) | Conditional | Map each to researcher action; **never** use positional dialog as umbrella |
| Positional fallback (at export time) | Matcher `wasPositionalFallback` (~502+) | Conditional | Show **only if** fallback occurred; dedicated short copy |

**Design change (summary):**

1. **Decouple** “acknowledge warnings” from “positional risk.” Use **Export** with inline acknowledgment of **specific** warning categories, or a summary sheet listing codes.
2. **Replace** the single positional dialog with: (a) if no positional risk predicted, no extra dialog; (b) if positional risk flags exist in preflight or export, show **targeted** copy once.

#### Effort

- Refactor action bar + dialog gating: **1–2 days**
- Message rewrite + severity re-tiering: **1–2 days**
- **Depends on:** Product list of which findings must block vs. inform

#### Plain-language example (positional)

**Instead of:** “positional column matching” (jargon)  
**Proposed:** `One or more ratings could not be matched to a unique column on the sheet using the protocol’s column IDs. The app may place values by column order instead. Only continue if the sheet’s column order matches the trial you imported.`

---

### D. Internal field names in user-facing text

#### Current behavior (code)

- `ComputeArmRoundTripDiagnosticsUseCase` emits messages containing **`arm_trial_metadata.arm_import_session_id`** (`compute_arm_round_trip_diagnostics_usecase.dart` ~201–202, ~215–216). These flow into preflight **Warnings** via `toDiagnosticFindings()` (~178–179).
- Details may expose **`TrialAssessment ids`**, **`Plot ids`** (`~110–111`, ~157–158) — more acceptable for support, but still technical.

#### User-facing problem

Researchers see database/table/column names and assume a bug or internal tool leak — **trust damage**.

#### Proposed rewrites (examples; for review)

| Code reference | Current `message` (abridged) | Proposed researcher-facing text |
|----------------|------------------------------|-----------------------------------|
| ~201–202 | `arm_trial_metadata.arm_import_session_id is not set; shell export session is inferred.` | `No primary rating session is pinned for this protocol. The app will use the session it can match to your imported rating sheet.` |
| ~215–216 | `arm_trial_metadata.arm_import_session_id ($pinned) does not match...` | `The pinned rating session no longer matches an open session in this trial. Export will use session [name or date] instead. Update the pinned session in trial settings if that is wrong.` |
| ~157–158 | `… no armImportColumnIndex` | `One or more assessments are not linked to a column on the rating sheet. Link columns in the protocol setup before exporting.` |

**Effort:** **0.5–1 day** (copy + QA all round-trip messages)  
**Depends on:** Whether **detail** lines stay visible in a “Technical details” collapsible for support.

---

### E. “Complete Data Package” vs “Data + Photos (ZIP)” — overlap

#### Current behavior (code)

- `ExportTrialUseCase.execute` sets `armAligned = (format == ExportFormat.armHandoff)` (`export_trial_usecase.dart` ~327–328). That branch calls `_buildArmHandoffPackage` + `Share.shareXFiles` with text `'${trial.name} – Import Assistant package'` (~524–537).
- The former duplicate ZIP export was removed; the remaining ZIP-like trial export path is `armHandoff`.
- UI strings differ only in `ExportFormatDetails` (`export_format.dart` ~26–30, ~46–50): labels **Complete Data Package** vs **Data + Photos (ZIP)** and different marketing descriptions.

#### User-facing problem

Two options imply different products; **behavior is the same** — violates expectations and complicates training.

#### Design proposals (pick one)

1. **Consolidate:** Single ZIP export label, e.g. **Trial data package (ZIP)**; one description listing CSVs + photos + mapping + validation.
2. **Differentiate in code:** If product truly wants two products, **split implementation** (e.g. photos optional only for a separate package export, or handoff excludes statistics for ARM — today statistics already omitted when `trialIsArmLinked` in bundle ~492–495, 1793–1795).
3. **Deprecate one enum:** Migrate workspaces to one `ExportFormat`; remove the other after a release.

#### Effort

- **Documentation + UI merge only:** **0.5 day**
- **Behavioral split + QA:** **2–5 days** (if product needs real distinction)

#### Dependencies

- Workspace defaults list `armHandoff` for variety/efficacy/glp; standalone has no ZIP-like trial export after duplicate removal.

---

### F. Warnings on a “complete” trial (e.g. 16/16 plots rated)

**Note:** The screenshot described in the brief was **not** available in this pass. The following is derived from **which findings are merged into preflight warnings** and their **logical relationship to plot completion**.

Preflight **never** uses “all plots rated” to suppress structural diagnostics. **Rating completeness** and **protocol linkage completeness** are independent.

#### Plausible contributors to multiple warnings when all plots are rated

| # | Finding source | Example `code` / origin | Fires when trial “complete”? | Researcher action | Info vs. warning proposal |
|---|----------------|-------------------------|------------------------------|-------------------|---------------------------|
| 1 | Import profile | `arm_confidence_warn` | Yes, if `exportConfidence == 'low'` | Re-import / resolve import report | **Warning** until profile reviewed; optional one-time dismiss |
| 2 | Round-trip | `arm_round_trip_arm_import_session_id_missing` | **Yes** — pinned session is optional | Pin correct session in metadata (if product adds UI) or accept inferred session | Often **Info** if export session resolves |
| 3 | Round-trip | `arm_round_trip_shell_session_resolved_by_heuristic` | Yes | Same as #2 | **Info** (expected when #2 true) |
| 4 | Readiness | Various `TrialReadinessService` checks | Yes (e.g. optional site fields, photos, applications) | Complete optional protocol sections | Split: **actionable warning** vs. **completeness info** |
| 5 | Export validation | `ExportValidationService` warnings | Yes (e.g. non-blocking data quirks) | Per-message | Tune severity in validation rules |

**Positional matching** text appears in **Export Anyway** dialog, not necessarily as five separate preflight rows — but it **amplifies** fatigue for any of the above.

#### Design proposal (thresholds)

1. Introduce **“Export-ready”** vs **“Protocol complete”**: allow export with **infos** without treating them like **warnings** for CTA purposes.
2. **Suppress or downgrade** `armImportSessionId` missing when `resolvedShellSessionId != null` and session ratings are all `RECORDED` for data plots (policy decision — verify with data integrity owner).
3. **Do not** use a single **positional** dialog as the gate for unrelated warnings (see C).

#### Effort

- Policy matrix + severity tweaks: **1–3 days**
- **Depends on:** Clinical/compliance stance on exporting with “low” confidence profile

---

### G. Implementation task scoping (after approval)

| Decision | Scopable task |
|----------|----------------|
| Eliminate unnecessary picker | Repair `shellInternalPath`, picker fallback UX, telemetry when file missing |
| Enrichment UX | Copy swap **or** separate “Sync from sheet” flow |
| Warnings / Export Anyway | Refactor `_ActionBar` + dialog; per-category acknowledgment |
| ZIP consolidation | Remove duplicate format **or** implement real behavioral split |
| Message rewrite | Round-trip + validation + readiness copy pass |

---

## Verified Behavior Before Fix Task 1

**Date:** 2026-04-23  
**Method:** Read-only trace of current `lib/` sources (no code, UI, or fix changes).

### A. “Export Without Enriching” does not require external file input

**Result: Partially confirmed — depends on whether an internal shell file exists.**

| Step | What happens | Reference |
|------|----------------|-----------|
| 1 | `_runExportCore` runs **before** the enrichment dialog. It sets `shellPath` from `arm_trial_metadata.shellInternalPath` if non-empty **and** `File(internalPath).existsSync()`, else **`FilePicker.pickFiles`** | `arm_export_preflight_screen.dart` ~82–100 |
| 2 | `linkUc.preview(trial.id, shellPath)` parses that **filesystem path** | ~115–116 |
| 3 | If enrichment dialog appears and user chooses **Export Without Enriching**, `linkUc.apply` is **not** called (~165–197 skips apply). `trial` may be reloaded (~199–201) | ~160–205 |
| 4 | `exportArmRatingShellUseCaseProvider.execute(..., selectedShellPath: shellPath, ...)` writes xlsx using **`ArmShellParser` / `ArmValueInjector`** on that path + DB ratings | ~208–214; `export_arm_rating_shell_usecase.dart` |

**Data sources for the xlsx:** (1) **Workbook bytes** from `shellPath` (stored copy or user-picked file); (2) **SQLite** for ratings, mappings, trial link metadata, applications, etc., inside `ExportArmRatingShellUseCase`.

**Surprise vs. prior narrative:** “Export Without Enriching” does **not** mean “no file was involved.” If internal storage was missing or the file was deleted, the user **already** used the picker in step 1 **before** the enrichment dialog. If internal storage is present, there is **no** picker and no new external input after import.

---

### B. “Enrich & Export” is the only path that invokes the external file picker

**Result: Refuted.**

- **Rating Sheet export:** `FilePicker.pickFiles` runs in `_runExportCore` whenever the internal shell path is missing or the file does not exist — **for all choices** (Export, Export Anyway, and **before** enrichment options) (`arm_export_preflight_screen.dart` ~89–100).
- **Enrich & Export** does not add a second picker; it calls `linkUc.apply(trial.id, shellPath)` with the **same** `shellPath` (~165–166).
- **Direct use case call:** If `ExportArmRatingShellUseCase.execute` is invoked **without** `selectedShellPath` and without `pickShellPathOverride`, it opens **`FilePicker.pickFiles`** itself (`export_arm_rating_shell_usecase.dart` ~288–328). In **production UI**, the only caller found is `ArmExportPreflightScreen` (`grep` on `exportArmRatingShellUseCaseProvider`), which always passes `selectedShellPath` (~212), so this picker is **not** shown on the normal UI path.

**Other export formats (PDF, CSV, ZIP, flat CSV):** Other `FilePicker` uses exist for import/backup/protocol (`grep` on `FilePicker.pickFiles` in `lib/`) — not for selecting a rating shell during those exports.

---

### C. Enrichment dialog always appears before every Rating Sheet export

**Result: Refuted — conditional.**

`shouldOfferShellMetadataEnrichmentBeforeExport` (`arm_shell_metadata_enrichment.dart` ~16–31) returns **false** unless **all** hold:

1. `preview.canApply` is true (~22)  
2. `trialFieldChanges` or `assessmentFieldChanges` is non-empty (~23–25)  
3. `existingLinkedShellPath` is empty **or** **not** the same normalized path as `selectedShellPath` (~26–29)

If the trial is already linked to the **same** shell path as selected, or there are no planned metadata changes, the dialog is **skipped** — export proceeds straight to `execute` after `preview` (~122–206 block not entered).

**Standalone / non–ARM-linked:** Rating Sheet export route is for ARM-linked trials; `ArmExportPreflightUseCase` returns a failure preflight if not ARM-linked (`arm_export_preflight_usecase.dart` ~125–129).

---

### D. Round-trip file came from “Export Without Enriching”

**Result: Partially confirmed — consistent with described taps; alternate production path not found.**

- Described sequence: preflight → **Export Anyway** (positional acknowledgment) → enrichment dialog → **Export Without Enriching** → share. In code, **Export Without Enriching** skips `apply` (~165–197) but still runs the same `execute` with the same `shellPath` (~208–214).
- **Production entry:** `grep` shows `exportArmRatingShellUseCaseProvider` used from **`arm_export_preflight_screen.dart` only** in `lib/` — no second menu path for the same use case.
- **Output:** Filename pattern is `${safeName}_RatingShell.xlsx` in temp (`export_arm_rating_shell_usecase.dart` ~658–664). ARM accepting **`AgQuest_Demo_Trial_RatingShell.xlsx`** matches that pattern after the `_filled` removal.
- **Cannot prove from code** the user did not use an older build or a test harness; within **current** app structure, the described taps match this path.

---

### E. Positional dialog on “Export Anyway” regardless of warning type

**Result: Confirmed.**

- `_runExportAnyway` always `showDialog` with fixed “positional column matching” copy (~34–66), then on confirm calls `_runExportCore(allowPositionalFallback: true)` (~67–68).
- There is **no** branch that skips this dialog based on which preflight warnings fired — only `confirmed != true || !mounted` exits (~67).

**Exact trigger:** User taps **Export Anyway** (shown when `preflight.warningCount > 0`, `_ActionBar` ~739–761) → dialog → user taps **Export Anyway** in dialog → `_runExportCore(allowPositionalFallback: true)`.

---

### F. Enrichment path mutates in-app trial data

**Result: Confirmed** (`ArmShellLinkUseCase.apply`, `arm_shell_link_usecase.dart` ~95–221).

**Mutations (within one DB transaction):**

| Target | What changes |
|--------|----------------|
| **`trials`** (via `_trialRepository.updateTrialSetup`) | `name`, `protocolNumber`, `cooperatorName`, `crop` from `trialFieldChanges` (~96–138); `updatedAt` bump (~190–195) |
| **`arm_assessment_metadata`** | Via `_armColumnMappingRepository.applyShellLinkFieldsForTrialAssessment` — fields such as `armShellColumnId`, `armShellRatingDate`, `armColumnIdInteger`, `pestCode`, `seName`, `seDescription`, `ratingType` (~152–164, ~141–145 aggregation) |
| **`arm_trial_metadata`** | `insertOnConflictUpdate`: `armLinkedShellPath`, `armLinkedShellAt`, `shellInternalPath` (copy via `ShellStorageService.storeShell` ~171–174), `shellCommentsSheet` (~179–188) |
| **`audit_events`** | Insert `arm_shell_linked` (~213–219) |

**Integrity risk:** Running **Enrich & Export** against a **wrong** shell can overwrite the above with values derived from that file’s preview.

---

### G. Complete Data Package and Data + Photos share one code path

**Result: Confirmed — same branch, same package builder.**

- `armAligned = (format == ExportFormat.armHandoff)` (`export_trial_usecase.dart` ~327–328).
- When `armAligned`, the same `_buildArmHandoffPackage(...)` and same `Share.shareXFiles` text (`'${trial.name} – Import Assistant package'`) run (~514–537).
- The former duplicate ZIP enum value has been removed, leaving `armHandoff` as the only package branch.

**Near-identical output:** Bundle contents depend on trial data (e.g. `statisticsCsv` null for ARM-linked trials ~492–495, 1793–1795), not on which of the two enum values was selected.

---

### H. `_filled` suffix removed from production code

**Result: Confirmed for `lib/`.**

- Output path: `'${tempDir.path}/${safeName}_RatingShell.xlsx'` (`export_arm_rating_shell_usecase.dart` ~664).
- `grep` for `_filled` / `RatingShell_filled` under **`lib/`**: **no matches**.
- **Outside `lib/`:** Test `test/data/arm_value_injector_test.dart` still uses temp names like `sub_filled_...` (test-only). `test/features/export/export_arm_rating_shell_usecase_test.dart` asserts **no** `_filled` in basename (~641, ~746). This document now references `_filled` only as historical narrative (Part 2C and this section).

---

### Fix-task validity after verification

| Prior assumption | After verification |
|------------------|-------------------|
| Picker only on enrich / “export without enrich = fully internal” | **Too strong:** picker runs whenever internal shell file missing, **before** enrich dialog; enrich branch does not uniquely own the picker. **Fix scope for “eliminate picker”** should center on **`shellInternalPath` reliability** and UX when file missing — not only on enrichment. |
| Enrichment dialog always shown | **Wrong:** gated by `shouldOfferShellMetadataEnrichmentBeforeExport`. Copy/flow fixes should not assume every export sees it. |
| Export Anyway / positional dialog | **Confirmed** as unconditional for that button — **warning/dialog consolidation task remains valid.** |
| ZIP duplicate formats | **Confirmed** same implementation — **consolidation/design task remains valid.** |
| `apply` mutates DB | **Confirmed** — **separate “sync from sheet” vs export** still a valid design axis. |

**Commit:** Per workspace rules, this documentation update is **not** auto-committed; confirm if you want it on the branch.

---

## Quality gates

- **Code changes:** None (this file only).
- **flutter analyze:** Run by agent after adding `docs/EXPORT_AUDIT.md` (expected: no new issues from doc alone).

---

## Incomplete brief items

- **Part 2D:** No on-device reproduction; no stack trace; no matrix of trial states (ARM vs standalone, ratings vs empty, etc.).
- **Part 4:** No binary/hex verification of xlsx round-trip; no BOM audit on actual device exports.

---

## Shell Storage Reliability Investigation

**Date:** 2026-04-24
**Method:** Read-only trace of current `lib/` sources. No device repro. Premise: after Tasks 2a–2b, the happy-path goal is *import shell → rate → export → save*, with the app already holding the shell. The picker in the export flow appeared because `shellInternalPath` did not resolve at export time for a trial that had previously exported cleanly. Establish the cause from code alone before scoping a fix.

### Q1 — How is `shellInternalPath` populated during Rating Shell import?

Entry point: `ImportArmRatingShellUseCase.execute(String shellPath)` in [import_arm_rating_shell_usecase.dart:166](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L166).

Full call chain:

1. Parse shell — `ArmShellParser(shellPath).parse()` at [line 168-169](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L168).
2. Duplicate-import guard on `armSourceFile` at [line 182-189](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L182).
3. DB transaction (structure only) at [line 193-623](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L193) — creates trial, plots, treatments, assessments, sessions, mappings.
4. **File I/O + mark ARM-linked** at [line 625-653](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L625):
   - [Line 627-630](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L627): `ShellStorageService.storeShell(sourcePath: shellPath, trialId: plan.trialId)` — returns an absolute path.
   - [Line 631-641](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L631): `_db.into(_db.armTrialMetadata).insertOnConflictUpdate(ArmTrialMetadataCompanion(... shellInternalPath: Value(internalPath) ...))` — writes the absolute path returned by `storeShell` to the DB.
   - [Line 642-647](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L642): `updateTrialSetup` to bump `updatedAt`.

The returned `internalPath` is the absolute path produced by `ShellStorageService.storeShell`. It contains the app's current iOS sandbox container UUID (see Q3). This absolute string is what the DB stores.

### Q2 — Is `storeShell` wrapped in a silent catch?

**Two different behaviors.** Critical distinction.

**`ImportArmRatingShellUseCase` at [line 626-653](lib/features/arm_import/usecases/import_arm_rating_shell_usecase.dart#L626):**

```dart
try {
  final internalPath = await ShellStorageService.storeShell(...);
  await _db.into(_db.armTrialMetadata).insertOnConflictUpdate(
    ArmTrialMetadataCompanion(... shellInternalPath: Value(internalPath) ...),
  );
  await _trialRepository.updateTrialSetup(plan.trialId, TrialsCompanion(...));
} catch (e) {
  await _rollbackFailedShellImport(plan.trialId);
  return ShellImportResult.failure(
    'Shell import failed: could not store shell or finalize trial ($e)',
  );
}
```

**Not silent.** On any failure (storeShell throwing, or the DB writes failing), the in-progress trial is rolled back via `_rollbackFailedShellImport` and a failure result with the thrown exception string is returned. No way to complete "Import Rating Shell" and end up with `shellInternalPath = null`.

**`ArmShellLinkUseCase.apply` at [line 168-189](lib/features/export/domain/arm_shell_link_usecase.dart#L168):**

```dart
// Store shell internally so export doesn't need a file picker.
String? internalPath;
try {
  internalPath = await ShellStorageService.storeShell(
    sourcePath: shellPath,
    trialId: trialId,
  );
} catch (_) {
  // Storage unavailable (e.g. test environment) — continue without.
}

await _db.into(_db.armTrialMetadata).insertOnConflictUpdate(
  ArmTrialMetadataCompanion(
    trialId: Value(trialId),
    armLinkedShellPath: Value(shellPath),
    armLinkedShellAt: Value(DateTime.now().toUtc()),
    shellInternalPath: internalPath != null
        ? Value(internalPath)
        : const Value.absent(),
    shellCommentsSheet: Value(preview.shellCommentsSheetText),
  ),
);
```

**Silent.** If `storeShell` throws, `internalPath` stays null, the catch logs nothing and surfaces nothing, and the DB write proceeds with `shellInternalPath: const Value.absent()` — meaning that column is **not updated**. If the trial previously had a `shellInternalPath` value, the existing value is preserved. If it had none, it stays null. Either way, the user sees a successful "Link Rating Sheet" outcome, no warning, no diagnostic.

The silent-catch comment *"Storage unavailable (e.g. test environment)"* describes the narrow case it was built for, but it catches **any** exception from `storeShell`.

### Q3 — What does `storeShell` actually do?

[shell_storage_service.dart:7-22](lib/data/services/shell_storage_service.dart#L7-L22):

```dart
static Future<String> storeShell({
  required String sourcePath,
  required int trialId,
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  final shellDir = Directory('${appDir.path}/shells');
  if (!shellDir.existsSync()) {
    await shellDir.create(recursive: true);
  }
  final destPath = '${shellDir.path}/$trialId.xlsx';
  await File(sourcePath).copy(destPath);
  return destPath;
}
```

1. Asks `path_provider` for `getApplicationDocumentsDirectory()` — on iOS this returns `/var/mobile/Containers/Data/Application/{container-UUID}/Documents`.
2. Builds `{appDir}/shells/{trialId}.xlsx` and creates the `shells` sub-directory if missing.
3. `File(sourcePath).copy(destPath)` — copies the shell bytes to the destination.
4. **Returns the absolute `destPath` string**, including the container UUID in the middle.

Failure modes:
- `getApplicationDocumentsDirectory()` throws if the platform plugin is uninitialized (test harnesses without `PathProviderPlatform` stub).
- `shellDir.create(recursive: true)` throws on permission denial or read-only FS (unlikely on iOS sandbox, possible on a locked backup restore).
- `File(sourcePath).copy(destPath)` throws if source is missing, destination is unwritable, disk is full, or the source is a cloud-only iCloud item whose download failed. The iOS document-picker via `file_picker` sometimes hands back a **temp security-scoped URL** whose download hasn't completed; copying it returns partial bytes or throws.
- On success, the returned path is **absolute and contains the container UUID**.

### Q4 — How does the preflight screen resolve the shell at export time?

[arm_export_preflight_screen.dart:78-100](lib/features/export/arm_export_preflight_screen.dart#L78-L100) (current HEAD, post-Task-2c revert):

```dart
final armMeta = await ref
    .read(armTrialMetadataRepositoryProvider)
    .getForTrial(widget.trial.id);
// Use internally stored shell if available; fall back to file picker.
String? shellPath;
final internalPath = armMeta?.shellInternalPath;
if (internalPath != null &&
    internalPath.isNotEmpty &&
    File(internalPath).existsSync()) {
  shellPath = internalPath;
} else {
  final pick = await FilePicker.pickFiles(...);  // fallback
  ...
}
```

The resolution reads the stored **absolute** `shellInternalPath` string and calls `File(storedAbsolutePath).existsSync()` to decide whether to use it or fall back to the picker.

Failure conditions for this check:
1. `shellInternalPath IS NULL` in the DB — never written. Path from the silent catch in `ArmShellLinkUseCase.apply` (Q2).
2. `shellInternalPath` is non-empty but the stored absolute path **no longer points at a real file**. This is the interesting case.

Case 2 happens when:
- The file at that path was deleted by external means (very unlikely on iOS).
- **The absolute path itself is wrong because the container UUID changed.** The stored string includes a UUID that was correct at import time; the current `getApplicationDocumentsDirectory()` call would return a different UUID, rendering the stored absolute string invalid even though the file still exists at `{currentAppDir}/shells/{trialId}.xlsx`.

**Note the existence of a second API in the same file, [line 24-31](lib/data/services/shell_storage_service.dart#L24-L31):**

```dart
static Future<String?> resolveShellPath(int trialId) async {
  final appDir = await getApplicationDocumentsDirectory();
  final destPath = '${appDir.path}/shells/$trialId.xlsx';
  final file = File(destPath);
  if (await file.exists()) return destPath;
  return null;
}
```

`ShellStorageService.resolveShellPath(trialId)` rebuilds the path from the current `appDir` and checks existence. **It has zero callers in production `lib/`** — grep confirms: written but unused. This is exactly the primitive the preflight screen should be using and isn't.

### Q5 — Is the picker always appearing or only sometimes?

**Only sometimes, based on code.** The fallback fires only when the three-part check at line 85-87 fails:

```dart
if (internalPath != null && internalPath.isNotEmpty && File(internalPath).existsSync())
```

On a trial freshly imported in the same app session, `shellInternalPath` was just written with the current `appDir`, so the stored absolute path and `File(...).existsSync()` agree — the fallback does **not** fire, the picker does **not** appear.

The user observed the picker appearing on a trial *that had previously exported cleanly*. That means the check succeeded in an earlier session and fails now. Interpretations from code:

- The stored absolute path is stable (DB value hasn't changed).
- The file either no longer exists at that exact absolute path, or the path resolves to nothing because the prefix (sandbox container) has shifted.

The intermittency fits the iOS-container-UUID hypothesis (see Q6), not a silent `storeShell` failure (which would have shown up on the first export, not later).

### Q6 — iOS behavior that can invalidate a stored absolute path between sessions

Documented iOS behaviors that plausibly apply on device `00008120-000238A01A9B401E`:

1. **Container UUID rotation on reinstall.** `/var/mobile/Containers/Data/Application/{UUID}/` contains the app's sandbox. iOS usually preserves the UUID across updates (`devicectl install` over an existing install) — but it is **not guaranteed stable** across:
   - reinstall with a different signing team / provisioning profile
   - device wipes / rebuilds
   - restore from backup
   - some `devicectl` failure modes where the app is effectively recreated
   - iOS upgrades that migrate containers
   During an active development cycle with many `xcrun devicectl device install app` iterations, the container UUID can shift unpredictably. Any stored **absolute** path that bakes in the old UUID will fail `existsSync()` in the new session even though the file would still be findable at `{newAppDir}/shells/{trialId}.xlsx`.

2. **Documents directory preservation isn't identical to path preservation.** Apple guarantees that files in `Documents/` survive app updates — but the *path* used to reach them (the absolute container path) is not part of that guarantee. Apps are expected to resolve `Documents/` at each launch via the platform API and treat historical absolute paths as invalid.

3. **iCloud Drive Documents sync** is not relevant here (the app doesn't opt in), but security-scoped bookmarks from the file picker are: a URL from `FilePicker.pickFiles` is only valid inside the bookmark's scope, which ends shortly after return. If the shell import runs against a `content://` or security-scoped path that was already revoked, `File(sourcePath).copy(destPath)` may produce a zero-byte or partial file. (This would manifest as a silent storage failure in the link use case, not as an intermittent picker — so less likely the current symptom.)

4. **Background file protection.** iOS default file protection is `NSFileProtectionCompleteUntilFirstUserAuthentication`. `existsSync()` should still succeed on a locked device after the first unlock, so this is unlikely to be the symptom.

The simplest explanation consistent with the evidence: **the absolute path stored in the DB includes a container UUID that has shifted since import**, so the existing `existsSync()` check fails on a file that would still be reachable via a path re-derived from the current `appDir`.

### Plain statements

**Does `shellInternalPath` reliably survive between import and export on the same device without reinstall?**
On a stable install (a single `devicectl` install, no wipe, no restore) the absolute path should remain valid until the file or the container is deleted. In a development cycle where the app is being reinstalled repeatedly — or on any occasion where iOS rotates the container UUID — the stored absolute path is **not reliable**. This is exactly the user's observed situation.

**Most likely cause of the picker appearing on a trial that was previously exported successfully:**
The DB's `shellInternalPath` string embeds a now-stale iOS sandbox container UUID. The file itself is still in `{appDocumentsDir}/shells/{trialId}.xlsx`, but the absolute path stored against the old UUID no longer resolves, so `File(internalPath).existsSync()` returns `false` and the fallback picker fires. This matches: the picker appearing on a trial that had previously exported cleanly, after several app reinstalls during development.

A secondary, additive cause is still possible for other trials: `ArmShellLinkUseCase.apply` silently catches any `storeShell` error, so a trial that reached the link flow but hit a transient storage error has `shellInternalPath = null` from the start. The user wouldn't notice until the first export attempt.

**Targeted fix to make import → rate → export → save work with no picker:**

Two complementary changes, both small.

- **Fix 1 (resolves the UUID-rotation case, which is the live symptom).** Stop trusting the stored absolute path at read time. In [arm_export_preflight_screen.dart:84-88](lib/features/export/arm_export_preflight_screen.dart#L84-L88), replace the absolute-path existence check with a call to the already-written `ShellStorageService.resolveShellPath(trialId)`, which reconstructs the current absolute path from today's `appDocumentsDir` and checks existence there. That method exists; it's simply unused. This converts the stored "path" into a "did we store it?" flag and recomputes the live location on every read.

  Optionally harden further by rewriting the DB column at import time to store a **relative** path (`shells/{trialId}.xlsx`) instead of the container-qualified absolute path. The helper's read-time resolver doesn't need it, but a relative string makes the DB row self-explanatory and prevents future code from blindly passing the stored string to `File()`.

- **Fix 2 (prevents silent failures in the link flow).** In [arm_shell_link_usecase.dart:168-177](lib/features/export/domain/arm_shell_link_usecase.dart#L168-L177), stop silently swallowing `storeShell` exceptions. At minimum, surface them as a diagnostic so the user learns the link succeeded but storage didn't. Ideally, treat a `storeShell` failure during link as a blocker — the link flow's entire purpose is to put the shell somewhere the app can reach, and failing silently only re-introduces the exact picker-at-export condition we're trying to eliminate.

After both are in, the user flow *import shell → rate → export → save* has no picker on any path that reaches a successful import, on any install state where the sandbox file survives.
