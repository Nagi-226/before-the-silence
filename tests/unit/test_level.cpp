#include "game/Level.h"
#include "game/entities/Player.h"
#include "game/entities/Enemy.h"
#include "game/entities/Pickup.h"
#include "math/Vector2D.h"
#include <gtest/gtest.h>
#include <vector>
#include <memory>

TEST(Level, IsWallValidWall) {
    EXPECT_TRUE(Level::isWall(0, 0));
}

TEST(Level, IsWallEmptySpace) {
    EXPECT_FALSE(Level::isWall(5, 5));
}

TEST(Level, IsWallOutOfBounds) {
    EXPECT_FALSE(Level::isWall(-1, 0));
    EXPECT_FALSE(Level::isWall(1000, 1000));
}

TEST(Level, IsWallStartPosition) {
    EXPECT_FALSE(Level::isWall(4, 39));
}

TEST(Level, SetupEntitiesCreatesEnemies) {
    std::vector<std::unique_ptr<Enemy>> enemies;
    std::vector<std::unique_ptr<Pickup>> pickups;
    Vector2D start, finish;
    Level::setupEntities(enemies, pickups, start, finish);
    EXPECT_GT(enemies.size(), 20u);
}

TEST(Level, SetupEntitiesCreatesPickups) {
    std::vector<std::unique_ptr<Enemy>> enemies;
    std::vector<std::unique_ptr<Pickup>> pickups;
    Vector2D start, finish;
    Level::setupEntities(enemies, pickups, start, finish);
    EXPECT_GT(pickups.size(), 1000u);
    EXPECT_LT(pickups.size(), 2000u);
}

TEST(Level, SetupEntitiesStartNotZero) {
    std::vector<std::unique_ptr<Enemy>> enemies;
    std::vector<std::unique_ptr<Pickup>> pickups;
    Vector2D start, finish;
    Level::setupEntities(enemies, pickups, start, finish);
    EXPECT_GT(start.x, 0.0f);
    EXPECT_GT(start.y, 0.0f);
    EXPECT_GT(finish.x, 0.0f);
    EXPECT_GT(finish.y, 0.0f);
}

TEST(Level, SetupEntitiesFinishFlag) {
    std::vector<std::unique_ptr<Enemy>> enemies;
    std::vector<std::unique_ptr<Pickup>> pickups;
    Vector2D start, finish;
    Level::setupEntities(enemies, pickups, start, finish);
    bool hasFlag = false;
    for (const auto& p : pickups) {
        if (!p->consumable) { hasFlag = true; break; }
    }
    EXPECT_TRUE(hasFlag);
}

TEST(Pickup, TypeFromSymbol) {
    EXPECT_EQ(Pickup::typeFromSymbol('H'), Pickup::Type::Health);
    EXPECT_EQ(Pickup::typeFromSymbol('C'), Pickup::Type::Coin);
    EXPECT_EQ(Pickup::typeFromSymbol('A'), Pickup::Type::Ammo);
    EXPECT_EQ(Pickup::typeFromSymbol('h'), Pickup::Type::UpgradeHealth);
    EXPECT_EQ(Pickup::typeFromSymbol('a'), Pickup::Type::UpgradeAmmo);
    EXPECT_EQ(Pickup::typeFromSymbol('w'), Pickup::Type::UpgradeSpeed);
}

TEST(Health, TakeDamage) {
    Health h(20, 20);
    h.takeDamage(5);
    EXPECT_EQ(h.current, 15);
}

TEST(Health, TakeDamageNoBelowZero) {
    Health h(1, 20);
    h.takeDamage(999);
    EXPECT_EQ(h.current, 0);
}

TEST(Health, Heal) {
    Health h(5, 20);
    h.heal(10);
    EXPECT_EQ(h.current, 15);
}

TEST(Health, HealNoAboveMax) {
    Health h(15, 20);
    h.heal(100);
    EXPECT_EQ(h.current, 20);
}

TEST(Health, IsAliveIsDead) {
    Health h(1, 20);
    EXPECT_TRUE(h.isAlive());
    EXPECT_FALSE(h.isDead());
    h.takeDamage(1);
    EXPECT_FALSE(h.isAlive());
    EXPECT_TRUE(h.isDead());
}

TEST(WeaponComponent, CanShoot) {
    WeaponComponent w;
    w.ammoClip = 30;
    w.cooldownTimer = 0.0f;
    w.isReloading = false;
    EXPECT_TRUE(w.canShoot());
    w.ammoClip = 0;
    EXPECT_FALSE(w.canShoot());
}

TEST(WeaponComponent, NeedsReload) {
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 90;
    EXPECT_TRUE(w.needsReload());
    w.ammoClip = 30;
    EXPECT_FALSE(w.needsReload());
    w.ammoReserve = 0;
    EXPECT_FALSE(w.needsReload());
}

TEST(WeaponComponent, AmmoString) {
    WeaponComponent w;
    w.ammoClip = 24;
    w.ammoReserve = 45;
    w.isReloading = false;
    EXPECT_NE(w.ammoString().find("24/30"), std::string::npos);
}

TEST(WeaponComponent, ReloadingString) {
    WeaponComponent w;
    w.isReloading = true;
    EXPECT_EQ(w.ammoString(), "换弹中...");
}

TEST(Level, ConstantsConsistent) {
    EXPECT_EQ(Level::dataSize(), Level::WIDTH * Level::HEIGHT);
    EXPECT_EQ(Level::dataSize(), 168u * 68u);
    EXPECT_EQ(Level::dataSize(), 11424u);
}
