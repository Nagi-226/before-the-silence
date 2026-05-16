# FindSDL2.cmake — 跨平台 SDL2 查找模块
#
# 定义 SDL2_ROOT 来指定安装目录，或确保 SDL2 在以下位置之一：
#   Windows: SDL2_ROOT, CMAKE_PREFIX_PATH, C:/SDL2, C:/SDL2-*
#   Linux:   标准系统路径
#
# 输出变量:
#   SDL2_FOUND          — 是否找到
#   SDL2_INCLUDE_DIR    — 头文件路径
#   SDL2_LIBRARY        — 库文件路径
#   SDL2::SDL2          — 导入目标
#   SDL2::SDL2main      — SDL2main 导入目标

if(TARGET SDL2::SDL2)
    return()
endif()

# —— 查找头文件 ——
find_path(SDL2_INCLUDE_DIR
    NAMES SDL.h
    PATH_SUFFIXES SDL2 include/SDL2
    HINTS
        ${SDL2_ROOT}
        ENV SDL2_ROOT
        ${CMAKE_PREFIX_PATH}
    PATHS
        C:/SDL2
        C:/SDL2-2*
        C:/SDL2*/
        "C:/Program Files/SDL2"
        /usr/local
        /usr
)

# —— 查找库文件 ——
if(WIN32 AND MSVC)
    set(SDL2_LIBNAME SDL2.lib)
elseif(WIN32 AND MINGW)
    set(SDL2_LIBNAME libSDL2.dll.a)
elseif(APPLE)
    set(SDL2_LIBNAME libSDL2.dylib)
else()
    set(SDL2_LIBNAME libSDL2.so)
endif()

find_library(SDL2_LIBRARY
    NAMES SDL2 ${SDL2_LIBNAME}
    PATH_SUFFIXES lib/x64 lib/x86 lib
    HINTS
        ${SDL2_ROOT}
        ENV SDL2_ROOT
        ${CMAKE_PREFIX_PATH}
    PATHS
        C:/SDL2
        C:/SDL2-2*
        C:/SDL2*/
        "C:/Program Files/SDL2"
        /usr/local
        /usr
)

# 查找 SDL2main（Windows 必需）
if(WIN32)
    find_library(SDL2_MAIN_LIBRARY
        NAMES SDL2main
        PATH_SUFFIXES lib/x64 lib/x86 lib
        HINTS
            ${SDL2_ROOT}
            ENV SDL2_ROOT
        PATHS
            C:/SDL2
            C:/SDL2-2*
            C:/SDL2*/
    )
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDL2
    REQUIRED_VARS SDL2_LIBRARY SDL2_INCLUDE_DIR
)

if(SDL2_FOUND AND NOT TARGET SDL2::SDL2)
    add_library(SDL2::SDL2 UNKNOWN IMPORTED)
    set_target_properties(SDL2::SDL2 PROPERTIES
        IMPORTED_LOCATION "${SDL2_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${SDL2_INCLUDE_DIR}"
    )
    if(WIN32)
        set_target_properties(SDL2::SDL2 PROPERTIES
            IMPORTED_IMPLIB "${SDL2_LIBRARY}"
        )
    endif()

    if(SDL2_MAIN_LIBRARY)
        add_library(SDL2::SDL2main UNKNOWN IMPORTED)
        set_target_properties(SDL2::SDL2main PROPERTIES
            IMPORTED_LOCATION "${SDL2_MAIN_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${SDL2_INCLUDE_DIR}"
        )
    endif()
endif()

mark_as_advanced(SDL2_INCLUDE_DIR SDL2_LIBRARY SDL2_MAIN_LIBRARY)
