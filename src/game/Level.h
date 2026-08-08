#pragma once
#include <vector>
#include <memory>
#include <string>
#include "math/Vector2D.h"

class Enemy;
class Pickup;

enum class WallMaterial : int {
    Brick = 0, Metal = 1, Stone = 2, Grate = 3, COUNT = 4
};

/// 关卡难度预设
enum class Difficulty : int { Easy = 0, Normal = 1, Hard = 2 };

/// 关卡数据 — 支持多地图 + 难度切换。
class Level
{
public:
    static constexpr int WIDTH = 168;
    static constexpr int HEIGHT = 68;
    static constexpr int MAP_COUNT = 2;  // v0.5.1 双地图

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

    // —— v0.5.1 地图切换 ——
    static void loadMap(int index);
    static int  currentMap() { return s_currentMap; }
    static bool hasNextMap() { return s_currentMap + 1 < MAP_COUNT; }

    // —— 碰撞检测 ——
    static bool isWall(int x, int y);
    static bool isWalkable(int x, int y) { return !isWall(x, y); }
    static void moveWithWallSlide(float& posX, float& posY, float dx, float dy);

    static WallMaterial getWallMaterial(int x, int y);
    static bool isSolidMaterial(WallMaterial m) { return m != WallMaterial::Grate; }

    static float getFloorHeight(int x, int y);
    static float getCeilingHeight(int x, int y);

    struct LightSource {
        int x, y; float radius; float intensity;
        unsigned char r, g, b;
    };
    static void queryLights(int x, int y, std::vector<LightSource>& out);

    // —— v0.5.4 难度 ——
    static Difficulty s_difficulty;
    static float enemyHealthMultiplier();
    static float enemyDamageMultiplier();
    static float enemySpeedMultiplier();

    // —— 实体生成 ——
    static void setupEntities(
        std::vector<std::unique_ptr<Enemy>>& enemies,
        std::vector<std::unique_ptr<Pickup>>& pickups,
        Vector2D& startPos, Vector2D& finishPos);

    static const char* data();
    static size_t dataSize();
    static const char* mapName();

private:
    static const char* s_mapDatas[MAP_COUNT];
    static const char* s_mapNames[MAP_COUNT];
    static int s_currentMap;
    static const char* s_activeData;
    static size_t s_activeSize;

    static WallMaterial materialFromSymbol(char symbol);
};
