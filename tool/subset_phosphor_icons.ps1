# Regenerate Phosphor Regular/Fill subset fonts from phosphoricons_flutter pub-cache.
# Requires: pip install fonttools  (pyftsubset)
# Run from repo root: .\tool\subset_phosphor_icons.ps1

$ErrorActionPreference = 'Stop'

$pkg = Join-Path $env:LOCALAPPDATA 'Pub\Cache\hosted\pub.dev\phosphoricons_flutter-1.0.0\lib\fonts'
if (-not (Test-Path $pkg)) {
    Write-Error "Source fonts not found at $pkg — run 'flutter pub get' while phosphoricons_flutter is still listed, or install the package manually."
}

$regularUnicodes = 'U+E03E,U+E058,U+E06C,U+E08E,U+E108,U+E13A,U+E150,U+E156,U+E182,U+E19A,U+E242,U+EA88,U+E2F0,U+E316,U+E32A,U+ED60,U+E47C,U+E67E'
$fillUnicodes = 'U+E150,U+E2F0,U+ED60'

$outDir = Join-Path $PSScriptRoot '..\assets\fonts'
$subsetArgs = @(
    '--layout-features=*', '--glyph-names', '--symbol-cmap', '--legacy-cmap',
    '--notdef-glyph', '--notdef-outline', '--recommended-glyphs',
    '--name-IDs=*', '--name-legacy', '--name-languages=*'
)

pyftsubset (Join-Path $pkg 'Phosphor.ttf') `
    --unicodes=$regularUnicodes `
    --output-file=(Join-Path $outDir 'Phosphor-Regular-subset.ttf') `
    @subsetArgs

pyftsubset (Join-Path $pkg 'Phosphor-Fill.ttf') `
    --unicodes=$fillUnicodes `
    --output-file=(Join-Path $outDir 'Phosphor-Fill-subset.ttf') `
    @subsetArgs

Write-Host 'Wrote assets/fonts/Phosphor-Regular-subset.ttf and Phosphor-Fill-subset.ttf'
