#include "algorithms/HybridRSAAESService.hpp"
#include <stdexcept>

namespace lk6::algorithms {

std::string HybridRSAAESService::Name() const {
    return "HybridRSAAES";
}

void HybridRSAAESService::GenerateKeys() {
    // TODO: Implement key generation using Crypto++ or OpenSSL
    // Gunakan AES-GCM/EAX untuk integritas dan RSA untuk membungkus session key.
    keyInfo_.algorithm = "HybridRSAAES";
}

lk6::core::KeyInfo HybridRSAAESService::GetKeyInfo() const {
    return keyInfo_;
}

lk6::core::CryptoOutput HybridRSAAESService::Encrypt(const std::vector<std::uint8_t>& plaintext) {
    // TODO: Implement encryption
    // Placeholder return so project skeleton can compile after real implementation is added.
    return { plaintext, {} };
}

std::vector<std::uint8_t> HybridRSAAESService::Decrypt(const lk6::core::CryptoOutput& input) {
    // TODO: Implement decryption
    return input.ciphertext;
}

} // namespace lk6::algorithms
