---
title: 'Trends 12m period range pill'
type: 'feature'
created: '2026-06-16'
status: 'done'
route: 'one-shot'
---

## Intent

**Problem:** On the Trends screen 12 months tab, the rolling year range caption (e.g. `Jul 2025 – Jun 2026`) was plain gray text, visually inconsistent with the pill-shaped trend chip (`Down x% from last week`) shown on the 7d and 30d tabs.

**Approach:** Extract a shared `CaptionPill` widget from `TrendChip` and use it for the 12-month period range with the same pill chrome (bgSubtle background, full radius, caption typography, left alignment, spacing).

## Suggested Review Order

**Shared pill widget**

- Reusable pill chrome extracted; TrendChip delegates with colored leading icon
  [`trend_chip.dart:9`](../../lib/presentation/widgets/trend_chip.dart#L9)

- Inner text/icon excluded from semantics to avoid duplicate TalkBack
  [`trend_chip.dart:40`](../../lib/presentation/widgets/trend_chip.dart#L40)

**12 months screen binding**

- Period range swapped from plain Text to left-aligned CaptionPill
  [`history_screen.dart:58`](../../lib/presentation/screens/history_screen.dart#L58)

**Tests**

- CaptionPill unit smoke and 12m screen assertion
  [`trend_chip_test.dart:103`](../../test/presentation/widgets/trend_chip_test.dart#L103)

  [`screen_smoke_test.dart:650`](../../test/presentation/screens/screen_smoke_test.dart#L650)
