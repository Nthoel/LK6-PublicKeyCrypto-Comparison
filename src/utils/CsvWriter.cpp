#include "utils/CsvWriter.hpp"

#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

namespace lk6::utils {

namespace {
std::string EscapeCsv(const std::string& value) {
    bool requiresQuotes = false;
    std::string escaped;

    for (char ch : value) {
        if (ch == '"' || ch == ',' || ch == '\n' || ch == '\r') {
            requiresQuotes = true;
        }

        if (ch == '"') {
            escaped += "\"\"";
        } else {
            escaped.push_back(ch);
        }
    }

    if (!requiresQuotes) {
        return escaped;
    }

    return "\"" + escaped + "\"";
}
} // namespace

void CsvWriter::WriteRows(const std::filesystem::path& path,
                         const std::vector<lk6::BenchmarkRow>& rows) {
    std::filesystem::create_directories(path.parent_path());

    std::ofstream output(path, std::ios::binary);
    if (!output) {
        throw std::runtime_error("Failed to open CSV output: " + path.string());
    }

    output << "algorithm,relative_file,size_category,input_bytes,output_bytes,keygen_ms,encrypt_ms,decrypt_ms,decrypted_match,notes\n";

    for (const auto& row : rows) {
        output << EscapeCsv(row.algorithm) << ","
               << EscapeCsv(row.relativeFile) << ","
               << EscapeCsv(row.sizeCategory) << ","
               << row.inputBytes << ","
               << row.outputBytes << ","
               << row.keygenMs << ","
               << row.encryptMs << ","
               << row.decryptMs << ","
               << (row.decryptedMatch ? "true" : "false") << ","
               << EscapeCsv(row.notes) << "\n";
    }
}

} // namespace lk6::utils
