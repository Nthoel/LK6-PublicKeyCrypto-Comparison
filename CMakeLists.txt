cmake_minimum_required(VERSION 3.20)
project(LK6PublicKeyCryptoComparison LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

option(LK6_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)

if (MSVC)
    add_compile_options(/W4 /permissive-)
    if (LK6_WARNINGS_AS_ERRORS)
        add_compile_options(/WX)
    endif()
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
    if (LK6_WARNINGS_AS_ERRORS)
        add_compile_options(-Werror)
    endif()
endif()

find_package(CryptoPP REQUIRED)

add_executable(lk6_crypto_compare
    src/main.cpp
    src/core/AlgorithmFactory.cpp
    src/benchmarks/BenchmarkRunner.cpp
    src/utils/FileUtils.cpp
    src/utils/CsvWriter.cpp
    src/algorithms/RSAAlgorithm.cpp
    src/algorithms/ECIESAlgorithm.cpp
    src/algorithms/ElGamalAlgorithm.cpp
    src/algorithms/HybridRSAAESAlgorithm.cpp
)

target_include_directories(lk6_crypto_compare PRIVATE include)
target_link_libraries(lk6_crypto_compare PRIVATE CryptoPP::CryptoPP)

if (WIN32)
    target_compile_definitions(lk6_crypto_compare PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()
