#pragma once
#include <string>
#include <vector>
#include <cstdint>

namespace lk6::utils {

std::vector<std::uint8_t> ReadBinaryFile(const std::string& path);
void WriteBinaryFile(const std::string& path, const std::vector<std::uint8_t>& data);

} // namespace lk6::utils
