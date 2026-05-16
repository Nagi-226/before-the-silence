#include "game/GameConfig.h"
#include <nlohmann/json.hpp>
#include <fstream>
#include <iostream>

using json = nlohmann::json;

namespace {

bool readFile(const std::string& path, json& out) {
    std::ifstream f(path);
    if (!f.is_open()) {
        std::cerr << "GameConfig: cannot open " << path << std::endl;
        return false;
    }
    try {
        f >> out;
    } catch (const json::parse_error& e) {
        std::cerr << "GameConfig: parse error in " << path << ": " << e.what() << std::endl;
        return false;
    }
    return true;
}

void loadPlayer(const std::string& dir, PlayerConfig& c) {
    json j;
    if (!readFile(dir + "/player.json", j)) return;
    if (j.contains("moveSpeed"))          c.moveSpeed = j["moveSpeed"];
    if (j.contains("turnSpeed"))          c.turnSpeed = j["turnSpeed"];
    if (j.contains("baseHealth"))         c.baseHealth = j["baseHealth"];
    if (j.contains("feedback")) {
        auto& fb = j["feedback"];
        if (fb.contains("hurtDuration"))         c.hurtDuration = fb["hurtDuration"];
        if (fb.contains("shakeDuration"))        c.shakeDuration = fb["shakeDuration"];
        if (fb.contains("muzzleFlashDuration"))  c.muzzleFlashDuration = fb["muzzleFlashDuration"];
        if (fb.contains("bobbingSpeed"))         c.bobbingSpeed = fb["bobbingSpeed"];
        if (fb.contains("bobbingAmplitude"))     c.bobbingAmplitude = fb["bobbingAmplitude"];
    }
    if (j.contains("look")) {
        auto& lk = j["look"];
        if (lk.contains("sensitivity"))  c.lookSensitivity = lk["sensitivity"];
        if (lk.contains("maxOffset"))    c.maxLookOffset = lk["maxOffset"];
    }
}

void loadWeapons(const std::string& dir, WeaponConfig& playerWeapon, std::vector<EnemyTemplateConfig>& templates) {
    json j;
    if (!readFile(dir + "/weapons.json", j)) return;
    if (j.contains("player")) {
        auto& p = j["player"];
        if (p.contains("ammoClip"))      playerWeapon.ammoClip = p["ammoClip"];
        if (p.contains("ammoReserve"))   playerWeapon.ammoReserve = p["ammoReserve"];
        if (p.contains("clipSize"))      playerWeapon.clipSize = p["clipSize"];
        if (p.contains("fireRate"))      playerWeapon.fireRate = p["fireRate"];
        if (p.contains("damage"))        playerWeapon.damage = p["damage"];
        if (p.contains("bulletSpeed"))   playerWeapon.bulletSpeed = p["bulletSpeed"];
        if (p.contains("bulletRange"))   playerWeapon.bulletRange = p["bulletRange"];
        if (p.contains("reloadTime"))    playerWeapon.reloadTime = p["reloadTime"];
        if (p.contains("spawnOffset"))   playerWeapon.spawnOffset = p["spawnOffset"];
    }
    if (j.contains("enemyTemplates") && j["enemyTemplates"].is_array()) {
        for (size_t i = 0; i < j["enemyTemplates"].size() && i < templates.size(); ++i) {
            auto& e = j["enemyTemplates"][i];
            if (e.contains("damage"))       templates[i].weapon.damage = e["damage"];
            if (e.contains("fireRate"))     templates[i].weapon.fireRate = e["fireRate"];
            if (e.contains("bulletSpeed"))  templates[i].weapon.bulletSpeed = e["bulletSpeed"];
        }
    }
}

void loadEnemies(const std::string& dir, std::vector<EnemyTemplateConfig>& templates) {
    json j;
    if (!readFile(dir + "/enemies.json", j)) return;
    if (j.contains("templates") && j["templates"].is_array()) {
        templates.clear();
        for (auto& e : j["templates"]) {
            EnemyTemplateConfig t;
            if (e.contains("textureFile"))     t.textureFile = e["textureFile"];
            if (e.contains("health"))          t.health = e["health"];
            if (e.contains("detectionRange"))  t.detectionRange = e["detectionRange"];
            if (e.contains("attackRange"))     t.attackRange = e["attackRange"];
            if (e.contains("moveSpeed"))       t.moveSpeed = e["moveSpeed"];
            if (e.contains("canDropPickup"))   t.canDropPickup = e["canDropPickup"];
            templates.push_back(t);
        }
    }
}

void loadPickups(const std::string& dir, PickupConfig& c) {
    json j;
    if (!readFile(dir + "/pickups.json", j)) return;
    if (j.contains("amounts")) {
        auto& a = j["amounts"];
        if (a.contains("ammoPickup"))  c.ammoPickupAmount = a["ammoPickup"];
        if (a.contains("healAmount"))  c.healAmount = a["healAmount"];
    }
    if (j.contains("upgrades")) {
        auto& u = j["upgrades"];
        if (u.contains("cost"))                c.upgradeCost = u["cost"];
        if (u.contains("healthUpgrade"))       c.healthUpgrade = u["healthUpgrade"];
        if (u.contains("ammoClipUpgrade"))     c.ammoClipUpgrade = u["ammoClipUpgrade"];
        if (u.contains("ammoReserveUpgrade"))  c.ammoReserveUpgrade = u["ammoReserveUpgrade"];
        if (u.contains("fireRateUpgrade"))     c.fireRateUpgrade = u["fireRateUpgrade"];
        if (u.contains("fireRateCap"))         c.fireRateCap = u["fireRateCap"];
    }
    if (j.contains("collision")) {
        auto& cl = j["collision"];
        if (cl.contains("pickupRadius"))     c.pickupRadius = cl["pickupRadius"];
        if (cl.contains("projectileRadius")) c.projectileRadius = cl["projectileRadius"];
    }
}

void loadGame(const std::string& dir, GameplayConfig& c) {
    json j;
    if (!readFile(dir + "/game.json", j)) return;
    if (j.contains("particles")) {
        auto& p = j["particles"];
        if (p.contains("maxParticles"))  c.maxParticles = p["maxParticles"];
    }
    if (j.contains("decals")) {
        auto& d = j["decals"];
        if (d.contains("maxDecals"))   c.maxDecals = d["maxDecals"];
        if (d.contains("lifetime"))    c.decalLifetime = d["lifetime"];
    }
    if (j.contains("weather")) {
        auto& w = j["weather"];
        if (w.contains("snowflakeCount"))  c.snowflakeCount = w["snowflakeCount"];
        if (w.contains("fallSpeed"))       c.weatherFallSpeed = w["fallSpeed"];
    }
    if (j.contains("dda")) {
        auto& d = j["dda"];
        if (d.contains("maxSteps"))  c.ddaMaxSteps = d["ddaMaxSteps"];
        if (d.contains("stepSize"))  c.ddaStepSize = d["ddaStepSize"];
    }
}

} // namespace

bool GameConfig::loadFromDirectory(const std::string& dir) {
    loadPlayer(dir, player);
    loadEnemies(dir, enemyTemplates);
    loadWeapons(dir, playerWeapon, enemyTemplates);
    loadPickups(dir, pickups);
    loadGame(dir, game);

    std::cout << "GameConfig: loaded from " << dir << " ("
              << enemyTemplates.size() << " enemy templates)" << std::endl;
    return true;
}
