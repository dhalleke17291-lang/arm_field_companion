# ARM Field Companion — UI standards

Use these so similar elements look and behave the same across the app.

## Tabs / navigation

- **Trial Detail:** Uses a horizontal hub strip (_TrialModuleHub), height 110, compact dock tiles. Not Material TabBar.
- **Session Detail:** Uses Material TabBar when applicable; theme from main.dart (tabBarTheme) applies.
- **Standard:** One hub style for trial modules; same tile height, padding, selected/unselected styling.

## Section headers

- **Widget:** `StandardSectionHeader` (lib/core/widgets/app_standard_widgets.dart).
- **Layout:** Icon (20) + title text (14, w600, primary) + optional action on the right.
- **Container:** primaryContainer background, padding H12 V8.
- **Use for:** List sections that show a count and an “Add” action (e.g. “3 assessments”, “2 seeding events”).

## Add actions

- **Section-level:** Top-right of the section header. Use `StandardSectionHeader(..., action: IconButton(...) or TextButton.icon(...))`.
- **FAB:** When the list has no header bar (e.g. Treatments, Applications), use FAB bottom-right for “Add”. Same FAB style app-wide (theme).

## Empty states

- **Widget:** `StandardEmptyState` (lib/core/widgets/app_standard_widgets.dart).
- **Layout:** Centered column: icon (56) → title (17, w600) → subtitle (14, onSurfaceVariant) → primary button (FilledButton.icon with Add).
- **Spacing:** See AppUiConstants (emptyStateSpacingAfterIcon 12, afterTitle 8, beforeAction 20).
- **Use for:** No assessments, no seeding records, no treatments, no application events, etc.

## Loading and error

- **Widgets:** `AppLoadingView`, `AppErrorView` (lib/core/widgets/loading_error_widgets.dart).
- **Loading:** Center + CircularProgressIndicator (theme primary).
- **Error:** Center + icon + message + optional Retry that invalidates the relevant provider.

## Forms

- **Short/simple edit:** Dialog (e.g. Add Assessment, Add Treatment).
- **Important domain record:** Full-screen (e.g. Record Seeding).
- **Fields:** Use theme inputDecorationTheme; same label style, spacing, and section grouping where possible.

## Cards / detail sections

- **Theme:** cardTheme in main.dart (radius 12, margin H8 V4, elevation 0, border).
- **Detail rows:** Consistent label (e.g. grey 13) + value (w600). Use same padding between rows.

## Size tiers

- **Primary button:** theme FilledButton (padding H24 V14); for empty state use V12 when using StandardEmptyState.
- **Section header padding:** H12 V8 (AppUiConstants).
- **List padding:** H8 V6 when using standard list layout.

## Add-action placement (consistent rule)

- **With section header:** Put the primary “Add” in the section header, top-right (e.g. Seeding, Assessments, Plots “Bulk Assign”). Use `StandardSectionHeader(..., action: ...)`.
- **Without section header:** Use FAB bottom-right for “Add” (Treatments, Applications, Sessions). Same FAB across these screens.
- **Plots:** Primary empty-state action is “Import Plots from CSV”; section header action is “Bulk Assign” (not Add). Secondary actions (Import Protocol, Add 10 Test Plots) live in empty-state trailing actions.

## Tab styling

- **Trial Detail:** Custom hub (_TrialModuleHub), not Material TabBar. Height 110, compact dock tiles; theme colors from colorScheme.
- **Session Detail:** Custom _SessionDockBar (dock-style tabs). Reuse same compact styling as trial hub where applicable.
- **Theme:** main.dart tabBarTheme (labelColor, indicatorColor, labelStyle, unselectedLabelStyle) applies to any Material TabBar. Prefer theme over per-screen overrides.

## Detail / info rows

- **Widget:** `StandardDetailRow` (lib/core/widgets/app_standard_widgets.dart).
- **Usage:** `StandardDetailRow(label: 'Label', value: 'Value', icon: optional IconData)`.
- **Style:** Label: onSurfaceVariant 13; value: w600 14; padding vertical 4. Optional leading icon (18, primary).
- **Use in:** Plot Detail card, record detail cards, any “label: value” rows so they look the same everywhere.
