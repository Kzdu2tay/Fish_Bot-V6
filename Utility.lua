--[[
    UTILITY v6
    V = esconder/mostrar
    Drag pelo header
    Ban-safe: tudo client-side, sem prints, sem FireServer
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local RS         = game:GetService("ReplicatedStorage")
local VIM        = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local noclipOn   = false
local noclipConn = nil
local ncKey      = Enum.KeyCode.F

local speedOn    = false
local speedVal   = 45
local spKey      = Enum.KeyCode.G

local jumpOn     = false
local jumpVal    = 80
local reJumpOn   = false
local reJumpConn = nil
local hjKey      = Enum.KeyCode.H

local shakeOn    = false
local shakeConn  = nil
local shakeKey   = Enum.KeyCode.J
local shakeDelay = 0.06

local listening  = nil
local currentTab = "main"

-- ═══════════════════════════════════════
-- ILHAS
-- ═══════════════════════════════════════
local ISLANDS = {
    { name = "Moosewood",             pos = Vector3.new(400,   135,  250)  },
    { name = "Roslit Bay",            pos = Vector3.new(-1600, 130,  500)  },
    { name = "Mushgrove Swamp",       pos = Vector3.new(2420,  135, -750)  },
    { name = "Snowcap Island",        pos = Vector3.new(2625,  135,  2370) },
    { name = "Statue of Sovereignty", pos = Vector3.new(35,    135, -1010) },
    { name = "Sunstone Island",       pos = Vector3.new(-870,  135, -1100) },
    { name = "Terrapin Island",       pos = Vector3.new(-95,   130,  1875) },
    { name = "Harvesters Spike",      pos = Vector3.new(-1260, 135,  1550) },
    { name = "The Arch",              pos = Vector3.new(1100,  130, -1250) },
    { name = "Birch Cay",             pos = Vector3.new(1650,  130, -2350) },
    { name = "Haddock Rock",          pos = Vector3.new(-500,  125,  -505) },
    { name = "Earmark Island",        pos = Vector3.new(1200,  130,   530) },
    { name = "Desolate Deep",         pos = Vector3.new(-800,  130, -3100) },
    { name = "Forsaken Shore",        pos = Vector3.new(-2750, 130,  1450) },
    { name = "Ancient Isle",          pos = Vector3.new(6000,  200,   300) },
    { name = "Grand Reef",            pos = Vector3.new(-3555, 150,   510) },
    { name = "N. Expedition Portal",  pos = Vector3.new(-1750, 130,  3750) },
}

local NPC_RANGE = 80

-- ═══════════════════════════════════════
-- CHAR HELPERS
-- ═══════════════════════════════════════
local function chr()  return LP.Character end
local function hum()  local c = chr(); return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp()  local c = chr(); return c and c:FindFirstChild("HumanoidRootPart") end
local function tool() local c = chr(); return c and c:FindFirstChildOfClass("Tool") end

-- ═══════════════════════════════════════
-- NOCLIP
-- ═══════════════════════════════════════
local function setNoclip(v)
    noclipOn = v
    if v then
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        noclipConn = RunService.PreSimulation:Connect(function()
            local c = chr(); if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        local c = chr()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
            end
        end
    end
end

-- ═══════════════════════════════════════
-- SPEED / JUMP
-- ═══════════════════════════════════════
local function applySpeed() local h = hum(); if h then h.WalkSpeed = speedOn and speedVal or 16 end end
local function applyJump()  local h = hum(); if h then h.JumpPower  = jumpOn  and jumpVal  or 50 end end

local function startReJump()
    if reJumpConn then reJumpConn:Disconnect(); reJumpConn = nil end
    reJumpConn = RunService.Heartbeat:Connect(function()
        if not reJumpOn or not jumpOn then reJumpConn:Disconnect(); reJumpConn = nil; return end
        local h = hum()
        if h and h.FloorMaterial ~= Enum.Material.Air then
            h.JumpPower = jumpVal; h:ChangeState(Enum.HumanoidStateType.Jumping); task.wait(0.15)
        end
    end)
end
local function stopReJump() if reJumpConn then reJumpConn:Disconnect(); reJumpConn = nil end end

-- ═══════════════════════════════════════
-- SHAKE
-- ═══════════════════════════════════════
local function pressEnter()
    pcall(VIM.SendKeyEvent, VIM, true,  Enum.KeyCode.Return, false, game)
    task.wait(0.02)
    pcall(VIM.SendKeyEvent, VIM, false, Enum.KeyCode.Return, false, game)
end
local function startShake()
    if shakeConn then pcall(task.cancel, shakeConn); shakeConn = nil end
    shakeConn = task.spawn(function() while shakeOn do pressEnter(); task.wait(shakeDelay) end end)
end
local function stopShake()
    shakeOn = false
    if shakeConn then pcall(task.cancel, shakeConn); shakeConn = nil end
end

-- ═══════════════════════════════════════
-- SELL
-- ═══════════════════════════════════════
local function sellFromHand()
    local t = tool(); if not t then return false, "Sem item na mão" end
    local WS = game:GetService("Workspace")
    for _, m in ipairs(WS:GetDescendants()) do
        local nm = m.Name:lower()
        if nm:find("appraiser") or nm:find("apprais") or nm:find("merchant") then
            local rf = m:FindFirstChildWhichIsA("RemoteFunction", true)
            if rf then local ok,res=pcall(function() return rf:InvokeServer(t) end); if ok then return true,"OK ("..tostring(res)..")" end end
            local re = m:FindFirstChildWhichIsA("RemoteEvent", true)
            if re then pcall(function() re:FireServer(t) end); return true,"OK" end
        end
    end
    local rsEv = RS:FindFirstChild("events") or RS:FindFirstChild("Events")
    if rsEv then
        for _, n in ipairs({"sell","Sell","appraise","Appraise","sellfish","SellFish","sellhand","SellHand","appraiseFish","SellItem"}) do
            local e = rsEv:FindFirstChild(n)
            if e then
                if e:IsA("RemoteEvent") then pcall(function() e:FireServer(t) end); return true,n
                elseif e:IsA("RemoteFunction") then local ok,r2=pcall(function() return e:InvokeServer(t) end); if ok then return true,n end end
            end
        end
        for _, child in ipairs(rsEv:GetDescendants()) do
            local cn = child.Name:lower()
            if (cn:find("sell") or cn:find("appraise")) and child:IsA("RemoteEvent") then
                pcall(function() child:FireServer(t) end); return true,child.Name
            end
        end
    end
    for _, obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local on2 = obj.Name:lower()
            if on2:find("sell") or on2:find("appraise") or on2:find("vend") then
                local sz = obj.AbsoluteSize
                if sz.X > 2 and sz.Y > 2 then pcall(function() obj.MouseButton1Click:Fire() end); return true,"GUI."..obj.Name end
            end
        end
    end
    return false,"Nenhum método encontrado"
end

-- ═══════════════════════════════════════
-- TP ILHA (client-side)
-- ═══════════════════════════════════════
local function tpToIsland(pos)
    local root = hrp(); if not root then return false,"Sem personagem" end
    root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    return true,"OK"
end

-- ═══════════════════════════════════════
-- TP NPC (só se próximo)
-- ═══════════════════════════════════════
local function getNearbyNPCs()
    local root = hrp(); if not root then return {} end
    local found = {}
    local WS = game:GetService("Workspace")
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local h = obj:FindFirstChildOfClass("Humanoid")
            local part = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if h and part then
                local dist = (root.Position - part.Position).Magnitude
                if dist <= NPC_RANGE then
                    table.insert(found, { name=obj.Name, part=part, dist=math.floor(dist) })
                end
            end
        end
    end
    table.sort(found, function(a,b) return a.dist < b.dist end)
    return found
end

local function tpToNPC(part)
    local root = hrp(); if not root then return end
    local offset = part.CFrame * CFrame.new(0, 0, -3.5)
    root.CFrame = CFrame.new(offset.Position + Vector3.new(0, 3, 0))
end

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if noclipOn then setNoclip(true) end
    if speedOn  then applySpeed()    end
    if jumpOn   then applyJump()     end
    if reJumpOn and jumpOn then startReJump() end
end)

-- ═══════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════
pcall(function()
    for _, n in ipairs({"UtilityGui","NoclipGui"}) do
        local o = PG:FindFirstChild(n); if o then o:Destroy() end
    end
end)

local gui = Instance.new("ScreenGui", PG)
gui.Name = "UtilityGui"; gui.ResetOnSpawn = false; gui.DisplayOrder = 999

local C = {
    bg      = Color3.fromRGB(8,  10,  18),
    panel   = Color3.fromRGB(13, 16,  28),
    card    = Color3.fromRGB(18, 22,  38),
    cardHov = Color3.fromRGB(24, 30,  52),
    accent  = Color3.fromRGB(82, 148, 255),
    accentD = Color3.fromRGB(48,  90, 190),
    green   = Color3.fromRGB(52, 211, 120),
    red     = Color3.fromRGB(235, 70,  80),
    yellow  = Color3.fromRGB(240, 190,  55),
    dim     = Color3.fromRGB(70,  82, 112),
    txt     = Color3.fromRGB(210, 218, 240),
    txtSub  = Color3.fromRGB(128, 140, 175),
    border  = Color3.fromRGB(26,  33,  58),
}

local function tw(o,p,d,style)
    return TweenSvc:Create(o, TweenInfo.new(d or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p)
end
local function twBack(o,p)
    return TweenSvc:Create(o, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), p)
end

-- Frame raiz
local frame = Instance.new("Frame", gui)
frame.Size             = UDim2.new(0, 212, 0, 0)
frame.Position         = UDim2.new(0, 18, 0.5, -160)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel  = 0
frame.AutomaticSize    = Enum.AutomaticSize.Y
frame.ClipsDescendants = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local frameBorder = Instance.new("UIStroke", frame)
frameBorder.Color = C.border; frameBorder.Thickness = 1.5

local rootLy = Instance.new("UIListLayout", frame)
rootLy.SortOrder = Enum.SortOrder.LayoutOrder; rootLy.Padding = UDim.new(0,0)

local function mkDiv(parent, order)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1,0,0,1); d.BackgroundColor3 = C.border
    d.BorderSizePixel = 0; d.LayoutOrder = order
end

local function pad(p,l,r,t,b)
    local u = Instance.new("UIPadding", p)
    u.PaddingLeft=UDim.new(0,l or 10); u.PaddingRight=UDim.new(0,r or 10)
    u.PaddingTop=UDim.new(0,t or 6);  u.PaddingBottom=UDim.new(0,b or 6)
end

-- ── HEADER ──────────────────────────────
local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1,0,0,36); header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0; header.LayoutOrder = 0

local hGrad = Instance.new("UIGradient", header)
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16,22,52)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8,10,18)),
})
hGrad.Rotation = 90

local statusDot = Instance.new("Frame", header)
statusDot.Size = UDim2.new(0,7,0,7); statusDot.Position = UDim2.new(0,11,0.5,-3)
statusDot.BackgroundColor3 = C.dim; statusDot.BorderSizePixel = 0
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1,0)

local htitle = Instance.new("TextLabel", header)
htitle.Size = UDim2.new(1,-65,1,0); htitle.Position = UDim2.new(0,24,0,0)
htitle.BackgroundTransparency = 1; htitle.Text = "⚙  UTILITY  v6"
htitle.TextColor3 = C.txt; htitle.Font = Enum.Font.GothamBlack; htitle.TextSize = 11
htitle.TextXAlignment = Enum.TextXAlignment.Left

local vHint = Instance.new("TextLabel", header)
vHint.Size = UDim2.new(0,20,0,14); vHint.Position = UDim2.new(1,-26,0.5,-7)
vHint.BackgroundColor3 = Color3.fromRGB(20,26,50); vHint.BorderSizePixel = 0
vHint.Text = "V"; vHint.TextColor3 = C.dim; vHint.Font = Enum.Font.GothamBold; vHint.TextSize = 8
vHint.TextXAlignment = Enum.TextXAlignment.Center
Instance.new("UICorner", vHint).CornerRadius = UDim.new(0,4)

-- ── TABS ────────────────────────────────
local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1,0,0,30); tabBar.BackgroundColor3 = C.panel
tabBar.BorderSizePixel = 0; tabBar.LayoutOrder = 1
pad(tabBar,6,6,5,5)
local tabLy = Instance.new("UIListLayout", tabBar)
tabLy.FillDirection = Enum.FillDirection.Horizontal
tabLy.SortOrder = Enum.SortOrder.LayoutOrder; tabLy.Padding = UDim.new(0,4)

local tabBtns = {}

local function mkTab(name, icon, order)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(0.5,-2,1,0); btn.BackgroundColor3 = C.card
    btn.BorderSizePixel = 0; btn.Text = icon.."  "..name
    btn.TextColor3 = C.dim; btn.Font = Enum.Font.GothamBold; btn.TextSize = 9
    btn.AutoButtonColor = false; btn.LayoutOrder = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    tabBtns[name] = btn; return btn
end

local tabMainBtn = mkTab("Cheats",   "🎮", 1)
local tabTPBtn   = mkTab("Teleport", "🗺",  2)

mkDiv(frame, 2)

local tabPages = {}

local function mkPage(order)
    local pg = Instance.new("Frame", frame)
    pg.Size = UDim2.new(1,0,0,0); pg.AutomaticSize = Enum.AutomaticSize.Y
    pg.BackgroundTransparency = 1; pg.BorderSizePixel = 0
    pg.LayoutOrder = order; pg.Visible = false
    local ly = Instance.new("UIListLayout", pg)
    ly.SortOrder = Enum.SortOrder.LayoutOrder; ly.Padding = UDim.new(0,0)
    return pg
end

local pageMain = mkPage(3)
local pageTP   = mkPage(4)
tabPages["Cheats"]    = pageMain
tabPages["Teleport"]  = pageTP

local function switchTab(name)
    currentTab = name
    for n,pg in pairs(tabPages) do pg.Visible = (n==name) end
    for n,btn in pairs(tabBtns) do
        local on = (n==name)
        tw(btn,{BackgroundColor3=on and C.accent or C.card, TextColor3=on and C.bg or C.dim}):Play()
    end
end

tabMainBtn.MouseButton1Click:Connect(function() switchTab("Cheats") end)
tabTPBtn.MouseButton1Click:Connect(function()   switchTab("Teleport") end)

-- ══════════════════════════════════════════
-- PAGE MAIN: CHEATS
-- ══════════════════════════════════════════
local BLOCKED_KEYS = {
    [Enum.KeyCode.Return]=true,[Enum.KeyCode.KeypadEnter]=true,
    [Enum.KeyCode.Backspace]=true,[Enum.KeyCode.Delete]=true,
    [Enum.KeyCode.Escape]=true,[Enum.KeyCode.Tab]=true,
    [Enum.KeyCode.CapsLock]=true,[Enum.KeyCode.LeftShift]=true,
    [Enum.KeyCode.RightShift]=true,[Enum.KeyCode.LeftControl]=true,
    [Enum.KeyCode.RightControl]=true,[Enum.KeyCode.LeftAlt]=true,
    [Enum.KeyCode.RightAlt]=true,[Enum.KeyCode.LeftSuper]=true,
    [Enum.KeyCode.RightSuper]=true,[Enum.KeyCode.V]=true,
}

local function addPadSec(p,t,b)
    local u = Instance.new("UIPadding",p)
    u.PaddingLeft=UDim.new(0,10);u.PaddingRight=UDim.new(0,10)
    u.PaddingTop=UDim.new(0,t or 7);u.PaddingBottom=UDim.new(0,b or 7)
end

local function mkSection(parent, cfg)
    local sec = Instance.new("Frame", parent)
    sec.Size = UDim2.new(1,0,0,0); sec.AutomaticSize = Enum.AutomaticSize.Y
    sec.BackgroundColor3 = C.card; sec.BorderSizePixel = 0; sec.LayoutOrder = cfg.order
    addPadSec(sec)
    local ly = Instance.new("UIListLayout", sec)
    ly.SortOrder = Enum.SortOrder.LayoutOrder; ly.Padding = UDim.new(0,5)

    local row1 = Instance.new("Frame", sec)
    row1.Size = UDim2.new(1,0,0,20); row1.BackgroundTransparency=1; row1.LayoutOrder=1

    local lbl = Instance.new("TextLabel", row1)
    lbl.Size=UDim2.new(1,-52,1,0); lbl.BackgroundTransparency=1
    lbl.Text=cfg.icon.."  "..cfg.label; lbl.TextColor3=C.txtSub
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local tr = Instance.new("Frame", row1)
    tr.Size=UDim2.new(0,36,0,18); tr.Position=UDim2.new(1,-36,0.5,-9)
    tr.BackgroundColor3=Color3.fromRGB(22,28,50); tr.BorderSizePixel=0
    Instance.new("UICorner",tr).CornerRadius=UDim.new(0,9)
    Instance.new("UIStroke",tr).Color=C.border

    local kn = Instance.new("Frame", tr)
    kn.Size=UDim2.new(0,14,0,14); kn.Position=UDim2.new(0,2,0.5,-7)
    kn.BackgroundColor3=Color3.fromRGB(195,205,235); kn.BorderSizePixel=0
    Instance.new("UICorner",kn).CornerRadius=UDim.new(0,7)

    local togHit = Instance.new("TextButton", tr)
    togHit.Size=UDim2.new(1,0,1,0); togHit.BackgroundTransparency=1
    togHit.Text=""; togHit.AutoButtonColor=false; togHit.ZIndex=5

    local row2 = Instance.new("Frame", sec)
    row2.Size=UDim2.new(1,0,0,20); row2.BackgroundTransparency=1; row2.LayoutOrder=2

    local tLbl = Instance.new("TextLabel", row2)
    tLbl.Size=UDim2.new(0,38,1,0); tLbl.BackgroundTransparency=1
    tLbl.Text="Tecla:"; tLbl.TextColor3=C.dim; tLbl.Font=Enum.Font.Gotham; tLbl.TextSize=8
    tLbl.TextXAlignment=Enum.TextXAlignment.Left

    local bindB = Instance.new("TextButton", row2)
    bindB.Size=UDim2.new(0,64,0,18); bindB.Position=UDim2.new(0,40,0.5,-9)
    bindB.BackgroundColor3=Color3.fromRGB(18,22,44); bindB.BorderSizePixel=0
    bindB.Text=cfg.keyName; bindB.TextColor3=C.accent
    bindB.Font=Enum.Font.GothamBold; bindB.TextSize=9; bindB.AutoButtonColor=false
    Instance.new("UICorner",bindB).CornerRadius=UDim.new(0,5)
    Instance.new("UIStroke",bindB).Color=C.accentD
    bindB.MouseEnter:Connect(function() if listening~=cfg.id then tw(bindB,{BackgroundColor3=Color3.fromRGB(25,30,58)}):Play() end end)
    bindB.MouseLeave:Connect(function() if listening~=cfg.id then tw(bindB,{BackgroundColor3=Color3.fromRGB(18,22,44)}):Play() end end)

    if cfg.slider then
        local s=cfg.slider
        local rowS1=Instance.new("Frame",sec); rowS1.Size=UDim2.new(1,0,0,13)
        rowS1.BackgroundTransparency=1; rowS1.LayoutOrder=3
        local valLbl=Instance.new("TextLabel",rowS1); valLbl.Size=UDim2.new(1,0,1,0)
        valLbl.BackgroundTransparency=1; valLbl.Text=s.label..": "..s.def
        valLbl.TextColor3=C.accent; valLbl.Font=Enum.Font.GothamBold; valLbl.TextSize=8
        valLbl.TextXAlignment=Enum.TextXAlignment.Left

        local rowS2=Instance.new("Frame",sec); rowS2.Size=UDim2.new(1,0,0,14)
        rowS2.BackgroundTransparency=1; rowS2.LayoutOrder=4
        local sbg=Instance.new("Frame",rowS2); sbg.Size=UDim2.new(1,0,0,4)
        sbg.Position=UDim2.new(0,0,0.5,-2); sbg.BackgroundColor3=Color3.fromRGB(20,25,45)
        sbg.BorderSizePixel=0; Instance.new("UICorner",sbg).CornerRadius=UDim.new(0,2)
        local pct0=(s.def-s.min)/(s.max-s.min)
        local fill=Instance.new("Frame",sbg); fill.Size=UDim2.new(pct0,0,1,0)
        fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0
        Instance.new("UICorner",fill).CornerRadius=UDim.new(0,2)
        local sk=Instance.new("Frame",sbg); sk.Size=UDim2.new(0,11,0,11)
        sk.AnchorPoint=Vector2.new(0.5,0.5); sk.Position=UDim2.new(pct0,0,0.5,0)
        sk.BackgroundColor3=Color3.fromRGB(255,255,255); sk.BorderSizePixel=0; sk.ZIndex=3
        Instance.new("UICorner",sk).CornerRadius=UDim.new(0,6)
        local sHit=Instance.new("TextButton",sbg); sHit.Size=UDim2.new(1,0,0,20)
        sHit.Position=UDim2.new(0,0,0.5,-10); sHit.BackgroundTransparency=1
        sHit.Text=""; sHit.AutoButtonColor=false; sHit.ZIndex=4
        local dragging=false
        sHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
        sHit.InputEnded:Connect(function(i)  if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
        UIS.InputChanged:Connect(function(i)
            if not dragging or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
            local pct=math.clamp((i.Position.X-sbg.AbsolutePosition.X)/sbg.AbsoluteSize.X,0,1)
            local val=math.floor(s.min+pct*(s.max-s.min)+0.5)
            fill.Size=UDim2.new(pct,0,1,0); sk.Position=UDim2.new(pct,0,0.5,0)
            valLbl.Text=s.label..": "..val; if s.onChange then s.onChange(val) end
        end)
    end

    local rjTr,rjKn,rjTogHit
    if cfg.rejump then
        local rowRJ=Instance.new("Frame",sec); rowRJ.Size=UDim2.new(1,0,0,18)
        rowRJ.BackgroundTransparency=1; rowRJ.LayoutOrder=5
        local rjL=Instance.new("TextLabel",rowRJ); rjL.Size=UDim2.new(1,-52,1,0)
        rjL.BackgroundTransparency=1; rjL.Text="↩  Re-jump"; rjL.TextColor3=C.txtSub
        rjL.Font=Enum.Font.GothamBold; rjL.TextSize=9; rjL.TextXAlignment=Enum.TextXAlignment.Left
        rjTr=Instance.new("Frame",rowRJ); rjTr.Size=UDim2.new(0,36,0,18)
        rjTr.Position=UDim2.new(1,-36,0.5,-9); rjTr.BackgroundColor3=Color3.fromRGB(22,28,50)
        rjTr.BorderSizePixel=0; Instance.new("UICorner",rjTr).CornerRadius=UDim.new(0,9)
        Instance.new("UIStroke",rjTr).Color=C.border
        rjKn=Instance.new("Frame",rjTr); rjKn.Size=UDim2.new(0,14,0,14)
        rjKn.Position=UDim2.new(0,2,0.5,-7); rjKn.BackgroundColor3=Color3.fromRGB(195,205,235)
        rjKn.BorderSizePixel=0; Instance.new("UICorner",rjKn).CornerRadius=UDim.new(0,7)
        rjTogHit=Instance.new("TextButton",rjTr); rjTogHit.Size=UDim2.new(1,0,1,0)
        rjTogHit.BackgroundTransparency=1; rjTogHit.Text=""; rjTogHit.AutoButtonColor=false; rjTogHit.ZIndex=5
    end

    local function setTogVis(on)
        tw(tr,{BackgroundColor3=on and C.accent or Color3.fromRGB(22,28,50)}):Play()
        twBack(kn,{Position=on and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
    end
    local function setRjVis(on)
        if rjTr and rjKn then
            tw(rjTr,{BackgroundColor3=on and C.accent or Color3.fromRGB(22,28,50)}):Play()
            twBack(rjKn,{Position=on and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
        end
    end
    return {togHit=togHit,bindBtn=bindB,rjTogHit=rjTogHit,setTogVis=setTogVis,setRjVis=setRjVis}
end

mkDiv(pageMain,1)
local ncSec=mkSection(pageMain,{id="nc",order=2,icon="👻",label="Noclip",    keyName=ncKey.Name})
mkDiv(pageMain,3)
local spSec=mkSection(pageMain,{id="sp",order=4,icon="💨",label="Speed",     keyName=spKey.Name,
    slider={min=16,max=300,def=speedVal,label="Speed",onChange=function(v) speedVal=v; if speedOn then local h=hum();if h then h.WalkSpeed=v end end end}})
mkDiv(pageMain,5)
local hjSec=mkSection(pageMain,{id="hj",order=6,icon="🦘",label="High Jump", keyName=hjKey.Name,
    slider={min=50,max=500,def=jumpVal,label="Força",onChange=function(v) jumpVal=v; if jumpOn then local h=hum();if h then h.JumpPower=v end end end},rejump=true})
mkDiv(pageMain,7)
local shSec=mkSection(pageMain,{id="sh",order=8,icon="🔄",label="Shake Spam",keyName=shakeKey.Name})
mkDiv(pageMain,9)

-- Sell
local sellSec=Instance.new("Frame",pageMain); sellSec.Size=UDim2.new(1,0,0,0)
sellSec.AutomaticSize=Enum.AutomaticSize.Y; sellSec.BackgroundColor3=C.card
sellSec.BorderSizePixel=0; sellSec.LayoutOrder=10; addPadSec(sellSec,7,9)
local sellLy=Instance.new("UIListLayout",sellSec); sellLy.SortOrder=Enum.SortOrder.LayoutOrder; sellLy.Padding=UDim.new(0,5)
local sTitleRow=Instance.new("Frame",sellSec); sTitleRow.Size=UDim2.new(1,0,0,16)
sTitleRow.BackgroundTransparency=1; sTitleRow.LayoutOrder=1
local sTL=Instance.new("TextLabel",sTitleRow); sTL.Size=UDim2.new(1,0,1,0)
sTL.BackgroundTransparency=1; sTL.Text="💰  Sell from Hand"; sTL.TextColor3=C.txtSub
sTL.Font=Enum.Font.GothamBold; sTL.TextSize=10; sTL.TextXAlignment=Enum.TextXAlignment.Left
local sellStatus=Instance.new("TextLabel",sellSec); sellStatus.Size=UDim2.new(1,0,0,10)
sellStatus.BackgroundTransparency=1; sellStatus.Text="Aguardando..."; sellStatus.TextColor3=C.dim
sellStatus.Font=Enum.Font.Gotham; sellStatus.TextSize=8; sellStatus.TextXAlignment=Enum.TextXAlignment.Left; sellStatus.LayoutOrder=2
local sellBtn=Instance.new("TextButton",sellSec); sellBtn.Size=UDim2.new(1,0,0,28); sellBtn.LayoutOrder=3
sellBtn.BackgroundColor3=Color3.fromRGB(16,58,36); sellBtn.BorderSizePixel=0
sellBtn.Text="💰  Vender Item da Mão"; sellBtn.TextColor3=C.green
sellBtn.Font=Enum.Font.GothamBold; sellBtn.TextSize=9; sellBtn.AutoButtonColor=false
Instance.new("UICorner",sellBtn).CornerRadius=UDim.new(0,7)
Instance.new("UIStroke",sellBtn).Color=Color3.fromRGB(22,82,50)
sellBtn.MouseEnter:Connect(function() tw(sellBtn,{BackgroundColor3=Color3.fromRGB(20,72,44)}):Play() end)
sellBtn.MouseLeave:Connect(function() tw(sellBtn,{BackgroundColor3=Color3.fromRGB(16,58,36)}):Play() end)

mkDiv(pageMain,11)
local footerMain=Instance.new("Frame",pageMain); footerMain.Size=UDim2.new(1,0,0,16)
footerMain.BackgroundTransparency=1; footerMain.LayoutOrder=12
local fL=Instance.new("TextLabel",footerMain); fL.Size=UDim2.new(1,-16,1,0); fL.Position=UDim2.new(0,10,0,0)
fL.BackgroundTransparency=1; fL.Text="V = ocultar  •  100% client-side"
fL.TextColor3=Color3.fromRGB(28,36,62); fL.Font=Enum.Font.Gotham; fL.TextSize=7
fL.TextXAlignment=Enum.TextXAlignment.Left

-- ══════════════════════════════════════════
-- PAGE TP
-- ══════════════════════════════════════════
local tpSubBar=Instance.new("Frame",pageTP); tpSubBar.Size=UDim2.new(1,0,0,28)
tpSubBar.BackgroundColor3=C.panel; tpSubBar.BorderSizePixel=0; tpSubBar.LayoutOrder=1
pad(tpSubBar,6,6,5,5)
local tpSubLy=Instance.new("UIListLayout",tpSubBar)
tpSubLy.FillDirection=Enum.FillDirection.Horizontal; tpSubLy.SortOrder=Enum.SortOrder.LayoutOrder; tpSubLy.Padding=UDim.new(0,4)

local subBtns={}
local function mkSubTab(name,icon,order)
    local btn=Instance.new("TextButton",tpSubBar); btn.Size=UDim2.new(0.5,-2,1,0)
    btn.BackgroundColor3=C.card; btn.BorderSizePixel=0
    btn.Text=icon.."  "..name; btn.TextColor3=C.dim
    btn.Font=Enum.Font.GothamBold; btn.TextSize=8; btn.AutoButtonColor=false; btn.LayoutOrder=order
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
    subBtns[name]=btn; return btn
end
local subIslandsBtn=mkSubTab("Ilhas","🏝",1)
local subNPCBtn=mkSubTab("NPCs próximos","🧑",2)

local tpContent=Instance.new("Frame",pageTP); tpContent.Size=UDim2.new(1,0,0,0)
tpContent.AutomaticSize=Enum.AutomaticSize.Y; tpContent.BackgroundTransparency=1; tpContent.LayoutOrder=2

-- Sub: Ilhas
local islandPage=Instance.new("ScrollingFrame",tpContent); islandPage.Size=UDim2.new(1,0,0,222)
islandPage.BackgroundTransparency=1; islandPage.BorderSizePixel=0
islandPage.ScrollBarThickness=3; islandPage.ScrollBarImageColor3=C.accent
islandPage.CanvasSize=UDim2.new(0,0,0,0); islandPage.AutomaticCanvasSize=Enum.AutomaticSize.Y
islandPage.Visible=true
local islandLy=Instance.new("UIListLayout",islandPage)
islandLy.SortOrder=Enum.SortOrder.LayoutOrder; islandLy.Padding=UDim.new(0,2)
pad(islandPage,8,8,6,6)

local tpStatus=Instance.new("TextLabel",islandPage); tpStatus.Size=UDim2.new(1,0,0,14)
tpStatus.BackgroundTransparency=1; tpStatus.Text=""; tpStatus.TextColor3=C.green
tpStatus.Font=Enum.Font.GothamBold; tpStatus.TextSize=8; tpStatus.TextXAlignment=Enum.TextXAlignment.Left; tpStatus.LayoutOrder=0

for i,island in ipairs(ISLANDS) do
    local btn=Instance.new("TextButton",islandPage); btn.Size=UDim2.new(1,0,0,27)
    btn.BackgroundColor3=C.card; btn.BorderSizePixel=0
    btn.Text="📍  "..island.name; btn.TextColor3=C.txtSub
    btn.Font=Enum.Font.GothamBold; btn.TextSize=9; btn.TextXAlignment=Enum.TextXAlignment.Left
    btn.AutoButtonColor=false; btn.LayoutOrder=i
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6); pad(btn,8,8,0,0)
    btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=C.cardHov,TextColor3=C.txt}):Play() end)
    btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.card,TextColor3=C.txtSub}):Play() end)
    btn.MouseButton1Click:Connect(function()
        tw(btn,{BackgroundColor3=C.accentD}):Play(); task.wait(0.12); tw(btn,{BackgroundColor3=C.card}):Play()
        local ok,msg=tpToIsland(island.pos)
        tpStatus.TextColor3=ok and C.green or C.red
        tpStatus.Text=(ok and "✅ " or "❌ ")..(ok and island.name or msg)
        task.delay(3,function() tpStatus.Text="" end)
    end)
end

-- Sub: NPCs
local npcPage=Instance.new("Frame",tpContent); npcPage.Size=UDim2.new(1,0,0,222)
npcPage.BackgroundTransparency=1; npcPage.BorderSizePixel=0; npcPage.Visible=false

local refreshBtn=Instance.new("TextButton",npcPage); refreshBtn.Size=UDim2.new(1,0,0,28)
refreshBtn.BackgroundColor3=Color3.fromRGB(16,28,60); refreshBtn.BorderSizePixel=0
refreshBtn.Text="🔍  Escanear NPCs próximos"; refreshBtn.TextColor3=C.accent
refreshBtn.Font=Enum.Font.GothamBold; refreshBtn.TextSize=9; refreshBtn.AutoButtonColor=false
Instance.new("UICorner",refreshBtn).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",refreshBtn).Color=C.accentD; pad(refreshBtn,8,8,0,0)
refreshBtn.MouseEnter:Connect(function() tw(refreshBtn,{BackgroundColor3=Color3.fromRGB(20,36,78)}):Play() end)
refreshBtn.MouseLeave:Connect(function() tw(refreshBtn,{BackgroundColor3=Color3.fromRGB(16,28,60)}):Play() end)

local npcScroll=Instance.new("ScrollingFrame",npcPage); npcScroll.Size=UDim2.new(1,0,0,190)
npcScroll.Position=UDim2.new(0,0,0,32); npcScroll.BackgroundTransparency=1; npcScroll.BorderSizePixel=0
npcScroll.ScrollBarThickness=3; npcScroll.ScrollBarImageColor3=C.accent
npcScroll.CanvasSize=UDim2.new(0,0,0,0); npcScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
local npcScrollLy=Instance.new("UIListLayout",npcScroll)
npcScrollLy.SortOrder=Enum.SortOrder.LayoutOrder; npcScrollLy.Padding=UDim.new(0,2)
pad(npcScroll,8,8,4,4)

local function rebuildNPCList()
    for _,ch in ipairs(npcScroll:GetChildren()) do
        if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    local npcs=getNearbyNPCs()
    if #npcs==0 then
        local lbl=Instance.new("TextLabel",npcScroll); lbl.Size=UDim2.new(1,0,0,26)
        lbl.BackgroundTransparency=1; lbl.Text="Nenhum NPC a "..NPC_RANGE.." studs"
        lbl.TextColor3=C.dim; lbl.Font=Enum.Font.Gotham; lbl.TextSize=9
        lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.LayoutOrder=1; return
    end
    for i,npc in ipairs(npcs) do
        local btn=Instance.new("TextButton",npcScroll); btn.Size=UDim2.new(1,0,0,27)
        btn.BackgroundColor3=C.card; btn.BorderSizePixel=0
        btn.Text="🧑  "..npc.name.."  ("..npc.dist.." st)"; btn.TextColor3=C.txtSub
        btn.Font=Enum.Font.GothamBold; btn.TextSize=8; btn.TextXAlignment=Enum.TextXAlignment.Left
        btn.AutoButtonColor=false; btn.LayoutOrder=i
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6); pad(btn,8,8,0,0)
        btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=C.cardHov,TextColor3=C.txt}):Play() end)
        btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.card,TextColor3=C.txtSub}):Play() end)
        local capturedPart=npc.part
        btn.MouseButton1Click:Connect(function()
            tw(btn,{BackgroundColor3=C.accentD}):Play(); task.wait(0.12); tw(btn,{BackgroundColor3=C.card}):Play()
            tpToNPC(capturedPart); task.delay(0.8,rebuildNPCList)
        end)
    end
end

refreshBtn.MouseButton1Click:Connect(function()
    refreshBtn.Text="⏳  Escaneando..."; task.wait(0.2)
    rebuildNPCList(); refreshBtn.Text="🔍  Escanear NPCs próximos"
end)

local currentSubTab="islands"
local function switchSubTab(name)
    currentSubTab=name; islandPage.Visible=(name=="islands"); npcPage.Visible=(name=="npcs")
    for n,btn in pairs(subBtns) do
        local on=(n==name)
        tw(btn,{BackgroundColor3=on and C.accent or C.card, TextColor3=on and C.bg or C.dim}):Play()
    end
end
subIslandsBtn.MouseButton1Click:Connect(function() switchSubTab("islands") end)
subNPCBtn.MouseButton1Click:Connect(function() switchSubTab("npcs"); rebuildNPCList() end)
switchSubTab("islands")

-- ══════════════════════════════════════════
-- VISIBILIDADE
-- ══════════════════════════════════════════
local guiVisible=true
local function setVisible(v)
    guiVisible=v
    for _,child in ipairs(frame:GetChildren()) do
        if child~=header and child:IsA("Frame") then child.Visible=v end
    end
    if v then frame.AutomaticSize=Enum.AutomaticSize.Y
    else frame.AutomaticSize=Enum.AutomaticSize.None; tw(frame,{Size=UDim2.new(0,212,0,36)},0.15):Play() end
    tw(vHint,{TextColor3=v and C.dim or C.accent},0.1):Play()
end

-- ══════════════════════════════════════════
-- TOGGLES LÓGICA
-- ══════════════════════════════════════════
local function updateDot()
    local anyOn=noclipOn or speedOn or jumpOn or shakeOn
    tw(statusDot,{BackgroundColor3=anyOn and C.green or C.dim}):Play()
end

ncSec.togHit.MouseButton1Click:Connect(function()
    noclipOn=not noclipOn; setNoclip(noclipOn); ncSec.setTogVis(noclipOn)
    tw(frameBorder,{Color=noclipOn and C.green or C.border}):Play(); updateDot()
end)
spSec.togHit.MouseButton1Click:Connect(function()
    speedOn=not speedOn; spSec.setTogVis(speedOn); applySpeed(); updateDot()
end)
hjSec.togHit.MouseButton1Click:Connect(function()
    jumpOn=not jumpOn; hjSec.setTogVis(jumpOn); applyJump()
    if not jumpOn then reJumpOn=false; hjSec.setRjVis(false); stopReJump() end; updateDot()
end)
if hjSec.rjTogHit then
    hjSec.rjTogHit.MouseButton1Click:Connect(function()
        if not jumpOn then return end
        reJumpOn=not reJumpOn; hjSec.setRjVis(reJumpOn)
        if reJumpOn then startReJump() else stopReJump() end
    end)
end
shSec.togHit.MouseButton1Click:Connect(function()
    shakeOn=not shakeOn; shSec.setTogVis(shakeOn)
    if shakeOn then startShake() else stopShake() end; updateDot()
end)
sellBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(10,44,26)}):Play(); task.wait(0.1)
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(16,58,36)}):Play()
        local ok,msg=sellFromHand()
        if ok then sellStatus.Text="✅ "..msg; tw(sellStatus,{TextColor3=C.green}):Play()
        else       sellStatus.Text="❌ "..msg; tw(sellStatus,{TextColor3=C.red}):Play() end
        task.wait(3); tw(sellStatus,{TextColor3=C.dim}):Play(); sellStatus.Text="Aguardando..."
    end)
end)

-- ══════════════════════════════════════════
-- REBIND
-- ══════════════════════════════════════════
local function setupBind(sec,id,getKey,setKey)
    sec.bindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening=id; sec.bindBtn.Text="..."
        tw(sec.bindBtn,{TextColor3=C.yellow}):Play()
        local conn; conn=UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
            if inp.KeyCode==Enum.KeyCode.Escape then
                sec.bindBtn.Text=getKey().Name; tw(sec.bindBtn,{TextColor3=C.accent}):Play()
                listening=nil; conn:Disconnect(); return
            end
            if BLOCKED_KEYS[inp.KeyCode] then
                sec.bindBtn.Text="inválida!"; tw(sec.bindBtn,{TextColor3=C.red}):Play()
                task.wait(0.8); sec.bindBtn.Text=getKey().Name
                tw(sec.bindBtn,{TextColor3=C.accent}):Play(); listening=nil; conn:Disconnect(); return
            end
            setKey(inp.KeyCode); sec.bindBtn.Text=inp.KeyCode.Name
            tw(sec.bindBtn,{TextColor3=C.accent}):Play(); listening=nil; conn:Disconnect()
        end)
    end)
end
setupBind(ncSec,"nc",function() return ncKey    end,function(k) ncKey=k    end)
setupBind(spSec,"sp",function() return spKey    end,function(k) spKey=k    end)
setupBind(hjSec,"hj",function() return hjKey    end,function(k) hjKey=k    end)
setupBind(shSec,"sh",function() return shakeKey end,function(k) shakeKey=k end)

-- ══════════════════════════════════════════
-- DRAG
-- ══════════════════════════════════════════
do
    local dr,ds,sp=false,nil,nil
    local dh=Instance.new("TextButton",frame)
    dh.Size=UDim2.new(1,-20,0,36); dh.Position=UDim2.new(0,0,0,0)
    dh.BackgroundTransparency=1; dh.Text=""; dh.AutoButtonColor=false; dh.ZIndex=20
    dh.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true;ds=i.Position;sp=frame.Position end
    end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════
-- HOTKEYS
-- ══════════════════════════════════════════
UIS.InputBegan:Connect(function(inp,gpe)
    if gpe or listening then return end
    local k=inp.KeyCode
    if     k==Enum.KeyCode.V  then setVisible(not guiVisible)
    elseif k==ncKey then noclipOn=not noclipOn;setNoclip(noclipOn);ncSec.setTogVis(noclipOn);tw(frameBorder,{Color=noclipOn and C.green or C.border}):Play();updateDot()
    elseif k==spKey then speedOn=not speedOn;spSec.setTogVis(speedOn);applySpeed();updateDot()
    elseif k==hjKey then jumpOn=not jumpOn;hjSec.setTogVis(jumpOn);applyJump();if not jumpOn then reJumpOn=false;hjSec.setRjVis(false);stopReJump() end;updateDot()
    elseif k==shakeKey then shakeOn=not shakeOn;shSec.setTogVis(shakeOn);if shakeOn then startShake() else stopShake() end;updateDot()
    end
end)

switchTab("Cheats")