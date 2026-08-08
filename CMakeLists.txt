cmake_minimum_required(VERSION 3.20)
project(RetroFPS VERSION 0.6.0 LANGUAGES CXX)

# C++17, no compiler extensions, UTF-8 source encoding
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
if(MSVC)
    add_compile_options(/utf-8 /W4)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Tell CMake where our custom find modules live
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# === Fetch nlohmann/json (header-only JSON library) ===
include(FetchContent)
FetchContent_Declare(json
    URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
)
FetchContent_MakeAvailable(json)

# === Math Layer (zero dependencies — always builds) ===
add_library(retrofps_math STATIC
    src/math/Vector2D.cpp
    src/math/MathAddon.cpp
)
target_include_directories(retrofps_math PUBLIC src)
target_compile_features(retrofps_math PUBLIC cxx_std_17)

# === Level Data Layer (depends on Math + nlohmann/json; always builds) ===
# Map data, collision detection, entity spawning, game config.
add_library(retrofps_level STATIC
    src/game/Level.cpp
    src/game/GameConfig.cpp
    src/game/systems/ParticleSystem.cpp
    src/game/systems/PickupSystem.cpp
)
target_link_libraries(retrofps_level PUBLIC retrofps_math nlohmann_json::nlohmann_json)
target_include_directories(retrofps_level PUBLIC src)
target_compile_features(retrofps_level PUBLIC cxx_std_17)

# === Tests (optional, enable with -DBUILD_TESTS=ON) ===
option(BUILD_TESTS "Build unit tests" OFF)
if(BUILD_TESTS)
    enable_testing()

    # Fetch GoogleTest
    FetchContent_Declare(googletest
        URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.tar.gz
    )
    set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
    set(BUILD_GMOCK OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)

    macro(add_unit_test name)
        add_executable(${name} tests/unit/${name}.cpp)
        target_link_libraries(${name} PRIVATE ${ARGN} GTest::gtest_main)
        target_include_directories(${name} PRIVATE src)
        include(GoogleTest)
        gtest_discover_tests(${name} WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    endmacro()

    add_unit_test(test_vector2d retrofps_math)
    add_unit_test(test_mathaddon retrofps_math)
    add_unit_test(test_level retrofps_level)
    add_unit_test(test_particles retrofps_level)
    add_unit_test(test_config retrofps_level)
    add_unit_test(test_pickup retrofps_level)
    add_unit_test(test_purelogic retrofps_math)
endif()

if(BUILD_TESTS AND SDL2_AVAILABLE)
    add_unit_test(test_reload retrofps_game)
endif()

# === Engine Layer (depends on Math Layer + SDL2; builds when SDL2 found) ===
# Prefer CONFIG mode for vcpkg integration; fall back to custom Find modules
find_package(SDL2 CONFIG QUIET)
if(NOT SDL2_FOUND)
    find_package(SDL2 MODULE QUIET)
endif()
find_package(SDL2_mixer CONFIG QUIET)
if(NOT SDL2_mixer_FOUND)
    find_package(SDL2_mixer MODULE QUIET)
endif()
find_package(SDL2_ttf CONFIG QUIET)
if(NOT SDL2_ttf_FOUND)
    find_package(SDL2_ttf MODULE QUIET)
endif()

if(TARGET SDL2::SDL2 AND TARGET SDL2_mixer::SDL2_mixer AND TARGET SDL2_ttf::SDL2_ttf)
    set(SDL2_AVAILABLE TRUE)
else()
    set(SDL2_AVAILABLE FALSE)
endif()

if(SDL2_AVAILABLE)
    add_library(retrofps_engine STATIC
        src/engine/Renderer.cpp
        src/engine/Input.cpp
        src/engine/Audio.cpp
        src/engine/ResourceCache.cpp
    )
    target_link_libraries(retrofps_engine PUBLIC
        retrofps_math
        SDL2::SDL2
        SDL2::SDL2main
        SDL2_mixer::SDL2_mixer
        SDL2_ttf::SDL2_ttf
    )
    target_include_directories(retrofps_engine PUBLIC src)
    if(EXISTS "${CMAKE_BINARY_DIR}/vcpkg_installed/x64-windows/include")
        target_include_directories(retrofps_engine SYSTEM PUBLIC "${CMAKE_BINARY_DIR}/vcpkg_installed/x64-windows/include")
    endif()
    # Add vendor SDL2 include dirs for "#include <SDL2/SDL.h>" resolution
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDL2-2.30.3/include")
        target_include_directories(retrofps_engine SYSTEM PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDL2-2.30.3/include")
    endif()
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDL2_mixer-2.8.0/include")
        target_include_directories(retrofps_engine SYSTEM PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDL2_mixer-2.8.0/include")
    endif()
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDL2_ttf-2.22.0/include")
        target_include_directories(retrofps_engine SYSTEM PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDL2_ttf-2.22.0/include")
    endif()
    target_compile_features(retrofps_engine PUBLIC cxx_std_17)

    # === Game Layer (components/entities/systems) ===
    add_library(retrofps_game STATIC
        src/game/systems/MovementSystem.cpp
        src/game/systems/CombatSystem.cpp
        src/game/systems/ReloadSystem.cpp
        src/game/systems/RenderSystem.cpp
        src/game/systems/EnemyAISystem.cpp
    )
    target_link_libraries(retrofps_game PUBLIC retrofps_level retrofps_engine retrofps_math)
    target_include_directories(retrofps_game PUBLIC src)
    target_compile_features(retrofps_game PUBLIC cxx_std_17)
endif()

# === Game executable (requires SDL2; skipped if not found) ===
if(SDL2_AVAILABLE)
    add_executable(RetroFPS
        src/main.cpp
    )
    target_link_libraries(RetroFPS PRIVATE
        retrofps_game
        retrofps_level
        retrofps_engine
        retrofps_math
        SDL2::SDL2
        SDL2::SDL2main
        SDL2_mixer::SDL2_mixer
        SDL2_ttf::SDL2_ttf
    )
    target_include_directories(RetroFPS PRIVATE src)

    # v0.6.0 修复: Release 模式下也显示控制台窗口以便查看错误信息
    set_target_properties(RetroFPS PROPERTIES
        WIN32_EXECUTABLE FALSE
    )

    # Copy assets + DLLs + launch script next to executable
    if(WIN32)
        add_custom_command(TARGET RetroFPS POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_SOURCE_DIR}/assets"
                "$<TARGET_FILE_DIR:RetroFPS>/assets"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                $<TARGET_RUNTIME_DLLS:RetroFPS>
                $<TARGET_FILE_DIR:RetroFPS>
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/启动游戏.bat"
                "$<TARGET_FILE_DIR:RetroFPS>/启动游戏.bat"
            COMMAND_EXPAND_LISTS
        )
    endif()
else()
    message(WARNING "SDL2 not found — engine layer + game executable will not be built.")
    message(STATUS "  Math/Level layer + unit tests are fully functional.")
    message(STATUS "  Install SDL2 devel libraries and re-run CMake:")
    message(STATUS "    E:\\vcpkg\\vcpkg.exe install sdl2 sdl2-mixer sdl2-ttf --triplet x64-windows")
    message(STATUS "  Then: delete build/ and reconfigure.")
endif()
