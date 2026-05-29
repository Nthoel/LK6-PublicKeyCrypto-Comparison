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
    if ($parent -and -not (Test-Path $parent)) {
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
    Write-Host ("[OK] " + $RelativePath) -ForegroundColor Green
}

$resolvedRoot = (Resolve-Path $ProjectRoot).Path
$backupRoot = $null

if (-not $NoBackup) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupRoot = Join-Path $resolvedRoot (".backup\stage3_" + $timestamp)
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

$dirs = @(
    "docs",
    "include\analysis",
    "include\benchmarks",
    "results\csv",
    "scripts",
    "src\analysis",
    "src\benchmarks"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $resolvedRoot $dir) -Force | Out-Null
}

$files = @{}

$files["include/analysis/ByteMetrics.hpp"] = @'
#pragma once

#include <cstdint>
#include <string>

namespace lk6::analysis {

double BytesToKB(std::uintmax_t bytes);
double ComputeShannonEntropy(const std::string& bytes);
double ComputePearsonCorrelation(const std::string& lhs, const std::string& rhs);
std::size_t CountDifferentBits(const std::string& lhs, const std::string& rhs);
std::size_t TotalComparedBits(const std::string& lhs, const std::string& rhs);
double ComputeAvalanchePercent(const std::string& lhs, const std::string& rhs);
std::string MutatePlaintextSingleBit(const std::string& original);

} // namespace lk6::analysis
'@

$files["src/analysis/ByteMetrics.cpp"] = @'
#include "analysis/ByteMetrics.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>

namespace lk6::analysis {

namespace {

std::size_t PopcountByte(unsigned char value) {
    std::size_t count = 0;
    while (value != 0U) {
        count += static_cast<std::size_t>(value & 1U);
        value >>= 1U;
    }
    return count;
}

} // namespace

double BytesToKB(std::uintmax_t bytes) {
    return static_cast<double>(bytes) / 1024.0;
}

double ComputeShannonEntropy(const std::string& bytes) {
    if (bytes.empty()) {
        return 0.0;
    }

    std::array<std::uint64_t, 256> frequency{};
    for (unsigned char value : bytes) {
        ++frequency[value];
    }

    const double total = static_cast<double>(bytes.size());
    double entropy = 0.0;

    for (const auto count : frequency) {
        if (count == 0U) {
            continue;
        }

        const double probability = static_cast<double>(count) / total;
        entropy -= probability * std::log2(probability);
    }

    return entropy;
}

double ComputePearsonCorrelation(const std::string& lhs, const std::string& rhs) {
    const auto sampleSize = std::min(lhs.size(), rhs.size());
    if (sampleSize < 2U) {
        return 0.0;
    }

    double sumX = 0.0;
    double sumY = 0.0;

    for (std::size_t i = 0; i < sampleSize; ++i) {
        sumX += static_cast<unsigned char>(lhs[i]);
        sumY += static_cast<unsigned char>(rhs[i]);
    }

    const double meanX = sumX / static_cast<double>(sampleSize);
    const double meanY = sumY / static_cast<double>(sampleSize);

    double numerator = 0.0;
    double denomX = 0.0;
    double denomY = 0.0;

    for (std::size_t i = 0; i < sampleSize; ++i) {
        const double x = static_cast<unsigned char>(lhs[i]) - meanX;
        const double y = static_cast<unsigned char>(rhs[i]) - meanY;
        numerator += x * y;
        denomX += x * x;
        denomY += y * y;
    }

    const double denominator = std::sqrt(denomX * denomY);
    if (denominator <= std::numeric_limits<double>::epsilon()) {
        return 0.0;
    }

    return numerator / denominator;
}

std::size_t CountDifferentBits(const std::string& lhs, const std::string& rhs) {
    const auto shared = std::min(lhs.size(), rhs.size());
    std::size_t changedBits = 0;

    for (std::size_t i = 0; i < shared; ++i) {
        const auto left = static_cast<unsigned char>(lhs[i]);
        const auto right = static_cast<unsigned char>(rhs[i]);
        changedBits += PopcountByte(static_cast<unsigned char>(left ^ right));
    }

    const auto extraBytes = (lhs.size() > rhs.size())
        ? (lhs.size() - rhs.size())
        : (rhs.size() - lhs.size());

    changedBits += extraBytes * 8U;
    return changedBits;
}

std::size_t TotalComparedBits(const std::string& lhs, const std::string& rhs) {
    return std::max(lhs.size(), rhs.size()) * 8U;
}

double ComputeAvalanchePercent(const std::string& lhs, const std::string& rhs) {
    const auto totalBits = TotalComparedBits(lhs, rhs);
    if (totalBits == 0U) {
        return 0.0;
    }

    const auto changedBits = CountDifferentBits(lhs, rhs);
    return (static_cast<double>(changedBits) / static_cast<double>(totalBits)) * 100.0;
}

std::string MutatePlaintextSingleBit(const std::string& original) {
    if (original.empty()) {
        return std::string(1, static_cast<char>(0x01));
    }

    std::string mutated = original;
    mutated[0] = static_cast<char>(static_cast<unsigned char>(mutated[0]) ^ 0x01U);
    return mutated;
}

} // namespace lk6::analysis
'@

$files["include/analysis/WordReportWriter.hpp"] = @'
#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace lk6::analysis {

struct AlgorithmMetricCell {
    std::uintmax_t cipherBytes = 0;
    double encryptMs = 0.0;
    double decryptMs = 0.0;
    double cipherEntropy = 0.0;
    double plainCipherCorrelation = 0.0;
    std::size_t avalancheChangedBits = 0;
    std::size_t avalancheTotalBits = 0;
    double avalanchePercent = 0.0;
    bool completed = false;
    bool decryptOk = false;
    std::string notes;
};

struct WordTaskRow {
    std::size_t id = 0;
    std::string relativeFile;
    std::string sizeCategory;
    std::uintmax_t plaintextBytes = 0;
    double plaintextEntropy = 0.0;
    double rsaVsEccCipherCorrelation = 0.0;
    AlgorithmMetricCell rsa;
    AlgorithmMetricCell elgamal;
    AlgorithmMetricCell ecc;
    AlgorithmMetricCell rsaAes;
};

struct AlgorithmSummaryRow {
    std::string algorithm;
    std::size_t sampleCount = 0;
    std::size_t successCount = 0;
    double avgCipherKB = 0.0;
    double avgOverheadRatio = 0.0;
    double avgEncryptMs = 0.0;
    double avgDecryptMs = 0.0;
    double avgCipherEntropy = 0.0;
    double avgPlainCipherCorrelation = 0.0;
    double avgAvalanchePercent = 0.0;
};

class WordReportWriter {
public:
    static void WriteAll(const std::filesystem::path& csvRoot,
                         const std::vector<WordTaskRow>& rows,
                         const std::vector<AlgorithmSummaryRow>& summaryRows);
};

} // namespace lk6::analysis
'@

$files["src/analysis/WordReportWriter.cpp"] = @'
#include "analysis/WordReportWriter.hpp"

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <stdexcept>
#include <string>
#include <vector>

#include "analysis/ByteMetrics.hpp"

namespace lk6::analysis {

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

void EnsureParent(const std::filesystem::path& path) {
    std::filesystem::create_directories(path.parent_path());
}

double SafeOverheadRatio(std::uintmax_t plainBytes, std::uintmax_t cipherBytes) {
    if (plainBytes == 0U) {
        return 0.0;
    }
    return static_cast<double>(cipherBytes) / static_cast<double>(plainBytes);
}

std::string BuildCombinedNotes(const WordTaskRow& row) {
    std::string notes;
    auto append = [&](const std::string& prefix, const std::string& value) {
        if (value.empty()) {
            return;
        }
        if (!notes.empty()) {
            notes += " | ";
        }
        notes += prefix + ": " + value;
    };

    append("RSA", row.rsa.notes);
    append("ElGamal", row.elgamal.notes);
    append("ECC", row.ecc.notes);
    append("RSA-AES", row.rsaAes.notes);

    return notes;
}

void WriteTask4(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,plaintext_kb,rsa_kb,elgamal_kb,ecc_kb,rsa_aes_kb,"
           "rsa_overhead_ratio,elgamal_overhead_ratio,ecc_overhead_ratio,rsa_aes_overhead_ratio\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << BytesToKB(row.plaintextBytes) << ","
            << BytesToKB(row.rsa.cipherBytes) << ","
            << BytesToKB(row.elgamal.cipherBytes) << ","
            << BytesToKB(row.ecc.cipherBytes) << ","
            << BytesToKB(row.rsaAes.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.rsa.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.elgamal.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.ecc.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.rsaAes.cipherBytes) << "\n";
    }
}

void WriteTask5(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,"
           "rsa_encrypt_ms,elgamal_encrypt_ms,ecc_encrypt_ms,rsa_aes_encrypt_ms,"
           "rsa_decrypt_ms,elgamal_decrypt_ms,ecc_decrypt_ms,rsa_aes_decrypt_ms\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.rsa.encryptMs << ","
            << row.elgamal.encryptMs << ","
            << row.ecc.encryptMs << ","
            << row.rsaAes.encryptMs << ","
            << row.rsa.decryptMs << ","
            << row.elgamal.decryptMs << ","
            << row.ecc.decryptMs << ","
            << row.rsaAes.decryptMs << "\n";
    }
}

void WriteTask6(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,plaintext_entropy_bit,"
           "rsa_entropy_bit,elgamal_entropy_bit,ecc_entropy_bit,rsa_aes_entropy_bit\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.plaintextEntropy << ","
            << row.rsa.cipherEntropy << ","
            << row.elgamal.cipherEntropy << ","
            << row.ecc.cipherEntropy << ","
            << row.rsaAes.cipherEntropy << "\n";
    }
}

void WriteTask7(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,"
           "rsa_plain_vs_cipher,elgamal_plain_vs_cipher,ecc_plain_vs_cipher,rsa_aes_plain_vs_cipher,"
           "rsa_vs_ecc_cipher\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.rsa.plainCipherCorrelation << ","
            << row.elgamal.plainCipherCorrelation << ","
            << row.ecc.plainCipherCorrelation << ","
            << row.rsaAes.plainCipherCorrelation << ","
            << row.rsaVsEccCipherCorrelation << "\n";
    }
}

void WriteTask8(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,"
           "rsa_changed_bits,rsa_total_bits,rsa_avalanche_percent,"
           "elgamal_changed_bits,elgamal_total_bits,elgamal_avalanche_percent,"
           "ecc_changed_bits,ecc_total_bits,ecc_avalanche_percent,"
           "rsa_aes_changed_bits,rsa_aes_total_bits,rsa_aes_avalanche_percent,notes\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.rsa.avalancheChangedBits << ","
            << row.rsa.avalancheTotalBits << ","
            << row.rsa.avalanchePercent << ","
            << row.elgamal.avalancheChangedBits << ","
            << row.elgamal.avalancheTotalBits << ","
            << row.elgamal.avalanchePercent << ","
            << row.ecc.avalancheChangedBits << ","
            << row.ecc.avalancheTotalBits << ","
            << row.ecc.avalanchePercent << ","
            << row.rsaAes.avalancheChangedBits << ","
            << row.rsaAes.avalancheTotalBits << ","
            << row.rsaAes.avalanchePercent << ","
            << EscapeCsv(BuildCombinedNotes(row)) << "\n";
    }
}

void WriteSummary(const std::filesystem::path& path, const std::vector<AlgorithmSummaryRow>& summaryRows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "algorithm,sample_count,success_count,success_rate_percent,avg_cipher_kb,avg_overhead_ratio,"
           "avg_encrypt_ms,avg_decrypt_ms,avg_cipher_entropy,avg_plain_cipher_correlation,avg_avalanche_percent\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : summaryRows) {
        const double successRate = row.sampleCount == 0U
            ? 0.0
            : (static_cast<double>(row.successCount) / static_cast<double>(row.sampleCount)) * 100.0;

        out << EscapeCsv(row.algorithm) << ","
            << row.sampleCount << ","
            << row.successCount << ","
            << successRate << ","
            << row.avgCipherKB << ","
            << row.avgOverheadRatio << ","
            << row.avgEncryptMs << ","
            << row.avgDecryptMs << ","
            << row.avgCipherEntropy << ","
            << row.avgPlainCipherCorrelation << ","
            << row.avgAvalanchePercent << "\n";
    }
}

} // namespace

void WordReportWriter::WriteAll(const std::filesystem::path& csvRoot,
                                const std::vector<WordTaskRow>& rows,
                                const std::vector<AlgorithmSummaryRow>& summaryRows) {
    std::filesystem::create_directories(csvRoot);

    WriteTask4(csvRoot / "lk6_task4_file_size.csv", rows);
    WriteTask5(csvRoot / "lk6_task5_time.csv", rows);
    WriteTask6(csvRoot / "lk6_task6_entropy.csv", rows);
    WriteTask7(csvRoot / "lk6_task7_correlation.csv", rows);
    WriteTask8(csvRoot / "lk6_task8_avalanche.csv", rows);
    WriteSummary(csvRoot / "lk6_summary_average.csv", summaryRows);
}

} // namespace lk6::analysis
'@

$files["include/benchmarks/BenchmarkRunner.hpp"] = @'
#pragma once

#include <cstdint>
#include <string>

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

$files["src/benchmarks/BenchmarkRunner.cpp"] = @'
#include "benchmarks/BenchmarkRunner.hpp"

#include <exception>
#include <filesystem>
#include <iostream>
#include <map>
#include <memory>
#include <utility>
#include <vector>

#include "analysis/ByteMetrics.hpp"
#include "analysis/WordReportWriter.hpp"
#include "core/AlgorithmFactory.hpp"
#include "core/IEncryptionScheme.hpp"
#include "utils/CsvWriter.hpp"
#include "utils/FileUtils.hpp"
#include "utils/Timer.hpp"

namespace lk6 {

namespace fs = std::filesystem;

namespace {

using analysis::AlgorithmMetricCell;
using analysis::AlgorithmSummaryRow;
using analysis::WordTaskRow;

AlgorithmMetricCell& SelectCell(WordTaskRow& row, AlgorithmId id) {
    switch (id) {
        case AlgorithmId::RSA:
            return row.rsa;
        case AlgorithmId::ECIES:
            return row.ecc;
        case AlgorithmId::ElGamal:
            return row.elgamal;
        case AlgorithmId::HybridRSA_AES:
            return row.rsaAes;
        default:
            return row.rsa;
    }
}

const AlgorithmMetricCell& SelectCell(const WordTaskRow& row, AlgorithmId id) {
    switch (id) {
        case AlgorithmId::RSA:
            return row.rsa;
        case AlgorithmId::ECIES:
            return row.ecc;
        case AlgorithmId::ElGamal:
            return row.elgamal;
        case AlgorithmId::HybridRSA_AES:
            return row.rsaAes;
        default:
            return row.rsa;
    }
}

std::string DisplayName(AlgorithmId id) {
    switch (id) {
        case AlgorithmId::RSA:
            return "RSA";
        case AlgorithmId::ECIES:
            return "ECC";
        case AlgorithmId::ElGamal:
            return "ElGamal";
        case AlgorithmId::HybridRSA_AES:
            return "RSA-AES";
        default:
            return "Unknown";
    }
}

std::vector<AlgorithmSummaryRow> BuildSummary(const std::vector<WordTaskRow>& rows) {
    const std::vector<AlgorithmId> ids{
        AlgorithmId::RSA,
        AlgorithmId::ElGamal,
        AlgorithmId::ECIES,
        AlgorithmId::HybridRSA_AES
    };

    std::vector<AlgorithmSummaryRow> summary;

    for (const auto id : ids) {
        AlgorithmSummaryRow row;
        row.algorithm = DisplayName(id);
        row.sampleCount = rows.size();

        std::size_t completedCount = 0;
        std::uintmax_t totalCipherBytes = 0;
        double totalOverheadRatio = 0.0;
        double totalEncryptMs = 0.0;
        double totalDecryptMs = 0.0;
        double totalEntropy = 0.0;
        double totalCorrelation = 0.0;
        double totalAvalanche = 0.0;

        for (const auto& taskRow : rows) {
            const auto& cell = SelectCell(taskRow, id);
            if (!cell.completed) {
                continue;
            }

            ++completedCount;
            if (cell.decryptOk) {
                ++row.successCount;
            }

            totalCipherBytes += cell.cipherBytes;
            totalEncryptMs += cell.encryptMs;
            totalDecryptMs += cell.decryptMs;
            totalEntropy += cell.cipherEntropy;
            totalCorrelation += cell.plainCipherCorrelation;
            totalAvalanche += cell.avalanchePercent;

            if (taskRow.plaintextBytes != 0U) {
                totalOverheadRatio += static_cast<double>(cell.cipherBytes) /
                                      static_cast<double>(taskRow.plaintextBytes);
            }
        }

        if (completedCount != 0U) {
            row.avgCipherKB = analysis::BytesToKB(totalCipherBytes / completedCount);
            row.avgOverheadRatio = totalOverheadRatio / static_cast<double>(completedCount);
            row.avgEncryptMs = totalEncryptMs / static_cast<double>(completedCount);
            row.avgDecryptMs = totalDecryptMs / static_cast<double>(completedCount);
            row.avgCipherEntropy = totalEntropy / static_cast<double>(completedCount);
            row.avgPlainCipherCorrelation = totalCorrelation / static_cast<double>(completedCount);
            row.avgAvalanchePercent = totalAvalanche / static_cast<double>(completedCount);
        }

        summary.push_back(row);
    }

    return summary;
}

} // namespace

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

    fs::create_directories(options_.outputRoot / "csv");

    std::vector<BenchmarkRow> rawRows;
    std::vector<analysis::WordTaskRow> wordRows;
    wordRows.reserve(datasetFiles.size());

    std::map<std::string, std::size_t> rowIndexByRelative;
    std::map<std::string, std::string> plaintextCache;
    std::map<std::string, std::map<AlgorithmId, std::string>> ciphertextCache;

    for (std::size_t i = 0; i < datasetFiles.size(); ++i) {
        const auto& file = datasetFiles[i];
        const auto relativeFile = fs::relative(file, options_.datasetRoot).generic_string();
        const auto bytes = fs::file_size(file);
        const auto plaintext = utils::ReadBinaryFile(file);

        analysis::WordTaskRow row;
        row.id = i + 1U;
        row.relativeFile = relativeFile;
        row.sizeCategory = GetSizeCategory(bytes);
        row.plaintextBytes = bytes;
        row.plaintextEntropy = analysis::ComputeShannonEntropy(plaintext);

        rowIndexByRelative[relativeFile] = i;
        plaintextCache[relativeFile] = plaintext;
        wordRows.push_back(std::move(row));
    }

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

        std::cout << "Generated keys for " << algorithmName
                  << " in " << keygenMs << " ms\n";

        for (const auto& file : datasetFiles) {
            BenchmarkRow rawRow;
            rawRow.algorithm = algorithmName;
            rawRow.relativeFile = fs::relative(file, options_.datasetRoot).generic_string();
            rawRow.inputBytes = fs::file_size(file);
            rawRow.sizeCategory = GetSizeCategory(rawRow.inputBytes);
            rawRow.keygenMs = keygenMs;

            auto& wordRow = wordRows.at(rowIndexByRelative.at(rawRow.relativeFile));
            auto& cell = SelectCell(wordRow, algorithm->Id());

            const auto encryptedPath = options_.outputRoot / "artifacts" / algorithmName /
                                       (rawRow.relativeFile + ".enc");
            const auto decryptedPath = options_.outputRoot / "artifacts" /
                                       (algorithmName + "_decrypted") / rawRow.relativeFile;
            const auto mutatedInputPath = options_.outputRoot / "artifacts" / "_mutated_input" /
                                          rawRow.relativeFile;
            const auto mutatedEncryptedPath = options_.outputRoot / "artifacts" /
                                              (algorithmName + "_mutated") /
                                              (rawRow.relativeFile + ".enc");

            try {
                utils::Timer encryptTimer;
                algorithm->EncryptFile(file, encryptedPath, keyPaths.publicKey);
                rawRow.encryptMs = encryptTimer.ElapsedMs();

                utils::Timer decryptTimer;
                algorithm->DecryptFile(encryptedPath, decryptedPath, keyPaths.privateKey);
                rawRow.decryptMs = decryptTimer.ElapsedMs();

                rawRow.outputBytes = fs::file_size(encryptedPath);
                rawRow.decryptedMatch = utils::FilesEqual(file, decryptedPath);
                rawRow.notes = rawRow.decryptedMatch ? "ok" : "decrypted output mismatch";

                const auto cipherBytes = utils::ReadBinaryFile(encryptedPath);
                ciphertextCache[rawRow.relativeFile][algorithm->Id()] = cipherBytes;

                cell.cipherBytes = rawRow.outputBytes;
                cell.encryptMs = rawRow.encryptMs;
                cell.decryptMs = rawRow.decryptMs;
                cell.decryptOk = rawRow.decryptedMatch;
                cell.completed = true;
                cell.cipherEntropy = analysis::ComputeShannonEntropy(cipherBytes);
                cell.plainCipherCorrelation = analysis::ComputePearsonCorrelation(
                    plaintextCache.at(rawRow.relativeFile),
                    cipherBytes
                );

                const auto mutatedPlaintext =
                    analysis::MutatePlaintextSingleBit(plaintextCache.at(rawRow.relativeFile));
                utils::WriteBinaryFile(mutatedInputPath, mutatedPlaintext);

                algorithm->EncryptFile(mutatedInputPath, mutatedEncryptedPath, keyPaths.publicKey);
                const auto mutatedCipherBytes = utils::ReadBinaryFile(mutatedEncryptedPath);

                cell.avalancheChangedBits = analysis::CountDifferentBits(cipherBytes, mutatedCipherBytes);
                cell.avalancheTotalBits = analysis::TotalComparedBits(cipherBytes, mutatedCipherBytes);
                cell.avalanchePercent = analysis::ComputeAvalanchePercent(cipherBytes, mutatedCipherBytes);
                cell.notes =
                    "direct ciphertext comparison; interpret carefully for probabilistic encryption";

                rawRow.notes = rawRow.notes + " | avalanche=probabilistic-ciphertext-compare";
            } catch (const std::exception& ex) {
                rawRow.decryptedMatch = false;
                rawRow.notes = ex.what();
                cell.notes = ex.what();
                cell.completed = false;
            }

            rawRows.push_back(rawRow);

            std::cout << "[" << algorithmName << "] "
                      << rawRow.relativeFile
                      << " enc=" << rawRow.encryptMs
                      << " ms dec=" << rawRow.decryptMs
                      << " ms status=" << rawRow.notes << "\n";
        }
    }

    for (auto& row : wordRows) {
        const auto cacheIt = ciphertextCache.find(row.relativeFile);
        if (cacheIt == ciphertextCache.end()) {
            continue;
        }

        const auto rsaIt = cacheIt->second.find(AlgorithmId::RSA);
        const auto eccIt = cacheIt->second.find(AlgorithmId::ECIES);

        if (rsaIt != cacheIt->second.end() && eccIt != cacheIt->second.end()) {
            row.rsaVsEccCipherCorrelation =
                analysis::ComputePearsonCorrelation(rsaIt->second, eccIt->second);
        }
    }

    utils::CsvWriter::WriteRows(options_.csvPath, rawRows);

    const auto summaryRows = BuildSummary(wordRows);
    analysis::WordReportWriter::WriteAll(options_.outputRoot / "csv", wordRows, summaryRows);

    std::cout << "CSV raw benchmark written to: " << options_.csvPath << "\n";
    std::cout << "Word-ready CSV files written under: " << (options_.outputRoot / "csv") << "\n";
    std::cout << "Generated files:\n"
              << "  - lk6_task4_file_size.csv\n"
              << "  - lk6_task5_time.csv\n"
              << "  - lk6_task6_entropy.csv\n"
              << "  - lk6_task7_correlation.csv\n"
              << "  - lk6_task8_avalanche.csv\n"
              << "  - lk6_summary_average.csv\n";

    return 0;
}

} // namespace lk6
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
    src/analysis/ByteMetrics.cpp
    src/analysis/WordReportWriter.cpp
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

$files["scripts/run-lk6-word-report.ps1"] = @'
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
'@

$files["docs/WORD-OUTPUT-MAPPING.md"] = @'
# LK6 Word Output Mapping

Script tahap ini menambahkan output CSV yang langsung dipakai untuk mengisi tabel Word LK6.

## File hasil utama

Folder output:
- `results/csv/lk6_task4_file_size.csv`
- `results/csv/lk6_task5_time.csv`
- `results/csv/lk6_task6_entropy.csv`
- `results/csv/lk6_task7_correlation.csv`
- `results/csv/lk6_task8_avalanche.csv`
- `results/csv/lk6_summary_average.csv`

## Pemetaan ke tugas Word

### Tugas 4 — Evaluasi Ukuran File
Gunakan:
- `lk6_task4_file_size.csv`

Kolom utama:
- `plaintext_kb`
- `rsa_kb`
- `elgamal_kb`
- `ecc_kb`
- `rsa_aes_kb`

Kolom tambahan:
- `*_overhead_ratio`

### Tugas 5 — Evaluasi Waktu Proses
Gunakan:
- `lk6_task5_time.csv`

Kolom:
- `*_encrypt_ms`
- `*_decrypt_ms`

### Tugas 6 — Evaluasi Entropi
Gunakan:
- `lk6_task6_entropy.csv`

Kolom:
- `plaintext_entropy_bit`
- `rsa_entropy_bit`
- `elgamal_entropy_bit`
- `ecc_entropy_bit`
- `rsa_aes_entropy_bit`

### Tugas 7 — Evaluasi Korelasi
Gunakan:
- `lk6_task7_correlation.csv`

Kolom:
- `rsa_plain_vs_cipher`
- `elgamal_plain_vs_cipher`
- `ecc_plain_vs_cipher`
- `rsa_aes_plain_vs_cipher`
- `rsa_vs_ecc_cipher`

### Tugas 8 — Evaluasi Avalanche Effect
Gunakan:
- `lk6_task8_avalanche.csv`

Kolom:
- `*_changed_bits`
- `*_total_bits`
- `*_avalanche_percent`

## Catatan metodologi
Pengukuran avalanche pada RSA, ElGamal, ECIES, dan Hybrid RSA-AES dilakukan dengan
membandingkan dua ciphertext hasil enkripsi plainteks asli dan plainteks yang dimutasi 1 bit.

Karena algoritma public-key modern bersifat probabilistik, nilai avalanche ini berguna sebagai
indikator praktis untuk tugas LK, tetapi harus diberi catatan pada pembahasan bahwa interpretasinya
tidak sesederhana block cipher deterministik.

## Jalankan pipeline
Gunakan:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-lk6-word-report.ps1 -DatasetRoot ".\data\input"
```
'@

$files["docs/STAGE3-LK6-NOTES.md"] = @'
# Stage 3 Notes

Tahap ini fokus pada keluaran hasil eksperimen yang rapi untuk laporan LK6.

## Yang ditambahkan
- modul analisis byte:
  - Shannon entropy
  - Pearson correlation
  - bit difference
  - avalanche effect
- writer CSV khusus untuk tabel Word LK6
- benchmark runner yang menghasilkan:
  - benchmark raw
  - task 4
  - task 5
  - task 6
  - task 7
  - task 8
  - summary average

## Saran penggunaan
1. Pastikan dataset final sudah berada di `data/input`
2. Build project
3. Jalankan `scripts/run-lk6-word-report.ps1`
4. Isi tabel Word dari file CSV hasil
'@

foreach ($key in $files.Keys) {
    Write-ProjectFile -Root $resolvedRoot -RelativePath $key -Content $files[$key] -BackupRoot $backupRoot
}

Write-Host ""
Write-Host "Stage 3 completed." -ForegroundColor Cyan
Write-Host ("Project root : " + $resolvedRoot)
if ($backupRoot) {
    Write-Host ("Backup root  : " + $backupRoot)
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Save and close any open editor tabs for files that were overwritten."
Write-Host "2. Rebuild the project:"
Write-Host "   powershell -ExecutionPolicy Bypass -File .\scripts\run-build.ps1 -Config Release -CryptoPPRoot $env:CRYPTOPP_ROOT"
Write-Host "3. Run the word-report pipeline:"
Write-Host "   powershell -ExecutionPolicy Bypass -File .\scripts\run-lk6-word-report.ps1 -DatasetRoot .\data\input"
Write-Host "4. Fill the LK6 Word tables using CSV files under results\csv"
