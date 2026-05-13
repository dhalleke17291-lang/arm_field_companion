# RATING REFERENCE ASSIST — COMPLETE SPECIFICATION
Last updated: May 2026

## PURPOSE

A visual calibration and identification guide available to raters
at the point of rating. Improves inter-rater consistency by giving
a reference at the moment it is needed — not in training days
before the trial, but on the rating screen during the trial.

Two distinct functions served by the same overlay:
- Calibration: what does 30% disease severity look like on a scale?
- Identification: what does this insect/weed/disease actually look like?

These are different cognitive needs served by different lanes.

GLP value: rating_guide_view_events creates an audit trail.
A GLP auditor can see whether raters viewed the reference guide
before assigning a value. Data quality provenance.

---

## RATING SCREEN CONSTRAINT — NON-NEGOTIABLE

The rating screen layout must NEVER be modified for this feature.
The rating screen is the highest-frequency interaction in the app.
Any disruption to value entry flow degrades the core workflow.

Implementation pattern:
- Small info icon (or equivalent unobtrusive indicator) placed
  adjacent to the assessment name on the rating screen.
- Tap-only behavior. No automatic display on screen entry.
- No banner, no modal pop-up on load, no persistent panel.
- Icon only renders when a guide exists for that assessment.
  If no guide content exists, no icon appears. Never an empty tap.
- Tapping opens a full-screen overlay or modal sheet showing
  the reference content for that assessment.
- Closing the overlay returns to the rating screen exactly as
  left — no state change, no scroll position change, no value
  cleared, no field focused differently.
- rating_guide_view_events writes one record when the overlay
  opens: assessment_id, session_id, rater, timestamp.
  This is the audit trail. Do not write on close.

---

## THREE-LANE ARCHITECTURE

**RENDER PRIORITY: Lane 3 > Lane 2 > Lane 1**

If Lane 3 content exists for this assessment in this trial:
  render Lane 3 content.
Else if Lane 2 content exists for this assessment type:
  render Lane 2 content.
Else if Lane 1 content exists for this assessment type:
  render Lane 1 content.
Else:
  no icon on rating screen.

The rater does not see which lane content comes from.
They see a reference image with attribution. That is all.

---

### LANE 1 — CALIBRATION: AI-GENERATED SEVERITY DIAGRAMS

**Purpose:**
Rater calibration on percentage and categorical scales.
Standard Area Diagram (SAD) approach — the established
scientific method for improving inter-rater consistency
in plant pathology. Research confirms SADs improve
consistency by removing photographic noise.

A diagram shows the concept of 30% severity directly.
A photo shows one instance under one set of conditions.
Diagrams are more consistent and more appropriate for
calibration than photos.

**What diagrams contain:**
- Crop-appropriate plant or leaf outline (stylized, not
  photorealistic — wheat leaf for wheat, canola for canola)
- Affected area shading or marking at each severity level
- Numeric label per level (%, category value, count)
- Full scale progression shown in one view so rater sees
  the entire range simultaneously
- Scale bar below the progression

**Assessment types suited to this lane:**
- Disease severity % (leaf, stem, root, whole plant)
- Weed control %
- Crop injury categorical (0-4 or 0-5 scales)
- Stand coverage %
- Any percentage or categorical assessment

**What diagrams do NOT cover:**
- Species identification (that is Lane 2)
- Novel or ambiguous symptom confirmation (Lane 2)

**Licensing:**
Diagrams are original AI-generated works owned by Agnexis.
They are not reproductions of any copyrighted photo or image.
Scale specifications are sourced from published scientific
literature and are cited, not reproduced.

Scale specification sources:
- AAFC extension publications (severity thresholds are
  scientific facts, not copyrightable expression)
- EPPO PP1 standards (PP1/152 and PP1/181 scale descriptions)
- Canadian Journal of Plant Pathology CC BY 4.0 articles
- Canadian Journal of Plant Science CC BY 4.0 articles

Per diagram: cite the scale specification source in
`citation_full` field in the schema.

**Quality control requirement:**
Every generated diagram must be validated against its
cited source specification before seeding into the library.
Severity levels in the diagram must match the thresholds
in the cited publication. Validation logged in schema.

**Build approach:**
Generate once per assessment type, store as PNG or SVG.
Not generated at runtime — pre-generated and seeded.
Validated manually before seeding.

---

### LANE 2 — IDENTIFICATION: iNATURALIST RESEARCH GRADE PHOTOS

**Purpose:**
Species identification — what does this pest, disease
symptom, or weed species actually look like in real prairie
field conditions? Confirms identification before rating begins.

**Source:**
iNaturalist (inaturalist.org / inaturalist.ca)
Community-verified citizen science observations.

**API filter parameters:**
- quality_grade: research
  (community-verified identification, not just uploaded)
- license: CC-BY, CC0
  (commercial use permitted with attribution)
- place_id: Manitoba (6803), Saskatchewan (6804), Alberta (6805)
  (Canadian prairie geography — authentic conditions)
- taxon_id: target species per assessment type
- order_by: votes (most community-validated first)

Per-photo attribution stored in schema and rendered
visibly in the overlay:
"© [photographer name] via iNaturalist [CC BY 4.0]"
or as specified by the individual photo's license.

**Minimum threshold before seeding a species:**
At least 3 Research Grade CC BY photos from Canadian
prairie locations. If fewer than 3 exist for MB/SK/AB,
expand to Canada-wide. If still insufficient, expand to
comparable Northern Great Plains geography (North Dakota,
Minnesota, Montana). If still insufficient, no Lane 2
content for that species — no icon shown.

Never seed a photo that does not have:
- Explicit CC BY or CC0 license tag on the observation
- Research Grade quality confirmation
- Verifiable source URL

**Target taxa for initial seeding:**

INSECTS:
- Bertha armyworm (Mamestra configurata)
- Diamondback moth (Plutella xylostella)
- Wheat midge (Sitodiplosis mosellana)
- Flea beetles (Phyllotreta spp.)
- Cabbage seedpod weevil (Ceutorhynchus obstrictus)
- Grasshoppers (Melanoplus spp.)
- Cereal aphids (Sitobion avenae, Rhopalosiphum padi)
- Pea leaf weevil (Sitona lineatus)
- Swede midge (Contarinia nasturtii)

DISEASES:
- Sclerotinia stem rot (Sclerotinia sclerotiorum)
- Fusarium head blight (Fusarium graminearum)
- Clubroot (Plasmodiophora brassicae)
- Alternaria black spot
- Leaf spot diseases
- Powdery mildew
- Stripe rust (Puccinia striiformis)
- Leaf rust (Puccinia triticina)

WEEDS:
- Wild oats (Avena fatua)
- Green foxtail (Setaria viridis)
- Canada thistle (Cirsium arvense)
- Wild mustard (Sinapis arvensis)
- Cleavers (Galium aparine)
- Kochia (Bassia scoparia)
- Shepherd's purse (Capsella bursa-pastoris)
- Redroot pigweed (Amaranthus retroflexus)
- Common lamb's quarters (Chenopodium album)
- Wild buckwheat (Fallopia convolvulus)
- Stinkweed (Thlaspi arvense)
- Narrow-leaved hawk's-beard (Crepis tectorum)
- Hemp-nettle (Galeopsis tetrahit)

---

### LANE 3 — CUSTOMER-UPLOADED HELPER IMAGES

**Purpose:**
Organization-specific reference content. A CRO or research
company uploads their own calibrated reference photos or
diagrams from their own training library.

Overrides Lane 1 and Lane 2 for any assessment where
customer content exists. Customer content is always
preferred because it matches the organization's own
training standards.

**Customer licensing responsibility:**
Customer confirms they have rights to upload the images.
Agnexis stores the images and the attestation but does
not validate license claims independently.
User agreement must include:
- Explicit content licensing clause (not bundled in general terms)
- Per-photo or per-trial scope, not blanket
- Revocable — revocation removes photo from library going forward

**Scope:** per-organization, per-trial or per-assessment-type.

---

## BUILD ORDER

**Lane 3 first:**
Customer upload UI in trial setup or assessment setup.
Photos linked to assessments by trial coordinator.
Zero licensing complexity for Agnexis.
Matches QuickTrials "helper images" parity immediately.
One session to build. Ships immediately.

**Lane 1 second:**
Generate initial diagram set for common prairie crop-assessment
combinations. Validate each diagram against its cited
specification. Seed validated diagrams into assessment_guide_anchors.

**Lane 2 third:**
Build iNaturalist API integration.
Query and cache CC BY photos per target species.
Seed for insects, diseases, weeds from target taxa list.
Implement geographic fallback logic.

---

## SCHEMA — EXISTING TABLES

- assessment_guides
- assessment_guide_anchors
- rating_guide_view_events

---

## SCHEMA — ADDITIONS NEEDED TO assessment_guide_anchors

```
lane: TEXT
  enum values: calibration_diagram | identification_photo | customer_upload

content_type: TEXT
  enum values: ai_generated_svg | ai_generated_png | inaturalist_photo | customer_photo

source_url: TEXT
  Lane 1: URL of the specification document used
  Lane 2: canonical iNaturalist observation URL
  Lane 3: null

license_identifier: TEXT
  Lane 1: 'original_work_agnexis'
  Lane 2: 'CC-BY-4.0' or 'CC0-1.0'
  Lane 3: 'customer_grant_v1'

attribution_string: TEXT
  Rendered visibly in overlay for every photo.
  Lane 1: "Severity scale based on [source citation]. Diagram © Agnexis."
  Lane 2: "© [photographer] via iNaturalist [license]"
  Lane 3: "Provided by [organization name]"
  No photo renders without an attribution string.

inaturalist_observation_id: INTEGER nullable   (Lane 2 only)
inaturalist_taxon_id: INTEGER nullable         (Lane 2 only)

generation_specification: TEXT nullable
  Lane 1 only. JSON describing how the diagram was generated.

validated_by: TEXT nullable        (Lane 1 only)
validation_date: DATE nullable     (Lane 1 only)

citation_full: TEXT nullable
  Lane 1: full bibliographic citation of scale specification source.
  Lane 2: null. Lane 3: null.

date_obtained: DATE
date_last_verified: DATE

customer_organization_id: INTEGER nullable     (Lane 3 only)
customer_consent_record_id: INTEGER nullable   (Lane 3 only)
```

---

## EXCLUDED SOURCES — DO NOT USE

- PPMN (Prairie Pest Monitoring Network): explicitly prohibited in software
- Bugwood Network CC BY-NC photographers: non-commercial only
- Provincial ministry web content without OGL: Crown Copyright by default
- AAFC publications not on open data portal: require written permission
- Industry/commodity organizations without written permission
- US sources for prairie-specific content: not authentic for Canadian trials

---

## COMPETITIVE CONTEXT

QuickTrials has a "helper images" feature (Lane 3 parity).

Agnexis differentiators:
- Lane 1 (curated calibration diagrams) for users without their own photo library
- Lane 2 (iNaturalist species ID) for all users regardless of organization size
- Canadian-prairie-specific content not replicable by foreign competitors
- Audit trail via rating_guide_view_events (GLP provenance QuickTrials lacks)

---

## SCHEDULING

Task 6 in the current sprint. Preceded by:
1. D6 cognition layer in Session FER
2. Presentation pass (all four PDF builders)
3. ARM import trial_purposes seeding
4. Standalone deviation structured fields (Mode C schema)

Lane 3 ships immediately when built.
Schema additions applied before any content seeded.
