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
