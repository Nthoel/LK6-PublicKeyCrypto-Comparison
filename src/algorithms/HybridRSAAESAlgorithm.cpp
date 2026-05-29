#include "algorithms/HybridRSAAESAlgorithm.hpp"

#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <string>

#include <cryptopp/aes.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/gcm.h>
#include <cryptopp/osrng.h>
#include <cryptopp/rsa.h>
#include <cryptopp/sha.h>

#include "utils/CryptoChunkIO.hpp"
#include "utils/FileUtils.hpp"

namespace lk6 {

namespace {
constexpr std::size_t kAesKeyBytes = 32;
constexpr std::size_t kIvBytes = 12;
constexpr char kMagic[] = "LK6H1";

std::string EncryptAesGcm(const CryptoPP::SecByteBlock& key,
                          const CryptoPP::SecByteBlock& iv,
                          const std::string& plaintext) {
    CryptoPP::GCM<CryptoPP::AES>::Encryption encryption;
    encryption.SetKeyWithIV(key, key.size(), iv, iv.size());

    std::string ciphertext;
    CryptoPP::StringSource ss(
        plaintext,
        true,
        new CryptoPP::AuthenticatedEncryptionFilter(
            encryption,
            new CryptoPP::StringSink(ciphertext)));

    return ciphertext;
}

std::string DecryptAesGcm(const CryptoPP::SecByteBlock& key,
                          const CryptoPP::SecByteBlock& iv,
                          const std::string& ciphertext) {
    CryptoPP::GCM<CryptoPP::AES>::Decryption decryption;
    decryption.SetKeyWithIV(key, key.size(), iv, iv.size());

    std::string plaintext;
    CryptoPP::StringSource ss(
        ciphertext,
        true,
        new CryptoPP::AuthenticatedDecryptionFilter(
            decryption,
            new CryptoPP::StringSink(plaintext)));

    return plaintext;
}

} // namespace

HybridRSAAESAlgorithm::HybridRSAAESAlgorithm(int rsaKeySizeBits)
    : rsaKeySizeBits_(rsaKeySizeBits) {}

AlgorithmId HybridRSAAESAlgorithm::Id() const {
    return AlgorithmId::HybridRSA_AES;
}

std::string HybridRSAAESAlgorithm::Name() const {
    return "hybrid_rsa_aes";
}

void HybridRSAAESAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    privateKey.GenerateRandomWithKeySize(rng, static_cast<unsigned int>(rsaKeySizeBits_));

    CryptoPP::RSA::PublicKey publicKey(privateKey);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    privateKey.Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    publicKey.Save(publicSink);
}

void HybridRSAAESAlgorithm::EncryptFile(const fs::path& inputFile,
                                        const fs::path& outputFile,
                                        const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PublicKey publicKey;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    publicKey.Load(publicSource);
    publicKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Encryptor rsaEncryptor(publicKey);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);

    CryptoPP::SecByteBlock aesKey(kAesKeyBytes);
    CryptoPP::SecByteBlock iv(kIvBytes);
    rng.GenerateBlock(aesKey, aesKey.size());
    rng.GenerateBlock(iv, iv.size());

    std::string encryptedAesKey;
    CryptoPP::StringSource ss1(
        aesKey.BytePtr(),
        aesKey.size(),
        true,
        new CryptoPP::PK_EncryptorFilter(
            rng,
            rsaEncryptor,
            new CryptoPP::StringSink(encryptedAesKey)));

    const std::string ciphertext = EncryptAesGcm(aesKey, iv, plaintext);

    std::string package(kMagic);
    utils::AppendUint32(package, static_cast<std::uint32_t>(encryptedAesKey.size()));
    package += encryptedAesKey;
    utils::AppendUint32(package, static_cast<std::uint32_t>(iv.size()));
    package.append(reinterpret_cast<const char*>(iv.BytePtr()), iv.size());
    package += ciphertext;

    utils::WriteBinaryFile(outputFile, package);
}

void HybridRSAAESAlgorithm::DecryptFile(const fs::path& inputFile,
                                        const fs::path& outputFile,
                                        const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::RSA::PrivateKey privateKey;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    privateKey.Load(privateSource);
    privateKey.ThrowIfInvalid(rng, 3);

    CryptoPP::RSAES_OAEP_SHA_Decryptor rsaDecryptor(privateKey);

    const std::string package = utils::ReadBinaryFile(inputFile);
    if (package.size() < 5 || package.substr(0, 5) != kMagic) {
        throw std::runtime_error("Invalid hybrid package header");
    }

    std::size_t offset = 5;
    const auto encryptedAesKeySize = static_cast<std::size_t>(utils::ReadUint32(package, offset));
    if (offset + encryptedAesKeySize > package.size()) {
        throw std::runtime_error("Invalid hybrid package: RSA-wrapped key exceeds file size");
    }

    const std::string encryptedAesKey = package.substr(offset, encryptedAesKeySize);
    offset += encryptedAesKeySize;

    const auto ivSize = static_cast<std::size_t>(utils::ReadUint32(package, offset));
    if (offset + ivSize > package.size()) {
        throw std::runtime_error("Invalid hybrid package: IV exceeds file size");
    }

    const std::string ivBytes = package.substr(offset, ivSize);
    offset += ivSize;

    const std::string ciphertext = package.substr(offset);

    std::string rawAesKey;
    CryptoPP::StringSource ss2(
        encryptedAesKey,
        true,
        new CryptoPP::PK_DecryptorFilter(
            rng,
            rsaDecryptor,
            new CryptoPP::StringSink(rawAesKey)));

    CryptoPP::SecByteBlock aesKey(
        reinterpret_cast<const CryptoPP::byte*>(rawAesKey.data()),
        rawAesKey.size());

    CryptoPP::SecByteBlock iv(
        reinterpret_cast<const CryptoPP::byte*>(ivBytes.data()),
        ivBytes.size());

    const std::string plaintext = DecryptAesGcm(aesKey, iv, ciphertext);
    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
