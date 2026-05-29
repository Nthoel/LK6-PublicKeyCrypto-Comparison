#include <iostream>
#include "core/AppConfig.hpp"
#include "benchmarks/BenchmarkRunner.hpp"
#include "utils/CsvWriter.hpp"

int main() {
    try {
        lk6::core::AppConfig config;
        lk6::benchmarks::BenchmarkRunner runner;

        const auto results = runner.Run(config);
        lk6::utils::CsvWriter::WriteBenchmarkResults(config.resultCsvPath, results);

        std::cout << "Benchmark completed. Results saved to: "
                  << config.resultCsvPath << std::endl;
        return 0;
    } catch (const std::exception& ex) {
        std::cerr << "Fatal error: " << ex.what() << std::endl;
        return 1;
    }
}
