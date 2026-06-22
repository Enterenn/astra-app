# Story 20.1: Onboarding Permission After Value Proposition

Status: done

<!-- Refacto Epic 20 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 20-1 · refactoring-audit-master-v0.6.1.md §5.1 · REF-23 · UX-REF-04 -->
<!-- First story in Epic 20 — version bump minor+1 at Epic 20 close (story 20-5), NOT this story -->
<!-- Prerequisite: Epic 19 complete (0.9.0+19) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **new user**,
I want to understand why Astra needs activity access before the system permission dialog,
So that I trust the app and am more likely to grant permission.

## Acceptance Criteria

- [x] **AC #1** — **Given** `OnboardingIntroPage` (index 0) on first launch
  **When** onboarding renders
  **Then** the screen **prominently** emphasises "100% offline" and "no account required" (UX-REF-04, REF-23)
  **And** trust value appears **above or directly under the headline** — not buried only inside card body copy
  **And** activity permission is **not** requested on first paint or in `initState` / cubit constructor

- [x] **AC #2** — **Given** user reads intro trust copy and taps **Start** (`onboardingStartBtn`)
  **When** they have seen product value
  **Then** `OnboardingCubit.requestActivityPermission()` runs (existing bridge in `onboarding_flow.dart`)
  **And** system activity dialog appears after value presentation — **not** before user action
  **And** flow advances to weight step after dialog dismisses (grant **or** deny)
  **And** Continue shows loading/disabled while `activityPermissionStatus == requesting`

- [x] **AC #3** — **Given** weight/height steps (indices 1–2)
  **When** unchanged by this story
  **Then** **Skip** remains available on both steps — no regression to mandatory biometrics
  **And** denied permission on intro still allows full onboarding completion via Skip path

- [x] **AC #4** — **Given** localized app (`en` / `fr`)
  **When** intro renders
  **Then** new trust emphasis strings come from ARB keys (no hardcoded French/English in widgets)

- [x] **AC #5** — **Given** `flutter test --exclude-tags slow`
  **When** run after implementation
  **Then** all tests pass
  **And** new/updated widget tests assert: trust emphasis visible on mount; **zero** permission requests before Start tap; permission invoked once on Start tap

- [x] **AC #6** — **Given** work completes on branch `refacto`
  **When** story is marked done
  **Then** **no version bump** — Epic 20 closes with minor+1 (`0.10.0+20`) when stories 20-1–20-5 are done

**Covers:** REF-23 · UX-REF-04 · Audit §5.1 (onboarding permission timing)

**Depends on:** Epic 19 complete (l10n infrastructure + locale preference).

**Out of scope:** Moving permission to after weight/height; notification permission in onboarding; changing headline/card paragraph locked copy from Epic 13 unless required for trust emphasis; post-onboarding permission CTA on Today (already exists); Epic 20 version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Trust value proposition UI on intro** (AC: #1, #4)
  - [x] Read `onboarding_intro_page.dart`, `trend_chip.dart` (`CaptionPill`), `onboarding_shell.dart`, `app_en.arb` / `app_fr.arb` fully before editing
  - [x] Add ARB keys (minimum):
    - `onboardingTrustOfflineBadge` — EN: "100% offline" · FR: "100 % hors ligne"
    - `onboardingTrustNoAccountBadge` — EN: "No account required" · FR: "Aucun compte requis"
  - [x] Run `flutter gen-l10n`; commit generated Dart with ARB
  - [x] Render two trust pills/chips **between headline and card** (wrap row, centered) — reuse `CaptionPill` from `trend_chip.dart` or extract a thin shared `TrustValuePill` if onboarding needs icons (Phosphor: `wifiSlash` + `userCircleMinus` or similar — keep glyph count minimal for Epic 20-5 subsetting)
  - [x] Preserve existing headline + card paragraphs unchanged unless Baptiste approves copy tweak in review brief
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Permission timing audit (preserve bridge, no regressions)** (AC: #2, #3)
  - [x] Read `onboarding_flow.dart` and `onboarding_cubit.dart` fully — confirm `_onIntroContinue` remains the **only** intro permission entry point
  - [x] Do **not** add `requestActivityPermission()` to cubit constructor, `OnboardingFlow.initState`, or `OnboardingIntroPage.build`
  - [x] Do **not** move permission to weight/height completion — audit intent is value-first **on intro**, permission on **Start** tap (user intent signal)
  - [x] Smoke: denied permission → Skip weight → Skip height → onboarding completes (existing path)
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (no-op commit OK if zero code changes — document verification in brief)

- [x] **Sub-task C — Tests** (AC: #5)
  - [x] Update `test/presentation/onboarding/onboarding_flow_test.dart`:
    - Assert trust badge strings visible on first pump (EN test harness)
    - Assert `permissionRequestCount == 0` after first pump (before Start tap)
    - Keep existing "intro Continue requests activity permission" test
  - [x] Add widget test with French locale (`TestMaterialApp` + `locale: Locale('fr')`) — assert French trust badge strings
  - [x] Run `flutter analyze` + `flutter test test/presentation/onboarding/`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Full regression** (AC: #5, #6)
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Manual: fresh install → intro shows trust pills → no OS dialog until Start → dialog → weight step
  - [x] Manual: deny permission → Skip ×2 → lands on Today shell
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Prominent trust value UI on intro (offline + no account) | Permission after weight/height |
| New ARB keys + gen-l10n | Notification permission in onboarding |
| Tests for mount-time no-permission + trust visibility | Changing 3-step flow order |
| Verify existing permission bridge unchanged | Today permission CTA rework |
| French + English trust strings | Version bump (Epic 20 close only) |

### Critical baseline — permission timing is already correct

Story 13-1 wired permission on intro **Start** tap. Current code matches REF-23 intent — **do not re-architect timing**.

```50:54:lib/presentation/onboarding/onboarding_flow.dart
  Future<void> _onIntroContinue(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    await cubit.requestActivityPermission();
    cubit.nextStep();
  }
```

**What is wrong today (audit §5.1):** trust value is implicit in card paragraphs — users may tap Start before internalising "100% offline, no account". **Fix = UX emphasis**, not moving the OS dialog to a later step.

**What must NOT change:**

- `_onIntroContinue` sequence: `requestActivityPermission()` → `nextStep()` always (grant or deny)
- `OnboardingCubit` has no auto-permission on construction
- Weight/height Skip buttons and `skipWeight` / `skipHeight` flows
- `OnboardingState.totalSteps == 3`
- Primary intro label remains `l10n.onboardingStartBtn` ("Start" / localized equivalent)

### Critical baseline — intro page today

```16:51:lib/presentation/onboarding/onboarding_intro_page.dart
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingIntroHeadline,
            ...
          ),
          const SizedBox(height: AstraSpacing.kSpaceXl),
          DecoratedBox(
            ...
                  Text(l10n.onboardingIntroParagraphOne, ...),
                  Text(l10n.onboardingIntroParagraphTwo, ...),
```

**Gap vs UX-REF-04:** no dedicated trust emphasis above the fold. Card copy mentions "No accounts" but audit requires explicit **"100% offline, no account required"** prominence.

### Recommended UI layout (audit §5.1)

```
[Progress bar — 3 segments, step 1 active]

     Your Health. Your Phone. Period.        ← headline (unchanged)

   [100% offline]  [No account required]     ← NEW trust pills (CaptionPill-style)

┌─────────────────────────────────────────┐
│  Card paragraph 1 (unchanged)           │
│  Card paragraph 2 (unchanged)           │
└─────────────────────────────────────────┘

                              [Start →]     ← triggers permission then weight
```

Spacing tokens: `kSpaceMd` between headline and pills; `kSpaceLg` between pills and card (match existing `kSpaceXl` rhythm if tighter layout needed).

### Reuse existing components

**Prefer `CaptionPill`** from `lib/presentation/widgets/trend_chip.dart`:

```12:60:lib/presentation/widgets/trend_chip.dart
class CaptionPill extends StatelessWidget {
  const CaptionPill({
    required this.label,
    this.leading,
    ...
```

Use `colors.bgSubtle` pill on `bgBase` — already used on Trends. Optional small Phosphor leading icon per pill; keep icons from existing onboarding set if possible.

**Do not** import Trends-specific widgets into onboarding beyond `CaptionPill` — if coupling feels wrong, duplicate minimal pill styling inline in `onboarding_intro_page.dart` (prefer reuse).

### ARB keys (minimum)

| Key | English | French |
|-----|---------|--------|
| `onboardingTrustOfflineBadge` | 100% offline | 100 % hors ligne |
| `onboardingTrustNoAccountBadge` | No account required | Aucun compte requis |

Add `@`-description metadata in ARB. Run `flutter gen-l10n` after edits.

**Do not** change locked strings from Story 13-1 unless Baptiste requests in review:
- `onboardingIntroHeadline`
- `onboardingIntroParagraphOne` / `Two`

### Optional enhancement (only if quick — not required for AC)

Story 13-1 spec included expandable **Learn more** disclaimer below card — current intro page lost this during Epic 19 l10n migration. Restoring `onboardingIntroLearnMore` + body keys would strengthen trust but is **optional** — trust pills satisfy UX-REF-04 minimum. Ask in review brief before adding.

### Previous story intelligence (Epic 19 — l10n)

| Learning | Application |
|----------|-------------|
| All onboarding strings in ARB | New trust keys → `app_en.arb` / `app_fr.arb` only |
| Import `package:astra_app/l10n/app_localizations.dart` | Same in intro page |
| `TestMaterialApp` + `test/helpers/l10n_test_helper.dart` | French widget test with explicit `locale:` |
| 811+ fast tests green at Epic 19 close | Regression bar unchanged |
| Sub-task stop → review → commit | Follow project-context gate |
| Sprint tracker is `sprint-status-refacto.yaml` | Update when story moves to done |
| No mid-epic version bump in Epic 19 | Epic 20 bumps at **20-5 close** only |

### Previous story intelligence (Epic 13 — onboarding redesign)

| Learning | Application |
|----------|-------------|
| Permission bridge on intro Start (not separate permission page) | **Preserve** — this story adds emphasis, not new step |
| Denied permission never blocks onboarding | Regression test already exists — keep passing |
| Loading state on Start during permission | Already wired via `primaryLoading: isRequestingActivity` |
| Skip on weight/height optional | Do not touch skip handlers |

### Git intelligence

Recent commits (2026-06-20):

- `4509c79` — l10n language picker + week pill labels
- `10072b2` — Epic 19 closed at `0.9.0+19`
- Onboarding flow tests already cover permission-on-continue, denied advance, loading state

Branch: `refacto`. No in-flight onboarding work expected.

### Architecture compliance

| Rule | Application |
|------|-------------|
| FR-22 trust before permission | Value pills visible **before** Start tap; OS dialog **after** Start |
| REF-23 | Product value presentation gate — satisfied by intro UI + user tap |
| UX-REF-04 | Explicit offline + no-account emphasis |
| Presentation l10n via ARB | No hardcoded trust strings |
| Review-before-commit | One commit per sub-task after Baptiste OK |
| Branch `refacto` only | Do not merge to main from this story |
| Phosphor icons selective use | If adding icons, note glyph for Epic 20-5 inventory |

### Cross-story roadmap (Epic 20)

| Story | Responsibility |
|-------|----------------|
| **20-1 (this)** | Onboarding trust emphasis + permission timing verification |
| 20-2 | Local Trends insight cards |
| 20-3 | Tab haptic feedback |
| 20-4 | Replace fl_chart with CustomPainter |
| 20-5 | Phosphor font subsetting + **Epic 20 version bump** `0.10.0+20` |

### Testing requirements

```bash
flutter gen-l10n
flutter analyze
flutter test test/presentation/onboarding/onboarding_flow_test.dart
flutter test test/presentation/cubits/onboarding_cubit_test.dart
flutter test --exclude-tags slow
```

**New/updated assertions (minimum):**

| Test | Asserts |
|------|---------|
| `shows intro headline on first step` (extend) | Trust badge strings visible on mount |
| New: `intro does not request permission before Start tap` | `permissionRequestCount == 0` after first pump |
| `intro Continue requests activity permission` (keep) | Count == 1 after Start tap |
| New: French locale intro | FR trust badge strings visible |
| Existing denied/skip/loading tests | Still pass unchanged |

**Manual checklist:**

1. Fresh install → intro shows two trust pills + card → **no** OS dialog
2. Tap Start → OS activity dialog → weight step (grant or deny)
3. Deny → Skip weight → Skip height → Today shell loads
4. Switch device language FR → trust pills in French

### Project structure notes

- Story file: `_bmad-output/implementation-artifacts/stories/20-1-onboarding-permission-after-value-proposition.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`
- **Primary modified:** `lib/presentation/onboarding/onboarding_intro_page.dart`, `lib/l10n/app_*.arb`, `lib/l10n/app_localizations*.dart`, `test/presentation/onboarding/onboarding_flow_test.dart`
- **Likely unchanged:** `onboarding_flow.dart`, `onboarding_cubit.dart` (verify only)
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows

### Anti-patterns — do NOT

- Request permission in `OnboardingCubit()` constructor or intro `build()`
- Move permission to weight Continue or height Let's Go
- Remove Skip on weight/height
- Hardcode "100% offline" / "No account required" in Dart widgets
- Add `google_fonts` or new dependencies for trust UI
- Bump `pubspec.yaml` version — Epic 20 closes on story 20-5
- Block onboarding when permission denied
- Change `onboardingStartBtn` to "Continue" (different key — weight step uses `onboardingContinueBtn`)

### Latest technical notes

- `permission_handler ^12.0.1` — `OnboardingCubit.requestActivityPermission()` uses injected `permissionRequester` in tests; production uses `resolveActivityPermission()` resolver
- `CaptionPill` is a generic presentation widget — safe to reuse from Trends
- Flutter widget tests: use `tester.pumpWidget` then assert **before** any tap for mount-time no-permission invariant

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 20-1]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#5.1]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-17.md — intro permission bridge]
- [Source: _bmad-output/implementation-artifacts/stories/13-1-onboarding-shell-and-intro-screen.md]
- [Source: _bmad-output/implementation-artifacts/stories/19-3-persist-and-apply-user-locale-preference.md — l10n patterns]
- [Source: lib/presentation/onboarding/onboarding_flow.dart — permission bridge]
- [Source: lib/presentation/onboarding/onboarding_intro_page.dart]
- [Source: lib/presentation/widgets/trend_chip.dart — CaptionPill]
- [Source: test/presentation/onboarding/onboarding_flow_test.dart]
- [Source: docs/project-context.md — review-before-commit]
- [Source: .cursor/rules/app-versioning.mdc — Epic 20 minor bump at close]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Sub-task B audit: `_onIntroContinue` in `onboarding_flow.dart` is the sole permission entry point; no auto-request in cubit constructor or intro page build. No code changes required.
- CaptionPill reused without icons to minimize Phosphor glyph count ahead of story 20-5.

### Completion Notes List

- Added trust value pills (`100% offline`, `No account required`) between headline and card on intro screen using existing `CaptionPill` widget.
- New ARB keys `onboardingTrustOfflineBadge` and `onboardingTrustNoAccountBadge` in EN/FR with `flutter gen-l10n`.
- Extended onboarding flow tests: trust badges visible on mount, zero permission requests before Start tap, French locale trust strings.
- Permission timing bridge unchanged — value-first UX emphasis only (audit §5.1 / UX-REF-04).
- `flutter analyze` clean; `flutter test test/presentation/onboarding/` 17/17 pass; `flutter test --exclude-tags slow` 815 pass (~2 skipped).
- Dette technique acceptée : L'extraction de CaptionPill hors de trend_chip.dart est différée à la Story 20-5 pour centraliser les refactorings de widgets.

### File List

- `lib/presentation/onboarding/onboarding_intro_page.dart` — trust pills UI
- `lib/l10n/app_en.arb` — new trust badge keys
- `lib/l10n/app_fr.arb` — new trust badge keys
- `lib/l10n/app_localizations.dart` — generated
- `lib/l10n/app_localizations_en.dart` — generated
- `lib/l10n/app_localizations_fr.dart` — generated
- `test/presentation/onboarding/onboarding_flow_test.dart` — trust visibility + no-permission-before-Start + FR locale tests
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` — status review → done

## Change Log

- 2026-06-20: Story 20-1 implemented — onboarding intro trust emphasis (offline + no account pills), permission timing verified unchanged, tests added.
- 2026-06-20: Story 20-1 closed after positive code review — AC validated, CaptionPill extraction deferred to story 20-5.
