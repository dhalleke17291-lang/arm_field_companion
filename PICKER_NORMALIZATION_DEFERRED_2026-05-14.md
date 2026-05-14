# SessionPicker Normalization — Deferred 2026-05-14

## Context

During the Plots tab cleanup pass, the opportunity arose to extract a shared
`SessionPicker` widget from the Heat map and Distribution pickers. The
extraction was deferred because the two callers use incompatible state
contracts.

## Incompatible State Contracts

**Heat map picker — external state**
- The parent widget holds `Session? _selectedSession`.
- The picker receives a `ValueChanged<Session>` callback.
- Session selection is owned and managed by the parent; the picker is stateless
  with respect to selection.

**Distribution picker — internal state**
- The widget holds `int? _pickedSessionId` privately.
- There is no parent callback — the selected session ID is consumed internally.
- The parent has no visibility into which session is currently selected.

## Why a Shared Widget Is Non-Trivial

Bridging the two conventions requires one of the following changes, each with
downstream effects:

1. **Give Distribution a parent callback** — adds `ValueChanged<int?>` (or
   `ValueChanged<Session?>`) to Distribution's constructor, which means every
   call site that instantiates Distribution must supply the callback and hold
   the state, changing the widget's external API.

2. **Move Heat map to internal state** — Heat map's parent currently routes the
   selected session into other providers or layout decisions. Switching to
   internal state means that wiring moves inside Heat map or is expressed via a
   different mechanism (e.g., an inherited widget or a local provider).

Either change touches code beyond the Plots widgets themselves and is therefore
outside a focused plots-refactor scope.

## Resolution Options

**Option A — Normalize to internal state (Heat map adopts Distribution's
pattern)**
- Heat map holds `int? _pickedSessionId` internally.
- Parent no longer passes session selection.
- Simplifies the parent; couples session routing into the Heat map widget.
- Preferred if Heat map's parent does nothing else with the selected session.

**Option B — Normalize to external state (Distribution adopts Heat map's
pattern)**
- Distribution adds `Session? selectedSession` and
  `ValueChanged<Session>` to its constructor.
- Parent holds and routes selection for both pickers.
- Consistent with Heat map's existing contract.
- Preferred if Distribution's parent will eventually need visibility into the
  selected session (e.g., for cross-widget coordination).

## Status

Deferred — queued for a separate audit + commit cycle.  
Not part of the 2026-05-14 Plots cleanup sprint.
