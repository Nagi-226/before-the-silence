#include "game/systems/CombatSystem.h"
#include "game/systems/ParticleSystem.h"
#include "game/systems/PureLogic.h"
#include "game/GameConfig.h"
#include "game/entities/Enemy.h"
#include "game/entities/Projectile.h"
#include <algorithm>

void CombatSystem::updatePlayerShooting(Player& player, const Input& input, float dT,
                                         std::vector<std::unique_ptr<Projectile>>& projectiles) {
    auto& w = player.weapon;

    updateCooldown(w, dT);

    if (w.isReloading) return;

    if (autoReloadStart(w)) return;

    if (input.isMouseHeld(SDL_BUTTON_LEFT) && tryFire(w)) {
        Vector2D dir = player.transform.forward();
        Vector2D spawnPos = player.transform.position + dir * m_weaponConfig.spawnOffset;
        projectiles.push_back(std::make_unique<Projectile>(
            spawnPos, dir, true, w.bulletSpeed, w.damage));

        player.muzzleFlashTimer = m_weaponConfig.spawnOffset > 0.0f
            ? m_weaponConfig.spawnOffset * 2.0f
            : 0.05f;
        m_particles.emitSpark(spawnPos, dir, 4);
    }
}

void CombatSystem::updateProjectiles(std::vector<std::unique_ptr<Projectile>>& projectiles,
                                      Player& player, std::vector<std::unique_ptr<Enemy>>& enemies, float dT) {
    for (auto& proj : projectiles) {
        proj->transform.position += proj->direction * proj->speed * dT;
        proj->distanceTraveled += proj->speed * dT;

        if (proj->shotFromPlayer) {
            for (auto& enemy : enemies) {
                if (!enemy->isAlive()) continue;
                if (proj->transform.position.distanceTo(enemy->transform.position) < m_pickupConfig.projectileRadius) {
                    enemy->health.takeDamage(proj->damage);
                    enemy->hurtTimer = Enemy::HURT_FLASH_TIME;
                    m_particles.emitBlood(enemy->transform.position, 4);
                    if (!enemy->isAlive()) {
                        enemy->state = Enemy::State::Dead;
                        m_particles.emitExplosion(enemy->transform.position, 15);
                    }
                    proj->collisionOccurred = true;
                    break;
                }
            }
        }
        else {
            if (proj->transform.position.distanceTo(player.transform.position) < m_pickupConfig.projectileRadius) {
                player.health.takeDamage(proj->damage);
                proj->collisionOccurred = true;

                player.hurtTimer = Player::HURT_DURATION;
                player.shakeTimer = Player::SHAKE_DURATION;
            }
        }
    }

    projectiles.erase(
        std::remove_if(projectiles.begin(), projectiles.end(),
            [](const auto& p) { return p->shouldDestroy(); }),
        projectiles.end());
}
