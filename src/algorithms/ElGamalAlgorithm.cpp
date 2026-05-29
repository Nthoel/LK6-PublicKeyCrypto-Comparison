#include "algorithms/ElGamalAlgorithm.hpp"

#include <string>

#include <cryptopp/elgamal.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/osrng.h>

#include "utils/CryptoChunkIO.hpp"
#include "utils/FileUtils.hpp"

namespace lk6 {

ElGamalAlgorithm::ElGamalAlgorithm(int keySizeBits) : keySizeBits_(keySizeBits) {}

AlgorithmId ElGamalAlgorithm::Id() const {
    return AlgorithmId::ElGamal;
}

std::string ElGamalAlgorithm::Name() const {
    return "elgamal";
}

void ElGamalAlgorithm::GenerateKeys(const KeyPaths& paths) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::ElGamal::Decryptor decryptor;
    decryptor.AccessKey().GenerateRandomWithKeySize(rng, static_cast<unsigned int>(keySizeBits_));

    CryptoPP::ElGamal::Encryptor encryptor(decryptor);

    utils::EnsureParentDir(paths.privateKey);
    utils::EnsureParentDir(paths.publicKey);

    CryptoPP::FileSink privateSink(paths.privateKey.string().c_str());
    decryptor.AccessKey().Save(privateSink);

    CryptoPP::FileSink publicSink(paths.publicKey.string().c_str());
    encryptor.AccessKey().Save(publicSink);
}

void ElGamalAlgorithm::EncryptFile(const fs::path& inputFile,
                                   const fs::path& outputFile,
                                   const fs::path& publicKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::ElGamal::Encryptor encryptor;
    CryptoPP::FileSource publicSource(publicKeyFile.string().c_str(), true);
    encryptor.AccessKey().Load(publicSource);
    encryptor.AccessKey().ThrowIfInvalid(rng, 3);

    const std::string plaintext = utils::ReadBinaryFile(inputFile);
    const std::string ciphertext = utils::EncryptChunked(rng, encryptor, plaintext);

    utils::WriteBinaryFile(outputFile, ciphertext);
}

void ElGamalAlgorithm::DecryptFile(const fs::path& inputFile,
                                   const fs::path& outputFile,
                                   const fs::path& privateKeyFile) {
    CryptoPP::AutoSeededRandomPool rng;

    CryptoPP::ElGamal::Decryptor decryptor;
    CryptoPP::FileSource privateSource(privateKeyFile.string().c_str(), true);
    decryptor.AccessKey().Load(privateSource);
    decryptor.AccessKey().ThrowIfInvalid(rng, 3);

    const std::string ciphertext = utils::ReadBinaryFile(inputFile);
    const std::string plaintext = utils::DecryptChunked(rng, decryptor, ciphertext);

    utils::WriteBinaryFile(outputFile, plaintext);
}

} // namespace lk6
