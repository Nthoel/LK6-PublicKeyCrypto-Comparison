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
