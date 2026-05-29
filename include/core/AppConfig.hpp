#pragma once
#include <string>
#include <vector>

namespace lk6::core {

struct AppConfig {
    std::string datasetRoot = "data/raw";
    std::string resultCsvPath = "results/csv/benchmark_results.csv";
    std::vector<std::string> enabledAlgorithms = {
        "RSA",
        "ECIES",
        "ElGamal",
        "HybridRSAAES"
    };
};

} // namespace lk6::core
