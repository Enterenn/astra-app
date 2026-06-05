---
title: 'Fix release APK WorkManager R8 crash'
type: 'bugfix'
created: '2026-06-05'
status: 'done'
route: 'one-shot'
---

## Intent

**Problem:** Release APK crashes instantly on launch (`astra-app stopped working`) because R8 full mode (AGP 9) strips WorkManager's reflection-instantiated classes (`WorkDatabase_Impl`).

**Approach:** Add ProGuard keep rules for `androidx.work` constructors and wire them into the release build type.

## Suggested Review Order

1. `android/app/proguard-rules.pro` — WorkManager/Room keep rules
2. `android/app/build.gradle.kts` — `proguardFiles` on release build type
