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

**Approach:** Set Phosphor icons to 20×20 logical px and tab labels to Figtree 10sp bold (w700) in `AppBottomNav`, with widget tests locking the sizes.

## Suggested Review Order

- Icons 20dp and Figtree 10sp bold labels on accent bar
  [`app_bottom_nav.dart:118`](../../lib/presentation/widgets/app_bottom_nav.dart#L118)

- Widget tests lock icon size and label typography
  [`app_bottom_nav_test.dart:59`](../../test/presentation/widgets/app_bottom_nav_test.dart#L59)
