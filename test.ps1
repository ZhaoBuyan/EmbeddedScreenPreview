# Build and run the regression suite (tool-only, no external project needed).
$ErrorActionPreference = "Stop"

$previousPath = $env:PATH
$previousTmp  = $env:TMP
$previousTemp = $env:TEMP

Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot\build.ps1"

    $env:PATH = "C:\msys64\mingw64\bin;$env:PATH"
    $env:TMP  = "C:\pc_build"
    $env:TEMP = $env:TMP
    New-Item -ItemType Directory -Force -Path $env:TMP | Out-Null

    function Invoke-Checked([string] $Program, [string[]] $Arguments) {
        & $Program @Arguments
        if ($LASTEXITCODE -ne 0) { throw "$Program failed: exit $LASTEXITCODE" }
    }

    $gccFlags = @('-std=c11','-O2','-Wall','-Wextra','-Wno-cast-function-type')

    Write-Host "[test] loader ..."   -ForegroundColor Cyan
    Invoke-Checked gcc ($gccFlags + @('-o','tests_loader.exe','tests_loader.c'))
    Invoke-Checked .\tests_loader.exe @()

    Write-Host "[test] sim ..."      -ForegroundColor Cyan
    Invoke-Checked gcc ($gccFlags + @('-o','tests_sim.exe','tests_sim.c','fv_sim.c','-lm'))
    Invoke-Checked .\tests_sim.exe @()

    Write-Host "[test] preview ..."  -ForegroundColor Cyan
    Invoke-Checked gcc ($gccFlags + @('-o','tests_preview.exe','tests_preview.c'))
    Invoke-Checked .\tests_preview.exe @()

    Write-Host "[test] terminal ..." -ForegroundColor Cyan
    Invoke-Checked gcc ($gccFlags + @('-o','tests_terminal.exe','tests_terminal.c','fv_terminal.c'))
    Invoke-Checked .\tests_terminal.exe @()

    Write-Host "[test] offscreen export ..." -ForegroundColor Cyan
    Invoke-Checked .\fbview.exe @('-dir', $PWD.Path, '-export', 'regression.bmp')
    $bmp = [IO.File]::ReadAllBytes("$PWD\regression.bmp")
    if ($bmp.Length -ne 1152054 -or $bmp[0] -ne 66 -or $bmp[1] -ne 77 -or
        [BitConverter]::ToInt32($bmp, 18) -ne 800 -or [BitConverter]::ToInt32($bmp, 22) -ne 480) {
        throw 'unexpected BMP header or dimensions'
    }

    Write-Host "All regression checks passed." -ForegroundColor Green
}
finally {
    Pop-Location
    $env:PATH = $previousPath
    $env:TMP  = $previousTmp
    $env:TEMP = $previousTemp
}