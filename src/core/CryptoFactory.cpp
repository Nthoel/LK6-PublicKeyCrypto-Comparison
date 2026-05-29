#include "core/CryptoFactory.hpp"
#include "algorithms/RSAService.hpp"
#include "algorithms/ECIESService.hpp"
#include "algorithms/ElGamalService.hpp"
#include "algorithms/HybridRSAAESService.hpp"
#include <stdexcept>

namespace lk6::core {

std::unique_ptr<IAsymmetricScheme> CreateScheme(const std::string& algorithmName) {
    if (algorithmName == "RSA") return std::make_unique<lk6::algorithms::RSAService>();
    if (algorithmName == "ECIES") return std::make_unique<lk6::algorithms::ECIESService>();
    if (algorithmName == "ElGamal") return std::make_unique<lk6::algorithms::ElGamalService>();
    if (algorithmName == "HybridRSAAES") return std::make_unique<lk6::algorithms::HybridRSAAESService>();

    throw std::invalid_argument("Unsupported algorithm: " + algorithmName);
}

} // namespace lk6::core
