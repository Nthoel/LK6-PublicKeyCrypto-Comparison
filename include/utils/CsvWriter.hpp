#pragma once

#include <filesystem>
#include <vector>

#include "core/Types.hpp"

namespace lk6::utils {

class CsvWriter {
public:
    static void WriteRows(const std::filesystem::path& path,
                          const std::vector<lk6::BenchmarkRow>& rows);
};

} // namespace lk6::utils
