#pragma once
#include <string>
#include <vector>
#include "core/CryptoTypes.hpp"

namespace lk6::utils {

class CsvWriter {
public:
    static void WriteBenchmarkResults(
        const std::string& outputPath,
        const std::vector<lk6::core::BenchmarkResult>& results
    );
};

} // namespace lk6::utils
