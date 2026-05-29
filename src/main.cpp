#include <exception>
#include <iostream>

#include "benchmarks/BenchmarkRunner.hpp"

int main(int argc, char* argv[]) {
    lk6::BenchmarkOptions options;

    if (argc >= 2) {
        options.datasetRoot = argv[1];
    }

    if (argc >= 3) {
        options.csvPath = argv[2];
    }

    if (argc >= 4) {
        options.outputRoot = argv[3];
    }

    try {
        lk6::BenchmarkRunner runner(options);
        return runner.RunAll();
    } catch (const std::exception& ex) {
        std::cerr << "Fatal error: " << ex.what() << "\n";
        return 1;
    }
}
