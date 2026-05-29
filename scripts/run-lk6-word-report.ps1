param(
    [string]$DatasetRoot = "data/input",
    [string]$BuildConfig = "Release",
    [string]$OutputRoot = "results"
)

$ErrorActionPreference = "Stop"

$exe = Join-Path "." ("build\" + $BuildConfig + "\lk6_crypto_compare.exe")
if (-not (Test-Path $exe)) {
    throw "Executable not found at $exe. Build first with scripts\run-build.ps1"
}

$datasetPath = (Resolve-Path $DatasetRoot).Path
$resultsRoot = Join-Path "." $OutputRoot
$rawCsv = Join-Path $resultsRoot "csv\benchmark_results.csv"

Write-Host "[INFO] Running benchmark on dataset: $datasetPath" -ForegroundColor Cyan
& $exe $datasetPath $rawCsv $resultsRoot

Write-Host ""
Write-Host "[DONE] Word-ready CSV files are available under:" -ForegroundColor Green
Write-Host "  $resultsRoot\csv"
Write-Host ""
Write-Host "Important files:" -ForegroundColor Yellow
Write-Host "  - lk6_task4_file_size.csv"
Write-Host "  - lk6_task5_time.csv"
Write-Host "  - lk6_task6_entropy.csv"
Write-Host "  - lk6_task7_correlation.csv"
Write-Host "  - lk6_task8_avalanche.csv"
Write-Host "  - lk6_summary_average.csv"
