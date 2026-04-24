_G.esp_mod = _G.esp_mod or {
    running = false,

    cfg = {
        MAX_DIST   = 500,
        FADE_START = 150,
        MIN_SIZE   = 10,
        MAX_SIZE   = 80,

        BOX_COLOR      = Color3.fromRGB(255, 60, 60),
        PASSIVE_COLOR  = Color3.fromRGB(80, 255, 120),
        BONE_COLOR     = Color3.fromRGB(255, 140, 0),
        NAME_COLOR     = Color3.fromRGB(255, 255, 255),
        DIST_COLOR     = Color3.fromRGB(180, 180, 180),
        TOOL_COLOR     = Color3.fromRGB(255, 220, 80),
        HP_HIGH        = Color3.fromRGB(0, 220, 80),
        HP_LOW         = Color3.fromRGB(220, 40, 40),
    },

    toggles = {
        ESP        = true,
        BOX        = true,
        BONES      = true,
        NAME       = true,
        DIST       = true,
        HEALTH     = true,
        TOOL       = true,
        SHOW_PASSIVE = true,
        SHOW_FLAGS = true
    }
}

_G.esp_mod.toggles.BOX = false

local m = _G.esp_mod
if m.running then return end
m.running = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function CFG(k) return m.cfg[k] end
local function T(k) return m.toggles[k] end

local BONE_PAIRS = {
    {"Head","Torso"},
    {"Torso","Left Arm"},
    {"Torso","Right Arm"},
    {"Torso","Left Leg"},
    {"Torso","Right Leg"},
}

local function isPassive(char)
    local torso = char and char:FindFirstChild("Torso")
    return torso and torso.Material == Enum.Material.ForceField
end

local function getAlpha(dist)
    if dist > CFG("MAX_DIST") then return 0 end
    if dist < CFG("FADE_START") then return 1 end
    return 1 - (dist - CFG("FADE_START")) / (CFG("MAX_DIST") - CFG("FADE_START"))
end

local function lerpColor(a,b,t)
    return Color3.new(
        a.R + (b.R-a.R)*t,
        a.G + (b.G-a.G)*t,
        a.B + (b.B-a.B)*t
    )
end

local function newLine()
    local l = Drawing.new("Line")
    l.Thickness = 1.25
    l.Visible = false
    return l
end

local function newText(size)
    local t = Drawing.new("Text")
    t.Size = size
    t.Font = Drawing.Fonts.Plex
    t.Center = true
    t.Outline = true
    t.Visible = false
    return t
end

local function newCorners()
    local c = {}
    for i=1,8 do
        local l = Drawing.new("Line")
        l.Thickness = 1.5
        l.Visible = false
        c[i]=l
    end
    return c
end

local function drawCorners(c,bx,by,bw,bh,a,col)
    local s = math.clamp(math.min(bw,bh)*0.22,3,10)
    local pts = {
        {Vector2.new(bx,by+s),Vector2.new(bx,by),Vector2.new(bx+s,by)},
        {Vector2.new(bx+bw-s,by),Vector2.new(bx+bw,by),Vector2.new(bx+bw,by+s)},
        {Vector2.new(bx,by+bh-s),Vector2.new(bx,by+bh),Vector2.new(bx+s,by+bh)},
        {Vector2.new(bx+bw-s,by+bh),Vector2.new(bx+bw,by+bh),Vector2.new(bx+bw,by+bh-s)},
    }
    local i=1
    for _,trio in ipairs(pts) do
        for j=1,2 do
            local l=c[i]
            l.From=trio[j]
            l.To=trio[j+1]
            l.Color=col
            l.Transparency=a
            l.Visible=true
            i=i+1
        end
    end
end

local function hideCorners(c)
    for _,l in ipairs(c) do l.Visible=false end
end

local esp = {}

local function createESP(plr)
    if plr==player then return end

    local bones={}
    for i=1,#BONE_PAIRS do bones[i]=newLine() end

    local box = Drawing.new("Square")
    box.Thickness=1.25
    box.Filled=false
    box.Visible=false

    esp[plr]={
        box=box,
        corners=newCorners(),
        nameLabel=newText(13),
        distLabel=newText(10),
        toolLabel=newText(10),
        hpLabel=newText(10),
        bones=bones
    }
end

local function removeESP(plr)
    local d=esp[plr]
    if not d then return end
    d.box:Remove()
    d.nameLabel:Remove()
    d.distLabel:Remove()
    d.toolLabel:Remove()
    d.hpLabel:Remove()
    for _,l in ipairs(d.corners) do l:Remove() end
    for _,l in ipairs(d.bones) do l:Remove() end
    esp[plr]=nil
end

for _,plr in ipairs(Players:GetPlayers()) do createESP(plr) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

RunService.RenderStepped:Connect(function()
    for plr,d in pairs(esp) do
        local char = plr.Character
        local torso = char and char:FindFirstChild("Torso")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        local function hide()
            d.box.Visible=false
            d.nameLabel.Visible=false
            d.distLabel.Visible=false
            d.toolLabel.Visible=false
            d.hpLabel.Visible=false
            hideCorners(d.corners)
            for _,l in ipairs(d.bones) do l.Visible=false end
        end

        if not torso or not T("ESP") then hide() continue end

        local dist = (camera.CFrame.Position - torso.Position).Magnitude
        local alpha = getAlpha(dist)
        local pos,onScreen = camera:WorldToViewportPoint(torso.Position)

        if not onScreen or alpha <= 0 then hide() continue end

        local passive = isPassive(char)
        local color = passive and CFG("PASSIVE_COLOR") or CFG("BOX_COLOR")

        local size = math.clamp(3200/dist,CFG("MIN_SIZE"),CFG("MAX_SIZE"))
        local bx = pos.X - size/2
        local by = pos.Y - size

        if T("BOX") then
            d.box.Size = Vector2.new(size,size*2)
            d.box.Position = Vector2.new(bx,by)
            d.box.Color = color
            d.box.Transparency = alpha*0.25
            d.box.Visible = true
            drawCorners(d.corners,bx,by,size,size*2,alpha,color)
        else
            d.box.Visible=false
            hideCorners(d.corners)
        end

        if T("NAME") and head then
            local hp,ho = camera:WorldToViewportPoint(head.Position + Vector3.new(0,1.5,0))
            d.nameLabel.Text = plr.DisplayName
            if T("SHOW_PASSIVE") and passive then
                d.nameLabel.Text = "[PASSIVE] "..plr.DisplayName
            end
            d.nameLabel.Position = Vector2.new(hp.X,hp.Y-14)
            d.nameLabel.Color = color
            d.nameLabel.Transparency = ho and alpha or 1
            d.nameLabel.Visible = ho
        else d.nameLabel.Visible=false end

        if T("DIST") then
            d.distLabel.Text = string.format("%.0f studs",dist)
            d.distLabel.Position = Vector2.new(pos.X,by+size*2+3)
            d.distLabel.Color = color
            d.distLabel.Transparency = alpha
            d.distLabel.Visible = true
        else d.distLabel.Visible=false end

        if T("TOOL") then
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                d.toolLabel.Text = "["..tool.Name.."]"
                d.toolLabel.Position = Vector2.new(pos.X,by+size*2+15)
                d.toolLabel.Color = color
                d.toolLabel.Transparency = alpha
                d.toolLabel.Visible = true
            else d.toolLabel.Visible=false end
        else d.toolLabel.Visible=false end

        if T("HEALTH") and hum then
            local frac = math.clamp(hum.Health/hum.MaxHealth,0,1)
            d.hpLabel.Text = string.format("%d%%",math.floor(frac*100))
            d.hpLabel.Position = Vector2.new(bx+size+5,pos.Y-5)
            d.hpLabel.Color = lerpColor(CFG("HP_LOW"),CFG("HP_HIGH"),frac)
            d.hpLabel.Transparency = alpha
            d.hpLabel.Visible = true
        else d.hpLabel.Visible=false end

        if T("BONES") then
            for i,pair in ipairs(BONE_PAIRS) do
                local a=char:FindFirstChild(pair[1])
                local b=char:FindFirstChild(pair[2])
                local line=d.bones[i]
                if a and b then
                    local pa,oa=camera:WorldToViewportPoint(a.Position)
                    local pb,ob=camera:WorldToViewportPoint(b.Position)
                    if oa and ob then
                        line.From=Vector2.new(pa.X,pa.Y)
                        line.To=Vector2.new(pb.X,pb.Y)
                        line.Color=color
                        line.Transparency=alpha
                        line.Visible=true
                    else line.Visible=false end
                else line.Visible=false end
            end
        else
            for _,l in ipairs(d.bones) do l.Visible=false end
        end
    end
end)

_G.esp_mod.stop = function()
    _G.esp_mod.running = false
    for plr in pairs(esp) do removeESP(plr) end
end