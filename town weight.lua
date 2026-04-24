_G.weight_mod = _G.weight_mod or {
    running = false,

    cfg = {
        value = 0,
        delay = 0.25
    },

    toggles = {
        enabled = true
    }
}

local m = _G.weight_mod

-- update on rerun
m.cfg.value = 0
m.cfg.delay = 0.25
m.toggles.enabled = true

if m.running then return end
m.running = true

task.spawn(function()
    while m.running do
        task.wait(m.cfg.delay)

        if not m.toggles.enabled then continue end

        local char = game.Players.LocalPlayer.Character
        if not char then continue end

        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then continue end

        local weight = tool:FindFirstChild("Weight")
        if weight then
            weight.Value = m.cfg.value
        end
    end
end)

_G.weight_mod.stop = function()
    _G.weight_mod.running = false
end