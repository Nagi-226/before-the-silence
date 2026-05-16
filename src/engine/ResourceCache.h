#pragma once
#include "SDL2/SDL.h"
#include "SDL2/SDL_mixer.h"
#include "SDL2/SDL_ttf.h"
#include <string>
#include <unordered_map>

/// 统一资源缓存 — 纹理/音效/字体加载、缓存、RAII 释放。
/// 同一个文件只加载一次，后续请求返回缓存。
///
/// 使用示例:
///   ResourceCache cache(renderer);
///   cache.loadTexture("Crosshair.bmp");
///   // ...
///   SDL_Texture* tex = cache.getTexture("Crosshair.bmp");
class ResourceCache
{
public:
    explicit ResourceCache(SDL_Renderer* renderer);
    ~ResourceCache();

    ResourceCache(const ResourceCache&) = delete;
    ResourceCache& operator=(const ResourceCache&) = delete;

    // —— 纹理 ——
    /// 加载 BMP 纹理（自动缓存）
    SDL_Texture* loadTexture(const std::string& filename);
    /// 获取已加载的纹理（未加载返回 nullptr）
    SDL_Texture* getTexture(const std::string& filename) const;

    // —— 音效 ——
    /// 加载 OGG 音效（自动缓存）
    Mix_Chunk* loadSound(const std::string& filename);
    /// 获取已加载的音效（未加载返回 nullptr）
    Mix_Chunk* getSound(const std::string& filename) const;

    // —— 字体 ——
    /// 加载字体（走 Renderer 的回退链）
    TTF_Font* loadFont(const std::string& filename, int fontSize);
    /// 获取已加载的字体（未加载返回 nullptr）
    TTF_Font* getFont(const std::string& filename, int fontSize) const;

    // —— 批量操作 ——
    /// 释放指定类型的所有资源
    void unloadTextures();
    void unloadSounds();
    void unloadFonts();
    /// 释放所有资源
    void unloadAll();

private:
    SDL_Renderer* m_renderer;

    std::unordered_map<std::string, SDL_Texture*> m_textures;
    std::unordered_map<std::string, Mix_Chunk*> m_sounds;
    std::unordered_map<std::string, TTF_Font*> m_fonts;  // key = "filename:size"

    std::string makeFontKey(const std::string& filename, int fontSize) const;
};
