# Stage 2 setup for Crypto++

This stage upgrades the LK6 scaffold into a benchmark project that is ready to use Crypto++.

## What this stage adds

- CMake integration through `cmake/FindCryptoPP.cmake`
- Actual modular C++ classes for:
  - RSA
  - ECIES
  - ElGamal
  - Hybrid RSA-AES
- Benchmark runner that scans `data/input`
- CSV output writer for experiment results
- PowerShell scripts for build and benchmark execution

## Recommended installation paths

### Option A - vcpkg

1. Install vcpkg
2. Run `vcpkg install cryptopp`
3. Build with the same toolchain you use for vcpkg

### Option B - manual Crypto++ install

1. Build or install Crypto++
2. Set environment variable `CRYPTOPP_ROOT`
3. Example:
   `setx CRYPTOPP_ROOT "C:\libs\cryptopp"`

## Build

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\run-build.ps1 -Config Release -CryptoPPRoot $env:CRYPTOPP_ROOT
```

## Run benchmark

```powershell
.\scripts\run-benchmark.ps1 -DatasetRoot "data/input"
```

## Notes for the LK report

- ECC is implemented as ECIES because it is a practical encryption scheme built on elliptic curve cryptography.
- RSA and ElGamal here use direct public-key encryption flow, so they are expected to scale worse on large files.
- Hybrid RSA-AES is expected to perform best on medium to very large datasets.
