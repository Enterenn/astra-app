# Regenerate Phosphor Regular/Fill subset fonts from official Phosphor source TTFs.
# Requires: pip install fonttools  (pyftsubset)
# Run from repo root: .\tool\subset_phosphor_icons.ps1
#
# phosphor-icons/core releases ship SVG assets only. Source icon fonts (TTF) are
# published in the companion phosphor-icons/web repo (linked from core release notes).

$ErrorActionPreference = 'Stop'

# Pinned to match phosphoricons_flutter 1.0.0 / @phosphor-icons/core v2.0.8 baseline.
$PhosphorWebRelease = 'v2.1.2'
$BaseUrl = "https://github.com/phosphor-icons/web/raw/$PhosphorWebRelease/src"

$fontDir = Join-Path $PSScriptRoot 'fonts'
$null = New-Item -ItemType Directory -Force -Path $fontDir

$regularSrc = Join-Path $fontDir 'Phosphor.ttf'
$fillSrc = Join-Path $fontDir 'Phosphor-Fill.ttf'

function Ensure-PhosphorSourceFont {
    param(
        [string]$Url,
        [string]$Dest
    )
    if (Test-Path $Dest) {
        return
    }
    Write-Host "Downloading $([IO.Path]::GetFileName($Dest)) from phosphor-icons/web $PhosphorWebRelease ..."
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

Ensure-PhosphorSourceFont "$BaseUrl/regular/Phosphor.ttf" $regularSrc
Ensure-PhosphorSourceFont "$BaseUrl/fill/Phosphor-Fill.ttf" $fillSrc

$regularUnicodes = 'U+E03E,U+E058,U+E06C,U+E08E,U+E108,U+E13A,U+E150,U+E156,U+E182,U+E19A,U+E242,U+EA88,U+E2F0,U+E316,U+E32A,U+ED60,U+E47C,U+E67E'
$fillUnicodes = 'U+E150,U+E2F0,U+ED60'

$outDir = Join-Path $PSScriptRoot '..\assets\fonts'
$subsetArgs = @(
    '--layout-features=*', '--glyph-names', '--symbol-cmap', '--legacy-cmap',
    '--notdef-glyph', '--notdef-outline', '--recommended-glyphs',
    '--name-IDs=*', '--name-legacy', '--name-languages=*'
)

pyftsubset $regularSrc `
    --unicodes=$regularUnicodes `
    --output-file=(Join-Path $outDir 'Phosphor-Regular-subset.ttf') `
    @subsetArgs

pyftsubset $fillSrc `
    --unicodes=$fillUnicodes `
    --output-file=(Join-Path $outDir 'Phosphor-Fill-subset.ttf') `
    @subsetArgs

Write-Host 'Wrote assets/fonts/Phosphor-Regular-subset.ttf and Phosphor-Fill-subset.ttf'
