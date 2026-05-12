--// =========================================================
--// Global State
--// =========================================================

_G.seat_mod = _G.seat_mod or {
    running = false,

    cfg = {
        MinDist     = 5,
        MaxDist     = 255,
        FadeStart   = 30,

        MinSize     = 8,
        MaxSize     = 70,
        ScaleFactor = 34, -- distance scaling factor

        Thickness   = 1.25,
        LabelSize   = 11,

        Color       = Color3.fromRGB(0, 200, 255),
        HoverColor  = Color3.fromRGB(255, 220, 0),
    },

    toggles = {
        enabled   = true,
        boxes     = true,
        text      = true,
        corners   = true,
        sit_click = true,
        hover     = true,
    }
}

local m = _G.seat_mod
if m.running then
    return
end
m.running = true

--// =========================================================
--// Services
--// =========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--// =========================================================
--// Helpers
--// =========================================================

local function CFG(k)
    return m.cfg[k]
end

local function T(k)
    return m.toggles[k]
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

local function newBox()
    return draw("Square", {
        Thickness = CFG("Thickness"),
        Filled = false,
        Visible = false
    })
end

local function newLabel()
    return draw("Text", {
        Size = CFG("LabelSize"),
        Font = Drawing.Fonts.Plex,
        Center = true,
        Outline = true,
        Visible = false
    })
end

local function newCorners()
    local c = {}
    for i = 1, 8 do
        c[i] = draw("Line", {
            Thickness = CFG("Thickness") + 0.5,
            Visible = false
        })
    end
    return c
end

local function hideCorners(c)
    for _, l in ipairs(c) do
        l.Visible = false
    end
end

local function updateCorners(c, bx, by, bw, bh, alpha, col)
    local s = math.clamp(math.min(bw, bh) * 0.25, 2, 9)

    local pts = {
        { Vector2.new(bx, by + s), Vector2.new(bx, by), Vector2.new(bx + s, by) },
        { Vector2.new(bx + bw - s, by), Vector2.new(bx + bw, by), Vector2.new(bx + bw, by + s) },
        { Vector2.new(bx, by + bh - s), Vector2.new(bx, by + bh), Vector2.new(bx + s, by + bh) },
        { Vector2.new(bx + bw - s, by + bh), Vector2.new(bx + bw, by + bh), Vector2.new(bx + bw, by + bh - s) },
    }

    local idx = 1
    for _, trio in ipairs(pts) do
        for j = 1, 2 do
            local l = c[idx]
            l.From = trio[j]
            l.To = trio[j + 1]
            l.Color = col
            l.Transparency = alpha
            l.Visible = true
            idx += 1
        end
    end
end

local function mouseIn(x, y, w, h)
    local mpos = UIS:GetMouseLocation()
    return mpos.X >= x and mpos.X <= x + w and mpos.Y >= y and mpos.Y <= y + h
end

local function getAlpha(dist)
    local minD = CFG("MinDist")
    local maxD = CFG("MaxDist")
    local fade = CFG("FadeStart")

    if dist < minD or dist > maxD then
        return 0
    end

    if dist <= fade then
        return 1
    end

    return 1 - ((dist - fade) / (maxD - fade))
end

local function hideSeatESP(d)
    d.box.Visible = false
    d.label.Visible = false
    hideCorners(d.corners)
end

--// =========================================================
--// Tracking
--// =========================================================

local drawings = {}
local connections = {}
local renderCache = {} -- stores current frame rect for click checks

local function addSeat(seat)
    if drawings[seat] then
        return
    end

    drawings[seat] = {
        box = newBox(),
        label = newLabel(),
        corners = newCorners(),
    }
end

local function removeSeat(seat)
    local d = drawings[seat]
    if not d then
        return
    end

    d.box:Remove()
    d.label:Remove()
    for _, l in ipairs(d.corners) do
        l:Remove()
    end

    drawings[seat] = nil
    renderCache[seat] = nil
end

-- initial scan
for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("Seat") or v:IsA("VehicleSeat") then
        addSeat(v)
    end
end

connections[#connections + 1] = workspace.DescendantAdded:Connect(function(v)
    if v:IsA("Seat") or v:IsA("VehicleSeat") then
        addSeat(v)
    end
end)

connections[#connections + 1] = workspace.DescendantRemoving:Connect(function(v)
    if v:IsA("Seat") or v:IsA("VehicleSeat") then
        removeSeat(v)
    end
end)

--// =========================================================
--// Render
--// =========================================================

connections[#connections + 1] = RunService.RenderStepped:Connect(function()
    if not T("enabled") then
        for _, d in pairs(drawings) do
            hideSeatESP(d)
        end
        table.clear(renderCache)
        return
    end

    for seat, d in pairs(drawings) do
        if not seat or not seat.Parent then
            removeSeat(seat)
            continue
        end

        local worldPos = seat.Position
        local vec, onScreen = camera:WorldToViewportPoint(worldPos)
        local dist = (camera.CFrame.Position - worldPos).Magnitude
        local alpha = getAlpha(dist)

        if not onScreen or vec.Z <= 0 or alpha <= 0 then
            hideSeatESP(d)
            renderCache[seat] = nil
            continue
        end

        -- size from seat extents + distance scaling (sample-style approach)
        local ext = seat.Size
        local scale = CFG("ScaleFactor") / math.max(dist, 1)
        local size = math.clamp(((ext.X + ext.Z) * 0.5) * 60 * scale, CFG("MinSize"), CFG("MaxSize"))

        local bx = vec.X - (size * 0.5)
        local by = vec.Y - (size * 0.5)

        local hovered = T("hover") and mouseIn(bx, by, size, size)
        local col = hovered and CFG("HoverColor") or CFG("Color")

        renderCache[seat] = {
            x = bx,
            y = by,
            w = size,
            h = size,
            visible = true
        }

        if T("boxes") then
            d.box.Size = Vector2.new(size, size)
            d.box.Position = Vector2.new(bx, by)
            d.box.Color = col
            d.box.Transparency = alpha * 0.35
            d.box.Visible = true
        else
            d.box.Visible = false
        end

        if T("corners") then
            updateCorners(d.corners, bx, by, size, size, alpha, col)
        else
            hideCorners(d.corners)
        end

        if T("text") then
            d.label.Text = string.format("%.0f studs", dist)
            d.label.Position = Vector2.new(vec.X, by + size + 3)
            d.label.Color = col
            d.label.Transparency = alpha
            d.label.Visible = true
        else
            d.label.Visible = false
        end
    end
end)

--// =========================================================
--// Click-to-Sit
--// =========================================================

connections[#connections + 1] = UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not T("sit_click") then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    local mpos = UIS:GetMouseLocation()

    for seat, rect in pairs(renderCache) do
        if seat and seat.Parent and rect and rect.visible then
            local inside =
                mpos.X >= rect.x and mpos.X <= rect.x + rect.w and
                mpos.Y >= rect.y and mpos.Y <= rect.y + rect.h

            if inside then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    seat:Sit(hum)
                end
                return
            end
        end
    end
end)

--// =========================================================
--// Stop / Cleanup
--// =========================================================

_G.seat_mod.stop = function()
    if not m.running then
        return
    end

    m.running = false

    for _, conn in ipairs(connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    table.clear(connections)

    for seat in pairs(drawings) do
        removeSeat(seat)
    end

    table.clear(renderCache)

    if cleardrawcache then
        pcall(cleardrawcache)
    end
end
