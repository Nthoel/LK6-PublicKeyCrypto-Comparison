#include "analysis/WordReportWriter.hpp"

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <stdexcept>
#include <string>
#include <vector>

#include "analysis/ByteMetrics.hpp"

namespace lk6::analysis {

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

void EnsureParent(const std::filesystem::path& path) {
    std::filesystem::create_directories(path.parent_path());
}

double SafeOverheadRatio(std::uintmax_t plainBytes, std::uintmax_t cipherBytes) {
    if (plainBytes == 0U) {
        return 0.0;
    }
    return static_cast<double>(cipherBytes) / static_cast<double>(plainBytes);
}

std::string BuildCombinedNotes(const WordTaskRow& row) {
    std::string notes;
    auto append = [&](const std::string& prefix, const std::string& value) {
        if (value.empty()) {
            return;
        }
        if (!notes.empty()) {
            notes += " | ";
        }
        notes += prefix + ": " + value;
    };

    append("RSA", row.rsa.notes);
    append("ElGamal", row.elgamal.notes);
    append("ECC", row.ecc.notes);
    append("RSA-AES", row.rsaAes.notes);

    return notes;
}

void WriteTask4(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,plaintext_kb,rsa_kb,elgamal_kb,ecc_kb,rsa_aes_kb,"
           "rsa_overhead_ratio,elgamal_overhead_ratio,ecc_overhead_ratio,rsa_aes_overhead_ratio\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << BytesToKB(row.plaintextBytes) << ","
            << BytesToKB(row.rsa.cipherBytes) << ","
            << BytesToKB(row.elgamal.cipherBytes) << ","
            << BytesToKB(row.ecc.cipherBytes) << ","
            << BytesToKB(row.rsaAes.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.rsa.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.elgamal.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.ecc.cipherBytes) << ","
            << SafeOverheadRatio(row.plaintextBytes, row.rsaAes.cipherBytes) << "\n";
    }
}

void WriteTask5(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,"
           "rsa_encrypt_ms,elgamal_encrypt_ms,ecc_encrypt_ms,rsa_aes_encrypt_ms,"
           "rsa_decrypt_ms,elgamal_decrypt_ms,ecc_decrypt_ms,rsa_aes_decrypt_ms\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.rsa.encryptMs << ","
            << row.elgamal.encryptMs << ","
            << row.ecc.encryptMs << ","
            << row.rsaAes.encryptMs << ","
            << row.rsa.decryptMs << ","
            << row.elgamal.decryptMs << ","
            << row.ecc.decryptMs << ","
            << row.rsaAes.decryptMs << "\n";
    }
}

void WriteTask6(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,plaintext_entropy_bit,"
           "rsa_entropy_bit,elgamal_entropy_bit,ecc_entropy_bit,rsa_aes_entropy_bit\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.plaintextEntropy << ","
            << row.rsa.cipherEntropy << ","
            << row.elgamal.cipherEntropy << ","
            << row.ecc.cipherEntropy << ","
            << row.rsaAes.cipherEntropy << "\n";
    }
}

void WriteTask7(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,"
           "rsa_plain_vs_cipher,elgamal_plain_vs_cipher,ecc_plain_vs_cipher,rsa_aes_plain_vs_cipher,"
           "rsa_vs_ecc_cipher\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.rsa.plainCipherCorrelation << ","
            << row.elgamal.plainCipherCorrelation << ","
            << row.ecc.plainCipherCorrelation << ","
            << row.rsaAes.plainCipherCorrelation << ","
            << row.rsaVsEccCipherCorrelation << "\n";
    }
}

void WriteTask8(const std::filesystem::path& path, const std::vector<WordTaskRow>& rows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "id,relative_file,size_category,"
           "rsa_changed_bits,rsa_total_bits,rsa_avalanche_percent,"
           "elgamal_changed_bits,elgamal_total_bits,elgamal_avalanche_percent,"
           "ecc_changed_bits,ecc_total_bits,ecc_avalanche_percent,"
           "rsa_aes_changed_bits,rsa_aes_total_bits,rsa_aes_avalanche_percent,notes\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : rows) {
        out << row.id << ","
            << EscapeCsv(row.relativeFile) << ","
            << EscapeCsv(row.sizeCategory) << ","
            << row.rsa.avalancheChangedBits << ","
            << row.rsa.avalancheTotalBits << ","
            << row.rsa.avalanchePercent << ","
            << row.elgamal.avalancheChangedBits << ","
            << row.elgamal.avalancheTotalBits << ","
            << row.elgamal.avalanchePercent << ","
            << row.ecc.avalancheChangedBits << ","
            << row.ecc.avalancheTotalBits << ","
            << row.ecc.avalanchePercent << ","
            << row.rsaAes.avalancheChangedBits << ","
            << row.rsaAes.avalancheTotalBits << ","
            << row.rsaAes.avalanchePercent << ","
            << EscapeCsv(BuildCombinedNotes(row)) << "\n";
    }
}

void WriteSummary(const std::filesystem::path& path, const std::vector<AlgorithmSummaryRow>& summaryRows) {
    EnsureParent(path);
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Failed to open: " + path.string());
    }

    out << "algorithm,sample_count,success_count,success_rate_percent,avg_cipher_kb,avg_overhead_ratio,"
           "avg_encrypt_ms,avg_decrypt_ms,avg_cipher_entropy,avg_plain_cipher_correlation,avg_avalanche_percent\n";

    out << std::fixed << std::setprecision(6);
    for (const auto& row : summaryRows) {
        const double successRate = row.sampleCount == 0U
            ? 0.0
            : (static_cast<double>(row.successCount) / static_cast<double>(row.sampleCount)) * 100.0;

        out << EscapeCsv(row.algorithm) << ","
            << row.sampleCount << ","
            << row.successCount << ","
            << successRate << ","
            << row.avgCipherKB << ","
            << row.avgOverheadRatio << ","
            << row.avgEncryptMs << ","
            << row.avgDecryptMs << ","
            << row.avgCipherEntropy << ","
            << row.avgPlainCipherCorrelation << ","
            << row.avgAvalanchePercent << "\n";
    }
}

} // namespace

void WordReportWriter::WriteAll(const std::filesystem::path& csvRoot,
                                const std::vector<WordTaskRow>& rows,
                                const std::vector<AlgorithmSummaryRow>& summaryRows) {
    std::filesystem::create_directories(csvRoot);

    WriteTask4(csvRoot / "lk6_task4_file_size.csv", rows);
    WriteTask5(csvRoot / "lk6_task5_time.csv", rows);
    WriteTask6(csvRoot / "lk6_task6_entropy.csv", rows);
    WriteTask7(csvRoot / "lk6_task7_correlation.csv", rows);
    WriteTask8(csvRoot / "lk6_task8_avalanche.csv", rows);
    WriteSummary(csvRoot / "lk6_summary_average.csv", summaryRows);
}

} // namespace lk6::analysis
