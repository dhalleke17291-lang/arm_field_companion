# Insight Voice Spec

**Status:** v1 (frozen). Governs every user-facing sentence produced by `TrialIntelligenceService` and any future analytical narration in the app.

**Who this serves:** The field researcher or trial technician. Serious, time-pressed, scientifically trained. Not a novice. Not a consumer.

**Speaker:** A senior plant-science colleague writing beside trial data. Speaks plainly from evidence. Says nothing when evidence is insufficient.

**What it is:** The rules every analytical sentence must pass before it reaches the user — on the Overview card, in shared session summaries, or in any future surface.

---

## 1. Principles

1. **Verdict first, evidence second.** The first line states the call. The evidence lives behind a tap.
2. **Silence beats noise.** If the basis threshold isn't met, say nothing. Never pad.
3. **One voice across surfaces.** The same sentence must read correctly on the Overview card, in a shared session summary, and in a notification.
4. **Scientific accuracy is non-negotiable.** Never round up a claim the numbers do not support.
5. **No personality, no hedging theatre.** No "we", no "looks like maybe", no exclamation, no emoji, no metaphors.
6. **Concrete over abstract.** Name the treatment, rep, assessment, or rating that drives the call whenever it exists.
7. **Confidence tier controls tone.** Preliminary insights must hedge. Established insights must commit.

## 2. Sentence shape (verdict line)

- **Length:** 4–14 words. Hard cap 16.
- **Voice:** Declarative, present tense, active.
- **Subject:** The trial, a treatment, a rep, an assessment, or an effect. Never the app, never the user.
- **No trailing data.** Numbers belong in the evidence block, not the verdict.

**Good**
- `Treatments are separating clearly.`
- `Rep 3 is drifting; verify consistency next session.`
- `Trait expression is low — interpret with caution.`
- `Treatments are not separating yet.`
- `Treatment 4 is outperforming controls consistently.`

**Bad**
- `Effect size: 25%. CV: 10-15%. Separation: increasing.` (evidence, not verdict)
- `It looks like maybe treatments might be separating.` (hedging theatre)
- `🌱 Great progress — your trial is healthy!` (personality, emoji)
- `The app has detected that the coefficient of variation for Rep 3 is elevated relative to other reps, which may indicate operator drift.` (too long, over-qualified)

## 3. Verdict types (allowed sentence kinds)

Every analytical string produced by the service must match one of these kinds. If a situation does not fit a kind, the service emits no verdict and falls back to factual summary or silence.

| Kind | Purpose | Example |
|---|---|---|
| **Separation verdict** | Whether treatments are distinguishing | `Treatments are separating clearly.` / `Treatments are not separating yet.` |
| **Trend verdict** | Behavior of a treatment or check across sessions | `Treatment 4 is outperforming controls consistently.` / `Check variability is stable across sessions.` |
| **Drift verdict** | Inconsistency in a rep, rater, or block | `Rep 3 is drifting; verify consistency next session.` |
| **Inconsistency verdict** | A plot or rating that does not match its neighborhood | `Plot 214 is inconsistent with its rep.` |
| **Expression verdict** | Trait-expression level affecting interpretability | `Trait expression is low — interpret with caution.` |
| **Coverage factual line** | Non-judgmental state of completeness | `7 rated · 9 remaining.` |
| **No-verdict factual summary** | When evidence is insufficient for a call but a neutral note has value | `Early session — not enough reps to evaluate separation yet.` |

Cross-rule: the service never invents a new kind. A new kind requires a spec revision.

## 4. Numbers

- Use **numerals**, not words. `3 reps`, not `three reps`. (Exception: sentence-initial numbers in share text may be spelled out only if the line cannot be rewritten.)
- Prefer **concrete counts** over vague quantifiers. `4 of 6 treatments` beats `most treatments`. `Several` and `a few` are banned.
- When a number carries judgement, **include its comparator anchor**. `CV 18% vs trial mean 9%` — never a bare CV.
- **No precision theater.** Round to meaningful significance: percentages to whole numbers unless < 10% (then one decimal). CVs to whole numbers. Effect sizes to one decimal place maximum.
- **Units always attached.** `25%`, `18 DAA`, `3 reps` — never `25` alone.
- Numbers live in the evidence block. The verdict cites a number only when it is the point of the sentence and no substitute exists.

## 5. Confidence-tier rules (hard)

| Tier | Required verb posture | Example openers |
|---|---|---|
| `preliminary` | Hedge. Flag that the call is early. | `Early signal:`, `Tentative —`, `Too soon to confirm —` |
| `moderate` | Commit, but name the limit. | `So far,`, `Based on N reps,` |
| `established` | State plainly. No hedge. | (no opener — just the verdict) |

A verdict that states an established-tier sentence on preliminary evidence is a **spec violation** and must be rejected in review.

### 5.1 Product confidence cap (Agnexis app)

`resolveConfidence` in code **never returns `established`** for user-facing insights. The app caps labels at **moderate** and uses a **conservative ladder** (slight under-confidence is acceptable; over-confidence is not). The `established` enum remains for unit tests of voice helpers and hypothetical tooling. Overview copy states that insights are exploratory and do not replace formal analysis.

**UI chip text** maps tiers to non-statistical words so field staff are not nudged toward inferential closure: **Early** (preliminary), **Developing** (moderate), **Review-ready** (reserved; not emitted in production). The expanded evidence block still states session/rep counts and method.

## 6. Severity-tier rules

| Severity | Tone |
|---|---|
| `info` | Neutral. No urgency. |
| `notable` | State the issue; no alarm. |
| `attention` | Direct. Name the next action if one is obvious. Never scold. |

The verdict line does not repeat severity with words like "Warning:" or "Alert:" — the UI already signals that with the left border.

## 7. Forbidden (in verdict strings)

- Emoji.
- Exclamation marks.
- First-person plural ("we", "our").
- Second-person imperative unless it is a single clear action. `Verify consistency.` is OK; `Please make sure you verify…` is not.
- Marketing words: "great", "awesome", "impressive", "insightful", "powerful".
- Over-qualification strings: "may potentially indicate", "could possibly suggest".
- Raw statistics inside the verdict (see §4).
- Re-stating the insight category as the sentence subject (`Trial health is healthy.`).
- Words like "detected", "identified", "flagged" in **verdict** strings. (Allowed in low-level technical/diagnostic copy where no verdict is being made.)

## 8. Terminology

- **Default user-facing term is `assessment`.** Ratings screens, Overview cards, export files, share text, notifications all say `assessment`.
- `trait` is allowed **only** in explicitly analytical screens that are already anchored to that language (e.g., statistical comparison views). A module wanting to use `trait` must document the anchor.
- `rating` refers to the numeric value recorded against a plot × assessment pair; it is not interchangeable with `assessment`.
- `treatment`, `rep`, `plot`, `session` are canonical. No synonyms.

## 9. Structure rules

- Default is **one verdict line + one evidence line**.
- Structured detail pages may use **short bullets or labeled rows** where that is clearer than prose.
- Freeform prose blocks are not allowed in insight surfaces.

## 10. Evidence block rules

The existing expanded-on-tap block already shows `basisSummary`, `method`, and `threshold`. Keep this. Numbers and method live **only** here. The verdict must stand alone without them but must never contradict them.

## 11. Protocol awareness (when data supports it)

If an assessment's role in the protocol is known (primary vs. secondary objective, critical timing), the verdict may reflect it:
- `This assessment drives the primary objective — significance matters here.`
- `Secondary assessment; non-significance is expected at this stage.`

Never invent protocol context that isn't in the data.

## 12. Share-text adaptation

When an insight is consumed by `composeSessionSummary`, the verdict is the bullet content. No UI affordances ("Tap for method") travel to share text. Evidence lives in parentheses after the verdict, one line, no more.

Example:
- `Rep 3 is drifting; verify consistency next session. (CV 18% vs trial mean 9%, established.)`

## 13. Review rule

Any string that will surface as a verdict must be reviewed against this spec before merge. If it fails Principles 1–5, §3 (type), §4 (numbers), or §5 (confidence), it is rejected regardless of how accurate it is.
