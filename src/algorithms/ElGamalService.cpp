#include "algorithms/ElGamalService.hpp"
#include <stdexcept>

namespace lk6::algorithms {

std::string ElGamalService::Name() const {
    return "ElGamal";
}

void ElGamalService::GenerateKeys() {
    // TODO: Implement key generation using Crypto++ or OpenSSL
    // Pastikan domain parameter dan random generator aman.
    keyInfo_.algorithm = "ElGamal";
}

lk6::core::KeyInfo ElGamalService::GetKeyInfo() const {
    return keyInfo_;
}

lk6::core::CryptoOutput ElGamalService::Encrypt(const std::vector<std::uint8_t>& plaintext) {
    // TODO: Implement encryption
    // Placeholder return so project skeleton can compile after real implementation is added.
    return { plaintext, {} };
}

std::vector<std::uint8_t> ElGamalService::Decrypt(const lk6::core::CryptoOutput& input) {
    // TODO: Implement decryption
    return input.ciphertext;
}

} // namespace lk6::algorithms
