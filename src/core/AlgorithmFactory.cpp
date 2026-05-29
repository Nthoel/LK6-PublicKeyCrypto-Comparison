#include "core/AlgorithmFactory.hpp"

#include <memory>
#include <vector>

#include "algorithms/ECIESAlgorithm.hpp"
#include "algorithms/ElGamalAlgorithm.hpp"
#include "algorithms/HybridRSAAESAlgorithm.hpp"
#include "algorithms/RSAAlgorithm.hpp"

namespace lk6 {

std::vector<std::unique_ptr<IEncryptionScheme>> CreateAlgorithms() {
    std::vector<std::unique_ptr<IEncryptionScheme>> algorithms;
    algorithms.push_back(std::make_unique<RSAAlgorithm>());
    algorithms.push_back(std::make_unique<ECIESAlgorithm>());
    algorithms.push_back(std::make_unique<ElGamalAlgorithm>());
    algorithms.push_back(std::make_unique<HybridRSAAESAlgorithm>());
    return algorithms;
}

} // namespace lk6
