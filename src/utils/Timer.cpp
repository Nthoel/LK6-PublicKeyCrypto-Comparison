#include "utils/Timer.hpp"

namespace lk6::utils {

void Timer::Start() {
    start_ = std::chrono::high_resolution_clock::now();
}

double Timer::StopMilliseconds() {
    const auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start_).count();
}

} // namespace lk6::utils
