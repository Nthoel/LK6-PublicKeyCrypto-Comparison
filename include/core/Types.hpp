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
