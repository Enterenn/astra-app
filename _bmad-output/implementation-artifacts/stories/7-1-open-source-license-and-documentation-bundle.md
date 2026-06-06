# Story 7.1: Open Source License and Documentation Bundle

Status: review

<!-- Epic 7 first story — OSS credibility docs. Documentation + README refresh only; no app behavior changes. -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **contributor**,
I want clear OSS licensing and technical documentation,
so that I can understand, audit, and extend the project confidently.

## Acceptance Criteria

1. **Given** the public repo  
   **When** inspected  
   **Then** `LICENSE` is Apache 2.0 and README states license and project pitch (FR26)

2. **Given** `docs/` folder  
   **When** reviewed  
   **Then** `OPEN_WEARABLES_ALIGNMENT.md`, `SERIES_TYPES.md`, `DEPENDENCIES.md`, and `REGULATORY_POSITION.md` exist (FR27)  
   **And** OW doc lists Phase 0 `steps/count` mapping; regulatory doc states General Wellness boundary

3. **Given** README  
   **When** read by a new visitor  
   **Then** airplane mode proof protocol and local-first positioning are explained (SM-3/SM-7 prep)

**Depends on:** Epics 1–6 complete (implementation exists to document).  
**Out of scope (later stories):** `docs/BETA_CHECKLIST.md` (Story 7.3), `test/release_manifest_test.dart` creation (Story 7.2), 24 h airplane-mode field test (Story 7.2), demo GIF capture (Story 7.3).

---

## Tasks / Subtasks

- [x] **A — LICENSE verification** (AC: #1)
  - [x] Confirm root `LICENSE` is unmodified Apache 2.0 full text (already present from Story 1.1)
  - [x] Remove README hedging: `*(to be added before public release)*` and `**(planned)**` under License section

- [x] **B — README modernization** (AC: #1, #3)
  - [x] Update **Project status** — app is implemented; Epics 1–6 done; Epic 7 in progress
  - [x] Fix **Interface** table: four tabs — Today · Trends · Data · Profil (not three surfaces)
  - [x] Keep and polish **Airplane mode protocol** section (already present — verify steps match current UI labels: Trends not History, Data tab → My Data screen)
  - [x] Update **Developer setup** — remove "Flutter code is not scaffolded yet"; add `flutter pub get`, `flutter run`, `flutter test`, `flutter build apk --release`
  - [x] Update **Contributing** — project accepts contributions; link `docs/project-context.md` review gate
  - [x] Update **Project documentation** table — correct story count, sprint status pointer, link all four FR-27 docs
  - [x] Add short **docs/** index link to `docs/README.md`

- [x] **C — Create `docs/SERIES_TYPES.md`** (AC: #2)
  - [x] Document Phase 0 canonical type `steps` / unit `count`
  - [x] Document allowed `resolution` values: `5min`, `1hour`, `1d` (constants in `lib/data/models/normalized_step_bucket.dart`)
  - [x] Document `provider` / `device_id` for phone ingestion: `internal_phone` / `smartphone` (`lib/data/datasources/data_ingestion_source.dart`)
  - [x] Note Phase 1+ planned types from addendum (heart_rate, hrv_rmssd, skin_temp) as **not stored in Phase 0**
  - [x] Clarify derived Today metrics (kcal, km, walking time) are **UI-computed**, not separate series types

- [x] **D — Create `docs/REGULATORY_POSITION.md`** (AC: #2)
  - [x] State **General Wellness Product** boundary — behavioral visibility, not medical device
  - [x] List allowed claims (step counts, goals, trends, export) vs prohibited (diagnosis, treatment, clinical thresholds)
  - [x] Reference CNIL April 2025 local-only personal-use architecture note (no cloud, no account Phase 0)
  - [x] Reference FDA General Wellness policy (lifestyle maintenance, no disease claims)
  - [x] Include **not legal advice** disclaimer; V2+ cloud sync reintroduces GDPR obligations
  - [x] Align copy tone with UX §4.6 and README "What ASTRA is not"

- [x] **E — Expand `docs/OPEN_WEARABLES_ALIGNMENT.md`** (AC: #2)
  - [x] Add entity mapping table: ASTRA `timeseries_samples` column → OW CSV column (10 columns)
  - [x] Document bucket identity unique index fields (`provider`, `device_id`, `type`, `start_time`, `end_time`, `resolution`)
  - [x] Reference implementation: `lib/data/csv/timeseries_csv_codec.dart`, schema `lib/core/database/migrations.dart`
  - [x] State explicitly: vocabulary alignment only — **no** Open Wearables server dependency
  - [x] Include canonical JSON example from addendum §2

- [x] **F — Complete `docs/DEPENDENCIES.md` FR-27 audit** (AC: #2)
  - [x] Add full **Dart/Flutter package table** for every `pubspec.yaml` dependency with version, purpose, network column
  - [x] Confirm `flutter_local_notifications` is local-only (no FCM/Firebase) — cite package usage in `lib/core/notifications/`
  - [x] Document debug vs release INTERNET policy (debug may have INTERNET for Flutter tooling; release must not — Story 7.2 verifies manifest)
  - [x] Remove stale "Epic 5 Story 5.1" deferral text; mark FR-27 package audit **complete** in this story
  - [x] Keep existing KGP patch section (Story 5.5) — still accurate reference material

- [x] **G — Update `docs/README.md`** (AC: #2)
  - [x] Move FR-27 files from "Planned deliverables" to "Active" with correct status
  - [x] Note `BETA_CHECKLIST.md` remains Story 7.3

- [x] **H — Verification** (AC: #1–#3)
  - [x] Manual read-through: new contributor can find license, docs, airplane protocol without opening `_bmad-output/`
  - [x] No Dart code changes required unless a broken link fix is discovered
  - [x] Each sub-task → separate commit per `docs/project-context.md`

---

## Dev Notes

### Current state — gap analysis (read before editing)

| Artifact | Status | Action |
|----------|--------|--------|
| `LICENSE` | ✅ Apache 2.0 full text present | Verify only |
| `README.md` | ⚠️ Stale pre-implementation copy | Major refresh (Task B) |
| `docs/OPEN_WEARABLES_ALIGNMENT.md` | ⚠️ Minimal (16 lines) | Expand (Task E) |
| `docs/SERIES_TYPES.md` | ❌ Missing | Create (Task C) |
| `docs/REGULATORY_POSITION.md` | ❌ Missing | Create (Task D) |
| `docs/DEPENDENCIES.md` | ⚠️ Partial — fonts, KGP, 4 packages | Complete audit table (Task F) |
| `docs/README.md` | ❌ Says FR-27 files "do not exist yet" | Update (Task G) |
| `docs/BETA_CHECKLIST.md` | ❌ Story 7.3 | Do not create here |

### Architecture compliance

- **Documentation-only story** — no changes to ingestion pipeline, SQLite schema, or UI behavior
- FR-27 docs live in `docs/` per architecture tree [Source: `architecture.md` §Project Structure]
- Do **not** add `http`, analytics, or cloud SDK references while auditing dependencies
- Preserve review-before-commit workflow from `docs/project-context.md` — one commit per sub-task (A–H)

### Technical requirements

**LICENSE (FR-26):**
- File already at repo root; do not replace with MIT or custom license
- README License section must link `[Apache License 2.0](LICENSE)` without "planned" qualifier

**SERIES_TYPES.md content must match code:**

| Field | Phase 0 value | Source |
|-------|---------------|--------|
| `type` | `steps` | `migrations.dart` CHECK constraint |
| `unit` | `count` | CSV codec + models |
| `resolution` | `5min` \| `1hour` \| `1d` | `normalized_step_bucket.dart` |
| `provider` | `internal_phone` | `data_ingestion_source.dart` |
| `device_id` | `smartphone` | `data_ingestion_source.dart` |
| `value` | non-negative integer for steps | schema CHECK |

**OPEN_WEARABLES_ALIGNMENT.md** must document CSV header exactly as:

```
id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset
```

(from `TimeseriesCsvCodec.headerRow`)

**REGULATORY_POSITION.md** must include:
- Product category: behavioral visibility / General Wellness
- CNIL local-only exemption context (April 2025 recommendation — user as sole controller)
- FDA wellness boundary (no clinical claims)
- Phase 0 scope: steps only, no BLE wearable data yet
- Disclaimer: not legal advice

**DEPENDENCIES.md** must audit all `pubspec.yaml` packages:

| Package | Network in health pipeline |
|---------|---------------------------|
| `flutter` / `flutter_bloc` | No |
| `sqflite`, `path`, `uuid` | No |
| `workmanager`, `pedometer` | No |
| `permission_handler` | No (OS permission dialogs only) |
| `fl_chart` | No |
| `flutter_local_notifications` | No — local channels only |
| `share_plus`, `path_provider`, `file_picker` | No data upload |
| `phosphoricons_flutter`, `figma_squircle` | No — bundled assets |

Dev deps (`sqflite_common_ffi`, `sqlite3`, `flutter_lints`) — test/desktop only, not shipped in release APK.

### File structure requirements

**Create:**
- `docs/SERIES_TYPES.md`
- `docs/REGULATORY_POSITION.md`

**Update:**
- `README.md`
- `docs/OPEN_WEARABLES_ALIGNMENT.md`
- `docs/DEPENDENCIES.md`
- `docs/README.md`

**Do not touch:**
- `lib/**` (unless dead link discovered)
- `android/**`, `ios/**` (Story 7.2)
- `_bmad-output/**` planning artifacts (reference only)
- `docs/BETA_CHECKLIST.md` (Story 7.3)

### Testing requirements

- **No new automated tests** — documentation story
- Manual verification checklist:
  1. All four FR-27 files exist and cross-link
  2. README airplane protocol uses current tab names (Today, Trends, Data)
  3. README does not claim "pre-implementation" or "scaffold not initialized"
  4. `DEPENDENCIES.md` lists every `pubspec.yaml` dependency
  5. `REGULATORY_POSITION.md` explicitly states wellness-only boundary
- Optional: `flutter analyze` if any doc link paths are validated in comments (not required)

### README sections to preserve (do not delete)

- Product principles (proof over promises, local-first, etc.)
- Airplane mode protocol (update labels only)
- Architecture pipeline diagram
- Tech stack table
- Data model summary
- "What ASTRA is not" section
- Roadmap table

### README sections requiring correction

| Section | Problem | Fix |
|---------|---------|-----|
| Project status | "Pre-implementation" | Reflect Epics 1–6 done, beta-prep phase |
| License row | "to be added" | Link to existing LICENSE |
| Interface | 3 surfaces | 4 tabs per Epic 5 |
| Developer setup | `flutter create` only | Add run/test/build commands |
| Contributing | "implementation upcoming" | Active contribution with review gate |
| Sprint tracker note | "all backlog" | Point to live `sprint-status.yaml` |
| License footer | "planned" | Apache 2.0 active |

### Cross-story boundaries

| Story | Owns |
|-------|------|
| **7.1 (this)** | LICENSE verify, README pitch, FR-27 docs bundle |
| **7.2** | `test/release_manifest_test.dart`, release INTERNET audit, 24 h airplane mode field test, KGP release verification |
| **7.3** | `docs/BETA_CHECKLIST.md`, demo GIF item, 100% pass gate |

Do not duplicate 7.2 manifest test creation or 7.3 checklist in this story.

### Project context reference

- Review-before-commit mandatory — deliver review brief per sub-task; wait for Baptiste OK [Source: `docs/project-context.md`]
- Update `docs/DEPENDENCIES.md` when packages added — standard story completion checklist item
- Communication language: French for Baptiste; **all doc deliverables in English** per `config.yaml` `document_output_language`

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 7.1 AC]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-26, FR-27, SM-3, SM-7]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md` — §1 Licensing, §2 Schema, §10 Regulatory docs]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — OSS credibility, docs/ tree, FR mapping]
- [Source: `_bmad-output/planning-artifacts/research/domain-astra-local-first-health-hub-research-2026-05-22.md` — CNIL/FDA boundaries]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §4.6 copy/regulatory tone]
- [Source: `lib/data/csv/timeseries_csv_codec.dart` — OW CSV implementation]
- [Source: `lib/core/database/migrations.dart` — schema v2 truth]
- [Source: `lib/data/datasources/data_ingestion_source.dart` — provider/device constants]

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- LICENSE verified: Apache 2.0 full text at repo root (unchanged since Story 1.1)
- notification_service.dart path used for flutter_local_notifications audit (not lib/core/notifications/)

### Completion Notes List

- Task A: LICENSE unchanged; README license hedging removed
- Task B: README refreshed — 4 tabs, implemented status, dev commands, FR-27 doc links, airplane protocol labels
- Task C: Created SERIES_TYPES.md aligned with normalized_step_bucket.dart and data_ingestion_source.dart
- Task D: Created REGULATORY_POSITION.md — General Wellness, CNIL/FDA framing, disclaimer
- Task E: Expanded OPEN_WEARABLES_ALIGNMENT.md — 10-column mapping, idx_bucket_identity, JSON example
- Task F: DEPENDENCIES.md — full pubspec audit table, local notifications proof, debug/release INTERNET note, FR-27 complete
- Task G: docs/README.md — FR-27 files active; BETA_CHECKLIST deferred to 7.3
- Task H: Manual verification — contributor path: README → docs/README.md → four FR-27 files; no lib/ changes

### File List

- README.md (updated)
- docs/SERIES_TYPES.md (created)
- docs/REGULATORY_POSITION.md (created)
- docs/OPEN_WEARABLES_ALIGNMENT.md (updated)
- docs/DEPENDENCIES.md (updated)
- docs/README.md (updated)
- _bmad-output/implementation-artifacts/sprint-status.yaml (updated)
- _bmad-output/implementation-artifacts/stories/7-1-open-source-license-and-documentation-bundle.md (updated)

---

## Change Log

- 2026-06-06: Story 7.1 implementation — OSS license verification, README refresh, FR-27 docs bundle (SERIES_TYPES, REGULATORY_POSITION, OW alignment, DEPENDENCIES audit, docs index)

---

## Git Intelligence Summary

Recent commits show active polish on DB session recovery, chart performance, and startup bounds — documentation should reflect the **current shipped app**, not the May 2025 planning state:

| Commit | Relevance |
|--------|-----------|
| `a22a1a4` fix(db): auto-reopen UI SQLite session | README should not imply fragile prototype |
| `6f71384` fix(trends): adaptive bar widths | Trends tab is production-ready |
| `df87fad` chore(assets): remove unused Material Icons | DEPENDENCIES.md: Phosphor-only iconography |
| `66377d4` perf(startup): bound today SQL queries | Mature performance posture for OSS credibility |

---

## Latest Technical Information

**Apache License 2.0:** Standard OSI-approved license; `LICENSE` file already contains canonical text from apache.org. README attribution sufficient — no SPDX file required for Phase 0.

**CNIL (April 2025):** Mobile health apps storing data locally only for personal use may fall outside GDPR processor obligations when user is sole controller. Document as architectural advantage, not legal guarantee. Full commercial EU launch needs counsel.

**FDA General Wellness (Jan 2026 revision):** Step counter + goal visualization = general wellness if no disease claims. ASTRA's "behavioral visibility tool" positioning aligns. Future wearable sensors (PPG) need re-evaluation before clinical-adjacent features.

**Open Wearables:** Schema vocabulary alignment only. ASTRA does not bundle OW server, SDK, or cloud sync. CSV column order matches OW export convention for user data portability.

---

## Story Completion Status

- **Status:** review
- **Epic 7:** First story — epic in-progress
- **Next story after done:** 7.2 Release Manifest Hardening and Privacy Audit
- **Completion note:** FR-27 documentation bundle complete; commits pending Baptiste review per project-context
