#pragma once

#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <string>

#include <cryptopp/cryptlib.h>
#include <cryptopp/filters.h>
#include <cryptopp/osrng.h>

namespace lk6::utils {

inline void AppendUint32(std::string& output, std::uint32_t value) {
    output.push_back(static_cast<char>((value >> 24) & 0xFF));
    output.push_back(static_cast<char>((value >> 16) & 0xFF));
    output.push_back(static_cast<char>((value >> 8) & 0xFF));
    output.push_back(static_cast<char>(value & 0xFF));
}

inline std::uint32_t ReadUint32(const std::string& input, std::size_t& offset) {
    if (offset + 4 > input.size()) {
        throw std::runtime_error("Invalid binary package: missing 4-byte length field");
    }

    const auto b0 = static_cast<std::uint8_t>(input[offset + 0]);
    const auto b1 = static_cast<std::uint8_t>(input[offset + 1]);
    const auto b2 = static_cast<std::uint8_t>(input[offset + 2]);
    const auto b3 = static_cast<std::uint8_t>(input[offset + 3]);
    offset += 4;

    return (static_cast<std::uint32_t>(b0) << 24) |
           (static_cast<std::uint32_t>(b1) << 16) |
           (static_cast<std::uint32_t>(b2) << 8) |
           (static_cast<std::uint32_t>(b3));
}

template <typename EncryptorT>
std::string EncryptChunked(CryptoPP::AutoSeededRandomPool& rng,
                           EncryptorT& encryptor,
                           const std::string& plaintext) {
    const std::size_t maxBlock = encryptor.FixedMaxPlaintextLength();
    if (maxBlock == 0) {
        throw std::runtime_error("Encryptor reported max plaintext length 0");
    }

    std::string output;

    for (std::size_t offset = 0; offset < plaintext.size(); offset += maxBlock) {
        const std::size_t blockSize = std::min(maxBlock, plaintext.size() - offset);
        std::string encryptedBlock;

        CryptoPP::StringSource ss(
            reinterpret_cast<const CryptoPP::byte*>(plaintext.data()) + offset,
            blockSize,
            true,
            new CryptoPP::PK_EncryptorFilter(
                rng,
                encryptor,
                new CryptoPP::StringSink(encryptedBlock)));

        AppendUint32(output, static_cast<std::uint32_t>(encryptedBlock.size()));
        output += encryptedBlock;
    }

    return output;
}

template <typename DecryptorT>
std::string DecryptChunked(CryptoPP::AutoSeededRandomPool& rng,
                           DecryptorT& decryptor,
                           const std::string& ciphertext) {
    std::string output;
    std::size_t offset = 0;

    while (offset < ciphertext.size()) {
        const auto blockSize = static_cast<std::size_t>(ReadUint32(ciphertext, offset));

        if (offset + blockSize > ciphertext.size()) {
            throw std::runtime_error("Invalid binary package: encrypted block exceeds file size");
        }

        std::string encryptedBlock = ciphertext.substr(offset, blockSize);
        offset += blockSize;

        std::string decryptedBlock;
        CryptoPP::StringSource ss(
            reinterpret_cast<const CryptoPP::byte*>(encryptedBlock.data()),
            encryptedBlock.size(),
            true,
            new CryptoPP::PK_DecryptorFilter(
                rng,
                decryptor,
                new CryptoPP::StringSink(decryptedBlock)));

        output += decryptedBlock;
    }

    return output;
}

} // namespace lk6::utils
