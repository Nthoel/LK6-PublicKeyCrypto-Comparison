#include "utils/FileUtil.hpp"
#include <fstream>
#include <iterator>
#include <stdexcept>

namespace lk6::utils {

std::vector<std::uint8_t> ReadBinaryFile(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("Failed to open file: " + path);

    return std::vector<std::uint8_t>(
        (std::istreambuf_iterator<char>(file)),
        std::istreambuf_iterator<char>()
    );
}

void WriteBinaryFile(const std::string& path, const std::vector<std::uint8_t>& data) {
    std::ofstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("Failed to write file: " + path);

    file.write(reinterpret_cast<const char*>(data.data()), static_cast<std::streamsize>(data.size()));
}

} // namespace lk6::utils
