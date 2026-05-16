# setup_sdl2.ps1 — 下载 SDL2 开发库到 vendor/ 目录
# 使用方法: .\scripts\setup_sdl2.ps1

$ErrorActionPreference = "Stop"
$vendorDir = Join-Path (Join-Path $PSScriptRoot "..") "vendor"
New-Item -ItemType Directory -Force -Path $vendorDir | Out-Null

# SDL2 版本与下载 URL
$downloads = @(
    @{
        Name = "SDL2"
        Url = "https://github.com/libsdl-org/SDL/releases/download/release-2.30.3/SDL2-devel-2.30.3-VC.zip"
        Dir = "SDL2-2.30.3"
    },
    @{
        Name = "SDL2_mixer"
        Url = "https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.0/SDL2_mixer-devel-2.8.0-VC.zip"
        Dir = "SDL2_mixer-2.8.0"
    },
    @{
        Name = "SDL2_ttf"
        Url = "https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.22.0/SDL2_ttf-devel-2.22.0-VC.zip"
        Dir = "SDL2_ttf-2.22.0"
    }
)

foreach ($pkg in $downloads) {
    $zipPath = Join-Path $vendorDir "$($pkg.Name).zip"
    $extractPath = Join-Path $vendorDir $pkg.Dir

    if (Test-Path $extractPath) {
        Write-Host "[SKIP] $($pkg.Name) already exists at $extractPath"
        continue
    }

    Write-Host "[DOWNLOAD] $($pkg.Name) from $($pkg.Url)"
    try {
        Invoke-WebRequest -Uri $pkg.Url -OutFile $zipPath -UseBasicParsing
    }
    catch {
        Write-Warning "Failed to download $($pkg.Name): $_"
        Write-Host "Please download manually from: $($pkg.Url)"
        Write-Host "Extract the 'include' and 'lib' folders to: $extractPath"
        continue
    }

    Write-Host "[EXTRACT] $zipPath"
    Expand-Archive -Path $zipPath -DestinationPath $vendorDir -Force

    # The ZIP has an inner folder structure: SDL2-2.x.x/
    $innerDir = Get-ChildItem -Path $vendorDir -Directory | Where-Object { $_.Name -like "SDL*" -and $_.Name -ne $pkg.Dir } | Select-Object -First 1
    if ($innerDir -and $innerDir.FullName -ne $extractPath) {
        Move-Item -Path $innerDir.FullName -Destination $extractPath -Force
    }

    Remove-Item $zipPath -Force
    Write-Host "[OK] $($pkg.Name) installed to $extractPath"
}

Write-Host ""
Write-Host "=== Setup Complete ==="
Write-Host "Set SDL2_ROOT environment variable or pass to CMake:"
Write-Host "  `$env:SDL2_ROOT = '$vendorDir\SDL2-2.30.3'"
Write-Host "  cmake -B build -DSDL2_ROOT='$vendorDir\SDL2-2.30.3' ..."
