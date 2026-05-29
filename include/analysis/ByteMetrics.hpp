#pragma once

#include <cstdint>
#include <string>

namespace lk6::analysis {

double BytesToKB(std::uintmax_t bytes);
double ComputeShannonEntropy(const std::string& bytes);
double ComputePearsonCorrelation(const std::string& lhs, const std::string& rhs);
std::size_t CountDifferentBits(const std::string& lhs, const std::string& rhs);
std::size_t TotalComparedBits(const std::string& lhs, const std::string& rhs);
double ComputeAvalanchePercent(const std::string& lhs, const std::string& rhs);
std::string MutatePlaintextSingleBit(const std::string& original);

} // namespace lk6::analysis
