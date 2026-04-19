--[[
    UTILITY v9 — Fisch
    V = hide/show (hold briefly, not spam)
    Drag by header
    100% client-side, no prints
]]

local Players  = game:GetService("Players")
local RunSvc   = game:GetService("RunService")
local UIS      = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local RS       = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local noclipOn   = false; local noclipConn = nil; local ncKey = Enum.KeyCode.F
local speedOn    = false; local speedVal   = 45;  local spKey = Enum.KeyCode.G
local jumpOn     = false; local jumpVal    = 80;  local hjKey = Enum.KeyCode.H
local reJumpOn   = false; local reJumpConn = nil
local shakeOn    = false; local shakeThread = nil; local shakeKey = Enum.KeyCode.J
local shakeActive = false
local sellKey    = Enum.KeyCode.K
local npcRange   = 150   -- ajustavel pelo slider
local listening  = nil
local currentTab = "Cheats"
local guiVisible = true
local vDebounce  = false  -- fix do bug V

-- ═══════════════════════════════════════
-- ISLANDS
-- ═══════════════════════════════════════
local ISLANDS = {
    { name="Moosewood",             pos=Vector3.new(400,135,250),    special=false },
    { name="Roslit Bay",            pos=Vector3.new(-1600,130,500),  special=false },
    { name="Forsaken Shore",        pos=Vector3.new(-2750,130,1450), special=false },
    { name="Mushgrove Swamp",       pos=Vector3.new(2420,135,-750),  special=false },
    { name="Snowcap Island",        pos=Vector3.new(2625,135,2370),  special=false },
    { name="Sunstone Island",       pos=Vector3.new(-870,135,-1100), special=false },
    { name="Statue of Sovereignty", pos=Vector3.new(35,135,-1010),   special=false },
    { name="Terrapin Island",       pos=Vector3.new(-95,130,1875),   special=false },
    { name="Harvesters Spike",      pos=Vector3.new(-1260,135,1550), special=false },
    { name="The Arch",              pos=Vector3.new(1100,130,-1250),  special=false },
    { name="Birch Cay",             pos=Vector3.new(1650,130,-2350), special=false },
    { name="Haddock Rock",          pos=Vector3.new(-500,125,-505),  special=false },
    { name="Earmark Island",        pos=Vector3.new(1200,130,530),   special=false },
    { name="Desolate Deep",         pos=Vector3.new(-800,130,-3100), special=false },
    { name="Ancient Isle",          pos=Vector3.new(6000,200,300),   special=false },
    { name="Grand Reef",            pos=Vector3.new(-3555,150,510),  special=false },
    { name="Roslit Volcano",        pos=Vector3.new(-1900,165,315),  special=true  },
    { name="N. Expedition Portal",  pos=Vector3.new(-1750,130,3750), special=true  },
    { name="Northern Summit",       pos=Vector3.new(19500,135,5300), special=true  },
    { name="Atlantis Central",      pos=Vector3.new(-4270,-600,1830),special=true  },
    { name="The Depths",            pos=Vector3.new(1060,-635,1315), special=true  },
    { name="Winter Village",        pos=Vector3.new(-75,365,9500),   special=true  },
}

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════
local function chr()  return LP.Character end
local function hum()  local c=chr(); return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp()  local c=chr(); return c and c:FindFirstChild("HumanoidRootPart") end
local function tool() local c=chr(); return c and c:FindFirstChildOfClass("Tool") end

-- ═══════════════════════════════════════
-- NOCLIP
-- ═══════════════════════════════════════
local function setNoclip(v)
    noclipOn = v
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    if v then
        noclipConn = RunSvc.PreSimulation:Connect(function()
            local c=chr(); if not c then return end
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end
        end)
    else
        local c=chr()
        if c then for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.CanCollide=true end
        end end
    end
end

local function applySpeed() local h=hum(); if h then h.WalkSpeed=speedOn and speedVal or 16 end end
local function applyJump()  local h=hum(); if h then h.JumpPower =jumpOn  and jumpVal  or 50 end end

local function startReJump()
    if reJumpConn then reJumpConn:Disconnect(); reJumpConn=nil end
    reJumpConn = RunSvc.Heartbeat:Connect(function()
        if not reJumpOn or not jumpOn then reJumpConn:Disconnect(); reJumpConn=nil; return end
        local h=hum()
        if h and h.FloorMaterial~=Enum.Material.Air then
            h.JumpPower=jumpVal; h:ChangeState(Enum.HumanoidStateType.Jumping); task.wait(0.15)
        end
    end)
end
local function stopReJump() if reJumpConn then reJumpConn:Disconnect(); reJumpConn=nil end end

-- ═══════════════════════════════════════
-- SHAKE v9 — zero lag
-- Metodo: PlayerGui.shakeui.safezone.button:FireClickEvent()
-- Nao usa VIM, nao usa loop tight, respira entre clicks
-- ═══════════════════════════════════════
local function getShakeButton()
    local sui = PG:FindFirstChild("shakeui")
    if not sui or not sui.Enabled then return nil end
    local sz = sui:FindFirstChild("safezone")
    if not sz then return nil end
    local btn = sz:FindFirstChild("button")
    if btn and btn:IsA("GuiButton") and btn.Visible then return btn end
    return nil
end

local function startShake()
    if shakeThread then task.cancel(shakeThread); shakeThread=nil end
    shakeThread = task.spawn(function()
        while shakeOn do
            local btn = getShakeButton()
            if btn then
                shakeActive = true
                -- Fire direto no botao — sem VIM, sem SendInput, zero overhead
                btn.MouseButton1Click:Fire()
                task.wait(0.035)
            else
                shakeActive = false
                task.wait(0.05)
            end
        end
        shakeActive = false
    end)
end

local function stopShake()
    shakeOn=false; shakeActive=false
    if shakeThread then task.cancel(shakeThread); shakeThread=nil end
end

-- ═══════════════════════════════════════
-- SELL
-- ═══════════════════════════════════════
local function sellFromHand()
    local t=tool(); if not t then return false,"No item in hand" end
    pcall(function() t:Activate() end)
    local rsEv = RS:FindFirstChild("events") or RS:FindFirstChild("Events")
    if rsEv then
        for _,n in ipairs({"sell","Sell","appraise","Appraise","sellfish","SellFish","SellItem","appraiseFish"}) do
            local e=rsEv:FindFirstChild(n)
            if e then
                if e:IsA("RemoteEvent") then pcall(function() e:FireServer(t) end); return true,n
                elseif e:IsA("RemoteFunction") then local ok=pcall(function() return e:InvokeServer(t) end); if ok then return true,n end end
            end
        end
    end
    for _,obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local n=obj.Name:lower()
            if n:find("sell") or n:find("appraise") then
                local sz=obj.AbsoluteSize
                if sz.X>2 and sz.Y>2 then pcall(function() obj.MouseButton1Click:Fire() end); return true,"GUI."..obj.Name end
            end
        end
    end
    return false,"Method not found"
end

-- ═══════════════════════════════════════
-- TP
-- ═══════════════════════════════════════
local function tpTo(pos)
    local r=hrp(); if not r then return false end
    r.CFrame=CFrame.new(pos+Vector3.new(0,5,0)); return true
end

-- ═══════════════════════════════════════
-- NEARBY NPCs
-- ═══════════════════════════════════════
local function getNearby()
    local r=hrp(); if not r then return {} end
    local found={}
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj~=LP.Character then
            local h2=obj:FindFirstChildOfClass("Humanoid")
            local part=obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if h2 and part then
                local d=(r.Position-part.Position).Magnitude
                if d<=npcRange then
                    table.insert(found,{name=obj.Name, part=part, dist=math.floor(d)})
                end
            end
        end
    end
    table.sort(found,function(a,b) return a.dist<b.dist end)
    return found
end

local function tpToNPC(part)
    local r=hrp(); if not r then return end
    r.CFrame=CFrame.new((part.CFrame*CFrame.new(0,0,-3.5)).Position+Vector3.new(0,3,0))
end

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if noclipOn then setNoclip(true) end
    if speedOn  then applySpeed()    end
    if jumpOn   then applyJump()     end
    if reJumpOn and jumpOn then startReJump() end
end)

-- ═══════════════════════════════════════
-- DESTROY OLD GUI
-- ═══════════════════════════════════════
pcall(function()
    for _,n in ipairs({"UtilityGui","NoclipGui"}) do
        local o=PG:FindFirstChild(n); if o then o:Destroy() end
    end
end)

local gui=Instance.new("ScreenGui",PG)
gui.Name="UtilityGui"; gui.ResetOnSpawn=false; gui.DisplayOrder=999

-- ═══════════════════════════════════════
-- COLORS
-- ═══════════════════════════════════════
local C={
    bg=Color3.fromRGB(8,10,18),      panel=Color3.fromRGB(13,16,28),
    card=Color3.fromRGB(18,22,38),   cardH=Color3.fromRGB(24,30,52),
    acc=Color3.fromRGB(82,148,255),  accD=Color3.fromRGB(48,90,190),
    grn=Color3.fromRGB(52,211,120),  red=Color3.fromRGB(235,70,80),
    yel=Color3.fromRGB(240,190,55),  pink=Color3.fromRGB(255,80,180),
    dim=Color3.fromRGB(70,82,112),   txt=Color3.fromRGB(210,218,240),
    sub=Color3.fromRGB(128,140,175), bdr=Color3.fromRGB(26,33,58),
}

local function tw(o,p,d) return TweenSvc:Create(o,TweenInfo.new(d or 0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p) end
local function twB(o,p)  return TweenSvc:Create(o,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),p) end

-- ═══════════════════════════════════════
-- ROOT FRAME
-- ═══════════════════════════════════════
local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,212,0,36)
frame.Position=UDim2.new(0,18,0.5,-160)
frame.BackgroundColor3=C.bg; frame.BorderSizePixel=0
frame.ClipsDescendants=true
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)
local fBdr=Instance.new("UIStroke",frame); fBdr.Color=C.bdr; fBdr.Thickness=1.5
local rootLy=Instance.new("UIListLayout",frame)
rootLy.SortOrder=Enum.SortOrder.LayoutOrder; rootLy.Padding=UDim.new(0,0)

local function mkDiv(p,order)
    local d=Instance.new("Frame",p); d.Size=UDim2.new(1,0,0,1)
    d.BackgroundColor3=C.bdr; d.BorderSizePixel=0; d.LayoutOrder=order
end
local function pad(p,l,r,t,b)
    local u=Instance.new("UIPadding",p)
    u.PaddingLeft=UDim.new(0,l or 10); u.PaddingRight=UDim.new(0,r or 10)
    u.PaddingTop=UDim.new(0,t or 6);   u.PaddingBottom=UDim.new(0,b or 6)
end

-- ═══════════════════════════════════════
-- HEADER
-- ═══════════════════════════════════════
local header=Instance.new("Frame",frame)
header.Size=UDim2.new(1,0,0,36); header.BackgroundColor3=C.panel
header.BorderSizePixel=0; header.LayoutOrder=0
local hGrad=Instance.new("UIGradient",header)
hGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(16,22,52)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(8,10,18))
}); hGrad.Rotation=90

local dot=Instance.new("Frame",header)
dot.Size=UDim2.new(0,7,0,7); dot.Position=UDim2.new(0,11,0.5,-3)
dot.BackgroundColor3=C.dim; dot.BorderSizePixel=0
Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

local htitle=Instance.new("TextLabel",header)
htitle.Size=UDim2.new(1,-60,1,0); htitle.Position=UDim2.new(0,24,0,0)
htitle.BackgroundTransparency=1; htitle.Text="⚙  UTILITY  v9"
htitle.TextColor3=C.txt; htitle.Font=Enum.Font.GothamBlack; htitle.TextSize=11
htitle.TextXAlignment=Enum.TextXAlignment.Left

local vHint=Instance.new("TextLabel",header)
vHint.Size=UDim2.new(0,20,0,14); vHint.Position=UDim2.new(1,-26,0.5,-7)
vHint.BackgroundColor3=Color3.fromRGB(20,26,50); vHint.BorderSizePixel=0
vHint.Text="V"; vHint.TextColor3=C.dim; vHint.Font=Enum.Font.GothamBold; vHint.TextSize=8
vHint.TextXAlignment=Enum.TextXAlignment.Center
Instance.new("UICorner",vHint).CornerRadius=UDim.new(0,4)

-- ═══════════════════════════════════════
-- TABS (3)
-- ═══════════════════════════════════════
local tabBar=Instance.new("Frame",frame)
tabBar.Size=UDim2.new(1,0,0,30); tabBar.BackgroundColor3=C.panel
tabBar.BorderSizePixel=0; tabBar.LayoutOrder=1
pad(tabBar,6,6,5,5)
local tabLy=Instance.new("UIListLayout",tabBar)
tabLy.FillDirection=Enum.FillDirection.Horizontal
tabLy.SortOrder=Enum.SortOrder.LayoutOrder; tabLy.Padding=UDim.new(0,3)

local tabBtns={}; local tabPages={}

local function mkTab(name,icon,order)
    local b=Instance.new("TextButton",tabBar)
    b.Size=UDim2.new(0.333,-2,1,0); b.BackgroundColor3=C.card
    b.BorderSizePixel=0; b.Text=icon.." "..name
    b.TextColor3=C.dim; b.Font=Enum.Font.GothamBold; b.TextSize=8
    b.AutoButtonColor=false; b.LayoutOrder=order
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    tabBtns[name]=b; return b
end
local function mkPage(order)
    local pg=Instance.new("Frame",frame)
    pg.Size=UDim2.new(1,0,0,0); pg.AutomaticSize=Enum.AutomaticSize.Y
    pg.BackgroundTransparency=1; pg.BorderSizePixel=0
    pg.LayoutOrder=order; pg.Visible=false
    local ly=Instance.new("UIListLayout",pg)
    ly.SortOrder=Enum.SortOrder.LayoutOrder; ly.Padding=UDim.new(0,0)
    return pg
end

mkTab("Cheats","🎮",1); mkTab("TP","🗺",2); mkTab("NPCs","🧑",3)
mkDiv(frame,2)
tabPages["Cheats"]=mkPage(3); tabPages["TP"]=mkPage(4); tabPages["NPCs"]=mkPage(5)

local function switchTab(name)
    currentTab=name
    for n,pg in pairs(tabPages) do pg.Visible=(n==name) end
    for n,b in pairs(tabBtns) do
        tw(b,{BackgroundColor3=(n==name)and C.acc or C.card,TextColor3=(n==name)and C.bg or C.dim}):Play()
    end
    -- recalc frame height
    frame.AutomaticSize=(guiVisible and Enum.AutomaticSize.Y or Enum.AutomaticSize.None)
end

for name,b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ═══════════════════════════════════════
-- SECTION BUILDER
-- ═══════════════════════════════════════
local BLOCKED={
    [Enum.KeyCode.Return]=true,[Enum.KeyCode.Escape]=true,
    [Enum.KeyCode.Tab]=true,[Enum.KeyCode.Backspace]=true,
    [Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,
    [Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,
    [Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true,
    [Enum.KeyCode.V]=true,
}

local function mkSection(parent, cfg)
    local sec=Instance.new("Frame",parent)
    sec.Size=UDim2.new(1,0,0,0); sec.AutomaticSize=Enum.AutomaticSize.Y
    sec.BackgroundColor3=C.card; sec.BorderSizePixel=0; sec.LayoutOrder=cfg.order
    local u=Instance.new("UIPadding",sec)
    u.PaddingLeft=UDim.new(0,10); u.PaddingRight=UDim.new(0,10)
    u.PaddingTop=UDim.new(0,7);   u.PaddingBottom=UDim.new(0,7)
    local ly=Instance.new("UIListLayout",sec)
    ly.SortOrder=Enum.SortOrder.LayoutOrder; ly.Padding=UDim.new(0,5)

    -- row 1: label + toggle
    local r1=Instance.new("Frame",sec); r1.Size=UDim2.new(1,0,0,20); r1.BackgroundTransparency=1; r1.LayoutOrder=1
    local lbl=Instance.new("TextLabel",r1); lbl.Size=UDim2.new(1,-52,1,0); lbl.BackgroundTransparency=1
    lbl.Text=cfg.icon.."  "..cfg.label; lbl.TextColor3=C.sub
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local tr=Instance.new("Frame",r1); tr.Size=UDim2.new(0,36,0,18); tr.Position=UDim2.new(1,-36,0.5,-9)
    tr.BackgroundColor3=Color3.fromRGB(22,28,50); tr.BorderSizePixel=0
    Instance.new("UICorner",tr).CornerRadius=UDim.new(0,9)
    Instance.new("UIStroke",tr).Color=C.bdr
    local kn=Instance.new("Frame",tr); kn.Size=UDim2.new(0,14,0,14); kn.Position=UDim2.new(0,2,0.5,-7)
    kn.BackgroundColor3=Color3.fromRGB(195,205,235); kn.BorderSizePixel=0
    Instance.new("UICorner",kn).CornerRadius=UDim.new(0,7)
    local togHit=Instance.new("TextButton",tr); togHit.Size=UDim2.new(1,0,1,0)
    togHit.BackgroundTransparency=1; togHit.Text=""; togHit.AutoButtonColor=false; togHit.ZIndex=5

    -- row 2: bind key
    local r2=Instance.new("Frame",sec); r2.Size=UDim2.new(1,0,0,20); r2.BackgroundTransparency=1; r2.LayoutOrder=2
    local kl=Instance.new("TextLabel",r2); kl.Size=UDim2.new(0,38,1,0); kl.BackgroundTransparency=1
    kl.Text="Key:"; kl.TextColor3=C.dim; kl.Font=Enum.Font.Gotham; kl.TextSize=8; kl.TextXAlignment=Enum.TextXAlignment.Left
    local bindB=Instance.new("TextButton",r2); bindB.Size=UDim2.new(0,64,0,18); bindB.Position=UDim2.new(0,40,0.5,-9)
    bindB.BackgroundColor3=Color3.fromRGB(18,22,44); bindB.BorderSizePixel=0
    bindB.Text=cfg.keyName; bindB.TextColor3=C.acc
    bindB.Font=Enum.Font.GothamBold; bindB.TextSize=9; bindB.AutoButtonColor=false
    Instance.new("UICorner",bindB).CornerRadius=UDim.new(0,5)
    Instance.new("UIStroke",bindB).Color=C.accD

    -- optional status label
    local statusLbl=nil
    if cfg.showStatus then
        local rs=Instance.new("Frame",sec); rs.Size=UDim2.new(1,0,0,12); rs.BackgroundTransparency=1; rs.LayoutOrder=2.5
        statusLbl=Instance.new("TextLabel",rs); statusLbl.Size=UDim2.new(1,0,1,0)
        statusLbl.BackgroundTransparency=1; statusLbl.Text=""
        statusLbl.TextColor3=C.dim; statusLbl.Font=Enum.Font.Code; statusLbl.TextSize=8
        statusLbl.TextXAlignment=Enum.TextXAlignment.Left
    end

    -- optional slider
    if cfg.slider then
        local s=cfg.slider
        local rs1=Instance.new("Frame",sec); rs1.Size=UDim2.new(1,0,0,13); rs1.BackgroundTransparency=1; rs1.LayoutOrder=3
        local vl=Instance.new("TextLabel",rs1); vl.Size=UDim2.new(1,0,1,0); vl.BackgroundTransparency=1
        vl.Text=s.label..": "..s.def; vl.TextColor3=C.acc; vl.Font=Enum.Font.GothamBold; vl.TextSize=8; vl.TextXAlignment=Enum.TextXAlignment.Left
        local rs2=Instance.new("Frame",sec); rs2.Size=UDim2.new(1,0,0,14); rs2.BackgroundTransparency=1; rs2.LayoutOrder=4
        local sbg=Instance.new("Frame",rs2); sbg.Size=UDim2.new(1,0,0,4); sbg.Position=UDim2.new(0,0,0.5,-2)
        sbg.BackgroundColor3=Color3.fromRGB(20,25,45); sbg.BorderSizePixel=0
        Instance.new("UICorner",sbg).CornerRadius=UDim.new(0,2)
        local pct0=(s.def-s.min)/(s.max-s.min)
        local fill=Instance.new("Frame",sbg); fill.Size=UDim2.new(pct0,0,1,0)
        fill.BackgroundColor3=C.acc; fill.BorderSizePixel=0
        Instance.new("UICorner",fill).CornerRadius=UDim.new(0,2)
        local sk=Instance.new("Frame",sbg); sk.Size=UDim2.new(0,11,0,11); sk.AnchorPoint=Vector2.new(0.5,0.5)
        sk.Position=UDim2.new(pct0,0,0.5,0); sk.BackgroundColor3=Color3.fromRGB(255,255,255); sk.BorderSizePixel=0; sk.ZIndex=3
        Instance.new("UICorner",sk).CornerRadius=UDim.new(0,6)
        local sHit=Instance.new("TextButton",sbg); sHit.Size=UDim2.new(1,0,0,20); sHit.Position=UDim2.new(0,0,0.5,-10)
        sHit.BackgroundTransparency=1; sHit.Text=""; sHit.AutoButtonColor=false; sHit.ZIndex=4
        local drag=false
        sHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
        sHit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
        UIS.InputChanged:Connect(function(i)
            if not drag or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
            local pct=math.clamp((i.Position.X-sbg.AbsolutePosition.X)/sbg.AbsoluteSize.X,0,1)
            local val=math.floor(s.min+pct*(s.max-s.min)+0.5)
            fill.Size=UDim2.new(pct,0,1,0); sk.Position=UDim2.new(pct,0,0.5,0)
            vl.Text=s.label..": "..val; if s.onChange then s.onChange(val) end
        end)
    end

    -- optional rejump
    local rjTr,rjKn,rjTogHit
    if cfg.rejump then
        local rr=Instance.new("Frame",sec); rr.Size=UDim2.new(1,0,0,18); rr.BackgroundTransparency=1; rr.LayoutOrder=5
        local rl=Instance.new("TextLabel",rr); rl.Size=UDim2.new(1,-52,1,0); rl.BackgroundTransparency=1
        rl.Text="↩  Re-jump"; rl.TextColor3=C.sub; rl.Font=Enum.Font.GothamBold; rl.TextSize=9; rl.TextXAlignment=Enum.TextXAlignment.Left
        rjTr=Instance.new("Frame",rr); rjTr.Size=UDim2.new(0,36,0,18); rjTr.Position=UDim2.new(1,-36,0.5,-9)
        rjTr.BackgroundColor3=Color3.fromRGB(22,28,50); rjTr.BorderSizePixel=0
        Instance.new("UICorner",rjTr).CornerRadius=UDim.new(0,9); Instance.new("UIStroke",rjTr).Color=C.bdr
        rjKn=Instance.new("Frame",rjTr); rjKn.Size=UDim2.new(0,14,0,14); rjKn.Position=UDim2.new(0,2,0.5,-7)
        rjKn.BackgroundColor3=Color3.fromRGB(195,205,235); rjKn.BorderSizePixel=0
        Instance.new("UICorner",rjKn).CornerRadius=UDim.new(0,7)
        rjTogHit=Instance.new("TextButton",rjTr); rjTogHit.Size=UDim2.new(1,0,1,0)
        rjTogHit.BackgroundTransparency=1; rjTogHit.Text=""; rjTogHit.AutoButtonColor=false; rjTogHit.ZIndex=5
    end

    local function setTog(on)
        tw(tr,{BackgroundColor3=on and C.acc or Color3.fromRGB(22,28,50)}):Play()
        twB(kn,{Position=on and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
    end
    local function setRj(on)
        if rjTr then tw(rjTr,{BackgroundColor3=on and C.acc or Color3.fromRGB(22,28,50)}):Play() end
        if rjKn then twB(rjKn,{Position=on and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play() end
    end
    return {togHit=togHit,bindBtn=bindB,rjTogHit=rjTogHit,setTog=setTog,setRj=setRj,statusLbl=statusLbl}
end

-- ═══════════════════════════════════════
-- PAGE CHEATS
-- ═══════════════════════════════════════
local pg1=tabPages["Cheats"]
mkDiv(pg1,1)
local ncSec=mkSection(pg1,{order=2,icon="👻",label="Noclip",keyName=ncKey.Name})
mkDiv(pg1,3)
local spSec=mkSection(pg1,{order=4,icon="💨",label="Speed",keyName=spKey.Name,
    slider={min=16,max=300,def=speedVal,label="Speed",onChange=function(v) speedVal=v; if speedOn then local h=hum(); if h then h.WalkSpeed=v end end end}})
mkDiv(pg1,5)
local hjSec=mkSection(pg1,{order=6,icon="🦘",label="High Jump",keyName=hjKey.Name,
    slider={min=50,max=500,def=jumpVal,label="Power",onChange=function(v) jumpVal=v; if jumpOn then local h=hum(); if h then h.JumpPower=v end end end},rejump=true})
mkDiv(pg1,7)
local shSec=mkSection(pg1,{order=8,icon="🔄",label="Shake",keyName=shakeKey.Name,showStatus=true})
mkDiv(pg1,9)

-- Sell section
local sellF=Instance.new("Frame",pg1); sellF.Size=UDim2.new(1,0,0,0); sellF.AutomaticSize=Enum.AutomaticSize.Y
sellF.BackgroundColor3=C.card; sellF.BorderSizePixel=0; sellF.LayoutOrder=10
local su=Instance.new("UIPadding",sellF); su.PaddingLeft=UDim.new(0,10); su.PaddingRight=UDim.new(0,10); su.PaddingTop=UDim.new(0,7); su.PaddingBottom=UDim.new(0,9)
local sLy=Instance.new("UIListLayout",sellF); sLy.SortOrder=Enum.SortOrder.LayoutOrder; sLy.Padding=UDim.new(0,5)
local sTR=Instance.new("Frame",sellF); sTR.Size=UDim2.new(1,0,0,16); sTR.BackgroundTransparency=1; sTR.LayoutOrder=1
local sTL=Instance.new("TextLabel",sTR); sTL.Size=UDim2.new(1,0,1,0); sTL.BackgroundTransparency=1
sTL.Text="💰  Sell from Hand"; sTL.TextColor3=C.sub; sTL.Font=Enum.Font.GothamBold; sTL.TextSize=10; sTL.TextXAlignment=Enum.TextXAlignment.Left
local sellSt=Instance.new("TextLabel",sellF); sellSt.Size=UDim2.new(1,0,0,10); sellSt.BackgroundTransparency=1
sellSt.Text="Waiting..."; sellSt.TextColor3=C.dim; sellSt.Font=Enum.Font.Gotham; sellSt.TextSize=8; sellSt.TextXAlignment=Enum.TextXAlignment.Left; sellSt.LayoutOrder=2
local sBR=Instance.new("Frame",sellF); sBR.Size=UDim2.new(1,0,0,20); sBR.BackgroundTransparency=1; sBR.LayoutOrder=3
local sBL=Instance.new("TextLabel",sBR); sBL.Size=UDim2.new(0,38,1,0); sBL.BackgroundTransparency=1
sBL.Text="Key:"; sBL.TextColor3=C.dim; sBL.Font=Enum.Font.Gotham; sBL.TextSize=8; sBL.TextXAlignment=Enum.TextXAlignment.Left
local sellBind=Instance.new("TextButton",sBR); sellBind.Size=UDim2.new(0,64,0,18); sellBind.Position=UDim2.new(0,40,0.5,-9)
sellBind.BackgroundColor3=Color3.fromRGB(18,22,44); sellBind.BorderSizePixel=0; sellBind.Text=sellKey.Name
sellBind.TextColor3=C.acc; sellBind.Font=Enum.Font.GothamBold; sellBind.TextSize=9; sellBind.AutoButtonColor=false
Instance.new("UICorner",sellBind).CornerRadius=UDim.new(0,5); Instance.new("UIStroke",sellBind).Color=C.accD
local sellBtn=Instance.new("TextButton",sellF); sellBtn.Size=UDim2.new(1,0,0,28); sellBtn.LayoutOrder=4
sellBtn.BackgroundColor3=Color3.fromRGB(16,58,36); sellBtn.BorderSizePixel=0
sellBtn.Text="💰  Sell Item in Hand"; sellBtn.TextColor3=C.grn
sellBtn.Font=Enum.Font.GothamBold; sellBtn.TextSize=9; sellBtn.AutoButtonColor=false
Instance.new("UICorner",sellBtn).CornerRadius=UDim.new(0,7); Instance.new("UIStroke",sellBtn).Color=Color3.fromRGB(22,82,50)
sellBtn.MouseEnter:Connect(function() tw(sellBtn,{BackgroundColor3=Color3.fromRGB(20,72,44)}):Play() end)
sellBtn.MouseLeave:Connect(function() tw(sellBtn,{BackgroundColor3=Color3.fromRGB(16,58,36)}):Play() end)
mkDiv(pg1,11)

-- ═══════════════════════════════════════
-- PAGE TP
-- ═══════════════════════════════════════
local pg2=tabPages["TP"]
local tpScroll=Instance.new("ScrollingFrame",pg2)
tpScroll.Size=UDim2.new(1,0,0,280); tpScroll.BackgroundTransparency=1; tpScroll.BorderSizePixel=0
tpScroll.ScrollBarThickness=3; tpScroll.ScrollBarImageColor3=C.acc
tpScroll.CanvasSize=UDim2.new(0,0,0,0); tpScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; tpScroll.LayoutOrder=1
local tpLy=Instance.new("UIListLayout",tpScroll); tpLy.SortOrder=Enum.SortOrder.LayoutOrder; tpLy.Padding=UDim.new(0,2)
pad(tpScroll,8,8,6,6)
local tpSt=Instance.new("TextLabel",tpScroll); tpSt.Size=UDim2.new(1,0,0,14); tpSt.BackgroundTransparency=1
tpSt.Text=""; tpSt.TextColor3=C.grn; tpSt.Font=Enum.Font.GothamBold; tpSt.TextSize=8
tpSt.TextXAlignment=Enum.TextXAlignment.Left; tpSt.LayoutOrder=0

for i,isl in ipairs(ISLANDS) do
    local bc=isl.special and Color3.fromRGB(40,16,42) or C.card
    local tc=isl.special and C.pink or C.sub
    local hc=isl.special and Color3.fromRGB(60,26,62) or C.cardH
    local b=Instance.new("TextButton",tpScroll); b.Size=UDim2.new(1,0,0,27)
    b.BackgroundColor3=bc; b.BorderSizePixel=0; b.Text="📍  "..isl.name
    b.TextColor3=tc; b.Font=Enum.Font.GothamBold; b.TextSize=9; b.TextXAlignment=Enum.TextXAlignment.Left
    b.AutoButtonColor=false; b.LayoutOrder=i
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); pad(b,8,8,0,0)
    b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=hc,TextColor3=C.txt}):Play() end)
    b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=bc,TextColor3=tc}):Play() end)
    b.MouseButton1Click:Connect(function()
        tw(b,{BackgroundColor3=C.accD}):Play(); task.wait(0.12); tw(b,{BackgroundColor3=bc}):Play()
        local ok=tpTo(isl.pos)
        tpSt.TextColor3=ok and C.grn or C.red
        tpSt.Text=(ok and "✅ " or "❌ ")..isl.name
        task.delay(3,function() tpSt.Text="" end)
    end)
end

-- ═══════════════════════════════════════
-- PAGE NPCs (nearby scan)
-- ═══════════════════════════════════════
local pg3=tabPages["NPCs"]

-- range slider
local rngF=Instance.new("Frame",pg3); rngF.Size=UDim2.new(1,0,0,0); rngF.AutomaticSize=Enum.AutomaticSize.Y
rngF.BackgroundColor3=C.card; rngF.BorderSizePixel=0; rngF.LayoutOrder=1
pad(rngF,10,10,7,7)
local rngLy=Instance.new("UIListLayout",rngF); rngLy.SortOrder=Enum.SortOrder.LayoutOrder; rngLy.Padding=UDim.new(0,4)
local rngRow1=Instance.new("Frame",rngF); rngRow1.Size=UDim2.new(1,0,0,13); rngRow1.BackgroundTransparency=1; rngRow1.LayoutOrder=1
local rngLbl=Instance.new("TextLabel",rngRow1); rngLbl.Size=UDim2.new(1,0,1,0); rngLbl.BackgroundTransparency=1
rngLbl.Text="Scan range: "..npcRange.." studs"; rngLbl.TextColor3=C.acc; rngLbl.Font=Enum.Font.GothamBold; rngLbl.TextSize=8; rngLbl.TextXAlignment=Enum.TextXAlignment.Left
local rngRow2=Instance.new("Frame",rngF); rngRow2.Size=UDim2.new(1,0,0,14); rngRow2.BackgroundTransparency=1; rngRow2.LayoutOrder=2
local rngBg=Instance.new("Frame",rngRow2); rngBg.Size=UDim2.new(1,0,0,4); rngBg.Position=UDim2.new(0,0,0.5,-2)
rngBg.BackgroundColor3=Color3.fromRGB(20,25,45); rngBg.BorderSizePixel=0
Instance.new("UICorner",rngBg).CornerRadius=UDim.new(0,2)
local rPct=(npcRange-1)/999
local rngFill=Instance.new("Frame",rngBg); rngFill.Size=UDim2.new(rPct,0,1,0)
rngFill.BackgroundColor3=C.acc; rngFill.BorderSizePixel=0
Instance.new("UICorner",rngFill).CornerRadius=UDim.new(0,2)
local rngKn=Instance.new("Frame",rngBg); rngKn.Size=UDim2.new(0,11,0,11); rngKn.AnchorPoint=Vector2.new(0.5,0.5)
rngKn.Position=UDim2.new(rPct,0,0.5,0); rngKn.BackgroundColor3=Color3.fromRGB(255,255,255); rngKn.BorderSizePixel=0; rngKn.ZIndex=3
Instance.new("UICorner",rngKn).CornerRadius=UDim.new(0,6)
local rngHit=Instance.new("TextButton",rngBg); rngHit.Size=UDim2.new(1,0,0,20); rngHit.Position=UDim2.new(0,0,0.5,-10)
rngHit.BackgroundTransparency=1; rngHit.Text=""; rngHit.AutoButtonColor=false; rngHit.ZIndex=4
local rngDrag=false
rngHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rngDrag=true end end)
rngHit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rngDrag=false end end)
UIS.InputChanged:Connect(function(i)
    if not rngDrag or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local pct=math.clamp((i.Position.X-rngBg.AbsolutePosition.X)/rngBg.AbsoluteSize.X,0,1)
    npcRange=math.floor(1+pct*999)
    rngFill.Size=UDim2.new(pct,0,1,0); rngKn.Position=UDim2.new(pct,0,0.5,0)
    rngLbl.Text="Scan range: "..npcRange.." studs"
end)
mkDiv(pg3,2)

-- scan button
local scanBtn=Instance.new("TextButton",pg3); scanBtn.Size=UDim2.new(1,0,0,30); scanBtn.LayoutOrder=3
scanBtn.BackgroundColor3=Color3.fromRGB(16,28,60); scanBtn.BorderSizePixel=0
scanBtn.Text="🔍  Scan Nearby NPCs"; scanBtn.TextColor3=C.acc
scanBtn.Font=Enum.Font.GothamBold; scanBtn.TextSize=9; scanBtn.AutoButtonColor=false
Instance.new("UICorner",scanBtn).CornerRadius=UDim.new(0,0)
Instance.new("UIStroke",scanBtn).Color=C.accD
scanBtn.MouseEnter:Connect(function() tw(scanBtn,{BackgroundColor3=Color3.fromRGB(20,36,78)}):Play() end)
scanBtn.MouseLeave:Connect(function() tw(scanBtn,{BackgroundColor3=Color3.fromRGB(16,28,60)}):Play() end)
mkDiv(pg3,4)

local npcScroll=Instance.new("ScrollingFrame",pg3)
npcScroll.Size=UDim2.new(1,0,0,220); npcScroll.BackgroundTransparency=1; npcScroll.BorderSizePixel=0
npcScroll.ScrollBarThickness=3; npcScroll.ScrollBarImageColor3=C.acc
npcScroll.CanvasSize=UDim2.new(0,0,0,0); npcScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; npcScroll.LayoutOrder=5
local npcLy=Instance.new("UIListLayout",npcScroll); npcLy.SortOrder=Enum.SortOrder.LayoutOrder; npcLy.Padding=UDim.new(0,2)
pad(npcScroll,8,8,4,4)

local function rebuildNPCs()
    for _,ch in ipairs(npcScroll:GetChildren()) do
        if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
    end
    local npcs=getNearby()
    if #npcs==0 then
        local l=Instance.new("TextLabel",npcScroll); l.Size=UDim2.new(1,0,0,26)
        l.BackgroundTransparency=1; l.Text="No NPCs within "..npcRange.." studs"
        l.TextColor3=C.dim; l.Font=Enum.Font.Gotham; l.TextSize=9
        l.TextXAlignment=Enum.TextXAlignment.Center; l.LayoutOrder=1; return
    end
    for i,npc in ipairs(npcs) do
        local b=Instance.new("TextButton",npcScroll); b.Size=UDim2.new(1,0,0,28)
        b.BackgroundColor3=C.card; b.BorderSizePixel=0; b.AutoButtonColor=false; b.LayoutOrder=i
        b.Text="🧑  "..npc.name.."  ("..npc.dist.." st)"
        b.TextColor3=C.sub; b.Font=Enum.Font.GothamBold; b.TextSize=8; b.TextXAlignment=Enum.TextXAlignment.Left
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); pad(b,8,8,0,0)
        b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.cardH,TextColor3=C.txt}):Play() end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.card,TextColor3=C.sub}):Play() end)
        local cp=npc.part
        b.MouseButton1Click:Connect(function()
            tw(b,{BackgroundColor3=C.accD}):Play(); task.wait(0.12); tw(b,{BackgroundColor3=C.card}):Play()
            tpToNPC(cp); task.delay(0.8,rebuildNPCs)
        end)
    end
end

scanBtn.MouseButton1Click:Connect(function()
    scanBtn.Text="⏳  Scanning..."; task.wait(0.15)
    rebuildNPCs(); scanBtn.Text="🔍  Scan Nearby NPCs"
end)

-- ═══════════════════════════════════════
-- VISIBILITY — com debounce pra nao bugar
-- ═══════════════════════════════════════
local function setVisible(v)
    if vDebounce then return end
    vDebounce=true
    guiVisible=v
    if v then
        -- mostra: primeiro restaura AutomaticSize, depois mostra conteudo
        frame.AutomaticSize=Enum.AutomaticSize.Y
        for _,ch in ipairs(frame:GetChildren()) do
            if ch~=header and (ch:IsA("Frame") or ch:IsA("ScrollingFrame")) then ch.Visible=true end
        end
        tw(vHint,{TextColor3=C.dim},0.1):Play()
    else
        -- esconde: tween pra 36px (so header), depois esconde conteudo
        frame.AutomaticSize=Enum.AutomaticSize.None
        tw(frame,{Size=UDim2.new(0,212,0,36)},0.18):Play()
        task.delay(0.18,function()
            for _,ch in ipairs(frame:GetChildren()) do
                if ch~=header and (ch:IsA("Frame") or ch:IsA("ScrollingFrame")) then ch.Visible=false end
            end
        end)
        tw(vHint,{TextColor3=C.acc},0.1):Play()
    end
    task.delay(0.25, function() vDebounce=false end)
end

-- ═══════════════════════════════════════
-- UPDATE DOT
-- ═══════════════════════════════════════
local function updateDot()
    tw(dot,{BackgroundColor3=(noclipOn or speedOn or jumpOn or shakeOn) and C.grn or C.dim}):Play()
end

-- ═══════════════════════════════════════
-- TOGGLES
-- ═══════════════════════════════════════
ncSec.togHit.MouseButton1Click:Connect(function()
    noclipOn=not noclipOn; setNoclip(noclipOn); ncSec.setTog(noclipOn)
    tw(fBdr,{Color=noclipOn and C.grn or C.bdr}):Play(); updateDot()
end)
spSec.togHit.MouseButton1Click:Connect(function()
    speedOn=not speedOn; spSec.setTog(speedOn); applySpeed(); updateDot()
end)
hjSec.togHit.MouseButton1Click:Connect(function()
    jumpOn=not jumpOn; hjSec.setTog(jumpOn); applyJump()
    if not jumpOn then reJumpOn=false; hjSec.setRj(false); stopReJump() end; updateDot()
end)
if hjSec.rjTogHit then
    hjSec.rjTogHit.MouseButton1Click:Connect(function()
        if not jumpOn then return end
        reJumpOn=not reJumpOn; hjSec.setRj(reJumpOn)
        if reJumpOn then startReJump() else stopReJump() end
    end)
end
shSec.togHit.MouseButton1Click:Connect(function()
    shakeOn=not shakeOn; shSec.setTog(shakeOn)
    if shakeOn then startShake() else stopShake() end; updateDot()
end)
sellBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(10,44,26)}):Play(); task.wait(0.1)
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(16,58,36)}):Play()
        local ok,msg=sellFromHand()
        sellSt.TextColor3=ok and C.grn or C.red; sellSt.Text=(ok and "✅ " or "❌ ")..msg
        task.wait(3); tw(sellSt,{TextColor3=C.dim}):Play(); sellSt.Text="Waiting..."
    end)
end)

-- shake status watcher
task.spawn(function()
    while true do
        task.wait(0.2)
        if shSec.statusLbl then
            if shakeOn then
                if shakeActive then shSec.statusLbl.Text="● clicking..."; shSec.statusLbl.TextColor3=C.grn
                else               shSec.statusLbl.Text="○ waiting for UI..."; shSec.statusLbl.TextColor3=C.yel end
            else shSec.statusLbl.Text="" end
        end
    end
end)

-- ═══════════════════════════════════════
-- REBIND
-- ═══════════════════════════════════════
local function setupBind(bindBtn,id,getKey,setKey)
    bindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening=id; bindBtn.Text="..."; tw(bindBtn,{TextColor3=C.yel}):Play()
        local conn; conn=UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
            if inp.KeyCode==Enum.KeyCode.Escape then
                bindBtn.Text=getKey().Name; tw(bindBtn,{TextColor3=C.acc}):Play()
                listening=nil; conn:Disconnect(); return
            end
            if BLOCKED[inp.KeyCode] then
                bindBtn.Text="invalid!"; tw(bindBtn,{TextColor3=C.red}):Play()
                task.wait(0.8); bindBtn.Text=getKey().Name; tw(bindBtn,{TextColor3=C.acc}):Play()
                listening=nil; conn:Disconnect(); return
            end
            setKey(inp.KeyCode); bindBtn.Text=inp.KeyCode.Name
            tw(bindBtn,{TextColor3=C.acc}):Play(); listening=nil; conn:Disconnect()
        end)
    end)
end

setupBind(ncSec.bindBtn, "nc",   function() return ncKey    end, function(k) ncKey=k    end)
setupBind(spSec.bindBtn, "sp",   function() return spKey    end, function(k) spKey=k    end)
setupBind(hjSec.bindBtn, "hj",   function() return hjKey    end, function(k) hjKey=k    end)
setupBind(shSec.bindBtn, "sh",   function() return shakeKey end, function(k) shakeKey=k end)
setupBind(sellBind,      "sell", function() return sellKey  end, function(k) sellKey=k  end)

-- ═══════════════════════════════════════
-- DRAG
-- ═══════════════════════════════════════
do
    local dr,ds,sp2=false,nil,nil
    local dh=Instance.new("TextButton",frame)
    dh.Size=UDim2.new(1,-20,0,36); dh.Position=UDim2.new(0,0,0,0)
    dh.BackgroundTransparency=1; dh.Text=""; dh.AutoButtonColor=false; dh.ZIndex=20
    dh.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true; ds=i.Position; sp2=frame.Position end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            frame.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
        end
    end)
end

-- ═══════════════════════════════════════
-- HOTKEYS
-- ═══════════════════════════════════════
UIS.InputBegan:Connect(function(inp,gpe)
    if gpe or listening then return end
    local k=inp.KeyCode
    if k==Enum.KeyCode.V then
        setVisible(not guiVisible)
    elseif k==ncKey then
        noclipOn=not noclipOn; setNoclip(noclipOn); ncSec.setTog(noclipOn)
        tw(fBdr,{Color=noclipOn and C.grn or C.bdr}):Play(); updateDot()
    elseif k==spKey then speedOn=not speedOn; spSec.setTog(speedOn); applySpeed(); updateDot()
    elseif k==hjKey then
        jumpOn=not jumpOn; hjSec.setTog(jumpOn); applyJump()
        if not jumpOn then reJumpOn=false; hjSec.setRj(false); stopReJump() end; updateDot()
    elseif k==shakeKey then
        shakeOn=not shakeOn; shSec.setTog(shakeOn)
        if shakeOn then startShake() else stopShake() end; updateDot()
    elseif k==sellKey then
        task.spawn(function()
            local ok,msg=sellFromHand()
            sellSt.TextColor3=ok and C.grn or C.red; sellSt.Text=(ok and "✅ " or "❌ ")..msg
            task.wait(3); tw(sellSt,{TextColor3=C.dim}):Play(); sellSt.Text="Waiting..."
        end)
    end
end)

switchTab("Cheats")