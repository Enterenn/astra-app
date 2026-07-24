# Story 32.3: Privacy at Rest — Product Decision (Disclaimer or SQLCipher)

Status: review

<!-- audits_2 Epic 32 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 32-3 · diagnostic-couche-donnees.md #1 · AUD2-FR12 · AUD2-FR33 · AUD2-UX4 · AUD2-NFR3 -->
<!-- Prerequisite: Story 32-2 done · Epic 29–31 delivered -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want the app to honestly state how my health data is protected on device,
So that privacy claims match actual storage.

## Acceptance Criteria

1. **Given** Phase 0 plaintext SQLite (`sqflite` without SQLCipher) — AUD2-FR12
   **When** product chooses **disclaimer path** (default for this epic unless Baptiste selects SQLCipher)
   **Then** My Data / privacy copy states health data is stored locally without encryption — AUD2-FR33, AUD2-UX4
   **And** marketing-facing docs aligned with NFR-4 Phase 0 stance

2. **Given** product chooses **SQLCipher path** instead
   **When** implemented
   **Then** `sqlcipher_flutter_libs` (or project-standard package) encrypts `astra_app.db` with Keystore-derived passphrase per architecture Phase 1 notes
   **And** UX4 copy reflects encrypted storage

3. **Given** either path
   **When** story closes
   **Then** decision recorded in story notes and `audits_2/README.md` P0-01 status updated

**Covers:** AUD2-FR12 · AUD2-FR33 · AUD2-UX4 · AUD2-NFR3 · diagnostic-couche-donnees.md #1 · audits_2/README.md P0-01

**Depends on:** Story 32-2 (orthogonal — no file conflict)

**Out of scope:**
- Goal single source / `isDatabaseOpen` (32-4)
- Test hook / migration v3 clock (32-5)
- Onboarding trust copy rewrite (already honest: local-only, no cloud — does not claim encryption)
- SQLCipher recovery phrase UX (Phase 1 addendum §4.1 — only if SQLCipher path and Baptiste explicitly scopes it)
- `pubspec.yaml` version bump (Epic 32 close = patch+1)

## Tasks / Subtasks

### Gate 0 — Product decision (blocking)

- [x] **Sub-task 0 — Record path choice** (AC: #3)
  - [x] Baptiste selects **Path A (disclaimer)** or **Path B (SQLCipher)** before any code
  - [x] Record choice in Dev Agent Record → Completion Notes (`Path A` default per epic)
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (decision note only, or proceed to path tasks)

### Path A — Disclaimer (default)

- [x] **Sub-task A1 — My Data privacy note UI** (AC: #1, AUD2-UX4)
  - [x] Read fully: `lib/presentation/screens/my_data_screen.dart` (Footprint `SectionCard` ~L204-214)
  - [x] Add sober trust copy **inside** the Footprint section, **below** `FootprintKpiRow` (preserve UX V-8 order: Background → Footprint → Your data)
  - [x] Style: `AstraTypography.captionFor(colors)` — same tier as footprint KPI labels; no banner/warning chrome (trust copy, not error state)
  - [x] EN + FR via new ARB keys (see Dev Notes — suggested keys/copy)
  - [x] Include semantics label for screen readers
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task A2 — Widget regression test** (AC: #1)
  - [x] Extend `test/presentation/screens/my_data_screen_test.dart` (seeded `_SeededMyDataCubit` pattern — no async DB)
  - [x] Assert disclaimer string visible in Footprint section when `MyDataStatus.ready`
  - [x] Run: `flutter test test/presentation/screens/my_data_screen_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task A3 — Docs + project context** (AC: #1, NFR-4)
  - [x] `README.md` Phase 0 section: one explicit bullet that local SQLite is **not encrypted at rest** in Phase 0 (align with existing "SQLCipher encryption (Phase 1)" excluded list — add plaintext honesty, do not remove Phase 1 roadmap)
  - [x] `docs/project-context.md`: add short **Data at rest (NFR-4)** subsection — Phase 0 plaintext OK; Phase 1 SQLCipher path documented in architecture/addendum; in-app disclosure on My Data
  - [x] Do **not** rewrite historical rows in `docs/BETA_CHECKLIST.md`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task A4 — Diagnostic close** (AC: #3)
  - [x] Update `diagnostic-couche-donnees.md` #1 → `fixed` (32-3, Path A disclaimer)
  - [x] Sync `audits_2/README.md` P0-01 row → `fixed` (32-3, disclaimer)
  - [x] Update diagnostic inventory table row #1 statut → `fixed`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

### Path B — SQLCipher (only if Baptiste selects)

- [ ] **Sub-task B1 — Dependency + open path** (AC: #2)
  - [ ] Add project-standard SQLCipher stack per `addendum.md` §4.1 (`sqlcipher_flutter_libs` + sqflite SQLCipher factory — verify current pub.dev compatibility with `sqflite ^2.4.2+1`)
  - [ ] Update `lib/core/database/app_database.dart`: passphrase from Android Keystore / iOS Keychain wrapper (new small service under `lib/core/security/` or `lib/core/database/`)
  - [ ] Preserve existing PRAGMAs: WAL, `foreign_keys`, `busy_timeout` (Story 30-2)
  - [ ] Document migration strategy: existing plaintext `astra_app.db` users → export/re-import or dedicated migration story (call out in Dev Agent Record if deferred)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task B2 — UX copy (encrypted)** (AC: #2, AUD2-UX4)
  - [ ] Same Footprint placement as Path A but copy states AES-256 / encrypted local storage (honest, no over-claim beyond SQLCipher)
  - [ ] Widget test + critical suite
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task B3 — Docs + diagnostic close** (AC: #3)
  - [ ] Update README, `docs/project-context.md`, `docs/DEPENDENCIES.md` (new native dep)
  - [ ] Close diagnostic #1 + P0-01 as `fixed` (32-3, SQLCipher)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Plaintext DB today:** `openAstraDatabase` uses vanilla `sqflite` → `astra_app.db` on device storage. Health rows in `timeseries_samples` are readable if the device/filesystem is compromised.

```12:26:lib/core/database/app_database.dart
Future<Database> openAstraDatabase({String? databasePath}) async {
  final path = databasePath ?? join(await getDatabasesPath(), 'astra_app.db');
  // ...
  return openDatabase(
    path,
    version: kDbVersion,
    onConfigure: (db) async {
      // WAL, foreign_keys, busy_timeout — no encryption
```

| Reference | Detail |
|-----------|--------|
| `pubspec.yaml:14` | `sqflite: ^2.4.2+1` — no `sqlcipher_flutter_libs` |
| `architecture.md` | NFR-4: plaintext OK Phase 0; SQLCipher Phase 1 |
| `addendum.md` §4.1 | AES-256 SQLCipher; key in Keystore/Keychain; recovery phrase Phase 1 |
| `diagnostic-couche-donnees.md` #1 | P0 open — marketing/research used "encrypted" positioning vs Phase 0 reality |

**Gap to close:** AUD2-NFR3 — user-facing protection level must match reality. In-app copy on **My Data → Footprint** is the primary AUD2-UX4 surface. Onboarding already says local-only / no cloud — it does **not** claim encryption; no onboarding change required unless Baptiste asks.

**What is NOT broken today:** Release manifest privacy (Story 7.2), offline proof, no cloud — this story is **at-rest honesty**, not network privacy.

[Source: `diagnostic-couche-donnees.md` #1 · `audits_2/README.md` P0-01 · AUD2-FR12]

### Recommended implementation — Path A (default)

**Minimal UI change:** In `my_data_screen.dart`, wrap Footprint section child in `Column`:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    FootprintKpiRow(...),
    const SizedBox(height: AstraSpacing.kSpaceSm),
    Semantics(
      label: l10n.myDataFootprintStorageProtectionSemantics,
      child: Text(
        l10n.myDataFootprintStorageProtectionPlaintext,
        style: AstraTypography.captionFor(colors),
      ),
    ),
  ],
)
```

**Suggested ARB keys (EN — tune with Baptiste at review):**

| Key | EN copy (starting point) |
|-----|--------------------------|
| `myDataFootprintStorageProtectionPlaintext` | Stored locally on this device without encryption. Data never leaves your phone, but is not protected if someone accesses your unlocked device or backup files. |
| `myDataFootprintStorageProtectionSemantics` | Local storage protection: data is not encrypted at rest on this device. |

**FR (starting point):**

| Key | FR copy |
|-----|---------|
| `myDataFootprintStorageProtectionPlaintext` | Stocké localement sur cet appareil sans chiffrement. Les données ne quittent jamais votre téléphone, mais ne sont pas protégées si quelqu'un accède à votre appareil déverrouillé ou à vos sauvegardes. |
| `myDataFootprintStorageProtectionSemantics` | Protection du stockage local : les données ne sont pas chiffrées au repos sur cet appareil. |

Run `flutter gen-l10n` after ARB edits (or build — project generates localizations from ARB).

**Do NOT:**
- Use `StatusBanner` (reads as error/stale, not trust disclosure)
- Claim "secure" or "protected" without qualifying plaintext
- Add README footer link on My Data (UX D-7 locked: no external links Phase 0)
- Implement SQLCipher while Path A is selected

### Path B — SQLCipher guardrails (if selected)

Pulls Phase 1 scope forward — expect **multi-sub-task epic** within this story:

| Requirement | Source |
|-------------|--------|
| AES-256 at rest | `addendum.md` §4.1 |
| Key in Android Keystore / iOS Keychain | `addendum.md` §4.1 |
| Migration from plaintext | export/re-import or in-place tool — document choice |
| Preserve D-24 txn boundaries | `architecture.md` |
| FFI tests | `sqflite_common_ffi` tests may need SQLCipher factory or stay on in-memory vanilla for unit tests — document split |
| `docs/DEPENDENCIES.md` | New native dependency row + network column |

**Package research (2026):** Prefer `sqlcipher_flutter_libs` + SQLCipher-enabled sqflite open helper compatible with Dart 3.12 / Flutter 3.x. Verify Android/iOS build before committing. No second DB package (addendum constraint).

**UX copy (encrypted path):** Parallel ARB keys e.g. `myDataFootprintStorageProtectionEncrypted` — state encrypted local database; avoid "unbreakable" marketing language.

### Architecture compliance

| Rule | Application |
|------|-------------|
| NFR-4 | Phase 0 plaintext acceptable; story closes honesty gap via disclosure OR Phase 1 encryption |
| AUD2-UX4 | Footprint section reflects actual at-rest protection |
| UX V-8 | Background → Footprint (KPI + note) → Your data — do not reorder sections |
| UX §3.5 | Footprint KPI row unchanged; note is additive caption below KPIs |
| D-06 / 30-2 | If SQLCipher: keep WAL + `busy_timeout` + `foreign_keys` in `onConfigure` |
| Agent rule #17 | No dev-tool changes needed for this story |
| Token economy | Path A = small diff (screen + ARB + docs); avoid new widgets unless reused |

[Source: `architecture.md` §Authentication & Security · `ux-design-specification.md` §3.5, V-8]

### File structure requirements

**Path A (expected):**

| File | Action |
|------|--------|
| `lib/presentation/screens/my_data_screen.dart` | **UPDATE** — Footprint privacy note |
| `lib/l10n/app_en.arb` | **UPDATE** — new keys |
| `lib/l10n/app_fr.arb` | **UPDATE** — new keys |
| `lib/l10n/app_localizations*.dart` | Generated — do not hand-edit |
| `test/presentation/screens/my_data_screen_test.dart` | **UPDATE** — assert disclaimer visible |
| `README.md` | **UPDATE** — Phase 0 plaintext bullet |
| `docs/project-context.md` | **UPDATE** — NFR-4 subsection |
| `planning-artifacts/audits_2/diagnostic-couche-donnees.md` | Close #1 |
| `planning-artifacts/audits_2/README.md` | P0-01 → fixed |

**Path B (additional):**

| File | Action |
|------|--------|
| `pubspec.yaml` | Add SQLCipher deps |
| `lib/core/database/app_database.dart` | Encrypted open |
| `lib/core/database/` or `lib/core/security/` | **NEW** — key escrow helper |
| `docs/DEPENDENCIES.md` | Audit row |
| `test/helpers/sqflite_test_helper.dart` | May need review for encrypted vs in-memory test DB |

**Do not touch (Path A):** `app_database.dart`, `migrations.dart`, ingestion repos, onboarding screens.

### Testing requirements

| Verify | Command |
|--------|---------|
| My Data widget test | `flutter test test/presentation/screens/my_data_screen_test.dart` |
| Critical gate | `flutter test --tags critical` |

Do **not** run bare `flutter test`.

**Path A regression focus:** Existing My Data tests (export/import/purge/background) must stay green — disclaimer is read-only UI.

**Path B additional:** Encrypted DB open smoke test; migration path manual checklist; release build on device.

### Previous story intelligence

| Learning | Impact on 32-3 |
|----------|----------------|
| 32-2: OK commit gate A→C | Follow Gate 0 → A1→A4 (Path A) with separate commits |
| 32-2: diagnostic + README sync pattern | Mirror in A4 — #1 + P0-01 |
| 32-1/32-2: Epic 32 same sprint file | Tracker = `sprint-status-audits-2.yaml` |
| 7-2: privacy = manifest/network | Complementary — 32-3 is storage-at-rest honesty |
| 19-2: My Data l10n via ARB | Add keys same way as `myDataFootprint*` family |

[Source: `stories/32-2-release-safe-guard-on-dev-sample-batch-insert.md`]

### Cross-story context (Epic 32)

| Story | Status | Relationship |
|-------|--------|--------------|
| 32-1 | done | ID alignment — orthogonal |
| 32-2 | done | Dev guard — orthogonal |
| **32-3** | **this story** | Product decision — privacy honesty |
| 32-4 | backlog | Goal source + `isDatabaseOpen` |
| 32-5 | backlog | Test hook + migration v3 |

**Epic 32 close after 32-5:** bump `pubspec.yaml` patch+1 + `README.md` per sprint tracker.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `c45260e` | Story 32-2 done — latest Epic 32 |
| `41e748f` / `ae04f84` | 32-2 guard pattern — separate test + diagnostic commits |
| `384ce70` | 32-1 — diagnostic close pattern for P0 rows |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.0+34`.

### Latest tech / library notes

- **Path A:** No package upgrade.
- **Path B:** `sqlcipher_flutter_libs` — native SQLCipher for Flutter; must align with AGP/KGP setup (Story 5.5). Check sqflite encryption API for 2.4.x before implementing.
- **Marketing drift:** `market-astra-local-first-health-hub-research-2026-05-22.md` tagline says "encrypted" — research doc only, not in-app. README Phase 0 already lists SQLCipher as excluded; add explicit plaintext bullet for AUD2-FR33 alignment.

### Project context reference

- OK commit gate: sub-tasks with separate commits after Baptiste approval
- Tests: targeted file + `flutter test --tags critical`
- Version bump: Epic 32 close — not per story
- Chat French; story/doc English per BMAD config

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 32-3, AUD2-FR12, AUD2-FR33, AUD2-UX4]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md` #1]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` P0-01]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §NFR-4, §Encryption at rest]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md` §4.1 SQLCipher]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §3.5, V-8]
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-24.md` §UX ↔ Epics]
- [Source: `lib/presentation/screens/my_data_screen.dart`]
- [Source: `lib/core/database/app_database.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/32-2-release-safe-guard-on-dev-sample-batch-insert.md`]

## Dev Agent Record

### Agent Model Used

Composer (create-story) · Composer (dev-story)

### Debug Log References

- Path A selected by Baptiste 2026-07-25 — explicit Phase 1 SQLCipher roadmap in disclaimer + README (product positioning, not just technical)

### Completion Notes List

- **Path A** — disclaimer + Phase 1 roadmap (product/risk positioning choice, not deferred security work)
- Footprint section: caption below KPIs, `AstraTypography.captionFor`, Semantics label EN/FR
- Copy states plaintext at rest + SQLCipher planned Phase 1 (honest + reassuring)
- README Included bullet + `docs/project-context.md` NFR-4 subsection
- Diagnostic #1 + P0-01 closed as `fixed` (32-3)
- Tests: `my_data_screen_test.dart` + `flutter test --tags critical` green

### File List

- `lib/presentation/screens/my_data_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart` (generated)
- `lib/l10n/app_localizations_en.dart` (generated)
- `lib/l10n/app_localizations_fr.dart` (generated)
- `test/presentation/screens/my_data_screen_test.dart`
- `README.md`
- `docs/project-context.md`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/stories/32-3-privacy-at-rest-product-decision.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`

## Change Log

- 2026-07-25: Story 32-3 created — privacy-at-rest product decision (disclaimer default vs SQLCipher branch)
- 2026-07-25: Path A implemented — Footprint disclaimer + Phase 1 SQLCipher roadmap, docs, diagnostic P0-01 closed
