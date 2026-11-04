# EmbeddedScreenPreview build script
#
#   .\build.ps1               build fbview.exe + demo_adapter.dll
#   .\build.ps1 -HostOnly     build the host only
#
# Requires: gcc on PATH (MSYS2 mingw64 recommended).

param(
    [switch] $HostOnly
)

$ErrorActionPreference = "Stop"

$oldPath = $env:PATH
$oldTmp  = $env:TMP
$oldTemp = $env:TEMP

$env:PATH = "C:\msys64\mingw64\bin;$env:PATH"

# gcc cannot create temp files under a non-ASCII path -> force an ASCII temp dir
$env:TMP  = "C:\pc_build"
$env:TEMP = "C:\pc_build"
New-Item -ItemType Directory -Force -Path $env:TMP | Out-Null

$GCC = "C:\msys64\mingw64\bin\gcc.exe"
if (-not (Test-Path $GCC)) { $GCC = "gcc" }

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