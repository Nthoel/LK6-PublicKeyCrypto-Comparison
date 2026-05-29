#include "benchmarks/BenchmarkRunner.hpp"
#include "benchmarks/DatasetScanner.hpp"
#include "core/CryptoFactory.hpp"
#include "utils/FileUtil.hpp"
#include "utils/Timer.hpp"
#include <exception>

namespace lk6::benchmarks {

std::vector<lk6::core::BenchmarkResult> BenchmarkRunner::Run(const lk6::core::AppConfig& config) {
    std::vector<lk6::core::BenchmarkResult> results;
    const auto dataset = ScanDataset(config.datasetRoot);

    for (const auto& algorithmName : config.enabledAlgorithms) {
        auto scheme = lk6::core::CreateScheme(algorithmName);

        lk6::utils::Timer timer;
        timer.Start();
        scheme->GenerateKeys();
        const double keyGenMs = timer.StopMilliseconds();

        for (const auto& file : dataset) {
            lk6::core::BenchmarkResult row{};
            row.algorithm = algorithmName;
            row.fileName = file.fileName;
            row.fileCategory = file.category;

            try {
                const auto plaintext = lk6::utils::ReadBinaryFile(file.filePath);
                row.plainBytes = plaintext.size();
                row.keyGenMs = keyGenMs;

                timer.Start();
                const auto encrypted = scheme->Encrypt(plaintext);
                row.encryptMs = timer.StopMilliseconds();
                row.cipherBytes = encrypted.ciphertext.size() + encrypted.metadata.size();

                timer.Start();
                const auto decrypted = scheme->Decrypt(encrypted);
                row.decryptMs = timer.StopMilliseconds();

                row.success = (plaintext == decrypted);
                row.notes = row.success ? "OK" : "Mismatch after decrypt";
            } catch (const std::exception& ex) {
                row.success = false;
                row.notes = ex.what();
            }

            results.push_back(row);
        }
    }

    return results;
}

} // namespace lk6::benchmarks
