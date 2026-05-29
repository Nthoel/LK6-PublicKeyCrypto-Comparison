#pragma once
#include <string>
#include <vector>

namespace lk6::benchmarks {

struct DatasetEntry {
    std::string filePath;
    std::string fileName;
    std::string category;
};

std::vector<DatasetEntry> ScanDataset(const std::string& root);

} // namespace lk6::benchmarks
