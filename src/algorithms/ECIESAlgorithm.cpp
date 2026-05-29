#include "algorithms/ECIESAlgorithm.hpp"

#include <string>

#include <cryptopp/eccrypto.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/oids.h>
#include <cryptopp/osrng.h>

#include "utils/FileUtils.hpp"

namespace lk6 {

namespace {
using ECIESDecryptor = CryptoPP::ECIES<CryptoPP::ECP>::Decryptor;
using ECIESEncryptor = CryptoPP::ECIES<CryptoPP::ECP>::Encryptor;
}

AlgorithmId ECIESAlgorithm::Id() const {
    return AlgorithmId::ECIES;
}

std::string ECIESAlgorithm::Name() const {
    return "ecies";
}

void ECIESAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    ECIESDecryptor decryptor(rng, CryptoPP::ASN1::secp256r1());
    ECIESEncryptor encryptor(decryptor);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    decryptor.GetPrivateKey().Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    encryptor.GetPublicKey().Save(publicSink);
}

void ECIESAlgorithm::EncryptFile(const fs::path& inputFile,
                                 const fs::path& outputFile,
                                 const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    ECIESEncryptor encryptor;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    encryptor.AccessPublicKey().Load(publicSource);
    encryptor.GetPublicKey().ThrowIfInvalid(rng, 3);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);

    std::string ciphertext;
    CryptoPP::StringSource ss(
        plaintext,
        true,
        new CryptoPP::PK_EncryptorFilter(
            rng,
            encryptor,
            new CryptoPP::StringSink(ciphertext)));

    utils::WriteBinaryFile(outputFile, ciphertext);
}

void ECIESAlgorithm::DecryptFile(const fs::path& inputFile,
                                 const fs::path& outputFile,
                                 const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    ECIESDecryptor decryptor;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    decryptor.AccessPrivateKey().Load(privateSource);
    decryptor.GetPrivateKey().ThrowIfInvalid(rng, 3);

    const std::string ciphertext = utils::ReadBinaryFile(inputFile);

    std::string plaintext;
    CryptoPP::StringSource ss(
        ciphertext,
        true,
        new CryptoPP::PK_DecryptorFilter(
            rng,
            decryptor,
            new CryptoPP::StringSink(plaintext)));

    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
