#include "engine/ResourceCache.h"
#include "SDL2/SDL_mixer.h"
#include "SDL2/SDL_ttf.h"
#include <iostream>

ResourceCache::ResourceCache(SDL_Renderer* renderer)
    : m_renderer(renderer)
{
}

ResourceCache::~ResourceCache() {
    unloadAll();
}

// —— 纹理 ——

SDL_Texture* ResourceCache::loadTexture(const std::string& filename) {
    auto it = m_textures.find(filename);
    if (it != m_textures.end()) {
        return it->second;  // 已缓存
    }

    // 尝试从多个路径加载
    const std::vector<std::string> paths = {
        "assets/images/" + filename,
        filename
    };

    SDL_Surface* surface = nullptr;
    for (const auto& path : paths) {
        surface = SDL_LoadBMP(path.c_str());
        if (surface) {
            std::cout << "ResourceCache: loaded texture " << path << std::endl;
            break;
        }
    }

    if (!surface) {
        std::cerr << "ResourceCache: failed to load texture " << filename
                  << " - " << SDL_GetError() << std::endl;
        return nullptr;
    }

    SDL_Texture* texture = SDL_CreateTextureFromSurface(m_renderer, surface);
    SDL_FreeSurface(surface);

    if (!texture) {
        std::cerr << "ResourceCache: failed to create texture from " << filename << std::endl;
        return nullptr;
    }

    m_textures[filename] = texture;
    return texture;
}

SDL_Texture* ResourceCache::getTexture(const std::string& filename) const {
    auto it = m_textures.find(filename);
    return (it != m_textures.end()) ? it->second : nullptr;
}

// —— 音效 ——

Mix_Chunk* ResourceCache::loadSound(const std::string& filename) {
    auto it = m_sounds.find(filename);
    if (it != m_sounds.end()) {
        return it->second;
    }

    const std::vector<std::string> paths = {
        "assets/sounds/" + filename,
        filename
    };

    Mix_Chunk* chunk = nullptr;
    for (const auto& path : paths) {
        chunk = Mix_LoadWAV(path.c_str());
        if (chunk) {
            std::cout << "ResourceCache: loaded sound " << path << std::endl;
            break;
        }
    }

    if (!chunk) {
        std::cerr << "ResourceCache: failed to load sound " << filename
                  << " - " << Mix_GetError() << std::endl;
        return nullptr;
    }

    m_sounds[filename] = chunk;
    return chunk;
}

Mix_Chunk* ResourceCache::getSound(const std::string& filename) const {
    auto it = m_sounds.find(filename);
    return (it != m_sounds.end()) ? it->second : nullptr;
}

// —— 字体 ——

std::string ResourceCache::makeFontKey(const std::string& filename, int fontSize) const {
    return filename + ":" + std::to_string(fontSize);
}

TTF_Font* ResourceCache::loadFont(const std::string& filename, int fontSize) {
    std::string key = makeFontKey(filename, fontSize);
    auto it = m_fonts.find(key);
    if (it != m_fonts.end()) {
        return it->second;
    }

    TTF_Font* font = TTF_OpenFont(filename.c_str(), fontSize);
    if (!font) {
        std::cerr << "ResourceCache: failed to load font " << filename
                  << " size " << fontSize << " - " << TTF_GetError() << std::endl;
        return nullptr;
    }

    std::cout << "ResourceCache: loaded font " << filename << " (" << fontSize << "pt)" << std::endl;
    m_fonts[key] = font;
    return font;
}

TTF_Font* ResourceCache::getFont(const std::string& filename, int fontSize) const {
    std::string key = makeFontKey(filename, fontSize);
    auto it = m_fonts.find(key);
    return (it != m_fonts.end()) ? it->second : nullptr;
}

// —— 批量操作 ——

void ResourceCache::unloadTextures() {
    for (auto& pair : m_textures) {
        SDL_DestroyTexture(pair.second);
    }
    m_textures.clear();
}

void ResourceCache::unloadSounds() {
    for (auto& pair : m_sounds) {
        Mix_FreeChunk(pair.second);
    }
    m_sounds.clear();
}

void ResourceCache::unloadFonts() {
    for (auto& pair : m_fonts) {
        TTF_CloseFont(pair.second);
    }
    m_fonts.clear();
}

void ResourceCache::unloadAll() {
    unloadTextures();
    unloadSounds();
    unloadFonts();
}
