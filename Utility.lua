--[[
    UTILITY v5
    V = esconder/mostrar
    Drag pelo header
    Ban-safe: tudo client-side, sem prints
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

-- ═══════════════════════════════════════
-- CHAR HELPERS
-- ═══════════════════════════════════════
local function chr()  return LP.Character end
local function hum()  local c = chr(); return c and c:FindFirstChildOfClass("Humanoid") end
local function tool() local c = chr(); return c and c:FindFirstChildOfClass("Tool") end

-- ═══════════════════════════════════════
-- NOCLIP (FIX: PreSimulation antes da física rodar)
-- ═══════════════════════════════════════
local function setNoclip(v)
    noclipOn = v
    if v then
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        noclipConn = RunService.PreSimulation:Connect(function()
            local c = chr(); if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        local c = chr()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.CanCollide = true
                end
            end
        end
    end
end

-- ═══════════════════════════════════════
-- SPEED
-- ═══════════════════════════════════════
local function applySpeed()
    local h = hum(); if h then h.WalkSpeed = speedOn and speedVal or 16 end
end

-- ═══════════════════════════════════════
-- JUMP
-- ═══════════════════════════════════════
local function applyJump()
    local h = hum(); if h then h.JumpPower = jumpOn and jumpVal or 50 end
end

local function startReJump()
    if reJumpConn then reJumpConn:Disconnect(); reJumpConn = nil end
    reJumpConn = RunService.Heartbeat:Connect(function()
        if not reJumpOn or not jumpOn then reJumpConn:Disconnect(); reJumpConn = nil; return end
        local h = hum()
        if h and h.FloorMaterial ~= Enum.Material.Air then
            h.JumpPower = jumpVal
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.15)
        end
    end)
end

local function stopReJump()
    if reJumpConn then reJumpConn:Disconnect(); reJumpConn = nil end
end

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
    shakeConn = task.spawn(function()
        while shakeOn do pressEnter(); task.wait(shakeDelay) end
    end)
end

local function stopShake()
    shakeOn = false
    if shakeConn then pcall(task.cancel, shakeConn); shakeConn = nil end
end

-- ═══════════════════════════════════════
-- SELL
-- ═══════════════════════════════════════
local function sellFromHand()
    local t = tool()
    if not t then return false, "Sem item na mão" end
    local WS = game:GetService("Workspace")
    for _, m in ipairs(WS:GetDescendants()) do
        local nm = m.Name:lower()
        if nm:find("appraiser") or nm:find("apprais") or nm:find("merchant") then
            local rf = m:FindFirstChildWhichIsA("RemoteFunction", true)
            if rf then local ok, res = pcall(function() return rf:InvokeServer(t) end); if ok then return true, "OK ("..tostring(res)..")" end end
            local re = m:FindFirstChildWhichIsA("RemoteEvent", true)
            if re then pcall(function() re:FireServer(t) end); return true, "OK" end
        end
    end
    local rsEv = RS:FindFirstChild("events") or RS:FindFirstChild("Events")
    if rsEv then
        for _, n in ipairs({"sell","Sell","appraise","Appraise","sellfish","SellFish","sellhand","SellHand","appraiseFish","SellItem"}) do
            local e = rsEv:FindFirstChild(n)
            if e then
                if e:IsA("RemoteEvent") then pcall(function() e:FireServer(t) end); return true, n
                elseif e:IsA("RemoteFunction") then local ok,r2=pcall(function() return e:InvokeServer(t) end); if ok then return true, n end end
            end
        end
        for _, child in ipairs(rsEv:GetDescendants()) do
            local cn = child.Name:lower()
            if (cn:find("sell") or cn:find("appraise")) and child:IsA("RemoteEvent") then
                pcall(function() child:FireServer(t) end); return true, child.Name
            end
        end
    end
    for _, obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local on2 = obj.Name:lower()
            if on2:find("sell") or on2:find("appraise") or on2:find("vend") then
                local sz = obj.AbsoluteSize
                if sz.X > 2 and sz.Y > 2 then pcall(function() obj.MouseButton1Click:Fire() end); return true, "GUI."..obj.Name end
            end
        end
    end
    return false, "Nenhum método encontrado"
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

local BG    = Color3.fromRGB(13, 15, 22)
local CARD  = Color3.fromRGB(20, 23, 34)
local BLUE  = Color3.fromRGB(65, 130, 240)
local GREEN = Color3.fromRGB(50, 210, 115)
local DIM   = Color3.fromRGB(88, 95, 118)
local TXT   = Color3.fromRGB(215, 220, 235)
local STROK = Color3.fromRGB(35, 42, 65)

local function tw(o, p, d)
    return TweenSvc:Create(o, TweenInfo.new(d or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p)
end
local function twB(o, p)
    return TweenSvc:Create(o, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), p)
end

-- Frame principal
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 185, 0, 0)
frame.Position = UDim2.new(0, 20, 0.5, -130)
frame.BackgroundColor3 = BG
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.ClipsDescendants = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke", frame)
mainStroke.Color = STROK; mainStroke.Thickness = 1.2

local rootLayout = Instance.new("UIListLayout", frame)
rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
rootLayout.Padding = UDim.new(0, 0)

local function mkDivider(order)
    local d = Instance.new("Frame", frame)
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = STROK; d.BorderSizePixel = 0; d.LayoutOrder = order
end

local function addPad(p, t, b)
    local u = Instance.new("UIPadding", p)
    u.PaddingLeft = UDim.new(0, 10); u.PaddingRight  = UDim.new(0, 10)
    u.PaddingTop  = UDim.new(0, t or 6); u.PaddingBottom = UDim.new(0, b or 6)
end

-- ── Header ──────────────────────────────
local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundTransparency = 1; header.LayoutOrder = 0

local htitle = Instance.new("TextLabel", header)
htitle.Size = UDim2.new(1, -30, 1, 0); htitle.Position = UDim2.new(0, 10, 0, 0)
htitle.BackgroundTransparency = 1; htitle.Text = "🔧 UTILITY"
htitle.TextColor3 = TXT; htitle.Font = Enum.Font.GothamBlack; htitle.TextSize = 11
htitle.TextXAlignment = Enum.TextXAlignment.Left

-- hint V
local vHint = Instance.new("TextLabel", header)
vHint.Size = UDim2.new(0, 24, 0, 14); vHint.Position = UDim2.new(1, -28, 0.5, -7)
vHint.BackgroundColor3 = Color3.fromRGB(28, 32, 48); vHint.BorderSizePixel = 0
vHint.Text = "V"; vHint.TextColor3 = DIM; vHint.Font = Enum.Font.GothamBold; vHint.TextSize = 8
vHint.TextXAlignment = Enum.TextXAlignment.Center
Instance.new("UICorner", vHint).CornerRadius = UDim.new(0, 4)

local hdot = Instance.new("Frame", header)
hdot.Size = UDim2.new(0, 6, 0, 6); hdot.Position = UDim2.new(0, 10, 0.5, 4)
hdot.BackgroundColor3 = DIM; hdot.BorderSizePixel = 0; hdot.Visible = false
Instance.new("UICorner", hdot).CornerRadius = UDim.new(1, 0)

-- ── Seção compacta ──────────────────────
local function mkSection(cfg)
    local sec = Instance.new("Frame", frame)
    sec.Size = UDim2.new(1, 0, 0, 0)
    sec.AutomaticSize = Enum.AutomaticSize.Y
    sec.BackgroundColor3 = CARD; sec.BorderSizePixel = 0; sec.LayoutOrder = cfg.order
    addPad(sec)
    local sl = Instance.new("UIListLayout", sec)
    sl.SortOrder = Enum.SortOrder.LayoutOrder; sl.Padding = UDim.new(0, 4)

    local row1 = Instance.new("Frame", sec)
    row1.Size = UDim2.new(1, 0, 0, 18); row1.BackgroundTransparency = 1; row1.LayoutOrder = 1

    local lbl = Instance.new("TextLabel", row1)
    lbl.Size = UDim2.new(1, -44, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = cfg.icon .. "  " .. cfg.label
    lbl.TextColor3 = Color3.fromRGB(160, 170, 200)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local tr = Instance.new("Frame", row1)
    tr.Size = UDim2.new(0, 34, 0, 17); tr.Position = UDim2.new(1, -34, 0.5, -8)
    tr.BackgroundColor3 = Color3.fromRGB(30, 33, 48); tr.BorderSizePixel = 0
    Instance.new("UICorner", tr).CornerRadius = UDim.new(0, 9)

    local kn = Instance.new("Frame", tr)
    kn.Size = UDim2.new(0, 13, 0, 13); kn.Position = UDim2.new(0, 2, 0.5, -6)
    kn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(0, 7)

    local togHit = Instance.new("TextButton", tr)
    togHit.Size = UDim2.new(1, 0, 1, 0); togHit.BackgroundTransparency = 1
    togHit.Text = ""; togHit.AutoButtonColor = false; togHit.ZIndex = 5

    local row2 = Instance.new("Frame", sec)
    row2.Size = UDim2.new(1, 0, 0, 20); row2.BackgroundTransparency = 1; row2.LayoutOrder = 2

    local tLbl = Instance.new("TextLabel", row2)
    tLbl.Size = UDim2.new(0, 34, 1, 0); tLbl.BackgroundTransparency = 1
    tLbl.Text = "Tecla:"; tLbl.TextColor3 = DIM
    tLbl.Font = Enum.Font.Gotham; tLbl.TextSize = 8
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    local bindB = Instance.new("TextButton", row2)
    bindB.Size = UDim2.new(0, 58, 0, 18); bindB.Position = UDim2.new(0, 36, 0.5, -9)
    bindB.BackgroundColor3 = Color3.fromRGB(25, 28, 42); bindB.BorderSizePixel = 0
    bindB.Text = cfg.keyName; bindB.TextColor3 = BLUE
    bindB.Font = Enum.Font.GothamBold; bindB.TextSize = 9
    bindB.AutoButtonColor = false
    Instance.new("UICorner", bindB).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", bindB).Color = Color3.fromRGB(40, 60, 110)
    bindB.MouseEnter:Connect(function()
        if listening ~= cfg.id then tw(bindB, {BackgroundColor3 = Color3.fromRGB(32, 36, 54)}):Play() end
    end)
    bindB.MouseLeave:Connect(function()
        if listening ~= cfg.id then tw(bindB, {BackgroundColor3 = Color3.fromRGB(25, 28, 42)}):Play() end
    end)

    -- Slider (opcional)
    if cfg.slider then
        local s = cfg.slider
        local row3 = Instance.new("Frame", sec)
        row3.Size = UDim2.new(1, 0, 0, 12); row3.BackgroundTransparency = 1; row3.LayoutOrder = 3

        local valLbl = Instance.new("TextLabel", row3)
        valLbl.Size = UDim2.new(1, 0, 1, 0); valLbl.BackgroundTransparency = 1
        valLbl.Text = s.label..": "..s.def; valLbl.TextColor3 = BLUE
        valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 8
        valLbl.TextXAlignment = Enum.TextXAlignment.Left

        local row4 = Instance.new("Frame", sec)
        row4.Size = UDim2.new(1, 0, 0, 12); row4.BackgroundTransparency = 1; row4.LayoutOrder = 4

        local sbg = Instance.new("Frame", row4)
        sbg.Size = UDim2.new(1, 0, 0, 3); sbg.Position = UDim2.new(0, 0, 0.5, -1)
        sbg.BackgroundColor3 = Color3.fromRGB(28, 32, 46); sbg.BorderSizePixel = 0
        Instance.new("UICorner", sbg).CornerRadius = UDim.new(0, 2)

        local pct0 = (s.def - s.min) / (s.max - s.min)
        local fill = Instance.new("Frame", sbg)
        fill.Size = UDim2.new(pct0, 0, 1, 0)
        fill.BackgroundColor3 = BLUE; fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

        local sk = Instance.new("Frame", sbg)
        sk.Size = UDim2.new(0, 10, 0, 10); sk.AnchorPoint = Vector2.new(0.5, 0.5)
        sk.Position = UDim2.new(pct0, 0, 0.5, 0)
        sk.BackgroundColor3 = Color3.fromRGB(255,255,255); sk.BorderSizePixel = 0; sk.ZIndex = 3
        Instance.new("UICorner", sk).CornerRadius = UDim.new(0, 5)

        local sHit = Instance.new("TextButton", sbg)
        sHit.Size = UDim2.new(1, 0, 0, 18); sHit.Position = UDim2.new(0, 0, 0.5, -9)
        sHit.BackgroundTransparency = 1; sHit.Text = ""; sHit.AutoButtonColor = false; sHit.ZIndex = 4

        local dragging = false
        sHit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
        sHit.InputEnded:Connect(function(i)  if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UIS.InputChanged:Connect(function(i)
            if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local pct = math.clamp((i.Position.X - sbg.AbsolutePosition.X) / sbg.AbsoluteSize.X, 0, 1)
            local val = math.floor(s.min + pct * (s.max - s.min) + 0.5)
            fill.Size = UDim2.new(pct, 0, 1, 0); sk.Position = UDim2.new(pct, 0, 0.5, 0)
            valLbl.Text = s.label..": "..val
            if s.onChange then s.onChange(val) end
        end)
    end

    -- Re-jump (só jump)
    local rjTr, rjKn, rjTogHit
    if cfg.rejump then
        local row5 = Instance.new("Frame", sec)
        row5.Size = UDim2.new(1, 0, 0, 18); row5.BackgroundTransparency = 1; row5.LayoutOrder = 5

        local rjL = Instance.new("TextLabel", row5)
        rjL.Size = UDim2.new(1, -44, 1, 0); rjL.BackgroundTransparency = 1
        rjL.Text = "↩  Re-jump"; rjL.TextColor3 = Color3.fromRGB(155, 165, 195)
        rjL.Font = Enum.Font.GothamBold; rjL.TextSize = 9
        rjL.TextXAlignment = Enum.TextXAlignment.Left

        rjTr = Instance.new("Frame", row5)
        rjTr.Size = UDim2.new(0, 34, 0, 17); rjTr.Position = UDim2.new(1, -34, 0.5, -8)
        rjTr.BackgroundColor3 = Color3.fromRGB(30, 33, 48); rjTr.BorderSizePixel = 0
        Instance.new("UICorner", rjTr).CornerRadius = UDim.new(0, 9)

        rjKn = Instance.new("Frame", rjTr)
        rjKn.Size = UDim2.new(0, 13, 0, 13); rjKn.Position = UDim2.new(0, 2, 0.5, -6)
        rjKn.BackgroundColor3 = Color3.fromRGB(255, 255, 255); rjKn.BorderSizePixel = 0
        Instance.new("UICorner", rjKn).CornerRadius = UDim.new(0, 7)

        rjTogHit = Instance.new("TextButton", rjTr)
        rjTogHit.Size = UDim2.new(1, 0, 1, 0); rjTogHit.BackgroundTransparency = 1
        rjTogHit.Text = ""; rjTogHit.AutoButtonColor = false; rjTogHit.ZIndex = 5
    end

    local function setTogVis(on)
        tw(tr, {BackgroundColor3 = on and BLUE or Color3.fromRGB(30, 33, 48)}):Play()
        twB(kn, {Position = on and UDim2.new(0, 19, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}):Play()
    end
    local function setRjVis(on)
        if rjTr and rjKn then
            tw(rjTr, {BackgroundColor3 = on and BLUE or Color3.fromRGB(30, 33, 48)}):Play()
            twB(rjKn, {Position = on and UDim2.new(0, 19, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}):Play()
        end
    end

    return { togHit=togHit, bindBtn=bindB, rjTogHit=rjTogHit, setTogVis=setTogVis, setRjVis=setRjVis }
end

-- ═══════════════════════════════════════
-- MONTA SEÇÕES
-- ═══════════════════════════════════════
mkDivider(1)
local ncSec = mkSection({id="nc", order=2, icon="👻", label="Noclip",    keyName=ncKey.Name})
mkDivider(3)
local spSec = mkSection({id="sp", order=4, icon="💨", label="Speed",     keyName=spKey.Name,
    slider={min=16, max=300, def=speedVal, label="Speed", onChange=function(v)
        speedVal=v; if speedOn then local h=hum(); if h then h.WalkSpeed=v end end
    end}})
mkDivider(5)
local hjSec = mkSection({id="hj", order=6, icon="🦘", label="High Jump", keyName=hjKey.Name,
    slider={min=50, max=500, def=jumpVal, label="Força", onChange=function(v)
        jumpVal=v; if jumpOn then local h=hum(); if h then h.JumpPower=v end end
    end}, rejump=true})
mkDivider(7)
local shSec = mkSection({id="sh", order=8, icon="🔄", label="Shake Spam", keyName=shakeKey.Name})
mkDivider(9)

-- ── Sell ────────────────────────────────
local sellSec = Instance.new("Frame", frame)
sellSec.Size = UDim2.new(1, 0, 0, 0); sellSec.AutomaticSize = Enum.AutomaticSize.Y
sellSec.BackgroundColor3 = CARD; sellSec.BorderSizePixel = 0; sellSec.LayoutOrder = 10
addPad(sellSec, 6, 8)
local sellLy = Instance.new("UIListLayout", sellSec)
sellLy.SortOrder = Enum.SortOrder.LayoutOrder; sellLy.Padding = UDim.new(0, 5)

local sTitleRow = Instance.new("Frame", sellSec)
sTitleRow.Size = UDim2.new(1, 0, 0, 16); sTitleRow.BackgroundTransparency = 1; sTitleRow.LayoutOrder = 1
local sTL = Instance.new("TextLabel", sTitleRow)
sTL.Size = UDim2.new(1, 0, 1, 0); sTL.BackgroundTransparency = 1
sTL.Text = "💰  Sell from Hand"; sTL.TextColor3 = Color3.fromRGB(160, 170, 200)
sTL.Font = Enum.Font.GothamBold; sTL.TextSize = 10; sTL.TextXAlignment = Enum.TextXAlignment.Left

local sellStatus = Instance.new("TextLabel", sellSec)
sellStatus.Size = UDim2.new(1, 0, 0, 10); sellStatus.BackgroundTransparency = 1
sellStatus.Text = "Aguardando..."; sellStatus.TextColor3 = DIM
sellStatus.Font = Enum.Font.Gotham; sellStatus.TextSize = 8
sellStatus.TextXAlignment = Enum.TextXAlignment.Left; sellStatus.LayoutOrder = 2

local sellBtn = Instance.new("TextButton", sellSec)
sellBtn.Size = UDim2.new(1, 0, 0, 26); sellBtn.LayoutOrder = 3
sellBtn.BackgroundColor3 = Color3.fromRGB(22, 75, 48); sellBtn.BorderSizePixel = 0
sellBtn.Text = "💰  Vender Item da Mão"; sellBtn.TextColor3 = GREEN
sellBtn.Font = Enum.Font.GothamBold; sellBtn.TextSize = 9; sellBtn.AutoButtonColor = false
Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", sellBtn).Color = Color3.fromRGB(28, 95, 62)
sellBtn.MouseEnter:Connect(function() tw(sellBtn, {BackgroundColor3 = Color3.fromRGB(28, 92, 58)}):Play() end)
sellBtn.MouseLeave:Connect(function() tw(sellBtn, {BackgroundColor3 = Color3.fromRGB(22, 75, 48)}):Play() end)

-- rodapé
mkDivider(11)
local footer = Instance.new("Frame", frame)
footer.Size = UDim2.new(1, 0, 0, 18); footer.BackgroundTransparency = 1; footer.LayoutOrder = 12
local fL = Instance.new("TextLabel", footer)
fL.Size = UDim2.new(1,-16,1,0); fL.Position = UDim2.new(0,10,0,0)
fL.BackgroundTransparency = 1; fL.Text = "V = ocultar  •  client-side"
fL.TextColor3 = Color3.fromRGB(40,45,65); fL.Font = Enum.Font.Gotham; fL.TextSize = 7
fL.TextXAlignment = Enum.TextXAlignment.Left

-- ═══════════════════════════════════════
-- TOGGLE V (esconder/mostrar)
-- ═══════════════════════════════════════
local guiVisible = true

local function setVisible(v)
    guiVisible = v
    for _, child in ipairs(frame:GetChildren()) do
        if child ~= header and child:IsA("Frame") then
            child.Visible = v
        end
    end
    if v then
        frame.AutomaticSize = Enum.AutomaticSize.Y
    else
        frame.AutomaticSize = Enum.AutomaticSize.None
        tw(frame, {Size = UDim2.new(0, 185, 0, 30)}, 0.15):Play()
    end
    tw(vHint, {TextColor3 = v and DIM or BLUE}, 0.1):Play()
end

-- ═══════════════════════════════════════
-- LÓGICA TOGGLES
-- ═══════════════════════════════════════
ncSec.togHit.MouseButton1Click:Connect(function()
    noclipOn = not noclipOn; setNoclip(noclipOn); ncSec.setTogVis(noclipOn)
    tw(mainStroke, {Color = noclipOn and GREEN or STROK}):Play()
end)

spSec.togHit.MouseButton1Click:Connect(function()
    speedOn = not speedOn; spSec.setTogVis(speedOn); applySpeed()
end)

hjSec.togHit.MouseButton1Click:Connect(function()
    jumpOn = not jumpOn; hjSec.setTogVis(jumpOn); applyJump()
    if not jumpOn then reJumpOn=false; hjSec.setRjVis(false); stopReJump() end
end)
if hjSec.rjTogHit then
    hjSec.rjTogHit.MouseButton1Click:Connect(function()
        if not jumpOn then return end
        reJumpOn = not reJumpOn; hjSec.setRjVis(reJumpOn)
        if reJumpOn then startReJump() else stopReJump() end
    end)
end

shSec.togHit.MouseButton1Click:Connect(function()
    shakeOn = not shakeOn; shSec.setTogVis(shakeOn)
    if shakeOn then startShake() else stopShake() end
end)

sellBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        tw(sellBtn, {BackgroundColor3 = Color3.fromRGB(15,55,35)}):Play()
        task.wait(0.1); tw(sellBtn, {BackgroundColor3 = Color3.fromRGB(22,75,48)}):Play()
        local ok, msg = sellFromHand()
        if ok then sellStatus.Text="✅ "..msg; tw(sellStatus,{TextColor3=GREEN}):Play()
        else       sellStatus.Text="❌ "..msg; tw(sellStatus,{TextColor3=Color3.fromRGB(230,65,80)}):Play() end
        task.wait(3); tw(sellStatus,{TextColor3=DIM}):Play(); sellStatus.Text="Aguardando..."
    end)
end)

-- ═══════════════════════════════════════
-- REBIND (FIX: bloqueia teclas perigosas)
-- ═══════════════════════════════════════

-- Teclas proibidas: causam bugs, abrem menus ou saem do jogo
local BLOCKED_KEYS = {
    [Enum.KeyCode.Return]       = true,
    [Enum.KeyCode.KeypadEnter]  = true,
    [Enum.KeyCode.Backspace]    = true,
    [Enum.KeyCode.Delete]       = true,
    [Enum.KeyCode.Escape]       = true,
    [Enum.KeyCode.Tab]          = true,
    [Enum.KeyCode.CapsLock]     = true,
    [Enum.KeyCode.LeftShift]    = true,
    [Enum.KeyCode.RightShift]   = true,
    [Enum.KeyCode.LeftControl]  = true,
    [Enum.KeyCode.RightControl] = true,
    [Enum.KeyCode.LeftAlt]      = true,
    [Enum.KeyCode.RightAlt]     = true,
    [Enum.KeyCode.LeftSuper]    = true,
    [Enum.KeyCode.RightSuper]   = true,
    [Enum.KeyCode.V]            = true, -- reservado para toggle GUI
}

local function setupBind(sec, id, getKey, setKey)
    sec.bindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = id; sec.bindBtn.Text = "..."
        tw(sec.bindBtn, {TextColor3 = Color3.fromRGB(235,195,55)}):Play()
        local conn; conn = UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end

            -- Cancela com Escape sem mudar a tecla
            if inp.KeyCode == Enum.KeyCode.Escape then
                sec.bindBtn.Text = getKey().Name
                tw(sec.bindBtn, {TextColor3 = BLUE}):Play()
                listening = nil; conn:Disconnect()
                return
            end

            -- Bloqueia teclas proibidas e avisa
            if BLOCKED_KEYS[inp.KeyCode] then
                sec.bindBtn.Text = "inválida!"
                tw(sec.bindBtn, {TextColor3 = Color3.fromRGB(230,65,80)}):Play()
                task.wait(0.8)
                sec.bindBtn.Text = getKey().Name
                tw(sec.bindBtn, {TextColor3 = BLUE}):Play()
                listening = nil; conn:Disconnect()
                return
            end

            -- Tecla válida: aplica
            setKey(inp.KeyCode)
            sec.bindBtn.Text = inp.KeyCode.Name
            tw(sec.bindBtn, {TextColor3 = BLUE}):Play()
            listening = nil; conn:Disconnect()
        end)
    end)
end

setupBind(ncSec,"nc",function() return ncKey    end,function(k) ncKey=k     end)
setupBind(spSec,"sp",function() return spKey    end,function(k) spKey=k     end)
setupBind(hjSec,"hj",function() return hjKey    end,function(k) hjKey=k     end)
setupBind(shSec,"sh",function() return shakeKey end,function(k) shakeKey=k  end)

-- ═══════════════════════════════════════
-- DRAG
-- ═══════════════════════════════════════
do
    local dr, ds, sp = false, nil, nil
    local dh = Instance.new("TextButton", frame)
    dh.Size = UDim2.new(1,-20,0,30); dh.Position = UDim2.new(0,0,0,0)
    dh.BackgroundTransparency = 1; dh.Text = ""; dh.AutoButtonColor = false; dh.ZIndex = 20
    dh.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dr=true; ds=i.Position; sp=frame.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end

-- ═══════════════════════════════════════
-- HOTKEYS GLOBAIS
-- ═══════════════════════════════════════
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or listening then return end
    local k = inp.KeyCode
    if k == Enum.KeyCode.V then
        setVisible(not guiVisible)
    elseif k == ncKey then
        noclipOn = not noclipOn; setNoclip(noclipOn); ncSec.setTogVis(noclipOn)
        tw(mainStroke, {Color = noclipOn and GREEN or STROK}):Play()
    elseif k == spKey then
        speedOn = not speedOn; spSec.setTogVis(speedOn); applySpeed()
    elseif k == hjKey then
        jumpOn = not jumpOn; hjSec.setTogVis(jumpOn); applyJump()
        if not jumpOn then reJumpOn=false; hjSec.setRjVis(false); stopReJump() end
    elseif k == shakeKey then
        shakeOn = not shakeOn; shSec.setTogVis(shakeOn)
        if shakeOn then startShake() else stopShake() end
    end
end)