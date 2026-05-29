
param(
    [string]$ProjectRoot = ".",
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

function Write-ProjectFile {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Content,
        [string]$BackupRoot
    )

    $targetPath = Join-Path $Root $RelativePath
    $parent = Split-Path $targetPath -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ((Test-Path $targetPath) -and $BackupRoot) {
        $backupPath = Join-Path $BackupRoot $RelativePath
        $backupParent = Split-Path $backupPath -Parent
        if (-not (Test-Path $backupParent)) {
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        }
        Copy-Item $targetPath $backupPath -Force
    }

    Set-Content -Path $targetPath -Value $Content -Encoding UTF8
    Write-Host ("[OK] " + $RelativePath)
}

$resolvedRoot = (Resolve-Path $ProjectRoot).Path
$backupRoot = $null

if (-not $NoBackup) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupRoot = Join-Path $resolvedRoot (".backup\stage2_" + $timestamp)
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

$dirs = @(
    "cmake",
    "config",
    "docs",
    "include\algorithms",
    "include\benchmarks",
    "include\core",
    "include\utils",
    "results\artifacts",
    "results\csv",
    "results\keys",
    "scripts",
    "src\algorithms",
    "src\benchmarks",
    "src\core",
    "src\utils",
    "third_party"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $resolvedRoot $dir) -Force | Out-Null
}

$files = @{}

$files["cmake/FindCryptoPP.cmake"] = @'
find_path(CRYPTOPP_INCLUDE_DIR
    NAMES cryptopp/cryptlib.h
    HINTS
        ${CRYPTOPP_ROOT}
        $ENV{CRYPTOPP_ROOT}
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp-install
    PATH_SUFFIXES include
)

find_library(CRYPTOPP_LIBRARY
    NAMES cryptopp cryptlib
    HINTS
        ${CRYPTOPP_ROOT}
        $ENV{CRYPTOPP_ROOT}
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp-install
    PATH_SUFFIXES lib lib64
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CryptoPP DEFAULT_MSG CRYPTOPP_INCLUDE_DIR CRYPTOPP_LIBRARY)

if (CryptoPP_FOUND AND NOT TARGET CryptoPP::CryptoPP)
    add_library(CryptoPP::CryptoPP UNKNOWN IMPORTED)
    set_target_properties(CryptoPP::CryptoPP PROPERTIES
        IMPORTED_LOCATION "${CRYPTOPP_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${CRYPTOPP_INCLUDE_DIR}"
    )
endif()
'@

$files["CMakeLists.txt"] = @'
cmake_minimum_required(VERSION 3.20)
project(LK6PublicKeyCryptoComparison LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

option(LK6_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)

if (MSVC)
    add_compile_options(/W4 /permissive-)
    if (LK6_WARNINGS_AS_ERRORS)
        add_compile_options(/WX)
    endif()
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
    if (LK6_WARNINGS_AS_ERRORS)
        add_compile_options(-Werror)
    endif()
endif()

find_package(CryptoPP REQUIRED)

add_executable(lk6_crypto_compare
    src/main.cpp
    src/core/AlgorithmFactory.cpp
    src/benchmarks/BenchmarkRunner.cpp
    src/utils/FileUtils.cpp
    src/utils/CsvWriter.cpp
    src/algorithms/RSAAlgorithm.cpp
    src/algorithms/ECIESAlgorithm.cpp
    src/algorithms/ElGamalAlgorithm.cpp
    src/algorithms/HybridRSAAESAlgorithm.cpp
)

target_include_directories(lk6_crypto_compare PRIVATE include)
target_link_libraries(lk6_crypto_compare PRIVATE CryptoPP::CryptoPP)

if (WIN32)
    target_compile_definitions(lk6_crypto_compare PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()
'@

$files["vcpkg.json"] = @'
{
  "name": "lk6-public-key-crypto-comparison",
  "version-string": "0.2.0",
  "description": "LK 6 modular benchmark project for RSA, ECIES, ElGamal, and Hybrid RSA-AES",
  "dependencies": [
    "cryptopp"
  ]
}
'@

$files["include/core/Types.hpp"] = @'
#pragma once

#include <cstdint>
#include <filesystem>
#include <string>

namespace lk6 {

namespace fs = std::filesystem;

enum class AlgorithmId {
    RSA,
    ECIES,
    ElGamal,
    HybridRSA_AES
};

inline std::string ToString(AlgorithmId id) {
    switch (id) {
        case AlgorithmId::RSA: return "rsa";
        case AlgorithmId::ECIES: return "ecies";
        case AlgorithmId::ElGamal: return "elgamal";
        case AlgorithmId::HybridRSA_AES: return "hybrid_rsa_aes";
        default: return "unknown";
    }
}

struct KeyPaths {
    fs::path publicKey;
    fs::path privateKey;
};

struct BenchmarkRow {
    std::string algorithm;
    std::string relativeFile;
    std::string sizeCategory;
    std::uintmax_t inputBytes = 0;
    std::uintmax_t outputBytes = 0;
    double keygenMs = 0.0;
    double encryptMs = 0.0;
    double decryptMs = 0.0;
    bool decryptedMatch = false;
    std::string notes;
};

struct BenchmarkOptions {
    fs::path datasetRoot = "data/input";
    fs::path outputRoot = "results";
    fs::path csvPath = "results/csv/benchmark_results.csv";
    bool recursive = true;
};

} // namespace lk6
'@

$files["include/core/IEncryptionScheme.hpp"] = @'
#pragma once

#include "core/Types.hpp"

namespace lk6 {

class IEncryptionScheme {
public:
    virtual ~IEncryptionScheme() = default;

    virtual AlgorithmId Id() const = 0;
    virtual std::string Name() const = 0;

    virtual void GenerateKeys(const KeyPaths& paths) = 0;
    virtual void EncryptFile(const fs::path& inputFile,
                             const fs::path& outputFile,
                             const fs::path& publicKeyFile) = 0;
    virtual void DecryptFile(const fs::path& inputFile,
                             const fs::path& outputFile,
                             const fs::path& privateKeyFile) = 0;
};

} // namespace lk6
'@

$files["include/core/AlgorithmFactory.hpp"] = @'
#pragma once

#include <memory>
#include <utility>
#include <vector>

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

std::vector<std::unique_ptr<IEncryptionScheme>> CreateAlgorithms();

} // namespace lk6
'@

$files["include/utils/Timer.hpp"] = @'
#pragma once

#include <chrono>

namespace lk6::utils {

class Timer {
public:
    using Clock = std::chrono::steady_clock;

    Timer() : start_(Clock::now()) {}

    void Reset() {
        start_ = Clock::now();
    }

    double ElapsedMs() const {
        const auto end = Clock::now();
        return std::chrono::duration<double, std::milli>(end - start_).count();
    }

private:
    Clock::time_point start_;
};

} // namespace lk6::utils
'@

$files["include/utils/FileUtils.hpp"] = @'
#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace lk6::utils {

namespace fs = std::filesystem;

std::string ReadBinaryFile(const fs::path& path);
void WriteBinaryFile(const fs::path& path, const std::string& data);
void EnsureParentDir(const fs::path& path);
std::vector<fs::path> CollectDatasetFiles(const fs::path& root, bool recursive = true);
bool FilesEqual(const fs::path& lhs, const fs::path& rhs);

} // namespace lk6::utils
'@

$files["include/utils/CsvWriter.hpp"] = @'
#pragma once

#include <filesystem>
#include <vector>

#include "core/Types.hpp"

namespace lk6::utils {

class CsvWriter {
public:
    static void WriteRows(const std::filesystem::path& path,
                          const std::vector<lk6::BenchmarkRow>& rows);
};

} // namespace lk6::utils
'@

$files["include/utils/CryptoChunkIO.hpp"] = @'
#pragma once

#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <string>

#include <cryptopp/cryptlib.h>
#include <cryptopp/filters.h>
#include <cryptopp/osrng.h>

namespace lk6::utils {

inline void AppendUint32(std::string& output, std::uint32_t value) {
    output.push_back(static_cast<char>((value >> 24) & 0xFF));
    output.push_back(static_cast<char>((value >> 16) & 0xFF));
    output.push_back(static_cast<char>((value >> 8) & 0xFF));
    output.push_back(static_cast<char>(value & 0xFF));
}

inline std::uint32_t ReadUint32(const std::string& input, std::size_t& offset) {
    if (offset + 4 > input.size()) {
        throw std::runtime_error("Invalid binary package: missing 4-byte length field");
    }

    const auto b0 = static_cast<std::uint8_t>(input[offset + 0]);
    const auto b1 = static_cast<std::uint8_t>(input[offset + 1]);
    const auto b2 = static_cast<std::uint8_t>(input[offset + 2]);
    const auto b3 = static_cast<std::uint8_t>(input[offset + 3]);
    offset += 4;

    return (static_cast<std::uint32_t>(b0) << 24) |
           (static_cast<std::uint32_t>(b1) << 16) |
           (static_cast<std::uint32_t>(b2) << 8) |
           (static_cast<std::uint32_t>(b3));
}

template <typename EncryptorT>
std::string EncryptChunked(CryptoPP::AutoSeededRandomPool& rng,
                           EncryptorT& encryptor,
                           const std::string& plaintext) {
    const std::size_t maxBlock = encryptor.FixedMaxPlaintextLength();
    if (maxBlock == 0) {
        throw std::runtime_error("Encryptor reported max plaintext length 0");
    }

    std::string output;

    for (std::size_t offset = 0; offset < plaintext.size(); offset += maxBlock) {
        const std::size_t blockSize = std::min(maxBlock, plaintext.size() - offset);
        std::string encryptedBlock;

        CryptoPP::StringSource ss(
            reinterpret_cast<const CryptoPP::byte*>(plaintext.data()) + offset,
            blockSize,
            true,
            new CryptoPP::PK_EncryptorFilter(
                rng,
                encryptor,
                new CryptoPP::StringSink(encryptedBlock)));

        AppendUint32(output, static_cast<std::uint32_t>(encryptedBlock.size()));
        output += encryptedBlock;
    }

    return output;
}

template <typename DecryptorT>
std::string DecryptChunked(CryptoPP::AutoSeededRandomPool& rng,
                           DecryptorT& decryptor,
                           const std::string& ciphertext) {
    std::string output;
    std::size_t offset = 0;

    while (offset < ciphertext.size()) {
        const auto blockSize = static_cast<std::size_t>(ReadUint32(ciphertext, offset));

        if (offset + blockSize > ciphertext.size()) {
            throw std::runtime_error("Invalid binary package: encrypted block exceeds file size");
        }

        std::string encryptedBlock = ciphertext.substr(offset, blockSize);
        offset += blockSize;

        std::string decryptedBlock;
        CryptoPP::StringSource ss(
            reinterpret_cast<const CryptoPP::byte*>(encryptedBlock.data()),
            encryptedBlock.size(),
            true,
            new CryptoPP::PK_DecryptorFilter(
                rng,
                decryptor,
                new CryptoPP::StringSink(decryptedBlock)));

        output += decryptedBlock;
    }

    return output;
}

} // namespace lk6::utils
'@

$files["include/algorithms/RSAAlgorithm.hpp"] = @'
#pragma once

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

class RSAAlgorithm final : public IEncryptionScheme {
public:
    explicit RSAAlgorithm(int keySizeBits = 3072);

    AlgorithmId Id() const override;
    std::string Name() const override;

    void GenerateKeys(const KeyPaths& paths) override;
    void EncryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& publicKeyFile) override;
    void DecryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& privateKeyFile) override;

private:
    int keySizeBits_;
};

} // namespace lk6
'@

$files["include/algorithms/ECIESAlgorithm.hpp"] = @'
#pragma once

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

class ECIESAlgorithm final : public IEncryptionScheme {
public:
    AlgorithmId Id() const override;
    std::string Name() const override;

    void GenerateKeys(const KeyPaths& paths) override;
    void EncryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& publicKeyFile) override;
    void DecryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& privateKeyFile) override;
};

} // namespace lk6
'@

$files["include/algorithms/ElGamalAlgorithm.hpp"] = @'
#pragma once

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

class ElGamalAlgorithm final : public IEncryptionScheme {
public:
    explicit ElGamalAlgorithm(int keySizeBits = 2048);

    AlgorithmId Id() const override;
    std::string Name() const override;

    void GenerateKeys(const KeyPaths& paths) override;
    void EncryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& publicKeyFile) override;
    void DecryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& privateKeyFile) override;

private:
    int keySizeBits_;
};

} // namespace lk6
'@

$files["include/algorithms/HybridRSAAESAlgorithm.hpp"] = @'
#pragma once

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

class HybridRSAAESAlgorithm final : public IEncryptionScheme {
public:
    explicit HybridRSAAESAlgorithm(int rsaKeySizeBits = 3072);

    AlgorithmId Id() const override;
    std::string Name() const override;

    void GenerateKeys(const KeyPaths& paths) override;
    void EncryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& publicKeyFile) override;
    void DecryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& privateKeyFile) override;

private:
    int rsaKeySizeBits_;
};

} // namespace lk6
'@

$files["include/benchmarks/BenchmarkRunner.hpp"] = @'
#pragma once

#include "core/Types.hpp"

namespace lk6 {

class BenchmarkRunner {
public:
    explicit BenchmarkRunner(BenchmarkOptions options);

    int RunAll();

private:
    std::string GetSizeCategory(std::uintmax_t bytes) const;

    BenchmarkOptions options_;
};

} // namespace lk6
'@

$files["src/utils/FileUtils.cpp"] = @'
#include "utils/FileUtils.hpp"

#include <algorithm>
#include <fstream>
#include <iterator>
#include <stdexcept>

namespace lk6::utils {

std::string ReadBinaryFile(const fs::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        throw std::runtime_error("Failed to open file for reading: " + path.string());
    }

    return std::string(
        std::istreambuf_iterator<char>(input),
        std::istreambuf_iterator<char>());
}

void WriteBinaryFile(const fs::path& path, const std::string& data) {
    EnsureParentDir(path);

    std::ofstream output(path, std::ios::binary);
    if (!output) {
        throw std::runtime_error("Failed to open file for writing: " + path.string());
    }

    output.write(data.data(), static_cast<std::streamsize>(data.size()));
    if (!output.good()) {
        throw std::runtime_error("Failed to write file: " + path.string());
    }
}

void EnsureParentDir(const fs::path& path) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        fs::create_directories(parent);
    }
}

std::vector<fs::path> CollectDatasetFiles(const fs::path& root, bool recursive) {
    std::vector<fs::path> files;

    if (!fs::exists(root)) {
        return files;
    }

    auto isTargetFile = [](const fs::path& path) {
        if (!fs::is_regular_file(path)) {
            return false;
        }

        const auto ext = path.extension().string();
        return ext == ".txt" || ext == ".csv" || ext == ".json";
    };

    if (recursive) {
        for (const auto& entry : fs::recursive_directory_iterator(root)) {
            if (isTargetFile(entry.path())) {
                files.push_back(entry.path());
            }
        }
    } else {
        for (const auto& entry : fs::directory_iterator(root)) {
            if (isTargetFile(entry.path())) {
                files.push_back(entry.path());
            }
        }
    }

    std::sort(files.begin(), files.end());
    return files;
}

bool FilesEqual(const fs::path& lhs, const fs::path& rhs) {
    if (!fs::exists(lhs) || !fs::exists(rhs)) {
        return false;
    }

    if (fs::file_size(lhs) != fs::file_size(rhs)) {
        return false;
    }

    return ReadBinaryFile(lhs) == ReadBinaryFile(rhs);
}

} // namespace lk6::utils
'@

$files["src/utils/CsvWriter.cpp"] = @'
#include "utils/CsvWriter.hpp"

#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

namespace lk6::utils {

namespace {
std::string EscapeCsv(const std::string& value) {
    bool requiresQuotes = false;
    std::string escaped;

    for (char ch : value) {
        if (ch == '"' || ch == ',' || ch == '\n' || ch == '\r') {
            requiresQuotes = true;
        }

        if (ch == '"') {
            escaped += "\"\"";
        } else {
            escaped.push_back(ch);
        }
    }

    if (!requiresQuotes) {
        return escaped;
    }

    return "\"" + escaped + "\"";
}
} // namespace

void CsvWriter::WriteRows(const std::filesystem::path& path,
                         const std::vector<lk6::BenchmarkRow>& rows) {
    std::filesystem::create_directories(path.parent_path());

    std::ofstream output(path, std::ios::binary);
    if (!output) {
        throw std::runtime_error("Failed to open CSV output: " + path.string());
    }

    output << "algorithm,relative_file,size_category,input_bytes,output_bytes,keygen_ms,encrypt_ms,decrypt_ms,decrypted_match,notes\n";

    for (const auto& row : rows) {
        output << EscapeCsv(row.algorithm) << ","
               << EscapeCsv(row.relativeFile) << ","
               << EscapeCsv(row.sizeCategory) << ","
               << row.inputBytes << ","
               << row.outputBytes << ","
               << row.keygenMs << ","
               << row.encryptMs << ","
               << row.decryptMs << ","
               << (row.decryptedMatch ? "true" : "false") << ","
               << EscapeCsv(row.notes) << "\n";
    }
}

} // namespace lk6::utils
'@

$files["src/core/AlgorithmFactory.cpp"] = @'
#include "core/AlgorithmFactory.hpp"

#include <memory>
#include <vector>

#include "algorithms/ECIESAlgorithm.hpp"
#include "algorithms/ElGamalAlgorithm.hpp"
#include "algorithms/HybridRSAAESAlgorithm.hpp"
#include "algorithms/RSAAlgorithm.hpp"

namespace lk6 {

std::vector<std::unique_ptr<IEncryptionScheme>> CreateAlgorithms() {
    std::vector<std::unique_ptr<IEncryptionScheme>> algorithms;
    algorithms.push_back(std::make_unique<RSAAlgorithm>());
    algorithms.push_back(std::make_unique<ECIESAlgorithm>());
    algorithms.push_back(std::make_unique<ElGamalAlgorithm>());
    algorithms.push_back(std::make_unique<HybridRSAAESAlgorithm>());
    return algorithms;
}

} // namespace lk6
'@

$files["src/algorithms/RSAAlgorithm.cpp"] = @'
#include "algorithms/RSAAlgorithm.hpp"

#include <stdexcept>
#include <string>

#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/osrng.h>
#include <cryptopp/rsa.h>
#include <cryptopp/sha.h>

#include "utils/CryptoChunkIO.hpp"
#include "utils/FileUtils.hpp"

namespace lk6 {

RSAAlgorithm::RSAAlgorithm(int keySizeBits) : keySizeBits_(keySizeBits) {}

AlgorithmId RSAAlgorithm::Id() const {
    return AlgorithmId::RSA;
}

std::string RSAAlgorithm::Name() const {
    return "rsa";
}

void RSAAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    privateKey.GenerateRandomWithKeySize(rng, static_cast<unsigned int>(keySizeBits_));

    CryptoPP::RSA::PublicKey publicKey(privateKey);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    privateKey.Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    publicKey.Save(publicSink);
}

void RSAAlgorithm::EncryptFile(const fs::path& inputFile,
                               const fs::path& outputFile,
                               const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PublicKey publicKey;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    publicKey.Load(publicSource);
    publicKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Encryptor encryptor(publicKey);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);
    const std::string ciphertext = utils::EncryptChunked(rng, encryptor, plaintext);

    utils::WriteBinaryFile(outputFile, ciphertext);
}

void RSAAlgorithm::DecryptFile(const fs::path& inputFile,
                               const fs::path& outputFile,
                               const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    privateKey.Load(privateSource);
    privateKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Decryptor decryptor(privateKey);

    const std::string ciphertext = utils::ReadBinaryFile(inputFile);
    const std::string plaintext = utils::DecryptChunked(rng, decryptor, ciphertext);

    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
'@

$files["src/algorithms/ECIESAlgorithm.cpp"] = @'
#include "algorithms/ECIESAlgorithm.hpp"

#include <string>

#include <cryptopp/eccrypto.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/oids.h>
#include <cryptopp/osrng.h>

#include "utils/FileUtils.hpp"

namespace lk6 {

namespace {
using ECIESDecryptor = CryptoPP::ECIES<CryptoPP::ECP>::Decryptor;
using ECIESEncryptor = CryptoPP::ECIES<CryptoPP::ECP>::Encryptor;
}

AlgorithmId ECIESAlgorithm::Id() const {
    return AlgorithmId::ECIES;
}

std::string ECIESAlgorithm::Name() const {
    return "ecies";
}

void ECIESAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    ECIESDecryptor decryptor(rng, CryptoPP::ASN1::secp256r1());
    ECIESEncryptor encryptor(decryptor);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    decryptor.GetPrivateKey().Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    encryptor.GetPublicKey().Save(publicSink);
}

void ECIESAlgorithm::EncryptFile(const fs::path& inputFile,
                                 const fs::path& outputFile,
                                 const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    ECIESEncryptor encryptor;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    encryptor.AccessPublicKey().Load(publicSource);
    encryptor.GetPublicKey().ThrowIfInvalid(rng, 3);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);

    std::string ciphertext;
    CryptoPP::StringSource ss(
        plaintext,
        true,
        new CryptoPP::PK_EncryptorFilter(
            rng,
            encryptor,
            new CryptoPP::StringSink(ciphertext)));

    utils::WriteBinaryFile(outputFile, ciphertext);
}

void ECIESAlgorithm::DecryptFile(const fs::path& inputFile,
                                 const fs::path& outputFile,
                                 const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    ECIESDecryptor decryptor;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    decryptor.AccessPrivateKey().Load(privateSource);
    decryptor.GetPrivateKey().ThrowIfInvalid(rng, 3);

    const std::string ciphertext = utils::ReadBinaryFile(inputFile);

    std::string plaintext;
    CryptoPP::StringSource ss(
        ciphertext,
        true,
        new CryptoPP::PK_DecryptorFilter(
            rng,
            decryptor,
            new CryptoPP::StringSink(plaintext)));

    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
'@

$files["src/algorithms/ElGamalAlgorithm.cpp"] = @'
#include "algorithms/ElGamalAlgorithm.hpp"

#include <string>

#include <cryptopp/elgamal.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/osrng.h>

#include "utils/CryptoChunkIO.hpp"
#include "utils/FileUtils.hpp"

namespace lk6 {

ElGamalAlgorithm::ElGamalAlgorithm(int keySizeBits) : keySizeBits_(keySizeBits) {}

AlgorithmId ElGamalAlgorithm::Id() const {
    return AlgorithmId::ElGamal;
}

std::string ElGamalAlgorithm::Name() const {
    return "elgamal";
}

void ElGamalAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::ElGamal::Decryptor decryptor;
    decryptor.AccessKey().GenerateRandomWithKeySize(rng, static_cast<unsigned int>(keySizeBits_));

    CryptoPP::ElGamal::Encryptor encryptor(decryptor);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    decryptor.AccessKey().Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    encryptor.AccessKey().Save(publicSink);
}

void ElGamalAlgorithm::EncryptFile(const fs::path& inputFile,
                                   const fs::path& outputFile,
                                   const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::ElGamal::Encryptor encryptor;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    encryptor.AccessKey().Load(publicSource);
    encryptor.AccessKey().ThrowIfInvalid(rng, 3);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);
    const std::string ciphertext = utils::EncryptChunked(rng, encryptor, plaintext);

    utils::WriteBinaryFile(outputFile, ciphertext);
}

void ElGamalAlgorithm::DecryptFile(const fs::path& inputFile,
                                   const fs::path& outputFile,
                                   const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::ElGamal::Decryptor decryptor;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    decryptor.AccessKey().Load(privateSource);
    decryptor.AccessKey().ThrowIfInvalid(rng, 3);

    const std::string ciphertext = utils::ReadBinaryFile(inputFile);
    const std::string plaintext = utils::DecryptChunked(rng, decryptor, ciphertext);

    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
'@

$files["src/algorithms/HybridRSAAESAlgorithm.cpp"] = @'
#include "algorithms/HybridRSAAESAlgorithm.hpp"

#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <string>

#include <cryptopp/aes.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/gcm.h>
#include <cryptopp/osrng.h>
#include <cryptopp/rsa.h>
#include <cryptopp/sha.h>

#include "utils/CryptoChunkIO.hpp"
#include "utils/FileUtils.hpp"

namespace lk6 {

namespace {
constexpr std::size_t kAesKeyBytes = 32;
constexpr std::size_t kIvBytes = 12;
constexpr char kMagic[] = "LK6H1";

std::string EncryptAesGcm(const CryptoPP::SecByteBlock& key,
                          const CryptoPP::SecByteBlock& iv,
                          const std::string& plaintext) {
    CryptoPP::GCM<CryptoPP::AES>::Encryption encryption;
    encryption.SetKeyWithIV(key, key.size(), iv, iv.size());

    std::string ciphertext;
    CryptoPP::StringSource ss(
        plaintext,
        true,
        new CryptoPP::AuthenticatedEncryptionFilter(
            encryption,
            new CryptoPP::StringSink(ciphertext)));

    return ciphertext;
}

std::string DecryptAesGcm(const CryptoPP::SecByteBlock& key,
                          const CryptoPP::SecByteBlock& iv,
                          const std::string& ciphertext) {
    CryptoPP::GCM<CryptoPP::AES>::Decryption decryption;
    decryption.SetKeyWithIV(key, key.size(), iv, iv.size());

    std::string plaintext;
    CryptoPP::StringSource ss(
        ciphertext,
        true,
        new CryptoPP::AuthenticatedDecryptionFilter(
            decryption,
            new CryptoPP::StringSink(plaintext)));

    return plaintext;
}

} // namespace

HybridRSAAESAlgorithm::HybridRSAAESAlgorithm(int rsaKeySizeBits)
    : rsaKeySizeBits_(rsaKeySizeBits) {}

AlgorithmId HybridRSAAESAlgorithm::Id() const {
    return AlgorithmId::HybridRSA_AES;
}

std::string HybridRSAAESAlgorithm::Name() const {
    return "hybrid_rsa_aes";
}

void HybridRSAAESAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    privateKey.GenerateRandomWithKeySize(rng, static_cast<unsigned int>(rsaKeySizeBits_));

    CryptoPP::RSA::PublicKey publicKey(privateKey);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    privateKey.Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    publicKey.Save(publicSink);
}

void HybridRSAAESAlgorithm::EncryptFile(const fs::path& inputFile,
                                        const fs::path& outputFile,
                                        const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PublicKey publicKey;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    publicKey.Load(publicSource);
    publicKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Encryptor rsaEncryptor(publicKey);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);

    CryptoPP::SecByteBlock aesKey(kAesKeyBytes);
    CryptoPP::SecByteBlock iv(kIvBytes);
    rng.GenerateBlock(aesKey, aesKey.size());
    rng.GenerateBlock(iv, iv.size());

    std::string encryptedAesKey;
    CryptoPP::StringSource ss1(
        aesKey.BytePtr(),
        aesKey.size(),
        true,
        new CryptoPP::PK_EncryptorFilter(
            rng,
            rsaEncryptor,
            new CryptoPP::StringSink(encryptedAesKey)));

    const std::string ciphertext = EncryptAesGcm(aesKey, iv, plaintext);

    std::string package(kMagic);
    utils::AppendUint32(package, static_cast<std::uint32_t>(encryptedAesKey.size()));
    package += encryptedAesKey;
    utils::AppendUint32(package, static_cast<std::uint32_t>(iv.size()));
    package.append(reinterpret_cast<const char*>(iv.BytePtr()), iv.size());
    package += ciphertext;

    utils::WriteBinaryFile(outputFile, package);
}

void HybridRSAAESAlgorithm::DecryptFile(const fs::path& inputFile,
                                        const fs::path& outputFile,
                                        const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    privateKey.Load(privateSource);
    privateKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Decryptor rsaDecryptor(privateKey);

    const std::string package = utils::ReadBinaryFile(inputFile);
    if (package.size() < 5 || package.substr(0, 5) != kMagic) {
        throw std::runtime_error("Invalid hybrid package header");
    }

    std::size_t offset = 5;
    const auto encryptedAesKeySize = static_cast<std::size_t>(utils::ReadUint32(package, offset));
    if (offset + encryptedAesKeySize > package.size()) {
        throw std::runtime_error("Invalid hybrid package: RSA-wrapped key exceeds file size");
    }

    const std::string encryptedAesKey = package.substr(offset, encryptedAesKeySize);
    offset += encryptedAesKeySize;

    const auto ivSize = static_cast<std::size_t>(utils::ReadUint32(package, offset));
    if (offset + ivSize > package.size()) {
        throw std::runtime_error("Invalid hybrid package: IV exceeds file size");
    }

    const std::string ivBytes = package.substr(offset, ivSize);
    offset += ivSize;

    const std::string ciphertext = package.substr(offset);

    std::string rawAesKey;
    CryptoPP::StringSource ss2(
        encryptedAesKey,
        true,
        new CryptoPP::PK_DecryptorFilter(
            rng,
            rsaDecryptor,
            new CryptoPP::StringSink(rawAesKey)));

    CryptoPP::SecByteBlock aesKey(
        reinterpret_cast<const CryptoPP::byte*>(rawAesKey.data()),
        rawAesKey.size());

    CryptoPP::SecByteBlock iv(
        reinterpret_cast<const CryptoPP::byte*>(ivBytes.data()),
        ivBytes.size());

    const std::string plaintext = DecryptAesGcm(aesKey, iv, ciphertext);
    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
'@

$files["src/benchmarks/BenchmarkRunner.cpp"] = @'
#include "benchmarks/BenchmarkRunner.hpp"

#include <exception>
#include <filesystem>
#include <iostream>
#include <utility>
#include <vector>

#include "core/AlgorithmFactory.hpp"
#include "utils/CsvWriter.hpp"
#include "utils/FileUtils.hpp"
#include "utils/Timer.hpp"

namespace lk6 {

BenchmarkRunner::BenchmarkRunner(BenchmarkOptions options)
    : options_(std::move(options)) {}

std::string BenchmarkRunner::GetSizeCategory(std::uintmax_t bytes) const {
    constexpr std::uintmax_t kb = 1024;
    constexpr std::uintmax_t mb = 1024 * 1024;

    if (bytes < 10 * kb) {
        return "very_small";
    }
    if (bytes <= 100 * kb) {
        return "small";
    }
    if (bytes <= 1 * mb) {
        return "medium";
    }
    if (bytes <= 5 * mb) {
        return "large";
    }
    return "very_large";
}

int BenchmarkRunner::RunAll() {
    const auto datasetFiles = utils::CollectDatasetFiles(options_.datasetRoot, options_.recursive);
    if (datasetFiles.empty()) {
        std::cerr << "No dataset files were found under: " << options_.datasetRoot << "\n";
        return 1;
    }

    std::vector<BenchmarkRow> rows;
    auto algorithms = CreateAlgorithms();

    for (const auto& algorithm : algorithms) {
        const auto algorithmName = algorithm->Name();
        const auto keyDir = options_.outputRoot / "keys" / algorithmName;
        const KeyPaths keyPaths{
            keyDir / "public.der",
            keyDir / "private.der"
        };

        utils::Timer keygenTimer;
        algorithm->GenerateKeys(keyPaths);
        const double keygenMs = keygenTimer.ElapsedMs();

        std::cout << "Generated keys for " << algorithmName << " in "
                  << keygenMs << " ms\n";

        for (const auto& file : datasetFiles) {
            BenchmarkRow row;
            row.algorithm = algorithmName;
            row.relativeFile = std::filesystem::relative(file, options_.datasetRoot).generic_string();
            row.inputBytes = std::filesystem::file_size(file);
            row.sizeCategory = GetSizeCategory(row.inputBytes);
            row.keygenMs = keygenMs;

            auto encryptedPath = options_.outputRoot / "artifacts" / algorithmName / row.relativeFile;
            encryptedPath += ".enc";

            auto decryptedPath = options_.outputRoot / "artifacts" / (algorithmName + "_decrypted") / row.relativeFile;

            try {
                utils::Timer encryptTimer;
                algorithm->EncryptFile(file, encryptedPath, keyPaths.publicKey);
                row.encryptMs = encryptTimer.ElapsedMs();

                utils::Timer decryptTimer;
                algorithm->DecryptFile(encryptedPath, decryptedPath, keyPaths.privateKey);
                row.decryptMs = decryptTimer.ElapsedMs();

                row.outputBytes = std::filesystem::file_size(encryptedPath);
                row.decryptedMatch = utils::FilesEqual(file, decryptedPath);
                row.notes = row.decryptedMatch ? "ok" : "decrypted output mismatch";
            } catch (const std::exception& ex) {
                row.decryptedMatch = false;
                row.notes = ex.what();
            }

            rows.push_back(row);

            std::cout << "[" << algorithmName << "] "
                      << row.relativeFile
                      << " enc=" << row.encryptMs
                      << " ms dec=" << row.decryptMs
                      << " ms status=" << row.notes << "\n";
        }
    }

    utils::CsvWriter::WriteRows(options_.csvPath, rows);
    std::cout << "CSV written to: " << options_.csvPath << "\n";
    return 0;
}

} // namespace lk6
'@

$files["src/main.cpp"] = @'
#include <exception>
#include <iostream>

#include "benchmarks/BenchmarkRunner.hpp"

int main(int argc, char* argv[]) {
    lk6::BenchmarkOptions options;

    if (argc >= 2) {
        options.datasetRoot = argv[1];
    }

    if (argc >= 3) {
        options.csvPath = argv[2];
    }

    if (argc >= 4) {
        options.outputRoot = argv[3];
    }

    try {
        lk6::BenchmarkRunner runner(options);
        return runner.RunAll();
    } catch (const std::exception& ex) {
        std::cerr << "Fatal error: " << ex.what() << "\n";
        return 1;
    }
}
'@

$files["scripts/run-build.ps1"] = @'
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
'@

$files["scripts/run-benchmark.ps1"] = @'
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
'@

$files["docs/SETUP-CRYPTOPP.md"] = @'
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
'@

$files["config/benchmark_notes.txt"] = @'
Dataset categories for LK6:
- very_small  : < 10 KB
- small       : 10 KB - 100 KB
- medium      : 100 KB - 1 MB
- large       : 1 MB - 5 MB
- very_large  : > 5 MB

Target file extensions:
- .txt
- .csv
- .json
'@

$files["README.md"] = @'
# LK6 Public Key Crypto Comparison

This project compares four public-key encryption approaches for LK 6:

- RSA
- ECC via ECIES
- ElGamal
- Hybrid RSA-AES

## Architecture

This repository uses modularity harmony:

- Single responsibility
- Low coupling
- High cohesion
- Consistent interfaces
- Benchmark-ready structure

## Stage 2

Run the stage 2 script to generate the Crypto++ integrated files, then install Crypto++ and build the project.

See:

- `docs/SETUP-CRYPTOPP.md`
- `scripts/run-build.ps1`
- `scripts/run-benchmark.ps1`
'@

$files["data/input/very_small/sample_01.txt"] = @'
LK6 sample file.
Replace this folder with your real dataset.
'@

$files["data/input/small/sample_01.csv"] = @'
id,name,amount
1,alpha,100
2,beta,125
3,gamma,150
'@

$files["data/input/medium/sample_01.json"] = @'
{
  "note": "Replace with a larger JSON file for real benchmarking.",
  "dataset": "lk6",
  "version": 1
}
'@

$files["data/input/large/.gitkeep"] = @'
'@

$files["data/input/very_large/.gitkeep"] = @'
'@

$files[".gitignore"] = @'
build/
results/artifacts/
results/keys/
results/csv/*.csv
*.enc
*.der
.vs/
.vscode/
'@

foreach ($entry in $files.GetEnumerator()) {
    Write-ProjectFile -Root $resolvedRoot -RelativePath $entry.Key -Content $entry.Value -BackupRoot $backupRoot
}

Write-Host ""
Write-Host "Stage 2 completed."
Write-Host "Project root : $resolvedRoot"
if ($backupRoot) {
    Write-Host "Backup root  : $backupRoot"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Install Crypto++ or point CRYPTOPP_ROOT to your local install"
Write-Host "2. Run: powershell -ExecutionPolicy Bypass -File .\scripts\run-build.ps1"
Write-Host "3. Run: .\scripts\run-benchmark.ps1"
