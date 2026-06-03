---
title: 'fix-windows-sqlite3-test-dll-locks'
type: 'bugfix'
created: '2026-06-03'
status: 'done'
route: 'one-shot'
---

# fix-windows-sqlite3-test-dll-locks

## Intent

**Problem:** On Windows, `flutter test` frequently failed with `PathAccessException` on `build/native_assets/windows/sqlite3.dll` because the `sqlite3` dev hook copied a native DLL that competing Dart/test processes could lock.

**Approach:** Configure `sqlite3` build hooks to load the built-in `winsqlite3.dll` on Windows (dev/test only — `sqlite3` is a dev dependency) and add `test/flutter_test_config.dart` to warm up sqflite FFI in the main isolate before tests run.

## Suggested Review Order

1. [pubspec.yaml](pubspec.yaml) — `hooks.user_defines.sqlite3` uses `source: system` + `name_windows: winsqlite3`; confirm this matches the intended Windows-only dev/test scope.
2. [test/flutter_test_config.dart](test/flutter_test_config.dart) — global Windows warm-up via `initSqfliteFfiForTests()`.
3. [scripts/README.md](scripts/README.md) — `pre_test.ps1` demoted to fallback; primary fix documented.
4. [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) — dev/test SQLite note for Windows.

## Verification

**Commands:**
- `flutter test` — expected: all tests pass; `build/native_assets/windows/sqlite3.dll` is not created.
