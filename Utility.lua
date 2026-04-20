--[[
    UTILITY v16 — Fisch 2026
    
    v16: AUTO-REEL ADAPTATIVO (aprende com erros)
    ══════════════════════════════════════════════
    
    O sistema monitora cada partida de pesca:
    
    DETECTA O RESULTADO via:
      • Desaparecimento da reelui = fim do minigame
      • Aparecimento de notificação/reward gui = SUCESSO
      • Timeout sem reward = FALHOU (perdeu o peixe)
    
    DIAGNÓSTICO DO ERRO:
      • Se a barra ficou muito tempo longe do peixe → "estava lento"
        → Aumenta hold_far e reduz release_far
      • Se overshooting frequente (barra passou do peixe) → "estava rápido demais"
        → Reduz hold_far, aumenta release_inside
      • Se oscilando sem estabilizar no estado DENTRO → "muito jitter"
        → Aumenta hold_inside levemente
      • Se perdeu com barra perto mas não capturou → "timing médio ruim"
        → Ajusta state CHEGANDO
    
    MEMÓRIA:
      • Guarda histórico das últimas 20 partidas
      • Score de confiança: % de sucessos nas últimas 10
      • Mostra na GUI: "Score: 8/10 ↑" ou "Score: 4/10 ↓"
      • Reseta aprendizado se o usuário quiser (botão Reset)
    
    LIMITES DE SEGURANÇA:
      • Timings nunca saem dos ranges seguros (não fica roboticamente rápido)
      • Jitter base mantido mesmo após aprendizado
      • Máx de ajuste por partida: ±8ms (gradual, não abrupto)
]]

local Players   = game:GetService("Players")
local RunSvc    = game:GetService("RunService")
local UIS       = game:GetService("UserInputService")
local TweenSvc  = game:GetService("TweenService")
local RS        = game:GetService("ReplicatedStorage")
local VIM       = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local noclipOn    = false; local noclipConn  = nil; local ncKey    = Enum.KeyCode.F
local speedOn     = false; local speedVal    = 45;  local spKey    = Enum.KeyCode.G; local speedConn = nil
local jumpOn      = false; local jumpVal     = 80;  local hjKey    = Enum.KeyCode.H; local jumpConn  = nil
local reJumpOn    = false; local reJumpConn  = nil
local shakeOn     = false; local shakeThread = nil; local shakeKey = Enum.KeyCode.J
local shakeActive = false
local sellKey     = Enum.KeyCode.K
local autoSellOn  = false; local autoSellThread = nil; local autoSellDelay = 1.5
local autoReelOn  = false; local autoReelThread = nil; local reelKey = Enum.KeyCode.L
local reelActive  = false
local npcRange    = 150
local listening   = nil
local currentTab  = "Cheats"
local guiVisible  = true
local vDebounce   = false

-- ═══════════════════════════════════════
-- 🧠 SISTEMA DE APRENDIZADO
-- ═══════════════════════════════════════

-- Timings base (em segundos) — todos com jitter aplicado em cima
local ReelParams = {
    -- Estado LONGE (>30% fora): hold longo
    hold_far     = 0.200,  -- range seguro: 0.120 ~ 0.280
    release_far  = 0.025,  -- range seguro: 0.010 ~ 0.060

    -- Estado CHEGANDO (10-30% fora): pulsos médios
    hold_mid     = 0.095,  -- range seguro: 0.055 ~ 0.150
    release_mid  = 0.040,  -- range seguro: 0.020 ~ 0.075

    -- Estado DENTRO (<10%): pulsinhos curtos
    hold_inside    = 0.042, -- range seguro: 0.025 ~ 0.080
    release_inside = 0.055, -- range seguro: 0.030 ~ 0.100
}

-- Histórico de aprendizado
local LearnHistory = {
    sessions      = {},   -- lista de {won, diagnosis, timestamp}
    totalWins     = 0,
    totalLosses   = 0,
    lastDiagnosis = "—",
    adjustCount   = 0,    -- quantas vezes ajustou
}

-- Diagnóstico em tempo real de uma partida
local SessionDiag = {
    timesFar        = 0,   -- frames em estado LONGE
    timesOvershoots = 0,   -- vezes que a barra ultrapassou o peixe
    timesInside     = 0,   -- frames em estado DENTRO
    timesMid        = 0,   -- frames em estado CHEGANDO
    duration        = 0,   -- duração total da partida (tick)
    startTime       = 0,
}

local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function rnd(a, b) return a + math.random() * (b - a) end

-- Aplica aprendizado com base no diagnóstico
local function applyLearning(won, diag)
    local STEP = 0.007 -- ajuste máximo por partida (7ms)
    local msg = ""

    if not won then
        -- Analisa por que perdeu
        local total = math.max(diag.timesFar + diag.timesMid + diag.timesInside, 1)
        local pctFar = diag.timesFar / total
        local pctOvr = diag.timesOvershoots / math.max(diag.timesInside + diag.timesMid, 1)

        if pctFar > 0.5 then
            -- Passou mais de 50% do tempo longe → estava lento
            ReelParams.hold_far    = clamp(ReelParams.hold_far    + STEP, 0.120, 0.280)
            ReelParams.release_far = clamp(ReelParams.release_far - STEP*0.5, 0.010, 0.060)
            msg = "lento → aumentei força"

        elseif pctOvr > 0.3 then
            -- Overshooting frequente → estava rápido demais
            ReelParams.hold_far    = clamp(ReelParams.hold_far    - STEP, 0.120, 0.280)
            ReelParams.hold_mid    = clamp(ReelParams.hold_mid    - STEP*0.7, 0.055, 0.150)
            ReelParams.release_inside = clamp(ReelParams.release_inside + STEP, 0.030, 0.100)
            msg = "rápido demais → reduzi força"

        elseif diag.timesInside > 0 and pctOvr < 0.1 then
            -- Estava dentro mas não capturou → timing médio
            ReelParams.hold_mid    = clamp(ReelParams.hold_mid    + STEP*0.5, 0.055, 0.150)
            ReelParams.release_mid = clamp(ReelParams.release_mid - STEP*0.3, 0.020, 0.075)
            msg = "timing médio ajustado"

        else
            -- Erro genérico — pequeno ajuste no hold_inside
            ReelParams.hold_inside = clamp(ReelParams.hold_inside + STEP*0.4, 0.025, 0.080)
            msg = "ajuste geral leve"
        end

        LearnHistory.totalLosses = LearnHistory.totalLosses + 1
    else
        -- Ganhou → pequena consolidação (reduz um pouco o overshooting pra ficar mais suave)
        if diag.timesOvershoots > 2 then
            ReelParams.hold_far = clamp(ReelParams.hold_far - STEP * 0.3, 0.120, 0.280)
            msg = "ganhou com overshoot → refinando"
        else
            msg = "perfeito ✓"
        end
        LearnHistory.totalWins = LearnHistory.totalWins + 1
    end

    LearnHistory.adjustCount = LearnHistory.adjustCount + 1
    LearnHistory.lastDiagnosis = (won and "✅ " or "❌ ") .. msg

    -- Guarda no histórico (máx 20)
    table.insert(LearnHistory.sessions, 1, {
        won = won, msg = msg, time = tick()
    })
    if #LearnHistory.sessions > 20 then
        table.remove(LearnHistory.sessions)
    end
end

-- Retorna score das últimas N partidas
local function getRecentScore(n)
    n = n or 10
    local wins, total = 0, 0
    for i = 1, math.min(n, #LearnHistory.sessions) do
        total = total + 1
        if LearnHistory.sessions[i].won then wins = wins + 1 end
    end
    return wins, total
end

-- ═══════════════════════════════════════
-- ILHAS
-- ═══════════════════════════════════════
local ISLANDS = {
    {name="Moosewood",             pos=Vector3.new(350,135,250),     cat="first"},
    {name="Roslit Bay",            pos=Vector3.new(-1600,130,500),   cat="first"},
    {name="Forsaken Shore",        pos=Vector3.new(-2750,130,1450),  cat="first"},
    {name="Mushgrove Swamp",       pos=Vector3.new(2420,135,-750),   cat="first"},
    {name="Snowcap Island",        pos=Vector3.new(2625,135,2370),   cat="first"},
    {name="Sunstone Island",       pos=Vector3.new(-870,135,-1100),  cat="first"},
    {name="Statue of Sovereignty", pos=Vector3.new(35,135,-1010),    cat="first"},
    {name="Terrapin Island",       pos=Vector3.new(-95,130,1875),    cat="first"},
    {name="Harvesters Spike",      pos=Vector3.new(-1260,135,1550),  cat="first"},
    {name="The Arch",              pos=Vector3.new(1100,130,-1250),  cat="first"},
    {name="Birch Cay",             pos=Vector3.new(1650,130,-2350),  cat="first"},
    {name="Haddock Rock",          pos=Vector3.new(-500,125,-505),   cat="first"},
    {name="Earmark Island",        pos=Vector3.new(1200,130,530),    cat="first"},
    {name="Desolate Deep",         pos=Vector3.new(-800,130,-3100),  cat="first"},
    {name="Ancient Isle",          pos=Vector3.new(6000,200,300),    cat="first"},
    {name="Grand Reef",            pos=Vector3.new(-3555,150,510),   cat="first"},
    {name="Castaway Cliffs",       pos=Vector3.new(-1800,135,-350),  cat="first"},
    {name="Lost Jungle",           pos=Vector3.new(2150,135,1850),   cat="first"},
    {name="Cursed Isle",           pos=Vector3.new(3520,130,-1640),  cat="first"},
    {name="Treasure Island",       pos=Vector3.new(4180,135,-2470),  cat="first"},
    {name="Roslit Volcano",        pos=Vector3.new(-1900,165,315),   cat="first"},
    {name="★ Waveborne",           pos=Vector3.new(10700,140,-8400), cat="second"},
    {name="★ Pine Shoals",         pos=Vector3.new(11850,135,-8000), cat="second"},
    {name="★ Emberreach",          pos=Vector3.new(2390,83,-490),    cat="second"},
    {name="★ Lushgrove",           pos=Vector3.new(1133,105,-560),   cat="second"},
    {name="★ Azure Lagoon",        pos=Vector3.new(3460,130,-1275),  cat="second"},
    {name="★ Cursed Shores",       pos=Vector3.new(-500,135,-3800),  cat="second"},
    {name="⭐ N. Expedition Portal",pos=Vector3.new(-1750,130,3750), cat="deep"},
    {name="⭐ Northern Summit",    pos=Vector3.new(19500,135,5300),  cat="deep"},
    {name="⭐ Atlantis Central",   pos=Vector3.new(-4270,-600,1830), cat="deep"},
    {name="⭐ The Depths",         pos=Vector3.new(1060,-635,1315),  cat="deep"},
    {name="⭐ Mariana's Veil",     pos=Vector3.new(-1500,125,530),   cat="deep"},
    {name="⭐ Cultist Lair",       pos=Vector3.new(4450,-2000,-4675),cat="deep"},
    {name="⭐ The Laboratory",     pos=Vector3.new(-4640,290,2080),  cat="deep"},
    {name="⭐ Vertigo",            pos=Vector3.new(1230,-490,600),   cat="deep"},
}

local RODS = {
    {name="Starter Rod",       loc="Moosewood • grátis",        pos=Vector3.new(465,150,230)},
    {name="Lucky Rod",         loc="Moosewood Merchant $500",   pos=Vector3.new(465,150,230)},
    {name="Long Rod",          loc="Moosewood Merchant $1.5k",  pos=Vector3.new(465,150,230)},
    {name="Fortune Rod",       loc="Roslit Blacksmith $1.5k",   pos=Vector3.new(-1515,140,760)},
    {name="Rapid Rod",         loc="Roslit Blacksmith $6k",     pos=Vector3.new(-1515,140,760)},
    {name="Steady Rod",        loc="Roslit Blacksmith $12.5k",  pos=Vector3.new(-1515,140,760)},
    {name="Magma Rod",         loc="Roslit Orc (Pufferfish)",   pos=Vector3.new(-1850,165,160)},
    {name="Enchanted Rod",     loc="Sunstone Merlin $35k",      pos=Vector3.new(-930,225,-990)},
    {name="Magnet Rod",        loc="Terrapin Shop $15k",        pos=Vector3.new(-195,130,1930)},
    {name="Fungal Rod",        loc="Mushgrove Agaric (quest)",  pos=Vector3.new(2790,140,-630)},
    {name="Kings Rod",         loc="Keepers Altar (end-game)",  pos=Vector3.new(1375,-805,-300)},
    {name="Destiny Rod",       loc="The Arch Caleia $190k",     pos=Vector3.new(980,130,-1230)},
    {name="Stone Rod",         loc="Ancient Isle $225k",        pos=Vector3.new(5500,145,-315)},
    {name="Phoenix Rod",       loc="Ancient Eclipse cave",      pos=Vector3.new(5950,270,890)},
    {name="Relic Rod",         loc="Archeological Site",        pos=Vector3.new(4040,135,80)},
    {name="Arctic Rod",        loc="N. Summit $25k",            pos=Vector3.new(19500,135,5300)},
    {name="Avalanche Rod",     loc="N. Frigid Cavern $35k",     pos=Vector3.new(20300,415,5640)},
    {name="Summit Rod",        loc="N. Cryogenic $300k",        pos=Vector3.new(20000,780,5700)},
    {name="Heaven's Rod",      loc="N. Glacial Grotto $1.75M",  pos=Vector3.new(20000,1040,5700)},
    {name="Champions Rod",     loc="Atlantis $80k",             pos=Vector3.new(-4450,-600,1875)},
    {name="Depthseeker Rod",   loc="Atlantis $40k",             pos=Vector3.new(-4450,-600,1875)},
    {name="Zeus Rod",          loc="Atlantis Zeus Room $1.7M",  pos=Vector3.new(-4300,-630,2680)},
    {name="Tempest Rod",       loc="Atlantis Sunken Trial",     pos=Vector3.new(-4620,-590,1840)},
    {name="Abyssal Specter",   loc="Atlantis Ethereal $1M",     pos=Vector3.new(-3915,-650,1830)},
    {name="Trident Rod",       loc="Desolate Deep Brine",       pos=Vector3.new(-800,130,-3100)},
    {name="Rod of the Depths", loc="The Depths altars",         pos=Vector3.new(1060,-635,1315)},
    {name="Sunken Rod",        loc="Treasure chest reward",     pos=Vector3.new(-2825,215,1515)},
    {name="Carrot Rod",        loc="Lushgrove Carrot Garden 75k",pos=Vector3.new(1310,130,-945)},
    {name="Midas Rod",         loc="Emberreach $500k",          pos=Vector3.new(2390,83,-490)},
    {name="Inferno Rod",       loc="Emberreach Volcano",        pos=Vector3.new(2390,150,-490)},
    {name="Leviathan Rod",     loc="Cultist Lair end-quest",    pos=Vector3.new(4450,-2000,-4675)},
}

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════
local function chr()  return LP.Character end
local function hum()  local c=chr(); return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp()  local c=chr(); return c and c:FindFirstChild("HumanoidRootPart") end
local function tool() local c=chr(); return c and c:FindFirstChildOfClass("Tool") end

-- ═══════════════════════════════════════
-- NOCLIP / SPEED / JUMP
-- ═══════════════════════════════════════
local function setNoclip(v)
    noclipOn=v
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    if v then
        noclipConn=RunSvc.Stepped:Connect(function()
            local c=chr(); if not c then return end
            for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
        end)
    else
        local c=chr()
        if c then for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.CanCollide=true end
        end end
    end
end
local function applySpeedOnce() local h=hum(); if h then h.WalkSpeed=speedOn and speedVal or 16 end end
local function startSpeedLoop()
    if speedConn then speedConn:Disconnect(); speedConn=nil end
    speedConn=RunSvc.Heartbeat:Connect(function()
        if not speedOn then speedConn:Disconnect(); speedConn=nil; return end
        local h=hum(); if h and h.WalkSpeed~=speedVal then h.WalkSpeed=speedVal end
    end)
end
local function stopSpeedLoop() if speedConn then speedConn:Disconnect(); speedConn=nil end; local h=hum(); if h then h.WalkSpeed=16 end end
local function startJumpLoop()
    if jumpConn then jumpConn:Disconnect(); jumpConn=nil end
    jumpConn=RunSvc.Heartbeat:Connect(function()
        if not jumpOn then jumpConn:Disconnect(); jumpConn=nil; return end
        local h=hum(); if h then h.UseJumpPower=true; if h.JumpPower~=jumpVal then h.JumpPower=jumpVal end end
    end)
end
local function stopJumpLoop() if jumpConn then jumpConn:Disconnect(); jumpConn=nil end; local h=hum(); if h then h.JumpPower=50 end end
local function startReJump()
    if reJumpConn then reJumpConn:Disconnect(); reJumpConn=nil end
    reJumpConn=RunSvc.Heartbeat:Connect(function()
        if not reJumpOn or not jumpOn then reJumpConn:Disconnect(); reJumpConn=nil; return end
        local h=hum(); if h and h.FloorMaterial~=Enum.Material.Air then h:ChangeState(Enum.HumanoidStateType.Jumping); task.wait(0.15) end
    end)
end
local function stopReJump() if reJumpConn then reJumpConn:Disconnect(); reJumpConn=nil end end

-- ═══════════════════════════════════════
-- SHAKE
-- ═══════════════════════════════════════
local function shakeUiVisible()
    local sui=PG:FindFirstChild("shakeui")
    return sui and sui.Enabled~=false
end
local function pressEnter()
    pcall(function() VIM:SendKeyEvent(true,Enum.KeyCode.Return,false,game) end)
    task.wait(0.02)
    pcall(function() VIM:SendKeyEvent(false,Enum.KeyCode.Return,false,game) end)
end
local function startShake()
    if shakeThread then task.cancel(shakeThread); shakeThread=nil end
    shakeThread=task.spawn(function()
        while shakeOn do
            if shakeUiVisible() then
                shakeActive=true; pressEnter()
                task.wait(0.05+math.random()*0.03)
            else
                shakeActive=false; task.wait(0.08)
            end
        end
        shakeActive=false
    end)
end
local function stopShake() shakeOn=false; shakeActive=false; if shakeThread then task.cancel(shakeThread); shakeThread=nil end end

-- ═══════════════════════════════════════
-- 🎣 AUTO-REEL v16 — ADAPTATIVO
-- ═══════════════════════════════════════

-- Referência ao label de status (setada depois da GUI ser criada)
local reelStatusLbl = nil

local function findReelUI()
    for _,name in ipairs({"reelui","fishingrod","reelbar","Fishing","FishingBar","ReelUI","FishingUI"}) do
        local g=PG:FindFirstChild(name)
        if g and g.Enabled~=false then return g end
    end
    for _,g in ipairs(PG:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            local n=g.Name:lower()
            if (n:find("reel") or n:find("fish")) and not n:find("shake") then return g end
        end
    end
    return nil
end

local function findReelElements(rGui)
    local playerbar, fishbar
    for _,d in ipairs(rGui:GetDescendants()) do
        if d:IsA("GuiObject") and d.Visible then
            local n=d.Name:lower()
            if not playerbar and (n=="playerbar" or n=="player" or n:find("playerbar")) then playerbar=d
            elseif not fishbar and (n=="fish" or n=="fishbar" or n=="fishicon" or n:find("fish") or n:find("target")) then fishbar=d end
        end
    end
    return playerbar, fishbar
end

-- Detecta se apareceu uma tela de reward/resultado após a pesca
local function detectRewardGui()
    for _,g in ipairs(PG:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            local n = g.Name:lower()
            if n:find("reward") or n:find("catch") or n:find("result") or n:find("fish_get") or n:find("caught") then
                return true, "win"
            end
            if n:find("fail") or n:find("escape") or n:find("lost") then
                return true, "lose"
            end
        end
    end
    -- Checa TextLabels com "escapou" / "got away" / "caught" visíveis
    for _,g in ipairs(PG:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            for _,d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible then
                    local t = d.Text:lower()
                    if t:find("got away") or t:find("escapou") or t:find("escaped") or t:find("failed") then
                        return true, "lose"
                    end
                    if t:find("caught") or t:find("capturou") or t:find("pescou") or t:find("hooked") then
                        return true, "win"
                    end
                end
            end
        end
    end
    return false, nil
end

local _mouseHeld = false
local function mousePress(x, y)
    if _mouseHeld then return end
    pcall(function() VIM:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true, game, 0) end)
    _mouseHeld = true
end
local function mouseRelease(x, y)
    if not _mouseHeld then return end
    pcall(function() VIM:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0) end)
    _mouseHeld = false
end
local function forceRelease()
    pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
    _mouseHeld = false
end

-- Atualiza o label de status do reel na GUI
local function updateReelStatus(text, color)
    if reelStatusLbl then
        reelStatusLbl.Text = text
        if color then reelStatusLbl.TextColor3 = color end
    end
end

local function startAutoReel()
    if autoReelThread then task.cancel(autoReelThread); autoReelThread=nil end
    reelActive = false
    forceRelease()

    autoReelThread = task.spawn(function()
        local C_grn  = Color3.fromRGB(52,211,120)
        local C_yel  = Color3.fromRGB(240,190,55)
        local C_red  = Color3.fromRGB(235,70,80)
        local C_cyan = Color3.fromRGB(80,220,255)
        local C_dim  = Color3.fromRGB(70,82,112)

        -- Aguarda a UI de reel abrir para começar uma sessão
        local wasActive = false  -- estava em minigame no frame anterior
        local sessionDiag = nil  -- diagnóstico da sessão atual
        local sessionStart = 0
        local postSessionWait = 0  -- timer para detectar resultado após UI fechar

        while autoReelOn do
            local rGui = findReelUI()

            if rGui then
                -- ── MINIGAME ATIVO ──
                if not wasActive then
                    -- Começou nova sessão
                    wasActive = true
                    postSessionWait = 0
                    sessionStart = tick()
                    sessionDiag = {
                        timesFar = 0, timesOvershoots = 0,
                        timesInside = 0, timesMid = 0,
                        startTime = tick()
                    }
                end

                local pb, fb = findReelElements(rGui)
                if not pb or not fb then
                    if _mouseHeld then forceRelease() end
                    reelActive = false
                    task.wait(0.08)
                else
                    reelActive = true

                    local cx = pb.AbsolutePosition.X + pb.AbsoluteSize.X * 0.5
                    local cy = pb.AbsolutePosition.Y + pb.AbsoluteSize.Y * 0.5
                    local pbL = pb.AbsolutePosition.X
                    local pbR = pb.AbsolutePosition.X + pb.AbsoluteSize.X
                    local barW = math.max(pb.AbsoluteSize.X, 1)
                    local barCenter = pbL + barW * 0.5

                    local fCX = fb.AbsolutePosition.X + fb.AbsoluteSize.X * 0.5
                    local fishInside = fCX >= pbL and fCX <= pbR
                    local dist = math.abs(fCX - barCenter)
                    local ratio = dist / barW

                    -- Detecta overshoot: peixe passou do lado oposto da barra
                    local prevBarCenter = barCenter
                    local overshoot = (fCX < pbL - barW * 0.1) or (fCX > pbR + barW * 0.1)

                    -- Registra diagnóstico
                    if sessionDiag then
                        if fishInside then
                            sessionDiag.timesInside = sessionDiag.timesInside + 1
                        elseif ratio < 0.30 then
                            sessionDiag.timesMid = sessionDiag.timesMid + 1
                        else
                            sessionDiag.timesFar = sessionDiag.timesFar + 1
                        end
                        if overshoot then
                            sessionDiag.timesOvershoots = sessionDiag.timesOvershoots + 1
                        end
                    end

                    -- Aplica lógica de reel com timings adaptados
                    local P = ReelParams
                    if fishInside then
                        mousePress(cx, cy)
                        task.wait(P.hold_inside + rnd(-0.008, 0.018))
                        mouseRelease(cx, cy)
                        task.wait(P.release_inside + rnd(-0.010, 0.025))
                    elseif ratio < 0.30 then
                        mousePress(cx, cy)
                        task.wait(P.hold_mid + rnd(-0.015, 0.025))
                        mouseRelease(cx, cy)
                        task.wait(P.release_mid + rnd(-0.008, 0.018))
                    else
                        mousePress(cx, cy)
                        task.wait(P.hold_far + rnd(-0.020, 0.050))
                        mouseRelease(cx, cy)
                        task.wait(P.release_far + rnd(0, 0.015))
                    end
                end

            else
                -- ── MINIGAME NÃO ATIVO ──
                if _mouseHeld then forceRelease() end
                reelActive = false

                if wasActive then
                    -- Acabou de fechar a UI — aguarda um momento para detectar resultado
                    wasActive = false
                    postSessionWait = tick()

                    -- Espera até 2s para aparecer alguma GUI de resultado
                    local won = false
                    local detected = false
                    for _ = 1, 20 do
                        task.wait(0.1)
                        local found, result = detectRewardGui()
                        if found then
                            won = (result == "win")
                            detected = true
                            break
                        end
                    end

                    -- Se não detectou explicitamente, assume win se durou mais de 3s (provavelmente capturou)
                    if not detected then
                        local dur = tick() - sessionStart
                        won = dur > 3.0
                    end

                    -- Aplica aprendizado
                    if sessionDiag then
                        applyLearning(won, sessionDiag)
                        sessionDiag = nil
                    end

                    -- Atualiza status na GUI
                    local w, t = getRecentScore(10)
                    local trend = (t > 0) and (w >= t * 0.7 and " ↑" or (w <= t * 0.3 and " ↓" or " →")) or ""
                    local scoreText = string.format("Score %d/%d%s • %s", w, t, trend, LearnHistory.lastDiagnosis)
                    updateReelStatus(scoreText, won and Color3.fromRGB(52,211,120) or Color3.fromRGB(240,190,55))

                    task.wait(1.5)
                else
                    updateReelStatus("○ aguardando UI de reel...", Color3.fromRGB(70,82,112))
                    task.wait(0.1)
                end
            end
        end

        forceRelease()
        reelActive = false
    end)
end

local function stopAutoReel()
    autoReelOn = false; reelActive = false
    forceRelease()
    if autoReelThread then task.cancel(autoReelThread); autoReelThread = nil end
end

-- ═══════════════════════════════════════
-- TREASURE MAPS
-- ═══════════════════════════════════════
local function getTreasureMaps()
    local maps={}
    local function scan(container)
        if not container then return end
        for _,t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("treasure") or t.Name:lower():find("map")) then
                local x,y,z
                for _,an in ipairs({"X","x","PosX","CoordX","TargetX"}) do local v=t:GetAttribute(an); if v then x=v; break end end
                for _,an in ipairs({"Y","y","PosY","CoordY","TargetY"}) do local v=t:GetAttribute(an); if v then y=v; break end end
                for _,an in ipairs({"Z","z","PosZ","CoordZ","TargetZ"}) do local v=t:GetAttribute(an); if v then z=v; break end end
                if not (x and y and z) then
                    for _,ch in ipairs(t:GetDescendants()) do
                        if ch:IsA("Vector3Value") then x=ch.Value.X; y=ch.Value.Y; z=ch.Value.Z; break end
                        if ch:IsA("StringValue") then
                            local sx,sy,sz=ch.Value:match("(%-?%d+)[,%s]+(%-?%d+)[,%s]+(%-?%d+)")
                            if sx then x=tonumber(sx);y=tonumber(sy);z=tonumber(sz); break end
                        end
                    end
                end
                if x and y and z then
                    table.insert(maps,{name=t.Name,pos=Vector3.new(x,y,z),fixed=true,tool=t})
                else
                    table.insert(maps,{name=t.Name.." (não fixado)",pos=nil,fixed=false,tool=t})
                end
            end
        end
    end
    scan(LP:FindFirstChild("Backpack"))
    local hand=tool()
    if hand and (hand.Name:lower():find("treasure") or hand.Name:lower():find("map")) then scan(LP.Character) end
    return maps
end

-- ═══════════════════════════════════════
-- SELL
-- ═══════════════════════════════════════
local function trySellTool(t)
    if not t then return false,"no_tool" end
    local rsEv=RS:FindFirstChild("events") or RS:FindFirstChild("Events") or RS:FindFirstChild("Remotes")
    if rsEv then
        for _,n in ipairs({"sell","Sell","appraise","Appraise","sellfish","SellFish","SellItem","appraiseFish","FishSell","submitFish","cashIn"}) do
            local e=rsEv:FindFirstChild(n)
            if e then
                if e:IsA("RemoteEvent") then pcall(function() e:FireServer(t) end); return true,"RE:"..n
                elseif e:IsA("RemoteFunction") then local ok=pcall(function() return e:InvokeServer(t) end); if ok then return true,"RF:"..n end end
            end
        end
        for _,e in ipairs(rsEv:GetDescendants()) do
            local lw=e.Name:lower()
            if (lw:find("sell") or lw:find("appraise") or lw:find("submit") or lw:find("cash")) and e:IsA("RemoteEvent") then
                pcall(function() e:FireServer(t) end); return true,"RE:"..e.Name
            end
        end
    end
    for _,obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local n=obj.Name:lower()
            if n:find("sell") or n:find("appraise") or n:find("submit") then
                local sz=obj.AbsoluteSize; if sz.X>2 and sz.Y>2 then pcall(function() obj.MouseButton1Click:Fire() end); return true,"GUI:"..obj.Name end
            end
        end
    end
    pcall(function() t:Activate() end); return false,"no_method"
end
local function sellFromHand() local t=tool(); if not t then return false,"No item in hand" end; return trySellTool(t) end
local function sellAll()
    local sold,failed=0,0; local items={}
    local bp=LP:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and not (t.Name:lower():find("treasure") or t.Name:lower():find("map")) then table.insert(items,t) end
    end end
    local hand=tool(); if hand and not (hand.Name:lower():find("treasure") or hand.Name:lower():find("map")) then table.insert(items,hand) end
    for _,t in ipairs(items) do local ok=trySellTool(t); if ok then sold=sold+1 else failed=failed+1 end; task.wait(0.15) end
    if sold==0 and failed==0 then return false,"Inventory empty" end
    return true,"Sold "..sold..(failed>0 and " | Failed "..failed or "")
end
local function startAutoSell(lbl)
    if autoSellThread then task.cancel(autoSellThread); autoSellThread=nil end
    autoSellThread=task.spawn(function()
        while autoSellOn do
            local ok,msg=sellAll()
            if lbl then lbl.TextColor3=ok and Color3.fromRGB(52,211,120) or Color3.fromRGB(240,190,55); lbl.Text=(ok and "✅ " or "⏳ ")..msg end
            task.wait(autoSellDelay)
        end
        if lbl then lbl.Text="Auto-sell off" end
    end)
end
local function stopAutoSell() autoSellOn=false; if autoSellThread then task.cancel(autoSellThread); autoSellThread=nil end end

local function tpTo(pos) local r=hrp(); if not r then return false end; r.CFrame=CFrame.new(pos+Vector3.new(0,5,0)); return true end
local function getNearby()
    local r=hrp(); if not r then return {} end; local found={}
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj~=LP.Character then
            local h2=obj:FindFirstChildOfClass("Humanoid")
            local part=obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if h2 and part then
                local d=(r.Position-part.Position).Magnitude
                if d<=npcRange then table.insert(found,{name=obj.Name,part=part,dist=math.floor(d)}) end
            end
        end
    end
    table.sort(found,function(a,b) return a.dist<b.dist end); return found
end
local function tpToNPC(part) local r=hrp(); if not r then return end; r.CFrame=CFrame.new((part.CFrame*CFrame.new(0,0,-3.5)).Position+Vector3.new(0,3,0)) end

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if noclipOn then setNoclip(true) end
    if speedOn  then applySpeedOnce(); startSpeedLoop() end
    if jumpOn   then startJumpLoop() end
    if reJumpOn and jumpOn then startReJump() end
end)

-- ═══════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════
pcall(function()
    for _,n in ipairs({"UtilityGui","NoclipGui"}) do
        local o=PG:FindFirstChild(n); if o then o:Destroy() end
    end
end)

local gui=Instance.new("ScreenGui",PG)
gui.Name="UtilityGui"; gui.ResetOnSpawn=false; gui.DisplayOrder=999; gui.IgnoreGuiInset=true

local C={
    bg=Color3.fromRGB(8,10,18),      panel=Color3.fromRGB(13,16,28),
    card=Color3.fromRGB(18,22,38),   cardH=Color3.fromRGB(24,30,52),
    acc=Color3.fromRGB(82,148,255),  accD=Color3.fromRGB(48,90,190),
    grn=Color3.fromRGB(52,211,120),  red=Color3.fromRGB(235,70,80),
    yel=Color3.fromRGB(240,190,55),  pink=Color3.fromRGB(255,80,180),
    gold=Color3.fromRGB(255,180,60), cyan=Color3.fromRGB(80,220,255),
    dim=Color3.fromRGB(70,82,112),   txt=Color3.fromRGB(210,218,240),
    sub=Color3.fromRGB(128,140,175), bdr=Color3.fromRGB(26,33,58),
    sellBg=Color3.fromRGB(16,58,36), sellH=Color3.fromRGB(20,72,44),
    learn=Color3.fromRGB(130,80,220),-- cor especial pro sistema de aprendizado
}

local function tw(o,p,d)  return TweenSvc:Create(o,TweenInfo.new(d or 0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p) end
local function twB(o,p)   return TweenSvc:Create(o,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),p) end

local FRAME_W=220; local HEADER_H=36
local frame=Instance.new("Frame",gui)
frame.Size=UDim2.new(0,FRAME_W,0,HEADER_H)
frame.Position=UDim2.new(0,-FRAME_W,0.5,-180)
frame.BackgroundColor3=C.bg; frame.BorderSizePixel=0
frame.ClipsDescendants=true; frame.BackgroundTransparency=1
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)
local fBdr=Instance.new("UIStroke",frame); fBdr.Color=C.bdr; fBdr.Thickness=1.5
fBdr.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

local contentHolder=Instance.new("Frame",frame)
contentHolder.Size=UDim2.new(1,0,0,9999); contentHolder.Position=UDim2.new(0,0,0,HEADER_H)
contentHolder.BackgroundTransparency=1; contentHolder.BorderSizePixel=0
local rootLy=Instance.new("UIListLayout",contentHolder)
rootLy.SortOrder=Enum.SortOrder.LayoutOrder; rootLy.Padding=UDim.new(0,0)

local function mkDiv(p,order)
    local d=Instance.new("Frame",p); d.Size=UDim2.new(1,0,0,1)
    d.BackgroundColor3=C.bdr; d.BorderSizePixel=0; d.LayoutOrder=order
end
local function pad(p,l,r,t,b)
    local u=Instance.new("UIPadding",p)
    u.PaddingLeft=UDim.new(0,l or 10); u.PaddingRight=UDim.new(0,r or 10)
    u.PaddingTop=UDim.new(0,t or 6); u.PaddingBottom=UDim.new(0,b or 6)
end

local header=Instance.new("Frame",frame)
header.Size=UDim2.new(1,0,0,HEADER_H); header.Position=UDim2.new(0,0,0,0)
header.BackgroundColor3=C.panel; header.BorderSizePixel=0; header.ZIndex=2
local hGrad=Instance.new("UIGradient",header)
hGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(16,22,52)),ColorSequenceKeypoint.new(1,C.bg)})
hGrad.Rotation=90

local dot=Instance.new("Frame",header)
dot.Size=UDim2.new(0,7,0,7); dot.Position=UDim2.new(0,11,0.5,-3)
dot.BackgroundColor3=C.dim; dot.BorderSizePixel=0; dot.ZIndex=4
Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

local htitle=Instance.new("TextLabel",header)
htitle.Size=UDim2.new(1,-60,1,0); htitle.Position=UDim2.new(0,24,0,0)
htitle.BackgroundTransparency=1; htitle.Text="⚙  UTILITY  v16"
htitle.TextColor3=C.txt; htitle.Font=Enum.Font.GothamBlack; htitle.TextSize=11
htitle.TextXAlignment=Enum.TextXAlignment.Left; htitle.ZIndex=4

local vHint=Instance.new("TextLabel",header)
vHint.Size=UDim2.new(0,20,0,14); vHint.Position=UDim2.new(1,-26,0.5,-7)
vHint.BackgroundColor3=Color3.fromRGB(20,26,50); vHint.BorderSizePixel=0
vHint.Text="V"; vHint.TextColor3=C.dim; vHint.Font=Enum.Font.GothamBold; vHint.TextSize=8
vHint.TextXAlignment=Enum.TextXAlignment.Center; vHint.ZIndex=4
Instance.new("UICorner",vHint).CornerRadius=UDim.new(0,4)

local tabBar=Instance.new("Frame",contentHolder)
tabBar.Size=UDim2.new(1,0,0,28); tabBar.BackgroundColor3=C.panel
tabBar.BorderSizePixel=0; tabBar.LayoutOrder=1
pad(tabBar,5,5,4,4)
local tabLy=Instance.new("UIListLayout",tabBar)
tabLy.FillDirection=Enum.FillDirection.Horizontal; tabLy.SortOrder=Enum.SortOrder.LayoutOrder; tabLy.Padding=UDim.new(0,2)

local tabBtns={}; local tabPages={}
local function mkTab(name,icon,order)
    local b=Instance.new("TextButton",tabBar)
    b.Size=UDim2.new(0.2,-2,1,0); b.BackgroundColor3=C.card
    b.BorderSizePixel=0; b.Text=icon; b.TextColor3=C.dim
    b.Font=Enum.Font.GothamBold; b.TextSize=11; b.AutoButtonColor=false; b.LayoutOrder=order
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    tabBtns[name]=b
    b.MouseEnter:Connect(function() vHint.Text=name:sub(1,4):upper() end)
    b.MouseLeave:Connect(function() vHint.Text="V" end)
    return b
end
local function mkPage(order)
    local pg=Instance.new("Frame",contentHolder)
    pg.Size=UDim2.new(1,0,0,0); pg.AutomaticSize=Enum.AutomaticSize.Y
    pg.BackgroundTransparency=1; pg.BorderSizePixel=0; pg.LayoutOrder=order; pg.Visible=false
    local ly=Instance.new("UIListLayout",pg); ly.SortOrder=Enum.SortOrder.LayoutOrder; ly.Padding=UDim.new(0,0)
    return pg
end

mkTab("Cheats","🎮",1); mkTab("TP","🗺",2); mkTab("Rods","🎣",3); mkTab("Maps","📜",4); mkTab("NPCs","🧑",5)
mkDiv(contentHolder,2)
tabPages["Cheats"]=mkPage(3); tabPages["TP"]=mkPage(4); tabPages["Rods"]=mkPage(5); tabPages["Maps"]=mkPage(6); tabPages["NPCs"]=mkPage(7)

local function getContentH() return rootLy.AbsoluteContentSize.Y end
local function refreshSize()
    if not guiVisible then return end; task.wait()
    frame.Size=UDim2.new(0,FRAME_W,0,HEADER_H+getContentH())
end
local function setVisible(v)
    if vDebounce then return end
    if guiVisible==v then return end
    vDebounce=true; guiVisible=v
    if v then
        contentHolder.Visible=true; task.wait()
        tw(frame,{Size=UDim2.new(0,FRAME_W,0,HEADER_H+getContentH()),BackgroundTransparency=0},0.2):Play()
        tw(vHint,{TextColor3=C.dim},0.15):Play()
        task.delay(0.25,function() vDebounce=false end)
    else
        local sh=tw(frame,{Size=UDim2.new(0,FRAME_W,0,HEADER_H)},0.18); sh:Play()
        tw(vHint,{TextColor3=C.acc},0.15):Play()
        sh.Completed:Connect(function()
            if not guiVisible then contentHolder.Visible=false end
            task.delay(0.05,function() vDebounce=false end)
        end)
    end
end
local function switchTab(name)
    currentTab=name
    for n,pg in pairs(tabPages) do pg.Visible=(n==name) end
    for n,b in pairs(tabBtns) do tw(b,{BackgroundColor3=(n==name) and C.acc or C.card,TextColor3=(n==name) and C.bg or C.dim}):Play() end
    refreshSize()
end
for name,b in pairs(tabBtns) do b.MouseButton1Click:Connect(function() switchTab(name) end) end

local function ripple(btn,col)
    local rip=Instance.new("Frame",btn)
    rip.Size=UDim2.new(0,0,0,0); rip.AnchorPoint=Vector2.new(0.5,0.5)
    rip.Position=UDim2.new(0.5,0,0.5,0); rip.BackgroundColor3=col or Color3.fromRGB(255,255,255)
    rip.BackgroundTransparency=0.7; rip.BorderSizePixel=0; rip.ZIndex=btn.ZIndex+1
    Instance.new("UICorner",rip).CornerRadius=UDim.new(1,0)
    local sz=math.max(btn.AbsoluteSize.X,btn.AbsoluteSize.Y)*2
    local t=TweenSvc:Create(rip,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,sz,0,sz),BackgroundTransparency=1})
    t:Play(); t.Completed:Connect(function() rip:Destroy() end)
end

local BLOCKED={[Enum.KeyCode.Return]=true,[Enum.KeyCode.Escape]=true,[Enum.KeyCode.Tab]=true,
    [Enum.KeyCode.Backspace]=true,[Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,
    [Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,
    [Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true,[Enum.KeyCode.V]=true}

local function mkSection(parent,cfg)
    local sec=Instance.new("Frame",parent)
    sec.Size=UDim2.new(1,0,0,0); sec.AutomaticSize=Enum.AutomaticSize.Y
    sec.BackgroundColor3=C.card; sec.BorderSizePixel=0; sec.LayoutOrder=cfg.order
    local u=Instance.new("UIPadding",sec)
    u.PaddingLeft=UDim.new(0,10); u.PaddingRight=UDim.new(0,10)
    u.PaddingTop=UDim.new(0,7); u.PaddingBottom=UDim.new(0,7)
    local ly=Instance.new("UIListLayout",sec); ly.SortOrder=Enum.SortOrder.LayoutOrder; ly.Padding=UDim.new(0,5)

    local r1=Instance.new("Frame",sec); r1.Size=UDim2.new(1,0,0,20); r1.BackgroundTransparency=1; r1.LayoutOrder=1
    local lbl=Instance.new("TextLabel",r1); lbl.Size=UDim2.new(1,-52,1,0); lbl.BackgroundTransparency=1
    lbl.Text=cfg.icon.."  "..cfg.label; lbl.TextColor3=C.sub
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local tr=Instance.new("Frame",r1); tr.Size=UDim2.new(0,36,0,18); tr.Position=UDim2.new(1,-36,0.5,-9)
    tr.BackgroundColor3=Color3.fromRGB(22,28,50); tr.BorderSizePixel=0
    Instance.new("UICorner",tr).CornerRadius=UDim.new(0,9); Instance.new("UIStroke",tr).Color=C.bdr
    local kn=Instance.new("Frame",tr); kn.Size=UDim2.new(0,14,0,14); kn.Position=UDim2.new(0,2,0.5,-7)
    kn.BackgroundColor3=Color3.fromRGB(195,205,235); kn.BorderSizePixel=0
    Instance.new("UICorner",kn).CornerRadius=UDim.new(0,7)
    local togHit=Instance.new("TextButton",tr); togHit.Size=UDim2.new(1,0,1,0)
    togHit.BackgroundTransparency=1; togHit.Text=""; togHit.AutoButtonColor=false; togHit.ZIndex=5
    togHit.MouseButton1Click:Connect(function() ripple(tr,C.acc) end)

    local r2=Instance.new("Frame",sec); r2.Size=UDim2.new(1,0,0,20); r2.BackgroundTransparency=1; r2.LayoutOrder=2
    local kl=Instance.new("TextLabel",r2); kl.Size=UDim2.new(0,38,1,0); kl.BackgroundTransparency=1
    kl.Text="Key:"; kl.TextColor3=C.dim; kl.Font=Enum.Font.Gotham; kl.TextSize=8; kl.TextXAlignment=Enum.TextXAlignment.Left
    local bindB=Instance.new("TextButton",r2); bindB.Size=UDim2.new(0,64,0,18); bindB.Position=UDim2.new(0,40,0.5,-9)
    bindB.BackgroundColor3=Color3.fromRGB(18,22,44); bindB.BorderSizePixel=0
    bindB.Text=cfg.keyName; bindB.TextColor3=C.acc; bindB.Font=Enum.Font.GothamBold; bindB.TextSize=9; bindB.AutoButtonColor=false
    Instance.new("UICorner",bindB).CornerRadius=UDim.new(0,5); Instance.new("UIStroke",bindB).Color=C.accD

    -- Status label (linha 1 do status)
    local statusLbl=nil
    if cfg.showStatus then
        local rs=Instance.new("Frame",sec); rs.Size=UDim2.new(1,0,0,12); rs.BackgroundTransparency=1; rs.LayoutOrder=2.5
        statusLbl=Instance.new("TextLabel",rs); statusLbl.Size=UDim2.new(1,0,1,0)
        statusLbl.BackgroundTransparency=1; statusLbl.Text=""; statusLbl.TextColor3=C.dim
        statusLbl.Font=Enum.Font.Code; statusLbl.TextSize=8; statusLbl.TextXAlignment=Enum.TextXAlignment.Left
    end

    -- Status label extra (linha 2, usada pra aprendizado)
    local statusLbl2=nil
    if cfg.showStatus2 then
        local rs2=Instance.new("Frame",sec); rs2.Size=UDim2.new(1,0,0,11); rs2.BackgroundTransparency=1; rs2.LayoutOrder=2.6
        statusLbl2=Instance.new("TextLabel",rs2); statusLbl2.Size=UDim2.new(1,0,1,0)
        statusLbl2.BackgroundTransparency=1; statusLbl2.Text=""; statusLbl2.TextColor3=C.learn
        statusLbl2.Font=Enum.Font.Code; statusLbl2.TextSize=7; statusLbl2.TextXAlignment=Enum.TextXAlignment.Left
    end

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
        fill.BackgroundColor3=C.acc; fill.BorderSizePixel=0; Instance.new("UICorner",fill).CornerRadius=UDim.new(0,2)
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
        tw(lbl,{TextColor3=on and C.txt or C.sub}):Play()
    end
    local function setRj(on)
        if rjTr then tw(rjTr,{BackgroundColor3=on and C.acc or Color3.fromRGB(22,28,50)}):Play() end
        if rjKn then twB(rjKn,{Position=on and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play() end
    end
    return {togHit=togHit,bindBtn=bindB,rjTogHit=rjTogHit,setTog=setTog,setRj=setRj,statusLbl=statusLbl,statusLbl2=statusLbl2,lbl=lbl}
end

-- ═══════════════════════════════════════
-- PAGE CHEATS
-- ═══════════════════════════════════════
local pg1=tabPages["Cheats"]
mkDiv(pg1,1)
local ncSec=mkSection(pg1,{order=2,icon="👻",label="Noclip",keyName=ncKey.Name})
mkDiv(pg1,3)
local spSec=mkSection(pg1,{order=4,icon="💨",label="Speed",keyName=spKey.Name,
    slider={min=16,max=300,def=speedVal,label="Speed",onChange=function(v) speedVal=v end}})
mkDiv(pg1,5)
local hjSec=mkSection(pg1,{order=6,icon="🦘",label="High Jump",keyName=hjKey.Name,
    slider={min=50,max=500,def=jumpVal,label="Power",onChange=function(v) jumpVal=v end},rejump=true})
mkDiv(pg1,7)
local shSec=mkSection(pg1,{order=8,icon="🔄",label="Shake",keyName=shakeKey.Name,showStatus=true})
mkDiv(pg1,9)

-- Auto-Reel com 2 linhas de status (linha 2 = aprendizado)
local reSec=mkSection(pg1,{order=10,icon="🎣",label="Auto-Reel  🧠",keyName=reelKey.Name,showStatus=true,showStatus2=true})

-- Liga a referência global do status ao label criado na seção
reelStatusLbl = reSec.statusLbl

-- Painel de aprendizado expandido (dentro da seção Auto-Reel)
local learnPad=Instance.new("Frame",reSec.lbl.Parent.Parent) -- parent = sec
learnPad.Size=UDim2.new(1,0,0,0); learnPad.AutomaticSize=Enum.AutomaticSize.Y
learnPad.BackgroundColor3=Color3.fromRGB(12,8,22); learnPad.BorderSizePixel=0; learnPad.LayoutOrder=6
Instance.new("UICorner",learnPad).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",learnPad).Color=Color3.fromRGB(60,40,100)
local lpu=Instance.new("UIPadding",learnPad)
lpu.PaddingLeft=UDim.new(0,8); lpu.PaddingRight=UDim.new(0,8)
lpu.PaddingTop=UDim.new(0,5); lpu.PaddingBottom=UDim.new(0,6)
local lpLy=Instance.new("UIListLayout",learnPad); lpLy.SortOrder=Enum.SortOrder.LayoutOrder; lpLy.Padding=UDim.new(0,3)

local lpTitle=Instance.new("TextLabel",learnPad); lpTitle.Size=UDim2.new(1,0,0,11); lpTitle.BackgroundTransparency=1; lpTitle.LayoutOrder=1
lpTitle.Text="🧠  Aprendizado adaptativo"; lpTitle.TextColor3=C.learn; lpTitle.Font=Enum.Font.GothamBold; lpTitle.TextSize=8; lpTitle.TextXAlignment=Enum.TextXAlignment.Left

local lpScore=Instance.new("TextLabel",learnPad); lpScore.Size=UDim2.new(1,0,0,10); lpScore.BackgroundTransparency=1; lpScore.LayoutOrder=2
lpScore.Text="Score: —"; lpScore.TextColor3=C.txt; lpScore.Font=Enum.Font.Code; lpScore.TextSize=8; lpScore.TextXAlignment=Enum.TextXAlignment.Left

local lpDiag=Instance.new("TextLabel",learnPad); lpDiag.Size=UDim2.new(1,0,0,10); lpDiag.BackgroundTransparency=1; lpDiag.LayoutOrder=3
lpDiag.Text="Último: —"; lpDiag.TextColor3=C.sub; lpDiag.Font=Enum.Font.Code; lpDiag.TextSize=7; lpDiag.TextXAlignment=Enum.TextXAlignment.Left

local lpParams=Instance.new("TextLabel",learnPad); lpParams.Size=UDim2.new(1,0,0,10); lpParams.BackgroundTransparency=1; lpParams.LayoutOrder=4
lpParams.Text=""; lpParams.TextColor3=C.dim; lpParams.Font=Enum.Font.Code; lpParams.TextSize=7; lpParams.TextXAlignment=Enum.TextXAlignment.Left

-- Linha divisória
local lpDiv=Instance.new("Frame",learnPad); lpDiv.Size=UDim2.new(1,0,0,1); lpDiv.BackgroundColor3=Color3.fromRGB(60,40,100); lpDiv.BorderSizePixel=0; lpDiv.LayoutOrder=5

-- Botão reset
local lpReset=Instance.new("TextButton",learnPad); lpReset.Size=UDim2.new(1,0,0,20); lpReset.LayoutOrder=6
lpReset.BackgroundColor3=Color3.fromRGB(30,12,42); lpReset.BorderSizePixel=0
lpReset.Text="🔄  Resetar aprendizado"; lpReset.TextColor3=C.learn
lpReset.Font=Enum.Font.GothamBold; lpReset.TextSize=8; lpReset.AutoButtonColor=false
Instance.new("UICorner",lpReset).CornerRadius=UDim.new(0,5)
lpReset.MouseEnter:Connect(function() tw(lpReset,{BackgroundColor3=Color3.fromRGB(44,18,60)}):Play() end)
lpReset.MouseLeave:Connect(function() tw(lpReset,{BackgroundColor3=Color3.fromRGB(30,12,42)}):Play() end)
lpReset.MouseButton1Click:Connect(function()
    ripple(lpReset,C.learn)
    -- Reseta todos os parâmetros para os defaults
    ReelParams.hold_far      = 0.200
    ReelParams.release_far   = 0.025
    ReelParams.hold_mid      = 0.095
    ReelParams.release_mid   = 0.040
    ReelParams.hold_inside   = 0.042
    ReelParams.release_inside= 0.055
    LearnHistory.sessions    = {}
    LearnHistory.totalWins   = 0
    LearnHistory.totalLosses = 0
    LearnHistory.lastDiagnosis = "—"
    LearnHistory.adjustCount = 0
    lpScore.Text = "Score: resetado"; lpScore.TextColor3=C.yel
    lpDiag.Text  = "Último: —"
    task.delay(2, function() lpScore.TextColor3=C.txt end)
end)

mkDiv(pg1,11)

-- ── Atualiza painel de aprendizado periodicamente
task.spawn(function()
    while true do
        task.wait(0.5)
        -- Score
        local w, t = getRecentScore(10)
        local trend = ""
        if t > 0 then
            local pct = w / t
            trend = pct >= 0.7 and " ↑" or (pct <= 0.3 and " ↓" or " →")
        end
        lpScore.Text = string.format("Score: %d/%d%s  |  Total: %d✅ %d❌  |  Ajustes: %d",
            w, t, trend, LearnHistory.totalWins, LearnHistory.totalLosses, LearnHistory.adjustCount)
        local sw, st = getRecentScore(10)
        lpScore.TextColor3 = (st > 0 and sw/st >= 0.6) and C.grn or ((st > 0 and sw/st <= 0.3) and C.red or C.yel)

        -- Último diagnóstico
        lpDiag.Text = "Último: " .. LearnHistory.lastDiagnosis

        -- Parâmetros atuais
        lpParams.Text = string.format("⚙ far %.0f/%.0f  mid %.0f/%.0f  in %.0f/%.0fms",
            ReelParams.hold_far*1000, ReelParams.release_far*1000,
            ReelParams.hold_mid*1000, ReelParams.release_mid*1000,
            ReelParams.hold_inside*1000, ReelParams.release_inside*1000)
    end
end)

-- SELL
local sellF=Instance.new("Frame",pg1)
sellF.Size=UDim2.new(1,0,0,0); sellF.AutomaticSize=Enum.AutomaticSize.Y
sellF.BackgroundColor3=C.card; sellF.BorderSizePixel=0; sellF.LayoutOrder=12
local su=Instance.new("UIPadding",sellF)
su.PaddingLeft=UDim.new(0,10); su.PaddingRight=UDim.new(0,10); su.PaddingTop=UDim.new(0,7); su.PaddingBottom=UDim.new(0,9)
local sLy=Instance.new("UIListLayout",sellF); sLy.SortOrder=Enum.SortOrder.LayoutOrder; sLy.Padding=UDim.new(0,5)
local sTR=Instance.new("Frame",sellF); sTR.Size=UDim2.new(1,0,0,16); sTR.BackgroundTransparency=1; sTR.LayoutOrder=1
local sTL=Instance.new("TextLabel",sTR); sTL.Size=UDim2.new(1,0,1,0); sTL.BackgroundTransparency=1
sTL.Text="💰  Sell"; sTL.TextColor3=C.sub; sTL.Font=Enum.Font.GothamBold; sTL.TextSize=10; sTL.TextXAlignment=Enum.TextXAlignment.Left
local sellSt=Instance.new("TextLabel",sellF)
sellSt.Size=UDim2.new(1,0,0,10); sellSt.BackgroundTransparency=1; sellSt.Text="Waiting..."
sellSt.TextColor3=C.dim; sellSt.Font=Enum.Font.Gotham; sellSt.TextSize=8; sellSt.TextXAlignment=Enum.TextXAlignment.Left; sellSt.LayoutOrder=2
local sBR=Instance.new("Frame",sellF); sBR.Size=UDim2.new(1,0,0,20); sBR.BackgroundTransparency=1; sBR.LayoutOrder=3
local sBL=Instance.new("TextLabel",sBR); sBL.Size=UDim2.new(0,38,1,0); sBL.BackgroundTransparency=1
sBL.Text="Key:"; sBL.TextColor3=C.dim; sBL.Font=Enum.Font.Gotham; sBL.TextSize=8; sBL.TextXAlignment=Enum.TextXAlignment.Left
local sellBind=Instance.new("TextButton",sBR)
sellBind.Size=UDim2.new(0,64,0,18); sellBind.Position=UDim2.new(0,40,0.5,-9)
sellBind.BackgroundColor3=Color3.fromRGB(18,22,44); sellBind.BorderSizePixel=0
sellBind.Text=sellKey.Name; sellBind.TextColor3=C.acc; sellBind.Font=Enum.Font.GothamBold; sellBind.TextSize=9; sellBind.AutoButtonColor=false
Instance.new("UICorner",sellBind).CornerRadius=UDim.new(0,5); Instance.new("UIStroke",sellBind).Color=C.accD
local sellBtn=Instance.new("TextButton",sellF)
sellBtn.Size=UDim2.new(1,0,0,28); sellBtn.LayoutOrder=4
sellBtn.BackgroundColor3=C.sellBg; sellBtn.BorderSizePixel=0
sellBtn.Text="💰  Sell Item in Hand"; sellBtn.TextColor3=C.grn
sellBtn.Font=Enum.Font.GothamBold; sellBtn.TextSize=9; sellBtn.AutoButtonColor=false
Instance.new("UICorner",sellBtn).CornerRadius=UDim.new(0,7); Instance.new("UIStroke",sellBtn).Color=Color3.fromRGB(22,82,50)
sellBtn.MouseEnter:Connect(function() tw(sellBtn,{BackgroundColor3=C.sellH}):Play() end)
sellBtn.MouseLeave:Connect(function() tw(sellBtn,{BackgroundColor3=C.sellBg}):Play() end)
sellBtn.MouseButton1Click:Connect(function() ripple(sellBtn,C.grn) end)
local innerDiv=Instance.new("Frame",sellF); innerDiv.Size=UDim2.new(1,0,0,1); innerDiv.BackgroundColor3=C.bdr; innerDiv.BorderSizePixel=0; innerDiv.LayoutOrder=5
local sellAllBtn=Instance.new("TextButton",sellF)
sellAllBtn.Size=UDim2.new(1,0,0,28); sellAllBtn.LayoutOrder=6
sellAllBtn.BackgroundColor3=Color3.fromRGB(14,50,30); sellAllBtn.BorderSizePixel=0
sellAllBtn.Text="📦  Sell All (mantém mapas)"; sellAllBtn.TextColor3=C.grn
sellAllBtn.Font=Enum.Font.GothamBold; sellAllBtn.TextSize=9; sellAllBtn.AutoButtonColor=false
Instance.new("UICorner",sellAllBtn).CornerRadius=UDim.new(0,7); Instance.new("UIStroke",sellAllBtn).Color=Color3.fromRGB(18,70,40)
sellAllBtn.MouseEnter:Connect(function() tw(sellAllBtn,{BackgroundColor3=Color3.fromRGB(18,64,38)}):Play() end)
sellAllBtn.MouseLeave:Connect(function() tw(sellAllBtn,{BackgroundColor3=Color3.fromRGB(14,50,30)}):Play() end)
sellAllBtn.MouseButton1Click:Connect(function() ripple(sellAllBtn,C.grn) end)
local innerDiv2=Instance.new("Frame",sellF); innerDiv2.Size=UDim2.new(1,0,0,1); innerDiv2.BackgroundColor3=C.bdr; innerDiv2.BorderSizePixel=0; innerDiv2.LayoutOrder=7
local autoRow=Instance.new("Frame",sellF); autoRow.Size=UDim2.new(1,0,0,20); autoRow.BackgroundTransparency=1; autoRow.LayoutOrder=8
local autoLbl=Instance.new("TextLabel",autoRow); autoLbl.Size=UDim2.new(1,-52,1,0); autoLbl.BackgroundTransparency=1
autoLbl.Text="🔁  Auto-Sell"; autoLbl.TextColor3=C.sub; autoLbl.Font=Enum.Font.GothamBold; autoLbl.TextSize=10; autoLbl.TextXAlignment=Enum.TextXAlignment.Left
local autoTr=Instance.new("Frame",autoRow); autoTr.Size=UDim2.new(0,36,0,18); autoTr.Position=UDim2.new(1,-36,0.5,-9)
autoTr.BackgroundColor3=Color3.fromRGB(22,28,50); autoTr.BorderSizePixel=0
Instance.new("UICorner",autoTr).CornerRadius=UDim.new(0,9); Instance.new("UIStroke",autoTr).Color=C.bdr
local autoKn=Instance.new("Frame",autoTr); autoKn.Size=UDim2.new(0,14,0,14); autoKn.Position=UDim2.new(0,2,0.5,-7)
autoKn.BackgroundColor3=Color3.fromRGB(195,205,235); autoKn.BorderSizePixel=0; Instance.new("UICorner",autoKn).CornerRadius=UDim.new(0,7)
local autoTogHit=Instance.new("TextButton",autoTr); autoTogHit.Size=UDim2.new(1,0,1,0)
autoTogHit.BackgroundTransparency=1; autoTogHit.Text=""; autoTogHit.AutoButtonColor=false; autoTogHit.ZIndex=5
autoTogHit.MouseButton1Click:Connect(function() ripple(autoTr,C.grn) end)
local autoDelRow1=Instance.new("Frame",sellF); autoDelRow1.Size=UDim2.new(1,0,0,13); autoDelRow1.BackgroundTransparency=1; autoDelRow1.LayoutOrder=9
local autoDelLbl=Instance.new("TextLabel",autoDelRow1); autoDelLbl.Size=UDim2.new(1,0,1,0); autoDelLbl.BackgroundTransparency=1
autoDelLbl.Text="Delay: 1.5s"; autoDelLbl.TextColor3=C.acc; autoDelLbl.Font=Enum.Font.GothamBold; autoDelLbl.TextSize=8; autoDelLbl.TextXAlignment=Enum.TextXAlignment.Left
local autoDelRow2=Instance.new("Frame",sellF); autoDelRow2.Size=UDim2.new(1,0,0,14); autoDelRow2.BackgroundTransparency=1; autoDelRow2.LayoutOrder=10
local adBg=Instance.new("Frame",autoDelRow2); adBg.Size=UDim2.new(1,0,0,4); adBg.Position=UDim2.new(0,0,0.5,-2)
adBg.BackgroundColor3=Color3.fromRGB(20,25,45); adBg.BorderSizePixel=0; Instance.new("UICorner",adBg).CornerRadius=UDim.new(0,2)
local adPct=(autoSellDelay-0.5)/(10-0.5)
local adFill=Instance.new("Frame",adBg); adFill.Size=UDim2.new(adPct,0,1,0); adFill.BackgroundColor3=C.grn; adFill.BorderSizePixel=0; Instance.new("UICorner",adFill).CornerRadius=UDim.new(0,2)
local adKn=Instance.new("Frame",adBg); adKn.Size=UDim2.new(0,11,0,11); adKn.AnchorPoint=Vector2.new(0.5,0.5)
adKn.Position=UDim2.new(adPct,0,0.5,0); adKn.BackgroundColor3=Color3.fromRGB(255,255,255); adKn.BorderSizePixel=0; adKn.ZIndex=3; Instance.new("UICorner",adKn).CornerRadius=UDim.new(0,6)
local adHit=Instance.new("TextButton",adBg); adHit.Size=UDim2.new(1,0,0,20); adHit.Position=UDim2.new(0,0,0.5,-10)
adHit.BackgroundTransparency=1; adHit.Text=""; adHit.AutoButtonColor=false; adHit.ZIndex=4
local adDrag=false
adHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then adDrag=true end end)
adHit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then adDrag=false end end)
UIS.InputChanged:Connect(function(i)
    if not adDrag or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local pct=math.clamp((i.Position.X-adBg.AbsolutePosition.X)/adBg.AbsoluteSize.X,0,1)
    autoSellDelay=math.floor((0.5+pct*(10-0.5))*10+0.5)/10
    adFill.Size=UDim2.new(pct,0,1,0); adKn.Position=UDim2.new(pct,0,0.5,0); autoDelLbl.Text="Delay: "..autoSellDelay.."s"
end)
local autoStLbl=Instance.new("TextLabel",sellF)
autoStLbl.Size=UDim2.new(1,0,0,10); autoStLbl.BackgroundTransparency=1; autoStLbl.Text=""
autoStLbl.TextColor3=C.dim; autoStLbl.Font=Enum.Font.Code; autoStLbl.TextSize=8
autoStLbl.TextXAlignment=Enum.TextXAlignment.Left; autoStLbl.LayoutOrder=11
mkDiv(pg1,13)

-- ═══════════════════════════════════════
-- PAGE TP
-- ═══════════════════════════════════════
local pg2=tabPages["TP"]
local tpScroll=Instance.new("ScrollingFrame",pg2)
tpScroll.Size=UDim2.new(1,0,0,300); tpScroll.BackgroundTransparency=1; tpScroll.BorderSizePixel=0
tpScroll.ScrollBarThickness=3; tpScroll.ScrollBarImageColor3=C.acc
tpScroll.CanvasSize=UDim2.new(0,0,0,0); tpScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; tpScroll.LayoutOrder=1
local tpLy=Instance.new("UIListLayout",tpScroll); tpLy.SortOrder=Enum.SortOrder.LayoutOrder; tpLy.Padding=UDim.new(0,2)
pad(tpScroll,8,8,6,6)
local tpSt=Instance.new("TextLabel",tpScroll); tpSt.Size=UDim2.new(1,0,0,14); tpSt.BackgroundTransparency=1
tpSt.Text=""; tpSt.TextColor3=C.grn; tpSt.Font=Enum.Font.GothamBold; tpSt.TextSize=8; tpSt.TextXAlignment=Enum.TextXAlignment.Left; tpSt.LayoutOrder=0
local function catColor(cat)
    if cat=="second" then return C.cyan,Color3.fromRGB(16,42,52),Color3.fromRGB(24,60,75) end
    if cat=="deep"   then return C.pink,Color3.fromRGB(40,16,42),Color3.fromRGB(60,26,62) end
    return C.sub,C.card,C.cardH
end
for i,isl in ipairs(ISLANDS) do
    local tc,bc,hc=catColor(isl.cat)
    local b=Instance.new("TextButton",tpScroll); b.Size=UDim2.new(1,0,0,26)
    b.BackgroundColor3=bc; b.BorderSizePixel=0; b.Text="📍 "..isl.name
    b.TextColor3=tc; b.Font=Enum.Font.GothamBold; b.TextSize=9; b.TextXAlignment=Enum.TextXAlignment.Left
    b.AutoButtonColor=false; b.LayoutOrder=i
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); pad(b,8,8,0,0)
    b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=hc,TextColor3=C.txt}):Play() end)
    b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=bc,TextColor3=tc}):Play() end)
    b.MouseButton1Click:Connect(function()
        ripple(b,tc); tw(b,{BackgroundColor3=C.accD}):Play(); task.wait(0.12); tw(b,{BackgroundColor3=bc}):Play()
        local ok=tpTo(isl.pos); tpSt.TextColor3=ok and C.grn or C.red; tpSt.Text=(ok and "✅ " or "❌ ")..isl.name
        task.delay(3,function() tpSt.Text="" end)
    end)
end

-- ═══════════════════════════════════════
-- PAGE RODS
-- ═══════════════════════════════════════
local pg4=tabPages["Rods"]
local rodScroll=Instance.new("ScrollingFrame",pg4)
rodScroll.Size=UDim2.new(1,0,0,300); rodScroll.BackgroundTransparency=1; rodScroll.BorderSizePixel=0
rodScroll.ScrollBarThickness=3; rodScroll.ScrollBarImageColor3=C.acc
rodScroll.CanvasSize=UDim2.new(0,0,0,0); rodScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; rodScroll.LayoutOrder=1
local rodLy=Instance.new("UIListLayout",rodScroll); rodLy.SortOrder=Enum.SortOrder.LayoutOrder; rodLy.Padding=UDim.new(0,2)
pad(rodScroll,8,8,6,6)
local rodSt=Instance.new("TextLabel",rodScroll); rodSt.Size=UDim2.new(1,0,0,14); rodSt.BackgroundTransparency=1
rodSt.Text=""; rodSt.TextColor3=C.grn; rodSt.Font=Enum.Font.GothamBold; rodSt.TextSize=8; rodSt.TextXAlignment=Enum.TextXAlignment.Left; rodSt.LayoutOrder=0
for i,rod in ipairs(RODS) do
    local b=Instance.new("TextButton",rodScroll); b.Size=UDim2.new(1,0,0,34)
    b.BackgroundColor3=C.card; b.BorderSizePixel=0; b.Text=""; b.AutoButtonColor=false; b.LayoutOrder=i
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); pad(b,8,8,3,3)
    local nm=Instance.new("TextLabel",b); nm.Size=UDim2.new(1,0,0,13); nm.Position=UDim2.new(0,0,0,0); nm.BackgroundTransparency=1
    nm.Text="🎣 "..rod.name; nm.TextColor3=C.cyan; nm.Font=Enum.Font.GothamBold; nm.TextSize=10; nm.TextXAlignment=Enum.TextXAlignment.Left
    local ll=Instance.new("TextLabel",b); ll.Size=UDim2.new(1,0,0,11); ll.Position=UDim2.new(0,0,0,14); ll.BackgroundTransparency=1
    ll.Text=rod.loc; ll.TextColor3=C.dim; ll.Font=Enum.Font.Gotham; ll.TextSize=8; ll.TextXAlignment=Enum.TextXAlignment.Left
    b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.cardH}):Play() end)
    b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.card}):Play() end)
    b.MouseButton1Click:Connect(function()
        ripple(b,C.cyan); tw(b,{BackgroundColor3=C.accD}):Play(); task.wait(0.12); tw(b,{BackgroundColor3=C.card}):Play()
        local ok=tpTo(rod.pos); rodSt.TextColor3=ok and C.grn or C.red; rodSt.Text=(ok and "✅ TP → " or "❌ ")..rod.name
        task.delay(3,function() rodSt.Text="" end)
    end)
end

-- ═══════════════════════════════════════
-- PAGE MAPS
-- ═══════════════════════════════════════
local pg5=tabPages["Maps"]
local mapF=Instance.new("Frame",pg5)
mapF.Size=UDim2.new(1,0,0,0); mapF.AutomaticSize=Enum.AutomaticSize.Y
mapF.BackgroundColor3=C.card; mapF.BorderSizePixel=0; mapF.LayoutOrder=1
pad(mapF,10,10,8,8)
local mapLy=Instance.new("UIListLayout",mapF); mapLy.SortOrder=Enum.SortOrder.LayoutOrder; mapLy.Padding=UDim.new(0,6)
local mapTitle=Instance.new("TextLabel",mapF); mapTitle.Size=UDim2.new(1,0,0,14); mapTitle.BackgroundTransparency=1
mapTitle.Text="📜  Treasure Maps no inventário"; mapTitle.TextColor3=C.gold; mapTitle.Font=Enum.Font.GothamBold; mapTitle.TextSize=10; mapTitle.TextXAlignment=Enum.TextXAlignment.Left; mapTitle.LayoutOrder=1
local mapInfo=Instance.new("TextLabel",mapF); mapInfo.Size=UDim2.new(1,0,0,11); mapInfo.BackgroundTransparency=1
mapInfo.Text="Leva o mapa no Jack Marrow pra fixar as coords"; mapInfo.TextColor3=C.dim; mapInfo.Font=Enum.Font.Gotham; mapInfo.TextSize=8; mapInfo.TextXAlignment=Enum.TextXAlignment.Left; mapInfo.LayoutOrder=2
local mapRefresh=Instance.new("TextButton",mapF)
mapRefresh.Size=UDim2.new(1,0,0,26); mapRefresh.LayoutOrder=3
mapRefresh.BackgroundColor3=Color3.fromRGB(40,30,12); mapRefresh.BorderSizePixel=0
mapRefresh.Text="🔍  Escanear mapas"; mapRefresh.TextColor3=C.gold; mapRefresh.Font=Enum.Font.GothamBold; mapRefresh.TextSize=9; mapRefresh.AutoButtonColor=false
Instance.new("UICorner",mapRefresh).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",mapRefresh).Color=Color3.fromRGB(100,70,20)
mapRefresh.MouseEnter:Connect(function() tw(mapRefresh,{BackgroundColor3=Color3.fromRGB(55,40,18)}):Play() end)
mapRefresh.MouseLeave:Connect(function() tw(mapRefresh,{BackgroundColor3=Color3.fromRGB(40,30,12)}):Play() end)
mapRefresh.MouseButton1Click:Connect(function() ripple(mapRefresh,C.gold) end)
local quickJack=Instance.new("TextButton",mapF)
quickJack.Size=UDim2.new(1,0,0,24); quickJack.LayoutOrder=4
quickJack.BackgroundColor3=Color3.fromRGB(18,30,48); quickJack.BorderSizePixel=0
quickJack.Text="🏴  TP Jack Marrow (fixar mapas)"; quickJack.TextColor3=C.acc; quickJack.Font=Enum.Font.GothamBold; quickJack.TextSize=9; quickJack.AutoButtonColor=false
Instance.new("UICorner",quickJack).CornerRadius=UDim.new(0,6)
quickJack.MouseEnter:Connect(function() tw(quickJack,{BackgroundColor3=Color3.fromRGB(24,40,64)}):Play() end)
quickJack.MouseLeave:Connect(function() tw(quickJack,{BackgroundColor3=Color3.fromRGB(18,30,48)}):Play() end)
quickJack.MouseButton1Click:Connect(function() ripple(quickJack,C.acc); tpTo(Vector3.new(-2825,215,1515)) end)
local mapListHolder=Instance.new("Frame",mapF)
mapListHolder.Size=UDim2.new(1,0,0,0); mapListHolder.AutomaticSize=Enum.AutomaticSize.Y
mapListHolder.BackgroundTransparency=1; mapListHolder.BorderSizePixel=0; mapListHolder.LayoutOrder=5
local mapListLy=Instance.new("UIListLayout",mapListHolder); mapListLy.SortOrder=Enum.SortOrder.LayoutOrder; mapListLy.Padding=UDim.new(0,3)
local function refreshMaps()
    for _,ch in ipairs(mapListHolder:GetChildren()) do
        if not (ch:IsA("UIListLayout") or ch:IsA("UIPadding")) then ch:Destroy() end
    end
    local maps=getTreasureMaps()
    if #maps==0 then
        local l=Instance.new("TextLabel",mapListHolder); l.Size=UDim2.new(1,0,0,24)
        l.BackgroundTransparency=1; l.Text="Nenhum mapa no inventário"
        l.TextColor3=C.dim; l.Font=Enum.Font.Gotham; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Center; l.LayoutOrder=1
        refreshSize(); return
    end
    for i,m in ipairs(maps) do
        local b=Instance.new("TextButton",mapListHolder); b.Size=UDim2.new(1,0,0,32)
        b.BackgroundColor3=m.fixed and C.card or Color3.fromRGB(30,26,18); b.BorderSizePixel=0; b.Text=""; b.AutoButtonColor=false; b.LayoutOrder=i
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); pad(b,8,8,3,3)
        local nm=Instance.new("TextLabel",b); nm.Size=UDim2.new(1,0,0,12); nm.Position=UDim2.new(0,0,0,0); nm.BackgroundTransparency=1
        nm.Text=(m.fixed and "📜 " or "❔ ")..m.name; nm.TextColor3=m.fixed and C.gold or C.yel; nm.Font=Enum.Font.GothamBold; nm.TextSize=9; nm.TextXAlignment=Enum.TextXAlignment.Left
        local cd=Instance.new("TextLabel",b); cd.Size=UDim2.new(1,0,0,11); cd.Position=UDim2.new(0,0,0,13); cd.BackgroundTransparency=1
        if m.fixed then cd.Text=string.format("X=%d  Y=%d  Z=%d",m.pos.X,m.pos.Y,m.pos.Z); cd.TextColor3=C.cyan
        else cd.Text="→ vai no Jack Marrow (Forsaken) pra fixar"; cd.TextColor3=C.dim end
        cd.Font=Enum.Font.Code; cd.TextSize=8; cd.TextXAlignment=Enum.TextXAlignment.Left
        if m.fixed then
            b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.cardH}):Play() end)
            b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.card}):Play() end)
            local pos=m.pos
            b.MouseButton1Click:Connect(function()
                ripple(b,C.gold); tw(b,{BackgroundColor3=C.gold}):Play(); task.wait(0.12); tw(b,{BackgroundColor3=C.card}):Play()
                tpTo(pos)
            end)
        end
    end
    refreshSize()
end
mapRefresh.MouseButton1Click:Connect(function()
    mapRefresh.Text="⏳  Escaneando..."; task.wait(0.2); refreshMaps(); mapRefresh.Text="🔍  Escanear mapas"
end)

-- ═══════════════════════════════════════
-- PAGE NPCs
-- ═══════════════════════════════════════
local pg3=tabPages["NPCs"]
local rngF=Instance.new("Frame",pg3); rngF.Size=UDim2.new(1,0,0,0); rngF.AutomaticSize=Enum.AutomaticSize.Y
rngF.BackgroundColor3=C.card; rngF.BorderSizePixel=0; rngF.LayoutOrder=1; pad(rngF,10,10,7,7)
local rngLy2=Instance.new("UIListLayout",rngF); rngLy2.SortOrder=Enum.SortOrder.LayoutOrder; rngLy2.Padding=UDim.new(0,4)
local rngRow1=Instance.new("Frame",rngF); rngRow1.Size=UDim2.new(1,0,0,13); rngRow1.BackgroundTransparency=1; rngRow1.LayoutOrder=1
local rngLbl=Instance.new("TextLabel",rngRow1); rngLbl.Size=UDim2.new(1,0,1,0); rngLbl.BackgroundTransparency=1
rngLbl.Text="Scan range: "..npcRange.." studs"; rngLbl.TextColor3=C.acc; rngLbl.Font=Enum.Font.GothamBold; rngLbl.TextSize=8; rngLbl.TextXAlignment=Enum.TextXAlignment.Left
local rngRow2=Instance.new("Frame",rngF); rngRow2.Size=UDim2.new(1,0,0,14); rngRow2.BackgroundTransparency=1; rngRow2.LayoutOrder=2
local rngBg=Instance.new("Frame",rngRow2); rngBg.Size=UDim2.new(1,0,0,4); rngBg.Position=UDim2.new(0,0,0.5,-2)
rngBg.BackgroundColor3=Color3.fromRGB(20,25,45); rngBg.BorderSizePixel=0; Instance.new("UICorner",rngBg).CornerRadius=UDim.new(0,2)
local rPct=(npcRange-1)/999
local rngFill=Instance.new("Frame",rngBg); rngFill.Size=UDim2.new(rPct,0,1,0); rngFill.BackgroundColor3=C.acc; rngFill.BorderSizePixel=0; Instance.new("UICorner",rngFill).CornerRadius=UDim.new(0,2)
local rngKn=Instance.new("Frame",rngBg); rngKn.Size=UDim2.new(0,11,0,11); rngKn.AnchorPoint=Vector2.new(0.5,0.5)
rngKn.Position=UDim2.new(rPct,0,0.5,0); rngKn.BackgroundColor3=Color3.fromRGB(255,255,255); rngKn.BorderSizePixel=0; rngKn.ZIndex=3; Instance.new("UICorner",rngKn).CornerRadius=UDim.new(0,6)
local rngHit=Instance.new("TextButton",rngBg); rngHit.Size=UDim2.new(1,0,0,20); rngHit.Position=UDim2.new(0,0,0.5,-10)
rngHit.BackgroundTransparency=1; rngHit.Text=""; rngHit.AutoButtonColor=false; rngHit.ZIndex=4
local rngDrag=false
rngHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rngDrag=true end end)
rngHit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rngDrag=false end end)
UIS.InputChanged:Connect(function(i)
    if not rngDrag or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local pct=math.clamp((i.Position.X-rngBg.AbsolutePosition.X)/rngBg.AbsoluteSize.X,0,1)
    npcRange=math.floor(1+pct*999); rngFill.Size=UDim2.new(pct,0,1,0); rngKn.Position=UDim2.new(pct,0,0.5,0); rngLbl.Text="Scan range: "..npcRange.." studs"
end)
mkDiv(pg3,2)
local scanBtn=Instance.new("TextButton",pg3); scanBtn.Size=UDim2.new(1,0,0,30); scanBtn.LayoutOrder=3
scanBtn.BackgroundColor3=Color3.fromRGB(16,28,60); scanBtn.BorderSizePixel=0
scanBtn.Text="🔍  Scan Nearby NPCs"; scanBtn.TextColor3=C.acc; scanBtn.Font=Enum.Font.GothamBold; scanBtn.TextSize=9; scanBtn.AutoButtonColor=false
Instance.new("UICorner",scanBtn).CornerRadius=UDim.new(0,7); Instance.new("UIStroke",scanBtn).Color=C.accD
scanBtn.MouseEnter:Connect(function() tw(scanBtn,{BackgroundColor3=Color3.fromRGB(20,36,78)}):Play() end)
scanBtn.MouseLeave:Connect(function() tw(scanBtn,{BackgroundColor3=Color3.fromRGB(16,28,60)}):Play() end)
scanBtn.MouseButton1Click:Connect(function() ripple(scanBtn,C.acc) end)
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
        l.TextColor3=C.dim; l.Font=Enum.Font.Gotham; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Center; l.LayoutOrder=1; return
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
            ripple(b,C.acc); tw(b,{BackgroundColor3=C.accD}):Play(); task.wait(0.12); tw(b,{BackgroundColor3=C.card}):Play()
            tpToNPC(cp); task.delay(0.8,rebuildNPCs)
        end)
    end
end
scanBtn.MouseButton1Click:Connect(function()
    scanBtn.Text="⏳  Scanning..."; task.wait(0.15); rebuildNPCs(); scanBtn.Text="🔍  Scan Nearby NPCs"
end)

-- ═══════════════════════════════════════
-- TOGGLES
-- ═══════════════════════════════════════
local function updateDot()
    local anyOn=noclipOn or speedOn or jumpOn or shakeOn or autoSellOn or autoReelOn
    tw(dot,{BackgroundColor3=anyOn and C.grn or C.dim}):Play()
end

ncSec.togHit.MouseButton1Click:Connect(function()
    noclipOn=not noclipOn; setNoclip(noclipOn); ncSec.setTog(noclipOn)
    tw(fBdr,{Color=noclipOn and C.grn or C.bdr}):Play(); updateDot()
end)
spSec.togHit.MouseButton1Click:Connect(function()
    speedOn=not speedOn; spSec.setTog(speedOn)
    if speedOn then applySpeedOnce(); startSpeedLoop() else stopSpeedLoop() end; updateDot()
end)
hjSec.togHit.MouseButton1Click:Connect(function()
    jumpOn=not jumpOn; hjSec.setTog(jumpOn)
    if jumpOn then startJumpLoop() else stopJumpLoop(); reJumpOn=false; hjSec.setRj(false); stopReJump() end; updateDot()
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
reSec.togHit.MouseButton1Click:Connect(function()
    autoReelOn=not autoReelOn; reSec.setTog(autoReelOn)
    if autoReelOn then startAutoReel() else stopAutoReel() end; updateDot()
end)

sellBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        tw(sellBtn,{BackgroundColor3=Color3.fromRGB(10,44,26)}):Play(); task.wait(0.1)
        tw(sellBtn,{BackgroundColor3=C.sellBg}):Play()
        local ok,msg=sellFromHand()
        sellSt.TextColor3=ok and C.grn or C.red; sellSt.Text=(ok and "✅ " or "❌ ")..msg
        task.wait(3); tw(sellSt,{TextColor3=C.dim}):Play(); sellSt.Text="Waiting..."
    end)
end)
sellAllBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        tw(sellAllBtn,{BackgroundColor3=Color3.fromRGB(10,38,22)}):Play(); task.wait(0.1)
        tw(sellAllBtn,{BackgroundColor3=Color3.fromRGB(14,50,30)}):Play()
        local ok,msg=sellAll()
        sellSt.TextColor3=ok and C.grn or C.red; sellSt.Text=(ok and "✅ " or "❌ ")..msg
        task.wait(3); tw(sellSt,{TextColor3=C.dim}):Play(); sellSt.Text="Waiting..."
    end)
end)
autoTogHit.MouseButton1Click:Connect(function()
    autoSellOn=not autoSellOn
    tw(autoTr,{BackgroundColor3=autoSellOn and C.grn or Color3.fromRGB(22,28,50)}):Play()
    twB(autoKn,{Position=autoSellOn and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
    tw(autoLbl,{TextColor3=autoSellOn and C.txt or C.sub}):Play()
    if autoSellOn then startAutoSell(autoStLbl)
    else stopAutoSell(); autoStLbl.Text="Auto-sell off"; task.delay(2,function() autoStLbl.Text="" end) end
    updateDot()
end)

-- Status loops
task.spawn(function()
    local d={"",".",".","..."}; local i=1
    while true do task.wait(0.2); i=i%4+1
        if shSec.statusLbl then
            if shakeOn then
                shSec.statusLbl.Text=(shakeActive and "● Enter pressing" or "○ waiting shake")..d[i]
                shSec.statusLbl.TextColor3=shakeActive and C.grn or C.yel
            else shSec.statusLbl.Text="" end
        end
    end
end)

-- Status do reel (linha 1) — loop de ativo/aguardando
task.spawn(function()
    local d={"",".",".","..."}; local i=1
    while true do task.wait(0.25); i=i%4+1
        if reSec.statusLbl and autoReelOn then
            if reelActive then
                reSec.statusLbl.Text = "● pescando" .. d[i]
                reSec.statusLbl.TextColor3 = C.grn
            else
                reSec.statusLbl.Text = "○ aguardando UI" .. d[i]
                reSec.statusLbl.TextColor3 = C.dim
            end
        elseif reSec.statusLbl then
            reSec.statusLbl.Text = ""
        end
    end
end)

-- REBIND
local function setupBind(bindBtn,id,getKey,setKey)
    bindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening=id; bindBtn.Text="..."; tw(bindBtn,{TextColor3=C.yel}):Play()
        local conn; conn=UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
            if inp.KeyCode==Enum.KeyCode.Escape then
                bindBtn.Text=getKey().Name; tw(bindBtn,{TextColor3=C.acc}):Play(); listening=nil; conn:Disconnect(); return
            end
            if BLOCKED[inp.KeyCode] then
                bindBtn.Text="invalid!"; tw(bindBtn,{TextColor3=C.red}):Play()
                task.wait(0.8); bindBtn.Text=getKey().Name; tw(bindBtn,{TextColor3=C.acc}):Play(); listening=nil; conn:Disconnect(); return
            end
            setKey(inp.KeyCode); bindBtn.Text=inp.KeyCode.Name
            tw(bindBtn,{TextColor3=C.acc}):Play(); listening=nil; conn:Disconnect()
        end)
    end)
end
setupBind(ncSec.bindBtn,"nc",  function() return ncKey    end,function(k) ncKey=k    end)
setupBind(spSec.bindBtn,"sp",  function() return spKey    end,function(k) spKey=k    end)
setupBind(hjSec.bindBtn,"hj",  function() return hjKey    end,function(k) hjKey=k    end)
setupBind(shSec.bindBtn,"sh",  function() return shakeKey end,function(k) shakeKey=k end)
setupBind(reSec.bindBtn,"re",  function() return reelKey  end,function(k) reelKey=k  end)
setupBind(sellBind,"sell",     function() return sellKey  end,function(k) sellKey=k  end)

-- DRAG
do
    local dragging,dragStart,startPos=false,nil,nil
    header.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=frame.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
        local d=i.Position-dragStart
        frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end)
end

-- HOTKEYS
UIS.InputBegan:Connect(function(inp,gpe)
    if gpe or listening then return end
    local k=inp.KeyCode
    if k==Enum.KeyCode.V then setVisible(not guiVisible)
    elseif k==ncKey    then noclipOn=not noclipOn;setNoclip(noclipOn);ncSec.setTog(noclipOn);tw(fBdr,{Color=noclipOn and C.grn or C.bdr}):Play();updateDot()
    elseif k==spKey    then speedOn=not speedOn;spSec.setTog(speedOn);if speedOn then applySpeedOnce();startSpeedLoop() else stopSpeedLoop() end;updateDot()
    elseif k==hjKey    then jumpOn=not jumpOn;hjSec.setTog(jumpOn);if jumpOn then startJumpLoop() else stopJumpLoop();reJumpOn=false;hjSec.setRj(false);stopReJump() end;updateDot()
    elseif k==shakeKey then shakeOn=not shakeOn;shSec.setTog(shakeOn);if shakeOn then startShake() else stopShake() end;updateDot()
    elseif k==reelKey  then autoReelOn=not autoReelOn;reSec.setTog(autoReelOn);if autoReelOn then startAutoReel() else stopAutoReel() end;updateDot()
    elseif k==sellKey  then
        task.spawn(function()
            local ok,msg=sellFromHand()
            sellSt.TextColor3=ok and C.grn or C.red;sellSt.Text=(ok and "✅ " or "❌ ")..msg
            task.wait(3);tw(sellSt,{TextColor3=C.dim}):Play();sellSt.Text="Waiting..."
        end)
    end
end)

-- INIT
switchTab("Cheats")
task.wait(0.1); refreshSize(); task.wait(0.05)
TweenSvc:Create(frame,TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{
    Position=UDim2.new(0,18,0.5,-180),
    BackgroundTransparency=0,
}):Play()
task.delay(1, refreshMaps)