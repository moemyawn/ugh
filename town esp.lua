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

local v2 = Vector2.new
local v3 = Vector3.new
local clamp = math.clamp
local floor = math.floor
local max = math.max
local next = next
local pairs = pairs
local os_clock = os.clock

local function CFG(key)
    return m.cfg[key]
end

local function T(key)
    return m.toggles[key]
end

-- drawing dirty-cache (avoid redundant property writes)
local drawState = setmetatable({}, { __mode = "k" })

local function setDraw(obj, k, v)
    local c = drawState[obj]
    if c[k] ~= v then
        obj[k] = v
        c[k] = v
    end
end

local function draw(drawType, props)
    local obj = Drawing.new(drawType)
    props = props or {}
    drawState[obj] = {}

    for k, v in pairs(props) do
        obj[k] = v
        drawState[obj][k] = v
    end

    if props.Visible == nil then
        obj.Visible = false
        drawState[obj].Visible = false
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
    for i = 1, 8 do
        setDraw(corners[i], "Visible", false)
    end
end

-- no temp tables, no per-call allocations except 8 Vector2s
local function drawCorners(corners, bx, by, bw, bh, alpha, color)
    local seg = clamp(math.min(bw, bh) * 0.22, 3, 10)
    local x2, y2 = bx + bw, by + bh
    local sx, sy = bx + seg, by + seg
    local ex, ey = x2 - seg, y2 - seg

    -- TL
    local l1 = corners[1]
    setDraw(l1, "From", v2(bx, sy)); setDraw(l1, "To", v2(bx, by))
    setDraw(l1, "Color", color); setDraw(l1, "Transparency", alpha); setDraw(l1, "Visible", true)

    local l2 = corners[2]
    setDraw(l2, "From", v2(bx, by)); setDraw(l2, "To", v2(sx, by))
    setDraw(l2, "Color", color); setDraw(l2, "Transparency", alpha); setDraw(l2, "Visible", true)

    -- TR
    local l3 = corners[3]
    setDraw(l3, "From", v2(ex, by)); setDraw(l3, "To", v2(x2, by))
    setDraw(l3, "Color", color); setDraw(l3, "Transparency", alpha); setDraw(l3, "Visible", true)

    local l4 = corners[4]
    setDraw(l4, "From", v2(x2, by)); setDraw(l4, "To", v2(x2, sy))
    setDraw(l4, "Color", color); setDraw(l4, "Transparency", alpha); setDraw(l4, "Visible", true)

    -- BL
    local l5 = corners[5]
    setDraw(l5, "From", v2(bx, ey)); setDraw(l5, "To", v2(bx, y2))
    setDraw(l5, "Color", color); setDraw(l5, "Transparency", alpha); setDraw(l5, "Visible", true)

    local l6 = corners[6]
    setDraw(l6, "From", v2(bx, y2)); setDraw(l6, "To", v2(sx, y2))
    setDraw(l6, "Color", color); setDraw(l6, "Transparency", alpha); setDraw(l6, "Visible", true)

    -- BR
    local l7 = corners[7]
    setDraw(l7, "From", v2(ex, y2)); setDraw(l7, "To", v2(x2, y2))
    setDraw(l7, "Color", color); setDraw(l7, "Transparency", alpha); setDraw(l7, "Visible", true)

    local l8 = corners[8]
    setDraw(l8, "From", v2(x2, y2)); setDraw(l8, "To", v2(x2, ey))
    setDraw(l8, "Color", color); setDraw(l8, "Transparency", alpha); setDraw(l8, "Visible", true)
end

local function lerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function getAlpha(dist, maxDist, fadeStart)
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

local BONE_NAME_SET = {}
for i = 1, #BONE_PAIRS do
    BONE_NAME_SET[BONE_PAIRS[i][1]] = true
    BONE_NAME_SET[BONE_PAIRS[i][2]] = true
end
BONE_NAME_SET.Head = true
BONE_NAME_SET.Torso = true
BONE_NAME_SET.UpperTorso = true
BONE_NAME_SET.LowerTorso = true
BONE_NAME_SET.HumanoidRootPart = true

--// =========================================================
--// ESP Storage
--// =========================================================

local esp = {}
local connections = {}

local function hideESP(d)
    setDraw(d.box, "Visible", false)
    setDraw(d.nameLabel, "Visible", false)
    setDraw(d.distLabel, "Visible", false)
    setDraw(d.toolLabel, "Visible", false)
    setDraw(d.hpLabel, "Visible", false)

    hideCorners(d.corners)

    for i = 1, #d.bones do
        setDraw(d.bones[i], "Visible", false)
    end
end

local function refreshPartCache(d, char)
    d._char = char
    d._parts = nil
    d._ext = nil
    d._torso = nil
    d._head = nil
    d._hum = nil
    d._toolName = nil
    d._toolVisible = false
    d._nextToolScan = 0
    d._nextPassiveScan = 0
    d._passive = false

    if not char then
        return
    end

    local parts = {}
    for name in pairs(BONE_NAME_SET) do
        parts[name] = char:FindFirstChild(name)
    end

    d._parts = parts
    d._torso = parts.HumanoidRootPart or parts.Torso
    d._head = parts.Head
    d._hum = char:FindFirstChildOfClass("Humanoid")
    d._ext = char:GetExtentsSize()
    d._nextPartRefresh = 0
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
        bones = boneLines,

        -- runtime caches
        _char = nil,
        _parts = nil,
        _ext = nil,
        _torso = nil,
        _head = nil,
        _hum = nil,
        _passive = false,
        _nextPassiveScan = 0,
        _toolName = nil,
        _toolVisible = false,
        _nextToolScan = 0,
        _nextPartRefresh = 0,
        _id = #connections + 1,
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

    drawState[d.box] = nil
    drawState[d.nameLabel] = nil
    drawState[d.distLabel] = nil
    drawState[d.toolLabel] = nil
    drawState[d.hpLabel] = nil

    for i = 1, #d.corners do
        drawState[d.corners[i]] = nil
        d.corners[i]:Remove()
    end

    for i = 1, #d.bones do
        drawState[d.bones[i]] = nil
        d.bones[i]:Remove()
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
--// Render Loop (heavily optimized)
--// =========================================================

local frameId = 0
local espHidden = false

connections[#connections + 1] = RunService.RenderStepped:Connect(function()
    frameId += 1
    local now = os_clock()

    local tESP = T("ESP")
    if not tESP then
        if not espHidden then
            for _, d in pairs(esp) do
                hideESP(d)
            end
            espHidden = true
        end
        return
    end
    espHidden = false

    -- pull toggles once per frame
    local tBOX = T("BOX")
    local tBONES = T("BONES")
    local tNAME = T("NAME")
    local tDIST = T("DIST")
    local tHEALTH = T("HEALTH")
    local tTOOL = T("TOOL")
    local tSHOW_PASSIVE = T("SHOW_PASSIVE")

    -- pull cfg once per frame
    local cMAX_DIST = CFG("MAX_DIST")
    local cFADE_START = CFG("FADE_START")
    local cMIN_SIZE = CFG("MIN_SIZE")
    local cMAX_SIZE = CFG("MAX_SIZE")
    local cSCALE_FACTOR = CFG("SCALE_FACTOR")
    local cBOX_COLOR = CFG("BOX_COLOR")
    local cPASSIVE_COLOR = CFG("PASSIVE_COLOR")
    local cBONE_COLOR = CFG("BONE_COLOR")
    local cDIST_COLOR = CFG("DIST_COLOR")
    local cTOOL_COLOR = CFG("TOOL_COLOR")
    local cHP_HIGH = CFG("HP_HIGH")
    local cHP_LOW = CFG("HP_LOW")

    local camPos = camera.CFrame.Position

    for plr, d in next, esp do
        local char = plr.Character
        if char ~= d._char then
            refreshPartCache(d, char)
        elseif char and now >= d._nextPartRefresh then
            -- cheap periodic refresh in case of rig swaps/late part loads
            refreshPartCache(d, char)
            d._nextPartRefresh = now + 1.0
        end

        if not char then
            hideESP(d)
            continue
        end

        local torso = d._torso
        local head = d._head
        local hum = d._hum
        local ext = d._ext

        if not torso or not ext then
            hideESP(d)
            continue
        end

        local torsoPos = torso.Position
        local center3D = head and ((torsoPos + head.Position) * 0.5) or torsoPos
        local vec, onScreen = camera:WorldToViewportPoint(center3D)
        local dist = (camPos - center3D).Magnitude
        local alpha = getAlpha(dist, cMAX_DIST, cFADE_START)

        if (not onScreen) or vec.Z <= 0 or alpha <= 0 then
            hideESP(d)
            continue
        end

        if now >= d._nextPassiveScan then
            d._passive = isPassive(char)
            d._nextPassiveScan = now + 0.15
        end

        local passive = d._passive
        local mainColor = passive and cPASSIVE_COLOR or cBOX_COLOR

        local scale = cSCALE_FACTOR / max(dist, 1)
        local bw = clamp(ext.X * 60 * scale, cMIN_SIZE, cMAX_SIZE)
        local bh = clamp(ext.Y * 60 * scale, cMIN_SIZE * 2, cMAX_SIZE * 2)

        local bx = vec.X - (bw * 0.5)
        local by = vec.Y - (bh * 0.5)

        -- BOX + CORNERS
        if tBOX then
            setDraw(d.box, "Size", v2(bw, bh))
            setDraw(d.box, "Position", v2(bx, by))
            setDraw(d.box, "Color", mainColor)
            setDraw(d.box, "Transparency", alpha * 0.25)
            setDraw(d.box, "Visible", true)

            drawCorners(d.corners, bx, by, bw, bh, alpha, mainColor)
        else
            setDraw(d.box, "Visible", false)
            hideCorners(d.corners)
        end

        -- NAME
        if tNAME and head then
            local hp, ho = camera:WorldToViewportPoint(head.Position + v3(0, 1.5, 0))
            if ho then
                local nameText = plr.DisplayName
                if tSHOW_PASSIVE and passive then
                    nameText = "[PASSIVE] " .. nameText
                end

                setDraw(d.nameLabel, "Text", nameText)
                setDraw(d.nameLabel, "Position", v2(hp.X, hp.Y - 14))
                setDraw(d.nameLabel, "Color", mainColor)
                setDraw(d.nameLabel, "Transparency", alpha)
                setDraw(d.nameLabel, "Visible", true)
            else
                setDraw(d.nameLabel, "Visible", false)
            end
        else
            setDraw(d.nameLabel, "Visible", false)
        end

        -- DIST
        if tDIST then
            setDraw(d.distLabel, "Text", tostring(floor(dist + 0.5)) .. " studs")
            setDraw(d.distLabel, "Position", v2(vec.X, by + bh + 3))
            setDraw(d.distLabel, "Color", cDIST_COLOR)
            setDraw(d.distLabel, "Transparency", alpha)
            setDraw(d.distLabel, "Visible", true)
        else
            setDraw(d.distLabel, "Visible", false)
        end

        -- TOOL (throttled scan)
        if tTOOL then
            if now >= d._nextToolScan then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    d._toolName = "[" .. tool.Name .. "]"
                    d._toolVisible = true
                else
                    d._toolName = nil
                    d._toolVisible = false
                end
                d._nextToolScan = now + 0.12
            end

            if d._toolVisible then
                setDraw(d.toolLabel, "Text", d._toolName)
                setDraw(d.toolLabel, "Position", v2(vec.X, by + bh + 15))
                setDraw(d.toolLabel, "Color", cTOOL_COLOR)
                setDraw(d.toolLabel, "Transparency", alpha)
                setDraw(d.toolLabel, "Visible", true)
            else
                setDraw(d.toolLabel, "Visible", false)
            end
        else
            setDraw(d.toolLabel, "Visible", false)
        end

        -- HEALTH
        if tHEALTH and hum and hum.MaxHealth > 0 then
            local frac = clamp(hum.Health / hum.MaxHealth, 0, 1)
            setDraw(d.hpLabel, "Text", tostring(floor(frac * 100)) .. "%")
            setDraw(d.hpLabel, "Position", v2(bx + bw + 8, vec.Y - 5))
            setDraw(d.hpLabel, "Color", lerpColor(cHP_LOW, cHP_HIGH, frac))
            setDraw(d.hpLabel, "Transparency", alpha)
            setDraw(d.hpLabel, "Visible", true)
        else
            setDraw(d.hpLabel, "Visible", false)
        end

        -- BONES (distance-based throttle)
        if tBONES then
            local doBoneUpdate = (dist < 160) or ((frameId + d._id) % 2 == 0)

            if doBoneUpdate then
                local parts = d._parts
                for i = 1, #BONE_PAIRS do
                    local pair = BONE_PAIRS[i]
                    local a = parts[pair[1]]
                    local b = parts[pair[2]]
                    local line = d.bones[i]

                    if a and b then
                        local pa, oa = camera:WorldToViewportPoint(a.Position)
                        local pb, ob = camera:WorldToViewportPoint(b.Position)

                        if oa and ob then
                            setDraw(line, "From", v2(pa.X, pa.Y))
                            setDraw(line, "To", v2(pb.X, pb.Y))
                            setDraw(line, "Color", cBONE_COLOR)
                            setDraw(line, "Transparency", alpha)
                            setDraw(line, "Visible", true)
                        else
                            setDraw(line, "Visible", false)
                        end
                    else
                        setDraw(line, "Visible", false)
                    end
                end
            end
        else
            for i = 1, #d.bones do
                setDraw(d.bones[i], "Visible", false)
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
