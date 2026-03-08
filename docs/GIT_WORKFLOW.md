# ARM Field Companion — Safe Git Workflow (Solo Developer)

Branch model:

- **main** — stable releases only
- **develop** — integration branch for completed features
- **feature/*** — individual feature branches

---

## 1. Safe step-by-step workflow (do this now)

### Step 1 — Verify repository status

```bash
cd ~/Desktop/arm_field_companion
git status
```

**What it does:** Shows modified (M) and untracked (??) files so you know exactly what will be committed.

---

### Step 2 — Stage all changes safely

```bash
git add .
```

**What it does:** Stages every change (modified and untracked). Your `.gitignore` already excludes `build/`, `.dart_tool/`, etc., so only source and assets are added.

**Optional (if you want to exclude the diff file):**

```bash
git add .
git reset cursor_code_review.diff
```

---

### Step 3 — Commit with a clear message

```bash
git commit -m "Implement diagnostics capture, immutable corrections, session lock, provenance metadata, and batch export of closed sessions"
```

**What it does:** Creates one commit on `feature/csv-export` with a descriptive message that matches the work done.

---

### Step 4 — Confirm branch structure

```bash
git branch
```

**What it does:** Lists local branches. You should see `* feature/csv-export` and `main`. Current branch is marked with `*`.

---

### Step 5 — Create a safety tag for this milestone

```bash
git tag v0.8_field_integrity_upgrade
```

**What it does:** Creates an annotated-style tag at the current commit. You can return to this exact state anytime with `git checkout v0.8_field_integrity_upgrade` or use it as a release reference.

**Optional (tag with a message):**

```bash
git tag -a v0.8_field_integrity_upgrade -m "Diagnostics, corrections, session lock, provenance, batch export"
```

---

### Step 6 — Push to remote (if you have one)

```bash
git push -u origin feature/csv-export
git push origin v0.8_field_integrity_upgrade
```

**What it does:** Pushes the branch and the tag to `origin`. If no remote is configured, these commands will report an error; that’s fine for a local-only repo.

**Check for a remote:**

```bash
git remote -v
```

If this prints nothing, you have no remote; skip the push step or add one later.

---

## 2. Optional safety improvements

### A. Create a develop branch (if it doesn’t exist)

From a clean state (e.g. after committing on `feature/csv-export`):

```bash
git checkout main
git checkout -b develop
git push -u origin develop
git checkout feature/csv-export
```

**What it does:** Creates `develop` from `main` for integration. You can later merge finished feature branches into `develop`, then `develop` into `main` for releases.

---

### B. Protect main from direct feature commits

- **Convention:** Do not commit directly to `main`. All work goes into `feature/*` (or `develop`), then is merged into `main` only for releases.
- **Enforcement:** On GitHub/GitLab you can set branch protection for `main` (require PR, block force-push). For a solo local repo, discipline is enough.

---

### C. .gitignore (already updated)

The project `.gitignore` now also includes:

- `android/.gradle/`
- `ios/Pods/`

So Flutter/Android/iOS build artifacts stay out of the repo.

---

### D. Periodic snapshot tags for major milestones

After future big changes, tag again, e.g.:

```bash
git tag -a v0.9_provenance_system -m "Provenance and export hardening"
```

Use a clear naming pattern: `v0.x_short_description`.

---

### E. Use small feature branches for future work

Create a branch per feature, then merge into `develop` or `main`:

```bash
git checkout develop   # or main
git checkout -b feature/gps-provenance
# ... work ...
git add . && git commit -m "Add GPS to provenance"
```

Examples:

- `feature/gps-provenance`
- `feature/assessment-corrections`
- `feature/export-manifest`

---

## 3. Quick reference — full sequence to run now

```bash
cd ~/Desktop/arm_field_companion
git status
git add .
git reset cursor_code_review.diff   # optional: leave diff file unstaged
git commit -m "Implement diagnostics capture, immutable corrections, session lock, provenance metadata, and batch export of closed sessions"
git branch
git tag -a v0.8_field_integrity_upgrade -m "Diagnostics, corrections, session lock, provenance, batch export"
git remote -v
# If remote exists:
# git push -u origin feature/csv-export
# git push origin v0.8_field_integrity_upgrade
```

No application code was changed; only Git workflow guidance and `.gitignore` hygiene were applied.
