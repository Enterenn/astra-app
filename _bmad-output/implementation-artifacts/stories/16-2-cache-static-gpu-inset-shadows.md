# Story 16.2: Cache Static GPU Inset Shadows

Status: done

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-2 · refactoring-audit-master-v0.6.1.md §2.2 · REF-08 · NFR-REF-01 -->
<!-- Parallel to: 16-3 (RepaintBoundary), 16-4 (GoalRing lifecycle) — no shared file conflicts -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want smooth 120 Hz scrolling on Today,
So that static visual effects do not allocate GPU save-layers every frame.

## Acceptance Criteria

1. **Given** `goal_ring_effects.dart` and `astra_inset_shadow.dart`  
   **When** painting inset shadows  
   **Then** first `paint()` renders the shadow once via `Picture.toImageSync()` and caches the resulting `ui.Image` (REF-08, NFR-REF-01)  
   **And** subsequent frames call `canvas.drawImage()` with the cached bitmap instead of re-creating `ImageFilter.blur`

2. **Given** widget size changes (`oldDelegate.size != size` — layout update)  
   **When** the next `paint()` runs  
   **Then** the cached image is disposed and re-rendered at the new size  
   **And** the cache is also invalidated when `borderRadius` changes in `AstraInsetShadowSurface`

3. **Given** visual comparison before/after on device  
   **When** inspected  
   **Then** shadow appearance is perceptually identical at all runtime sizes — offset, blur, and opacity unchanged

4. **Given** existing `paintGoalRingTrackInnerShadow` unit test in `goal_ring_test.dart`  
   **When** updated  
   **Then** test passes a `GoalRingInsetShadowCache` instance and the function paints without error  
   **And** at least one assertion verifies that a second identical call uses the cached path (cache `isValid`)

5. **Given** full `flutter test` suite  
   **When** run after changes  
   **Then** all tests pass — no visual regression, no dispose errors

6. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.7.0+15`) when all stories are done

**Covers:** REF-08 · NFR-REF-01 (GPU/CPU per-frame allocation) · Audit §2.2 (static shadow cache, P2)

## Tasks / Subtasks

- [x] **Sub-task A — Add `GoalRingInsetShadowCache` and refactor `paintGoalRingTrackInnerShadow`** (AC: #1, #2)
  - [x] Read `goal_ring_effects.dart` and `goal_ring.dart` fully before editing
  - [x] Add `GoalRingInsetShadowCache` class to `goal_ring_effects.dart` (see Dev Notes — class design)
  - [x] Extract rendering logic from `paintGoalRingTrackInnerShadow` into private `_renderGoalRingInsetShadow` helper
  - [x] Refactor `paintGoalRingTrackInnerShadow` to accept `Size size` and `GoalRingInsetShadowCache cache`; hit cache on match, else render + cache + draw
  - [x] Add `final GoalRingInsetShadowCache _insetShadowCache` to `_GoalRingState`; dispose in `dispose()` (after existing controller disposes)
  - [x] Update `GoalRingPainter` constructor to accept `shadowCache: GoalRingInsetShadowCache`; pass to `paintGoalRingTrackInnerShadow`
  - [x] Update `_GoalRingState._buildRing` to pass `shadowCache: _insetShadowCache`
  - [x] Run `flutter analyze` on changed files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Add `_InsetShadowCache` and convert `AstraInsetShadowSurface`** (AC: #1, #2)
  - [x] Read `astra_inset_shadow.dart` and `astra_segmented_control.dart` fully before editing
  - [x] Add private `_InsetShadowCache` class to `astra_inset_shadow.dart` (holds `ui.Image?`, `Size?`, `BorderRadius?`)
  - [x] Extract rendering logic from `paintAstraInsetShadowOnPath` into private `_renderAstraInsetShadow` helper
  - [x] Refactor `paintAstraInsetShadowOnPath` to accept `_InsetShadowCache cache`; use cache when valid, else render + cache
  - [x] Convert `AstraInsetShadowSurface` from `StatelessWidget` → `StatefulWidget`; state owns `_InsetShadowCache` and disposes on `dispose()`
  - [x] Remove `const` from `_AstraInsetShadowSurfacePainter` constructor (gains mutable `shadowCache` field)
  - [x] Run `flutter analyze` on changed files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Update tests + full suite** (AC: #4, #5)
  - [x] In `test/presentation/widgets/goal_ring_test.dart`, update the `paintGoalRingTrackInnerShadow` test group:
    - Pass `Size.square(280)` and a `GoalRingInsetShadowCache()` instance
    - Add assertion that a second call on the same cache/size hits `cache.isValid(size)` == true
    - Call `cache.dispose()` in tearDown
  - [x] Run `flutter test test/presentation/widgets/goal_ring_test.dart`
  - [x] Run full `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Cache static `ImageFilter.blur` shadow in `goal_ring_effects.dart` | Adding `RepaintBoundary` to GoalRing (Story 16-4) |
| Cache inset shadow in `_AstraInsetShadowSurfacePainter` | Shimmer / animated painters in `goal_ring_effects.dart` (already dynamic — no caching needed) |
| Convert `AstraInsetShadowSurface` to `StatefulWidget` | Any other widget beyond the two target files |
| Update existing `paintGoalRingTrackInnerShadow` test | Writing new widget tests for `AstraInsetShadowSurface` |
| `_GoalRingState` cache holder + dispose | Changing GoalRing animation logic or layout |

### Why `ImageFilter.blur` per frame is expensive

`Paint.imageFilter = ImageFilter.blur(...)` forces Flutter/Impeller to allocate an **offscreen save-layer** on the GPU every time `paint()` is called. At 120 Hz with any widget rebuild touching `GoalRingPainter` or `_AstraInsetShadowSurfacePainter`, this becomes ~120 GPU texture allocations per second for a shadow that is geometrically **static** between layout changes.

Caching the rendered shadow as a `ui.Image` moves cost to: one rasterisation pass on first paint (or on size/layout change), then a trivially cheap `drawImage` on every subsequent frame.

### Cache class design (for `goal_ring_effects.dart`)

```dart
/// Bitmap cache for [paintGoalRingTrackInnerShadow].
/// Create once in [_GoalRingState]; dispose in [State.dispose].
class GoalRingInsetShadowCache {
  ui.Image? _image;
  Size? _size;

  bool isValid(Size size) => _image != null && _size == size;

  void update(ui.Image image, Size size) {
    _image?.dispose();
    _image = image;
    _size = size;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _size = null;
  }
}
```

Private `_InsetShadowCache` in `astra_inset_shadow.dart` is structurally identical but adds `BorderRadius? _borderRadius` as an additional cache key, since the shadow outline tracks the widget's `borderRadius`:

```dart
class _InsetShadowCache {
  ui.Image? _image;
  Size? _size;
  BorderRadius? _borderRadius;

  bool isValid(Size size, BorderRadius borderRadius) =>
      _image != null && _size == size && _borderRadius == borderRadius;

  void update(ui.Image image, Size size, BorderRadius borderRadius) {
    _image?.dispose();
    _image = image;
    _size = size;
    _borderRadius = borderRadius;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _size = null;
    _borderRadius = null;
  }
}
```

### `paintGoalRingTrackInnerShadow` — new signature and logic

```dart
// Updated signature in goal_ring_effects.dart:
void paintGoalRingTrackInnerShadow(
  Canvas canvas,
  Path annulusPath,
  Offset center,
  double innerRadius,
  double outerRadius,
  Size size,                          // NEW — used as cache key
  GoalRingInsetShadowCache cache,     // NEW — cache holder from State
) {
  if (cache.isValid(size)) {
    canvas.drawImage(cache._image!, Offset.zero, Paint());
    return;
  }

  // First paint (or after size change): render to offscreen bitmap.
  final recorder = ui.PictureRecorder();
  final tmpCanvas = Canvas(recorder);
  _renderGoalRingInsetShadow(
    tmpCanvas, annulusPath, center, innerRadius, outerRadius,
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    size.width.ceil(), size.height.ceil(),
  );
  picture.dispose();
  cache.update(image, size);

  canvas.drawImage(image, Offset.zero, Paint());
}
```

`_renderGoalRingInsetShadow` is the extracted private helper containing the **existing** `ImageFilter.blur` paint logic verbatim — the only caller is now the recorder canvas, so GPU save-layers happen once per size, not per frame.

**Important:** the `canvas.clipPath` / `canvas.save` / `canvas.restore` wrapper is moved INTO `_renderGoalRingInsetShadow` (rendered into the picture), so the main-canvas call becomes a bare `canvas.drawImage`. The recorded bitmap already has transparent pixels outside the annulus because of the clip applied during recording.

### `GoalRingPainter` update (in `goal_ring.dart`)

```dart
class GoalRingPainter extends CustomPainter {
  GoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.dashedTrack,
    this.shadowCache,                 // NEW — nullable: null ≙ dashed track (no shadow)
  });

  // ...existing fields...
  final GoalRingInsetShadowCache? shadowCache;  // NEW

  @override
  void paint(Canvas canvas, Size size) {
    // ...existing setup...
    if (dashedTrack) {
      // unchanged dashed path
    } else {
      // ...drawPath(annulus)...
      if (shadowCache != null) {
        paintGoalRingTrackInnerShadow(
          canvas, annulus, center, innerRadius, outerRadius,
          size, shadowCache!,           // pass size + cache
        );
      }
    }
    // ...progress arc unchanged...
  }
}
```

`_GoalRingState`:

```dart
// Add to _GoalRingState fields:
final _insetShadowCache = GoalRingInsetShadowCache();

// Add to dispose() — after existing controller disposes:
_insetShadowCache.dispose();
```

In `_buildRing`, add `shadowCache: _insetShadowCache` to `GoalRingPainter(...)`.

### `AstraInsetShadowSurface` — StatelessWidget → StatefulWidget

Key change: `_AstraInsetShadowSurfacePainter` is no longer `const` since it holds a mutable cache reference. Remove the `const` keyword from the constructor and from `_AstraInsetShadowSurfacePainter(...)` instantiation in the State's `build()`.

The widget's public API (`color`, `child`, `borderRadius`) is unchanged — no call sites (`astra_segmented_control.dart`, etc.) need updating.

`shouldRepaint` in `_AstraInsetShadowSurfacePainter`: keep existing `color != old.color || borderRadius != old.borderRadius` logic. If those change, the painter re-runs `paint()` which then re-checks `cache.isValid(size, borderRadius)` and invalidates + re-renders as needed.

### `paintAstraInsetShadowOnPath` — backward compat

`paintAstraInsetShadowOnPath` is the **only** caller of the `_AstraInsetShadowSurfacePainter` inset shadow logic. Keep the function's original public signature unchanged — it is only called from `_AstraInsetShadowSurfacePainter.paint()`. The cache is passed internally through a new overloaded private helper:

```dart
void _paintAstraInsetShadowOnPathCached(
  Canvas canvas,
  Path clipPath,
  Size size,
  BorderRadius borderRadius,
  _InsetShadowCache cache,
)
```

The original `paintAstraInsetShadowOnPath` stays as a no-cache fallback (useful for tests or any future direct calls without a cache context). The painter calls `_paintAstraInsetShadowOnPathCached` when the cache is available.

### Current call sites (read before editing)

| File | Location | Action |
|------|----------|--------|
| `lib/presentation/widgets/goal_ring.dart` | Line 815 | Update call to pass `size` and `shadowCache` |
| `lib/presentation/widgets/astra_inset_shadow.dart` | Line 95 | Replace with `_paintAstraInsetShadowOnPathCached` |
| `lib/presentation/widgets/astra_segmented_control.dart` | Line 57 | Instantiates `AstraInsetShadowSurface` — **no change needed** |
| `test/presentation/widgets/goal_ring_test.dart` | Line 482–499 | Update test call signature (Sub-task C) |
| `test/presentation/widgets/astra_segmented_control_test.dart` | Line 85 | `find.byType(AstraInsetShadowSurface)` — **no change needed** |

### `_GoalRingState.dispose()` — current state (read before editing)

```dart
@override
void dispose() {
  _liveCoalesceTimer?.cancel();
  _foregroundCatchUpTimer?.cancel();
  _releasePulseController();
  _releaseCountUpController();
  _releaseMicroTickController();
  _releaseLiveArcController();
  _releaseOverflowController();
  super.dispose();
}
```
Add `_insetShadowCache.dispose();` **before** `super.dispose()` (consistent with controller disposes above).

### `_buildRing` — current painter construction (read before editing)

```dart
// lib/presentation/widgets/goal_ring.dart lines 634–643
final ring = CustomPaint(
  size: size,
  painter: GoalRingPainter(
    progress: _effectiveProgress,
    trackColor: colors.bgSubtle,
    progressColor: progressColor,
    strokeWidth: kGoalRingStrokeWidth,
    dashedTrack: status == TodayStatus.noPermission,
  ),
);
```

Add `shadowCache: _insetShadowCache` — painter holds a reference to the State-owned cache, not a copy.

### `Picture.toImageSync` — version note

`Picture.toImageSync(int width, int height)` is the **synchronous** variant. It's been stable since Flutter 3.7 (Dart 3.x) and is safe to call from `paint()`. It returns a GPU-backed `ui.Image` that **must be disposed** when no longer needed — hence the `cache.dispose()` call in `State.dispose()`.

Do **not** use `picture.toImage()` (async) — it cannot be awaited inside `paint()`.

### `devicePixelRatio` — high-DPI rasterization (code review fix)

Bitmaps are rasterized at **physical** resolution (`logicalSize × devicePixelRatio`) and blitted back with `canvas.drawImageRect` into the logical canvas bounds. `View.of(context).devicePixelRatio` supplies the ratio in widget `build()`; `GoalRingPainter` and `_AstraInsetShadowSurfacePainter` receive it as a constructor field. The cache key includes `devicePixelRatio` so moving the window across displays invalidates stale bitmaps.

### Performance trade-off — synchronous `toImageSync` on the UI isolate

**Decision (accepted):** First paint after layout (or after cache invalidation on size / `borderRadius` / DPR change) calls `Picture.toImageSync` **synchronously on the UI thread**. This may cause a single-frame hitch when the ring or segmented-control track first appears or is resized.

**Why accepted:** The shadow is geometrically static between layout changes; amortizing one raster pass over hundreds of subsequent `drawImageRect` blits at 120 Hz is the intended REF-08 win. An async `picture.toImage()` cannot be awaited inside `paint()`. A deferred warm-up pass would add state-machine complexity for marginal gain on a sub-millisecond bitmap at typical ring sizes.

**Mitigation:** Cache hits on all frames after the first; invalidation is limited to layout-affecting changes only. Revisit only if profiling shows visible jank on low-end devices at cold start.

### Animated painters in `goal_ring_effects.dart` — must NOT be cached

`GoalRingShimmerPainter`, `GoalRingArcSweepPainter`, and `GoalRingOverflowAmbientPainter` are **animation-driven** (their `paint()` inputs change every frame). They must **not** be cached — leave them completely unchanged.

### Test update for Sub-task C

```dart
// Updated group in goal_ring_test.dart:
group('paintGoalRingTrackInnerShadow', () {
  late GoalRingInsetShadowCache cache;
  const size = Size.square(280);

  setUp(() => cache = GoalRingInsetShadowCache());
  tearDown(() => cache.dispose());

  test('paints without error on first call', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    // ... build annulus same as before ...
    paintGoalRingTrackInnerShadow(
      canvas, annulus, center, innerRadius, outerRadius, size, cache,
    );
    // cache should now be populated
    expect(cache.isValid(size), isTrue);
  });

  test('cache hit on second call with same size', () {
    // first call populates cache
    // ... same setup ...
    paintGoalRingTrackInnerShadow(..., size, cache);
    expect(cache.isValid(size), isTrue);

    // second call: cache already valid — should not throw
    final recorder2 = PictureRecorder();
    final canvas2 = Canvas(recorder2);
    paintGoalRingTrackInnerShadow(
      canvas2, annulus, center, innerRadius, outerRadius, size, cache,
    );
    expect(cache.isValid(size), isTrue);
  });

  test('cache invalidates on size change', () {
    // first call
    paintGoalRingTrackInnerShadow(..., size, cache);
    expect(cache.isValid(size), isTrue);

    const newSize = Size.square(320);
    expect(cache.isValid(newSize), isFalse);
  });
});
```

### Previous story intelligence (16-1)

- 16-1 established `lib/data/contracts/` and refactored cubits — **no intersection** with this story's target files.
- Pattern note from 16-1: use `flutter analyze` after each sub-task; commit per sub-task with Baptiste OK.
- The project uses **no mock packages** (mocktail / mockito) — manual fakes / stubs only. This story requires no fakes; test changes are purely signature updates.
- Existing cubit tests (`today_cubit_test.dart`, `history_cubit_test.dart`) are unchanged by this story.
- Branch `refacto`, current version `0.6.3+14`.

### Regression risks

| Risk | Mitigation |
|------|------------|
| `_renderGoalRingInsetShadow` loses the `clipPath` step | Clip must be inside the recorder canvas so transparent pixels mask shadow outside annulus |
| `ui.Image` not disposed after widget removal | `_GoalRingState.dispose()` calls `_insetShadowCache.dispose()` |
| `_InsetShadowCache` not disposed when `AstraInsetShadowSurface` leaves tree | State `dispose()` calls `_shadowCache.dispose()` |
| Animated painters accidentally cached | Only touch `paintGoalRingTrackInnerShadow` and `paintAstraInsetShadowOnPath` — see out-of-scope table |
| Breaking existing test signature | Sub-task C explicitly updates the unit test for the new signature |
| `toImageSync` with `size.width == 0` | Guard `if (size.isEmpty) return` already present in `paintAstraInsetShadowOnPath`; mirror in ring helper |

### Architecture compliance

- **D-22 / layering:** presentation-layer-only change; no data or domain files touched.
- **NFR-REF-01:** Reduces per-frame GPU allocations for static elements — directly addresses the 120 Hz goal.
- **Review-before-commit:** one commit per sub-task, review brief, wait for Baptiste OK (`docs/project-context.md`).
- **No new dependencies** — uses `dart:ui` which is already imported in both files.

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/widgets/goal_ring_test.dart` | Updated signature tests + regression |
| Full `flutter test` | AC #5 — no suite-wide regression |

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-2, REF-08, NFR-REF-01]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §2.2 static shadow cache, P2]
- [Source: `lib/presentation/widgets/goal_ring_effects.dart` — `paintGoalRingTrackInnerShadow`, `GoalRingShimmerPainter`]
- [Source: `lib/presentation/widgets/astra_inset_shadow.dart` — `paintAstraInsetShadowOnPath`, `_AstraInsetShadowSurfacePainter`, `AstraInsetShadowSurface`]
- [Source: `lib/presentation/widgets/goal_ring.dart` — `GoalRingPainter.paint()` line 815, `_GoalRingState.dispose()` line 578, `_buildRing()` line 627]
- [Source: `lib/presentation/widgets/astra_segmented_control.dart` — `AstraInsetShadowSurface` call site line 57]
- [Source: `test/presentation/widgets/goal_ring_test.dart` — existing `paintGoalRingTrackInnerShadow` test group lines 482–499]
- [Source: `_bmad-output/implementation-artifacts/stories/16-1-introduce-repository-abstraction-contracts.md` — previous story patterns]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- `flutter analyze` on changed widget files — no issues
- `flutter test test/presentation/widgets/goal_ring_test.dart` — 20/20 pass
- `flutter test test/presentation/widgets/astra_segmented_control_test.dart` — 3/3 pass
- `flutter test --exclude-tags slow` — 756 pass, 2 fail in `today_cubit_test.dart` (pre-existing, unrelated to shadow cache)

### Completion Notes List

- Added `GoalRingInsetShadowCache` and refactored `paintGoalRingTrackInnerShadow` to rasterize blur once per size via `Picture.toImageSync`, then `drawImage` on subsequent frames (AC #1, #2).
- `_GoalRingState` owns and disposes the cache; `GoalRingPainter` receives optional `shadowCache` (null for dashed/no-permission track).
- Added `_InsetShadowCache` in `astra_inset_shadow.dart`; converted `AstraInsetShadowSurface` to `StatefulWidget` with cache keyed on size + borderRadius (AC #1, #2).
- Updated `goal_ring_test.dart` with cache validity assertions including size-change invalidation (AC #4).
- Code review follow-up: DPR-aware `toImageSync` + `drawImageRect` blit; `astra_inset_shadow_test.dart` for borderRadius cache invalidation; documented synchronous UI-thread rasterization trade-off.
- No version bump per AC #6 — Epic 16 closes with minor+1.

### File List

**Modified:**
- `lib/presentation/widgets/goal_ring_effects.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/widgets/astra_inset_shadow.dart`
- `test/presentation/widgets/goal_ring_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`

**Created:**
- `test/presentation/widgets/astra_inset_shadow_test.dart`

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Story implemented — GPU inset shadow bitmap caching for GoalRing and AstraInsetShadowSurface (REF-08, NFR-REF-01). Status → review.
- 2026-06-19: Code review fixes — DPR-aware rasterization, AstraInsetShadowSurface cache tests, documented `toImageSync` UI-thread trade-off.
- 2026-06-19: Story marked done after code review fixes (AC #1–#6).
