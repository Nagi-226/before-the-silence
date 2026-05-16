#include "game/systems/RenderSystem.h"
#include "game/systems/ParticleSystem.h"
#include "game/GameConfig.h"
#include "math/MathAddon.h"
#include <cmath>
#include <algorithm>

// 前置声明（定义在文件后半部分）
static void flushFloorCeiling(Renderer& renderer, SDL_Texture*& tex,
                               std::vector<Uint32>& pixelBuffer);

// ============================================================================
//  构造 / 析构
// ============================================================================

RenderSystem::RenderSystem(ResourceCache& cache, const GameConfig& config, ParticleSystem& particles)
    : m_config(config)
    , m_particles(particles)
{
    s_texBrick   = cache.loadTexture("Wall Brick.bmp");
    s_texMetal   = cache.loadTexture("Wall Metal.bmp");
    s_texStone   = cache.loadTexture("Wall Stone.bmp");
    s_texGrate   = cache.loadTexture("Wall Grate.bmp");
    s_texFloor   = cache.loadTexture("Floor Tile.bmp");
    s_texCeiling = cache.loadTexture("Ceiling.bmp");
    m_spriteBuffer.reserve(64);
    m_pixelBuffer.resize(WORLD_WIDTH * WORLD_HEIGHT);
}

RenderSystem::~RenderSystem() {
    if (m_floorCeilTex) SDL_DestroyTexture(m_floorCeilTex);
}

static void initCosSinLUT(float dirX0, float dirX1, float* cosLUT, float* sinLUT) {
    for (int x = 0; x < RenderSystem::WORLD_WIDTH; ++x) {
        float angle = dirX0 + (x + 0.5f) * (dirX1 - dirX0) / RenderSystem::WORLD_WIDTH;
        cosLUT[x] = std::cos(angle);
        sinLUT[x] = std::sin(angle);
    }
}

// ============================================================================
//  弹痕贴花
// ============================================================================

void RenderSystem::addBulletDecal(Vector2D worldPos, float distance, int screenX) {
    if (s_decals.size() > static_cast<size_t>(m_config.game.maxDecals)) {
        s_decals.erase(s_decals.begin());
    }
    s_decals.push_back({worldPos, screenX, distance, m_config.game.decalLifetime});
}

// ============================================================================
//  主渲染入口
// ============================================================================

void RenderSystem::render(Renderer& renderer, const Player& player,
                           const std::vector<std::unique_ptr<Enemy>>& enemies,
                           const std::vector<std::unique_ptr<Projectile>>& /*projectiles*/,
                           const std::vector<std::unique_ptr<Pickup>>& pickups,
                           float dT) {
    renderer.beginFrame();

    float listDepth[WORLD_WIDTH] = {};

    // 1. 天空 + 地面
    if (s_texturedFloors && s_texFloor) {
        drawTexturedCeiling(renderer, player);
        drawTexturedFloor(renderer, player);
        flushFloorCeiling(renderer, m_floorCeilTex, m_pixelBuffer);
    } else {
        drawSkyGradient(renderer);
    }

    // 2. 墙壁
    drawWalls(renderer, player, listDepth);

    // 3. 距离雾
    applyDistanceFog(renderer, listDepth);

    // 4. 弹痕贴花
    drawDecals(renderer, player, dT);

    // 5. 动态光照
    if (s_dynamicLights) {
        applyDynamicLighting(renderer, player, dT);
    }

    // 6. 粒子
    if (s_particles) {
        m_particles.update(dT);
        drawParticles(renderer, player, dT);
    }

    // 7. 天气
    if (s_weather) {
        drawWeather(renderer, dT);
    }

    // 8. 精灵
    drawSprites(renderer, player, enemies, pickups, listDepth, dT);

    // 9. 水下/毒气
    if (s_underwaterFX) {
        applyUnderwaterFX(renderer, player, dT);
    }

    // 10. 后处理
    applyHurtVignette(renderer, player);
    applyMuzzleFlash(renderer, player);

    // 11. Y-shearing
    if (s_yShear) {
        applyYShear(renderer, player);
    }

    // 12. HUD + 小地图
    drawHUD(renderer, player);
    drawMinimap(renderer, player, enemies, pickups);

    renderer.endFrame();
}

// ============================================================================
//  DDA 光线投射
// ============================================================================

RaycastResult RenderSystem::raycast(Vector2D start, Vector2D dir) {
    RaycastResult result;
    Vector2D deltaDist(std::abs(1.0f / dir.x), std::abs(1.0f / dir.y));

    int mapX = static_cast<int>(start.x), mapY = static_cast<int>(start.y);
    int stepX, stepY;
    Vector2D sideDist;

    if (dir.x < 0) { stepX = -1; sideDist.x = (start.x - mapX) * deltaDist.x; }
    else           { stepX =  1; sideDist.x = (mapX + 1.0f - start.x) * deltaDist.x; }
    if (dir.y < 0) { stepY = -1; sideDist.y = (start.y - mapY) * deltaDist.y; }
    else           { stepY =  1; sideDist.y = (mapY + 1.0f - start.y) * deltaDist.y; }

    int maxSteps = m_config.game.ddaMaxSteps;
    while (maxSteps-- > 0) {
        if (sideDist.x < sideDist.y) {
            sideDist.x += deltaDist.x; mapX += stepX;
            result.distance = sideDist.x - deltaDist.x;
            result.hitXSide = true;
        } else {
            sideDist.y += deltaDist.y; mapY += stepY;
            result.distance = sideDist.y - deltaDist.y;
            result.hitXSide = false;
        }
        if (Level::isWall(mapX, mapY)) {
            result.colorFactor = result.hitXSide ? 0.8f : 1.0f;
            result.hitX = start.x + dir.x * result.distance;
            result.hitY = start.y + dir.y * result.distance;
            result.material = Level::getWallMaterial(mapX, mapY);
            return result;
        }
    }
    result.distance = -1.0f;
    return result;
}

// ============================================================================
//  渐变天空
// ============================================================================

void RenderSystem::drawSkyGradient(Renderer& renderer) {
    int halfH = WORLD_HEIGHT / 2;
    SDL_Color skyTop{32, 40, 60, 255}, skyBot{100, 120, 160, 255};
    for (int y = 0; y < halfH; ++y) {
        float t = static_cast<float>(y) / (halfH - 1);
        SDL_Color c = lerpColor(skyTop, skyBot, t);
        renderer.setColor(c.r, c.g, c.b);
        renderer.fillRect(0, y, WORLD_WIDTH, 1);
    }
    renderer.setColor(64, 64, 64);
    renderer.fillRect(0, halfH, WORLD_WIDTH, halfH);
}

// ============================================================================
//  纹理地板/天花板
// ============================================================================

void RenderSystem::drawTexturedFloor(Renderer& renderer, const Player& player) {
    if (!s_texFloor) return;
    int halfH = WORLD_HEIGHT / 2;
    float dirX0 = player.transform.angle - FOV_RAD / 2.0f;
    float dirX1 = player.transform.angle + FOV_RAD / 2.0f;
    initCosSinLUT(dirX0, dirX1, m_cosLUT, m_sinLUT);
    m_lutInitialized = true;

    for (int y = halfH; y < WORLD_HEIGHT; ++y) {
        float rowDist = static_cast<float>(WORLD_HEIGHT) / (2.0f * (y - halfH) + 1.0f);
        Vector2D floor(
            player.transform.position.x + std::cos(dirX0) * rowDist,
            player.transform.position.y + std::sin(dirX0) * rowDist);

        Uint32* row = &m_pixelBuffer[y * WORLD_WIDTH];
        for (int x = 0; x < WORLD_WIDTH; ++x) {
            int texX = static_cast<int>(std::abs(floor.x * 4.0f)) % 64;
            int texY = static_cast<int>(std::abs(floor.y * 4.0f)) % 64;
            Uint8 c = static_cast<Uint8>((texX + texY) & 1 ? 70 : 58);
            row[x] = (255u << 24) | (c << 16) | (c << 8) | c;
            floor.x += m_cosLUT[x] * (rowDist / WORLD_WIDTH);
            floor.y += m_sinLUT[x] * (rowDist / WORLD_WIDTH);
        }
    }
}

void RenderSystem::drawTexturedCeiling(Renderer& renderer, const Player& player) {
    if (!s_texCeiling) return;
    int halfH = WORLD_HEIGHT / 2;

    for (int y = 0; y < halfH; ++y) {
        Uint32* row = &m_pixelBuffer[y * WORLD_WIDTH];
        for (int x = 0; x < WORLD_WIDTH; ++x) {
            Uint8 c = static_cast<Uint8>(40 + ((x / 16 + y / 8) & 1) * 10);
            row[x] = (255u << 24) | ((Uint8)(c + 5) << 16) | (c << 8) | c;
        }
    }
}

static void flushFloorCeiling(Renderer& renderer, SDL_Texture*& tex,
                               std::vector<Uint32>& pixelBuffer) {
    if (!tex) {
        tex = renderer.createStreamingTexture(
            RenderSystem::WORLD_WIDTH, RenderSystem::WORLD_HEIGHT);
    }
    if (tex) {
        renderer.updateTexture(tex, pixelBuffer.data(),
                               RenderSystem::WORLD_WIDTH * 4);
        SDL_Rect full = {0, 0, RenderSystem::WORLD_WIDTH, RenderSystem::WORLD_HEIGHT};
        renderer.copyTexture(tex, nullptr, &full);
    }
}

// ============================================================================
//  墙壁渲染
// ============================================================================

Uint8 RenderSystem::getShadeLevel(float distance, float colorFactor) {
    float shade;
    if      (distance < 3.0f)  shade = 1.0f;
    else if (distance < 6.0f)  shade = 0.75f;
    else if (distance < 9.0f)  shade = 0.5f;
    else if (distance < 12.0f) shade = 0.25f;
    else                       shade = 0.15f;
    return static_cast<Uint8>(std::round(255.0f * shade * colorFactor));
}

void RenderSystem::drawWallColumn(Renderer& renderer, int x, const RaycastResult& hit,
                                   int yTop, int height, float /*shade*/) {
    Uint8 s = getShadeLevel(hit.distance, hit.colorFactor);

    if (hit.material == WallMaterial::Grate) {
        renderer.setColor(40, 40, 50, 200);
        renderer.drawVerticalLine(x, yTop, height);
        int barSpacing = 4;
        for (int dy = 0; dy < height; dy += barSpacing) {
            renderer.setColor(120, 130, 150, 150);
            renderer.fillRect(x, yTop + dy, 1, 2);
        }
        return;
    }

    SDL_Texture* tex = nullptr;
    SDL_Color fallbackColor;
    if (s_texturedWalls) {
        switch (hit.material) {
        case WallMaterial::Brick: tex = s_texBrick; break;
        case WallMaterial::Metal: tex = s_texMetal; break;
        case WallMaterial::Stone: tex = s_texStone; break;
        default: break;
        }
    }

    if (tex) {
        float texFrac = hit.hitXSide ? (hit.hitY - std::floor(hit.hitY))
                                     : (hit.hitX - std::floor(hit.hitX));
        int srcX = static_cast<int>(texFrac * 64.0f) % 64;
        SDL_SetTextureColorMod(tex, s, s, s);
        SDL_Rect src = { srcX, 0, 1, 64 };
        SDL_Rect dst = { x, yTop, 1, height };
        renderer.copyTexture(tex, &src, &dst);
    } else {
        switch (hit.material) {
        case WallMaterial::Brick: fallbackColor = {0,   0,   s, 255}; break;
        case WallMaterial::Metal: fallbackColor = {(Uint8)(s/2), (Uint8)(s/2), s, 255}; break;
        case WallMaterial::Stone: fallbackColor = {(Uint8)(s/3), (Uint8)(s/3), (Uint8)(s/3), 255}; break;
        case WallMaterial::Grate: fallbackColor = {(Uint8)(s/2), (Uint8)(s/2), s, 255}; break;
        default:                  fallbackColor = {0, 0, s, 255}; break;
        }
        renderer.setColor(fallbackColor.r, fallbackColor.g, fallbackColor.b);
        renderer.drawVerticalLine(x, yTop, height);
    }
}

void RenderSystem::drawWalls(Renderer& renderer, const Player& player, float listDepth[]) {
    for (int x = 0; x < WORLD_WIDTH; ++x) {
        float angleOffset = -FOV_RAD / 2.0f + FOV_RAD * (x / static_cast<float>(WORLD_WIDTH - 1));
        float rayAngle = player.transform.angle + angleOffset;
        RaycastResult hit = raycast(player.transform.position, Vector2D(rayAngle));

        if (hit.distance > 0.0f) {
            listDepth[x] = hit.distance;
            float wallH = static_cast<float>(WORLD_HEIGHT) / hit.distance;
            if (wallH > WORLD_HEIGHT) wallH = static_cast<float>(WORLD_HEIGHT);
            int yTop = static_cast<int>((WORLD_HEIGHT - wallH) / 2);
            drawWallColumn(renderer, x, hit, yTop, static_cast<int>(wallH), 1.0f);
        }
    }
}

// ============================================================================
//  距离雾
// ============================================================================

void RenderSystem::applyDistanceFog(Renderer& renderer, const float listDepth[]) {
    SDL_Color fog{30, 35, 50, 255};
    for (int x = 0; x < WORLD_WIDTH; ++x) {
        float d = listDepth[x];
        if (d <= 0.0f || d < 10.0f) continue;
        float fogStr = MathAddon::clamp((d - 10.0f) / 10.0f, 0.0f, 1.0f);
        renderer.setColor(fog.r, fog.g, fog.b, static_cast<Uint8>(fogStr * 128.0f));
        renderer.drawVerticalLine(x, 0, WORLD_HEIGHT);
    }
}

// ============================================================================
//  精灵渲染
// ============================================================================

void RenderSystem::drawSprites(Renderer& renderer, const Player& player,
                                const std::vector<std::unique_ptr<Enemy>>& enemies,
                                const std::vector<std::unique_ptr<Pickup>>& pickups,
                                const float listDepth[], float dT) {
    m_spriteBuffer.clear();

    for (const auto& enemy : enemies) {
        if (!enemy->isAlive()) continue;
        float dist = player.transform.position.distanceTo(enemy->transform.position);
        if (dist < 0.5f || dist > 25.0f) continue;

        Vector2D toEnemy = enemy->transform.position - player.transform.position;
        float diff = player.transform.angle - std::atan2(toEnemy.y, toEnemy.x);
        diff = MathAddon::wrapAngleRad(diff);
        if (std::abs(diff) > FOV_RAD * 0.65f) continue;

        float baseSize = 14.0f + 4.0f * (enemy->weapon.damage);
        float animScale = s_animatedEnemies ? (1.0f + 0.05f * std::sin(enemy->animTimer * 6.28f)) : 1.0f;
        float size = baseSize * animScale;

        Uint8 r = enemy->hurtTimer > 0.0f ? (Uint8)255 : (Uint8)220;
        Uint8 g = enemy->hurtTimer > 0.0f ? (Uint8)50  : (Uint8)30;
        if (s_animatedEnemies && enemy->state == Enemy::State::Attacking) {
            r = 255; g = 40;
        }
        m_spriteBuffer.push_back({enemy->transform.position, dist, diff, r, g, 0, size, 0.0f, false});
    }

    for (const auto& pickup : pickups) {
        if (pickup->consumed) continue;
        float dist = player.transform.position.distanceTo(pickup->transform.position);
        if (dist < 0.3f || dist > 20.0f) continue;

        Vector2D toPickup = pickup->transform.position - player.transform.position;
        float diff = player.transform.angle - std::atan2(toPickup.y, toPickup.x);
        diff = MathAddon::wrapAngleRad(diff);
        if (std::abs(diff) > FOV_RAD * 0.65f) continue;

        float bobY = std::sin(pickup->bobPhase) * 3.0f;

        Uint8 pr=255, pg=215, pb=0;
        switch (pickup->type) {
        case Pickup::Type::Health: pr=255; pg=100; pb=100; break;
        case Pickup::Type::Ammo:   pr=100; pg=100; pb=255; break;
        case Pickup::Type::Coin:   pr=255; pg=215; pb=0;   break;
        default: pr=0; pg=255; pb=0; break;
        }
        m_spriteBuffer.push_back({pickup->transform.position, dist, diff, pr, pg, pb, 8.0f, bobY, true});
    }

    std::sort(m_spriteBuffer.begin(), m_spriteBuffer.end(),
        [](const SpriteEntry& a, const SpriteEntry& b) { return a.dist > b.dist; });

    for (const auto& sp : m_spriteBuffer) {
        float screenX = WORLD_WIDTH / 2.0f - (sp.diff / (FOV_RAD / 2.0f)) * (WORLD_WIDTH / 2.0f);
        float screenSize = sp.size * WORLD_HEIGHT / sp.dist;
        if (screenSize > WORLD_HEIGHT * 2) screenSize = WORLD_HEIGHT * 2.0f;
        float halfS = screenSize / 2.0f;
        if (screenX + halfS < 0 || screenX - halfS > WORLD_WIDTH) continue;

        int col = static_cast<int>(screenX);
        if (col > 0 && col < WORLD_WIDTH && sp.dist > listDepth[col] + 0.3f) continue;

        renderer.setColor(sp.r, sp.g, sp.b);
        renderer.fillRect(static_cast<int>(screenX - halfS),
                          static_cast<int>(WORLD_HEIGHT / 2.0f - halfS + sp.bobY),
                          static_cast<int>(screenSize), static_cast<int>(screenSize));
    }
}

// ============================================================================
//  弹痕贴花
// ============================================================================

void RenderSystem::drawDecals(Renderer& renderer, const Player& player, float dT) {
    for (auto& decal : s_decals) {
        decal.lifetime -= dT;
        if (decal.lifetime <= 0.0f) continue;

        float alpha = MathAddon::clamp(decal.lifetime / m_config.game.decalLifetime, 0.0f, 0.6f);
        float size = 4.0f * WORLD_HEIGHT / decal.distance;
        if (size > 16.0f) size = 16.0f;
        if (size < 2.0f) size = 2.0f;

        renderer.setColor(40, 40, 40, static_cast<Uint8>(alpha * 255));
        renderer.fillRect(decal.screenX - static_cast<int>(size / 2),
                          WORLD_HEIGHT / 2 - static_cast<int>(size / 2),
                          static_cast<int>(size), static_cast<int>(size));
    }
    s_decals.erase(std::remove_if(s_decals.begin(), s_decals.end(),
        [](const BulletDecal& d) { return d.lifetime <= 0.0f; }), s_decals.end());
}

// ============================================================================
//  动态光照
// ============================================================================

void RenderSystem::applyDynamicLighting(Renderer& renderer, const Player& /*player*/, float dT) {
    m_lightFlickerPhase += dT * 3.0f;
    float flicker = 0.7f + 0.3f * std::sin(m_lightFlickerPhase);

    renderer.setColor(255, static_cast<Uint8>(200 * flicker), static_cast<Uint8>(100 * flicker),
                      static_cast<Uint8>(20 * flicker));
    renderer.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
}

// ============================================================================
//  后处理
// ============================================================================

void RenderSystem::applyHurtVignette(Renderer& renderer, const Player& player) {
    if (player.hurtTimer <= 0.0f) return;
    float intensity = player.hurtTimer / Player::HURT_DURATION;
    Uint8 alpha = static_cast<Uint8>(intensity * 120.0f);
    renderer.setColor(180, 0, 0, alpha);
    renderer.fillRect(0, 0, WORLD_WIDTH, 15);
    renderer.fillRect(0, WORLD_HEIGHT - 15, WORLD_WIDTH, 15);
    renderer.fillRect(0, 0, 15, WORLD_HEIGHT);
    renderer.fillRect(WORLD_WIDTH - 15, 0, 15, WORLD_HEIGHT);
}

void RenderSystem::applyMuzzleFlash(Renderer& renderer, const Player& player) {
    if (player.muzzleFlashTimer <= 0.0f) return;
    float intensity = player.muzzleFlashTimer / Player::MUZZLE_FLASH_DURATION;
    int flashH = static_cast<int>(40.0f * intensity);
    Uint8 alpha = static_cast<Uint8>(intensity * 180.0f);
    renderer.setColor(255, 200, 50, alpha);
    renderer.fillRect(WORLD_WIDTH / 2 - 30, WORLD_HEIGHT - flashH, 60, flashH);
    renderer.setColor(255, 255, 200, static_cast<Uint8>(alpha * 0.3f));
    renderer.fillRect(0, WORLD_HEIGHT * 2 / 3, WORLD_WIDTH, WORLD_HEIGHT / 3);
}

// ============================================================================
//  HUD
// ============================================================================

void RenderSystem::drawHUD(Renderer& renderer, const Player& player) {
    const int barX = 4, barH = 6;

    // 血量条
    {
        float hpRatio = player.health.max > 0
            ? static_cast<float>(player.health.current) / static_cast<float>(player.health.max) : 0.0f;
        int bw = static_cast<int>(80.0f * hpRatio);
        renderer.setColor(40, 0, 0); renderer.fillRect(barX, 4, 80, barH);
        Uint8 r = hpRatio < 0.5f ? 255 : static_cast<Uint8>(255 * (1.0f - hpRatio) * 2.0f);
        Uint8 g = hpRatio > 0.5f ? 255 : static_cast<Uint8>(255 * hpRatio * 2.0f);
        renderer.setColor(r, g, 0); renderer.fillRect(barX, 4, bw, barH);
    }

    // 弹药条
    {
        float ammoRatio = player.weapon.clipSize > 0
            ? static_cast<float>(player.weapon.ammoClip) / static_cast<float>(player.weapon.clipSize) : 0.0f;
        int bw = static_cast<int>(60.0f * ammoRatio);
        renderer.setColor(30, 30, 30); renderer.fillRect(barX, 14, 60, barH);
        if (player.weapon.isReloading) {
            float rp = player.weapon.reloadTimer / player.weapon.reloadTime;
            renderer.setColor(255, 200, 0);
            renderer.fillRect(barX, 14, static_cast<int>(60.0f * rp), barH);
        } else {
            renderer.setColor(100, 150, 255);
            renderer.fillRect(barX, 14, bw, barH);
        }
    }

    // 备弹块
    {
        int blocks = player.weapon.ammoReserve / 5;
        if (blocks > 12) blocks = 12;
        renderer.setColor(80, 80, 120);
        for (int i = 0; i < blocks; ++i) renderer.fillRect(barX + i * 6, 24, 4, 4);
    }

    // 准星
    int cx = WORLD_WIDTH / 2, cy = WORLD_HEIGHT / 2;
    renderer.setColor(255, 255, 255);
    renderer.fillRect(cx - 5, cy, 11, 1);
    renderer.fillRect(cx, cy - 5, 1, 11);

    // 金币
    {
        int dots = player.coins > 50 ? 50 : player.coins;
        renderer.setColor(255, 215, 0);
        for (int i = 0; i < dots; ++i)
            renderer.fillRect(WORLD_WIDTH - 4 - (i % 10) * 3, 4 + (i / 10) * 3, 2, 2);
    }

    // 换弹文字
    if (player.weapon.isReloading) {
        float rp = player.weapon.reloadTimer / player.weapon.reloadTime;
        renderer.setColor(255, 200, 0);
        renderer.fillRect(WORLD_WIDTH / 2 - 20, WORLD_HEIGHT - 20, 40, 3);
        renderer.setColor(255, 255, 100);
        renderer.fillRect(WORLD_WIDTH / 2 - 18, WORLD_HEIGHT - 19, static_cast<int>(36.0f * rp), 1);
    }
    if (!player.weapon.isReloading && player.weapon.ammoClip <= 3 && player.weapon.ammoClip > 0) {
        renderer.setColor(255, 50, 50, 128);
        renderer.fillRect(WORLD_WIDTH / 2 - 15, WORLD_HEIGHT - 15, 30, 2);
    }
}

// ============================================================================
//  小地图
// ============================================================================

void RenderSystem::initMinimapGrid() {
    const float sx = static_cast<float>(MM_W) / Level::WIDTH;
    const float sy = static_cast<float>(MM_H) / Level::HEIGHT;
    for (int ly = 0; ly < MM_H; ++ly) {
        for (int lx = 0; lx < MM_W; ++lx) {
            m_minimapWalls[ly * MM_W + lx] =
                Level::isWall(static_cast<int>(lx / sx), static_cast<int>(ly / sy));
        }
    }
    m_minimapReady = true;
}

void RenderSystem::drawMinimap(Renderer& renderer, const Player& player,
                                const std::vector<std::unique_ptr<Enemy>>& enemies,
                                const std::vector<std::unique_ptr<Pickup>>& pickups) {
    const int mmX = WORLD_WIDTH - 44, mmY = WORLD_HEIGHT - 28;
    const float sx = static_cast<float>(MM_W) / Level::WIDTH;
    const float sy = static_cast<float>(MM_H) / Level::HEIGHT;

    if (!m_minimapReady) initMinimapGrid();

    renderer.setColor(0, 0, 0, 180);
    renderer.fillRect(mmX, mmY, MM_W, MM_H);

    // 预计算墙壁数据 — 单层循环，无 Level::isWall 调用
    for (int ly = 0; ly < MM_H; ++ly) {
        for (int lx = 0; lx < MM_W; ++lx) {
            if (m_minimapWalls[ly * MM_W + lx]) {
                renderer.setColor(60, 60, 60);
                renderer.fillRect(mmX + lx, mmY + ly, 1, 1);
            }
        }
    }

    for (const auto& pk : pickups) {
        if (!pk->consumable) {
            renderer.setColor(255, 255, 0);
            renderer.fillRect(mmX + static_cast<int>(pk->transform.position.x * sx) - 1,
                              mmY + static_cast<int>(pk->transform.position.y * sy) - 1, 2, 2);
        } else if (!pk->consumed) {
            renderer.setColor(0, 255, 100);
            renderer.fillRect(mmX + static_cast<int>(pk->transform.position.x * sx),
                              mmY + static_cast<int>(pk->transform.position.y * sy), 1, 1);
        }
    }

    for (const auto& e : enemies)
        if (e->isAlive()) {
            renderer.setColor(255, 30, 30);
            renderer.fillRect(mmX + static_cast<int>(e->transform.position.x * sx),
                              mmY + static_cast<int>(e->transform.position.y * sy), 1, 1);
        }

    renderer.setColor(255, 255, 255);
    renderer.fillRect(mmX + static_cast<int>(player.transform.position.x * sx) - 1,
                      mmY + static_cast<int>(player.transform.position.y * sy) - 1, 2, 2);

    renderer.setColor(100, 100, 100, 128);
    renderer.fillRect(mmX - 1, mmY - 1, MM_W + 2, 1);
    renderer.fillRect(mmX - 1, mmY + MM_H, MM_W + 2, 1);
    renderer.fillRect(mmX - 1, mmY, 1, MM_H);
    renderer.fillRect(mmX + MM_W, mmY, 1, MM_H);
}

// ============================================================================
//  帮助函数
// ============================================================================

SDL_Color RenderSystem::lerpColor(SDL_Color a, SDL_Color b, float t) {
    return {
        static_cast<Uint8>(a.r + (b.r - a.r) * t),
        static_cast<Uint8>(a.g + (b.g - a.g) * t),
        static_cast<Uint8>(a.b + (b.b - a.b) * t), 255
    };
}

// ============================================================================
//  粒子渲染
// ============================================================================

void RenderSystem::drawParticles(Renderer& renderer, const Player& player, float /*dT*/) {
    const Particle* particles = m_particles.activeParticles();
    int count = m_particles.activeCount();
    for (int i = 0; i < count; ++i) {
        const auto& p = particles[i];
        Vector2D toParticle = p.position - player.transform.position;
        float angleTo = std::atan2(toParticle.y, toParticle.x);
        float diff = player.transform.angle - angleTo;
        diff = MathAddon::wrapAngleRad(diff);

        if (std::abs(diff) > FOV_RAD * 0.7f) continue;

        float dist = toParticle.magnitude();
        if (dist < 0.2f || dist > 15.0f) continue;

        float screenX = WORLD_WIDTH / 2.0f - (diff / (FOV_RAD / 2.0f)) * (WORLD_WIDTH / 2.0f);
        float screenSize = p.size * WORLD_HEIGHT / dist;
        if (screenSize < 1.0f || screenSize > 20.0f) continue;

        Uint8 alpha = static_cast<Uint8>(p.alpha() * 255);
        renderer.setColor(p.r, p.g, p.b, alpha);
        int sx = static_cast<int>(screenX - screenSize / 2);
        int sy = static_cast<int>(WORLD_HEIGHT / 2.0f - screenSize / 2);
        renderer.fillRect(sx, sy, static_cast<int>(screenSize), static_cast<int>(screenSize));
    }
}

// ============================================================================
//  天气效果
// ============================================================================

void RenderSystem::drawWeather(Renderer& renderer, float dT) {
    m_weatherPhase += dT;

    for (int i = 0; i < m_config.game.snowflakeCount; ++i) {
        float seed = static_cast<float>((i * 2654435761u) ^ static_cast<unsigned>(m_weatherPhase * 1000.0f));
        float x = std::fmod(seed * 0.001f, 1.0f) * WORLD_WIDTH;
        float y = std::fmod((seed * 0.002f + m_weatherPhase * m_config.game.weatherFallSpeed),
                            static_cast<float>(WORLD_HEIGHT));
        float sz = 1.0f + std::fmod(seed, 1.0f) * 1.5f;
        Uint8 alpha = static_cast<Uint8>(150 + std::fmod(seed * 3.0f, 1.0f) * 105);
        renderer.setColor(200, 210, 230, alpha);
        renderer.fillRect(static_cast<int>(x), static_cast<int>(y),
                          static_cast<int>(sz), static_cast<int>(sz));
    }
}

// ============================================================================
//  水下/毒气效果
// ============================================================================

void RenderSystem::applyUnderwaterFX(Renderer& renderer, const Player& player, float dT) {
    bool inWater = (player.transform.position.y > 55.0f && player.transform.position.y < 60.0f);

    if (!inWater) return;

    static float distortionPhase = 0.0f;
    distortionPhase += dT * 2.0f;

    float wave = std::sin(distortionPhase) * 0.5f + 0.5f;
    renderer.setColor(0, 60, static_cast<Uint8>(120 * wave), 40);
    renderer.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);

    for (int y = 0; y < WORLD_HEIGHT; y += 8) {
        float offset = std::sin(distortionPhase + y * 0.1f) * 2.0f;
        renderer.setColor(0, 50, 100, 30);
        renderer.fillRect(static_cast<int>(offset), y, WORLD_WIDTH, 2);
    }
}

// ============================================================================
//  Y-shearing 上下视角
// ============================================================================

void RenderSystem::applyYShear(Renderer& renderer, const Player& player) {
    if (std::abs(player.lookOffset) < 0.5f) return;

    int offset = static_cast<int>(player.lookOffset);

    renderer.setColor(0, 0, 0, 200);
    if (offset > 0) {
        renderer.fillRect(0, 0, WORLD_WIDTH, offset);
    } else if (offset < 0) {
        renderer.fillRect(0, WORLD_HEIGHT + offset, WORLD_WIDTH, -offset);
    }
}
