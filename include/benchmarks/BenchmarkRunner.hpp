#pragma once

#include "core/Types.hpp"

namespace lk6 {

class BenchmarkRunner {
public:
    explicit BenchmarkRunner(BenchmarkOptions options);

    int RunAll();

private:
    std::string GetSizeCategory(std::uintmax_t bytes) const;

    BenchmarkOptions options_;
};

} // namespace lk6
