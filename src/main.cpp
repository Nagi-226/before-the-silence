#include <iostream>
#include <cstdlib>
#include <ctime>
#include <vector>
#include <memory>
#include "SDL2/SDL.h"
#include "SDL2/SDL_mixer.h"
#include "SDL2/SDL_ttf.h"

#include "engine/Renderer.h"
#include "engine/Input.h"
#include "engine/Audio.h"
#include "engine/ResourceCache.h"
#include "framework/GameLoop.h"

#include "game/GameConfig.h"
#include "game/Level.h"
#include "game/entities/Player.h"
#include "game/entities/Enemy.h"
#include "game/entities/Projectile.h"
#include "game/entities/Pickup.h"
#include "game/systems/MovementSystem.h"
#include "game/systems/CombatSystem.h"
#include "game/systems/PickupSystem.h"
#include "game/systems/ReloadSystem.h"
#include "game/systems/EnemyAISystem.h"
#include "game/systems/RenderSystem.h"
#include "game/systems/ParticleSystem.h"

// —— v0.4.0 DI 组装 ——

int main(int argc, char* args[]) {
    srand(static_cast<unsigned>(time(nullptr)));

    // 0. 加载配置
    GameConfig config;
    config.loadFromDirectory("assets/config");

    // 1. SDL 初始化
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0) {
        std::cerr << "SDL_Init failed: " << SDL_GetError() << std::endl;
        return 1;
    }
    if (TTF_Init() < 0) {
        std::cerr << "TTF_Init failed: " << TTF_GetError() << std::endl;
        SDL_Quit();
        return 1;
    }
    Audio::init();

    // 2. 窗口 + 渲染器
    SDL_Window* window = SDL_CreateWindow(
        "Retro FPS v0.4.0 — DI + JSON Config",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        960, 540, 0
    );
    if (!window) {
        Audio::shutdown(); TTF_Quit(); SDL_Quit();
        return 1;
    }

    int winW, winH;
    SDL_GetWindowSize(window, &winW, &winH);
    Renderer renderer(window, winW, winH);
    ResourceCache cache(renderer.getSDLRenderer());
    SDL_SetRelativeMouseMode(SDL_TRUE);
    Input input;

    // 3. 初始化 System（依赖注入）
    ParticleSystem particles(config.game.maxParticles);
    MovementSystem movementSys(config.player);
    ReloadSystem reloadSys;
    CombatSystem combatSys(config.playerWeapon, config.pickups, particles);
    PickupSystem pickupSys(config.pickups);
    EnemyAISystem enemyAISys(config.game, reloadSys);
    RenderSystem renderSys(cache, config, particles);

    // 4. 关卡 + 实体初始化
    Vector2D startPos, finishPos;
    std::vector<std::unique_ptr<Enemy>> enemies;
    std::vector<std::unique_ptr<Pickup>> pickups;
    std::vector<std::unique_ptr<Projectile>> projectiles;

    Level::setupEntities(enemies, pickups, startPos, finishPos);
    Player player(startPos);

    // 从配置覆盖玩家武器
    player.weapon.ammoClip = config.playerWeapon.ammoClip;
    player.weapon.ammoReserve = config.playerWeapon.ammoReserve;
    player.weapon.clipSize = config.playerWeapon.clipSize;
    player.weapon.fireRate = config.playerWeapon.fireRate;
    player.weapon.damage = config.playerWeapon.damage;
    player.weapon.bulletSpeed = config.playerWeapon.bulletSpeed;
    player.weapon.bulletRange = config.playerWeapon.bulletRange;
    player.weapon.reloadTime = config.playerWeapon.reloadTime;
    player.health = Health(config.player.baseHealth, config.player.baseHealth);

    // 6. 主循环
    GameLoop::run(
        // Update
        [&](float dT) {
            input.update();
            movementSys.updatePlayer(player, input, dT);
            reloadSys.update(player.weapon, input, dT);
            combatSys.updatePlayerShooting(player, input, dT, projectiles);
            enemyAISys.update(enemies, player, projectiles, dT);
            combatSys.updateProjectiles(projectiles, player, enemies, dT);
            pickupSys.update(player, pickups);
        },
        // Render
        [&]() {
            renderSys.render(renderer, player, enemies, projectiles, pickups, GameLoop::FIXED_DT);
        },
        // Quit check
        [&]() -> bool {
            return input.shouldQuit() || player.health.isDead();
        }
    );

    // 7. 清理
    SDL_SetRelativeMouseMode(SDL_FALSE);
    Audio::shutdown();
    TTF_Quit();
    SDL_Quit();

    return 0;
}
