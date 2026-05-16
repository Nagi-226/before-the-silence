#pragma once
#include "game/components/Transform.h"
#include <string>

/// 拾取物实体 — 组合模式。
class Pickup
{
public:
    enum class Type {
        Health,         // H — 回血
        Coin,           // C — 金币
        Ammo,           // A — 弹药
        UpgradeHealth,  // h — 升级生命上限
        UpgradeAmmo,    // a — 升级弹药上限
        UpgradeSpeed    // w — 升级射速
    };

    Transform transform;
    Type type;
    std::string textureFile;
    std::string soundFile;
    bool consumable = true;
    bool consumed = false;

    // v0.3.4 浮动动画
    float bobPhase = 0.0f;       // sin 波相位
    static constexpr float BOB_SPEED = 3.0f;

    Pickup(Vector2D pos, Type t, const std::string& tex, const std::string& snd = "", bool cons = true)
        : transform(pos)
        , type(t)
        , textureFile(tex)
        , soundFile(snd)
        , consumable(cons)
    {}

    /// 从 legacy 关卡符号创建对应拾取物类型
    static Type typeFromSymbol(char symbol) {
        switch (symbol) {
        case 'H': return Type::Health;
        case 'C': return Type::Coin;
        case 'A': return Type::Ammo;
        case 'h': return Type::UpgradeHealth;
        case 'a': return Type::UpgradeAmmo;
        case 'w': return Type::UpgradeSpeed;
        default:  return Type::Coin;
        }
    }

    /// 获取默认纹理文件名
    static const char* defaultTexture(Type t) {
        switch (t) {
        case Type::Health:        return "Health Pack.bmp";
        case Type::Coin:          return "Coin.bmp";
        case Type::Ammo:          return "Ammo.bmp";
        case Type::UpgradeHealth: return "Upgrade Health.bmp";
        case Type::UpgradeAmmo:   return "Upgrade Ammo.bmp";
        case Type::UpgradeSpeed:  return "Upgrade Weapon Speed.bmp";
        default:                  return "Coin.bmp";
        }
    }
};
