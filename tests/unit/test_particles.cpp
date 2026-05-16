#include "game/systems/ParticleSystem.h"
#include <gtest/gtest.h>

TEST(ParticleSystem, ConstructorDefault) {
    ParticleSystem ps;
    EXPECT_EQ(ps.activeCount(), 0);
}

TEST(ParticleSystem, ConstructorCustomMax) {
    ParticleSystem ps(100);
    EXPECT_EQ(ps.activeCount(), 0);
}

TEST(ParticleSystem, EmitSingle) {
    ParticleSystem ps;
    Particle p;
    p.lifetime = 1.0f;
    p.maxLifetime = 1.0f;
    ps.emit(p);
    EXPECT_EQ(ps.activeCount(), 1);
}

TEST(ParticleSystem, EmitMultiple) {
    ParticleSystem ps;
    for (int i = 0; i < 5; ++i) {
        Particle p;
        p.lifetime = 1.0f;
        p.maxLifetime = 1.0f;
        ps.emit(p);
    }
    EXPECT_EQ(ps.activeCount(), 5);
}

TEST(ParticleSystem, EmitRespectsMaxLimit) {
    ParticleSystem ps(5);
    for (int i = 0; i < 10; ++i) {
        Particle p;
        p.lifetime = 1.0f;
        p.maxLifetime = 1.0f;
        ps.emit(p);
    }
    EXPECT_LE(ps.activeCount(), 5);
}

TEST(ParticleSystem, UpdateMovesParticles) {
    ParticleSystem ps;
    Particle p;
    p.position = Vector2D(0.0f, 0.0f);
    p.velocity = Vector2D(1.0f, 0.0f);
    p.lifetime = 1.0f;
    p.maxLifetime = 1.0f;
    ps.emit(p);

    ps.update(0.5f);

    EXPECT_EQ(ps.activeCount(), 1);
    EXPECT_NEAR(ps.activeParticles()[0].position.x, 0.5f, 0.001f);
    EXPECT_NEAR(ps.activeParticles()[0].lifetime, 0.5f, 0.001f);
    EXPECT_GT(ps.activeParticles()[0].velocity.y, 0.0f);  // gravity
}

TEST(ParticleSystem, UpdateRemovesDeadParticles) {
    ParticleSystem ps;
    Particle p;
    p.lifetime = 0.1f;
    p.maxLifetime = 0.1f;
    ps.emit(p);

    ps.update(0.2f);

    EXPECT_EQ(ps.activeCount(), 0);
}

TEST(ParticleSystem, AlphaCalculation) {
    Particle p;
    p.lifetime = 0.5f;
    p.maxLifetime = 1.0f;
    EXPECT_NEAR(p.alpha(), 0.5f, 0.001f);
}

TEST(ParticleSystem, AlphaDeadParticle) {
    Particle p;
    p.lifetime = 0.0f;
    p.maxLifetime = 1.0f;
    EXPECT_FLOAT_EQ(p.alpha(), 0.0f);

    p.maxLifetime = 0.0f;
    EXPECT_FLOAT_EQ(p.alpha(), 0.0f);
}

TEST(ParticleSystem, EmitSparkCreatesParticles) {
    ParticleSystem ps;
    ps.emitSpark(Vector2D(5.0f, 5.0f), Vector2D(1.0f, 0.0f), 6);
    EXPECT_EQ(ps.activeCount(), 6);
}

TEST(ParticleSystem, EmitBloodCreatesParticles) {
    ParticleSystem ps;
    ps.emitBlood(Vector2D(5.0f, 5.0f), 8);
    EXPECT_EQ(ps.activeCount(), 8);
}

TEST(ParticleSystem, EmitExplosionCreatesParticles) {
    ParticleSystem ps;
    ps.emitExplosion(Vector2D(5.0f, 5.0f), 12);
    EXPECT_EQ(ps.activeCount(), 12);
}

TEST(ParticleSystem, ClearEmptiesAll) {
    ParticleSystem ps;
    for (int i = 0; i < 10; ++i) {
        Particle p;
        p.lifetime = 1.0f;
        p.maxLifetime = 1.0f;
        ps.emit(p);
    }

    ps.clear();

    EXPECT_EQ(ps.activeCount(), 0);
}

TEST(ParticleSystem, IsDeadCheck) {
    Particle p;
    p.lifetime = 1.0f;
    EXPECT_FALSE(p.isDead());

    p.lifetime = 0.0f;
    EXPECT_TRUE(p.isDead());

    p.lifetime = -0.1f;
    EXPECT_TRUE(p.isDead());
}

TEST(ParticleSystem, EmitFromSparkHasCorrectColor) {
    ParticleSystem ps;
    ps.emitSpark(Vector2D(0, 0), Vector2D(0, -1), 1);

    ASSERT_EQ(ps.activeCount(), 1);
    EXPECT_EQ(ps.activeParticles()[0].r, 255);
    EXPECT_GE(ps.activeParticles()[0].g, 200);
    EXPECT_LE(ps.activeParticles()[0].g, 255);
}

TEST(ParticleSystem, EmitFromBloodHasCorrectColor) {
    ParticleSystem ps;
    ps.emitBlood(Vector2D(0, 0), 1);

    ASSERT_EQ(ps.activeCount(), 1);
    EXPECT_GE(ps.activeParticles()[0].r, 180);
    EXPECT_EQ(ps.activeParticles()[0].g, 0);
    EXPECT_EQ(ps.activeParticles()[0].b, 0);
}

TEST(ParticleSystem, GravityAppliedDuringUpdate) {
    ParticleSystem ps;
    Particle p;
    p.position = Vector2D(0, 0);
    p.velocity = Vector2D(0, 0);
    p.lifetime = 2.0f;
    p.maxLifetime = 2.0f;
    ps.emit(p);

    ps.update(1.0f);

    ASSERT_EQ(ps.activeCount(), 1);
    EXPECT_GT(ps.activeParticles()[0].velocity.y, 0.0f);
}

TEST(ParticleSystem, PoolWrapAroundWorks) {
    ParticleSystem ps(3);
    for (int i = 0; i < 6; ++i) {
        Particle p;
        p.lifetime = 1.0f;
        p.maxLifetime = 1.0f;
        ps.emit(p);
    }
    // Pool size 3, after 6 emits, should still have 3 particles
    EXPECT_EQ(ps.activeCount(), 3);
}
