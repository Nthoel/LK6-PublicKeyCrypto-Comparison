#include "algorithms/RSAService.hpp"
#include <stdexcept>

namespace lk6::algorithms {

std::string RSAService::Name() const {
    return "RSA";
}

void RSAService::GenerateKeys() {
    // TODO: Implement key generation using Crypto++ or OpenSSL
    // Gunakan RSAES-OAEP bila memungkinkan.
    keyInfo_.algorithm = "RSA";
}

lk6::core::KeyInfo RSAService::GetKeyInfo() const {
    return keyInfo_;
}

lk6::core::CryptoOutput RSAService::Encrypt(const std::vector<std::uint8_t>& plaintext) {
    // TODO: Implement encryption
    // Placeholder return so project skeleton can compile after real implementation is added.
    return { plaintext, {} };
}

std::vector<std::uint8_t> RSAService::Decrypt(const lk6::core::CryptoOutput& input) {
    // TODO: Implement decryption
    return input.ciphertext;
}

} // namespace lk6::algorithms
