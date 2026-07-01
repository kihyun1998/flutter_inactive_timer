# Standalone unit-test harness for the flutter_inactive_timer Windows plugin.
#
# This is intentionally decoupled from the Flutter example app build: it
# compiles the plugin sources together with the Flutter C++ client-wrapper
# (shipped in the SDK's engine artifacts) and GoogleTest, so the plugin's
# native logic can be exercised directly via HandleMethodCall().
#
# Configure & build (from repo root), e.g.:
#   cmake -S windows/test -B build/win-test -G Ninja -DCMAKE_BUILD_TYPE=Debug
#   cmake --build build/win-test
#   ctest --test-dir build/win-test --output-on-failure
#
# FLUTTER_ROOT is derived from `flutter` on PATH, or pass -DFLUTTER_ROOT=...

cmake_minimum_required(VERSION 3.14)
project(flutter_inactive_timer_windows_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- Locate the Flutter Windows engine artifacts -----------------------------
if(NOT DEFINED FLUTTER_ROOT)
  if(DEFINED ENV{FLUTTER_ROOT})
    set(FLUTTER_ROOT $ENV{FLUTTER_ROOT})
  else()
    find_program(FLUTTER_EXE NAMES flutter flutter.bat)
    if(NOT FLUTTER_EXE)
      message(FATAL_ERROR "Could not find `flutter` on PATH; pass -DFLUTTER_ROOT=<sdk>.")
    endif()
    get_filename_component(_flutter_bin "${FLUTTER_EXE}" DIRECTORY)
    get_filename_component(FLUTTER_ROOT "${_flutter_bin}" DIRECTORY)
  endif()
endif()

set(FLUTTER_ARTIFACTS "${FLUTTER_ROOT}/bin/cache/artifacts/engine/windows-x64")
set(WRAPPER "${FLUTTER_ARTIFACTS}/cpp_client_wrapper")

if(NOT EXISTS "${WRAPPER}/core_implementations.cc")
  message(FATAL_ERROR "Flutter C++ client wrapper not found at ${WRAPPER}. "
                      "Run any `flutter` command once so the SDK caches Windows artifacts.")
endif()

# --- GoogleTest --------------------------------------------------------------
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/release-1.12.1.zip
)
# Match the plugin's dynamic CRT (/MD) so linking succeeds on MSVC.
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# --- Flutter C++ client wrapper (compiled as a static lib) -------------------
add_library(flutter_wrapper_plugin STATIC
  "${WRAPPER}/core_implementations.cc"
  "${WRAPPER}/standard_codec.cc"
  "${WRAPPER}/plugin_registrar.cc"
  "${WRAPPER}/engine_method_result.cc"
)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${WRAPPER}/include"
  "${FLUTTER_ARTIFACTS}"
)
target_link_libraries(flutter_wrapper_plugin PUBLIC
  "${FLUTTER_ARTIFACTS}/flutter_windows.dll.lib"
)

# --- The test executable -----------------------------------------------------
set(PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
add_executable(flutter_inactive_timer_windows_test
  "${PLUGIN_DIR}/flutter_inactive_timer_plugin.cpp"
  "flutter_inactive_timer_plugin_test.cpp"
)
target_include_directories(flutter_inactive_timer_windows_test PRIVATE "${PLUGIN_DIR}")
target_link_libraries(flutter_inactive_timer_windows_test PRIVATE
  flutter_wrapper_plugin
  GTest::gtest_main
)

# Ensure flutter_windows.dll is next to the test exe at runtime.
add_custom_command(TARGET flutter_inactive_timer_windows_test POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ARTIFACTS}/flutter_windows.dll"
    "$<TARGET_FILE_DIR:flutter_inactive_timer_windows_test>"
)

include(GoogleTest)
enable_testing()
gtest_discover_tests(flutter_inactive_timer_windows_test)
