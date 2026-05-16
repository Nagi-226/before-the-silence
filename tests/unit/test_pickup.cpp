#include "game/systems/PickupSystem.h"
#include "game/GameConfig.h"
#include "game/entities/Player.h"
#include "game/entities/Pickup.h"
#include <gtest/gtest.h>

class PickupSystemTest : public ::testing::Test {
protected:
    PickupConfig config;
    PickupSystem sys{config};
};

TEST_F(PickupSystemTest, HealthPickupHeals) {
    Player player(Vector2D(0, 0));
    player.health = Health(5, 20);

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::Health, "", "", true));

    sys.update(player, pickups);

    EXPECT_GT(player.health.current, 5);
    EXPECT_TRUE(pickups.empty());  // consumed and removed
}

TEST_F(PickupSystemTest, CoinPickupIncrementsCoins) {
    Player player(Vector2D(0, 0));
    player.coins = 0;

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::Coin, "", "", true));

    sys.update(player, pickups);

    EXPECT_EQ(player.coins, 1);
    EXPECT_TRUE(pickups.empty());
}

TEST_F(PickupSystemTest, AmmoPickupAddsReserve) {
    Player player(Vector2D(0, 0));
    player.weapon.ammoReserve = 10;

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::Ammo, "", "", true));

    sys.update(player, pickups);

    EXPECT_EQ(player.weapon.ammoReserve, 20);
}

TEST_F(PickupSystemTest, FarPickupNotCollected) {
    Player player(Vector2D(0, 0));

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(10.0f, 10.0f), Pickup::Type::Coin, "", "", true));

    sys.update(player, pickups);

    EXPECT_EQ(player.coins, 0);
    EXPECT_EQ(pickups.size(), 1u);  // not collected
}

TEST_F(PickupSystemTest, UpgradeHealthNeedsCoins) {
    Player player(Vector2D(0, 0));
    player.coins = 5;  // not enough for upgrade (cost = 10)
    player.health = Health(10, 20);

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::UpgradeHealth, "", "", true));

    sys.update(player, pickups);

    // Should not apply upgrade — insufficient coins
    EXPECT_EQ(player.coins, 5);
    EXPECT_EQ(player.health.max, 20);
    EXPECT_EQ(player.healthUpgrades, 0);
}

TEST_F(PickupSystemTest, UpgradeHealthWithEnoughCoins) {
    Player player(Vector2D(0, 0));
    player.coins = 10;
    player.health = Health(10, 20);

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::UpgradeHealth, "", "", true));

    sys.update(player, pickups);

    EXPECT_EQ(player.coins, 0);
    EXPECT_EQ(player.health.max, 25);
    EXPECT_GT(player.health.current, 10);  // also healed
    EXPECT_EQ(player.healthUpgrades, 1);
}

TEST_F(PickupSystemTest, UpgradeSpeed) {
    Player player(Vector2D(0, 0));
    player.coins = 10;
    player.weapon.fireRate = 10.0f;

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::UpgradeSpeed, "", "", true));

    sys.update(player, pickups);

    EXPECT_EQ(player.coins, 0);
    EXPECT_NEAR(player.weapon.fireRate, 12.0f, 0.01f);
    EXPECT_EQ(player.speedUpgrades, 1);
}

TEST_F(PickupSystemTest, UpgradeSpeedCapped) {
    Player player(Vector2D(0, 0));
    player.coins = 50;
    player.weapon.fireRate = 19.0f;

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::UpgradeSpeed, "", "", true));

    sys.update(player, pickups);

    EXPECT_NEAR(player.weapon.fireRate, 20.0f, 0.01f);  // capped
}

TEST_F(PickupSystemTest, MultiplePickupsCollected) {
    Player player(Vector2D(0, 0));
    player.coins = 0;

    std::vector<std::unique_ptr<Pickup>> pickups;
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.3f, 0.0f), Pickup::Type::Coin, "", "", true));
    pickups.push_back(std::make_unique<Pickup>(
        Vector2D(0.6f, 0.0f), Pickup::Type::Coin, "", "", true));

    sys.update(player, pickups);

    EXPECT_EQ(player.coins, 2);
    EXPECT_TRUE(pickups.empty());
}

TEST_F(PickupSystemTest, AlreadyConsumedPickupSkipped) {
    Player player(Vector2D(0, 0));

    std::vector<std::unique_ptr<Pickup>> pickups;
    auto p = std::make_unique<Pickup>(
        Vector2D(0.5f, 0.0f), Pickup::Type::Coin, "", "", true);
    p->consumed = true;
    pickups.push_back(std::move(p));

    sys.update(player, pickups);

    EXPECT_EQ(player.coins, 0);
    EXPECT_TRUE(pickups.empty());  // consumed items get erased
}
