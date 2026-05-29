#include "benchmarks/DatasetScanner.hpp"
#include <filesystem>

namespace fs = std::filesystem;

namespace lk6::benchmarks {

std::vector<DatasetEntry> ScanDataset(const std::string& root) {
    std::vector<DatasetEntry> entries;

    if (!fs::exists(root)) return entries;

    for (const auto& categoryDir : fs::directory_iterator(root)) {
        if (!categoryDir.is_directory()) continue;

        const auto category = categoryDir.path().filename().string();

        for (const auto& file : fs::directory_iterator(categoryDir.path())) {
            if (!file.is_regular_file()) continue;

            entries.push_back({
                file.path().string(),
                file.path().filename().string(),
                category
            });
        }
    }

    return entries;
}

} // namespace lk6::benchmarks
