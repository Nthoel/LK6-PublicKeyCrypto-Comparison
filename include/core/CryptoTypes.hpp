#pragma once
#include <string>
#include <vector>
#include <cstdint>

namespace lk6::core {

struct KeyInfo {
    std::string algorithm;
    std::size_t publicKeyBytes = 0;
    std::size_t privateKeyBytes = 0;
};

struct CryptoOutput {
    std::vector<std::uint8_t> ciphertext;
    std::vector<std::uint8_t> metadata;
};

struct BenchmarkResult {
    std::string algorithm;
    std::string fileName;
    std::string fileCategory;
    std::size_t plainBytes = 0;
    std::size_t cipherBytes = 0;
    double keyGenMs = 0.0;
    double encryptMs = 0.0;
    double decryptMs = 0.0;
    bool success = false;
    std::string notes;
};

} // namespace lk6::core
