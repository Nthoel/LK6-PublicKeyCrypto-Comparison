#pragma once
#include <string>
#include <vector>
#include <cstdint>
#include "core/CryptoTypes.hpp"

namespace lk6::core {

class IAsymmetricScheme {
public:
    virtual ~IAsymmetricScheme() = default;

    virtual std::string Name() const = 0;
    virtual void GenerateKeys() = 0;
    virtual KeyInfo GetKeyInfo() const = 0;

    virtual CryptoOutput Encrypt(const std::vector<std::uint8_t>& plaintext) = 0;
    virtual std::vector<std::uint8_t> Decrypt(const CryptoOutput& input) = 0;
};

} // namespace lk6::core
