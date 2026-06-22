# Story 17.2: Pin file_picker to Exact Beta Version

Status: done

<!-- Refacto Epic 17 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 17-2 · refactoring-audit-master-v0.6.1.md §6.2 · REF-15 -->
<!-- Prerequisite: Story 17-1 done (share_plus removed; save-only export on file_picker 12.0.0-beta.5) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **maintainer**,
I want `file_picker` locked to a known-good version,
So that `flutter pub upgrade` cannot silently break CSV import/export.

## Acceptance Criteria

1. **Given** `pubspec.yaml`  
   **When** updated  
   **Then** dependency reads `file_picker: 12.0.0-beta.5` without caret `^` (REF-15)  
   **And** no other `file_picker` version constraint appears elsewhere in the repo

2. **Given** `flutter pub get`  
   **When** lockfile resolves  
   **Then** `pubspec.lock` lists exactly `version: "12.0.0-beta.5"` for direct `file_picker`  
   **And** committed lockfile matches resolved version (sha256 may change only if pub re-resolves same version — verify version string, not hash churn)

3. **Given** exact pin in place  
   **When** `flutter pub upgrade file_picker` runs  
   **Then** resolved version remains `12.0.0-beta.5` (no silent bump to `12.0.0-beta.6` or `12.0.0-beta.7`)

4. **Given** Story 17-1 save-only export and Story 4.4 import flows  
   **When** `flutter test --exclude-tags slow` runs after pin change  
   **Then** all tests pass — pin is dependency-only; no runtime behavior change expected

5. **Given** documentation hygiene  
   **When** story completes  
   **Then** `docs/DEPENDENCIES.md` states exact-pin policy (no `^`, intentional hold on beta.5, upgrade criteria documented)  
   **And** no misleading `^12.0.0-beta.5` references remain in docs for the locked version

6. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no app version bump** — Epic 17 closes with patch+1 (`0.7.1+16`) when stories 17-1–17-3 are done

**Covers:** REF-15 · Audit §6.2 stability note · NFR-REF-06 (keep essential `file_picker`)

**Depends on:** Story 17-1 complete.

**Out of scope:** Upgrading to `12.0.0-beta.6`/`beta.7`, `figma_squircle` removal (Story 17-3), CSV format or cubit logic changes.

## Tasks / Subtasks

- [x] **Sub-task A — Pin exact version in pubspec** (AC: #1, #2, #3)
  - [x] Read current `pubspec.yaml` line 20: `file_picker: ^12.0.0-beta.5`
  - [x] Change to exact pin: `file_picker: 12.0.0-beta.5` (no `^`, no range)
  - [x] Run `flutter pub get`
  - [x] Verify lockfile:

```powershell
Select-String -Path pubspec.lock -Pattern "file_picker" -Context 0,6
```

  - [x] Confirm resolved version is `"12.0.0-beta.5"`
  - [x] Run `flutter pub upgrade file_picker` — confirm version unchanged in `pubspec.lock`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Documentation update** (AC: #5)
  - [x] Update `docs/DEPENDENCIES.md`:
    - Direct-deps table row for `file_picker`: note **exact pin** (no caret)
    - Epic 5 UI packages note: replace "Beta pin" with "Exact pin at 12.0.0-beta.5 (REF-15)"
    - KGP section: add one line — hold at beta.5 until deliberate upgrade story; pub.dev latest prerelease is beta.7 (informational, do not upgrade in this story)
  - [x] Grep docs for stale caret references:

```powershell
rg "file_picker.*\\^|\\^12\\.0\\.0-beta" docs/ README.md pubspec.yaml
```

  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression verification** (AC: #4)
  - [x] Run targeted tests (My Data CSV paths):

```powershell
flutter test test/presentation/cubits/my_data_cubit_export_test.dart
flutter test test/presentation/cubits/my_data_cubit_import_test.dart
flutter test test/data/repositories/step_repository_export_test.dart
```

  - [x] Run full suite: `flutter test --exclude-tags slow`
  - [x] Optional sanity: `flutter analyze` (no new errors)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove `^` from `file_picker` in `pubspec.yaml` | Upgrade to beta.6/beta.7 |
| Verify lockfile + `pub upgrade` guard | Change `MyDataCubit` import/export logic |
| Update `docs/DEPENDENCIES.md` pin policy | APK size re-measurement (no dep change beyond pin syntax) |
| Regression test run | Epic 17 version bump (deferred to epic close) |
| `pubspec.yaml`, `pubspec.lock`, `docs/DEPENDENCIES.md` | KGP patches (file_picker needs none — Story 5.5) |

### Why pin beta.5 (do NOT upgrade)

Story 4.4 deliberately adopted `12.0.0-beta.5` for:
- Static `FilePicker.pickFile` / `FilePicker.saveFile` API (11.x → 12.x breaking change)
- AGP9-aware Gradle (no ASTRA KGP patch required)
- `saveFile` with `bytes` + `fileName` for CSV export (Story 17-1)

As of 2026-06-19, pub.dev latest prerelease is **`12.0.0-beta.7`** (beta.6/beta.7 published ~45h before audit). REF-15 explicitly locks **beta.5** — stability over chasing prerelease churn. Upgrading requires a **separate deliberate story** with manual CSV import/export device testing.

### Current state (read before editing)

```20:20:pubspec.yaml
  file_picker: ^12.0.0-beta.5
```

```140:147:pubspec.lock
  file_picker:
    dependency: "direct main"
    description:
      name: file_picker
      sha256: fc83774ce5bd7ce08168333b5e53dbe9090ec04eb21e7aa7cd7bac921032c934
      url: "https://pub.dev"
    source: hosted
    version: "12.0.0-beta.5"
```

Lockfile already resolves to beta.5 — this story **changes constraint semantics**, not runtime code. The caret allows `flutter pub upgrade` to pull beta.6+ when compatible; exact pin blocks that.

### Exact pin syntax (Flutter pub)

Per [Dart pub dependency docs](https://dart.dev/tools/pub/dependencies#version-constraints):

| Constraint | Meaning |
|------------|---------|
| `^12.0.0-beta.5` | Any compatible version ≥ beta.5 (prereleases within same major allowed) |
| `12.0.0-beta.5` | **Exactly** this version only |

This will be ASTRA's **first intentional exact pin** in `pubspec.yaml` (all other direct deps use `^`). Do not convert other packages — scope is REF-15 only.

### Runtime consumers (unchanged — verify tests only)

| Location | API used |
|----------|----------|
| `lib/presentation/cubits/my_data_cubit.dart` | `FilePicker.saveFile` (export), `FilePicker.pickFile` (import) |
| Tests | Injectable callbacks — no direct `file_picker` platform channel in unit tests |

No Dart import changes required for this story.

### Cross-story context (Epic 17)

| Story | Status | Relationship |
|-------|--------|--------------|
| **17-1** | done | Removed share_plus; explicitly deferred caret removal to 17-2 |
| **17-2** | this story | Pin only |
| **17-3** | backlog | Independent (`figma_squircle`) |

Epic 17 versioning: patch+1 at epic close → `0.7.1+16` when 17-1–17-3 done. Current app version: `0.7.0+15`.

### Previous story intelligence (17-1)

- Sub-task workflow: review brief → Baptiste OK → commit (one commit per sub-task)
- `file_picker` save-only export verified on device; `exportSuccessPending` gates snackbar
- Full suite **801 passed** at 17-1 close (`--exclude-tags slow`)
- KGP: only `pedometer` + `workmanager_android` patched; `file_picker` AGP9-aware, no patch
- Do **not** re-touch share_plus removal or cubit export logic

### Git intelligence (recent commits)

Recent Epic 17 pattern on `refacto`:
- `refactor(data): remove share_plus fallback from MyDataCubit export flow`
- `chore(deps): remove share_plus and KGP patch`
- `test(data): rewrite export tests for save-only CSV flow`

Suggested commit scopes for this story:
- `chore(deps): pin file_picker to exact 12.0.0-beta.5`
- `docs(deps): document file_picker exact pin policy`

### Architecture compliance

- **REF-15 / NFR-REF-06:** Keep `file_picker`; only constrain version resolution
- **NFR-REF-03:** No APK impact expected (same resolved version) — skip `--analyze-size` unless lockfile unexpectedly changes transitive tree
- **Review-before-commit:** per `docs/project-context.md`
- **Branch:** `refacto` only until merge review

### Library / framework requirements

| Package | Target constraint | Resolved | Notes |
|---------|-------------------|----------|-------|
| `file_picker` | `12.0.0-beta.5` (exact) | `12.0.0-beta.5` | Beta channel; no stable 12.x yet |
| `path_provider` | `^2.1.5` (unchanged) | — | Temp dir staging for export |

**Do not upgrade** despite pub.dev showing `12.0.0-beta.7` as latest prerelease.

### File structure requirements

| File | Action |
|------|--------|
| `pubspec.yaml` | **UPDATE** — remove `^` from `file_picker` line |
| `pubspec.lock` | **UPDATE** — commit after `flutter pub get` (repo tracks lockfile: `.gitignore` has `!pubspec.lock`) |
| `docs/DEPENDENCIES.md` | **UPDATE** — exact pin policy + upgrade criteria |
| `lib/**` | **NO CHANGE** |
| `test/**` | **NO CHANGE** (run only) |
| `README.md` | **NO CHANGE** unless it mentions `^12.0.0-beta.5` (currently generic "file_picker") |

### Testing requirements

| Command | Purpose |
|---------|---------|
| `flutter pub get` | Lock resolves to beta.5 |
| `flutter pub upgrade file_picker` | Proves pin blocks upgrade |
| `flutter test test/presentation/cubits/my_data_cubit_export_test.dart` | Export path regression |
| `flutter test test/presentation/cubits/my_data_cubit_import_test.dart` | Import path regression |
| `flutter test --exclude-tags slow` | Full regression (AC #4) |

No new tests required — dependency constraint change with identical resolved artifact.

### Regression risks

| Risk | Mitigation |
|------|------------|
| Accidental upgrade to beta.6+ | Exact pin + `flutter pub upgrade file_picker` verification |
| Lockfile drift / merge conflict | Only version constraint changes; re-run `flutter pub get` |
| Docs still say `^12.0.0-beta.5` | Grep docs after Sub-task B |
| Developer "helpfully" upgrades while pinning | Story explicitly forbids beta.6/beta.7 |

### Upgrade criteria (document in DEPENDENCIES.md)

Document for future maintainers — **not actionable in this story**:

1. pub.dev publishes stable `12.0.0` (non-beta), **or**
2. Deliberate story to evaluate beta.6+ with manual Android CSV import/export + full test suite
3. Re-check AGP/KGP compatibility (Story 5.5 criteria)

### Manual verification (optional, quick)

If Baptiste wants extra confidence beyond unit tests:
1. My Data → Export CSV → save dialog opens (same as 17-1)
2. My Data → Import CSV → pick dialog opens

Not required for AC — identical resolved package version.

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 17-2, REF-15]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §6.2 file_picker pin strategy]
- [Source: `_bmad-output/implementation-artifacts/stories/17-1-replace-share-plus-with-file-picker-csv-export.md` — deferred pin, saveFile API]
- [Source: `_bmad-output/implementation-artifacts/stories/4-4-csv-import.md` — beta.5 adoption rationale]
- [Source: `pubspec.yaml` — current caret constraint]
- [Source: `pubspec.lock` — committed lockfile policy]
- [Source: `docs/DEPENDENCIES.md` — dependency inventory]
- [Source: `docs/project-context.md` — review-before-commit, DEPENDENCIES update rule]
- [Source: pub.dev file_picker — latest prerelease 12.0.0-beta.7 (do not upgrade)]

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- `flutter pub get` — resolved `file_picker 12.0.0-beta.5` (beta.7 available, blocked by exact pin)
- `flutter pub upgrade file_picker` — "No dependencies changed"
- `pubspec.lock` version confirmed: `"12.0.0-beta.5"` (no lockfile diff — constraint-only change)
- Targeted CSV tests: 20 passed
- Full suite: 802 passed, 2 skipped (`--exclude-tags slow`)
- `flutter analyze`: 15 pre-existing info/warnings, no new errors

### Completion Notes List

- Sub-task A: Removed `^` from `file_picker` in `pubspec.yaml` — exact pin `12.0.0-beta.5`. Lockfile unchanged (already at beta.5). `flutter pub upgrade file_picker` confirms pin blocks beta.6/beta.7.
- Sub-task B: Updated `docs/DEPENDENCIES.md` — exact pin policy, REF-15 note, upgrade criteria, beta.7 informational. Grep clean in `docs/` and `README.md`.
- Sub-task C: All CSV regression tests pass; full suite 802 passed. No runtime code changes.
- Code review approved; story marked done.

### File List

- `pubspec.yaml` — exact pin `file_picker: 12.0.0-beta.5`
- `docs/DEPENDENCIES.md` — exact pin policy and upgrade criteria
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` — status review → done
- `_bmad-output/implementation-artifacts/stories/17-2-pin-file-picker-to-exact-beta-version.md` — story tracking

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Story implemented — exact pin applied, docs updated, 802 tests pass. Status → review.
- 2026-06-19: Code review approved. Status → done.
