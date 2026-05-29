#pragma once

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

class HybridRSAAESAlgorithm final : public IEncryptionScheme {
public:
    explicit HybridRSAAESAlgorithm(int rsaKeySizeBits = 3072);

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
    int rsaKeySizeBits_;
};

} // namespace lk6
