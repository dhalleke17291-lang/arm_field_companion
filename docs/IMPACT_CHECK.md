# Pre-Change Impact Check

**Use this before implementing any requested change.** It ensures we don’t introduce conflicts, break logic, or harm dependencies, internal communication, or data integrity.

---

## 1. Run before every change

- [ ] **Analyzer** — `flutter analyze` must pass before and after.
- [ ] **Tests** — `flutter test` must pass before and after.
- [ ] **Dependencies** — No new `pubspec` entries unless necessary; no version bumps that break existing code.
- [ ] **Logic** — No change to business rules in UseCases without explicit intent; no silent change to protocol vs execution semantics.
- [ ] **Internal communication** — Providers, repositories, and screens that consume them: who reads/writes what? No duplicate or conflicting sources of truth.
- [ ] **Data integrity** — Session-scoped data stays session-scoped; plot identity remains `Plots.id`; export and audit expectations unchanged.
- [ ] **Other screens/flows** — Navigation, session detail, plot queue, trial detail, export: no regressions or unexpected side effects.

---

## 2. How to report impact

| Impact level | Action |
|--------------|--------|
| **High** — Touches schema, multiple modules, or core UseCases; risk of data or navigation breakage; many files. | **Prior warning:** Describe impact, what could break, and alternatives. Do **not** proceed until the user explicitly agrees. |
| **Manageable** — Local to one feature, additive (new provider/screen), or small refactor with clear scope. | **Inform:** Summarise what will change (files, behaviour) and any small risks. Get consent, then proceed. |
| **None / trivial** — Typo, doc-only, single optional UI tweak. | Proceed; mention briefly. |

---

## 3. Field speed improvements — verification (done)

The following was checked for the first batch of field speed improvements:

| Item | Dependencies | Logic | Internal comms | Data / export | Result |
|------|--------------|--------|----------------|----------------|--------|
| Last value memory | No new deps | In-memory only; set on save success, pre-fill when empty | Only rating screen; no other consumer | Not exported; session-scoped by key | ✅ No conflict |
| One-tap flag | No new deps | Toggle: insert "Flagged" or delete all flags for plot/session | New provider; only rating screen | Same PlotFlags table; export doesn’t use flags yet | ✅ Note: “Remove flag” removes *all* flags for that plot in session (including any note added via long-press) |
| Jump to plot | No new deps | Reads existing providers; pushes RatingScreen | Plot queue only | None | ✅ No conflict |
| Scale shown | None | Read-only from Assessment | None | None | ✅ No conflict |
| Offline indicator | None | Display only | None | None | ✅ No conflict |
| Hold-to-save | None | Same handler as tap; _isSaving guards | None | None | ✅ No conflict |

**Tests:** All 20 pass. **Analyzer:** No issues.

---

## 4. When you request a change

- I will run this impact check (analyzer, tests, dependencies, logic, internal communication, data integrity, other flows).
- If impact is **high** → I will warn you and wait for your go-ahead before making changes.
- If impact is **manageable** → I will summarise and ask for consent, then proceed.
- I will keep this in mind for every change from now on.
