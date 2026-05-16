#include "game/GameConfig.h"
#include <gtest/gtest.h>

TEST(GameConfig, PlayerDefaultsReasonable) {
    PlayerConfig c;
    EXPECT_GT(c.moveSpeed, 0.0f);
    EXPECT_GT(c.turnSpeed, 0.0f);
    EXPECT_GT(c.baseHealth, 0);
    EXPECT_GT(c.hurtDuration, 0.0f);
    EXPECT_GT(c.shakeDuration, 0.0f);
    EXPECT_GT(c.maxLookOffset, 0.0f);
}

TEST(GameConfig, PlayerConfigAssignable) {
    PlayerConfig c;
    c.moveSpeed = 8.0f;
    c.baseHealth = 25;
    c.lookSensitivity = 0.05f;
    EXPECT_FLOAT_EQ(c.moveSpeed, 8.0f);
    EXPECT_EQ(c.baseHealth, 25);
    EXPECT_FLOAT_EQ(c.lookSensitivity, 0.05f);
}

TEST(GameConfig, WeaponConfigDefaults) {
    WeaponConfig w;
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 90);
    EXPECT_EQ(w.clipSize, 30);
    EXPECT_GT(w.fireRate, 0.0f);
    EXPECT_GT(w.bulletSpeed, 0.0f);
    EXPECT_GT(w.reloadTime, 0.0f);
}

TEST(GameConfig, EnemyTemplateDefaults) {
    EnemyTemplateConfig t;
    t.health = 5;
    t.detectionRange = 12.0f;
    t.canDropPickup = true;
    EXPECT_EQ(t.health, 5);
    EXPECT_FLOAT_EQ(t.detectionRange, 12.0f);
    EXPECT_TRUE(t.canDropPickup);
}

TEST(GameConfig, PickupConfigDefaults) {
    PickupConfig p;
    EXPECT_GT(p.ammoPickupAmount, 0);
    EXPECT_GT(p.healAmount, 0);
    EXPECT_GT(p.upgradeCost, 0);
    EXPECT_GT(p.pickupRadius, 0.0f);
    EXPECT_GT(p.projectileRadius, 0.0f);
    EXPECT_GT(p.fireRateCap, 0.0f);
}

TEST(GameConfig, GameplayConfigDefaults) {
    GameplayConfig g;
    EXPECT_GT(g.maxParticles, 0);
    EXPECT_GT(g.maxDecals, 0);
    EXPECT_GT(g.decalLifetime, 0.0f);
    EXPECT_GT(g.snowflakeCount, 0);
    EXPECT_GT(g.ddaMaxSteps, 0);
    EXPECT_GT(g.ddaStepSize, 0.0f);
}

TEST(GameConfig, LoadFromDirectoryFallsBackOnMissingFiles) {
    GameConfig config;
    config.loadFromDirectory("nonexistent/path");
    // All values should remain at defaults
    EXPECT_EQ(config.playerWeapon.ammoClip, 30);
    EXPECT_EQ(config.enemyTemplates.size(), 0u);
    EXPECT_GT(config.pickups.pickupRadius, 0.0f);
    EXPECT_GT(config.game.maxParticles, 0);
}
