#pragma once
#include "core/IAsymmetricScheme.hpp"

namespace lk6::algorithms {

class RSAService : public lk6::core::IAsymmetricScheme {
public:
    std::string Name() const override;
    void GenerateKeys() override;
    lk6::core::KeyInfo GetKeyInfo() const override;
    lk6::core::CryptoOutput Encrypt(const std::vector<std::uint8_t>& plaintext) override;
    std::vector<std::uint8_t> Decrypt(const lk6::core::CryptoOutput& input) override;

private:
    lk6::core::KeyInfo keyInfo_{};
};

} // namespace lk6::algorithms
