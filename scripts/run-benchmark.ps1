param(
    [string]$BuildDir = "build",
    [string]$Config = "Release",
    [string]$DatasetRoot = "data/input",
    [string]$CsvPath = "results/csv/benchmark_results.csv",
    [string]$OutputRoot = "results"
)

$ErrorActionPreference = "Stop"

$candidates = @(
    (Join-Path $BuildDir "lk6_crypto_compare.exe"),
    (Join-Path (Join-Path $BuildDir $Config) "lk6_crypto_compare.exe"),
    (Join-Path (Join-Path $BuildDir "Debug") "lk6_crypto_compare.exe"),
    (Join-Path (Join-Path $BuildDir "Release") "lk6_crypto_compare.exe")
)

$exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $exe) {
    throw "Executable not found. Build the project first using scripts/run-build.ps1"
}

& $exe $DatasetRoot $CsvPath $OutputRoot
