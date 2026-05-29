find_path(CRYPTOPP_INCLUDE_DIR
    NAMES cryptopp/cryptlib.h
    HINTS
        ${CRYPTOPP_ROOT}
        $ENV{CRYPTOPP_ROOT}
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp-install
    PATH_SUFFIXES include
)

find_library(CRYPTOPP_LIBRARY
    NAMES cryptopp cryptlib
    HINTS
        ${CRYPTOPP_ROOT}
        $ENV{CRYPTOPP_ROOT}
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp
        ${CMAKE_SOURCE_DIR}/third_party/cryptopp-install
    PATH_SUFFIXES lib lib64
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CryptoPP DEFAULT_MSG CRYPTOPP_INCLUDE_DIR CRYPTOPP_LIBRARY)

if (CryptoPP_FOUND AND NOT TARGET CryptoPP::CryptoPP)
    add_library(CryptoPP::CryptoPP UNKNOWN IMPORTED)
    set_target_properties(CryptoPP::CryptoPP PROPERTIES
        IMPORTED_LOCATION "${CRYPTOPP_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${CRYPTOPP_INCLUDE_DIR}"
    )
endif()
