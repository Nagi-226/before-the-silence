#pragma once

/// 游戏对象生命周期基类 — 吸收 javidx9 设计理念。
/// 所有游戏对象（Engine/Entity/System）遵循此模式：
///   OnCreate()  → 资源初始化、数据加载
///   OnUpdate(dT) → 每帧固定步长逻辑更新
///   OnDestroy()  → 资源释放
///
/// 使用示例:
///   class Player : public Engine {
///       void OnCreate() override { /* 加载精灵、注册输入 */ }
///       void OnUpdate(float dT) override { /* 处理移动、射击 */ }
///       void OnDestroy() override { /* 释放纹理 */ }
///   };
class Engine
{
public:
    virtual ~Engine() = default;

    /// 创建阶段 — 分配资源、初始化状态
    /// 在所有 OnUpdate 调用之前执行一次
    virtual void OnCreate() {}

    /// 每帧更新 — 固定时间步长 delta time
    /// @param dT 帧间隔（秒），通常为 1/60
    virtual void OnUpdate(float dT) {}

    /// 销毁阶段 — 释放所有资源
    /// 在对象生命周期结束时执行一次
    virtual void OnDestroy() {}
};
