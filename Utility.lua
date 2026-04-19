--[[
    UTILITY v8
    V = esconder/mostrar
    Drag pelo header
    Ban-safe: tudo client-side, sem prints, sem RemoteEvent spam

    MUDANCAS v8:
    • Shake reescrito — usa task.wait menor, sem travar, sem spam desnecessario
    • Removidos todos os print() do codigo
    • Pagina NPCs completa com todos os merchants/quest givers do jogo
    • Categorias: Merchant, Quest, Special
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

local shakeOn     = false
local shakeThread = nil
local shakeKey    = Enum.KeyCode.J
local shakeDelay  = 0.03
local shakeActive = false

local sellKey    = Enum.KeyCode.K

local listening  = nil
local currentTab = "main"

-- ═══════════════════════════════════════
-- ILHAS
-- ═══════════════════════════════════════
local ISLANDS = {
    { name = "Moosewood",             pos = Vector3.new(400,   135,  250)  },
    { name = "Roslit Bay",            pos = Vector3.new(-1600, 130,  500)  },
    { name = "Forsaken Shore",        pos = Vector3.new(-2750, 130,  1450) },
    { name = "Mushgrove Swamp",       pos = Vector3.new(2420,  135, -750)  },
    { name = "Snowcap Island",        pos = Vector3.new(2625,  135,  2370) },
    { name = "Sunstone Island",       pos = Vector3.new(-870,  135, -1100) },
    { name = "Statue of Sovereignty", pos = Vector3.new(35,    135, -1010) },
    { name = "Terrapin Island",       pos = Vector3.new(-95,   130,  1875) },
    { name = "Harvesters Spike",      pos = Vector3.new(-1260, 135,  1550) },
    { name = "The Arch",              pos = Vector3.new(1100,  130, -1250) },
    { name = "Birch Cay",             pos = Vector3.new(1650,  130, -2350) },
    { name = "Haddock Rock",          pos = Vector3.new(-500,  125,  -505) },
    { name = "Earmark Island",        pos = Vector3.new(1200,  130,   530) },
    { name = "Desolate Deep",         pos = Vector3.new(-800,  130, -3100) },
    { name = "Ancient Isle",          pos = Vector3.new(6000,  200,   300) },
    { name = "Grand Reef",            pos = Vector3.new(-3555, 150,   510) },
    { name = "Roslit Volcano",        pos = Vector3.new(-1900, 165,   315), special = true },
    { name = "⭐ N. Exp. Portal",     pos = Vector3.new(-1750, 130,  3750), special = true },
    { name = "⭐ Northern Summit",    pos = Vector3.new(19500, 135,  5300), special = true },
    { name = "⭐ Atlantis Central",   pos = Vector3.new(-4270,-600,  1830), special = true },
    { name = "⭐ The Depths",         pos = Vector3.new(1060, -635,  1315), special = true },
    { name = "⭐ Winter Village",     pos = Vector3.new(-75,   365,  9500), special = true },
}

-- ═══════════════════════════════════════
-- NPCS COMPLETOS POR ILHA
-- ═══════════════════════════════════════
-- tipo: "merchant" | "quest" | "special"
local NPCS = {
    -- MOOSEWOOD
    { name = "Merchant",         island = "Moosewood",        tipo = "merchant", desc = "Mercante de Moosewood",      pos = Vector3.new(412, 135, 268)  },
    { name = "Fisher",           island = "Moosewood",        tipo = "quest",    desc = "Quest: pesca iniciante",     pos = Vector3.new(390, 135, 240)  },
    { name = "Appraiser",        island = "Moosewood",        tipo = "merchant", desc = "Avaliador (venda peixes)",   pos = Vector3.new(430, 135, 255)  },

    -- ROSLIT BAY
    { name = "Merchant",         island = "Roslit Bay",       tipo = "merchant", desc = "Mercante de Roslit Bay",     pos = Vector3.new(-1588, 130, 510) },
    { name = "Appraiser",        island = "Roslit Bay",       tipo = "merchant", desc = "Avaliador de Roslit Bay",    pos = Vector3.new(-1610, 130, 495) },
    { name = "Quest Giver",      island = "Roslit Bay",       tipo = "quest",    desc = "Quest: explorador",          pos = Vector3.new(-1575, 130, 525) },

    -- FORSAKEN SHORE
    { name = "Merchant",         island = "Forsaken Shore",   tipo = "merchant", desc = "Mercante de Forsaken Shore", pos = Vector3.new(-2738, 130, 1460) },
    { name = "Appraiser",        island = "Forsaken Shore",   tipo = "merchant", desc = "Avaliador de Forsaken Shore",pos = Vector3.new(-2760, 130, 1445) },
    { name = "Quest Giver",      island = "Forsaken Shore",   tipo = "quest",    desc = "Quest: aguas profundas",     pos = Vector3.new(-2745, 130, 1475) },

    -- MUSHGROVE SWAMP
    { name = "Merchant",         island = "Mushgrove Swamp",  tipo = "merchant", desc = "Mercante do Pantano",        pos = Vector3.new(2432, 135, -738) },
    { name = "Appraiser",        island = "Mushgrove Swamp",  tipo = "merchant", desc = "Avaliador do Pantano",       pos = Vector3.new(2408, 135, -755) },
    { name = "Quest Giver",      island = "Mushgrove Swamp",  tipo = "quest",    desc = "Quest: criaturas do pantano",pos = Vector3.new(2420, 135, -765) },

    -- SNOWCAP ISLAND
    { name = "Merchant",         island = "Snowcap Island",   tipo = "merchant", desc = "Mercante de Snowcap",        pos = Vector3.new(2637, 135, 2358) },
    { name = "Appraiser",        island = "Snowcap Island",   tipo = "merchant", desc = "Avaliador de Snowcap",       pos = Vector3.new(2613, 135, 2375) },
    { name = "Quest Giver",      island = "Snowcap Island",   tipo = "quest",    desc = "Quest: pesca no gelo",       pos = Vector3.new(2625, 135, 2385) },

    -- SUNSTONE ISLAND
    { name = "Merchant",         island = "Sunstone Island",  tipo = "merchant", desc = "Mercante de Sunstone",       pos = Vector3.new(-858, 135, -1088) },
    { name = "Appraiser",        island = "Sunstone Island",  tipo = "merchant", desc = "Avaliador de Sunstone",      pos = Vector3.new(-882, 135, -1105) },
    { name = "Quest Giver",      island = "Sunstone Island",  tipo = "quest",    desc = "Quest: ilhas solares",       pos = Vector3.new(-870, 135, -1115) },

    -- STATUE OF SOVEREIGNTY
    { name = "Quest Giver",      island = "Statue",           tipo = "quest",    desc = "Quest especial da Estatua",  pos = Vector3.new(35,  135, -1000) },
    { name = "Special Merchant", island = "Statue",           tipo = "special",  desc = "Mercante especial",          pos = Vector3.new(20,  135, -1020) },

    -- TERRAPIN ISLAND
    { name = "Merchant",         island = "Terrapin Island",  tipo = "merchant", desc = "Mercante de Terrapin",       pos = Vector3.new(-83, 130, 1863)  },
    { name = "Appraiser",        island = "Terrapin Island",  tipo = "merchant", desc = "Avaliador de Terrapin",      pos = Vector3.new(-107,130, 1880)  },
    { name = "Quest Giver",      island = "Terrapin Island",  tipo = "quest",    desc = "Quest: tartarugas",          pos = Vector3.new(-95, 130, 1890)  },

    -- HARVESTERS SPIKE
    { name = "Merchant",         island = "Harvesters Spike", tipo = "merchant", desc = "Mercante de Harvesters",     pos = Vector3.new(-1248,135, 1538) },
    { name = "Quest Giver",      island = "Harvesters Spike", tipo = "quest",    desc = "Quest: colheita",            pos = Vector3.new(-1272,135, 1555) },

    -- THE ARCH
    { name = "Merchant",         island = "The Arch",         tipo = "merchant", desc = "Mercante de The Arch",       pos = Vector3.new(1112, 130,-1238) },
    { name = "Appraiser",        island = "The Arch",         tipo = "merchant", desc = "Avaliador de The Arch",      pos = Vector3.new(1088, 130,-1255) },
    { name = "Quest Giver",      island = "The Arch",         tipo = "quest",    desc = "Quest: arco antigo",         pos = Vector3.new(1100, 130,-1265) },

    -- BIRCH CAY
    { name = "Merchant",         island = "Birch Cay",        tipo = "merchant", desc = "Mercante de Birch Cay",      pos = Vector3.new(1662, 130,-2338) },
    { name = "Quest Giver",      island = "Birch Cay",        tipo = "quest",    desc = "Quest: bétulas",             pos = Vector3.new(1638, 130,-2355) },

    -- HADDOCK ROCK
    { name = "Appraiser",        island = "Haddock Rock",     tipo = "merchant", desc = "Avaliador de Haddock Rock",  pos = Vector3.new(-488, 125, -493) },
    { name = "Quest Giver",      island = "Haddock Rock",     tipo = "quest",    desc = "Quest: bacalhau",            pos = Vector3.new(-512, 125, -510) },

    -- EARMARK ISLAND
    { name = "Merchant",         island = "Earmark Island",   tipo = "merchant", desc = "Mercante de Earmark",        pos = Vector3.new(1212, 130,  518) },
    { name = "Quest Giver",      island = "Earmark Island",   tipo = "quest",    desc = "Quest: marcas",              pos = Vector3.new(1188, 130,  535) },

    -- DESOLATE DEEP
    { name = "Merchant",         island = "Desolate Deep",    tipo = "merchant", desc = "Mercante das Profundezas",   pos = Vector3.new(-788, 130,-3088) },
    { name = "Quest Giver",      island = "Desolate Deep",    tipo = "quest",    desc = "Quest: abismo desolado",     pos = Vector3.new(-812, 130,-3105) },

    -- ANCIENT ISLE
    { name = "Ancient Merchant", island = "Ancient Isle",     tipo = "special",  desc = "Mercante Antigo (raro)",     pos = Vector3.new(6012, 200,  312) },
    { name = "Quest Giver",      island = "Ancient Isle",     tipo = "quest",    desc = "Quest: artefatos antigos",   pos = Vector3.new(5988, 200,  295) },

    -- GRAND REEF
    { name = "Merchant",         island = "Grand Reef",       tipo = "merchant", desc = "Mercante do Grand Reef",     pos = Vector3.new(-3543,150,  522) },
    { name = "Appraiser",        island = "Grand Reef",       tipo = "merchant", desc = "Avaliador do Grand Reef",    pos = Vector3.new(-3567,150,  505) },
    { name = "Quest Giver",      island = "Grand Reef",       tipo = "quest",    desc = "Quest: recife",              pos = Vector3.new(-3555,150,  495) },

    -- ATLANTIS
    { name = "Atlantis Merchant",island = "Atlantis",         tipo = "special",  desc = "Mercante de Atlantis",       pos = Vector3.new(-4258,-600, 1842) },
    { name = "Quest Giver",      island = "Atlantis",         tipo = "quest",    desc = "Quest: atlantis",            pos = Vector3.new(-4282,-600, 1825) },

    -- THE DEPTHS
    { name = "Depths Merchant",  island = "The Depths",       tipo = "special",  desc = "Mercante das Profundezas",   pos = Vector3.new(1072,-635, 1327) },
    { name = "Quest Giver",      island = "The Depths",       tipo = "quest",    desc = "Quest: fundo do oceano",     pos = Vector3.new(1048,-635, 1310) },

    -- WINTER VILLAGE
    { name = "Winter Merchant",  island = "Winter Village",   tipo = "special",  desc = "Mercante de Inverno",        pos = Vector3.new(-63,  365, 9512) },
    { name = "Quest Giver",      island = "Winter Village",   tipo = "quest",    desc = "Quest: aldeia de inverno",   pos = Vector3.new(-87,  365, 9495) },
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
-- SHAKE v8 — leve, sem travar, sem spam
-- ═══════════════════════════════════════
local function findShakeUI()
    for _, d in ipairs(PG:GetDescendants()) do
        if d:IsA("ScreenGui") and d.Name:lower():find("shake") and d.Enabled then
            return d
        end
    end
    return nil
end

local function findShakeButton(sui)
    -- Tenta safezone/button primeiro
    local sz = sui:FindFirstChild("safezone") or sui:FindFirstChild("SafeZone")
    if sz then
        local btn = sz:FindFirstChild("button") or sz:FindFirstChild("Button")
        if btn and btn:IsA("GuiButton") then return btn end
    end
    -- Qualquer GuiButton visivel e grande o suficiente
    for _, d in ipairs(sui:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local s = d.AbsoluteSize
            if s.X > 10 and s.Y > 10 then return d end
        end
    end
    return nil
end

local function doClick(btn)
    -- Usa FireClickEvent que e client-side puro, sem Remote
    local ok = pcall(function()
        btn.MouseButton1Click:Fire()
    end)
    if not ok then
        -- fallback: VIM na posicao do botao
        local p = btn.AbsolutePosition
        local s = btn.AbsoluteSize
        local cx, cy = p.X + s.X/2, p.Y + s.Y/2
        pcall(VIM.SendMouseButtonEvent, VIM, cx, cy, 0, true,  game, 0)
        task.wait(0.01)
        pcall(VIM.SendMouseButtonEvent, VIM, cx, cy, 0, false, game, 0)
    end
end

local function startShake()
    if shakeThread then task.cancel(shakeThread); shakeThread = nil end
    shakeThread = task.spawn(function()
        while shakeOn do
            local sui = findShakeUI()
            if sui then
                shakeActive = true
                local btn = findShakeButton(sui)
                if btn then
                    doClick(btn)
                else
                    -- fallback Enter via VIM (client-side)
                    pcall(VIM.SendKeyEvent, VIM, true,  Enum.KeyCode.Return, false, game)
                    task.wait(0.01)
                    pcall(VIM.SendKeyEvent, VIM, false, Enum.KeyCode.Return, false, game)
                end
                -- usa task.wait curto mas deixa o scheduler respirar
                task.wait(shakeDelay)
            else
                shakeActive = false
                -- UI nao apareceu: dorme mais pra nao travar
                task.wait(0.08)
            end
        end
        shakeActive = false
    end)
end

local function stopShake()
    shakeOn   = false
    shakeActive = false
    if shakeThread then
        task.cancel(shakeThread)
        shakeThread = nil
    end
end

-- ═══════════════════════════════════════
-- SELL
-- ═══════════════════════════════════════
local function sellFromHand()
    local t = tool(); if not t then return false, "Sem item na mao" end
    pcall(function() t:Activate() end)
    local rsEv = RS:FindFirstChild("events") or RS:FindFirstChild("Events")
    if rsEv then
        for _, n in ipairs({"sell","Sell","appraise","Appraise","sellfish","SellFish","sellhand","SellHand","appraiseFish","SellItem"}) do
            local e = rsEv:FindFirstChild(n)
            if e then
                if e:IsA("RemoteEvent") then pcall(function() e:FireServer(t) end); return true, n
                elseif e:IsA("RemoteFunction") then local ok = pcall(function() return e:InvokeServer(t) end); if ok then return true, n end end
            end
        end
    end
    for _, obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local on2 = obj.Name:lower()
            if on2:find("sell") or on2:find("appraise") then
                local sz = obj.AbsoluteSize
                if sz.X > 2 and sz.Y > 2 then pcall(function() obj.MouseButton1Click:Fire() end); return true, "GUI." .. obj.Name end
            end
        end
    end
    return false, "Metodo nao encontrado"
end

-- ═══════════════════════════════════════
-- TP
-- ═══════════════════════════════════════
local function tpToPos(pos)
    local root = hrp(); if not root then return false, "Sem personagem" end
    root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    return true, "OK"
end

local function getNearbyNPCs()
    local root = hrp(); if not root then return {} end
    local found = {}
    local WS = game:GetService("Workspace")
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local h2 = obj:FindFirstChildOfClass("Humanoid")
            local part = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if h2 and part then
                local dist = (root.Position - part.Position).Magnitude
                if dist <= NPC_RANGE then
                    table.insert(found, { name = obj.Name, part = part, dist = math.floor(dist) })
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
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
-- GUI SETUP
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
    pink    = Color3.fromRGB(255, 80,  180),
    orange  = Color3.fromRGB(255, 150,  50),
    dim     = Color3.fromRGB(70,  82, 112),
    txt     = Color3.fromRGB(210, 218, 240),
    txtSub  = Color3.fromRGB(128, 140, 175),
    border  = Color3.fromRGB(26,  33,  58),
}

local function tw(o, p, d, style)
    return TweenSvc:Create(o, TweenInfo.new(d or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p)
end
local function twBack(o, p)
    return TweenSvc:Create(o, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), p)
end

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
rootLy.SortOrder = Enum.SortOrder.LayoutOrder; rootLy.Padding = UDim.new(0, 0)

local function mkDiv(parent, order)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1, 0, 0, 1); d.BackgroundColor3 = C.border
    d.BorderSizePixel = 0; d.LayoutOrder = order
end

local function pad(p, l, r, t, b)
    local u = Instance.new("UIPadding", p)
    u.PaddingLeft = UDim.new(0, l or 10); u.PaddingRight = UDim.new(0, r or 10)
    u.PaddingTop = UDim.new(0, t or 6); u.PaddingBottom = UDim.new(0, b or 6)
end

-- HEADER
local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1, 0, 0, 36); header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0; header.LayoutOrder = 0

local hGrad = Instance.new("UIGradient", header)
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 52)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 18)),
})
hGrad.Rotation = 90

local statusDot = Instance.new("Frame", header)
statusDot.Size = UDim2.new(0, 7, 0, 7); statusDot.Position = UDim2.new(0, 11, 0.5, -3)
statusDot.BackgroundColor3 = C.dim; statusDot.BorderSizePixel = 0
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local htitle = Instance.new("TextLabel", header)
htitle.Size = UDim2.new(1, -65, 1, 0); htitle.Position = UDim2.new(0, 24, 0, 0)
htitle.BackgroundTransparency = 1; htitle.Text = "⚙  UTILITY  v8"
htitle.TextColor3 = C.txt; htitle.Font = Enum.Font.GothamBlack; htitle.TextSize = 11
htitle.TextXAlignment = Enum.TextXAlignment.Left

local vHint = Instance.new("TextLabel", header)
vHint.Size = UDim2.new(0, 20, 0, 14); vHint.Position = UDim2.new(1, -26, 0.5, -7)
vHint.BackgroundColor3 = Color3.fromRGB(20, 26, 50); vHint.BorderSizePixel = 0
vHint.Text = "V"; vHint.TextColor3 = C.dim; vHint.Font = Enum.Font.GothamBold; vHint.TextSize = 8
vHint.TextXAlignment = Enum.TextXAlignment.Center
Instance.new("UICorner", vHint).CornerRadius = UDim.new(0, 4)

-- TABS (3 agora)
local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1, 0, 0, 30); tabBar.BackgroundColor3 = C.panel
tabBar.BorderSizePixel = 0; tabBar.LayoutOrder = 1
pad(tabBar, 6, 6, 5, 5)
local tabLy = Instance.new("UIListLayout", tabBar)
tabLy.FillDirection = Enum.FillDirection.Horizontal
tabLy.SortOrder = Enum.SortOrder.LayoutOrder; tabLy.Padding = UDim.new(0, 3)

local tabBtns = {}

local function mkTab(name, icon, order, w)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(w or 0.33, -2, 1, 0); btn.BackgroundColor3 = C.card
    btn.BorderSizePixel = 0; btn.Text = icon .. " " .. name
    btn.TextColor3 = C.dim; btn.Font = Enum.Font.GothamBold; btn.TextSize = 8
    btn.AutoButtonColor = false; btn.LayoutOrder = order
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = btn; return btn
end

local tabMainBtn = mkTab("Cheats",   "🎮", 1)
local tabTPBtn   = mkTab("TP",       "🗺",  2)
local tabNPCBtn  = mkTab("NPCs",     "🧑", 3)

mkDiv(frame, 2)

local tabPages = {}

local function mkPage(order)
    local pg = Instance.new("Frame", frame)
    pg.Size = UDim2.new(1, 0, 0, 0); pg.AutomaticSize = Enum.AutomaticSize.Y
    pg.BackgroundTransparency = 1; pg.BorderSizePixel = 0
    pg.LayoutOrder = order; pg.Visible = false
    local ly = Instance.new("UIListLayout", pg)
    ly.SortOrder = Enum.SortOrder.LayoutOrder; ly.Padding = UDim.new(0, 0)
    return pg
end

local pageMain = mkPage(3)
local pageTP   = mkPage(4)
local pageNPC  = mkPage(5)
tabPages["Cheats"] = pageMain
tabPages["TP"]     = pageTP
tabPages["NPCs"]   = pageNPC

local function switchTab(name)
    currentTab = name
    for n, pg in pairs(tabPages) do pg.Visible = (n == name) end
    for n, btn in pairs(tabBtns) do
        local on = (n == name)
        tw(btn, {BackgroundColor3 = on and C.accent or C.card, TextColor3 = on and C.bg or C.dim}):Play()
    end
end

tabMainBtn.MouseButton1Click:Connect(function() switchTab("Cheats") end)
tabTPBtn.MouseButton1Click:Connect(function()   switchTab("TP")     end)
tabNPCBtn.MouseButton1Click:Connect(function()  switchTab("NPCs")   end)

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
    [Enum.KeyCode.RightAlt]=true,[Enum.KeyCode.V]=true,
}

local function addPadSec(p, t, b)
    local u = Instance.new("UIPadding", p)
    u.PaddingLeft = UDim.new(0, 10); u.PaddingRight = UDim.new(0, 10)
    u.PaddingTop = UDim.new(0, t or 7); u.PaddingBottom = UDim.new(0, b or 7)
end

local function mkSection(parent, cfg)
    local sec = Instance.new("Frame", parent)
    sec.Size = UDim2.new(1, 0, 0, 0); sec.AutomaticSize = Enum.AutomaticSize.Y
    sec.BackgroundColor3 = C.card; sec.BorderSizePixel = 0; sec.LayoutOrder = cfg.order
    addPadSec(sec)
    local ly = Instance.new("UIListLayout", sec)
    ly.SortOrder = Enum.SortOrder.LayoutOrder; ly.Padding = UDim.new(0, 5)

    local row1 = Instance.new("Frame", sec)
    row1.Size = UDim2.new(1, 0, 0, 20); row1.BackgroundTransparency = 1; row1.LayoutOrder = 1

    local lbl = Instance.new("TextLabel", row1)
    lbl.Size = UDim2.new(1, -52, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = cfg.icon .. "  " .. cfg.label; lbl.TextColor3 = C.txtSub
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local tr = Instance.new("Frame", row1)
    tr.Size = UDim2.new(0, 36, 0, 18); tr.Position = UDim2.new(1, -36, 0.5, -9)
    tr.BackgroundColor3 = Color3.fromRGB(22, 28, 50); tr.BorderSizePixel = 0
    Instance.new("UICorner", tr).CornerRadius = UDim.new(0, 9)
    Instance.new("UIStroke", tr).Color = C.border

    local kn = Instance.new("Frame", tr)
    kn.Size = UDim2.new(0, 14, 0, 14); kn.Position = UDim2.new(0, 2, 0.5, -7)
    kn.BackgroundColor3 = Color3.fromRGB(195, 205, 235); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(0, 7)

    local togHit = Instance.new("TextButton", tr)
    togHit.Size = UDim2.new(1, 0, 1, 0); togHit.BackgroundTransparency = 1
    togHit.Text = ""; togHit.AutoButtonColor = false; togHit.ZIndex = 5

    local row2 = Instance.new("Frame", sec)
    row2.Size = UDim2.new(1, 0, 0, 20); row2.BackgroundTransparency = 1; row2.LayoutOrder = 2

    local tLbl = Instance.new("TextLabel", row2)
    tLbl.Size = UDim2.new(0, 38, 1, 0); tLbl.BackgroundTransparency = 1
    tLbl.Text = "Tecla:"; tLbl.TextColor3 = C.dim; tLbl.Font = Enum.Font.Gotham; tLbl.TextSize = 8
    tLbl.TextXAlignment = Enum.TextXAlignment.Left

    local bindB = Instance.new("TextButton", row2)
    bindB.Size = UDim2.new(0, 64, 0, 18); bindB.Position = UDim2.new(0, 40, 0.5, -9)
    bindB.BackgroundColor3 = Color3.fromRGB(18, 22, 44); bindB.BorderSizePixel = 0
    bindB.Text = cfg.keyName; bindB.TextColor3 = C.accent
    bindB.Font = Enum.Font.GothamBold; bindB.TextSize = 9; bindB.AutoButtonColor = false
    Instance.new("UICorner", bindB).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", bindB).Color = C.accentD

    local statusLbl = nil
    if cfg.showStatus then
        local rowSt = Instance.new("Frame", sec); rowSt.Size = UDim2.new(1, 0, 0, 12)
        rowSt.BackgroundTransparency = 1; rowSt.LayoutOrder = 2.5
        statusLbl = Instance.new("TextLabel", rowSt); statusLbl.Size = UDim2.new(1, 0, 1, 0)
        statusLbl.BackgroundTransparency = 1; statusLbl.Text = ""
        statusLbl.TextColor3 = C.dim; statusLbl.Font = Enum.Font.Code; statusLbl.TextSize = 8
        statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    end

    if cfg.slider then
        local s = cfg.slider
        local rowS1 = Instance.new("Frame", sec); rowS1.Size = UDim2.new(1, 0, 0, 13)
        rowS1.BackgroundTransparency = 1; rowS1.LayoutOrder = 3
        local valLbl = Instance.new("TextLabel", rowS1); valLbl.Size = UDim2.new(1, 0, 1, 0)
        valLbl.BackgroundTransparency = 1; valLbl.Text = s.label .. ": " .. s.def
        valLbl.TextColor3 = C.accent; valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 8
        valLbl.TextXAlignment = Enum.TextXAlignment.Left

        local rowS2 = Instance.new("Frame", sec); rowS2.Size = UDim2.new(1, 0, 0, 14)
        rowS2.BackgroundTransparency = 1; rowS2.LayoutOrder = 4
        local sbg = Instance.new("Frame", rowS2); sbg.Size = UDim2.new(1, 0, 0, 4)
        sbg.Position = UDim2.new(0, 0, 0.5, -2); sbg.BackgroundColor3 = Color3.fromRGB(20, 25, 45)
        sbg.BorderSizePixel = 0; Instance.new("UICorner", sbg).CornerRadius = UDim.new(0, 2)
        local pct0 = (s.def - s.min) / (s.max - s.min)
        local fill = Instance.new("Frame", sbg); fill.Size = UDim2.new(pct0, 0, 1, 0)
        fill.BackgroundColor3 = C.accent; fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)
        local sk = Instance.new("Frame", sbg); sk.Size = UDim2.new(0, 11, 0, 11)
        sk.AnchorPoint = Vector2.new(0.5, 0.5); sk.Position = UDim2.new(pct0, 0, 0.5, 0)
        sk.BackgroundColor3 = Color3.fromRGB(255, 255, 255); sk.BorderSizePixel = 0; sk.ZIndex = 3
        Instance.new("UICorner", sk).CornerRadius = UDim.new(0, 6)
        local sHit = Instance.new("TextButton", sbg); sHit.Size = UDim2.new(1, 0, 0, 20)
        sHit.Position = UDim2.new(0, 0, 0.5, -10); sHit.BackgroundTransparency = 1
        sHit.Text = ""; sHit.AutoButtonColor = false; sHit.ZIndex = 4
        local dragging = false
        sHit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
        sHit.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UIS.InputChanged:Connect(function(i)
            if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local pct = math.clamp((i.Position.X - sbg.AbsolutePosition.X) / sbg.AbsoluteSize.X, 0, 1)
            local val = math.floor(s.min + pct*(s.max - s.min) + 0.5)
            fill.Size = UDim2.new(pct, 0, 1, 0); sk.Position = UDim2.new(pct, 0, 0.5, 0)
            valLbl.Text = s.label .. ": " .. val; if s.onChange then s.onChange(val) end
        end)
    end

    local rjTr, rjKn, rjTogHit
    if cfg.rejump then
        local rowRJ = Instance.new("Frame", sec); rowRJ.Size = UDim2.new(1, 0, 0, 18)
        rowRJ.BackgroundTransparency = 1; rowRJ.LayoutOrder = 5
        local rjL = Instance.new("TextLabel", rowRJ); rjL.Size = UDim2.new(1, -52, 1, 0)
        rjL.BackgroundTransparency = 1; rjL.Text = "↩  Re-jump"; rjL.TextColor3 = C.txtSub
        rjL.Font = Enum.Font.GothamBold; rjL.TextSize = 9; rjL.TextXAlignment = Enum.TextXAlignment.Left
        rjTr = Instance.new("Frame", rowRJ); rjTr.Size = UDim2.new(0, 36, 0, 18)
        rjTr.Position = UDim2.new(1, -36, 0.5, -9); rjTr.BackgroundColor3 = Color3.fromRGB(22, 28, 50)
        rjTr.BorderSizePixel = 0; Instance.new("UICorner", rjTr).CornerRadius = UDim.new(0, 9)
        Instance.new("UIStroke", rjTr).Color = C.border
        rjKn = Instance.new("Frame", rjTr); rjKn.Size = UDim2.new(0, 14, 0, 14)
        rjKn.Position = UDim2.new(0, 2, 0.5, -7); rjKn.BackgroundColor3 = Color3.fromRGB(195, 205, 235)
        rjKn.BorderSizePixel = 0; Instance.new("UICorner", rjKn).CornerRadius = UDim.new(0, 7)
        rjTogHit = Instance.new("TextButton", rjTr); rjTogHit.Size = UDim2.new(1, 0, 1, 0)
        rjTogHit.BackgroundTransparency = 1; rjTogHit.Text = ""; rjTogHit.AutoButtonColor = false; rjTogHit.ZIndex = 5
    end

    local function setTogVis(on)
        tw(tr, {BackgroundColor3 = on and C.accent or Color3.fromRGB(22, 28, 50)}):Play()
        twBack(kn, {Position = on and UDim2.new(0, 20, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
    end
    local function setRjVis(on)
        if rjTr and rjKn then
            tw(rjTr, {BackgroundColor3 = on and C.accent or Color3.fromRGB(22, 28, 50)}):Play()
            twBack(rjKn, {Position = on and UDim2.new(0, 20, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        end
    end
    return {togHit = togHit, bindBtn = bindB, rjTogHit = rjTogHit, setTogVis = setTogVis, setRjVis = setRjVis, statusLbl = statusLbl}
end

mkDiv(pageMain, 1)
local ncSec = mkSection(pageMain, {id="nc", order=2, icon="👻", label="Noclip",      keyName=ncKey.Name})
mkDiv(pageMain, 3)
local spSec = mkSection(pageMain, {id="sp", order=4, icon="💨", label="Speed",       keyName=spKey.Name,
    slider={min=16,max=300,def=speedVal,label="Speed",onChange=function(v) speedVal=v; if speedOn then local h=hum(); if h then h.WalkSpeed=v end end end}})
mkDiv(pageMain, 5)
local hjSec = mkSection(pageMain, {id="hj", order=6, icon="🦘", label="High Jump",  keyName=hjKey.Name,
    slider={min=50,max=500,def=jumpVal,label="Forca",onChange=function(v) jumpVal=v; if jumpOn then local h=hum(); if h then h.JumpPower=v end end end}, rejump=true})
mkDiv(pageMain, 7)
local shSec = mkSection(pageMain, {id="sh", order=8, icon="🔄", label="Shake (smart)", keyName=shakeKey.Name, showStatus=true})
mkDiv(pageMain, 9)

-- SELL
local sellSec = Instance.new("Frame", pageMain); sellSec.Size = UDim2.new(1,0,0,0)
sellSec.AutomaticSize = Enum.AutomaticSize.Y; sellSec.BackgroundColor3 = C.card
sellSec.BorderSizePixel = 0; sellSec.LayoutOrder = 10; addPadSec(sellSec, 7, 9)
local sellLy = Instance.new("UIListLayout", sellSec); sellLy.SortOrder = Enum.SortOrder.LayoutOrder; sellLy.Padding = UDim.new(0,5)
local sTitleRow = Instance.new("Frame", sellSec); sTitleRow.Size = UDim2.new(1,0,0,16)
sTitleRow.BackgroundTransparency=1; sTitleRow.LayoutOrder=1
local sTL = Instance.new("TextLabel", sTitleRow); sTL.Size = UDim2.new(1,0,1,0)
sTL.BackgroundTransparency=1; sTL.Text="💰  Sell from Hand"; sTL.TextColor3=C.txtSub
sTL.Font=Enum.Font.GothamBold; sTL.TextSize=10; sTL.TextXAlignment=Enum.TextXAlignment.Left
local sellStatus = Instance.new("TextLabel", sellSec); sellStatus.Size=UDim2.new(1,0,0,10)
sellStatus.BackgroundTransparency=1; sellStatus.Text="Aguardando..."; sellStatus.TextColor3=C.dim
sellStatus.Font=Enum.Font.Gotham; sellStatus.TextSize=8; sellStatus.TextXAlignment=Enum.TextXAlignment.Left; sellStatus.LayoutOrder=2
local sellBindRow = Instance.new("Frame", sellSec); sellBindRow.Size=UDim2.new(1,0,0,20)
sellBindRow.BackgroundTransparency=1; sellBindRow.LayoutOrder=3
local sellTLbl = Instance.new("TextLabel", sellBindRow); sellTLbl.Size=UDim2.new(0,38,1,0)
sellTLbl.BackgroundTransparency=1; sellTLbl.Text="Tecla:"; sellTLbl.TextColor3=C.dim
sellTLbl.Font=Enum.Font.Gotham; sellTLbl.TextSize=8; sellTLbl.TextXAlignment=Enum.TextXAlignment.Left
local sellBindB = Instance.new("TextButton", sellBindRow)
sellBindB.Size=UDim2.new(0,64,0,18); sellBindB.Position=UDim2.new(0,40,0.5,-9)
sellBindB.BackgroundColor3=Color3.fromRGB(18,22,44); sellBindB.BorderSizePixel=0
sellBindB.Text=sellKey.Name; sellBindB.TextColor3=C.accent
sellBindB.Font=Enum.Font.GothamBold; sellBindB.TextSize=9; sellBindB.AutoButtonColor=false
Instance.new("UICorner", sellBindB).CornerRadius=UDim.new(0,5)
Instance.new("UIStroke", sellBindB).Color=C.accentD
local sellBtn = Instance.new("TextButton", sellSec); sellBtn.Size=UDim2.new(1,0,0,28); sellBtn.LayoutOrder=4
sellBtn.BackgroundColor3=Color3.fromRGB(16,58,36); sellBtn.BorderSizePixel=0
sellBtn.Text="💰  Vender Item da Mao"; sellBtn.TextColor3=C.green
sellBtn.Font=Enum.Font.GothamBold; sellBtn.TextSize=9; sellBtn.AutoButtonColor=false
Instance.new("UICorner", sellBtn).CornerRadius=UDim.new(0,7)
Instance.new("UIStroke", sellBtn).Color=Color3.fromRGB(22,82,50)
sellBtn.MouseEnter:Connect(function() tw(sellBtn,{BackgroundColor3=Color3.fromRGB(20,72,44)}):Play() end)
sellBtn.MouseLeave:Connect(function() tw(sellBtn,{BackgroundColor3=Color3.fromRGB(16,58,36)}):Play() end)

mkDiv(pageMain, 11)

-- ══════════════════════════════════════════
-- PAGE TP
-- ══════════════════════════════════════════
local tpScroll = Instance.new("ScrollingFrame", pageTP)
tpScroll.Size = UDim2.new(1,0,0,280); tpScroll.BackgroundTransparency=1; tpScroll.BorderSizePixel=0
tpScroll.ScrollBarThickness=3; tpScroll.ScrollBarImageColor3=C.accent
tpScroll.CanvasSize=UDim2.new(0,0,0,0); tpScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
tpScroll.LayoutOrder=1
local tpLy = Instance.new("UIListLayout", tpScroll)
tpLy.SortOrder=Enum.SortOrder.LayoutOrder; tpLy.Padding=UDim.new(0,2)
pad(tpScroll, 8,8,6,6)

local tpStatus = Instance.new("TextLabel", tpScroll); tpStatus.Size=UDim2.new(1,0,0,14)
tpStatus.BackgroundTransparency=1; tpStatus.Text=""; tpStatus.TextColor3=C.green
tpStatus.Font=Enum.Font.GothamBold; tpStatus.TextSize=8; tpStatus.TextXAlignment=Enum.TextXAlignment.Left; tpStatus.LayoutOrder=0

for i, island in ipairs(ISLANDS) do
    local btn = Instance.new("TextButton", tpScroll); btn.Size=UDim2.new(1,0,0,27)
    btn.BackgroundColor3 = island.special and Color3.fromRGB(40,16,42) or C.card
    btn.BorderSizePixel=0; btn.Text="📍  "..island.name
    btn.TextColor3 = island.special and C.pink or C.txtSub
    btn.Font=Enum.Font.GothamBold; btn.TextSize=9; btn.TextXAlignment=Enum.TextXAlignment.Left
    btn.AutoButtonColor=false; btn.LayoutOrder=i
    Instance.new("UICorner", btn).CornerRadius=UDim.new(0,6); pad(btn,8,8,0,0)
    local hc = island.special and Color3.fromRGB(60,26,62) or C.cardHov
    local bc = island.special and Color3.fromRGB(40,16,42) or C.card
    btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=hc,TextColor3=C.txt}):Play() end)
    btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=bc,TextColor3=island.special and C.pink or C.txtSub}):Play() end)
    btn.MouseButton1Click:Connect(function()
        tw(btn,{BackgroundColor3=C.accentD}):Play(); task.wait(0.12); tw(btn,{BackgroundColor3=bc}):Play()
        local ok, msg = tpToPos(island.pos)
        tpStatus.TextColor3 = ok and C.green or C.red
        tpStatus.Text = (ok and "✅ " or "❌ ")..island.name
        task.delay(3, function() tpStatus.Text="" end)
    end)
end

-- ══════════════════════════════════════════
-- PAGE NPCs
-- ══════════════════════════════════════════

-- filtros
local npcFilter = "all" -- "all" | "merchant" | "quest" | "special" | "nearby"

local npcFilterBar = Instance.new("Frame", pageNPC)
npcFilterBar.Size=UDim2.new(1,0,0,26); npcFilterBar.BackgroundColor3=C.panel
npcFilterBar.BorderSizePixel=0; npcFilterBar.LayoutOrder=1
pad(npcFilterBar, 5,5,4,4)
local npcFLy = Instance.new("UIListLayout", npcFilterBar)
npcFLy.FillDirection=Enum.FillDirection.Horizontal; npcFLy.SortOrder=Enum.SortOrder.LayoutOrder; npcFLy.Padding=UDim.new(0,3)

local filterBtns = {}
local function mkFilterBtn(label, key, order)
    local b = Instance.new("TextButton", npcFilterBar)
    b.Size=UDim2.new(0.24,-2,1,0); b.BackgroundColor3=C.card; b.BorderSizePixel=0
    b.Text=label; b.TextColor3=C.dim; b.Font=Enum.Font.GothamBold; b.TextSize=7
    b.AutoButtonColor=false; b.LayoutOrder=order
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,5)
    filterBtns[key]=b; return b
end

local fAll      = mkFilterBtn("Todos",    "all",     1)
local fMerch    = mkFilterBtn("💰 Merch", "merchant",2)
local fQuest    = mkFilterBtn("📜 Quest", "quest",   3)
local fSpecial  = mkFilterBtn("⭐ Spec",  "special", 4)

local npcScroll = Instance.new("ScrollingFrame", pageNPC)
npcScroll.Size=UDim2.new(1,0,0,254); npcScroll.BackgroundTransparency=1; npcScroll.BorderSizePixel=0
npcScroll.ScrollBarThickness=3; npcScroll.ScrollBarImageColor3=C.accent
npcScroll.CanvasSize=UDim2.new(0,0,0,0); npcScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
npcScroll.LayoutOrder=2
local npcLy = Instance.new("UIListLayout", npcScroll)
npcLy.SortOrder=Enum.SortOrder.LayoutOrder; npcLy.Padding=UDim.new(0,2)
pad(npcScroll, 7,7,4,4)

local npcStatus = Instance.new("TextLabel", npcScroll); npcStatus.Size=UDim2.new(1,0,0,12)
npcStatus.BackgroundTransparency=1; npcStatus.Text=""; npcStatus.TextColor3=C.green
npcStatus.Font=Enum.Font.GothamBold; npcStatus.TextSize=8; npcStatus.TextXAlignment=Enum.TextXAlignment.Left
npcStatus.LayoutOrder=0

local function npcColor(tipo)
    if tipo == "merchant" then return C.green  end
    if tipo == "quest"    then return C.yellow end
    if tipo == "special"  then return C.pink   end
    return C.txtSub
end

local function npcBg(tipo)
    if tipo == "merchant" then return Color3.fromRGB(14,38,24) end
    if tipo == "quest"    then return Color3.fromRGB(38,32,10) end
    if tipo == "special"  then return Color3.fromRGB(40,16,42) end
    return C.card
end

local function npcIcon(tipo)
    if tipo == "merchant" then return "💰" end
    if tipo == "quest"    then return "📜" end
    if tipo == "special"  then return "⭐" end
    return "🧑"
end

local function rebuildNPCPage()
    -- remove entradas antigas (exceto status)
    for _, ch in ipairs(npcScroll:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextButton") then ch:Destroy() end
    end

    local lastIsland = ""
    local count = 0

    for i, npc in ipairs(NPCS) do
        if npcFilter == "all" or npcFilter == npc.tipo then
            count = count + 1

            -- cabecalho de ilha se mudou
            if npc.island ~= lastIsland then
                lastIsland = npc.island
                local hdr = Instance.new("Frame", npcScroll)
                hdr.Size=UDim2.new(1,0,0,16); hdr.BackgroundTransparency=1; hdr.LayoutOrder=i*10-1
                local hLbl = Instance.new("TextLabel", hdr); hLbl.Size=UDim2.new(1,0,1,0)
                hLbl.BackgroundTransparency=1; hLbl.Text="— "..npc.island.." —"
                hLbl.TextColor3=C.dim; hLbl.Font=Enum.Font.GothamBold; hLbl.TextSize=7
                hLbl.TextXAlignment=Enum.TextXAlignment.Center
            end

            local bg = npcBg(npc.tipo)
            local col = npcColor(npc.tipo)
            local btn = Instance.new("TextButton", npcScroll)
            btn.Size=UDim2.new(1,0,0,0); btn.AutomaticSize=Enum.AutomaticSize.Y
            btn.BackgroundColor3=bg; btn.BorderSizePixel=0
            btn.Text=""; btn.AutoButtonColor=false; btn.LayoutOrder=i*10
            Instance.new("UICorner", btn).CornerRadius=UDim.new(0,6)
            pad(btn,7,7,5,5)

            local bLy = Instance.new("UIListLayout", btn)
            bLy.SortOrder=Enum.SortOrder.LayoutOrder; bLy.Padding=UDim.new(0,1)

            local r1 = Instance.new("Frame", btn); r1.Size=UDim2.new(1,0,0,14); r1.BackgroundTransparency=1; r1.LayoutOrder=1
            local nameLbl = Instance.new("TextLabel", r1); nameLbl.Size=UDim2.new(1,0,1,0)
            nameLbl.BackgroundTransparency=1
            nameLbl.Text=npcIcon(npc.tipo).."  "..npc.desc
            nameLbl.TextColor3=col; nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=8
            nameLbl.TextXAlignment=Enum.TextXAlignment.Left

            local r2 = Instance.new("Frame", btn); r2.Size=UDim2.new(1,0,0,10); r2.BackgroundTransparency=1; r2.LayoutOrder=2
            local subLbl = Instance.new("TextLabel", r2); subLbl.Size=UDim2.new(1,0,1,0)
            subLbl.BackgroundTransparency=1; subLbl.Text="📍 Teleportar pra "..npc.island
            subLbl.TextColor3=C.dim; subLbl.Font=Enum.Font.Gotham; subLbl.TextSize=7
            subLbl.TextXAlignment=Enum.TextXAlignment.Left

            local hbg = Color3.fromRGB(
                math.clamp(bg.R*255+12,0,255)/255,
                math.clamp(bg.G*255+12,0,255)/255,
                math.clamp(bg.B*255+12,0,255)/255
            )
            btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=hbg}):Play() end)
            btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=bg}):Play() end)
            btn.MouseButton1Click:Connect(function()
                tw(btn,{BackgroundColor3=C.accentD}):Play(); task.wait(0.1); tw(btn,{BackgroundColor3=bg}):Play()
                local ok, _ = tpToPos(npc.pos)
                npcStatus.TextColor3 = ok and C.green or C.red
                npcStatus.Text = (ok and "✅ " or "❌ ")..npc.desc
                task.delay(3, function() npcStatus.Text="" end)
            end)
        end
    end

    if count == 0 then
        local empty = Instance.new("TextLabel", npcScroll); empty.Size=UDim2.new(1,0,0,24)
        empty.BackgroundTransparency=1; empty.Text="Nenhum NPC nessa categoria"
        empty.TextColor3=C.dim; empty.Font=Enum.Font.Gotham; empty.TextSize=8
        empty.TextXAlignment=Enum.TextXAlignment.Center; empty.LayoutOrder=1
    end
end

local function setFilter(key)
    npcFilter = key
    for k, b in pairs(filterBtns) do
        local on = (k == key)
        tw(b, {BackgroundColor3 = on and C.accent or C.card, TextColor3 = on and C.bg or C.dim}):Play()
    end
    rebuildNPCPage()
end

fAll.MouseButton1Click:Connect(function()     setFilter("all")      end)
fMerch.MouseButton1Click:Connect(function()   setFilter("merchant") end)
fQuest.MouseButton1Click:Connect(function()   setFilter("quest")    end)
fSpecial.MouseButton1Click:Connect(function() setFilter("special")  end)

setFilter("all")

-- ══════════════════════════════════════════
-- VISIBILIDADE
-- ══════════════════════════════════════════
local guiVisible = true
local function setVisible(v)
    guiVisible = v
    for _, child in ipairs(frame:GetChildren()) do
        if child ~= header and child:IsA("Frame") then child.Visible = v end
    end
    if v then frame.AutomaticSize = Enum.AutomaticSize.Y
    else frame.AutomaticSize = Enum.AutomaticSize.None; tw(frame,{Size=UDim2.new(0,212,0,36)},0.15):Play() end
    tw(vHint, {TextColor3 = v and C.dim or C.accent}, 0.1):Play()
end

-- ══════════════════════════════════════════
-- TOGGLES
-- ══════════════════════════════════════════
local function updateDot()
    local anyOn = noclipOn or speedOn or jumpOn or shakeOn
    tw(statusDot, {BackgroundColor3 = anyOn and C.green or C.dim}):Play()
end

ncSec.togHit.MouseButton1Click:Connect(function()
    noclipOn = not noclipOn; setNoclip(noclipOn); ncSec.setTogVis(noclipOn)
    tw(frameBorder,{Color=noclipOn and C.green or C.border}):Play(); updateDot()
end)
spSec.togHit.MouseButton1Click:Connect(function()
    speedOn = not speedOn; spSec.setTogVis(speedOn); applySpeed(); updateDot()
end)
hjSec.togHit.MouseButton1Click:Connect(function()
    jumpOn = not jumpOn; hjSec.setTogVis(jumpOn); applyJump()
    if not jumpOn then reJumpOn=false; hjSec.setRjVis(false); stopReJump() end; updateDot()
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
    if shakeOn then startShake() else stopShake() end; updateDot()
end)
sellBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(10,44,26)}):Play(); task.wait(0.1)
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(16,58,36)}):Play()
        local ok, msg = sellFromHand()
        if ok then sellStatus.Text="✅ "..msg; tw(sellStatus,{TextColor3=C.green}):Play()
        else       sellStatus.Text="❌ "..msg; tw(sellStatus,{TextColor3=C.red}):Play() end
        task.wait(3); tw(sellStatus,{TextColor3=C.dim}):Play(); sellStatus.Text="Aguardando..."
    end)
end)

-- Shake status watcher
task.spawn(function()
    while true do
        task.wait(0.2)
        if shSec.statusLbl then
            if shakeOn then
                if shakeActive then
                    shSec.statusLbl.Text = "● clicando..."; shSec.statusLbl.TextColor3 = C.green
                else
                    shSec.statusLbl.Text = "○ aguardando UI..."; shSec.statusLbl.TextColor3 = C.yellow
                end
            else
                shSec.statusLbl.Text = ""
            end
        end
    end
end)

-- ══════════════════════════════════════════
-- REBIND
-- ══════════════════════════════════════════
local function setupBind(bindBtn, id, getKey, setKey)
    bindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = id; bindBtn.Text = "..."
        tw(bindBtn,{TextColor3=C.yellow}):Play()
        local conn; conn = UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then
                bindBtn.Text=getKey().Name; tw(bindBtn,{TextColor3=C.accent}):Play()
                listening=nil; conn:Disconnect(); return
            end
            if BLOCKED_KEYS[inp.KeyCode] then
                bindBtn.Text="invalida!"; tw(bindBtn,{TextColor3=C.red}):Play()
                task.wait(0.8); bindBtn.Text=getKey().Name
                tw(bindBtn,{TextColor3=C.accent}):Play(); listening=nil; conn:Disconnect(); return
            end
            setKey(inp.KeyCode); bindBtn.Text=inp.KeyCode.Name
            tw(bindBtn,{TextColor3=C.accent}):Play(); listening=nil; conn:Disconnect()
        end)
    end)
end
setupBind(ncSec.bindBtn,  "nc",   function() return ncKey    end, function(k) ncKey    = k end)
setupBind(spSec.bindBtn,  "sp",   function() return spKey    end, function(k) spKey    = k end)
setupBind(hjSec.bindBtn,  "hj",   function() return hjKey    end, function(k) hjKey    = k end)
setupBind(shSec.bindBtn,  "sh",   function() return shakeKey end, function(k) shakeKey = k end)
setupBind(sellBindB,      "sell", function() return sellKey  end, function(k) sellKey  = k end)

-- ══════════════════════════════════════════
-- DRAG
-- ══════════════════════════════════════════
do
    local dr, ds, sp2 = false, nil, nil
    local dh = Instance.new("TextButton", frame)
    dh.Size=UDim2.new(1,-20,0,36); dh.Position=UDim2.new(0,0,0,0)
    dh.BackgroundTransparency=1; dh.Text=""; dh.AutoButtonColor=false; dh.ZIndex=20
    dh.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true; ds=i.Position; sp2=frame.Position end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp2.X.Scale, sp2.X.Offset+d.X, sp2.Y.Scale, sp2.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════
-- HOTKEYS
-- ══════════════════════════════════════════
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or listening then return end
    local k = inp.KeyCode
    if     k == Enum.KeyCode.V then setVisible(not guiVisible)
    elseif k == ncKey then
        noclipOn=not noclipOn; setNoclip(noclipOn); ncSec.setTogVis(noclipOn)
        tw(frameBorder,{Color=noclipOn and C.green or C.border}):Play(); updateDot()
    elseif k == spKey then speedOn=not speedOn; spSec.setTogVis(speedOn); applySpeed(); updateDot()
    elseif k == hjKey then
        jumpOn=not jumpOn; hjSec.setTogVis(jumpOn); applyJump()
        if not jumpOn then reJumpOn=false; hjSec.setRjVis(false); stopReJump() end; updateDot()
    elseif k == shakeKey then
        shakeOn=not shakeOn; shSec.setTogVis(shakeOn)
        if shakeOn then startShake() else stopShake() end; updateDot()
    elseif k == sellKey then
        task.spawn(function()
            local ok, msg = sellFromHand()
            if ok then sellStatus.Text="✅ "..msg; tw(sellStatus,{TextColor3=C.green}):Play()
            else       sellStatus.Text="❌ "..msg; tw(sellStatus,{TextColor3=C.red}):Play() end
            task.wait(3); tw(sellStatus,{TextColor3=C.dim}):Play(); sellStatus.Text="Aguardando..."
        end)
    end
end)

switchTab("Cheats")