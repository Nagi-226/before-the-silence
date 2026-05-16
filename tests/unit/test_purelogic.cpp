#include "game/systems/PureLogic.h"
#include <gtest/gtest.h>

// ============================================================================
//  reloadTimerUpdate
// ============================================================================

TEST(PureLogic, ReloadTimerCompletesFullReload) {
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    bool done = reloadTimerUpdate(w, 2.0f);

    EXPECT_TRUE(done);
    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 10);
    EXPECT_FLOAT_EQ(w.reloadTimer, 0.0f);
}

TEST(PureLogic, ReloadTimerPartialProgress) {
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    bool done = reloadTimerUpdate(w, 0.8f);

    EXPECT_FALSE(done);
    EXPECT_TRUE(w.isReloading);
    EXPECT_FLOAT_EQ(w.reloadTimer, 0.8f);
    EXPECT_EQ(w.ammoClip, 10);
}

TEST(PureLogic, ReloadTimerInsufficientReserve) {
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 5;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    reloadTimerUpdate(w, 2.0f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 15);   // 10 + 5 partial
    EXPECT_EQ(w.ammoReserve, 0);
}

TEST(PureLogic, ReloadTimerNotReloading) {
    WeaponComponent w;
    w.ammoClip = 5;
    w.ammoReserve = 30;
    w.isReloading = false;

    bool done = reloadTimerUpdate(w, 2.0f);

    EXPECT_FALSE(done);
    EXPECT_EQ(w.ammoClip, 5);
    EXPECT_EQ(w.ammoReserve, 30);
}

TEST(PureLogic, ReloadTimerMultipleCalls) {
    WeaponComponent w;
    w.ammoClip = 0;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    reloadTimerUpdate(w, 0.6f);
    EXPECT_TRUE(w.isReloading);
    reloadTimerUpdate(w, 0.6f);
    EXPECT_TRUE(w.isReloading);
    bool done = reloadTimerUpdate(w, 0.8f);

    EXPECT_TRUE(done);
    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
}

TEST(PureLogic, ReloadTimerFullClipNoTransfer) {
    WeaponComponent w;
    w.ammoClip = 30;
    w.ammoReserve = 90;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    reloadTimerUpdate(w, 2.0f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 90);  // no transfer needed
}

// ============================================================================
//  autoReloadStart
// ============================================================================

TEST(PureLogic, AutoReloadStartsWhenClipEmpty) {
    WeaponComponent w;
    w.ammoClip = 0;
    w.ammoReserve = 30;
    w.isReloading = false;

    bool started = autoReloadStart(w);

    EXPECT_TRUE(started);
    EXPECT_TRUE(w.isReloading);
    EXPECT_FLOAT_EQ(w.reloadTimer, 0.0f);
}

TEST(PureLogic, AutoReloadNoReserve) {
    WeaponComponent w;
    w.ammoClip = 0;
    w.ammoReserve = 0;

    bool started = autoReloadStart(w);

    EXPECT_FALSE(started);
    EXPECT_FALSE(w.isReloading);
}

TEST(PureLogic, AutoReloadAlreadyReloading) {
    WeaponComponent w;
    w.ammoClip = 0;
    w.ammoReserve = 30;
    w.isReloading = true;

    bool started = autoReloadStart(w);

    EXPECT_FALSE(started);  // already reloading
}

TEST(PureLogic, AutoReloadHasAmmoInClip) {
    WeaponComponent w;
    w.ammoClip = 5;
    w.ammoReserve = 30;

    bool started = autoReloadStart(w);

    EXPECT_FALSE(started);  // still has ammo in clip
}

// ============================================================================
//  tryFire / updateCooldown
// ============================================================================

TEST(PureLogic, TryFireSucceeds) {
    WeaponComponent w;
    w.ammoClip = 30;
    w.cooldownTimer = 0.0f;
    w.isReloading = false;
    w.fireRate = 10.0f;

    bool fired = tryFire(w);

    EXPECT_TRUE(fired);
    EXPECT_EQ(w.ammoClip, 29);
    EXPECT_NEAR(w.cooldownTimer, 0.1f, 0.001f);
}

TEST(PureLogic, TryFireFailsEmptyClip) {
    WeaponComponent w;
    w.ammoClip = 0;
    w.cooldownTimer = 0.0f;

    bool fired = tryFire(w);

    EXPECT_FALSE(fired);
}

TEST(PureLogic, TryFireFailsOnCooldown) {
    WeaponComponent w;
    w.ammoClip = 30;
    w.cooldownTimer = 0.5f;

    bool fired = tryFire(w);

    EXPECT_FALSE(fired);
}

TEST(PureLogic, TryFireFailsWhenReloading) {
    WeaponComponent w;
    w.ammoClip = 30;
    w.isReloading = true;

    bool fired = tryFire(w);

    EXPECT_FALSE(fired);
}

TEST(PureLogic, UpdateCooldownDecrements) {
    WeaponComponent w;
    w.cooldownTimer = 0.3f;

    updateCooldown(w, 0.1f);

    EXPECT_NEAR(w.cooldownTimer, 0.2f, 0.001f);
}

TEST(PureLogic, UpdateCooldownReachesZero) {
    WeaponComponent w;
    w.cooldownTimer = 0.05f;

    updateCooldown(w, 0.1f);

    EXPECT_LT(w.cooldownTimer, 0.05f);
}

TEST(PureLogic, UpdateCooldownAlreadyZero) {
    WeaponComponent w;
    w.cooldownTimer = 0.0f;

    updateCooldown(w, 0.1f);

    EXPECT_FLOAT_EQ(w.cooldownTimer, 0.0f);
}

// ============================================================================
//  isWithinRadius
// ============================================================================

TEST(PureLogic, IsWithinRadiusTrue) {
    EXPECT_TRUE(isWithinRadius(Vector2D(0, 0), Vector2D(0.5f, 0), 1.0f));
}

TEST(PureLogic, IsWithinRadiusFalse) {
    EXPECT_FALSE(isWithinRadius(Vector2D(0, 0), Vector2D(2.0f, 0), 1.0f));
}

TEST(PureLogic, IsWithinRadiusExactBoundary) {
    // distance = 1.0, radius = 1.0 — not within (< not <=)
    EXPECT_FALSE(isWithinRadius(Vector2D(0, 0), Vector2D(1.0f, 0), 1.0f));
}
