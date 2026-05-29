#pragma once

#include "core/Types.hpp"

namespace lk6 {

class IEncryptionScheme {
public:
    virtual ~IEncryptionScheme() = default;

    virtual AlgorithmId Id() const = 0;
    virtual std::string Name() const = 0;

    virtual void GenerateKeys(const KeyPaths& paths) = 0;
    virtual void EncryptFile(const fs::path& inputFile,
                             const fs::path& outputFile,
                             const fs::path& publicKeyFile) = 0;
    virtual void DecryptFile(const fs::path& inputFile,
                             const fs::path& outputFile,
                             const fs::path& privateKeyFile) = 0;
};

} // namespace lk6
