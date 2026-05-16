#include "math/MathAddon.h"
#include <gtest/gtest.h>
#include <cmath>

TEST(MathAddon, RadToDeg0) {
    EXPECT_NEAR(MathAddon::angleRadToDeg(0.0f), 0.0f, 0.0001f);
}

TEST(MathAddon, RadToDegPi) {
    EXPECT_NEAR(MathAddon::angleRadToDeg(MathAddon::PI), 180.0f, 0.0001f);
}

TEST(MathAddon, RadToDeg2Pi) {
    EXPECT_NEAR(MathAddon::angleRadToDeg(MathAddon::PI2), 360.0f, 0.0001f);
}

TEST(MathAddon, DegToRad0) {
    EXPECT_NEAR(MathAddon::angleDegToRad(0.0f), 0.0f, 0.0001f);
}

TEST(MathAddon, DegToRad180) {
    EXPECT_NEAR(MathAddon::angleDegToRad(180.0f), MathAddon::PI, 0.0001f);
}

TEST(MathAddon, DegToRad360) {
    EXPECT_NEAR(MathAddon::angleDegToRad(360.0f), MathAddon::PI2, 0.0001f);
}

TEST(MathAddon, RadDegRoundtrip) {
    float rad = 1.5f;
    float deg = MathAddon::angleRadToDeg(rad);
    float back = MathAddon::angleDegToRad(deg);
    EXPECT_NEAR(back, rad, 0.0001f);
}

TEST(MathAddon, LerpT0) {
    EXPECT_FLOAT_EQ(MathAddon::lerp(10.0f, 20.0f, 0.0f), 10.0f);
}

TEST(MathAddon, LerpT1) {
    EXPECT_FLOAT_EQ(MathAddon::lerp(10.0f, 20.0f, 1.0f), 20.0f);
}

TEST(MathAddon, LerpHalf) {
    EXPECT_FLOAT_EQ(MathAddon::lerp(10.0f, 20.0f, 0.5f), 15.0f);
}

TEST(MathAddon, LerpExtrapolate) {
    EXPECT_FLOAT_EQ(MathAddon::lerp(10.0f, 20.0f, 2.0f), 30.0f);
}

TEST(MathAddon, LerpNegativeT) {
    EXPECT_FLOAT_EQ(MathAddon::lerp(10.0f, 20.0f, -1.0f), 0.0f);
}

TEST(MathAddon, ClampWithinRange) {
    EXPECT_FLOAT_EQ(MathAddon::clamp(5.0f, 0.0f, 10.0f), 5.0f);
}

TEST(MathAddon, ClampBelowMin) {
    EXPECT_FLOAT_EQ(MathAddon::clamp(-5.0f, 0.0f, 10.0f), 0.0f);
}

TEST(MathAddon, ClampAboveMax) {
    EXPECT_FLOAT_EQ(MathAddon::clamp(15.0f, 0.0f, 10.0f), 10.0f);
}

TEST(MathAddon, ClampAtMin) {
    EXPECT_FLOAT_EQ(MathAddon::clamp(0.0f, 0.0f, 10.0f), 0.0f);
}

TEST(MathAddon, ClampAtMax) {
    EXPECT_FLOAT_EQ(MathAddon::clamp(10.0f, 0.0f, 10.0f), 10.0f);
}

TEST(MathAddon, ClampMinGreaterThanMax) {
    float result = MathAddon::clamp(5.0f, 10.0f, 0.0f);
    EXPECT_FLOAT_EQ(result, 10.0f);
}

TEST(MathAddon, WrapAngle0) {
    EXPECT_NEAR(MathAddon::wrapAngleRad(0.0f), 0.0f, 0.0001f);
}

TEST(MathAddon, WrapAnglePi) {
    EXPECT_NEAR(MathAddon::wrapAngleRad(MathAddon::PI), MathAddon::PI, 0.0001f);
}

TEST(MathAddon, WrapAngleNegativePi) {
    EXPECT_NEAR(MathAddon::wrapAngleRad(-MathAddon::PI), -MathAddon::PI, 0.0001f);
}

TEST(MathAddon, WrapAngleOverPi) {
    float result = MathAddon::wrapAngleRad(MathAddon::PI + 0.5f);
    EXPECT_NEAR(result, -MathAddon::PI + 0.5f, 0.0001f);
}

TEST(MathAddon, WrapAngle3Pi) {
    float result = MathAddon::wrapAngleRad(3.0f * MathAddon::PI);
    bool ok = std::abs(result - MathAddon::PI) < 0.0001f
           || std::abs(result + MathAddon::PI) < 0.0001f;
    EXPECT_TRUE(ok);
}

TEST(MathAddon, WrapAngleNegative3Pi) {
    float result = MathAddon::wrapAngleRad(-3.0f * MathAddon::PI);
    bool ok = std::abs(result - MathAddon::PI) < 0.0001f
           || std::abs(result + MathAddon::PI) < 0.0001f;
    EXPECT_TRUE(ok);
}

TEST(MathAddon, DecayTimerNormal) {
    float timer = 1.0f;
    bool done = MathAddon::decayTimer(timer, 0.3f);
    EXPECT_NEAR(timer, 0.7f, 0.0001f);
    EXPECT_FALSE(done);
}

TEST(MathAddon, DecayTimerReachZero) {
    float timer = 0.2f;
    bool done = MathAddon::decayTimer(timer, 0.5f);
    EXPECT_FLOAT_EQ(timer, 0.0f);
    EXPECT_TRUE(done);
}

TEST(MathAddon, DecayTimerAlreadyZero) {
    float timer = 0.0f;
    bool done = MathAddon::decayTimer(timer, 0.1f);
    EXPECT_FLOAT_EQ(timer, 0.0f);
    EXPECT_TRUE(done);
}

TEST(MathAddon, DecayTimerNegativeReset) {
    float timer = -1.0f;
    bool done = MathAddon::decayTimer(timer, 0.0f);
    EXPECT_FLOAT_EQ(timer, 0.0f);
    EXPECT_TRUE(done);
}

TEST(MathAddon, Constants) {
    EXPECT_GT(MathAddon::PI, 3.14f);
    EXPECT_LT(MathAddon::PI, 3.15f);
    EXPECT_NEAR(MathAddon::PI2, 2.0f * MathAddon::PI, 0.0001f);
}
