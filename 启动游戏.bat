@echo off
chcp 65001 >nul
title 复古FPS v0.6.0
cd /d "%~dp0"

echo.
echo    ╔═══════════════════════════╗
echo    ║   复古 FPS  v0.6.0      ║
echo    ║   Retro Pseudo-3D FPS   ║
echo    ╚═══════════════════════════╝
echo.
echo    controls:
echo      W A S D  - Move
echo      Mouse    - Look
echo      LeftClick- Shoot
echo      R        - Reload
echo      ESC      - Quit
echo.

:: 优先使用 Release 版本, 不存在则尝试 Debug 版本
if exist "build\Release\RetroFPS.exe" (
    echo    Launching Release build...
    start "" "build\Release\RetroFPS.exe"
) else if exist "build\Debug\RetroFPS.exe" (
    echo    Launching Debug build...
    start "" "build\Debug\RetroFPS.exe"
) else (
    echo    [ERROR] RetroFPS.exe not found!
    echo    Please build the project first:
    echo      cmake --build build --config Release --target RetroFPS
    pause
)
