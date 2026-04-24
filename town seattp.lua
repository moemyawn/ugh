_G.seat_mod = _G.seat_mod or {
    running = false,

    cfg = {
        MinDist   = 5,
        MaxDist   = 255,
        FadeStart = 30,
        MinSize   = 8,
        MaxSize   = 40,
        Thickness = 1.25,

        Color      = Color3.fromRGB(0, 200, 255),
        HoverColor = Color3.fromRGB(255, 220, 0),

        LabelSize  = 11
    },

    toggles = {
        enabled   = true,
        boxes     = true,
        text      = true,
        corners   = true,
        sit_click = true,
        hover     = true
    }
}

local m = _G.seat_mod
if m.running then return end
m.running = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local seats = {}
local drawings = {}

local function CFG(k) return m.cfg[k] end
local function T(k) return m.toggles[k] end

-- ui builders
local function newBox()
    local b = Drawing.new("Square")
    b.Thickness = CFG("Thickness")
    b.Filled = false
    b.Visible = false
    return b
end

local function newLabel()
    local t = Drawing.new("Text")
    t.Size = CFG("LabelSize")
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
        l.Thickness = CFG("Thickness") + 0.5
        l.Visible = false
        c[i]=l
    end
    return c
end

local function updateCorners(c,bx,by,bw,bh,a,col)
    local s = math.clamp(math.min(bw,bh)*0.25,2,7)
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

local function mouseIn(x,y,w,h)
    local mpos = UIS:GetMouseLocation()
    return mpos.X>=x and mpos.X<=x+w and mpos.Y>=y and mpos.Y<=y+h
end

-- seat tracking
local function addSeat(seat)
    if drawings[seat] then return end
    seats[#seats+1]=seat
    drawings[seat]={
        box=newBox(),
        label=newLabel(),
        corners=newCorners()
    }
end

local function removeSeat(seat)
    local d=drawings[seat]
    if not d then return end

    d.box:Remove()
    d.label:Remove()
    for _,l in ipairs(d.corners) do l:Remove() end

    drawings[seat]=nil
end

-- initial scan
for _,v in ipairs(workspace:GetDescendants()) do
    if v:IsA("Seat") or v:IsA("VehicleSeat") then
        addSeat(v)
    end
end

local connAdd = workspace.DescendantAdded:Connect(function(v)
    if v:IsA("Seat") or v:IsA("VehicleSeat") then
        addSeat(v)
    end
end)

local connRem = workspace.DescendantRemoving:Connect(function(v)
    if v:IsA("Seat") or v:IsA("VehicleSeat") then
        removeSeat(v)
    end
end)

-- render
local renderConn = RunService.RenderStepped:Connect(function()
    if not T("enabled") then return end

    for seat,d in pairs(drawings) do
        if not seat or not seat.Parent then
            removeSeat(seat)
            continue
        end

        local pos,onScreen = camera:WorldToViewportPoint(seat.Position)
        local dist = (camera.CFrame.Position - seat.Position).Magnitude

        if not onScreen or dist > CFG("MaxDist") then
            d.box.Visible=false
            d.label.Visible=false
            hideCorners(d.corners)
            continue
        end

        local alpha = 1
        if dist > CFG("FadeStart") then
            alpha = 1 - (dist-CFG("FadeStart"))/(CFG("MaxDist")-CFG("FadeStart"))
        end

        local size = math.clamp(1600/dist,CFG("MinSize"),CFG("MaxSize"))
        local bx,by = pos.X-size/2,pos.Y-size

        local hover = T("hover") and mouseIn(bx,by,size,size)
        local col = hover and CFG("HoverColor") or CFG("Color")

        if T("boxes") then
            d.box.Size=Vector2.new(size,size)
            d.box.Position=Vector2.new(bx,by)
            d.box.Color=col
            d.box.Transparency=alpha*0.35
            d.box.Visible=true
        else
            d.box.Visible=false
        end

        if T("corners") then
            updateCorners(d.corners,bx,by,size,size,alpha,col)
        else
            hideCorners(d.corners)
        end

        if T("text") then
            d.label.Text=string.format("%.0f studs",dist)
            d.label.Position=Vector2.new(pos.X,by+size+3)
            d.label.Color=col
            d.label.Transparency=alpha
            d.label.Visible=true
        else
            d.label.Visible=false
        end
    end
end)

-- click sit
local inputConn = UIS.InputBegan:Connect(function(input,gpe)
    if gpe or not T("sit_click") then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    for seat,d in pairs(drawings) do
        if seat and seat.Parent and d.box.Visible then
            local b=d.box
            if mouseIn(b.Position.X,b.Position.Y,b.Size.X,b.Size.Y) then
                local char=player.Character
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if hum then seat:Sit(hum) end
                return
            end
        end
    end
end)

_G.seat_mod.stop = function()
    m.running=false
    renderConn:Disconnect()
    inputConn:Disconnect()
    connAdd:Disconnect()
    connRem:Disconnect()

    for seat in pairs(drawings) do
        removeSeat(seat)
    end
end