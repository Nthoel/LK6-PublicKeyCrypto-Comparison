#pragma once

#include <chrono>

namespace lk6::utils {

class Timer {
public:
    using Clock = std::chrono::steady_clock;

    Timer() : start_(Clock::now()) {}

    void Reset() {
        start_ = Clock::now();
    }

    double ElapsedMs() const {
        const auto end = Clock::now();
        return std::chrono::duration<double, std::milli>(end - start_).count();
    }

private:
    Clock::time_point start_;
};

} // namespace lk6::utils
