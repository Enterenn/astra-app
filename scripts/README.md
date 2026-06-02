# Scripts

## `pre_test.ps1` (Windows)

Releases `build/native_assets/windows/sqlite3.dll` before `flutter test` when a prior run was killed or left a Dart process holding the FFI DLL.

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
$paths = @(
  "D:\03_Web\02_astra-app\astra-app\build",
  "D:\03_Web\02_astra-app\astra-app\.dart_tool",
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

Project-wide test config: `dart_test.yaml` (`concurrency: 1`, `timeout: 60s`).
