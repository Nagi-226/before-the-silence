#pragma once
#include "SDL2/SDL.h"
#include <string>
#include <unordered_map>

#include "SDL2/SDL_ttf.h"

/// SDL2 渲染封装 — 管理 SDL_Renderer + 离屏渲染目标 + 字体。
/// 内部分辨率 240×135，渲染到离屏纹理后放大到窗口。
/// 热路径方法不分配内存（预分配缓冲区）。
class Renderer
{
public:
    static constexpr int INTERNAL_WIDTH = 240;
    static constexpr int INTERNAL_HEIGHT = 135;

    /// @param window SDL_Window（Renderer 不负责其生命周期）
    /// @param windowWidth 窗口实际宽度
    /// @param windowHeight 窗口实际高度
    Renderer(SDL_Window* window, int windowWidth, int windowHeight);
    ~Renderer();

    // 禁止拷贝
    Renderer(const Renderer&) = delete;
    Renderer& operator=(const Renderer&) = delete;

    // —— 渲染流程 ——
    /// 切换渲染目标为离屏纹理，清除为黑色
    void beginFrame();
    /// 将离屏纹理缩放到窗口并呈现
    void endFrame();

    // —— 绘制基元 ——
    /// 设置绘制颜色
    void setColor(Uint8 r, Uint8 g, Uint8 b, Uint8 a = 255);
    /// 填充矩形（内部坐标）
    void fillRect(int x, int y, int w, int h);
    /// 绘制竖线（核心伪3D渲染操作，热路径）
    void drawVerticalLine(int x, int yTop, int height);

    // —— 纹理操作 ——
    /// 复制纹理到指定位置
    void copyTexture(SDL_Texture* texture, const SDL_Rect* srcRect, const SDL_Rect* dstRect);
    /// 设置纹理颜色调制（用于距离阴影着色）
    void setTextureColorMod(SDL_Texture* texture, Uint8 r, Uint8 g, Uint8 b);
    /// 创建流式纹理（用于 CPU 端逐像素更新）
    SDL_Texture* createStreamingTexture(int w, int h);
    /// 更新流式纹理像素数据
    void updateTexture(SDL_Texture* texture, const void* pixels, int pitch);

    // —— 字体 ——
    /// 加载字体（走回退链: 微软雅黑→黑体→宋体→思源黑体）
    /// @param fontSize 字号
    /// @return 字体指针，失败返回 nullptr
    TTF_Font* loadFont(int fontSize);
    /// 渲染 UTF-8 中文文字到纹理
    /// @return 文字纹理（调用者不负责释放，由字体系统管理）
    SDL_Texture* renderText(TTF_Font* font, const std::string& text, SDL_Color color);

    // —— 查询 ——
    SDL_Renderer* getSDLRenderer() { return m_renderer; }
    int getWindowWidth() const { return m_windowWidth; }
    int getWindowHeight() const { return m_windowHeight; }

private:
    SDL_Renderer* m_renderer = nullptr;
    SDL_Texture* m_textureScreen = nullptr;  // 240×135 离屏渲染目标
    int m_windowWidth;
    int m_windowHeight;

    // 字体缓存：{fontSize → TTF_Font*}
    std::unordered_map<int, TTF_Font*> m_fontCache;

    // 文字纹理缓存：{key → SDL_Texture*}（复用，避免每帧创建）
    std::unordered_map<std::string, SDL_Texture*> m_textCache;

    TTF_Font* tryLoadFont(const std::string& path, int fontSize);
    void releaseFonts();
    void releaseTextCache();
};
