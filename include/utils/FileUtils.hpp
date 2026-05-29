#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace lk6::utils {

namespace fs = std::filesystem;

std::string ReadBinaryFile(const fs::path& path);
void WriteBinaryFile(const fs::path& path, const std::string& data);
void EnsureParentDir(const fs::path& path);
std::vector<fs::path> CollectDatasetFiles(const fs::path& root, bool recursive = true);
bool FilesEqual(const fs::path& lhs, const fs::path& rhs);

} // namespace lk6::utils
