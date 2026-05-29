cmake_minimum_required(VERSION 3.16)
project(LK6PublicKeyCryptoComparison VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(include)

file(GLOB_RECURSE PROJECT_SOURCES
    src/*.cpp
)

add_executable(lk6_compare ${PROJECT_SOURCES})

# Catatan:
# Jika memakai Crypto++, sesuaikan salah satu pendekatan berikut:
# 1) Pakai package manager (vcpkg/conan)
# 2) Tambahkan include dan link directory manual
#
# Contoh pseudo:
# find_package(cryptopp CONFIG REQUIRED)
# target_link_libraries(lk6_compare PRIVATE cryptopp-static)
