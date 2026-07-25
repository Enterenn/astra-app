---
title: 'Bottom nav icon and label sizing'
type: 'feature'
created: '2026-06-05'
status: 'done'
route: 'one-shot'
---

# Bottom nav icon and label sizing

## Intent

**Problem:** Tab bar icons and labels did not match the updated Figma spec (24dp icons, semibold caption-derived labels).

**Approach:** Set Phosphor icons to 20×20 logical px and tab labels to Figtree 10sp bold (w700) in `AppBottomNav`. Nav integration covered by `widget_test.dart` and `app_scaffold_test.dart` (dedicated `app_bottom_nav_test.dart` removed in test-suite Phase A — see `spec-test-suite-cleanup.md`).

## Suggested Review Order

- Icons 20dp and Figtree 10sp bold labels on accent bar
  [`app_bottom_nav.dart:118`](../../lib/presentation/widgets/app_bottom_nav.dart#L118)

- Icon size and label typography defined in widget source; nav smoke in scaffold/widget tests
  [`app_bottom_nav.dart:118`](../../lib/presentation/widgets/app_bottom_nav.dart#L118)
  [`app_scaffold_test.dart`](../../test/presentation/screens/app_scaffold_test.dart)
  [`widget_test.dart`](../../test/widget_test.dart)
