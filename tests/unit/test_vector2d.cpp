#include "math/Vector2D.h"
#include "math/MathAddon.h"
#include <gtest/gtest.h>
#include <cmath>

TEST(Vector2D, ConstructDefault) {
    Vector2D v;
    EXPECT_FLOAT_EQ(v.x, 0.0f);
    EXPECT_FLOAT_EQ(v.y, 0.0f);
}

TEST(Vector2D, ConstructXY) {
    Vector2D v(3.0f, 4.0f);
    EXPECT_FLOAT_EQ(v.x, 3.0f);
    EXPECT_FLOAT_EQ(v.y, 4.0f);
}

TEST(Vector2D, ConstructCopy) {
    Vector2D a(1.0f, 2.0f);
    Vector2D b(a);
    EXPECT_FLOAT_EQ(b.x, 1.0f);
    EXPECT_FLOAT_EQ(b.y, 2.0f);
}

TEST(Vector2D, ConstructFromAngle) {
    Vector2D v(MathAddon::PI / 2.0f);
    EXPECT_NEAR(v.x, 0.0f, 0.0001f);
    EXPECT_NEAR(v.y, 1.0f, 0.0001f);
}

TEST(Vector2D, Magnitude) {
    Vector2D v(3.0f, 4.0f);
    EXPECT_NEAR(v.magnitude(), 5.0f, 0.0001f);
}

TEST(Vector2D, MagnitudeZero) {
    Vector2D v(0.0f, 0.0f);
    EXPECT_FLOAT_EQ(v.magnitude(), 0.0f);
}

TEST(Vector2D, MagnitudeSquared) {
    Vector2D v(3.0f, 4.0f);
    EXPECT_FLOAT_EQ(v.magnitudeSquared(), 25.0f);
}

TEST(Vector2D, Angle) {
    Vector2D v(1.0f, 0.0f);
    EXPECT_NEAR(v.angle(), 0.0f, 0.0001f);
}

TEST(Vector2D, AngleUp) {
    Vector2D v(0.0f, -1.0f);
    EXPECT_NEAR(v.angle(), -MathAddon::PI / 2.0f, 0.0001f);
}

TEST(Vector2D, Normalize) {
    Vector2D v(3.0f, 4.0f);
    Vector2D n = v.normalize();
    EXPECT_NEAR(n.magnitude(), 1.0f, 0.0001f);
    EXPECT_NEAR(n.x, 0.6f, 0.0001f);
    EXPECT_NEAR(n.y, 0.8f, 0.0001f);
}

TEST(Vector2D, NormalizeZeroVector) {
    Vector2D v(0.0f, 0.0f);
    Vector2D n = v.normalize();
    EXPECT_FLOAT_EQ(n.x, 0.0f);
    EXPECT_FLOAT_EQ(n.y, 0.0f);
}

TEST(Vector2D, GetPerpendicular) {
    Vector2D v(1.0f, 0.0f);
    Vector2D p = v.getPerpendicular();
    EXPECT_NEAR(p.x, 0.0f, 0.0001f);
    EXPECT_NEAR(p.y, 1.0f, 0.0001f);
}

TEST(Vector2D, Dot) {
    Vector2D a(1.0f, 0.0f), b(0.0f, 1.0f);
    EXPECT_FLOAT_EQ(a.dot(b), 0.0f);
}

TEST(Vector2D, DotParallel) {
    Vector2D a(2.0f, 0.0f), b(3.0f, 0.0f);
    EXPECT_FLOAT_EQ(a.dot(b), 6.0f);
}

TEST(Vector2D, Cross) {
    Vector2D a(1.0f, 0.0f), b(0.0f, 1.0f);
    EXPECT_FLOAT_EQ(a.cross(b), 1.0f);
}

TEST(Vector2D, AngleBetween) {
    Vector2D a(1.0f, 0.0f), b(0.0f, 1.0f);
    EXPECT_NEAR(a.angleBetween(b), MathAddon::PI / 2.0f, 0.0001f);
}

TEST(Vector2D, DistanceTo) {
    Vector2D a(0.0f, 0.0f), b(3.0f, 4.0f);
    EXPECT_NEAR(a.distanceTo(b), 5.0f, 0.0001f);
}

TEST(Vector2D, AddScalar) {
    Vector2D v(1.0f, 2.0f);
    Vector2D r = v + 3.0f;
    EXPECT_FLOAT_EQ(r.x, 4.0f);
    EXPECT_FLOAT_EQ(r.y, 5.0f);
}

TEST(Vector2D, MulScalar) {
    Vector2D v(2.0f, 3.0f);
    Vector2D r = v * 4.0f;
    EXPECT_FLOAT_EQ(r.x, 8.0f);
    EXPECT_FLOAT_EQ(r.y, 12.0f);
}

TEST(Vector2D, AddAssignScalar) {
    Vector2D v(1.0f, 2.0f);
    v += 10.0f;
    EXPECT_FLOAT_EQ(v.x, 11.0f);
    EXPECT_FLOAT_EQ(v.y, 12.0f);
}

TEST(Vector2D, AddVector) {
    Vector2D a(1.0f, 2.0f), b(3.0f, 4.0f);
    Vector2D r = a + b;
    EXPECT_FLOAT_EQ(r.x, 4.0f);
    EXPECT_FLOAT_EQ(r.y, 6.0f);
}

TEST(Vector2D, SubVector) {
    Vector2D a(5.0f, 4.0f), b(3.0f, 2.0f);
    Vector2D r = a - b;
    EXPECT_FLOAT_EQ(r.x, 2.0f);
    EXPECT_FLOAT_EQ(r.y, 2.0f);
}

TEST(Vector2D, Equal) {
    Vector2D a(1.0f, 2.0f), b(1.0f, 2.0f);
    EXPECT_TRUE(a == b);
}

TEST(Vector2D, NotEqual) {
    Vector2D a(1.0f, 2.0f), b(1.0f, 3.0f);
    EXPECT_TRUE(a != b);
}
