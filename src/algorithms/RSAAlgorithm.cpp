#include "algorithms/RSAAlgorithm.hpp"

#include <stdexcept>
#include <string>

#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/osrng.h>
#include <cryptopp/rsa.h>
#include <cryptopp/sha.h>

#include "utils/CryptoChunkIO.hpp"
#include "utils/FileUtils.hpp"

namespace lk6 {

RSAAlgorithm::RSAAlgorithm(int keySizeBits) : keySizeBits_(keySizeBits) {}

AlgorithmId RSAAlgorithm::Id() const {
    return AlgorithmId::RSA;
}

std::string RSAAlgorithm::Name() const {
    return "rsa";
}

void RSAAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    privateKey.GenerateRandomWithKeySize(rng, static_cast<unsigned int>(keySizeBits_));

    CryptoPP::RSA::PublicKey publicKey(privateKey);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    privateKey.Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    publicKey.Save(publicSink);
}

void RSAAlgorithm::EncryptFile(const fs::path& inputFile,
                               const fs::path& outputFile,
                               const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PublicKey publicKey;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    publicKey.Load(publicSource);
    publicKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Encryptor encryptor(publicKey);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);
    const std::string ciphertext = utils::EncryptChunked(rng, encryptor, plaintext);

    utils::WriteBinaryFile(outputFile, ciphertext);
}

void RSAAlgorithm::DecryptFile(const fs::path& inputFile,
                               const fs::path& outputFile,
                               const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    privateKey.Load(privateSource);
    privateKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Decryptor decryptor(privateKey);

    const std::string ciphertext = utils::ReadBinaryFile(inputFile);
    const std::string plaintext = utils::DecryptChunked(rng, decryptor, ciphertext);

    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
