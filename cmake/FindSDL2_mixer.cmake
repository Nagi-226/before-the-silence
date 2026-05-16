# FindSDL2_mixer.cmake — SDL2_mixer 查找模块

if(TARGET SDL2_mixer::SDL2_mixer)
    return()
endif()

find_path(SDL2_MIXER_INCLUDE_DIR
    NAMES SDL_mixer.h
    PATH_SUFFIXES SDL2 include/SDL2
    HINTS ${SDL2_ROOT} ENV SDL2_ROOT ${SDL2_MIXER_ROOT} ENV SDL2_MIXER_ROOT
    PATHS C:/SDL2_mixer C:/SDL2_mixer-* "C:/Program Files/SDL2_mixer"
)

if(WIN32 AND MSVC)
    set(SDL2_MIXER_LIBNAME SDL2_mixer.lib)
elseif(WIN32 AND MINGW)
    set(SDL2_MIXER_LIBNAME libSDL2_mixer.dll.a)
else()
    set(SDL2_MIXER_LIBNAME libSDL2_mixer.so)
endif()

find_library(SDL2_MIXER_LIBRARY
    NAMES SDL2_mixer ${SDL2_MIXER_LIBNAME}
    PATH_SUFFIXES lib/x64 lib/x86 lib
    HINTS ${SDL2_ROOT} ENV SDL2_ROOT ${SDL2_MIXER_ROOT} ENV SDL2_MIXER_ROOT
    PATHS C:/SDL2_mixer C:/SDL2_mixer-* "C:/Program Files/SDL2_mixer"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDL2_mixer
    REQUIRED_VARS SDL2_MIXER_LIBRARY SDL2_MIXER_INCLUDE_DIR
)

if(SDL2_mixer_FOUND AND NOT TARGET SDL2_mixer::SDL2_mixer)
    add_library(SDL2_mixer::SDL2_mixer UNKNOWN IMPORTED)
    set_target_properties(SDL2_mixer::SDL2_mixer PROPERTIES
        IMPORTED_LOCATION "${SDL2_MIXER_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${SDL2_MIXER_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(SDL2_MIXER_INCLUDE_DIR SDL2_MIXER_LIBRARY)
