# EmbeddedScreenPreview regression suite (standalone)
#
#   .\test.ps1              build then test
#   .\test.ps1 -SkipBuild   test only
#
# Covers: adapter loader (reload + failure cleanup), viewport math and
# bandwidth thresholds, host plumbing with fixtures, terminal capture,
# and offscreen export including bandwidth limiting.

param([switch] $SkipBuild)

$ErrorActionPreference = "Stop"
if (-not $SkipBuild) { & "$PSScriptRoot\build.ps1" }

$previousPath = $env:PATH
$previousTmp  = $env:TMP
$previousTemp = $env:TEMP

Push-Location $PSScriptRoot
try {
    $env:PATH = "C:\msys64\mingw64\bin;$env:PATH"
    $env:TMP  = "C:\pc_build"
    $env:TEMP = $env:TMP
    New-Item -ItemType Directory -Force -Path $env:TMP | Out-Null

    function Invoke-Checked([string] $Program, [string[]] $Arguments) {
        & $Program @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$Program failed: exit $LASTEXITCODE" }
    }

    $cc = @('-std=c11','-O2','-Wall','-Wextra','-Wno-cast-function-type')
    $libs = @('-lgdi32','-luser32','-lshell32','-lole32','-lcomctl32')

    Write-Host "[test] loader ..." -ForegroundColor Cyan
    Invoke-Checked gcc ($cc + @('-o','tests_loader.exe','tests_loader.c'))
    Invoke-Checked .\tests_loader.exe @($PWD.Path)

    Write-Host "[test] bandwidth model ..." -ForegroundColor Cyan
    Invoke-Checked gcc ($cc + @('-o','tests_sim.exe','tests_sim.c','fv_sim.c'))
    Invoke-Checked .\tests_sim.exe @()

    Write-Host "[test] host plumbing ..." -ForegroundColor Cyan
    $fixture = Join-Path $PSScriptRoot '_fbview/tests'
    $small = Join-Path $fixture 'small'
    $bad   = Join-Path $fixture 'bad'
    New-Item -ItemType Directory -Force $small, $bad | Out-Null
    Copy-Item -LiteralPath "$PSScriptRoot/demo_adapter.dll" -Destination "$small/demo_adapter.dll" -Force
    @('width=320','height=240','fps=15','bandwidth_mb_s=12','scan_hz=50') |
        Set-Content -LiteralPath "$small/preview.ini" -Encoding ascii
    Invoke-Checked gcc ($cc + @('-o','tests_host.exe','tests_host.c','fbview_loader.c','fv_sim.c','fv_terminal.c') + $libs)
    Invoke-Checked .\tests_host.exe @($PWD.Path, $small, $bad)

    Write-Host "[test] terminal ..." -ForegroundColor Cyan
    Invoke-Checked gcc ($cc + @('-o','tests_terminal.exe','tests_terminal.c'))
    Invoke-Checked .\tests_terminal.exe @()

    Write-Host "[test] offscreen export ..." -ForegroundColor Cyan
    Invoke-Checked .\fbview.exe @('-dir', $PWD.Path, '-export', 'regression.bmp')
    $bmp = [IO.File]::ReadAllBytes("$PWD\regression.bmp")
    if ($bmp[0] -ne 66 -or $bmp[1] -ne 77) { throw 'not a BMP' }
    if ([BitConverter]::ToInt32($bmp, 18) -ne 800 -or
        [BitConverter]::ToInt32($bmp, 22) -ne -480 -or
        [BitConverter]::ToInt16($bmp, 28) -ne 32) {
        throw 'unexpected BMP geometry or bit depth'
    }

    Write-Host "[test] bandwidth limiting changes the frame ..." -ForegroundColor Cyan
    Invoke-Checked .\fbview.exe @('-dir', $PWD.Path, '-bandwidth', '60', '-export', 'limited.bmp')
    Invoke-Checked .\fbview.exe @('-dir', $PWD.Path, '-bandwidth', '0',  '-export', 'recovered.bmp')
    $baseline = (Get-FileHash -LiteralPath 'regression.bmp').Hash
    if ((Get-FileHash -LiteralPath 'limited.bmp').Hash -eq $baseline) {
        throw 'bandwidth limit did not change the displayed frame'
    }
    if ((Get-FileHash -LiteralPath 'recovered.bmp').Hash -ne $baseline) {
        throw 'unlimited bandwidth did not restore the frame'
    }

    Write-Host "[test] text reaches the exported frame ..." -ForegroundColor Cyan
    $white = 0
    for ($offset = 54; $offset -lt [Math]::Min($bmp.Length, 54 + 800 * 120 * 4); $offset += 4) {
        if ($bmp[$offset] -eq 255 -and $bmp[$offset+1] -eq 255 -and $bmp[$offset+2] -eq 255) { $white++ }
    }
    if ($white -lt 10) { throw 'text is missing from the exported frame' }

    Write-Host "All regression checks passed." -ForegroundColor Green
}
finally {
    Pop-Location
    $env:PATH = $previousPath
    $env:TMP  = $previousTmp
    $env:TEMP = $previousTemp
}