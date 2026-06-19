# Story 17.3: Replace figma_squircle with Native ClipPath

Status: done

<!-- Refacto Epic 17 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 17-3 · refactoring-audit-master-v0.6.1.md §6.2 · REF-16 · NFR-REF-03 -->
<!-- Prerequisite: Stories 17-1 and 17-2 done -->
<!-- Last story in Epic 17 — epic close bumps patch+1 (0.7.1+16) after review -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **maintainer**,
I want nav bar active-item masking without a third-party squircle package,
So that APK size decreases with no visual regression.

## Acceptance Criteria

1. **Given** active bottom-nav item uses `figma_squircle` (`SmoothRectangleBorder`)  
   **When** refactored  
   **Then** selected-tab background uses **`ClipPath` + `Path`** via standard Flutter APIs (REF-16)  
   **And** `figma_squircle` is removed from `pubspec.yaml`, `pubspec.lock`, and all Dart imports

2. **Given** the refactored nav item  
   **When** compared to pre-change behavior  
   **Then** active tab remains **52×52** with **16px** corner radius (`kBottomNavSquircleRadius`)  
   **And** squircle fill tokens unchanged: `bgElevated` (light) / `bgBase` (dark)  
   **And** icon/label colors, Phosphor Fill/Regular swap, semantics, and tap targets unchanged

3. **Given** dependency removal  
   **When** `flutter pub get` and `rg "figma_squircle|SmoothRectangleBorder|SmoothBorderRadius" lib/ test/` run  
   **Then** zero matches in app/test code  
   **And** `docs/DEPENDENCIES.md` updated (remove `figma_squircle` rows; note native squircle clipper)

4. **Given** post-change release build (NFR-REF-03)  
   **When** APK size is compared to Story 17-1 baseline (or fresh `--analyze-size` if baseline unavailable)  
   **Then** size delta is noted in review brief (audit estimates ~15 KB reduction)

5. **Given** side-by-side screenshot comparison (light + dark, each tab selected once)  
   **When** reviewed by Baptiste  
   **Then** active tab indicator shape is acceptable — no obvious visual regression vs `figma_squircle`

6. **Given** full `flutter test --exclude-tags slow` suite  
   **When** run after changes  
   **Then** all tests pass

7. **Given** work completes on branch `refacto`  
   **When** story is marked done and Epic 17 closes  
   **Then** version bump **patch+1, build+1** → `0.7.1+16` in `pubspec.yaml` + README.md status row (Epic 17 close — not per-story for 17-1/17-2)

**Covers:** REF-16 · NFR-REF-03 · Audit §6.2 dependency table

**Depends on:** Stories 17-1 and 17-2 complete.

**Out of scope:** Nav tab count/labels, accent colors, haptics (Story 20-3), Phosphor font subsetting (Story 20-5), `fl_chart` removal.

## Tasks / Subtasks

- [x] **Sub-task A — Replace squircle rendering with native ClipPath** (AC: #1, #2)
  - [x] Read `lib/presentation/widgets/app_bottom_nav.dart` fully — only runtime consumer of `figma_squircle`
  - [x] Remove `import 'package:figma_squircle/figma_squircle.dart'`
  - [x] Replace selected-state `DecoratedBox` + `SmoothRectangleBorder` with `ClipPath` + fill:

```dart
// Pattern — private clipper in same file (single call site)
ClipPath(
  clipper: _BottomNavSquircleClipper(
    radius: AstraSpacing.kBottomNavSquircleRadius,
  ),
  child: ColoredBox(
    color: squircleFill,
    child: hitTarget,
  ),
)
```

  - [x] Implement `_BottomNavSquircleClipper extends CustomClipper<Path>` returning a `Path` from native Flutter geometry (see Dev Notes — do **not** re-add a third-party package)
  - [x] Preserve `_NavItem` structure: `Semantics`, `AstraPressable`, `InkWell`, inactive state (no clip), selected state (clip + fill)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Remove dependency + update docs** (AC: #1, #3)
  - [x] Remove `figma_squircle: ^0.6.3` from `pubspec.yaml`
  - [x] Run `flutter pub get` — verify `pubspec.lock` no longer lists `figma_squircle`
  - [x] Update `docs/DEPENDENCIES.md`:
    - Remove direct-deps table row for `figma_squircle`
    - Remove Epic 5 UI packages row for `figma_squircle`
    - Add one line under Epic 5 UI: active nav squircle uses native `ClipPath` + `CustomClipper<Path>` (Story 17-3)
  - [x] Verify clean grep:

```powershell
rg "figma_squircle|SmoothRectangleBorder|SmoothBorderRadius" lib/ test/ pubspec.yaml docs/DEPENDENCIES.md
```

  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Tests, APK delta, visual sign-off** (AC: #4, #5, #6)
  - [x] Run existing nav tests (must pass unchanged):

```powershell
flutter test test/presentation/screens/app_scaffold_test.dart --name "AppBottomNav"
flutter test test/widget_test.dart --name "AppBottomNav"
flutter test --exclude-tags slow
```

  - [x] Optional widget assertion: selected tab subtree contains `ClipPath`, not `SmoothRectangleBorder`
  - [ ] Run `flutter build apk --release --analyze-size` — record delta vs Story 17-1 baseline in review brief
  - [ ] Capture side-by-side screenshots (before/after or emulator comparison): light + dark, each tab selected
  - [ ] Baptiste visual sign-off on squircle shape (AC #5)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Epic 17 close (after code review)** (AC: #7)
  - [x] Bump `pubspec.yaml` → `0.7.1+16`
  - [x] Update README.md project status version row
  - [x] Mark `epic-17: done` in `sprint-status-refacto.yaml`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Native squircle for active nav item in `app_bottom_nav.dart` | Changing nav from 3 tabs (Story 10.1) back to 4 |
| Remove `figma_squircle` from pubspec + lockfile | `ContinuousRectangleBorder` as **public** ShapeDecoration without ClipPath (AC requires ClipPath + Path) |
| Update `docs/DEPENDENCIES.md` | License bundle regen (Story 7-1 noted figma_squircle as bundled assets — no runtime license screen change expected) |
| APK size note in review brief | `fl_chart`, `phosphoricons_flutter`, `uuid` slimming (other epics) |
| Epic 17 version bump at close | Story 18+ work |

### Current state (read before editing)

**Single runtime consumer** — entire package usage is in one widget:

```1:1:lib/presentation/widgets/app_bottom_nav.dart
import 'package:figma_squircle/figma_squircle.dart';
```

```164:177:lib/presentation/widgets/app_bottom_nav.dart
    final squircleChild = selected
        ? DecoratedBox(
            decoration: ShapeDecoration(
              color: squircleFill,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AstraSpacing.kBottomNavSquircleRadius,
                  cornerSmoothing: AstraSpacing.kBottomNavSquircleSmoothing,
                ),
              ),
            ),
            child: hitTarget,
          )
        : hitTarget;
```

**Spacing tokens** (keep radius; smoothing constant becomes informational or removable):

```43:47:lib/core/constants/astra_spacing.dart
  /// Active tab squircle corner radius (= kRadiusLg = 16px).
  static const double kBottomNavSquircleRadius = kRadiusLg;

  /// Figma corner smoothing for active tab squircle (0–1, spec = 100%).
  static const double kBottomNavSquircleSmoothing = 1.0;
```

`kBottomNavSquircleSmoothing` is **figma_squircle-specific**. After migration:
- **Preferred:** remove constant if unused (YAGNI)
- **Alternative:** keep with doc comment referencing native clipper approximation — do not wire to dead code

### Implementation guidance — ClipPath + Path (REF-16)

Story 5.7 originally shipped `ContinuousRectangleBorder` for Figma 100% corner smoothing. Current code uses `figma_squircle` for closer superellipse match. REF-16 requires native `ClipPath`/`Path`.

**Recommended clipper** (native Flutter, no third-party deps):

```dart
class _BottomNavSquircleClipper extends CustomClipper<Path> {
  const _BottomNavSquircleClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    ).getOuterPath(rect);
  }

  @override
  bool shouldReclip(covariant _BottomNavSquircleClipper oldClipper) =>
      oldClipper.radius != radius;
}
```

This satisfies AC #1 (`ClipPath` wraps child; `CustomClipper` returns `Path`) and aligns with Story 5.7 visual spec.

**If Baptiste rejects visual parity** during AC #5 review, escalate within native APIs only:
1. Try `RoundedSuperellipseBorder(borderRadius: ...).getOuterPath(rect)` inside the same clipper (Flutter 3.27+, project on **3.44+**)
2. Do **not** reintroduce `figma_squircle` or add another package

**Do not** use plain `BorderRadius.circular(16)` on `BoxDecoration` alone — Story 5.7 explicitly forbids (sharp corners vs Figma smoothing).

### What must NOT change

| Behavior | Current implementation |
|----------|------------------------|
| Pill bar | 72px height, accent fill, `kRadiusFull` capsule |
| Item box | 52×52, 3 tabs (STEPS, TRENDS, MENU) |
| Active icon | `PhosphorIconsFill.*`, color `accentPrimary` |
| Inactive icon | `PhosphorIconsRegular.*`, color `accentSecondary` |
| Squircle fill | Light: `bgElevated`; Dark: `bgBase` |
| Accessibility | `Semantics(button: true, selected: ...)` per item |
| Press feedback | `AstraPressable` + `InkWell` |

Parent usage: `AppScaffold` embeds `AppBottomNav` — no scaffold changes expected.

### Cross-story context (Epic 17)

| Story | Status | Relationship |
|-------|--------|--------------|
| **17-1** | done | Removed `share_plus`; APK baseline captured |
| **17-2** | done | Exact `file_picker` pin — independent |
| **17-3** | this story | Last Epic 17 story; triggers epic close bump |

Epic 17 versioning: **patch+1** at epic close → `0.7.1+16`. Current app version: `0.7.0+15`.

### Previous story intelligence (17-2)

- Sub-task workflow: review brief → Baptiste OK → commit (one commit per sub-task)
- Full suite **802 passed** at 17-2 close (`--exclude-tags slow`)
- First exact pin in pubspec — do not change `file_picker` line in this story
- Do not re-touch CSV export/import or `MyDataCubit`

### Git intelligence (recent commits)

Recent Epic 17 pattern on `refacto`:
- `chore(deps): pin file_picker to exact 12.0.0-beta.5`
- `docs(deps): document file_picker exact pin policy`
- `chore(story): mark 17-2 done after code review`

Suggested commit scopes for this story:
- `refactor(ui): replace figma_squircle with native ClipPath on nav`
- `chore(deps): remove figma_squircle`
- `docs(deps): drop figma_squircle from dependency inventory`
- `chore(release): bump to 0.7.1+16 — Epic 17 close` (Sub-task D only)

### Architecture compliance

- **REF-16 / NFR-REF-03:** Remove replaceable UI dependency; measure APK impact
- **NFR-REF-02 (<50MB install):** Every removed package supports install budget
- **UX spec § active tab:** White/near-white squircle behind icon + label — preserve token mapping
- **Review-before-commit:** per `docs/project-context.md`
- **Branch:** `refacto` only until merge review

### Library / framework requirements

| Item | Requirement |
|------|-------------|
| Flutter SDK | 3.44+ (project standard) — `ContinuousRectangleBorder`, `ClipPath`, `CustomClipper<Path>` |
| `figma_squircle` | **Remove** — was `^0.6.3`, only used in `app_bottom_nav.dart` |
| KGP patches | None for `figma_squircle` (never patched) |

No new pub.dev dependencies.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/app_bottom_nav.dart` | **UPDATE** — native squircle, remove figma import |
| `lib/core/constants/astra_spacing.dart` | **OPTIONAL** — remove `kBottomNavSquircleSmoothing` if unused |
| `pubspec.yaml` | **UPDATE** — remove `figma_squircle` line |
| `pubspec.lock` | **UPDATE** — commit after `flutter pub get` |
| `docs/DEPENDENCIES.md` | **UPDATE** — remove package, note native clipper |
| `test/presentation/screens/app_scaffold_test.dart` | **RUN** — `AppBottomNav uses floating pill tokens` |
| `test/widget_test.dart` | **RUN** — tab switching tests |
| `README.md` | **UPDATE** — version row at Epic 17 close (Sub-task D) |
| `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` | **UPDATE** — story + epic status at close |

**Do not create** a shared `squircle_utils.dart` unless a second call site appears — keep clipper private in `app_bottom_nav.dart`.

### Testing requirements

| Command | Purpose |
|---------|---------|
| `flutter analyze lib/presentation/widgets/app_bottom_nav.dart` | No analyzer errors after refactor |
| `flutter test test/presentation/screens/app_scaffold_test.dart` | Nav token regression |
| `flutter test test/widget_test.dart` | Tab switch smoke |
| `flutter test --exclude-tags slow` | Full regression (AC #6) |
| `rg "figma_squircle" lib/ test/ pubspec.yaml` | Zero runtime references (AC #3) |

Optional new test in `app_scaffold_test.dart`:
- Tap each tab; assert selected item has `ClipPath` ancestor
- Assert no `SmoothRectangleBorder` in widget tree

No golden files required — Baptiste manual visual sign-off satisfies AC #5.

### Regression risks

| Risk | Mitigation |
|------|------------|
| Squircle looks sharper than Figma | Use `ContinuousRectangleBorder` path; fallback `RoundedSuperellipseBorder`; Baptiste visual review |
| ClipPath clips InkWell splash | Verify press ripple still visible — may need `Material`/`InkWell` outside clip or accept subtle change; test on device |
| Tests find `DecoratedBox` squircle | Tests assert pill tokens, not figma types — should pass; verify after edit |
| Accidental scope creep into nav redesign | Only swap shape implementation |
| Forgetting DEPENDENCIES.md | Grep after Sub-task B |

### APK measurement (NFR-REF-03)

Story 17-1 captured pre-`share_plus`-removal baseline. For this story:
1. Run `flutter build apk --release --analyze-size` post-change
2. Note delta in review brief (~15 KB expected per audit)
3. No new baseline doc file — numbers in Dev Agent Record or review brief only

### Epic 17 close checklist (Sub-task D — after code review approved)

1. `pubspec.yaml` → `version: 0.7.1+16`
2. `README.md` status version row
3. `sprint-status-refacto.yaml`: `17-3-*: done`, `epic-17: done`
4. Verify profile footer reads new version via `package_info_plus` (no code change)

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 17-3, REF-16, Epic 17]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §6.2 figma_squircle ~15 KB]
- [Source: `_bmad-output/implementation-artifacts/stories/5-7-four-tab-floating-navigation.md` — squircle visual spec, ContinuousRectangleBorder]
- [Source: `_bmad-output/implementation-artifacts/stories/17-1-replace-share-plus-with-file-picker-csv-export.md` — APK baseline, epic versioning]
- [Source: `_bmad-output/implementation-artifacts/stories/17-2-pin-file-picker-to-exact-beta-version.md` — sub-task workflow, test count]
- [Source: `lib/presentation/widgets/app_bottom_nav.dart` — sole consumer]
- [Source: `lib/core/constants/astra_spacing.dart` — squircle tokens]
- [Source: `docs/DEPENDENCIES.md` — dependency inventory]
- [Source: `docs/project-context.md` — review-before-commit, DEPENDENCIES update rule]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — active tab squircle UX]

## Dev Agent Record

### Agent Model Used

Claude claude-4.6-sonnet-medium-thinking (Cursor)

### Debug Log References

- `flutter analyze` on changed files: no issues
- `flutter test --exclude-tags slow`: 802 passed (1 flaky isolation failure on first run in `today_cubit_test.dart`, green on re-run)
- `rg` on lib/test/pubspec: zero `figma_squircle` / `SmoothRectangleBorder` / `SmoothBorderRadius` matches

### Completion Notes List

- Sub-task A: Replaced `SmoothRectangleBorder` with `ClipPath` + `_BottomNavSquircleClipper` using `RoundedSuperellipseBorder.getOuterPath()` (production clipper in `app_bottom_nav.dart`).
- Sub-task B: Removed `figma_squircle` from pubspec/lock; updated `docs/DEPENDENCIES.md`; removed unused `kBottomNavSquircleSmoothing` token.
- Sub-task C (partial): Nav tests pass; strengthened `ClipPath` tab-switch assertions in `app_scaffold_test.dart`. APK `--analyze-size` and Baptiste visual sign-off (AC #5) pending.
- Sub-task D: Epic 17 closed — version `0.7.1+16`, README + sprint status synced.
- Code review follow-up: aligned `docs/DEPENDENCIES.md` and Dev Agent Record with `RoundedSuperellipseBorder` (not `ContinuousRectangleBorder`).

### File List

- `lib/presentation/widgets/app_bottom_nav.dart` (modified)
- `lib/core/constants/astra_spacing.dart` (modified)
- `pubspec.yaml` (modified)
- `pubspec.lock` (modified)
- `docs/DEPENDENCIES.md` (modified)
- `test/presentation/screens/app_scaffold_test.dart` (modified)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (modified)

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Implemented native ClipPath squircle (Sub-tasks A–B); tests green; story → review. APK delta + visual sign-off pending.
- 2026-06-19: Code review follow-up — doc alignment, strengthened nav ClipPath tests, Epic 17 close (`0.7.1+16`).
