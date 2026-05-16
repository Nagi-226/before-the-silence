#pragma once
#include "game/entities/Player.h"
#include "engine/Input.h"

struct PlayerConfig;

/// 移动系统 — 处理玩家移动和墙壁碰撞。
/// 从 Input 读取方向 → 计算新位置 → 碰撞检测 → 写入 Transform。
class MovementSystem
{
public:
    explicit MovementSystem(const PlayerConfig& config) : m_config(config) {}

    /// @param player 玩家实体（读输入 → 写位置）
    /// @param input  输入状态（只读）
    /// @param dT     帧间隔（秒）
    void updatePlayer(Player& player, const Input& input, float dT);

private:
    const PlayerConfig& m_config;
};
