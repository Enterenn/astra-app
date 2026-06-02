# pre_test.ps1 — release sqlite3.dll before flutter test (Windows + sqflite FFI)
param([switch]$Clean)

$projectRoot = Split-Path -Parent $PSScriptRoot
$dllPath = Join-Path $projectRoot "build\native_assets\windows\sqlite3.dll"
$nativeAssetsDir = Join-Path $projectRoot "build\native_assets\windows"

Write-Host "=== pre_test: stopping Dart/Flutter test processes ===" -ForegroundColor Cyan

@('dart', 'flutter', 'flutter_tester', 'flutter_tools') | ForEach-Object {
    $procs = Get-Process -Name $_ -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force
        Write-Host "  killed: $_ ($($procs.Count))"
    }
}

Start-Sleep -Milliseconds 800

$handleExe = Get-Command handle.exe -ErrorAction SilentlyContinue
if ($handleExe -and (Test-Path $dllPath)) {
    $handles = & handle.exe -nobanner $dllPath 2>$null
    if ($handles) {
        Write-Host "  WARN: sqlite3.dll still has open handles:" -ForegroundColor Yellow
        $handles | Write-Host
        Write-Host "  Install Sysinternals Handle or close the listed process, then re-run." -ForegroundColor Yellow
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
