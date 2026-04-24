_G.tp_mod = _G.tp_mod or {
    running = false,

    cfg = {
        TP_SPEED = 16,
        UP_DOWN = true,
        RADIUS = 10,
        CIRCLE_COLOR = Color3.fromRGB(255,255,255),
        SEGMENTS = 40
    },

    state = {
        frozen = false,
        origin = nil
    }
}

_G.tp_mod.cfg.TP_SPEED = 16
_G.tp_mod.cfg.RADIUS = 10

local m = _G.tp_mod
if m.running then return end
m.running = true

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- circle lines
local circle = {}
for i=1,m.cfg.SEGMENTS do
    local l = Drawing.new("Line")
    l.Thickness = 1.5
    l.Visible = false
    circle[i] = l
end

local function setFrozen(state)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    m.state.frozen = state

    if state then
        m.state.origin = root.Position
        root.Anchored = true
        if hum then hum.WalkSpeed = 0 end
    else
        root.Anchored = false
        if m.state.origin then
            root.CFrame = CFrame.new(m.state.origin)
        end
        m.state.origin = nil
        if hum then hum.WalkSpeed = 16 end
    end
end

player.CharacterAdded:Connect(function()
    m.state.frozen = false
    m.state.origin = nil
end)

UIS.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Tab then
        setFrozen(not m.state.frozen)
    end
end)

RunService.RenderStepped:Connect(function()
    local origin = m.state.origin
    if not origin or not m.state.frozen then
        for _,l in ipairs(circle) do l.Visible = false end
        return
    end

    local seg = m.cfg.SEGMENTS
    local r = m.cfg.RADIUS

    for i=1,seg do
        local a1 = (i/seg)*math.pi*2
        local a2 = ((i+1)/seg)*math.pi*2

        local p1 = origin + Vector3.new(math.cos(a1)*r,0,math.sin(a1)*r)
        local p2 = origin + Vector3.new(math.cos(a2)*r,0,math.sin(a2)*r)

        local v1,on1 = camera:WorldToViewportPoint(p1)
        local v2,on2 = camera:WorldToViewportPoint(p2)

        local l = circle[i]
        if on1 and on2 then
            l.From = Vector2.new(v1.X,v1.Y)
            l.To = Vector2.new(v2.X,v2.Y)
            l.Color = m.cfg.CIRCLE_COLOR
            l.Visible = true
        else
            l.Visible = false
        end
    end
end)

RunService.Stepped:Connect(function(_,dt)
    if not m.state.frozen then return end

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local camCF = camera.CFrame
    local flatLook = Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z)
    local flatRight = Vector3.new(camCF.RightVector.X,0,camCF.RightVector.Z)

    if flatLook.Magnitude>0 then flatLook=flatLook.Unit end
    if flatRight.Magnitude>0 then flatRight=flatRight.Unit end

    local move = Vector3.zero

    if UIS:IsKeyDown(Enum.KeyCode.W) then move += flatLook end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move -= flatLook end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move -= flatRight end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move += flatRight end

    if m.cfg.UP_DOWN then
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
    end

    if move.Magnitude > 0 then
        local offset = move.Unit * m.cfg.TP_SPEED * dt
        local newPos = root.Position + offset

        local origin = m.state.origin
        if origin then
            local delta = newPos - origin
            if delta.Magnitude > m.cfg.RADIUS then
                newPos = origin + delta.Unit * m.cfg.RADIUS
            end
        end

        root.CFrame = CFrame.new(newPos) * (root.CFrame - root.Position)
    end
end)

_G.tp_mod.stop = function()
    _G.tp_mod.running = false
    setFrozen(false)
    for _,l in ipairs(circle) do l:Remove() end
end