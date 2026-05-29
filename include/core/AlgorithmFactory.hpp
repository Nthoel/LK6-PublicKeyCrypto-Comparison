#pragma once

#include <memory>
#include <utility>
#include <vector>

#include "core/IEncryptionScheme.hpp"

namespace lk6 {

std::vector<std::unique_ptr<IEncryptionScheme>> CreateAlgorithms();

} // namespace lk6
