--// =========================================================
--// Global State
--// =========================================================

_G.esp_mod = _G.esp_mod or {
    running = false,

    cfg = {
        MAX_DIST     = 500,
        FADE_START   = 150,

        MIN_SIZE     = 10,
        MAX_SIZE     = 180,
        SCALE_FACTOR = 32,

        BOX_COLOR     = Color3.fromRGB(255, 60, 60),
        PASSIVE_COLOR = Color3.fromRGB(80, 255, 120),
        BONE_COLOR    = Color3.fromRGB(255, 140, 0),
        NAME_COLOR    = Color3.fromRGB(255, 255, 255),
        DIST_COLOR    = Color3.fromRGB(180, 180, 180),
        TOOL_COLOR    = Color3.fromRGB(255, 220, 80),
        HP_HIGH       = Color3.fromRGB(0, 220, 80),
        HP_LOW        = Color3.fromRGB(220, 40, 40),
    },

    toggles = {
        ESP          = true,
        BOX          = true,
        BONES        = true,
        NAME         = true,
        DIST         = true,
        HEALTH       = true,
        TOOL         = true,
        SHOW_PASSIVE = true,
        SHOW_FLAGS   = true,
    }
}

-- keep your override
_G.esp_mod.toggles.BOX = false

local m = _G.esp_mod
if m.running then
    return
end
m.running = true

--// =========================================================
--// Services
--// =========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

--// =========================================================
--// Helpers
--// =========================================================

local function CFG(key)
    return m.cfg[key]
end

local function T(key)
    return m.toggles[key]
end

local function draw(drawType, props)
    local obj = Drawing.new(drawType)
    props = props or {}

    obj.Visible = props.Visible or false
    for k, v in pairs(props) do
        if k ~= "Visible" then
            obj[k] = v
        end
    end

    return obj
end

local function newLine(thickness)
    return draw("Line", {
        Thickness = thickness or 1.25,
        Visible = false
    })
end

local function newText(size)
    return draw("Text", {
        Size = size or 12,
        Font = Drawing.Fonts.Plex,
        Center = true,
        Outline = true,
        Visible = false
    })
end

local function newCorners()
    local corners = {}
    for i = 1, 8 do
        corners[i] = newLine(1.5)
    end
    return corners
end

local function hideCorners(corners)
    for _, l in ipairs(corners) do
        l.Visible = false
    end
end

local function drawCorners(corners, bx, by, bw, bh, alpha, color)
    local seg = math.clamp(math.min(bw, bh) * 0.22, 3, 10)

    local points = {
        { Vector2.new(bx, by + seg), Vector2.new(bx, by), Vector2.new(bx + seg, by) },
        { Vector2.new(bx + bw - seg, by), Vector2.new(bx + bw, by), Vector2.new(bx + bw, by + seg) },
        { Vector2.new(bx, by + bh - seg), Vector2.new(bx, by + bh), Vector2.new(bx + seg, by + bh) },
        { Vector2.new(bx + bw - seg, by + bh), Vector2.new(bx + bw, by + bh), Vector2.new(bx + bw, by + bh - seg) },
    }

    local idx = 1
    for _, trio in ipairs(points) do
        for j = 1, 2 do
            local l = corners[idx]
            l.From = trio[j]
            l.To = trio[j + 1]
            l.Color = color
            l.Transparency = alpha
            l.Visible = true
            idx += 1
        end
    end
end

local function lerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function getAlpha(dist)
    local maxDist = CFG("MAX_DIST")
    local fadeStart = CFG("FADE_START")

    if dist > maxDist then
        return 0
    end

    if dist <= fadeStart then
        return 1
    end

    return 1 - ((dist - fadeStart) / (maxDist - fadeStart))
end

local function getTorso(char)
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

local function isPassive(char)
    local torso = char and getTorso(char)
    return torso and torso.Material == Enum.Material.ForceField or false
end

local BONE_PAIRS = {
    { "Head", "UpperTorso" },
    { "Head", "Torso" },
    { "UpperTorso", "LowerTorso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
    { "UpperTorso", "LeftUpperArm" },
    { "UpperTorso", "RightUpperArm" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LowerTorso", "RightUpperLeg" },
}

--// =========================================================
--// ESP Storage
--// =========================================================

local esp = {}
local connections = {}

local function hideESP(d)
    d.box.Visible = false
    d.nameLabel.Visible = false
    d.distLabel.Visible = false
    d.toolLabel.Visible = false
    d.hpLabel.Visible = false

    hideCorners(d.corners)

    for _, l in ipairs(d.bones) do
        l.Visible = false
    end
end

local function createESP(plr)
    if plr == localPlayer or esp[plr] then
        return
    end

    local boneLines = {}
    for i = 1, #BONE_PAIRS do
        boneLines[i] = newLine(1.15)
    end

    local box = draw("Square", {
        Thickness = 1.25,
        Filled = false,
        Visible = false
    })

    esp[plr] = {
        box = box,
        corners = newCorners(),
        nameLabel = newText(13),
        distLabel = newText(10),
        toolLabel = newText(10),
        hpLabel = newText(10),
        bones = boneLines
    }
end

local function removeESP(plr)
    local d = esp[plr]
    if not d then
        return
    end

    d.box:Remove()
    d.nameLabel:Remove()
    d.distLabel:Remove()
    d.toolLabel:Remove()
    d.hpLabel:Remove()

    for _, l in ipairs(d.corners) do
        l:Remove()
    end

    for _, l in ipairs(d.bones) do
        l:Remove()
    end

    esp[plr] = nil
end

--// =========================================================
--// Init Players
--// =========================================================

for _, plr in ipairs(Players:GetPlayers()) do
    createESP(plr)
end

connections[#connections + 1] = Players.PlayerAdded:Connect(createESP)
connections[#connections + 1] = Players.PlayerRemoving:Connect(removeESP)

--// =========================================================
--// Render Loop (optimized style)
--// =========================================================

connections[#connections + 1] = RunService.RenderStepped:Connect(function()
    if not T("ESP") then
        for _, d in pairs(esp) do
            hideESP(d)
        end
        return
    end

    for plr, d in pairs(esp) do
        local char = plr.Character
        if not char then
            hideESP(d)
            continue
        end

        local torso = getTorso(char)
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not torso then
            hideESP(d)
            continue
        end

        -- model-based sizing (same idea as your sample)
        local pivot = char:GetPivot()
        local ext = char:GetExtentsSize()

        local headOffset = 0
        if head then
            headOffset = ((head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)) - pivot.Position).Magnitude
        else
            headOffset = ext.Y * 0.5
        end

        local center3D = pivot.Position + Vector3.new(0, headOffset * 0.5, 0)
        local vec, onScreen = camera:WorldToViewportPoint(center3D)
        local dist = (camera.CFrame.Position - center3D).Magnitude
        local alpha = getAlpha(dist)

        if not onScreen or vec.Z <= 0 or alpha <= 0 then
            hideESP(d)
            continue
        end

        local passive = isPassive(char)
        local mainColor = passive and CFG("PASSIVE_COLOR") or CFG("BOX_COLOR")

        local scale = CFG("SCALE_FACTOR") / math.max(dist, 1)
        local bw = math.clamp(ext.X * 60 * scale, CFG("MIN_SIZE"), CFG("MAX_SIZE"))
        local bh = math.clamp(ext.Y * 60 * scale, CFG("MIN_SIZE") * 2, CFG("MAX_SIZE") * 2)

        local bx = vec.X - (bw * 0.5)
        local by = vec.Y - (bh * 0.5)

        -- BOX + CORNERS
        if T("BOX") then
            d.box.Size = Vector2.new(bw, bh)
            d.box.Position = Vector2.new(bx, by)
            d.box.Color = mainColor
            d.box.Transparency = alpha * 0.25
            d.box.Visible = true

            drawCorners(d.corners, bx, by, bw, bh, alpha, mainColor)
        else
            d.box.Visible = false
            hideCorners(d.corners)
        end

        -- NAME
        if T("NAME") and head then
            local hp, ho = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
            local nameText = plr.DisplayName

            if T("SHOW_PASSIVE") and passive then
                nameText = "[PASSIVE] " .. nameText
            end

            d.nameLabel.Text = nameText
            d.nameLabel.Position = Vector2.new(hp.X, hp.Y - 14)
            d.nameLabel.Color = mainColor
            d.nameLabel.Transparency = ho and alpha or 1
            d.nameLabel.Visible = ho
        else
            d.nameLabel.Visible = false
        end

        -- DIST
        if T("DIST") then
            d.distLabel.Text = string.format("%.0f studs", dist)
            d.distLabel.Position = Vector2.new(vec.X, by + bh + 3)
            d.distLabel.Color = CFG("DIST_COLOR")
            d.distLabel.Transparency = alpha
            d.distLabel.Visible = true
        else
            d.distLabel.Visible = false
        end

        -- TOOL
        if T("TOOL") then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                d.toolLabel.Text = "[" .. tool.Name .. "]"
                d.toolLabel.Position = Vector2.new(vec.X, by + bh + 15)
                d.toolLabel.Color = CFG("TOOL_COLOR")
                d.toolLabel.Transparency = alpha
                d.toolLabel.Visible = true
            else
                d.toolLabel.Visible = false
            end
        else
            d.toolLabel.Visible = false
        end

        -- HEALTH
        if T("HEALTH") and hum and hum.MaxHealth > 0 then
            local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            d.hpLabel.Text = string.format("%d%%", math.floor(frac * 100))
            d.hpLabel.Position = Vector2.new(bx + bw + 8, vec.Y - 5)
            d.hpLabel.Color = lerpColor(CFG("HP_LOW"), CFG("HP_HIGH"), frac)
            d.hpLabel.Transparency = alpha
            d.hpLabel.Visible = true
        else
            d.hpLabel.Visible = false
        end

        -- BONES
        if T("BONES") then
            for i, pair in ipairs(BONE_PAIRS) do
                local a = char:FindFirstChild(pair[1])
                local b = char:FindFirstChild(pair[2])
                local line = d.bones[i]

                if a and b then
                    local pa, oa = camera:WorldToViewportPoint(a.Position)
                    local pb, ob = camera:WorldToViewportPoint(b.Position)

                    if oa and ob then
                        line.From = Vector2.new(pa.X, pa.Y)
                        line.To = Vector2.new(pb.X, pb.Y)
                        line.Color = CFG("BONE_COLOR")
                        line.Transparency = alpha
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, l in ipairs(d.bones) do
                l.Visible = false
            end
        end
    end
end)

--// =========================================================
--// Stop / Cleanup
--// =========================================================

_G.esp_mod.stop = function()
    if not _G.esp_mod.running then
        return
    end

    _G.esp_mod.running = false

    for _, conn in ipairs(connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    table.clear(connections)

    for plr in pairs(esp) do
        removeESP(plr)
    end

    if cleardrawcache then
        pcall(cleardrawcache)
    end
end
