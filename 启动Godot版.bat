@echo off
chcp 65001 >nul
title Before the Silence - Godot Edition
cd /d "%~dp0"

echo.
echo    ============================================
echo      Before the Silence  -  Godot Remake
echo      WASD move / Mouse aim / LMB shoot
echo      R reload / Q or Wheel switch weapon / ESC menu
echo    ============================================
echo.

set "GODOT_EXE="

:: 1) Real exe in WinGet Packages (package dirs are symlinks - for /d matches names without following)
for /d %%d in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do (
    for /f "delims=" %%i in ('dir /b "%%~d\Godot_v*-stable_win64.exe" 2^>nul') do set "GODOT_EXE=%%~d\%%~i"
)

:: 2) Fallback: godot on PATH (WinGet link shim)
if not defined GODOT_EXE (
    for /f "delims=" %%i in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%i"
)

if not defined GODOT_EXE (
    echo    [ERROR] Godot engine not found.
    echo    Install it with:  winget install GodotEngine.GodotEngine
    echo    Or edit this file and set GODOT_EXE to your Godot.exe path.
    pause
    exit /b 1
)

echo    Engine: %GODOT_EXE%
echo    Launching...
start "" "%GODOT_EXE%" --path "%~dp0godot"
