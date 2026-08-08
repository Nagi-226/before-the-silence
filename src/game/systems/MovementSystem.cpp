#include "game/systems/MovementSystem.h"
#include "game/GameConfig.h"
#include "game/Level.h"
#include "math/MathAddon.h"
#include <cmath>

void MovementSystem::updatePlayer(Player& player, const Input& input, float dT) {
    player.moveForward = 0;
    player.moveRight = 0;
    player.moveForward += input.isKeyHeld(SDL_SCANCODE_W) ? 1 : 0;
    player.moveForward -= input.isKeyHeld(SDL_SCANCODE_S) ? 1 : 0;
    player.moveRight   += input.isKeyHeld(SDL_SCANCODE_D) ? 1 : 0;
    player.moveRight   -= input.isKeyHeld(SDL_SCANCODE_A) ? 1 : 0;

    player.isMoving = (player.moveForward != 0 || player.moveRight != 0);

    // 视角转动（鼠标 X）
    player.turnAmount = input.getMouseDeltaX() * 0.005f;
    player.transform.angle += player.turnAmount * m_config.turnSpeed;
    player.transform.angle = MathAddon::wrapAngleRad(player.transform.angle);

    // 上下视角（鼠标上推 = 往上看，下推 = 往下看，负号修正 SDL Y 轴反转）
    player.lookOffset -= input.getMouseDeltaY() * m_config.lookSensitivity;
    player.lookOffset = MathAddon::clamp(player.lookOffset,
        -m_config.maxLookOffset, m_config.maxLookOffset);

    // 计算移动向量
    Vector2D forward = player.transform.forward();
    Vector2D right = forward.getPerpendicular();

    float moveX = forward.x * player.moveForward + right.x * player.moveRight;
    float moveY = forward.y * player.moveForward + right.y * player.moveRight;

    float len = std::sqrt(moveX * moveX + moveY * moveY);
    if (len > 0.0f) {
        moveX = moveX / len * m_config.moveSpeed * dT;
        moveY = moveY / len * m_config.moveSpeed * dT;
    }

    Level::moveWithWallSlide(player.transform.position.x, player.transform.position.y, moveX, moveY);

    // 视觉反馈计时器衰减
    MathAddon::decayTimer(player.hurtTimer, dT);
    MathAddon::decayTimer(player.shakeTimer, dT);
    MathAddon::decayTimer(player.muzzleFlashTimer, dT);

    // 视角晃动（行走时 sin 波 Y 偏移）
    if (player.isMoving) {
        player.bobPhase += dT * m_config.bobbingSpeed;
    } else {
        if (std::abs(player.bobPhase) < 0.01f) {
            player.bobPhase = 0.0f;
        } else {
            player.bobPhase *= 0.9f;
        }
    }
}
