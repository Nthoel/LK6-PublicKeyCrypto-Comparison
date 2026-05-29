#pragma once
#include <vector>
#include "core/AppConfig.hpp"
#include "core/CryptoTypes.hpp"

namespace lk6::benchmarks {

class BenchmarkRunner {
public:
    std::vector<lk6::core::BenchmarkResult> Run(const lk6::core::AppConfig& config);
};

} // namespace lk6::benchmarks
