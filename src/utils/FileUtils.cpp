#include "utils/FileUtils.hpp"

#include <algorithm>
#include <fstream>
#include <iterator>
#include <stdexcept>

namespace lk6::utils {

std::string ReadBinaryFile(const fs::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        throw std::runtime_error("Failed to open file for reading: " + path.string());
    }

    return std::string(
        std::istreambuf_iterator<char>(input),
        std::istreambuf_iterator<char>());
}

void WriteBinaryFile(const fs::path& path, const std::string& data) {
    EnsureParentDir(path);

    std::ofstream output(path, std::ios::binary);
    if (!output) {
        throw std::runtime_error("Failed to open file for writing: " + path.string());
    }

    output.write(data.data(), static_cast<std::streamsize>(data.size()));
    if (!output.good()) {
        throw std::runtime_error("Failed to write file: " + path.string());
    }
}

void EnsureParentDir(const fs::path& path) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        fs::create_directories(parent);
    }
}

std::vector<fs::path> CollectDatasetFiles(const fs::path& root, bool recursive) {
    std::vector<fs::path> files;

    if (!fs::exists(root)) {
        return files;
    }

    auto isTargetFile = [](const fs::path& path) {
        if (!fs::is_regular_file(path)) {
            return false;
        }

        const auto ext = path.extension().string();
        return ext == ".txt" || ext == ".csv" || ext == ".json";
    };

    if (recursive) {
        for (const auto& entry : fs::recursive_directory_iterator(root)) {
            if (isTargetFile(entry.path())) {
                files.push_back(entry.path());
            }
        }
    } else {
        for (const auto& entry : fs::directory_iterator(root)) {
            if (isTargetFile(entry.path())) {
                files.push_back(entry.path());
            }
        }
    }

    std::sort(files.begin(), files.end());
    return files;
}

bool FilesEqual(const fs::path& lhs, const fs::path& rhs) {
    if (!fs::exists(lhs) || !fs::exists(rhs)) {
        return false;
    }

    if (fs::file_size(lhs) != fs::file_size(rhs)) {
        return false;
    }

    return ReadBinaryFile(lhs) == ReadBinaryFile(rhs);
}

} // namespace lk6::utils
