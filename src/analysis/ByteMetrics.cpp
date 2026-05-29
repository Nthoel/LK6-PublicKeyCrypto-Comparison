#include "analysis/ByteMetrics.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>

namespace lk6::analysis {

namespace {

std::size_t PopcountByte(unsigned char value) {
    std::size_t count = 0;
    while (value != 0U) {
        count += static_cast<std::size_t>(value & 1U);
        value >>= 1U;
    }
    return count;
}

} // namespace

double BytesToKB(std::uintmax_t bytes) {
    return static_cast<double>(bytes) / 1024.0;
}

double ComputeShannonEntropy(const std::string& bytes) {
    if (bytes.empty()) {
        return 0.0;
    }

    std::array<std::uint64_t, 256> frequency{};
    for (unsigned char value : bytes) {
        ++frequency[value];
    }

    const double total = static_cast<double>(bytes.size());
    double entropy = 0.0;

    for (const auto count : frequency) {
        if (count == 0U) {
            continue;
        }

        const double probability = static_cast<double>(count) / total;
        entropy -= probability * std::log2(probability);
    }

    return entropy;
}

double ComputePearsonCorrelation(const std::string& lhs, const std::string& rhs) {
    const auto sampleSize = std::min(lhs.size(), rhs.size());
    if (sampleSize < 2U) {
        return 0.0;
    }

    double sumX = 0.0;
    double sumY = 0.0;

    for (std::size_t i = 0; i < sampleSize; ++i) {
        sumX += static_cast<unsigned char>(lhs[i]);
        sumY += static_cast<unsigned char>(rhs[i]);
    }

    const double meanX = sumX / static_cast<double>(sampleSize);
    const double meanY = sumY / static_cast<double>(sampleSize);

    double numerator = 0.0;
    double denomX = 0.0;
    double denomY = 0.0;

    for (std::size_t i = 0; i < sampleSize; ++i) {
        const double x = static_cast<unsigned char>(lhs[i]) - meanX;
        const double y = static_cast<unsigned char>(rhs[i]) - meanY;
        numerator += x * y;
        denomX += x * x;
        denomY += y * y;
    }

    const double denominator = std::sqrt(denomX * denomY);
    if (denominator <= std::numeric_limits<double>::epsilon()) {
        return 0.0;
    }

    return numerator / denominator;
}

std::size_t CountDifferentBits(const std::string& lhs, const std::string& rhs) {
    const auto shared = std::min(lhs.size(), rhs.size());
    std::size_t changedBits = 0;

    for (std::size_t i = 0; i < shared; ++i) {
        const auto left = static_cast<unsigned char>(lhs[i]);
        const auto right = static_cast<unsigned char>(rhs[i]);
        changedBits += PopcountByte(static_cast<unsigned char>(left ^ right));
    }

    const auto extraBytes = (lhs.size() > rhs.size())
        ? (lhs.size() - rhs.size())
        : (rhs.size() - lhs.size());

    changedBits += extraBytes * 8U;
    return changedBits;
}

std::size_t TotalComparedBits(const std::string& lhs, const std::string& rhs) {
    return std::max(lhs.size(), rhs.size()) * 8U;
}

double ComputeAvalanchePercent(const std::string& lhs, const std::string& rhs) {
    const auto totalBits = TotalComparedBits(lhs, rhs);
    if (totalBits == 0U) {
        return 0.0;
    }

    const auto changedBits = CountDifferentBits(lhs, rhs);
    return (static_cast<double>(changedBits) / static_cast<double>(totalBits)) * 100.0;
}

std::string MutatePlaintextSingleBit(const std::string& original) {
    if (original.empty()) {
        return std::string(1, static_cast<char>(0x01));
    }

    std::string mutated = original;
    mutated[0] = static_cast<char>(static_cast<unsigned char>(mutated[0]) ^ 0x01U);
    return mutated;
}

} // namespace lk6::analysis
