_G.gun_mod = _G.gun_mod or {
    running = false,

    cfg = {
        auto = true,
        GunRecoil = 0.225,
        GunRecoilX = 0.225,
        ReloadSpeed = 0.000001,
        ReloadSpeed2 = 0.000001,
        AimSpeed = 0.001,
        AimFov = 70,
        BulletSpeed = 9999,
        BulletSpeedMin = 9999,
        Scatter = 3,
        AimScatterMultiplyer = 3,
        waittime = 0.07
    },

    toggles = {
        auto = true,
        GunRecoil = true,
        GunRecoilX = true,
        ReloadSpeed = true,
        ReloadSpeed2 = true,
        AimSpeed = true,
        AimFov = true,
        BulletSpeed = true,
        BulletSpeedMin = true,
        Scatter = true,
        AimScatterMultiplyer = true,
        waittime = true
    }
}

_G.gun_mod.toggles.auto = false
_G.gun_mod.toggles.waittime = false
_G.gun_mod.toggles.Scatter = false
_G.gun_mod.toggles.AimScatterMultiplyer = false
_G.gun_mod.toggles.ReloadSpeed = true
_G.gun_mod.toggles.ReloadSpeed2 = true
_G.gun_mod.cfg.GunRecoil = 0.175
_G.gun_mod.cfg.GunRecoilX = 0.175
_G.gun_mod.cfg.ReloadSpeed = 1.2
_G.gun_mod.cfg.ReloadSpeed2 = 0.4

local m = _G.gun_mod

if m.running then return end
m.running = true

task.spawn(function()
    while m.running do
        task.wait(0.25)

        local char = game.Players.LocalPlayer.Character
        if not char then continue end

        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then continue end

        local mod = tool:FindFirstChild("Settings")
        if not mod then continue end

        local s = require(mod)
        if not s then continue end

        for k, v in pairs(m.cfg) do
            if m.toggles[k] then
                s[k] = v
            end
        end
    end
end)