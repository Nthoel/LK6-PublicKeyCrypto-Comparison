param(
    [string]$BuildDir = "build"
)

$ErrorActionPreference = "Stop"

$exe = Join-Path $BuildDir "lk6_compare.exe"

if (-not (Test-Path -LiteralPath $exe)) {
    throw "Executable not found: $exe. Build the project first."
}

& $exe
