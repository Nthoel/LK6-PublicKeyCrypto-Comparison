#pragma once
#include <memory>
#include <string>
#include "core/IAsymmetricScheme.hpp"

namespace lk6::core {

std::unique_ptr<IAsymmetricScheme> CreateScheme(const std::string& algorithmName);

} // namespace lk6::core
