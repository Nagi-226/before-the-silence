cmake_minimum_required(VERSION 3.20)
project(RetroFirstPersonShooter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# For single-config generators (Ninja/Makefiles)
if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

find_package(SDL2 CONFIG REQUIRED)
find_package(SDL2_mixer CONFIG REQUIRED)
find_package(SDL2_ttf CONFIG REQUIRED)

set(SOURCES
  main.cpp
  Game.cpp
  UnitPlayer.cpp
  UnitEnemy.cpp
  Weapon.cpp
  Level.cpp
  MathAddon.cpp
  Sprite.cpp
  Vector2D.cpp
  Projectile.cpp
  Pickup.cpp
  Unit.cpp
  SoundLoader.cpp
  Timer.cpp
  Ammo.cpp
  UpgradeAmmo.cpp
  UpgradeWeaponSpeed.cpp
  UpgradeHealth.cpp
  Coin.cpp
  Health.cpp
  TextureLoader.cpp
)

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(${PROJECT_NAME} PRIVATE
  SDL2::SDL2
  SDL2::SDL2main
  $<$<TARGET_EXISTS:SDL2_mixer::SDL2_mixer>:SDL2_mixer::SDL2_mixer>
  $<$<TARGET_EXISTS:SDL2_mixer::SDL2_mixer-static>:SDL2_mixer::SDL2_mixer-static>
  $<$<TARGET_EXISTS:SDL2_ttf::SDL2_ttf>:SDL2_ttf::SDL2_ttf>
  $<$<TARGET_EXISTS:SDL2_ttf::SDL2_ttf-static>:SDL2_ttf::SDL2_ttf-static>
)

if(MSVC)
  target_compile_options(${PROJECT_NAME} PRIVATE /utf-8)
endif()

# Copy runtime DLLs (including SDL2_ttf.dll) next to the executable.
if(WIN32)
  add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      $<TARGET_RUNTIME_DLLS:${PROJECT_NAME}>
      $<TARGET_FILE_DIR:${PROJECT_NAME}>
    COMMAND_EXPAND_LISTS
  )
endif()
