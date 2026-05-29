param(
    [string]$BuildDir = "build"
)

$ErrorActionPreference = "Stop"

cmake -S . -B $BuildDir
cmake --build $BuildDir
