#pragma once

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

class RSAAlgorithm final : public IEncryptionScheme {
public:
    explicit RSAAlgorithm(int keySizeBits = 3072);

    AlgorithmId Id() const override;
    std::string Name() const override;

    void GenerateKeys(const KeyPaths& paths) override;
    void EncryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& publicKeyFile) override;
    void DecryptFile(const fs::path& inputFile,
                     const fs::path& outputFile,
                     const fs::path& privateKeyFile) override;

private:
    int keySizeBits_;
};

} // namespace lk6
