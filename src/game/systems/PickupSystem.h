#pragma once
#include "game/entities/Player.h"
#include <vector>
#include <memory>

struct PickupConfig;
class Pickup;

/// 拾取系统 — 处理玩家接触拾取物。
class PickupSystem
{
public:
    explicit PickupSystem(const PickupConfig& config) : m_config(config) {}

    /// 检测玩家与所有拾取物的重叠
    void update(Player& player, std::vector<std::unique_ptr<Pickup>>& pickups);

private:
    void applyPickup(Player& player, const Pickup& pickup);
    const PickupConfig& m_config;
};
