#include "utils/CsvWriter.hpp"
#include <fstream>
#include <stdexcept>

namespace lk6::utils {

void CsvWriter::WriteBenchmarkResults(
    const std::string& outputPath,
    const std::vector<lk6::core::BenchmarkResult>& results
) {
    std::ofstream out(outputPath);
    if (!out) throw std::runtime_error("Failed to open CSV output: " + outputPath);

    out << "algorithm,file_name,file_category,plain_bytes,cipher_bytes,keygen_ms,encrypt_ms,decrypt_ms,success,notes\n";

    for (const auto& row : results) {
        out
            << row.algorithm << ','
            << row.fileName << ','
            << row.fileCategory << ','
            << row.plainBytes << ','
            << row.cipherBytes << ','
            << row.keyGenMs << ','
            << row.encryptMs << ','
            << row.decryptMs << ','
            << (row.success ? "true" : "false") << ','
            << '"' << row.notes << '"' << '\n';
    }
}

} // namespace lk6::utils
