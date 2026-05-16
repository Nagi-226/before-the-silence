# FindSDL2_ttf.cmake — SDL2_ttf 查找模块

if(TARGET SDL2_ttf::SDL2_ttf)
    return()
endif()

find_path(SDL2_TTF_INCLUDE_DIR
    NAMES SDL_ttf.h
    PATH_SUFFIXES SDL2 include/SDL2
    HINTS ${SDL2_ROOT} ENV SDL2_ROOT ${SDL2_TTF_ROOT} ENV SDL2_TTF_ROOT
    PATHS C:/SDL2_ttf C:/SDL2_ttf-* "C:/Program Files/SDL2_ttf"
)

if(WIN32 AND MSVC)
    set(SDL2_TTF_LIBNAME SDL2_ttf.lib)
elseif(WIN32 AND MINGW)
    set(SDL2_TTF_LIBNAME libSDL2_ttf.dll.a)
else()
    set(SDL2_TTF_LIBNAME libSDL2_ttf.so)
endif()

find_library(SDL2_TTF_LIBRARY
    NAMES SDL2_ttf ${SDL2_TTF_LIBNAME}
    PATH_SUFFIXES lib/x64 lib/x86 lib
    HINTS ${SDL2_ROOT} ENV SDL2_ROOT ${SDL2_TTF_ROOT} ENV SDL2_TTF_ROOT
    PATHS C:/SDL2_ttf C:/SDL2_ttf-* "C:/Program Files/SDL2_ttf"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDL2_ttf
    REQUIRED_VARS SDL2_TTF_LIBRARY SDL2_TTF_INCLUDE_DIR
)

if(SDL2_ttf_FOUND AND NOT TARGET SDL2_ttf::SDL2_ttf)
    add_library(SDL2_ttf::SDL2_ttf UNKNOWN IMPORTED)
    set_target_properties(SDL2_ttf::SDL2_ttf PROPERTIES
        IMPORTED_LOCATION "${SDL2_TTF_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${SDL2_TTF_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(SDL2_TTF_INCLUDE_DIR SDL2_TTF_LIBRARY)
