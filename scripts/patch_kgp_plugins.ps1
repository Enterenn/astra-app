# Copies version-checked Built-in Kotlin build.gradle patches into pub-cache.
# Run after `flutter pub get` when building with AGP 9 built-in Kotlin enabled.
# See docs/DEPENDENCIES.md § Android Built-in Kotlin / KGP.

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptDir -Parent
$PubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
$LockFile = Join-Path $ProjectRoot "pubspec.lock"
$ManifestFile = Join-Path $ScriptDir "kgp-patches\manifest.json"

if (-not (Test-Path $LockFile)) {
    throw "pubspec.lock not found at $LockFile"
}

function Get-LockedVersion {
    param([string]$PackageName)

    $content = Get-Content $LockFile -Raw
    if ($content -match "(?ms)  ${PackageName}:\r?\n(?:.*?\r?\n)*?    version: ""([^""]+)""") {
        return $Matches[1]
    }

    throw "Could not read locked version for '$PackageName' from pubspec.lock"
}

$manifest = Get-Content $ManifestFile -Raw | ConvertFrom-Json

foreach ($entry in $manifest) {
    $lockedVersion = Get-LockedVersion $entry.package
    $expectedPrefix = ($entry.patchFile -split '-build\.gradle$')[0]
    $expectedVersion = ($expectedPrefix -split '-', 2)[1]

    if ($lockedVersion -ne $expectedVersion) {
        throw "Locked version for '$($entry.package)' is '$lockedVersion' but patch expects '$expectedVersion'. Update scripts/kgp-patches/ before patching."
    }

    $patchSource = Join-Path $ScriptDir "kgp-patches\$($entry.patchFile)"
    $pluginDir = Join-Path $PubCache "$($entry.package)-$lockedVersion"
    $patchTarget = Join-Path $pluginDir $entry.target

    if (-not (Test-Path $patchSource)) {
        throw "Patch file missing: $patchSource"
    }
    if (-not (Test-Path $pluginDir)) {
        throw "Plugin not found in pub cache: $pluginDir (run flutter pub get)"
    }

    Copy-Item -Path $patchSource -Destination $patchTarget -Force
    Write-Host "Patched: $patchTarget"
}

Write-Host "KGP plugin patches applied."
