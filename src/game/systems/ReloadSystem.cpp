#include "game/systems/ReloadSystem.h"
#include "game/systems/PureLogic.h"
#include "engine/Input.h"

void ReloadSystem::update(WeaponComponent& weapon, const Input& input, float dT) {
    // v0.5.1: 防止自动换弹每帧重复触发 — 仅在未换弹且需要换弹时触发
    if (!weapon.isReloading && input.isKeyPressed(SDL_SCANCODE_R) && weapon.needsReload()) {
        weapon.isReloading = true;
        weapon.reloadTimer = 0.0f;
    }
    reloadTimerUpdate(weapon, dT);
}

void ReloadSystem::updateReloadTimer(WeaponComponent& weapon, float dT) {
    reloadTimerUpdate(weapon, dT);
}
