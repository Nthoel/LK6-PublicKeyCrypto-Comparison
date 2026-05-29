#pragma once
#include <chrono>

namespace lk6::utils {

class Timer {
public:
    void Start();
    double StopMilliseconds();

private:
    std::chrono::high_resolution_clock::time_point start_;
};

} // namespace lk6::utils
