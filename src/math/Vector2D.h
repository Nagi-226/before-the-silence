#pragma once
#include <cmath>

/// 2D 向量 — 纯计算零依赖。
/// 用于位置、方向、速度等所有 2D 几何计算。
/// 操作符返回新对象（值语义），符合 C++17 惯用法。
class Vector2D
{
public:
    Vector2D()                       : x(0.0f), y(0.0f) {}
    Vector2D(float sx, float sy)     : x(sx), y(sy) {}
    Vector2D(const Vector2D& other)  : x(other.x), y(other.y) {}
    /// 从弧度角构造单位方向向量
    explicit Vector2D(float angleRad) : x(std::cos(angleRad)), y(std::sin(angleRad)) {}

    // —— 查询 ——
    float angle() const { return std::atan2(y, x); }
    float magnitude() const { return std::sqrt(x * x + y * y); }
    float magnitudeSquared() const { return x * x + y * y; }

    // —— 变换 ——
    /// 返回归一化向量（零向量保持不变）
    Vector2D normalize() const;
    /// 返回垂直向量（逆时针旋转 90°）
    Vector2D getPerpendicular() const { return Vector2D(-y, x); }

    // —— 向量运算 ——
    float dot(const Vector2D& other) const { return x * other.x + y * other.y; }
    float cross(const Vector2D& other) const { return x * other.y - y * other.x; }
    /// 返回从 this 到 other 的有向夹角（弧度），范围 [-PI, PI]
    float angleBetween(const Vector2D& other) const { return std::atan2(cross(other), dot(other)); }
    /// 返回到 other 的距离
    float distanceTo(const Vector2D& other) const {
        float dx = x - other.x, dy = y - other.y;
        return std::sqrt(dx * dx + dy * dy);
    }

    // —— 标量算子 ——
    Vector2D operator+(float v) const { return Vector2D(x + v, y + v); }
    Vector2D operator-(float v) const { return Vector2D(x - v, y - v); }
    Vector2D operator*(float v) const { return Vector2D(x * v, y * v); }
    Vector2D operator/(float v) const { return (v != 0.0f) ? Vector2D(x / v, y / v) : Vector2D(); }

    Vector2D& operator+=(float v) { x += v; y += v; return *this; }
    Vector2D& operator-=(float v) { x -= v; y -= v; return *this; }
    Vector2D& operator*=(float v) { x *= v; y *= v; return *this; }
    Vector2D& operator/=(float v) { if (v != 0.0f) { x /= v; y /= v; } return *this; }

    // —— 向量算子 ——
    Vector2D operator+(const Vector2D& o) const { return Vector2D(x + o.x, y + o.y); }
    Vector2D operator-(const Vector2D& o) const { return Vector2D(x - o.x, y - o.y); }
    Vector2D operator*(const Vector2D& o) const { return Vector2D(x * o.x, y * o.y); }
    Vector2D operator/(const Vector2D& o) const {
        return Vector2D((o.x != 0.0f) ? x / o.x : 0.0f,
                        (o.y != 0.0f) ? y / o.y : 0.0f);
    }

    Vector2D& operator+=(const Vector2D& o) { x += o.x; y += o.y; return *this; }
    Vector2D& operator-=(const Vector2D& o) { x -= o.x; y -= o.y; return *this; }
    Vector2D& operator*=(const Vector2D& o) { x *= o.x; y *= o.y; return *this; }
    Vector2D& operator/=(const Vector2D& o) {
        x = (o.x != 0.0f) ? x / o.x : 0.0f;
        y = (o.y != 0.0f) ? y / o.y : 0.0f;
        return *this;
    }

    // —— 比较 ——
    bool operator==(const Vector2D& o) const { return x == o.x && y == o.y; }
    bool operator!=(const Vector2D& o) const { return !(*this == o); }

    float x, y;
};
