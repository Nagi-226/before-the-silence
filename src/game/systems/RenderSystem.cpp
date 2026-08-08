#include "game/systems/RenderSystem.h"
#include "game/systems/ParticleSystem.h"
#include "game/systems/CombatSystem.h"
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
    s_texCloud   = cache.loadTexture("Cloud.bmp");
    s_texWeapon  = cache.loadTexture("Weapon.bmp");
    // v0.6.2: 加载敌人精灵纹理（精灵表，多帧动画）
    s_texAlienSmall  = cache.loadTexture("Alien Small.bmp");
    s_texAlienMedium = cache.loadTexture("Alien Medium.bmp");
    s_texAlienLarge  = cache.loadTexture("Alien Large.bmp");
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
    if (s_cloudSkybox) {
        drawCloudSkybox(renderer, dT, player);
    } else if (s_texturedFloors && s_texFloor) {
        drawTexturedCeiling();
        drawTexturedFloor(player);
        flushFloorCeiling(renderer, m_floorCeilTex, m_pixelBuffer);
    } else {
        drawSkyGradient(renderer);
    }

    // 2. 墙壁（区域高度由 s_wallHeightVariation 控制，内部处理）
    drawWalls(renderer, player, listDepth);

    // 3. 距离雾
    applyDistanceFog(renderer, listDepth);

    // 4. 弹痕贴花
    drawDecals(renderer, dT);

    // 4.5 v0.4.7 弹道拖尾
    drawTracers(renderer, player, dT);

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
    drawSprites(renderer, player, enemies, pickups, listDepth);

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

    // 12. v0.4.4 武器模型
    if (s_weaponModel) {
        drawWeaponModel(renderer, player);
    }

    // 13. HUD + 小地图
    drawHUD(renderer, player);
    drawMinimap(renderer, player, enemies, pickups);

    // 14. v0.4.6 游戏状态覆盖层
    drawGameOverlay(renderer, player);

    renderer.endFrame();
}

// ============================================================================
//  DDA 光线投射
// ============================================================================

RaycastResult RenderSystem::raycast(Vector2D start, Vector2D dir) {
    RaycastResult result;
    // 防止除零 → infinity → DDA 死循环/崩溃
    float invX = (std::abs(dir.x) < 1e-8f) ? 1e8f : (1.0f / std::abs(dir.x));
    float invY = (std::abs(dir.y) < 1e-8f) ? 1e8f : (1.0f / std::abs(dir.y));
    Vector2D deltaDist(invX, invY);

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

static void drawSkyGradientImpl(Renderer& renderer, SDL_Color top, SDL_Color bot) {
    int halfH = RenderSystem::WORLD_HEIGHT / 2;
    for (int y = 0; y < halfH; ++y) {
        float t = static_cast<float>(y) / (halfH - 1);
        SDL_Color c = {
            static_cast<Uint8>(top.r + (bot.r - top.r) * t),
            static_cast<Uint8>(top.g + (bot.g - top.g) * t),
            static_cast<Uint8>(top.b + (bot.b - top.b) * t),
            255
        };
        renderer.setColor(c.r, c.g, c.b);
        renderer.fillRect(0, y, RenderSystem::WORLD_WIDTH, 1);
    }
}

void RenderSystem::drawSkyGradient(Renderer& renderer) {
    drawSkyGradientImpl(renderer, {32, 40, 60, 255}, {100, 120, 160, 255});
    int halfH = WORLD_HEIGHT / 2;
    renderer.setColor(64, 64, 64);
    renderer.fillRect(0, halfH, WORLD_WIDTH, halfH);
}

// ============================================================================
//  纹理地板/天花板
// ============================================================================

void RenderSystem::drawTexturedFloor(const Player& player) {
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

void RenderSystem::drawTexturedCeiling() {
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
    float shade = 0.15f;  // 默认最暗，防止 NaN 距离导致未初始化
    if      (distance < 3.0f)  shade = 1.0f;
    else if (distance < 6.0f)  shade = 0.75f;
    else if (distance < 9.0f)  shade = 0.5f;
    else if (distance < 12.0f) shade = 0.25f;
    else                       shade = 0.15f;
    return static_cast<Uint8>(std::round(255.0f * shade * colorFactor));
}

void RenderSystem::drawWallColumn(Renderer& renderer, int x, const RaycastResult& hit,
                                   int yTop, int height, float /*shade*/) {
    // 安全钳位: 防止极端距离导致非法渲染坐标
    if (height <= 0 || height > WORLD_HEIGHT * 4) return;
    if (yTop < -WORLD_HEIGHT || yTop > WORLD_HEIGHT * 4) return;
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
            // 鱼眼校正（参考 DOOM/Wolf3D 经典实现，消除边缘拉伸畸变）
            float correctedDist = hit.distance * std::cos(angleOffset);
            if (correctedDist < 0.2f) correctedDist = 0.2f;
            listDepth[x] = correctedDist;

            // v0.4.1 区域高度变化
            float floorH = 0.5f, ceilH = 0.5f;
            if (s_wallHeightVariation) {
                int cellX = static_cast<int>(hit.hitX);
                int cellY = static_cast<int>(hit.hitY);
                floorH = Level::getFloorHeight(cellX, cellY);
                ceilH = Level::getCeilingHeight(cellX, cellY);
            }

            // 墙体以地平线为中心，pitch 控制上下看
            float pitchAdj = player.lookOffset / Player::MAX_LOOK_OFFSET;
            int pitchShift = static_cast<int>(pitchAdj * WORLD_HEIGHT * 0.4f);
            int horizon = WORLD_HEIGHT / 2 + pitchShift;
            int yTop    = static_cast<int>(horizon - WORLD_HEIGHT * ceilH  / correctedDist);
            int yBottom = static_cast<int>(horizon + WORLD_HEIGHT * floorH / correctedDist);
            if (yTop < 0)    yTop = 0;
            if (yBottom >= WORLD_HEIGHT) yBottom = WORLD_HEIGHT - 1;
            int wallH = yBottom - yTop;
            if (wallH <= 0) continue;
            drawWallColumn(renderer, x, hit, yTop, wallH, 1.0f);
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
                                const float listDepth[]) {
    m_spriteBuffer.clear();

    for (const auto& enemy : enemies) {
        // v0.4.7 显示活着的敌人 + 淡出中的尸体
        bool isDead = (enemy->state == Enemy::State::Dead);
        if (!enemy->isAlive() && !isDead) continue;
        if (isDead && enemy->corpseFadeTimer <= 0.0f) continue;

        float dist = player.transform.position.distanceTo(enemy->transform.position);
        if (dist < 0.5f || dist > 25.0f) continue;

        Vector2D toEnemy = enemy->transform.position - player.transform.position;
        float diff = player.transform.angle - std::atan2(toEnemy.y, toEnemy.x);
        diff = MathAddon::wrapAngleRad(diff);
        if (std::abs(diff) > FOV_RAD * 0.65f) continue;

        float baseSize = 14.0f + 4.0f * (enemy->weapon.damage);
        float animScale = s_animatedEnemies ? (1.0f + 0.05f * std::sin(enemy->animTimer * 6.28f)) : 1.0f;
        float fadeAlpha = 1.0f;
        // 尸体淡出缩小时变暗
        if (isDead) {
            fadeAlpha = enemy->corpseFadeTimer / Enemy::CORPSE_FADE_DURATION;
            baseSize *= fadeAlpha;
        }
        float size = baseSize * animScale;

        // v0.6.2: 根据模板ID选择对应精灵纹理
        SDL_Texture* tex = nullptr;
        if (enemy->templateId == 0)      tex = s_texAlienSmall;
        else if (enemy->templateId == 1) tex = s_texAlienMedium;
        else if (enemy->templateId == 2) tex = s_texAlienLarge;

        Uint8 r = enemy->hurtTimer > 0.0f ? (Uint8)255 : (Uint8)220;
        Uint8 g = enemy->hurtTimer > 0.0f ? (Uint8)50  : (Uint8)30;
        if (s_animatedEnemies && enemy->state == Enemy::State::Attacking) {
            r = 255; g = 40;
        }
        m_spriteBuffer.push_back({
            enemy->transform.position, dist, diff,
            r, g, 0, size, 0.0f, false,
            tex, enemy->animFrame, isDead, fadeAlpha
        });
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

    // 上下看偏移（与墙壁/天空一致的 pitch 公式）
    int pitchShift = static_cast<int>(player.lookOffset / Player::MAX_LOOK_OFFSET * WORLD_HEIGHT * 0.4f);

    for (const auto& sp : m_spriteBuffer) {
        float screenX, screenSize;
        float correctedDist = sp.dist * std::cos(sp.diff);
        if (correctedDist < 0.3f) correctedDist = 0.3f;
        projectToScreen(sp.diff, correctedDist, screenX, screenSize);
        screenSize = screenSize * sp.size / 16.0f;
        constexpr float MAX_SPRITE_PX = 80.0f; // v0.6.3: 放宽上限，近距离更大
        if (screenSize > MAX_SPRITE_PX) screenSize = MAX_SPRITE_PX;

        int dstW = static_cast<int>(screenSize);
        int dstH = static_cast<int>(screenSize);
        int xLeft  = static_cast<int>(screenX - dstW / 2.0f);
        int yTop   = static_cast<int>(WORLD_HEIGHT / 2.0f - dstH / 2.0f + sp.bobY + pitchShift);
        int xRight = xLeft + dstW;

        // v0.6.3: 恢复原始(src-legacy)逐列深度测试纹理渲染
        // 参考原 Sprite::draw() — 逐像素列检查深度缓冲，实现精灵部分遮挡
        if (!sp.isPickup && sp.tex) {
            int frameX = sp.animFrame * Enemy::FRAME_WIDTH;
            int texW   = Enemy::FRAME_WIDTH; // 32px 单帧宽度

            // 受伤闪红调色
            bool hurtFlash = (sp.r == 255 && sp.g < 100);
            if (hurtFlash) {
                SDL_SetTextureColorMod(sp.tex, 255, static_cast<Uint8>(sp.g), 0);
            }
            // 尸体淡出
            if (sp.isDead) {
                Uint8 shade = static_cast<Uint8>(255 * sp.fadeAlpha);
                SDL_SetTextureAlphaMod(sp.tex, shade);
            }

            // 逐列渲染，每列单独做深度测试
            for (int col = 0; col < texW; ++col) {
                int screenCol = xLeft + (col * dstW) / texW;
                if (screenCol < 0 || screenCol >= WORLD_WIDTH) continue; // 屏幕裁剪

                // 深度测试：仅当精灵比墙壁更近时才绘制此列
                if (listDepth[screenCol] <= 0.0f || correctedDist < listDepth[screenCol]) {
                    SDL_Rect src = { frameX + col, 0, 1, 32 };
                    SDL_Rect dst = { screenCol, yTop, 1, dstH };
                    renderer.copyTexture(sp.tex, &src, &dst);
                }
            }

            // 恢复纹理调制
            SDL_SetTextureColorMod(sp.tex, 255, 255, 255);
            SDL_SetTextureAlphaMod(sp.tex, 255);
        } else {
            // 拾取物：逐列检测遮挡，可见列才绘制
            for (int col = xLeft; col <= xRight; ++col) {
                if (col < 0 || col >= WORLD_WIDTH) continue;
                if (listDepth[col] <= 0.0f || correctedDist < listDepth[col]) {
                    renderer.setColor(sp.r, sp.g, sp.b);
                    renderer.drawVerticalLine(col, yTop, dstH);
                }
            }
        }
    }
}

// ============================================================================
//  弹痕贴花
// ============================================================================

void RenderSystem::drawDecals(Renderer& renderer, float dT) {
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
            int wx = static_cast<int>(lx / sx);
            int wy = static_cast<int>(ly / sy);
            wx = (wx < 0) ? 0 : ((wx >= Level::WIDTH) ? Level::WIDTH - 1 : wx);
            wy = (wy < 0) ? 0 : ((wy >= Level::HEIGHT) ? Level::HEIGHT - 1 : wy);
            m_minimapWalls[ly * MM_W + lx] = Level::isWall(wx, wy);
        }
    }
    m_minimapReady = true;
}

void RenderSystem::drawMinimap(Renderer& renderer, const Player& player,
                                const std::vector<std::unique_ptr<Enemy>>& enemies,
                                const std::vector<std::unique_ptr<Pickup>>& pickups) {
    // v0.6.1: 增大尺寸，更清晰
    const int mmX = WORLD_WIDTH - MM_W - 2, mmY = WORLD_HEIGHT - MM_H - 2;
    const float sx = static_cast<float>(MM_W) / Level::WIDTH;
    const float sy = static_cast<float>(MM_H) / Level::HEIGHT;

    if (!m_minimapReady) initMinimapGrid();

    // 半透明背景
    renderer.setColor(0, 0, 0, 160);
    renderer.fillRect(mmX - 1, mmY - 1, MM_W + 2, MM_H + 2);

    // 墙壁 — 每个像素单独渲染，映射到世界地图的对应位置
    for (int ly = 0; ly < MM_H; ++ly) {
        for (int lx = 0; lx < MM_W; ++lx) {
            if (m_minimapWalls[ly * MM_W + lx]) {
                renderer.setColor(80, 80, 80);
                renderer.fillRect(mmX + lx, mmY + ly, 1, 1);
            }
        }
    }

    // 实体 — 只显示非常近的（玩家周围 8 格内）
    constexpr float MM_ENTITY_RANGE = 8.0f;
    for (const auto& pk : pickups) {
        if (pk->consumed) continue;
        if (pk->transform.position.distanceTo(player.transform.position) > MM_ENTITY_RANGE) continue;
        int px = mmX + static_cast<int>(pk->transform.position.x * sx);
        int py = mmY + static_cast<int>(pk->transform.position.y * sy);
        if (pk->type == Pickup::Type::Coin) {
            renderer.setColor(255, 215, 0); // 金色
        } else if (pk->type == Pickup::Type::Health || pk->type == Pickup::Type::UpgradeHealth) {
            renderer.setColor(255, 80, 80);  // 红色
        } else {
            renderer.setColor(80, 80, 255);  // 蓝色（弹药/升级）
        }
        renderer.fillRect(px, py, 1, 1);
    }

    for (const auto& e : enemies) {
        if (!e->isAlive()) continue;
        if (e->transform.position.distanceTo(player.transform.position) > MM_ENTITY_RANGE) continue;
        renderer.setColor(255, 30, 30); // 红色敌人
        int ex = mmX + static_cast<int>(e->transform.position.x * sx);
        int ey = mmY + static_cast<int>(e->transform.position.y * sy);
        renderer.fillRect(ex, ey, 1, 1);
    }

    // 玩家 — 白色十字
    int px = mmX + static_cast<int>(player.transform.position.x * sx);
    int py = mmY + static_cast<int>(player.transform.position.y * sy);
    renderer.setColor(255, 255, 255);
    renderer.fillRect(px - 1, py, 3, 1);
    renderer.fillRect(px, py - 1, 1, 3);

    // 边框
    renderer.setColor(100, 100, 100, 200);
    renderer.fillRect(mmX - 1, mmY - 1, MM_W + 2, 1);      // 上
    renderer.fillRect(mmX - 1, mmY + MM_H, MM_W + 2, 1);    // 下
    renderer.fillRect(mmX - 1, mmY, 1, MM_H);               // 左
    renderer.fillRect(mmX + MM_W, mmY, 1, MM_H);            // 右
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

void RenderSystem::projectToScreen(float diff, float dist, float& screenX, float& screenSize) {
    screenX = WORLD_WIDTH / 2.0f - (diff / (FOV_RAD / 2.0f)) * (WORLD_WIDTH / 2.0f);
    screenSize = 16.0f * WORLD_HEIGHT / dist;
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

        float screenX, screenSize;
        projectToScreen(diff, dist, screenX, screenSize);
        screenSize = screenSize * p.size / 16.0f;
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

    m_distortionPhase += dT * 2.0f;

    float wave = std::sin(m_distortionPhase) * 0.5f + 0.5f;
    renderer.setColor(0, 60, static_cast<Uint8>(120 * wave), 40);
    renderer.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);

    for (int y = 0; y < WORLD_HEIGHT; y += 8) {
        float offset = std::sin(m_distortionPhase + y * 0.1f) * 2.0f;
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

// ============================================================================
//  v0.4.2 云层天空盒
// ============================================================================

void RenderSystem::drawCloudSkybox(Renderer& renderer, float dT, const Player& player) {
    m_cloudOffset += dT * 8.0f;

    // 上下看时平移地平线
    float pitchAdj = player.lookOffset / Player::MAX_LOOK_OFFSET;
    int horizon = WORLD_HEIGHT / 2 + static_cast<int>(pitchAdj * WORLD_HEIGHT * 0.4f);
    if (horizon < WORLD_HEIGHT / 4) horizon = WORLD_HEIGHT / 4;
    if (horizon > WORLD_HEIGHT * 3 / 4) horizon = WORLD_HEIGHT * 3 / 4;

    drawSkyGradientImpl(renderer, {32, 40, 60, 255}, {100, 120, 160, 255});

    // 滚动云层（天空区域）
    if (s_texCloud) {
        for (int y = 10; y < horizon - 20; y += 30) {
            int cloudY = y + static_cast<int>(std::sin(y * 0.02f + m_cloudOffset * 0.3f) * 5.0f);
            SDL_Rect src = { static_cast<int>(m_cloudOffset) % 200, 0, WORLD_WIDTH, 32 };
            SDL_Rect dst = { 0, cloudY, WORLD_WIDTH, 20 };
            SDL_SetTextureAlphaMod(s_texCloud, 80);
            renderer.copyTexture(s_texCloud, &src, &dst);
            SDL_SetTextureAlphaMod(s_texCloud, 255);
        }
    }

    // 地面（从地平线开始）
    renderer.setColor(64, 64, 64);
    if (horizon < WORLD_HEIGHT)
        renderer.fillRect(0, horizon, WORLD_WIDTH, WORLD_HEIGHT - horizon);
}

// ============================================================================
//  v0.4.4 武器模型动画
// ============================================================================

void RenderSystem::drawWeaponModel(Renderer& renderer, const Player& player) {
    // 绘制武器（屏幕底部居中）
    if (s_texWeapon) {
        int weaponW = 80, weaponH = 60;
        int wx = WORLD_WIDTH / 2 - weaponW / 2;
        int wy = WORLD_HEIGHT - weaponH;

        // 开火时上跳
        if (player.muzzleFlashTimer > 0.0f) {
            wy -= static_cast<int>(5.0f * player.muzzleFlashTimer / Player::MUZZLE_FLASH_DURATION);
        }

        int frameX = player.weaponAnimFrame * 32;
        SDL_Rect src = { frameX, 0, 32, 60 };
        SDL_Rect dst = { wx, wy, weaponW, weaponH };
        renderer.copyTexture(s_texWeapon, &src, &dst);
    } else {
        renderer.setColor(80, 80, 80);
        renderer.fillRect(WORLD_WIDTH / 2 - 15, WORLD_HEIGHT - 40, 30, 40);
        if (player.muzzleFlashTimer > 0.0f) {
            renderer.setColor(255, 200, 50);
            renderer.fillRect(WORLD_WIDTH / 2 - 4, WORLD_HEIGHT - 50, 8, 12);
        }
    }
}

// ============================================================================
//  v0.4.7 弹道拖尾渲染
// ============================================================================

static std::vector<CombatSystem::TracerLine> s_tracers;

void RenderSystem::addTracer(Vector2D from, Vector2D to) {
    if (s_tracers.size() > 128) s_tracers.erase(s_tracers.begin());
    s_tracers.push_back({from, to, 0.08f});
}

void RenderSystem::drawTracers(Renderer& renderer, const Player& player, float dT) {
    for (auto& t : s_tracers) t.lifetime -= dT;
    s_tracers.erase(std::remove_if(s_tracers.begin(), s_tracers.end(),
        [](const auto& t) { return t.lifetime <= 0.0f; }), s_tracers.end());

    for (const auto& t : s_tracers) {
        float alpha = t.lifetime / 0.08f;
        if (alpha > 1.0f) alpha = 1.0f;

        Vector2D mid = (t.from + t.to) * 0.5f;
        float dist = mid.distanceTo(player.transform.position);
        if (dist < 0.3f || dist > 15.0f) continue;

        float screenX = WORLD_WIDTH / 2.0f;
        float size = 3.0f * WORLD_HEIGHT / dist;
        if (size > 6.0f) size = 6.0f;
        if (size < 1.0f) continue;

        renderer.setColor(255, 220, 100, static_cast<Uint8>(alpha * 200));
        renderer.fillRect(static_cast<int>(screenX - size / 2),
                          WORLD_HEIGHT / 2 - 1,
                          static_cast<int>(size), 2);
    }
}

// ============================================================================
//  v0.4.6 游戏状态覆盖层
// ============================================================================

void RenderSystem::drawGameOverlay(Renderer& renderer, const Player& player) {
    int cx = WORLD_WIDTH / 2, cy = WORLD_HEIGHT / 2;

    if (player.gameState == Player::State::Victory) {
        renderer.setColor(0, 0, 0, 150);
        renderer.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
        renderer.setColor(50, 255, 50);
        renderer.fillRect(cx - 40, cy - 12, 80, 24);
        renderer.setColor(0, 0, 0);
        renderer.fillRect(cx - 38, cy - 10, 76, 20);
        renderer.setColor(50, 255, 50);
        renderer.fillRect(cx - 30, cy - 4, 60, 8);
    }
    else if (player.gameState == Player::State::Defeat) {
        renderer.setColor(100, 0, 0, 150);
        renderer.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
        renderer.setColor(255, 50, 50);
        renderer.fillRect(cx - 40, cy - 12, 80, 24);
        renderer.setColor(0, 0, 0);
        renderer.fillRect(cx - 38, cy - 10, 76, 20);
        renderer.setColor(255, 100, 100);
        renderer.fillRect(cx - 30, cy - 4, 60, 8);
    }

}
