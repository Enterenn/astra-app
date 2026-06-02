# pre_test.ps1 — release sqlite3.dll before flutter test (Windows + sqflite FFI)
param([switch]$Clean)

$projectRoot = Split-Path -Parent $PSScriptRoot
$dllPath = Join-Path $projectRoot "build\native_assets\windows\sqlite3.dll"
$nativeAssetsDir = Join-Path $projectRoot "build\native_assets\windows"

function Stop-ProcessesForProject {
    param([string[]]$Names)
    foreach ($name in $Names) {
        $filter = if ($name.EndsWith('.exe')) { "Name = '$name'" } else { "Name = '$name.exe'" }
        $procs = Get-CimInstance Win32_Process -Filter $filter -ErrorAction SilentlyContinue |
            Where-Object {
                $_.CommandLine -and ($_.CommandLine -like "*$projectRoot*")
            }
        foreach ($proc in $procs) {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  killed: $($proc.Name) (pid $($proc.ProcessId))" -ForegroundColor DarkGray
        }
    }
}

Write-Host "=== pre_test: stopping project-scoped Dart test processes ===" -ForegroundColor Cyan
Write-Host "  project: $projectRoot"

Stop-ProcessesForProject -Names @('dart', 'flutter_tester')

Start-Sleep -Milliseconds 800

$handleExe = Get-Command handle.exe -ErrorAction SilentlyContinue
if ($handleExe -and (Test-Path $dllPath)) {
    $handles = & handle.exe -nobanner $dllPath 2>$null
    if ($handles) {
        Write-Host "  WARN: sqlite3.dll still has open handles:" -ForegroundColor Yellow
        $handles | Write-Host
        Write-Host "  Install Sysinternals Handle or close the listed process, then re-run." -ForegroundColor Yellow
        Write-Host "  Or run: Get-Process dart,flutter_tester | Stop-Process -Force (kills all; use with care)." -ForegroundColor Yellow
    }
}

if (Test-Path $nativeAssetsDir) {
    try {
        if (Test-Path $dllPath) {
            Remove-Item $dllPath -Force -ErrorAction Stop
            Write-Host "  removed sqlite3.dll" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ERROR: could not delete sqlite3.dll: $_" -ForegroundColor Red
        Write-Host "  Close Cursor/Android Studio/emulator, run as Admin, or add Defender exclusions." -ForegroundColor Yellow
        exit 1
    }
}

if ($Clean) {
    Write-Host "=== flutter clean ===" -ForegroundColor Cyan
    Push-Location $projectRoot
    flutter clean
    Pop-Location
}

Write-Host "=== pre_test: OK ===" -ForegroundColor Green
