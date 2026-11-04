# EmbeddedScreenPreview build script (standalone, no external project required)
#
#   .\build.ps1               fbview.exe + demo_adapter.dll
#   .\build.ps1 -HostOnly     host only
#
# Requires gcc (MSYS2 mingw64 recommended).

param([switch] $HostOnly)

$ErrorActionPreference = "Stop"

$oldPath = $env:PATH
$oldTmp  = $env:TMP
$oldTemp = $env:TEMP



# gcc cannot create temporary files under a path containing non-ASCII
# characters (a Chinese user name in %TEMP% is enough to break it), so prefer
# an ASCII staging directory and fall back to the default temp dir.
$asciiTmp = "C:\pc_build"
try {
    New-Item -ItemType Directory -Force -Path $asciiTmp -ErrorAction Stop | Out-Null
    $probe = Join-Path $asciiTmp "_probe.tmp"
    Set-Content -LiteralPath $probe -Value "x" -ErrorAction Stop
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    $env:TMP  = $asciiTmp
    $env:TEMP = $asciiTmp
}
catch {
    Write-Host "note: $asciiTmp not usable, using the default temp directory" -ForegroundColor Yellow
}

# Prefer MSYS2's gcc when present, otherwise trust PATH.
$msysGcc = "C:\msys64\mingw64\bin\gcc.exe"
if (Test-Path $msysGcc) {
    $env:PATH = "C:\msys64\mingw64\bin;$env:PATH"
    $GCC = $msysGcc
}
else {
    $GCC = "gcc"
}
Push-Location $PSScriptRoot
try {
    Write-Host "[1/2] fbview.exe ..." -ForegroundColor Cyan
    & $GCC -std=c11 -O2 -Wall -Wextra -Wno-cast-function-type -I. -o fbview.exe `
        fbview_main.c fbview.c fbview_loader.c fv_sim.c fv_terminal.c `
        -lgdi32 -luser32 -lshell32 -lole32 -lcomctl32
    if ($LASTEXITCODE -ne 0) { throw "fbview.exe build failed" }
    Write-Host "      OK -> fbview.exe" -ForegroundColor Green

    if (-not $HostOnly) {
        Write-Host "[2/2] demo_adapter.dll ..." -ForegroundColor Cyan
        & $GCC -std=c11 -O2 -Wall -Wextra -shared -DFBVIEW_BUILD_DLL -I. `
            -o demo_adapter.dll demo_adapter.c
        if ($LASTEXITCODE -ne 0) { throw "demo_adapter.dll build failed" }
        Write-Host "      OK -> demo_adapter.dll" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Run:" -ForegroundColor Yellow
    Write-Host "  .\fbview.exe                          pick a folder"
    Write-Host "  .\fbview.exe -dir .                   use this folder"
    Write-Host "  .\fbview.exe -dir . -export out.bmp   offscreen render"
}
finally {
    Pop-Location
    $env:PATH = $oldPath
    $env:TMP  = $oldTmp
    $env:TEMP = $oldTemp
}