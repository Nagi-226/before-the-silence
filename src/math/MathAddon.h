#pragma once

/// 数学工具函数 — 纯静态，零状态。
/// 覆盖角度转换、线性插值、值钳制、角度归一化等通用数学操作。
class MathAddon
{
public:
    // —— 角度转换 ——
    static float angleRadToDeg(float rad);
    static float angleDegToRad(float deg);

    // —— 线性插值 ——
    /// 线性插值 t 在 [0,1] 内返回插值，可超出范围
    static float lerp(float a, float b, float t);

    // —— 钳制 ——
    /// 将 value 限制在 [min, max] 范围内
    static float clamp(float value, float min, float max);

    // —— 角度归一化 ——
    /// 将弧度归一化到 [-PI, PI] 范围
    static float wrapAngleRad(float rad);

    // —— 工具 ——
    /// 衰减计时器（delta time 递减并钳制到零）
    /// @return 计时器是否已归零
    static bool decayTimer(float& timer, float dT);

    // —— 常量 ——
    static constexpr float PI = 3.14159265359f;
    static constexpr float PI2 = PI * 2.0f;
    static constexpr float DEG_TO_RAD = PI / 180.0f;
    static constexpr float RAD_TO_DEG = 180.0f / PI;
};
