param(
    [string]$BuildDir = "build",
    [string]$Config = "Release",
    [string]$Generator = "",
    [string]$CryptoPPRoot = $env:CRYPTOPP_ROOT
)

$ErrorActionPreference = "Stop"

$cmakeArgs = @("-S", ".", "-B", $BuildDir)

if ($Generator -ne "") {
    $cmakeArgs += @("-G", $Generator)
}

if ($CryptoPPRoot) {
    $cmakeArgs += "-DCRYPTOPP_ROOT=$CryptoPPRoot"
}

cmake @cmakeArgs
cmake --build $BuildDir --config $Config
Write-Host "Build completed."
