#pragma once
#include <vector>
#include <memory>
#include "math/Vector2D.h"

class Enemy;
class Pickup;

/// 墙壁材质类型
enum class WallMaterial : int {
    Brick = 0,     // X — 砖墙（默认）
    Metal = 1,     // M — 金属板
    Stone = 2,     // S — 石墙
    Grate = 3,     // G — 铁栅栏（半透明）
    COUNT = 4
};

/// 关卡数据 — 168×68 符号地图。
/// 提供墙壁碰撞检测 + 材质查询 + 实体生成 + 光源查询。
class Level
{
public:
    static constexpr int WIDTH = 168;
    static constexpr int HEIGHT = 68;

    // —— 符号定义 ——
    static constexpr char SYMBOL_WALL = 'X';
    static constexpr char SYMBOL_METAL = 'M';
    static constexpr char SYMBOL_STONE = 'S';
    static constexpr char SYMBOL_GRATE = 'G';
    static constexpr char SYMBOL_START = 'P';
    static constexpr char SYMBOL_FINISH = 'F';
    static constexpr char SYMBOL_HEALTH = 'H';
    static constexpr char SYMBOL_COIN = 'C';
    static constexpr char SYMBOL_AMMO = 'A';
    static constexpr char SYMBOL_UPGRADE_HEALTH = 'h';
    static constexpr char SYMBOL_UPGRADE_AMMO = 'a';
    static constexpr char SYMBOL_UPGRADE_SPEED = 'w';
    static constexpr char SYMBOL_ENEMY_SMALL = '0';
    static constexpr char SYMBOL_ENEMY_MEDIUM = '1';
    static constexpr char SYMBOL_ENEMY_LARGE = '2';

    // —— 碰撞检测 ——
    static bool isWall(int x, int y);
    static bool isWalkable(int x, int y) { return !isWall(x, y); }
    static void moveWithWallSlide(float& posX, float& posY, float dx, float dy);

    // —— v0.3.2 墙壁材质 ——
    static WallMaterial getWallMaterial(int x, int y);
    /// 材质是否为实心（铁栅栏是半透明的）
    static bool isSolidMaterial(WallMaterial m) { return m != WallMaterial::Grate; }

    // —— v0.3.5 光源 ——
    struct LightSource {
        int x, y;              // 光源位置（格子坐标）
        float radius;          // 光照半径（格子数）
        float intensity;       // 基础强度 [0, 1]
        unsigned char r, g, b; // 光源颜色 [0, 255]
    };
    /// 查询影响指定格子的所有光源
    static void queryLights(int x, int y, std::vector<LightSource>& out);

    // —— 实体生成 ——
    static void setupEntities(
        std::vector<std::unique_ptr<Enemy>>& enemies,
        std::vector<std::unique_ptr<Pickup>>& pickups,
        Vector2D& startPos,
        Vector2D& finishPos
    );

    static const char* data();
    static size_t dataSize();

private:
    static const char* s_levelData;
    static const size_t s_levelSize;

    /// 从字符推导墙壁材质
    static WallMaterial materialFromSymbol(char symbol);
};
