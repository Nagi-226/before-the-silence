#include "game/systems/ReloadSystem.h"
#include "game/components/WeaponComponent.h"
#include <gtest/gtest.h>

TEST(ReloadSystem, UpdateReloadTimerCompletesReload) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    // Simulate complete reload
    sys.updateReloadTimer(w, 2.0f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);    // 10 + 20 from reserve
    EXPECT_EQ(w.ammoReserve, 10); // 30 - 20 transferred
    EXPECT_FLOAT_EQ(w.reloadTimer, 0.0f);
}

TEST(ReloadSystem, UpdateReloadTimerPartialProgress) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    sys.updateReloadTimer(w, 0.8f);

    EXPECT_TRUE(w.isReloading);
    EXPECT_FLOAT_EQ(w.reloadTimer, 0.8f);
    EXPECT_EQ(w.ammoClip, 10);  // unchanged until complete
}

TEST(ReloadSystem, UpdateReloadTimerExactAtBoundary) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 0;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    sys.updateReloadTimer(w, 2.0f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 0);
}

TEST(ReloadSystem, UpdateReloadTimerOverTime) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 5;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    // More than needed
    sys.updateReloadTimer(w, 3.0f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 5);   // 30 - 25 = 5
}

TEST(ReloadSystem, UpdateReloadTimerInsufficientReserve) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 5;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    sys.updateReloadTimer(w, 2.0f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 15);    // 10 + 5
    EXPECT_EQ(w.ammoReserve, 0);
}

TEST(ReloadSystem, UpdateReloadTimerNotReloading) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 30;
    w.isReloading = false;

    sys.updateReloadTimer(w, 2.0f);

    // Nothing should change
    EXPECT_EQ(w.ammoClip, 10);
    EXPECT_EQ(w.ammoReserve, 30);
    EXPECT_FALSE(w.isReloading);
}

TEST(ReloadSystem, UpdateReloadTimerZeroReloadTime) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 10;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 0.0f;  // instant reload
    w.isReloading = true;

    sys.updateReloadTimer(w, 0.0f);  // dT = 0, but timer >= reloadTime (0 >= 0)

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 10);
}

TEST(ReloadSystem, MultiplePartialUpdates) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 0;
    w.ammoReserve = 30;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    sys.updateReloadTimer(w, 0.5f);
    sys.updateReloadTimer(w, 0.5f);
    sys.updateReloadTimer(w, 0.5f);
    sys.updateReloadTimer(w, 0.5f);

    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
}

TEST(ReloadSystem, FullClipDoesNotNeedMoreAmmo) {
    ReloadSystem sys;
    WeaponComponent w;
    w.ammoClip = 30;
    w.ammoReserve = 90;
    w.clipSize = 30;
    w.reloadTime = 2.0f;
    w.isReloading = true;

    sys.updateReloadTimer(w, 2.0f);

    // Full clip, no transfer needed
    EXPECT_FALSE(w.isReloading);
    EXPECT_EQ(w.ammoClip, 30);
    EXPECT_EQ(w.ammoReserve, 90);
}
