#pragma once
#include "game/entities/Player.h"
#include "game/entities/Enemy.h"
#include "game/entities/Projectile.h"
#include "game/entities/Pickup.h"
#include "game/Level.h"
#include "engine/Renderer.h"
#include "engine/ResourceCache.h"
#include <vector>
#include <memory>

class GameConfig;
class ParticleSystem;

/// DDA 光线投射结果。
struct RaycastResult {
    float distance = -1.0f;
    float colorFactor = 1.0f;
    bool hitXSide = false;
    float hitX = 0.0f, hitY = 0.0f;
    WallMaterial material = WallMaterial::Brick;
};

/// 弹痕贴花 — 子弹击中墙壁留下的标记。
struct BulletDecal {
    Vector2D worldPos;
    int screenX;
    float distance;
    float lifetime = 5.0f;
};

/// 渲染系统 — 伪3D 核心渲染管线。
class RenderSystem
{
public:
    static constexpr int WORLD_WIDTH = 240;
    static constexpr int WORLD_HEIGHT = 135;
    static constexpr float FOV_RAD = 3.14159265359f / 3.0f;

    /// 全局开关
    static bool s_texturedWalls;
    static bool s_texturedFloors;
    static bool s_animatedEnemies;
    static bool s_dynamicLights;
    static bool s_particles;
    static bool s_weather;
    static bool s_underwaterFX;
    static bool s_yShear;
    static bool s_wallHeightVariation;  // v0.4.1
    static bool s_cloudSkybox;          // v0.4.2
    static bool s_weaponModel;          // v0.4.4

    RenderSystem(ResourceCache& cache, const GameConfig& config, ParticleSystem& particles);
    ~RenderSystem();

    void render(Renderer& renderer, const Player& player,
                const std::vector<std::unique_ptr<Enemy>>& enemies,
                const std::vector<std::unique_ptr<Projectile>>& projectiles,
                const std::vector<std::unique_ptr<Pickup>>& pickups,
                float dT);

    /// v0.3.4 添加弹痕
    void addBulletDecal(Vector2D worldPos, float distance, int screenX);
    std::vector<BulletDecal>& getDecals() { return s_decals; }

    /// v0.4.7 添加弹道拖尾
    void addTracer(Vector2D from, Vector2D to);

private:
    // —— 光线投射 ——
    RaycastResult raycast(Vector2D start, Vector2D dir);

    // —— 天空 + 地面 ——
    void drawSkyGradient(Renderer& renderer);
    void drawTexturedFloor(const Player& player);
    void drawTexturedCeiling();

    // —— 墙壁 ——
    void drawWalls(Renderer& renderer, const Player& player, float listDepth[]);
    void drawWallColumn(Renderer& renderer, int x, const RaycastResult& hit,
                        int yTop, int height, float shade);
    Uint8 getShadeLevel(float distance, float colorFactor);

    // —— 雾 ——
    void applyDistanceFog(Renderer& renderer, const float listDepth[]);

    // —— 精灵 ——
    void drawSprites(Renderer& renderer, const Player& player,
                     const std::vector<std::unique_ptr<Enemy>>& enemies,
                     const std::vector<std::unique_ptr<Pickup>>& pickups,
                     const float listDepth[]);

    // —— 弹痕贴花 ——
    void drawDecals(Renderer& renderer, float dT);

    // —— 动态光照 ——
    void applyDynamicLighting(Renderer& renderer, const Player& player, float dT);

    // —— 后处理 ——
    void applyHurtVignette(Renderer& renderer, const Player& player);
    void applyMuzzleFlash(Renderer& renderer, const Player& player);

    // —— HUD + 小地图 ——
    void drawHUD(Renderer& renderer, const Player& player);
    void drawMinimap(Renderer& renderer, const Player& player,
                     const std::vector<std::unique_ptr<Enemy>>& enemies,
                     const std::vector<std::unique_ptr<Pickup>>& pickups);

    // —— 帮助函数 ——
    static SDL_Color lerpColor(SDL_Color a, SDL_Color b, float t);
    // 精灵投影：角度差 + 距离 → 屏幕X + 屏幕尺寸
    static void projectToScreen(float diff, float dist, float& screenX, float& screenSize);

    // —— 粒子渲染 ——
    void drawParticles(Renderer& renderer, const Player& player, float dT);
    // —— 天气 ——
    void drawWeather(Renderer& renderer, float dT);
    // —— 水下/毒气 ——
    void applyUnderwaterFX(Renderer& renderer, const Player& player, float dT);
    // —— Y-shearing ——
    void applyYShear(Renderer& renderer, const Player& player);
    // —— v0.4.2 云层天空盒 (v0.6.1: +pitch) ——
    void drawCloudSkybox(Renderer& renderer, float dT, const Player& player);
    // —— v0.4.4 武器模型（只读渲染，动画更新在游戏逻辑侧） ——
    void drawWeaponModel(Renderer& renderer, const Player& player);
    // —— v0.4.7 弹道拖尾 ——
    void drawTracers(Renderer& renderer, const Player& player, float dT);
    // —— v0.4.6 游戏状态 ——
    void drawGameOverlay(Renderer& renderer, const Player& player);

    // 配置引用
    const GameConfig& m_config;
    ParticleSystem& m_particles;

    // —— 静态纹理资源 ——
    static SDL_Texture* s_texBrick;
    static SDL_Texture* s_texMetal;
    static SDL_Texture* s_texStone;
    static SDL_Texture* s_texGrate;
    static SDL_Texture* s_texFloor;
    static SDL_Texture* s_texCeiling;
    static SDL_Texture* s_texCloud;    // v0.4.2
    static SDL_Texture* s_texWeapon;   // v0.4.4

    // —— 弹痕贴花 ——
    static std::vector<BulletDecal> s_decals;

    // —— 光闪烁相位 ——
    float m_lightFlickerPhase = 0.0f;
    // —— 天气相位 ——
    float m_weatherPhase = 0.0f;
    // —— v0.4.2 云层偏移 ——
    float m_cloudOffset = 0.0f;
    float m_distortionPhase = 0.0f;  // 水下扭曲相位

    // —— 预分配缓冲区（热路径复用） ——
    struct SpriteEntry {
        Vector2D pos; float dist; float diff;
        Uint8 r, g, b; float size; float bobY;
        bool isPickup;
        SDL_Texture* tex = nullptr; // v0.6.2: 敌人纹理精灵表
        int animFrame = 0;          // v0.6.2: 当前动画帧
        bool isDead = false;        // v0.6.2: 尸体淡出
        float fadeAlpha = 1.0f;     // v0.6.2: 透明度
    };
    std::vector<SpriteEntry> m_spriteBuffer;
    std::vector<Uint32> m_pixelBuffer;
    SDL_Texture* m_floorCeilTex = nullptr;
    float m_cosLUT[240] = {};
    float m_sinLUT[240] = {};
    bool m_lutInitialized = false;

    // —— 小地图预计算墙壁网格 (v0.6.1: 增大尺寸) ——
    // v0.6.2: 修正宽高比，MM_W/MM_H 与 Level WIDTH/HEIGHT 比例一致 (168:68 ≈ 2.47:1)
    static constexpr int MM_W = 68, MM_H = 28;
    bool m_minimapWalls[MM_W * MM_H] = {};
    bool m_minimapReady = false;
    void initMinimapGrid();

    // —— v0.6.2 敌人精灵纹理 ——
    static SDL_Texture* s_texAlienSmall;
    static SDL_Texture* s_texAlienMedium;
    static SDL_Texture* s_texAlienLarge;
};

// 声明全局纹理和弹痕的存储
inline bool RenderSystem::s_texturedWalls = true;
inline bool RenderSystem::s_texturedFloors = true;
inline bool RenderSystem::s_animatedEnemies = true;
inline bool RenderSystem::s_dynamicLights = false;
inline bool RenderSystem::s_particles = true;
inline bool RenderSystem::s_weather = true;
inline bool RenderSystem::s_underwaterFX = true;
inline bool RenderSystem::s_yShear = false;
inline bool RenderSystem::s_wallHeightVariation = true;
inline bool RenderSystem::s_cloudSkybox = true;
inline bool RenderSystem::s_weaponModel = true;
inline SDL_Texture* RenderSystem::s_texBrick = nullptr;
inline SDL_Texture* RenderSystem::s_texMetal = nullptr;
inline SDL_Texture* RenderSystem::s_texStone = nullptr;
inline SDL_Texture* RenderSystem::s_texGrate = nullptr;
inline SDL_Texture* RenderSystem::s_texFloor = nullptr;
inline SDL_Texture* RenderSystem::s_texCeiling = nullptr;
inline SDL_Texture* RenderSystem::s_texCloud = nullptr;
inline SDL_Texture* RenderSystem::s_texWeapon = nullptr;
inline SDL_Texture* RenderSystem::s_texAlienSmall = nullptr;
inline SDL_Texture* RenderSystem::s_texAlienMedium = nullptr;
inline SDL_Texture* RenderSystem::s_texAlienLarge = nullptr;
inline std::vector<BulletDecal> RenderSystem::s_decals;
