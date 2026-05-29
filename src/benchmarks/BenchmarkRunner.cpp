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
