---
title: 'Remove Today stale banner'
type: 'bugfix'
created: '2026-06-05'
status: 'done'
route: 'one-shot'
baseline_commit: '600c893b7d44c543b02477eabcbbc93dc2685ab0'
---

## Intent

**Problem:** Today showed a compact stale `StatusBanner` ("Steps may be delayed — see My Data") that navigated users to My Data, but the background-status card was removed from My Data in story 5.10 — making the banner a dead-end CTA.

**Approach:** Remove the stale banner and its `onNavigateToMyData` navigation plumbing from Today. Add a regression test asserting no stale UI appears when `isStale` is true.

## Suggested Review Order

- Entry point: stale banner block removed from Today layout
  [`today_screen.dart:56`](../../lib/presentation/screens/today_screen.dart#L56)

- Scaffold no longer wires My Data navigation callback
  [`app_scaffold.dart:185`](../../lib/presentation/screens/app_scaffold.dart#L185)

- Regression test locks new contract for stale state
  [`screen_smoke_test.dart`](../../test/presentation/screens/screen_smoke_test.dart) (Today smoke group)

- Scaffold integration test for banner navigation removed
  [`app_scaffold_test.dart:252`](../../test/presentation/screens/app_scaffold_test.dart#L252)
