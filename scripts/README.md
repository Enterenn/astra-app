# Scripts

## `pre_test.ps1` (Windows)

**Primary fix (since 2026-06):** `pubspec.yaml` `hooks.user_defines.sqlite3` uses `winsqlite3.dll` on Windows so tests no longer copy or lock `build/native_assets/windows/sqlite3.dll`. You should not need this script for normal `flutter test` runs.

Fallback when a hung test or old native-asset copy still holds `sqlite3.dll`:

Releases `build/native_assets/windows/sqlite3.dll` before `flutter test` when a prior run was killed or left a Dart process holding the FFI DLL. Only stops `dart` / `flutter_tester` processes whose command line references this repo (does not kill global `flutter` CLI).

```powershell
# Normal (fast)
.\scripts\pre_test.ps1
flutter test

# After a hung test or PathAccessException on sqlite3.dll
.\scripts\pre_test.ps1 -Clean
flutter test
```

### One-time: Windows Defender exclusions (Admin PowerShell)

Reduces "Access denied" when Flutter replaces `sqlite3.dll`:

```powershell
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$paths = @(
  (Join-Path $projectRoot 'build'),
  (Join-Path $projectRoot '.dart_tool'),
  "$env:LOCALAPPDATA\Pub\Cache",
  "$env:LOCALAPPDATA\flutter"
)
$paths | ForEach-Object { Add-MpPreference -ExclusionPath $_ }
```

### If the DLL is still locked

```text
handle.exe -nobanner build\native_assets\windows\sqlite3.dll
```

(Sysinternals Handle: https://learn.microsoft.com/sysinternals/downloads/handle)

Project-wide test config: `dart_test.yaml` (`concurrency: 1`, `timeout: 60s`) and `test/flutter_test_config.dart` (Windows sqflite FFI warm-up).

## `patch_kgp_plugins.ps1` / `patch_kgp_plugins.sh`

Copies version-checked Built-in Kotlin `build.gradle` patches from `scripts/kgp-patches/` into pub-cache after `flutter pub get`. Required for Android builds until `pedometer`, `share_plus`, and `workmanager_android` publish upstream migrations.

```powershell
flutter pub get
.\scripts\patch_kgp_plugins.ps1
```

See `docs/DEPENDENCIES.md` § Android Built-in Kotlin / KGP.
