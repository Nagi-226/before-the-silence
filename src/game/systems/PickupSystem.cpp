#include "game/systems/PickupSystem.h"
#include "game/GameConfig.h"
#include "game/entities/Pickup.h"
#include <algorithm>

void PickupSystem::update(Player& player, std::vector<std::unique_ptr<Pickup>>& pickups) {
    for (auto& pickup : pickups) {
        if (pickup->consumed) continue;

        float dist = player.transform.position.distanceTo(pickup->transform.position);
        if (dist < m_config.pickupRadius) {
            if (pickup->consumable) {
                applyPickup(player, *pickup);
            }
            pickup->consumed = true;
        }
    }

    pickups.erase(
        std::remove_if(pickups.begin(), pickups.end(),
            [](const auto& p) { return p->consumed; }),
        pickups.end());
}

void PickupSystem::applyPickup(Player& player, const Pickup& pickup) {
    switch (pickup.type) {
    case Pickup::Type::Health:
        player.health.heal(m_config.healAmount);
        break;
    case Pickup::Type::Coin:
        player.coins++;
        break;
    case Pickup::Type::Ammo:
        player.weapon.ammoReserve += m_config.ammoPickupAmount;
        break;
    case Pickup::Type::UpgradeHealth:
        if (player.coins >= m_config.upgradeCost) {
            player.coins -= m_config.upgradeCost;
            player.health.max += m_config.healthUpgrade;
            player.health.heal(m_config.healthUpgrade);
            player.healthUpgrades++;
        }
        break;
    case Pickup::Type::UpgradeAmmo:
        if (player.coins >= m_config.upgradeCost) {
            player.coins -= m_config.upgradeCost;
            player.weapon.clipSize += m_config.ammoClipUpgrade;
            player.weapon.ammoReserve += m_config.ammoReserveUpgrade;
            player.ammoUpgrades++;
        }
        break;
    case Pickup::Type::UpgradeSpeed:
        if (player.coins >= m_config.upgradeCost) {
            player.coins -= m_config.upgradeCost;
            player.weapon.fireRate = std::min(player.weapon.fireRate + m_config.fireRateUpgrade, m_config.fireRateCap);
            player.speedUpgrades++;
        }
        break;
    }
}
