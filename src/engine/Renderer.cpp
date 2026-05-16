#include "engine/Renderer.h"
#include "SDL2/SDL_ttf.h"
#include <iostream>
#include <vector>

Renderer::Renderer(SDL_Window* window, int windowWidth, int windowHeight)
    : m_windowWidth(windowWidth)
    , m_windowHeight(windowHeight)
{
    m_renderer = SDL_CreateRenderer(window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_TARGETTEXTURE | SDL_RENDERER_PRESENTVSYNC);
    if (!m_renderer) {
        std::cerr << "Renderer: SDL_CreateRenderer failed: " << SDL_GetError() << std::endl;
        return;
    }
    SDL_SetRenderDrawBlendMode(m_renderer, SDL_BLENDMODE_BLEND);

    // 创建离屏渲染目标（240×135 内部分辨率）
    m_textureScreen = SDL_CreateTexture(m_renderer,
        SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_TARGET,
        INTERNAL_WIDTH, INTERNAL_HEIGHT);
    if (!m_textureScreen) {
        std::cerr << "Renderer: SDL_CreateTexture(screen) failed: " << SDL_GetError() << std::endl;
    }
    SDL_SetTextureBlendMode(m_textureScreen, SDL_BLENDMODE_BLEND);

    SDL_RendererInfo info;
    SDL_GetRendererInfo(m_renderer, &info);
    std::cout << "Renderer: " << info.name << " (" << INTERNAL_WIDTH << "x" << INTERNAL_HEIGHT << ")" << std::endl;
}

Renderer::~Renderer() {
    releaseTextCache();
    releaseFonts();
    if (m_textureScreen) SDL_DestroyTexture(m_textureScreen);
    if (m_renderer) SDL_DestroyRenderer(m_renderer);
}

// —— 渲染流程 ——

void Renderer::beginFrame() {
    if (!m_renderer || !m_textureScreen) return;
    // 切换到离屏渲染目标并清除
    SDL_SetRenderTarget(m_renderer, m_textureScreen);
    SDL_SetRenderDrawColor(m_renderer, 0, 0, 0, 255);
    SDL_RenderClear(m_renderer);
}

void Renderer::endFrame() {
    if (!m_textureScreen) return;  // 离屏纹理未创建，跳过渲染

    SDL_SetRenderTarget(m_renderer, nullptr);
    SDL_Rect dstRect = { 0, 0, m_windowWidth, m_windowHeight };
    SDL_RenderCopy(m_renderer, m_textureScreen, nullptr, &dstRect);
    SDL_RenderPresent(m_renderer);
}

// —— 绘制基元 ——

void Renderer::setColor(Uint8 r, Uint8 g, Uint8 b, Uint8 a) {
    SDL_SetRenderDrawColor(m_renderer, r, g, b, a);
}

void Renderer::fillRect(int x, int y, int w, int h) {
    SDL_Rect rect = { x, y, w, h };
    SDL_RenderFillRect(m_renderer, &rect);
}

void Renderer::drawVerticalLine(int x, int yTop, int height) {
    // 热路径 — 无分配，直接调用 SDL
    SDL_Rect rect = { x, yTop, 1, height };
    SDL_RenderFillRect(m_renderer, &rect);
}

// —— 纹理操作 ——

void Renderer::copyTexture(SDL_Texture* texture, const SDL_Rect* srcRect, const SDL_Rect* dstRect) {
    SDL_RenderCopy(m_renderer, texture, srcRect, dstRect);
}

void Renderer::setTextureColorMod(SDL_Texture* texture, Uint8 r, Uint8 g, Uint8 b) {
    SDL_SetTextureColorMod(texture, r, g, b);
}

SDL_Texture* Renderer::createStreamingTexture(int w, int h) {
    return SDL_CreateTexture(m_renderer, SDL_PIXELFORMAT_ABGR8888,
                             SDL_TEXTUREACCESS_STREAMING, w, h);
}

void Renderer::updateTexture(SDL_Texture* texture, const void* pixels, int pitch) {
    SDL_UpdateTexture(texture, nullptr, pixels, pitch);
}

// —— 字体 ——

TTF_Font* Renderer::tryLoadFont(const std::string& path, int fontSize) {
    TTF_Font* font = TTF_OpenFont(path.c_str(), fontSize);
    if (font) {
        std::cout << "Renderer: loaded font " << path << " (" << fontSize << "pt)" << std::endl;
    }
    return font;
}

TTF_Font* Renderer::loadFont(int fontSize) {
    // 检查缓存
    auto it = m_fontCache.find(fontSize);
    if (it != m_fontCache.end()) return it->second;

    TTF_Font* font = nullptr;

    // 中文字体回退链（static const 避免每帧分配）
    static const std::vector<std::string> candidates = {
        "C:/Windows/Fonts/msyh.ttc",       // 微软雅黑
        "C:/Windows/Fonts/msyhbd.ttc",     // 微软雅黑粗体
        "C:/Windows/Fonts/simhei.ttf",     // 黑体
        "C:/Windows/Fonts/simsun.ttc",     // 宋体
        "assets/fonts/NotoSansSC-Regular.otf"  // 思源黑体
    };

    for (const auto& path : candidates) {
        font = tryLoadFont(path, fontSize);
        if (font) break;
    }

    if (!font) {
        std::cerr << "Renderer: failed to load any font at size " << fontSize << std::endl;
        return nullptr;
    }

    m_fontCache[fontSize] = font;
    return font;
}

SDL_Texture* Renderer::renderText(TTF_Font* font, const std::string& text, SDL_Color color) {
    if (!font || text.empty()) return nullptr;

    // 检查缓存
    std::string cacheKey = std::to_string(reinterpret_cast<uintptr_t>(font))
        + ":" + text + ":" + std::to_string(color.r) + "," + std::to_string(color.g) + "," + std::to_string(color.b);
    auto it = m_textCache.find(cacheKey);
    if (it != m_textCache.end()) return it->second;

    // 渲染 UTF-8 文字
    SDL_Surface* surface = TTF_RenderUTF8_Blended(font, text.c_str(), color);
    if (!surface) return nullptr;

    SDL_Texture* texture = SDL_CreateTextureFromSurface(m_renderer, surface);
    SDL_FreeSurface(surface);
    if (!texture) return nullptr;

    m_textCache[cacheKey] = texture;
    return texture;
}

void Renderer::releaseFonts() {
    for (auto& pair : m_fontCache) {
        TTF_CloseFont(pair.second);
    }
    m_fontCache.clear();
}

void Renderer::releaseTextCache() {
    for (auto& pair : m_textCache) {
        SDL_DestroyTexture(pair.second);
    }
    m_textCache.clear();
}
