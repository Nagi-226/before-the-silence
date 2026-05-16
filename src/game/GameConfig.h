#pragma once
#include <string>
#include <vector>

/// 玩家参数配置（从 player.json 加载）
struct PlayerConfig {
    float moveSpeed = 7.0f;
    float turnSpeed = 2.0f;
    int baseHealth = 20;

    float hurtDuration = 0.3f;
    float shakeDuration = 0.15f;
    float muzzleFlashDuration = 0.05f;
    float bobbingSpeed = 8.0f;
    float bobbingAmplitude = 1.5f;

    float lookSensitivity = 0.03f;
    float maxLookOffset = 30.0f;
};

/// 武器参数配置（从 weapons.json 加载）
struct WeaponConfig {
    int ammoClip = 30;
    int ammoReserve = 90;
    int clipSize = 30;
    float fireRate = 10.0f;
    int damage = 1;
    float bulletSpeed = 15.0f;
    float bulletRange = 10.0f;
    float reloadTime = 2.0f;
    float spawnOffset = 0.5f;
};

/// 敌人模板配置（从 enemies.json 加载）
struct EnemyTemplateConfig {
    std::string textureFile;
    int health = 1;
    float detectionRange = 8.0f;
    float attackRange = 2.0f;
    float moveSpeed = 2.5f;
    bool canDropPickup = false;
    WeaponConfig weapon;
};

/// 拾取物数值配置（从 pickups.json 加载）
struct PickupConfig {
    int ammoPickupAmount = 10;
    int healAmount = 1;

    int upgradeCost = 10;
    int healthUpgrade = 5;
    int ammoClipUpgrade = 5;
    int ammoReserveUpgrade = 10;
    float fireRateUpgrade = 2.0f;
    float fireRateCap = 20.0f;

    float pickupRadius = 1.0f;
    float projectileRadius = 0.5f;
};

/// 全局游戏参数（从 game.json 加载）
struct GameplayConfig {
    int maxParticles = 300;
    int maxDecals = 64;
    float decalLifetime = 5.0f;
    int snowflakeCount = 60;
    float weatherFallSpeed = 40.0f;
    int ddaMaxSteps = 256;
    float ddaStepSize = 0.5f;
};

/// 统一游戏配置 — 从 assets/config/ JSON 文件加载全部数值。
/// 关卡设计师可独立调参，无需重编译。
class GameConfig {
public:
    PlayerConfig player;
    WeaponConfig playerWeapon;
    std::vector<EnemyTemplateConfig> enemyTemplates;
    PickupConfig pickups;
    GameplayConfig game;

    /// 从目录加载所有 JSON 配置文件
    bool loadFromDirectory(const std::string& dir);
};
