--[[
    UTILITY v19 — AUTO-REEL REWRITE

    O que mudou vs v18 (APENAS auto-reel):
    • Duty-cycle ao invés de on/off bruto — proporcional à distância do peixe
    • Loop em RunService.Heartbeat (60fps real) — sem task.wait, sem lag
    • Sem switchDelay — sem oscilação de 100ms spammando clique
    • Anti-ricochete nas bordas (cooldown 80ms após cada troca forçada)
    • Sem predição (você pediu)
    • Overlay visual < > , mantido igual ao v18

    Resto do script (cast, shake, TP, sell, maps, learning) = idêntico v18
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local State = {
    flags = {
        noclip = false, speed = false, jump = false, rejump = false,
        shake = false, cast = false, autoSell = false, autoReel = false,
    },
    values = {
        speed = 45, jump = 80, autoSellDelay = 1.5,
        npcRange = 150, castReleasePct = 0.72,
    },
    keys = {
        noclip = Enum.KeyCode.F, speed = Enum.KeyCode.G, jump = Enum.KeyCode.H,
        shake = Enum.KeyCode.J, cast = Enum.KeyCode.U, sell = Enum.KeyCode.K,
        reel = Enum.KeyCode.L, toggleGui = Enum.KeyCode.V,
    },
    runtime = {
        currentTab = "Cheats", guiVisible = true, guiAnimating = false,
        listening = nil, shakeActive = false, reelActive = false,
        castActive = false, castPhase = "idle",
        reelMouseHeld = false, castMouseHeld = false, lastCastEquipAttempt = 0,
    },
    tasks = {},
    connections = {},
}

local UI = { tabs = {}, pages = {}, search = {}, refs = {} }

-- ════════════════════════════════════════
-- REEL PARAMS v19 — duty-cycle based
-- Instead of hold/release times, we store % of cycle to hold
-- at different distances from fish.
-- ════════════════════════════════════════
local ReelParams = {
    duty_far = 0.90,     -- fish far (>30% away): hold 90% of time
    duty_mid = 0.65,     -- fish mid (10-30%): hold 65%
    duty_near = 0.50,    -- fish near (inside barWidth*5%): balance point
    cycle_ms = 45,       -- total cycle duration (ms) — smaller = snappier
    rebound_ms = 80,     -- anti-oscillation cooldown when fish crosses edge
    dead_zone = 0.04,    -- dead zone as fraction of barWidth (center)
}

local LearnHistory = {
    sessions = {}, totalWins = 0, totalLosses = 0,
    lastDiagnosis = "—", adjustCount = 0,
}

local ISLANDS = {
    { name = "Moosewood", pos = Vector3.new(350, 135, 250), cat = "first" },
    { name = "Roslit Bay", pos = Vector3.new(-1600, 130, 500), cat = "first" },
    { name = "Forsaken Shore", pos = Vector3.new(-2750, 130, 1450), cat = "first" },
    { name = "Mushgrove Swamp", pos = Vector3.new(2420, 135, -750), cat = "first" },
    { name = "Snowcap Island", pos = Vector3.new(2625, 135, 2370), cat = "first" },
    { name = "Sunstone Island", pos = Vector3.new(-870, 135, -1100), cat = "first" },
    { name = "Statue of Sovereignty", pos = Vector3.new(35, 135, -1010), cat = "first" },
    { name = "Terrapin Island", pos = Vector3.new(-95, 130, 1875), cat = "first" },
    { name = "Harvesters Spike", pos = Vector3.new(-1260, 135, 1550), cat = "first" },
    { name = "The Arch", pos = Vector3.new(1100, 130, -1250), cat = "first" },
    { name = "Birch Cay", pos = Vector3.new(1650, 130, -2350), cat = "first" },
    { name = "Haddock Rock", pos = Vector3.new(-500, 125, -505), cat = "first" },
    { name = "Earmark Island", pos = Vector3.new(1200, 130, 530), cat = "first" },
    { name = "Desolate Deep", pos = Vector3.new(-800, 130, -3100), cat = "first" },
    { name = "Ancient Isle", pos = Vector3.new(6000, 200, 300), cat = "first" },
    { name = "Grand Reef", pos = Vector3.new(-3555, 150, 510), cat = "first" },
    { name = "Castaway Cliffs", pos = Vector3.new(-1800, 135, -350), cat = "first" },
    { name = "Lost Jungle", pos = Vector3.new(2150, 135, 1850), cat = "first" },
    { name = "Cursed Isle", pos = Vector3.new(3520, 130, -1640), cat = "first" },
    { name = "Treasure Island", pos = Vector3.new(4180, 135, -2470), cat = "first" },
    { name = "Roslit Volcano", pos = Vector3.new(-1900, 165, 315), cat = "first" },
    { name = "★ Waveborne", pos = Vector3.new(10700, 140, -8400), cat = "second" },
    { name = "★ Pine Shoals", pos = Vector3.new(11850, 135, -8000), cat = "second" },
    { name = "★ Emberreach", pos = Vector3.new(2390, 83, -490), cat = "second" },
    { name = "★ Lushgrove", pos = Vector3.new(1133, 105, -560), cat = "second" },
    { name = "★ Azure Lagoon", pos = Vector3.new(3460, 130, -1275), cat = "second" },
    { name = "★ Cursed Shores", pos = Vector3.new(-500, 135, -3800), cat = "second" },
    { name = "⭐ N. Expedition Portal", pos = Vector3.new(-1750, 130, 3750), cat = "deep" },
    { name = "⭐ Northern Summit", pos = Vector3.new(19500, 135, 5300), cat = "deep" },
    { name = "⭐ Atlantis Central", pos = Vector3.new(-4270, -600, 1830), cat = "deep" },
    { name = "⭐ The Depths", pos = Vector3.new(1060, -635, 1315), cat = "deep" },
    { name = "⭐ Mariana's Veil", pos = Vector3.new(-1500, 125, 530), cat = "deep" },
    { name = "⭐ Cultist Lair", pos = Vector3.new(4450, -2000, -4675), cat = "deep" },
    { name = "⭐ The Laboratory", pos = Vector3.new(-4640, 290, 2080), cat = "deep" },
    { name = "⭐ Vertigo", pos = Vector3.new(1230, -490, 600), cat = "deep" },
}

local RODS = {
    { name = "Starter Rod", loc = "Moosewood • grátis", pos = Vector3.new(465, 150, 230) },
    { name = "Lucky Rod", loc = "Moosewood Merchant $500", pos = Vector3.new(465, 150, 230) },
    { name = "Long Rod", loc = "Moosewood Merchant $1.5k", pos = Vector3.new(465, 150, 230) },
    { name = "Fortune Rod", loc = "Roslit Blacksmith $1.5k", pos = Vector3.new(-1515, 140, 760) },
    { name = "Rapid Rod", loc = "Roslit Blacksmith $6k", pos = Vector3.new(-1515, 140, 760) },
    { name = "Steady Rod", loc = "Roslit Blacksmith $12.5k", pos = Vector3.new(-1515, 140, 760) },
    { name = "Magma Rod", loc = "Roslit Orc (Pufferfish)", pos = Vector3.new(-1850, 165, 160) },
    { name = "Enchanted Rod", loc = "Sunstone Merlin $35k", pos = Vector3.new(-930, 225, -990) },
    { name = "Magnet Rod", loc = "Terrapin Shop $15k", pos = Vector3.new(-195, 130, 1930) },
    { name = "Fungal Rod", loc = "Mushgrove Agaric (quest)", pos = Vector3.new(2790, 140, -630) },
    { name = "Kings Rod", loc = "Keepers Altar (end-game)", pos = Vector3.new(1375, -805, -300) },
    { name = "Destiny Rod", loc = "The Arch Caleia $190k", pos = Vector3.new(980, 130, -1230) },
    { name = "Stone Rod", loc = "Ancient Isle $225k", pos = Vector3.new(5500, 145, -315) },
    { name = "Phoenix Rod", loc = "Ancient Eclipse cave", pos = Vector3.new(5950, 270, 890) },
    { name = "Relic Rod", loc = "Archeological Site", pos = Vector3.new(4040, 135, 80) },
    { name = "Arctic Rod", loc = "N. Summit $25k", pos = Vector3.new(19500, 135, 5300) },
    { name = "Avalanche Rod", loc = "N. Frigid Cavern $35k", pos = Vector3.new(20300, 415, 5640) },
    { name = "Summit Rod", loc = "N. Cryogenic $300k", pos = Vector3.new(20000, 780, 5700) },
    { name = "Heaven's Rod", loc = "N. Glacial Grotto $1.75M", pos = Vector3.new(20000, 1040, 5700) },
    { name = "Champions Rod", loc = "Atlantis $80k", pos = Vector3.new(-4450, -600, 1875) },
    { name = "Depthseeker Rod", loc = "Atlantis $40k", pos = Vector3.new(-4450, -600, 1875) },
    { name = "Zeus Rod", loc = "Atlantis Zeus Room $1.7M", pos = Vector3.new(-4300, -630, 2680) },
    { name = "Tempest Rod", loc = "Atlantis Sunken Trial", pos = Vector3.new(-4620, -590, 1840) },
    { name = "Abyssal Specter", loc = "Atlantis Ethereal $1M", pos = Vector3.new(-3915, -650, 1830) },
    { name = "Trident Rod", loc = "Desolate Deep Brine", pos = Vector3.new(-800, 130, -3100) },
    { name = "Rod of the Depths", loc = "The Depths altars", pos = Vector3.new(1060, -635, 1315) },
    { name = "Sunken Rod", loc = "Treasure chest reward", pos = Vector3.new(-2825, 215, 1515) },
    { name = "Carrot Rod", loc = "Lushgrove Carrot Garden 75k", pos = Vector3.new(1310, 130, -945) },
    { name = "Midas Rod", loc = "Emberreach $500k", pos = Vector3.new(2390, 83, -490) },
    { name = "Inferno Rod", loc = "Emberreach Volcano", pos = Vector3.new(2390, 150, -490) },
    { name = "Leviathan Rod", loc = "Cultist Lair end-quest", pos = Vector3.new(4450, -2000, -4675) },
}

local Theme = {
    shell = Color3.fromRGB(8, 11, 19), panel = Color3.fromRGB(14, 18, 31),
    surface = Color3.fromRGB(18, 24, 41), surfaceHover = Color3.fromRGB(24, 32, 54),
    surfaceAlt = Color3.fromRGB(12, 16, 28), accent = Color3.fromRGB(88, 164, 255),
    accentSoft = Color3.fromRGB(48, 94, 190), success = Color3.fromRGB(62, 215, 132),
    danger = Color3.fromRGB(236, 87, 97), warning = Color3.fromRGB(241, 192, 69),
    text = Color3.fromRGB(223, 230, 247), subtext = Color3.fromRGB(156, 170, 201),
    muted = Color3.fromRGB(104, 118, 152), border = Color3.fromRGB(31, 40, 70),
    gold = Color3.fromRGB(255, 191, 74), cyan = Color3.fromRGB(104, 230, 255),
    purple = Color3.fromRGB(152, 108, 255), cast = Color3.fromRGB(92, 255, 191),
    sell = Color3.fromRGB(22, 68, 45), sellHover = Color3.fromRGB(28, 84, 54),
}

local GUI_WIDTH = 226
local HEADER_HEIGHT = 38
local WINDOW_Y_OFFSET = -180

local BLOCKED_KEYS = {
    [Enum.KeyCode.Return] = true, [Enum.KeyCode.Escape] = true,
    [Enum.KeyCode.Tab] = true, [Enum.KeyCode.Backspace] = true,
    [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true,
    [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.RightControl] = true,
    [Enum.KeyCode.LeftAlt] = true, [Enum.KeyCode.RightAlt] = true,
    [Enum.KeyCode.V] = true,
}

local function create(className, props)
    local parent = props.Parent
    props.Parent = nil
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    if parent then object.Parent = parent end
    return object
end

local function addCorner(parent, radius)
    create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius) })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Parent = parent, Color = color,
        Thickness = thickness or 1, Transparency = transparency or 0,
    })
end

local function addGradient(parent, rotation, colors)
    return create("UIGradient", {
        Parent = parent, Rotation = rotation or 0,
        Color = ColorSequence.new(colors),
    })
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        Parent = parent,
        PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0),
    })
end

local function tween(instance, properties, duration, style, direction)
    local info = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tw = TweenService:Create(instance, info, properties)
    tw:Play()
    return tw
end

local function spring(instance, properties)
    local tw = TweenService:Create(instance, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), properties)
    tw:Play()
    return tw
end

local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function character() return LocalPlayer.Character end
local function humanoid() local c = character(); return c and c:FindFirstChildOfClass("Humanoid") end
local function rootPart() local c = character(); return c and c:FindFirstChild("HumanoidRootPart") end
local function heldTool() local c = character(); return c and c:FindFirstChildOfClass("Tool") end

local function setStatus(label, text, color)
    if not label then return end
    if label.Text ~= text then label.Text = text end
    if color and label.TextColor3 ~= color then label.TextColor3 = color end
end

local function startTask(name, callback)
    if State.tasks[name] then task.cancel(State.tasks[name]) end
    State.tasks[name] = task.spawn(callback)
end

local function stopTask(name)
    if State.tasks[name] then
        task.cancel(State.tasks[name])
        State.tasks[name] = nil
    end
end

local function saveLearnData()
    pcall(function()
        LocalPlayer:SetAttribute("RP_duty_far", ReelParams.duty_far)
        LocalPlayer:SetAttribute("RP_duty_mid", ReelParams.duty_mid)
        LocalPlayer:SetAttribute("RP_duty_near", ReelParams.duty_near)
        LocalPlayer:SetAttribute("RP_cycle_ms", ReelParams.cycle_ms)
        LocalPlayer:SetAttribute("RP_rebound_ms", ReelParams.rebound_ms)
        LocalPlayer:SetAttribute("LH_wins", LearnHistory.totalWins)
        LocalPlayer:SetAttribute("LH_losses", LearnHistory.totalLosses)
        LocalPlayer:SetAttribute("LH_adjusts", LearnHistory.adjustCount)
        LocalPlayer:SetAttribute("LH_last", LearnHistory.lastDiagnosis)
    end)
end

local function loadLearnData()
    pcall(function()
        local function getAttr(key, def)
            local v = LocalPlayer:GetAttribute(key)
            if v == nil then return def end
            return v
        end
        ReelParams.duty_far = getAttr("RP_duty_far", 0.90)
        ReelParams.duty_mid = getAttr("RP_duty_mid", 0.65)
        ReelParams.duty_near = getAttr("RP_duty_near", 0.50)
        ReelParams.cycle_ms = getAttr("RP_cycle_ms", 45)
        ReelParams.rebound_ms = getAttr("RP_rebound_ms", 80)
        LearnHistory.totalWins = getAttr("LH_wins", 0)
        LearnHistory.totalLosses = getAttr("LH_losses", 0)
        LearnHistory.adjustCount = getAttr("LH_adjusts", 0)
        LearnHistory.lastDiagnosis = getAttr("LH_last", "—")
    end)
end

-- ════════════════════════════════════════
-- LEARNING v19 — adjusts duty cycles instead of hold/release times
-- ════════════════════════════════════════
local function applyLearning(won, diagnosis)
    local step = 0.025
    local message = ""

    if not won then
        local total = math.max(diagnosis.timesFar + diagnosis.timesMid + diagnosis.timesInside, 1)
        local farPct = diagnosis.timesFar / total
        local overshootPct = diagnosis.timesOvershoots / math.max(diagnosis.timesInside + diagnosis.timesMid, 1)

        if farPct > 0.5 then
            ReelParams.duty_far = clamp(ReelParams.duty_far + step, 0.60, 0.98)
            message = "lento -> aumentei duty far"
        elseif overshootPct > 0.3 then
            ReelParams.duty_far = clamp(ReelParams.duty_far - step, 0.60, 0.98)
            ReelParams.duty_mid = clamp(ReelParams.duty_mid - step * 0.7, 0.35, 0.85)
            message = "rápido demais -> reduzi duty"
        elseif diagnosis.timesInside > 0 and overshootPct < 0.1 then
            ReelParams.duty_mid = clamp(ReelParams.duty_mid + step * 0.5, 0.35, 0.85)
            message = "timing médio refinado"
        else
            ReelParams.duty_near = clamp(ReelParams.duty_near + step * 0.3, 0.35, 0.70)
            message = "ajuste leve centro"
        end

        LearnHistory.totalLosses = LearnHistory.totalLosses + 1
    else
        if diagnosis.timesOvershoots > 2 then
            ReelParams.duty_far = clamp(ReelParams.duty_far - step * 0.3, 0.60, 0.98)
            message = "ganhou com overshoot -> refinando"
        else
            message = "perfeito ✓"
        end
        LearnHistory.totalWins = LearnHistory.totalWins + 1
    end

    LearnHistory.adjustCount = LearnHistory.adjustCount + 1
    LearnHistory.lastDiagnosis = (won and "✅ " or "❌ ") .. message
    table.insert(LearnHistory.sessions, 1, { won = won, msg = message, time = tick() })
    if #LearnHistory.sessions > 20 then table.remove(LearnHistory.sessions) end
    saveLearnData()
end

local function getRecentScore(amount)
    amount = amount or 10
    local wins, total = 0, 0
    for i = 1, math.min(amount, #LearnHistory.sessions) do
        total += 1
        if LearnHistory.sessions[i].won then wins += 1 end
    end
    return wins, total
end

local function bindConnection(name, conn)
    if State.connections[name] then State.connections[name]:Disconnect() end
    State.connections[name] = conn
end

local function disconnectConnection(name)
    if State.connections[name] then
        State.connections[name]:Disconnect()
        State.connections[name] = nil
    end
end

local function updateActivityDot()
    local any = State.flags.noclip or State.flags.speed or State.flags.jump
        or State.flags.shake or State.flags.cast or State.flags.autoSell or State.flags.autoReel
    if UI.refs.activityDot then
        tween(UI.refs.activityDot, { BackgroundColor3 = any and Theme.success or Theme.muted }, 0.15)
    end
end

local function teleportTo(position)
    local root = rootPart()
    if not root then return false end
    root.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
    return true
end

local function setNoclip(enabled)
    State.flags.noclip = enabled
    disconnectConnection("noclip")
    if enabled then
        bindConnection("noclip", RunService.Stepped:Connect(function()
            local c = character()
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end))
    else
        local c = character()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
            end
        end
    end
end

local function applySpeedOnce()
    local h = humanoid()
    if h then h.WalkSpeed = State.flags.speed and State.values.speed or 16 end
end

local function startSpeedLoop()
    disconnectConnection("speed")
    bindConnection("speed", RunService.Heartbeat:Connect(function()
        if not State.flags.speed then disconnectConnection("speed"); return end
        local h = humanoid()
        if h and h.WalkSpeed ~= State.values.speed then h.WalkSpeed = State.values.speed end
    end))
end

local function stopSpeedLoop()
    disconnectConnection("speed")
    local h = humanoid(); if h then h.WalkSpeed = 16 end
end

local function startJumpLoop()
    disconnectConnection("jump")
    bindConnection("jump", RunService.Heartbeat:Connect(function()
        if not State.flags.jump then disconnectConnection("jump"); return end
        local h = humanoid()
        if h then
            h.UseJumpPower = true
            if h.JumpPower ~= State.values.jump then h.JumpPower = State.values.jump end
        end
    end))
end

local function stopJumpLoop()
    disconnectConnection("jump")
    local h = humanoid(); if h then h.JumpPower = 50 end
end

local function startRejumpLoop()
    disconnectConnection("rejump")
    bindConnection("rejump", RunService.Heartbeat:Connect(function()
        if not State.flags.rejump or not State.flags.jump then
            disconnectConnection("rejump"); return
        end
        local h = humanoid()
        if h and h.FloorMaterial ~= Enum.Material.Air then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.15)
        end
    end))
end

local function stopRejumpLoop() disconnectConnection("rejump") end

local function shakeUiVisible()
    local g = PlayerGui:FindFirstChild("shakeui")
    return g and g.Enabled ~= false
end

local function tapKey(kc)
    pcall(function() VirtualInputManager:SendKeyEvent(true, kc, false, game) end)
    task.wait(0.02)
    pcall(function() VirtualInputManager:SendKeyEvent(false, kc, false, game) end)
end

local function pressEnter() tapKey(Enum.KeyCode.Return) end
local function equipRodSlot() tapKey(Enum.KeyCode.One) end

local function startShake()
    startTask("shake", function()
        while State.flags.shake do
            if shakeUiVisible() then
                State.runtime.shakeActive = true
                pressEnter()
                task.wait(0.05 + math.random() * 0.03)
            else
                State.runtime.shakeActive = false
                task.wait(0.08)
            end
        end
        State.runtime.shakeActive = false
    end)
end

local function stopShake()
    State.runtime.shakeActive = false
    stopTask("shake")
end

local function sendMouseDown(x, y)
    if State.runtime.castMouseHeld then return end
    pcall(function() VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true, game, 0) end)
    State.runtime.castMouseHeld = true
end

local function sendMouseUp(x, y)
    if not State.runtime.castMouseHeld then return end
    pcall(function() VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0) end)
    State.runtime.castMouseHeld = false
end

local function forceCastRelease()
    pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
    State.runtime.castMouseHeld = false
end

local function findGuiByPatterns(names, includes, excludes)
    for _, name in ipairs(names) do
        local g = PlayerGui:FindFirstChild(name)
        if g and g:IsA("ScreenGui") and g.Enabled ~= false then return g end
    end
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            local ln = g.Name:lower()
            local matched = false
            for _, p in ipairs(includes) do if ln:find(p) then matched = true; break end end
            if matched then
                local blocked = false
                for _, p in ipairs(excludes or {}) do if ln:find(p) then blocked = true; break end end
                if not blocked then return g end
            end
        end
    end
    return nil
end

local function rectContains(parent, child)
    local pp, ps = parent.AbsolutePosition, parent.AbsoluteSize
    local cp, cs = child.AbsolutePosition, child.AbsoluteSize
    return cp.X >= pp.X - 2 and cp.Y >= pp.Y - 2
        and cp.X + cs.X <= pp.X + ps.X + 2
        and cp.Y + cs.Y <= pp.Y + ps.Y + 2
end

local function findCastUI()
    return findGuiByPatterns(
        { "castui", "CastUI", "castbar", "CastBar", "powerui", "PowerUI", "chargeui", "ChargeUI", "castingui", "CastingUI", "throwui", "ThrowUI", "powerbar", "PowerBar" },
        { "cast", "power", "charge", "throw", "launch" },
        { "shake", "reel", "fish" }
    )
end

local function findCastBar(castGui)
    local bestBar, bestBarScore = nil, -math.huge
    local greenCandidates = {}

    for _, d in ipairs(castGui:GetDescendants()) do
        if d:IsA("Frame") and d.Visible then
            local sz = d.AbsoluteSize
            local ln = d.Name:lower()

            if sz.Y > 36 and sz.X > 6 and sz.X < 100 then
                local ratio = sz.Y / math.max(sz.X, 1)
                if ratio > 1.5 then
                    local score = ratio * 3 + sz.Y * 0.03
                    if ln:find("bar") or ln:find("meter") or ln:find("power") then score += 4 end
                    if score > bestBarScore then bestBarScore = score; bestBar = d end
                end
            end

            local c = d.BackgroundColor3
            if c.G > c.R * 1.15 and c.G > c.B * 1.10 and c.G > 0.2 then
                table.insert(greenCandidates, d)
            elseif ln:find("fill") or ln:find("progress") or ln:find("green") then
                table.insert(greenCandidates, d)
            end
        end
    end

    if not bestBar then return nil, nil end

    local bestFill, bestFillScore = nil, -math.huge
    for _, c in ipairs(greenCandidates) do
        if c.Parent and rectContains(bestBar, c) then
            local sz = c.AbsoluteSize
            local score = sz.Y + sz.X * 0.2
            if c.Parent == bestBar then score += 20 end
            if score > bestFillScore then bestFillScore = score; bestFill = c end
        end
    end

    return bestBar, bestFill
end

local function getCastProgress(outer, fill)
    if not outer or not fill then return 0 end
    local bh = math.max(outer.AbsoluteSize.Y, 1)
    return math.clamp(fill.AbsoluteSize.Y / bh, 0, 1)
end

local function startCast()
    forceCastRelease()
    State.runtime.lastCastEquipAttempt = 0
    State.runtime.castActive = false
    State.runtime.castPhase = "idle"
    local primeStartedAt = 0
    local cycleLocked = false
    local clearSince = 0

    local function hasFishingPhaseUI()
        if shakeUiVisible() then return true end
        for _, n in ipairs({ "reelui", "ReelUI", "fishingrod", "FishingRod", "reelbar", "ReelBar", "Fishing", "FishingBar", "FishingUI" }) do
            local g = PlayerGui:FindFirstChild(n)
            if g and g.Enabled ~= false then return true end
        end
        for _, g in ipairs(PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled then
                local ln = g.Name:lower()
                if (ln:find("reel") or ln:find("fish")) and not ln:find("shake") and not ln:find("cast") then
                    return true
                end
            end
        end
        return false
    end

    startTask("cast", function()
        while State.flags.cast do
            local castGui = findCastUI()
            local busy = hasFishingPhaseUI()

            if castGui and castGui.Enabled and not cycleLocked then
                local outer, fill = findCastBar(castGui)
                if outer and fill then
                    local cx = outer.AbsolutePosition.X + outer.AbsoluteSize.X * 0.5
                    local cy = outer.AbsolutePosition.Y + outer.AbsoluteSize.Y * 0.5

                    State.runtime.castActive = true
                    State.runtime.castPhase = "holding"
                    sendMouseDown(cx, cy)

                    local elapsed, timeout = 0, 3.5
                    while State.flags.cast and elapsed < timeout do
                        task.wait(0.02)
                        elapsed += 0.02
                        outer, fill = findCastBar(castGui)
                        local progress = getCastProgress(outer, fill)
                        if progress >= State.values.castReleasePct then break end
                        if not castGui.Parent or castGui.Enabled == false then break end
                    end

                    State.runtime.castPhase = "releasing"
                    sendMouseUp(cx, cy)
                    State.runtime.castActive = false
                    State.runtime.castPhase = "cooldown"
                    cycleLocked = true
                    clearSince = 0
                    task.wait(0.45 + math.random() * 0.20)
                else
                    forceCastRelease()
                    State.runtime.castActive = false
                    State.runtime.castPhase = "searching"
                    task.wait(0.08)
                end
            elseif cycleLocked or busy then
                forceCastRelease()
                State.runtime.castActive = false
                State.runtime.castPhase = "cooldown"
                if busy or (castGui and castGui.Enabled) then
                    clearSince = 0; cycleLocked = true
                else
                    clearSince += 0.10
                    if clearSince >= 1.20 then
                        cycleLocked = false
                        State.runtime.castPhase = "idle"
                    end
                end
                task.wait(0.10)
            else
                State.runtime.castActive = false
                State.runtime.castPhase = "arming"
                local cam = workspace.CurrentCamera
                local cx = cam and (cam.ViewportSize.X * 0.5) or 400
                local cy = cam and (cam.ViewportSize.Y * 0.5) or 300

                if tick() - State.runtime.lastCastEquipAttempt >= 0.90 then
                    State.runtime.lastCastEquipAttempt = tick()
                    equipRodSlot()
                end

                if (not State.runtime.castMouseHeld) or (tick() - primeStartedAt >= 1.35) then
                    if State.runtime.castMouseHeld then
                        sendMouseUp(cx, cy)
                        task.wait(0.12)
                    end
                    sendMouseDown(cx, cy)
                    primeStartedAt = tick()
                end
                task.wait(0.08)
            end
        end

        forceCastRelease()
        State.runtime.castActive = false
        State.runtime.castPhase = "idle"
    end)
end

local function stopCast()
    State.flags.cast = false
    forceCastRelease()
    State.runtime.lastCastEquipAttempt = 0
    State.runtime.castActive = false
    State.runtime.castPhase = "idle"
    stopTask("cast")
end

-- ════════════════════════════════════════
-- AUTO-REEL v19 — DUTY CYCLE REWRITE
-- ════════════════════════════════════════
local function findReelUI()
    for _, n in ipairs({ "reelui", "ReelUI", "fishingrod", "FishingRod", "reelbar", "ReelBar", "Fishing", "FishingBar", "FishingUI" }) do
        local g = PlayerGui:FindFirstChild(n)
        if g and g.Enabled ~= false then return g end
    end
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            local ln = g.Name:lower()
            if (ln:find("reel") or ln:find("fish")) and not ln:find("shake") then return g end
        end
    end
    return nil
end

local function findReelElements(reelGui)
    local pb, fb
    for _, d in ipairs(reelGui:GetDescendants()) do
        if d:IsA("GuiObject") and d.Visible then
            local ln = d.Name:lower()
            if not pb and (ln == "playerbar" or ln == "player" or ln:find("playerbar")) then
                pb = d
            elseif not fb and (ln == "fish" or ln == "fishbar" or ln == "fishicon" or ln:find("fish") or ln:find("target")) then
                fb = d
            end
        end
    end
    return pb, fb
end

local function detectRewardGui()
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            local ln = g.Name:lower()
            if ln:find("reward") or ln:find("catch") or ln:find("result") or ln:find("caught") then
                return true, "win"
            end
            if ln:find("fail") or ln:find("escape") or ln:find("lost") then
                return true, "lose"
            end
        end
    end
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            for _, d in ipairs(g:GetDescendants()) do
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

local function reelMousePress(x, y)
    if State.runtime.reelMouseHeld then return end
    pcall(function() VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true, game, 0) end)
    State.runtime.reelMouseHeld = true
end

local function reelMouseRelease(x, y)
    if not State.runtime.reelMouseHeld then return end
    pcall(function() VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0) end)
    State.runtime.reelMouseHeld = false
end

local function reelForceRelease()
    pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
    State.runtime.reelMouseHeld = false
end

local function getOrCreateReelOverlay(reelGui)
    local overlay = reelGui:FindFirstChild("UtilityReelOverlay")
    if overlay then return overlay end

    overlay = create("Frame", {
        Parent = reelGui, Name = "UtilityReelOverlay",
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 19,
    })

    local function makeMarker(name, text, color)
        return create("TextLabel", {
            Parent = overlay, Name = name,
            Size = UDim2.new(0, 14, 0, 14), BackgroundTransparency = 1,
            Text = text, TextColor3 = color,
            Font = Enum.Font.Code, TextSize = 14,
            TextStrokeTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false, ZIndex = 20,
        })
    end

    makeMarker("Left", "<", Theme.warning)
    makeMarker("Right", ">", Theme.warning)
    makeMarker("Fish", ",", Theme.cast)
    return overlay
end

local function hideReelOverlay(reelGui)
    if not reelGui then return end
    local overlay = reelGui:FindFirstChild("UtilityReelOverlay")
    if not overlay then return end
    for _, ch in ipairs(overlay:GetChildren()) do
        if ch:IsA("TextLabel") then ch.Visible = false end
    end
end

local function updateReelOverlay(reelGui, pb, fb)
    local overlay = getOrCreateReelOverlay(reelGui)
    local l = overlay:FindFirstChild("Left")
    local r = overlay:FindFirstChild("Right")
    local f = overlay:FindFirstChild("Fish")
    if not (l and r and f and pb and fb) then
        hideReelOverlay(reelGui); return
    end

    local bl = pb.AbsolutePosition.X
    local br = pb.AbsolutePosition.X + pb.AbsoluteSize.X
    local bb = pb.AbsolutePosition.Y + pb.AbsoluteSize.Y
    local fx = fb.AbsolutePosition.X + fb.AbsoluteSize.X * 0.5
    local fy = fb.AbsolutePosition.Y + fb.AbsoluteSize.Y

    l.Position = UDim2.fromOffset(math.floor(bl - 7), math.floor(bb + 1))
    l.Visible = true
    r.Position = UDim2.fromOffset(math.floor(br - 7), math.floor(bb + 1))
    r.Visible = true
    f.Position = UDim2.fromOffset(math.floor(fx - 7), math.floor(fy - 1))
    f.Visible = true
end

-- ════════════════════════════════════════
-- CORE FIX v19: duty-cycle loop
--
-- How it works:
-- 1. Runs every Heartbeat (~16ms)
-- 2. Calculates fish offset from player bar center (-1 to +1)
-- 3. Converts offset to duty cycle (% of time mouse should be down)
-- 4. Within each cycle (45ms), mouse is down for (duty*cycle)ms
-- 5. No switchDelay/oscillation — pure time-based modulation
-- 6. Anti-rebound: if fish crosses center, lock state for 80ms
-- ════════════════════════════════════════
local function startAutoReel()
    reelForceRelease()
    State.runtime.reelActive = false

    startTask("autoReel", function()
        local wasActive = false
        local sessionStart = 0
        local sessionDiag

        -- Duty-cycle state
        local cycleStartTime = tick()
        local lastFishSide = 0  -- -1 left, 0 center, +1 right
        local reboundUntil = 0  -- timestamp until which state is locked

        while State.flags.autoReel do
            local reelGui = findReelUI()

            if reelGui then
                if not wasActive then
                    wasActive = true
                    sessionStart = tick()
                    sessionDiag = {
                        timesFar = 0, timesOvershoots = 0,
                        timesInside = 0, timesMid = 0,
                        startTime = tick(),
                    }
                    cycleStartTime = tick()
                    lastFishSide = 0
                    reboundUntil = 0
                end

                local pb, fb = findReelElements(reelGui)
                if not pb or not fb then
                    reelForceRelease()
                    hideReelOverlay(reelGui)
                    State.runtime.reelActive = false
                    task.wait(0.05)
                else
                    State.runtime.reelActive = true

                    local barLeft = pb.AbsolutePosition.X
                    local barRight = pb.AbsolutePosition.X + pb.AbsoluteSize.X
                    local barWidth = math.max(pb.AbsoluteSize.X, 1)
                    local barCenter = barLeft + barWidth * 0.5
                    local barY = pb.AbsolutePosition.Y + pb.AbsoluteSize.Y * 0.5
                    local fishX = fb.AbsolutePosition.X + fb.AbsoluteSize.X * 0.5

                    -- offset: -1 (far left) to +1 (far right), normalized to half barWidth
                    local rawOffset = (fishX - barCenter) / (barWidth * 0.5)
                    local offset = clamp(rawOffset, -1.2, 1.2)
                    local absOffset = math.abs(offset)
                    local fishInside = fishX >= barLeft and fishX <= barRight

                    -- Diagnosis for learning
                    if sessionDiag then
                        if fishInside then
                            sessionDiag.timesInside += 1
                        elseif absOffset < 0.5 then
                            sessionDiag.timesMid += 1
                        else
                            sessionDiag.timesFar += 1
                        end
                        if absOffset > 1.1 then
                            sessionDiag.timesOvershoots += 1
                        end
                    end

                    updateReelOverlay(reelGui, pb, fb)

                    -- ───────────────────────────────
                    -- DUTY CYCLE CALCULATION
                    -- ───────────────────────────────
                    -- offset = -1 (esquerda total) → duty = 0 (solta 100%)
                    -- offset = +1 (direita total) → duty = 1 (segura 100%)
                    -- offset ≈ 0 (centro) → duty ≈ duty_near (equilíbrio)
                    -- Dead zone: if within dead_zone of center, use exactly duty_near

                    local duty
                    if absOffset < ReelParams.dead_zone then
                        -- Dead zone — no agitation
                        duty = ReelParams.duty_near
                    elseif offset > 0 then
                        -- Fish is right of center → hold more
                        if absOffset < 0.3 then
                            -- Near: smooth transition near → mid
                            duty = ReelParams.duty_near + (ReelParams.duty_mid - ReelParams.duty_near) * (absOffset / 0.3)
                        elseif absOffset < 0.7 then
                            -- Mid → far transition
                            duty = ReelParams.duty_mid + (ReelParams.duty_far - ReelParams.duty_mid) * ((absOffset - 0.3) / 0.4)
                        else
                            duty = ReelParams.duty_far
                        end
                    else
                        -- Fish is left of center → release more (invert duty)
                        if absOffset < 0.3 then
                            duty = ReelParams.duty_near - (ReelParams.duty_mid - ReelParams.duty_near) * (absOffset / 0.3)
                        elseif absOffset < 0.7 then
                            duty = (1 - ReelParams.duty_mid) - (ReelParams.duty_far - ReelParams.duty_mid) * ((absOffset - 0.3) / 0.4)
                        else
                            duty = 1 - ReelParams.duty_far
                        end
                    end

                    duty = clamp(duty, 0, 1)

                    -- ───────────────────────────────
                    -- ANTI-REBOUND (fix spam direita)
                    -- ───────────────────────────────
                    -- If fish just crossed center, lock the desired state
                    -- for rebound_ms. Prevents oscillation when player bar
                    -- overshoots and fish appears briefly on the other side.
                    local fishSide = fishX > barCenter + barWidth * 0.02 and 1
                        or (fishX < barCenter - barWidth * 0.02 and -1 or 0)
                    if fishSide ~= 0 and fishSide ~= lastFishSide and lastFishSide ~= 0 then
                        reboundUntil = tick() + (ReelParams.rebound_ms / 1000)
                    end
                    if fishSide ~= 0 then lastFishSide = fishSide end

                    -- ───────────────────────────────
                    -- DRIVE MOUSE BASED ON DUTY CYCLE
                    -- ───────────────────────────────
                    local now = tick()
                    local cyclePhase = ((now - cycleStartTime) * 1000) % ReelParams.cycle_ms
                    local holdThreshold = duty * ReelParams.cycle_ms
                    local shouldHold = cyclePhase < holdThreshold

                    -- During rebound: override with whatever state matches fishSide
                    if now < reboundUntil then
                        if fishSide > 0 then shouldHold = true
                        elseif fishSide < 0 then shouldHold = false end
                    end

                    if shouldHold and not State.runtime.reelMouseHeld then
                        reelMousePress(barCenter, barY)
                    elseif not shouldHold and State.runtime.reelMouseHeld then
                        reelMouseRelease(barCenter, barY)
                    end

                    -- Yield to next frame (Heartbeat = ~16ms @ 60fps)
                    RunService.Heartbeat:Wait()
                end
            else
                -- No reel UI visible
                if State.runtime.reelMouseHeld then reelForceRelease() end
                State.runtime.reelActive = false
                lastFishSide = 0
                reboundUntil = 0

                if wasActive then
                    wasActive = false
                    hideReelOverlay(reelGui)

                    -- Detect win/lose
                    local won, detected = false, false
                    for _ = 1, 20 do
                        task.wait(0.1)
                        local found, result = detectRewardGui()
                        if found then
                            won = result == "win"
                            detected = true
                            break
                        end
                    end
                    if not detected then won = (tick() - sessionStart) > 3.0 end

                    if sessionDiag then
                        applyLearning(won, sessionDiag)
                        sessionDiag = nil
                    end

                    if UI.refs.reelScore then
                        local wins, total = getRecentScore(10)
                        local trend = ""
                        if total > 0 then
                            if wins >= total * 0.7 then trend = " ↑"
                            elseif wins <= total * 0.3 then trend = " ↓"
                            else trend = " →" end
                        end
                        UI.refs.reelScore.Text = string.format("Score %d/%d%s • %s", wins, total, trend, LearnHistory.lastDiagnosis)
                        UI.refs.reelScore.TextColor3 = won and Theme.success or Theme.warning
                    end

                    task.wait(1.5)
                else
                    task.wait(0.08)
                end
            end
        end

        reelForceRelease()
        State.runtime.reelActive = false
    end)
end

local function stopAutoReel()
    State.flags.autoReel = false
    State.runtime.reelActive = false
    reelForceRelease()
    hideReelOverlay(findReelUI())
    stopTask("autoReel")
end

-- ════════════════════════════════════════
-- SELL / MAPS / NPCs (igual v18)
-- ════════════════════════════════════════
local function getTreasureMaps()
    local maps = {}
    local function scan(cont)
        if not cont then return end
        for _, t in ipairs(cont:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("treasure") or t.Name:lower():find("map")) then
                local x, y, z
                for _, a in ipairs({ "X", "x", "PosX", "CoordX", "TargetX" }) do
                    local v = t:GetAttribute(a); if v then x = v; break end
                end
                for _, a in ipairs({ "Y", "y", "PosY", "CoordY", "TargetY" }) do
                    local v = t:GetAttribute(a); if v then y = v; break end
                end
                for _, a in ipairs({ "Z", "z", "PosZ", "CoordZ", "TargetZ" }) do
                    local v = t:GetAttribute(a); if v then z = v; break end
                end
                if not (x and y and z) then
                    for _, d in ipairs(t:GetDescendants()) do
                        if d:IsA("Vector3Value") then
                            x = d.Value.X; y = d.Value.Y; z = d.Value.Z; break
                        end
                        if d:IsA("StringValue") then
                            local sx, sy, sz = d.Value:match("(%-?%d+)[,%s]+(%-?%d+)[,%s]+(%-?%d+)")
                            if sx then x = tonumber(sx); y = tonumber(sy); z = tonumber(sz); break end
                        end
                    end
                end
                if x and y and z then
                    table.insert(maps, { name = t.Name, pos = Vector3.new(x, y, z), fixed = true, tool = t })
                else
                    table.insert(maps, { name = t.Name .. " (não fixado)", pos = nil, fixed = false, tool = t })
                end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    if heldTool() and (heldTool().Name:lower():find("treasure") or heldTool().Name:lower():find("map")) then
        scan(LocalPlayer.Character)
    end
    return maps
end

local function trySellTool(t)
    if not t then return false, "no_tool" end
    local ev = ReplicatedStorage:FindFirstChild("events")
        or ReplicatedStorage:FindFirstChild("Events")
        or ReplicatedStorage:FindFirstChild("Remotes")
    if ev then
        for _, n in ipairs({ "sell", "Sell", "appraise", "Appraise", "sellfish", "SellFish", "SellItem", "appraiseFish", "FishSell", "submitFish", "cashIn" }) do
            local r = ev:FindFirstChild(n)
            if r then
                if r:IsA("RemoteEvent") then
                    pcall(function() r:FireServer(t) end)
                    return true, "RE:" .. n
                end
                if r:IsA("RemoteFunction") then
                    local ok = pcall(function() r:InvokeServer(t) end)
                    if ok then return true, "RF:" .. n end
                end
            end
        end
        for _, r in ipairs(ev:GetDescendants()) do
            local ln = r.Name:lower()
            if (ln:find("sell") or ln:find("appraise") or ln:find("submit") or ln:find("cash")) and r:IsA("RemoteEvent") then
                pcall(function() r:FireServer(t) end)
                return true, "RE:" .. r.Name
            end
        end
    end
    for _, o in ipairs(PlayerGui:GetDescendants()) do
        if o:IsA("GuiButton") and o.Visible then
            local ln = o.Name:lower()
            if ln:find("sell") or ln:find("appraise") or ln:find("submit") then
                local sz = o.AbsoluteSize
                if sz.X > 2 and sz.Y > 2 then
                    pcall(function() o.MouseButton1Click:Fire() end)
                    return true, "GUI:" .. o.Name
                end
            end
        end
    end
    pcall(function() t:Activate() end)
    return false, "no_method"
end

local function sellFromHand()
    local t = heldTool()
    if not t then return false, "No item in hand" end
    return trySellTool(t)
end

local function sellAll()
    local sold, failed = 0, 0
    local items = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not (t.Name:lower():find("treasure") or t.Name:lower():find("map")) then
                table.insert(items, t)
            end
        end
    end
    local t = heldTool()
    if t and not (t.Name:lower():find("treasure") or t.Name:lower():find("map")) then
        table.insert(items, t)
    end
    for _, i in ipairs(items) do
        local ok = trySellTool(i)
        if ok then sold += 1 else failed += 1 end
        task.wait(0.15)
    end
    if sold == 0 and failed == 0 then return false, "Inventory empty" end
    return true, "Sold " .. sold .. (failed > 0 and (" | Failed " .. failed) or "")
end

local function startAutoSell()
    startTask("autoSell", function()
        while State.flags.autoSell do
            local ok, msg = sellAll()
            setStatus(UI.refs.autoSellStatus, (ok and "✅ " or "⏳ ") .. msg, ok and Theme.success or Theme.warning)
            task.wait(State.values.autoSellDelay)
        end
        setStatus(UI.refs.autoSellStatus, "Auto-sell off", Theme.muted)
    end)
end

local function stopAutoSell() stopTask("autoSell") end

local function getNearbyNPCs()
    local r = rootPart()
    if not r then return {} end
    local res = {}
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o ~= LocalPlayer.Character then
            local h = o:FindFirstChildOfClass("Humanoid")
            local p = o:FindFirstChild("HumanoidRootPart") or o:FindFirstChildOfClass("BasePart")
            if h and p then
                local d = (r.Position - p.Position).Magnitude
                if d <= State.values.npcRange then
                    table.insert(res, { name = o.Name, part = p, dist = math.floor(d) })
                end
            end
        end
    end
    table.sort(res, function(a, b) return a.dist < b.dist end)
    return res
end

local function teleportToNPC(part)
    local r = rootPart()
    if not r then return end
    r.CFrame = CFrame.new((part.CFrame * CFrame.new(0, 0, -3.5)).Position + Vector3.new(0, 3, 0))
end

local function createRipple(btn, color)
    local r = create("Frame", {
        Parent = btn, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = color or Color3.new(1, 1, 1),
        BackgroundTransparency = 0.68, BorderSizePixel = 0,
        ZIndex = btn.ZIndex + 1,
    })
    addCorner(r, 999)
    local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.2
    local tw = TweenService:Create(r, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, sz, 0, sz), BackgroundTransparency = 1,
    })
    tw:Play()
    tw.Completed:Connect(function() r:Destroy() end)
end

local function makeCard(parent, order, alt)
    local c = create("Frame", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = alt and Theme.surfaceAlt or Theme.surface,
        BorderSizePixel = 0,
    })
    addCorner(c, 10)
    addStroke(c, Theme.border, 1, 0.12)
    addPadding(c, 8, 8, 7, 7)
    create("UIListLayout", {
        Parent = c, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    })
    return c
end

local function makeDivider(parent, order)
    return create("Frame", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.border, BorderSizePixel = 0,
    })
end

local function makeToggle(tParent, activeColor)
    local track = create("Frame", {
        Parent = tParent, Size = UDim2.new(0, 36, 0, 18),
        BackgroundColor3 = Color3.fromRGB(24, 31, 55), BorderSizePixel = 0,
    })
    addCorner(track, 9)
    addStroke(track, Theme.border, 1)
    local knob = create("Frame", {
        Parent = track, Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 3, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(241, 245, 255),
        BorderSizePixel = 0,
    })
    addCorner(knob, 999)
    local hit = create("TextButton", {
        Parent = track, Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 4,
    })
    local function setState(on)
        tween(track, { BackgroundColor3 = on and activeColor or Color3.fromRGB(24, 31, 55) }, 0.16)
        spring(knob, { Position = on and UDim2.new(0, 21, 0.5, -6) or UDim2.new(0, 3, 0.5, -6) })
    end
    return { track = track, knob = knob, hit = hit, set = setState }
end

local function makeSlider(parent, label, mn, mx, def, color, onChanged, order)
    local val = create("TextLabel", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 11),
        BackgroundTransparency = 1,
        Text = label .. ": " .. def, TextColor3 = color,
        Font = Enum.Font.GothamBold, TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local wrap = create("Frame", {
        Parent = parent, LayoutOrder = order + 1,
        Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
    })
    local bar = create("Frame", {
        Parent = wrap, Size = UDim2.new(1, 0, 0, 4),
        Position = UDim2.new(0, 0, 0.5, -2),
        BackgroundColor3 = Color3.fromRGB(22, 28, 49),
        BorderSizePixel = 0,
    })
    addCorner(bar, 3)
    local pct = (def - mn) / (mx - mn)
    local fill = create("Frame", {
        Parent = bar, Size = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = color, BorderSizePixel = 0,
    })
    addCorner(fill, 3)
    local knob = create("Frame", {
        Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(pct, 0, 0.5, 0), Size = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.fromRGB(247, 250, 255), BorderSizePixel = 0,
    })
    addCorner(knob, 999)
    local hit = create("TextButton", {
        Parent = bar, Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 4,
    })
    local dragging = false
    local function apply(sx)
        local p = clamp((sx - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor(mn + p * (mx - mn) + 0.5)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        val.Text = label .. ": " .. v
        if onChanged then onChanged(v) end
    end
    hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; apply(i.Position.X) end end)
    hit.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then apply(i.Position.X) end
    end)
    return { label = val }
end

local function makeBindRow(parent, kc, order)
    local r = create("Frame", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
    })
    create("TextLabel", {
        Parent = r, Size = UDim2.new(0, 32, 1, 0),
        BackgroundTransparency = 1, Text = "Key:",
        TextColor3 = Theme.muted, Font = Enum.Font.Gotham,
        TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local b = create("TextButton", {
        Parent = r, Size = UDim2.new(0, 54, 0, 16),
        Position = UDim2.new(0, 32, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(20, 25, 47),
        BorderSizePixel = 0, Text = kc.Name,
        TextColor3 = Theme.accent, Font = Enum.Font.GothamBold,
        TextSize = 8, AutoButtonColor = false,
    })
    addCorner(b, 5)
    addStroke(b, Theme.accentSoft, 1)
    return b
end

local function makeSearchBox(parent, placeholder, order)
    local wrap = create("Frame", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.surfaceAlt, BorderSizePixel = 0,
    })
    addCorner(wrap, 8)
    addStroke(wrap, Theme.border, 1)
    addPadding(wrap, 8, 8, 0, 0)
    create("TextLabel", {
        Parent = wrap, Size = UDim2.new(0, 16, 1, 0),
        BackgroundTransparency = 1, Text = "⌕",
        TextColor3 = Theme.muted, Font = Enum.Font.GothamBold,
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local box = create("TextBox", {
        Parent = wrap, Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1, PlaceholderText = placeholder,
        Text = "", TextColor3 = Theme.text, PlaceholderColor3 = Theme.muted,
        Font = Enum.Font.Gotham, TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    })
    return box
end

local function makeActionButton(parent, order, text, bg, tc)
    local b = create("TextButton", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = bg, BorderSizePixel = 0,
        Text = text, TextColor3 = tc,
        Font = Enum.Font.GothamBold, TextSize = 9,
        AutoButtonColor = false,
    })
    addCorner(b, 7)
    addStroke(b, Theme.border, 1)
    return b
end

local function makeStatusLabel(parent, order, fontSize, color)
    return create("TextLabel", {
        Parent = parent, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = color or Theme.muted,
        Font = Enum.Font.Code, TextSize = fontSize or 8,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function makeToggleSection(parent, opts)
    local section = makeCard(parent, opts.order, opts.alt)
    local row = create("Frame", {
        Parent = section, LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
    })
    local label = create("TextLabel", {
        Parent = row, Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = string.format("%s  %s", opts.icon, opts.label),
        TextColor3 = Theme.subtext, Font = Enum.Font.GothamBold,
        TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local toggle = makeToggle(row, opts.toggleColor or Theme.accent)
    toggle.track.Position = UDim2.new(1, -36, 0.5, -9)
    toggle.hit.MouseButton1Click:Connect(function() createRipple(toggle.track, opts.toggleColor or Theme.accent) end)

    local bindButton = makeBindRow(section, opts.keyCode, 2)
    local status = opts.showStatus and makeStatusLabel(section, 3, 8, Theme.muted) or nil
    local status2 = opts.showStatus2 and makeStatusLabel(section, 4, 7, Theme.purple) or nil
    local lastOrder = opts.showStatus2 and 4 or (opts.showStatus and 3 or 2)

    if opts.slider then
        makeSlider(section, opts.slider.label, opts.slider.min, opts.slider.max,
            opts.slider.value, opts.slider.color or Theme.accent,
            opts.slider.onChanged, lastOrder + 1)
        lastOrder += 2
    end

    local extraToggle
    if opts.extraToggle then
        local er = create("Frame", {
            Parent = section, LayoutOrder = lastOrder + 1,
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
        })
        create("TextLabel", {
            Parent = er, Size = UDim2.new(1, -60, 1, 0),
            BackgroundTransparency = 1, Text = opts.extraToggle.label,
            TextColor3 = Theme.subtext, Font = Enum.Font.GothamBold,
            TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
        })
        extraToggle = makeToggle(er, opts.extraToggle.color or Theme.accent)
        extraToggle.track.Position = UDim2.new(1, -36, 0.5, -9)
        extraToggle.hit.MouseButton1Click:Connect(function() createRipple(extraToggle.track, opts.extraToggle.color or Theme.accent) end)
    end

    local function setEnabled(on)
        toggle.set(on)
        tween(label, { TextColor3 = on and Theme.text or Theme.subtext }, 0.14)
    end
    local function setExtraEnabled(on) if extraToggle then extraToggle.set(on) end end

    return {
        section = section, label = label, bindButton = bindButton,
        status = status, status2 = status2,
        toggleButton = toggle.hit,
        extraToggleButton = extraToggle and extraToggle.hit or nil,
        setEnabled = setEnabled, setExtraEnabled = setExtraEnabled,
    }
end

local function refreshFrameSize()
    if not UI.refs.frame or not State.runtime.guiVisible then return end
    task.wait()
    UI.refs.frame.Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT + UI.refs.rootLayout.AbsoluteContentSize.Y)
end

local function switchTab(name)
    State.runtime.currentTab = name
    for n, p in pairs(UI.pages) do p.Visible = n == name end
    for n, b in pairs(UI.tabs) do
        tween(b, {
            BackgroundColor3 = n == name and Theme.accent or Theme.surfaceAlt,
            TextColor3 = n == name and Theme.shell or Theme.muted,
        }, 0.16)
    end
    refreshFrameSize()
end

local function setGuiVisible(v)
    if State.runtime.guiAnimating or State.runtime.guiVisible == v then return end
    State.runtime.guiAnimating = true
    State.runtime.guiVisible = v
    if v then
        UI.refs.content.Visible = true
        task.wait()
        tween(UI.refs.frame, {
            Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT + UI.refs.rootLayout.AbsoluteContentSize.Y),
            BackgroundTransparency = 0,
        }, 0.2)
        tween(UI.refs.hideHint, { TextColor3 = Theme.muted }, 0.15)
        task.delay(0.24, function() State.runtime.guiAnimating = false end)
    else
        local sh = tween(UI.refs.frame, { Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT) }, 0.18)
        tween(UI.refs.hideHint, { TextColor3 = Theme.accent }, 0.15)
        sh.Completed:Connect(function()
            if not State.runtime.guiVisible then UI.refs.content.Visible = false end
            task.delay(0.04, function() State.runtime.guiAnimating = false end)
        end)
    end
end

local function setupBind(button, id, getKey, setKey)
    button.MouseButton1Click:Connect(function()
        if State.runtime.listening then return end
        State.runtime.listening = id
        button.Text = "..."
        tween(button, { TextColor3 = Theme.warning }, 0.12)
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then
                button.Text = getKey().Name
                tween(button, { TextColor3 = Theme.accent }, 0.12)
                State.runtime.listening = nil
                conn:Disconnect()
                return
            end
            if BLOCKED_KEYS[inp.KeyCode] then
                button.Text = "invalid!"
                tween(button, { TextColor3 = Theme.danger }, 0.12)
                task.wait(0.8)
                button.Text = getKey().Name
                tween(button, { TextColor3 = Theme.accent }, 0.12)
                State.runtime.listening = nil
                conn:Disconnect()
                return
            end
            setKey(inp.KeyCode)
            button.Text = inp.KeyCode.Name
            tween(button, { TextColor3 = Theme.accent }, 0.12)
            State.runtime.listening = nil
            conn:Disconnect()
        end)
    end)
end

local function updateLearningPanel()
    if not UI.refs.learnScore then return end
    local wins, total = getRecentScore(10)
    local trend = ""
    if total > 0 then
        local r = wins / total
        if r >= 0.7 then trend = " ↑"
        elseif r <= 0.3 then trend = " ↓"
        else trend = " →" end
    end
    UI.refs.learnScore.Text = string.format("Score: %d/%d%s  |  ✅%d  ❌%d  |  adj:%d",
        wins, total, trend, LearnHistory.totalWins, LearnHistory.totalLosses, LearnHistory.adjustCount)
    if total > 0 then
        local r = wins / total
        UI.refs.learnScore.TextColor3 = r >= 0.6 and Theme.success or (r <= 0.3 and Theme.danger or Theme.warning)
    else
        UI.refs.learnScore.TextColor3 = Theme.warning
    end
    UI.refs.learnDiag.Text = "Último: " .. LearnHistory.lastDiagnosis
    UI.refs.learnParams.Text = string.format("⚙ far %.2f  mid %.2f  near %.2f | cycle %dms",
        ReelParams.duty_far, ReelParams.duty_mid, ReelParams.duty_near, ReelParams.cycle_ms)
end

local function toggleNoclip()
    setNoclip(not State.flags.noclip)
    UI.refs.noclip.setEnabled(State.flags.noclip)
    if UI.refs.frameStroke then
        tween(UI.refs.frameStroke, { Color = State.flags.noclip and Theme.success or Theme.border }, 0.16)
    end
    updateActivityDot()
end

local function toggleSpeed()
    State.flags.speed = not State.flags.speed
    UI.refs.speed.setEnabled(State.flags.speed)
    if State.flags.speed then applySpeedOnce(); startSpeedLoop() else stopSpeedLoop() end
    updateActivityDot()
end

local function toggleJump()
    State.flags.jump = not State.flags.jump
    UI.refs.jump.setEnabled(State.flags.jump)
    if State.flags.jump then
        startJumpLoop()
    else
        stopJumpLoop()
        State.flags.rejump = false
        UI.refs.jump.setExtraEnabled(false)
        stopRejumpLoop()
    end
    updateActivityDot()
end

local function toggleRejump()
    if not State.flags.jump then return end
    State.flags.rejump = not State.flags.rejump
    UI.refs.jump.setExtraEnabled(State.flags.rejump)
    if State.flags.rejump then startRejumpLoop() else stopRejumpLoop() end
end

local function toggleCast()
    if State.flags.cast then
        stopCast()
        UI.refs.cast.setEnabled(false)
        setStatus(UI.refs.cast.status, "", Theme.muted)
    else
        State.flags.cast = true
        UI.refs.cast.setEnabled(true)
        startCast()
    end
    updateActivityDot()
end

local function toggleShake()
    State.flags.shake = not State.flags.shake
    UI.refs.shake.setEnabled(State.flags.shake)
    if State.flags.shake then startShake() else stopShake() end
    updateActivityDot()
end

local function toggleAutoReel()
    State.flags.autoReel = not State.flags.autoReel
    UI.refs.reel.setEnabled(State.flags.autoReel)
    if State.flags.autoReel then startAutoReel() else stopAutoReel() end
    updateActivityDot()
end

local function toggleAutoSell()
    State.flags.autoSell = not State.flags.autoSell
    UI.refs.autoSell.toggle.set(State.flags.autoSell)
    tween(UI.refs.autoSell.label, { TextColor3 = State.flags.autoSell and Theme.text or Theme.subtext }, 0.14)
    if State.flags.autoSell then
        startAutoSell()
    else
        stopAutoSell()
        setStatus(UI.refs.autoSellStatus, "Auto-sell off", Theme.muted)
    end
    updateActivityDot()
end

local function flashAction(btn, base, pulse)
    createRipple(btn, pulse)
    tween(btn, { BackgroundColor3 = pulse }, 0.08)
    task.delay(0.12, function() tween(btn, { BackgroundColor3 = base }, 0.15) end)
end

local function runSellInHand()
    task.spawn(function()
        flashAction(UI.refs.sellButton, Theme.sell, Theme.sellHover)
        local ok, m = sellFromHand()
        setStatus(UI.refs.sellStatus, (ok and "✅ " or "❌ ") .. m, ok and Theme.success or Theme.danger)
        task.wait(3)
        setStatus(UI.refs.sellStatus, "Waiting...", Theme.muted)
    end)
end

local function runSellAll()
    task.spawn(function()
        flashAction(UI.refs.sellAllButton, Color3.fromRGB(16, 57, 35), Theme.sellHover)
        local ok, m = sellAll()
        setStatus(UI.refs.sellStatus, (ok and "✅ " or "❌ ") .. m, ok and Theme.success or Theme.danger)
        task.wait(3)
        setStatus(UI.refs.sellStatus, "Waiting...", Theme.muted)
    end)
end

local function renderTeleportList()
    local holder = UI.refs.tpList
    if not holder then return end
    for _, c in ipairs(holder:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local q = (UI.search.tp and UI.search.tp.Text or ""):lower()
    local lo = 1
    for _, isl in ipairs(ISLANDS) do
        if q == "" or isl.name:lower():find(q, 1, true) then
            local tc, bc, hc = Theme.subtext, Theme.surface, Theme.surfaceHover
            if isl.cat == "second" then
                tc, bc, hc = Theme.cyan, Color3.fromRGB(14, 35, 46), Color3.fromRGB(18, 49, 63)
            elseif isl.cat == "deep" then
                tc, bc, hc = Color3.fromRGB(255, 132, 184), Color3.fromRGB(40, 16, 35), Color3.fromRGB(57, 23, 49)
            end
            local b = makeActionButton(holder, lo, "📍  " .. isl.name, bc, tc)
            b.TextXAlignment = Enum.TextXAlignment.Left
            addPadding(b, 10, 10, 0, 0)
            b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = hc, TextColor3 = Theme.text }, 0.15) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = bc, TextColor3 = tc }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                createRipple(b, tc)
                local ok = teleportTo(isl.pos)
                setStatus(UI.refs.tpStatus, (ok and "✅ " or "❌ ") .. isl.name, ok and Theme.success or Theme.danger)
                task.delay(3, function() setStatus(UI.refs.tpStatus, "", Theme.success) end)
            end)
            lo += 1
        end
    end
    if lo == 1 then
        create("TextLabel", {
            Parent = holder, LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
            Text = "Nada encontrado", TextColor3 = Theme.muted,
            Font = Enum.Font.Gotham, TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
end

local function renderRodList()
    local holder = UI.refs.rodList
    if not holder then return end
    for _, c in ipairs(holder:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local q = (UI.search.rods and UI.search.rods.Text or ""):lower()
    local lo = 1
    for _, rod in ipairs(RODS) do
        local s = (rod.name .. " " .. rod.loc):lower()
        if q == "" or s:find(q, 1, true) then
            local b = create("TextButton", {
                Parent = holder, LayoutOrder = lo,
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.surface, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
            })
            addCorner(b, 10)
            addStroke(b, Theme.border, 1)
            addPadding(b, 10, 10, 4, 4)
            create("TextLabel", {
                Parent = b, Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = "🎣  " .. rod.name,
                TextColor3 = Theme.cyan, Font = Enum.Font.GothamBold,
                TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
            })
            create("TextLabel", {
                Parent = b, Position = UDim2.new(0, 0, 0, 16),
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1, Text = rod.loc,
                TextColor3 = Theme.muted, Font = Enum.Font.Gotham,
                TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
            })
            b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Theme.surfaceHover }, 0.15) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Theme.surface }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                createRipple(b, Theme.cyan)
                local ok = teleportTo(rod.pos)
                setStatus(UI.refs.rodStatus, (ok and "✅ TP -> " or "❌ ") .. rod.name, ok and Theme.success or Theme.danger)
                task.delay(3, function() setStatus(UI.refs.rodStatus, "", Theme.success) end)
            end)
            lo += 1
        end
    end
    if lo == 1 then
        create("TextLabel", {
            Parent = holder, LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
            Text = "Nada encontrado", TextColor3 = Theme.muted,
            Font = Enum.Font.Gotham, TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
end

local function refreshMaps()
    local holder = UI.refs.mapList
    if not holder then return end
    for _, c in ipairs(holder:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local maps = getTreasureMaps()
    if #maps == 0 then
        create("TextLabel", {
            Parent = holder, LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
            Text = "Nenhum mapa no inventário",
            TextColor3 = Theme.muted, Font = Enum.Font.Gotham,
            TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center,
        })
        refreshFrameSize()
        return
    end
    for i, m in ipairs(maps) do
        local b = create("TextButton", {
            Parent = holder, LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = m.fixed and Theme.surface or Color3.fromRGB(48, 38, 22),
            BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        })
        addCorner(b, 8)
        addStroke(b, Theme.border, 1)
        addPadding(b, 10, 10, 4, 4)
        create("TextLabel", {
            Parent = b, Size = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            Text = (m.fixed and "📜  " or "❔  ") .. m.name,
            TextColor3 = m.fixed and Theme.gold or Theme.warning,
            Font = Enum.Font.GothamBold, TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        create("TextLabel", {
            Parent = b, Position = UDim2.new(0, 0, 0, 14),
            Size = UDim2.new(1, 0, 0, 11),
            BackgroundTransparency = 1,
            Text = m.fixed and string.format("X=%d  Y=%d  Z=%d", m.pos.X, m.pos.Y, m.pos.Z)
                or "→ leve no Jack Marrow para fixar",
            TextColor3 = m.fixed and Theme.cyan or Theme.muted,
            Font = Enum.Font.Code, TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        if m.fixed then
            b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Theme.surfaceHover }, 0.15) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Theme.surface }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                createRipple(b, Theme.gold)
                teleportTo(m.pos)
            end)
        end
    end
    refreshFrameSize()
end

local function rebuildNPCs()
    local holder = UI.refs.npcList
    if not holder then return end
    for _, c in ipairs(holder:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local npcs = getNearbyNPCs()
    if #npcs == 0 then
        create("TextLabel", {
            Parent = holder, LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
            Text = "No NPCs within " .. State.values.npcRange .. " studs",
            TextColor3 = Theme.muted, Font = Enum.Font.Gotham,
            TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center,
        })
        return
    end
    for i, npc in ipairs(npcs) do
        local b = makeActionButton(holder, i, "🧑  " .. npc.name .. "  (" .. npc.dist .. " st)", Theme.surface, Theme.subtext)
        b.TextXAlignment = Enum.TextXAlignment.Left
        addPadding(b, 10, 10, 0, 0)
        b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Theme.surfaceHover, TextColor3 = Theme.text }, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Theme.surface, TextColor3 = Theme.subtext }, 0.15) end)
        b.MouseButton1Click:Connect(function()
            createRipple(b, Theme.accent)
            teleportToNPC(npc.part)
            task.delay(0.8, rebuildNPCs)
        end)
    end
end

loadLearnData()

pcall(function()
    for _, n in ipairs({ "UtilityGui", "NoclipGui" }) do
        local e = PlayerGui:FindFirstChild(n)
        if e then e:Destroy() end
    end
end)

local gui = create("ScreenGui", {
    Parent = PlayerGui, Name = "UtilityGui",
    ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true,
})

local frame = create("Frame", {
    Parent = gui, Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT),
    Position = UDim2.new(0, -GUI_WIDTH, 0.5, WINDOW_Y_OFFSET),
    BackgroundColor3 = Theme.shell, BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true,
})
addCorner(frame, 14)
addGradient(frame, 90, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 14, 24)),
    ColorSequenceKeypoint.new(1, Theme.shell),
})
local frameStroke = addStroke(frame, Theme.border, 1.5, 0.06)

local header = create("Frame", {
    Parent = frame, Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = Theme.panel, BorderSizePixel = 0, ZIndex = 2,
})
addGradient(header, 90, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 25, 54)),
    ColorSequenceKeypoint.new(1, Theme.panel),
})

local activityDot = create("Frame", {
    Parent = header, Size = UDim2.new(0, 7, 0, 7),
    Position = UDim2.new(0, 12, 0.5, -4),
    BackgroundColor3 = Theme.muted, BorderSizePixel = 0, ZIndex = 4,
})
addCorner(activityDot, 999)

create("TextLabel", {
    Parent = header, Size = UDim2.new(1, -70, 0, 16),
    Position = UDim2.new(0, 24, 0, 5),
    BackgroundTransparency = 1, Text = "UTILITY v19",
    TextColor3 = Theme.text, Font = Enum.Font.GothamBlack,
    TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
})

create("TextLabel", {
    Parent = header, Size = UDim2.new(1, -70, 0, 11),
    Position = UDim2.new(0, 24, 0, 20),
    BackgroundTransparency = 1, Text = "reel duty-cycle",
    TextColor3 = Theme.subtext, Font = Enum.Font.Gotham,
    TextSize = 7, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
})

local hideHint = create("TextLabel", {
    Parent = header, Size = UDim2.new(0, 22, 0, 14),
    Position = UDim2.new(1, -30, 0.5, -7),
    BackgroundColor3 = Color3.fromRGB(22, 28, 54), BorderSizePixel = 0,
    Text = "V", TextColor3 = Theme.muted,
    Font = Enum.Font.GothamBold, TextSize = 8, ZIndex = 4,
})
addCorner(hideHint, 5)

local content = create("Frame", {
    Parent = frame, Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
    Size = UDim2.new(1, 0, 0, 9999), BackgroundTransparency = 1,
})

local rootLayout = create("UIListLayout", {
    Parent = content, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
})

UI.refs.frame = frame
UI.refs.frameStroke = frameStroke
UI.refs.activityDot = activityDot
UI.refs.content = content
UI.refs.hideHint = hideHint
UI.refs.rootLayout = rootLayout

local tabBar = create("Frame", {
    Parent = content, LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Theme.panel, BorderSizePixel = 0,
})
addPadding(tabBar, 4, 4, 4, 3)
create("UIListLayout", {
    Parent = tabBar, FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
})

local function createTab(name, title, order)
    local b = create("TextButton", {
        Parent = tabBar, LayoutOrder = order,
        Size = UDim2.new(0.2, -3, 1, 0),
        BackgroundColor3 = Theme.surfaceAlt, BorderSizePixel = 0,
        Text = title, TextColor3 = Theme.muted,
        Font = Enum.Font.GothamBold, TextSize = 9, AutoButtonColor = false,
    })
    addCorner(b, 7)
    UI.tabs[name] = b
    b.MouseButton1Click:Connect(function() switchTab(name) end)
end

createTab("Cheats", "Cheats", 1)
createTab("TP", "Travel", 2)
createTab("Rods", "Rods", 3)
createTab("Maps", "Maps", 4)
createTab("NPCs", "NPCs", 5)

makeDivider(content, 2)

local function createPage(name, order)
    local p = create("Frame", {
        Parent = content, LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = false,
    })
    create("UIListLayout", {
        Parent = p, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })
    UI.pages[name] = p
    return p
end

local cheatsPage = createPage("Cheats", 3)
local tpPage = createPage("TP", 4)
local rodsPage = createPage("Rods", 5)
local mapsPage = createPage("Maps", 6)
local npcsPage = createPage("NPCs", 7)

makeDivider(cheatsPage, 1)

UI.refs.noclip = makeToggleSection(cheatsPage, {
    order = 2, icon = "👻", label = "Noclip",
    keyCode = State.keys.noclip, toggleColor = Theme.success,
})
makeDivider(cheatsPage, 3)

UI.refs.speed = makeToggleSection(cheatsPage, {
    order = 4, icon = "💨", label = "Speed",
    keyCode = State.keys.speed, toggleColor = Theme.accent,
    slider = {
        label = "Speed", min = 16, max = 300,
        value = State.values.speed, color = Theme.accent,
        onChanged = function(v) State.values.speed = v end,
    },
})
makeDivider(cheatsPage, 5)

UI.refs.jump = makeToggleSection(cheatsPage, {
    order = 6, icon = "🦘", label = "High Jump",
    keyCode = State.keys.jump, toggleColor = Theme.warning,
    slider = {
        label = "Power", min = 50, max = 500,
        value = State.values.jump, color = Theme.warning,
        onChanged = function(v) State.values.jump = v end,
    },
    extraToggle = { label = "↩  Re-jump", color = Theme.warning },
})
makeDivider(cheatsPage, 7)

UI.refs.cast = makeToggleSection(cheatsPage, {
    order = 8, icon = "🎯", label = "Auto Cast",
    keyCode = State.keys.cast, toggleColor = Theme.cast, showStatus = true,
})
makeDivider(cheatsPage, 9)

UI.refs.shake = makeToggleSection(cheatsPage, {
    order = 10, icon = "🔄", label = "Shake",
    keyCode = State.keys.shake, toggleColor = Theme.success, showStatus = true,
})
makeDivider(cheatsPage, 11)

UI.refs.reel = makeToggleSection(cheatsPage, {
    order = 12, icon = "🎣", label = "Auto-Reel v19",
    keyCode = State.keys.reel, toggleColor = Theme.purple,
    showStatus = true, showStatus2 = true,
})
UI.refs.reelScore = UI.refs.reel.status

local learningCard = makeCard(UI.refs.reel.section, 6, true)
addStroke(learningCard, Color3.fromRGB(76, 56, 130), 1)

create("TextLabel", {
    Parent = learningCard, LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "🧠  Duty-cycle learning",
    TextColor3 = Theme.purple, Font = Enum.Font.GothamBold,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.learnScore = create("TextLabel", {
    Parent = learningCard, LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundTransparency = 1, Text = "Score: —",
    TextColor3 = Theme.text, Font = Enum.Font.Code,
    TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.learnDiag = create("TextLabel", {
    Parent = learningCard, LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundTransparency = 1, Text = "Último: —",
    TextColor3 = Theme.subtext, Font = Enum.Font.Code,
    TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.learnParams = create("TextLabel", {
    Parent = learningCard, LayoutOrder = 4,
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundTransparency = 1, Text = "",
    TextColor3 = Theme.muted, Font = Enum.Font.Code,
    TextSize = 7, TextXAlignment = Enum.TextXAlignment.Left,
})

makeDivider(learningCard, 5).BackgroundColor3 = Color3.fromRGB(76, 56, 130)

local resetBtn = makeActionButton(learningCard, 6, "🔄  Resetar aprendizado", Color3.fromRGB(43, 18, 56), Theme.purple)
resetBtn.MouseEnter:Connect(function() tween(resetBtn, { BackgroundColor3 = Color3.fromRGB(59, 24, 74) }, 0.14) end)
resetBtn.MouseLeave:Connect(function() tween(resetBtn, { BackgroundColor3 = Color3.fromRGB(43, 18, 56) }, 0.14) end)
resetBtn.MouseButton1Click:Connect(function()
    createRipple(resetBtn, Theme.purple)
    ReelParams.duty_far = 0.90
    ReelParams.duty_mid = 0.65
    ReelParams.duty_near = 0.50
    ReelParams.cycle_ms = 45
    ReelParams.rebound_ms = 80
    LearnHistory.sessions = {}
    LearnHistory.totalWins = 0
    LearnHistory.totalLosses = 0
    LearnHistory.lastDiagnosis = "—"
    LearnHistory.adjustCount = 0
    saveLearnData()
    updateLearningPanel()
    UI.refs.learnScore.Text = "Score: resetado"
    UI.refs.learnScore.TextColor3 = Theme.warning
    task.delay(2, updateLearningPanel)
end)

makeDivider(cheatsPage, 13)

local sellCard = makeCard(cheatsPage, 14)
create("TextLabel", {
    Parent = sellCard, LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1, Text = "💰  Sell",
    TextColor3 = Theme.subtext, Font = Enum.Font.GothamBold,
    TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.sellStatus = create("TextLabel", {
    Parent = sellCard, LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1, Text = "Waiting...",
    TextColor3 = Theme.muted, Font = Enum.Font.Code,
    TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
})

local sellBindButton = makeBindRow(sellCard, State.keys.sell, 3)

UI.refs.sellButton = makeActionButton(sellCard, 4, "💰  Sell Item in Hand", Theme.sell, Theme.success)
UI.refs.sellButton.MouseEnter:Connect(function() tween(UI.refs.sellButton, { BackgroundColor3 = Theme.sellHover }, 0.15) end)
UI.refs.sellButton.MouseLeave:Connect(function() tween(UI.refs.sellButton, { BackgroundColor3 = Theme.sell }, 0.15) end)

makeDivider(sellCard, 5)

UI.refs.sellAllButton = makeActionButton(sellCard, 6, "📦  Sell All (mantém mapas)", Color3.fromRGB(16, 57, 35), Theme.success)
UI.refs.sellAllButton.MouseEnter:Connect(function() tween(UI.refs.sellAllButton, { BackgroundColor3 = Theme.sellHover }, 0.15) end)
UI.refs.sellAllButton.MouseLeave:Connect(function() tween(UI.refs.sellAllButton, { BackgroundColor3 = Color3.fromRGB(16, 57, 35) }, 0.15) end)

makeDivider(sellCard, 7)

local autoSellRow = create("Frame", {
    Parent = sellCard, LayoutOrder = 8,
    Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
})

UI.refs.autoSell = {}
UI.refs.autoSell.label = create("TextLabel", {
    Parent = autoSellRow, Size = UDim2.new(1, -60, 1, 0),
    BackgroundTransparency = 1, Text = "🔁  Auto-Sell",
    TextColor3 = Theme.subtext, Font = Enum.Font.GothamBold,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
})
UI.refs.autoSell.toggle = makeToggle(autoSellRow, Theme.success)
UI.refs.autoSell.toggle.track.Position = UDim2.new(1, -36, 0.5, -9)
UI.refs.autoSell.toggle.hit.MouseButton1Click:Connect(function() createRipple(UI.refs.autoSell.toggle.track, Theme.success) end)

makeSlider(sellCard, "Delay", 5, 100, math.floor(State.values.autoSellDelay * 10), Theme.success, function(v)
    State.values.autoSellDelay = v / 10
end, 9)

UI.refs.autoSellStatus = makeStatusLabel(sellCard, 11, 8, Theme.muted)
makeDivider(cheatsPage, 15)

local tpCard = makeCard(tpPage, 1)
UI.refs.tpStatus = makeStatusLabel(tpCard, 1, 8, Theme.success)
UI.search.tp = makeSearchBox(tpCard, "Buscar ilha...", 2)

local tpScroll = create("ScrollingFrame", {
    Parent = tpCard, LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 250),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.accent,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
})
UI.refs.tpList = tpScroll
create("UIListLayout", {
    Parent = tpScroll, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local rodsCard = makeCard(rodsPage, 1)
UI.refs.rodStatus = makeStatusLabel(rodsCard, 1, 8, Theme.success)
UI.search.rods = makeSearchBox(rodsCard, "Buscar vara...", 2)

local rodsScroll = create("ScrollingFrame", {
    Parent = rodsCard, LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 250),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.accent,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
})
UI.refs.rodList = rodsScroll
create("UIListLayout", {
    Parent = rodsScroll, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local mapsCard = makeCard(mapsPage, 1)
create("TextLabel", {
    Parent = mapsCard, LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1, Text = "📜  Treasure Maps no inventário",
    TextColor3 = Theme.gold, Font = Enum.Font.GothamBold,
    TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
})
create("TextLabel", {
    Parent = mapsCard, LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1, Text = "Leva o mapa no Jack Marrow pra fixar as coords",
    TextColor3 = Theme.muted, Font = Enum.Font.Gotham,
    TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
})

local scanMapsButton = makeActionButton(mapsCard, 3, "🔍  Escanear mapas", Color3.fromRGB(53, 40, 16), Theme.gold)
local jackButton = makeActionButton(mapsCard, 4, "🏴  TP Jack Marrow (fixar mapas)", Color3.fromRGB(18, 34, 53), Theme.accent)

local mapList = create("Frame", {
    Parent = mapsCard, LayoutOrder = 5,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
})
UI.refs.mapList = mapList
create("UIListLayout", {
    Parent = mapList, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local npcCard = makeCard(npcsPage, 1)
makeSlider(npcCard, "Scan range", 1, 1000, State.values.npcRange, Theme.accent, function(v)
    State.values.npcRange = v
end, 1)

local scanNpcButton = makeActionButton(npcCard, 3, "🔍  Scan Nearby NPCs", Color3.fromRGB(18, 34, 62), Theme.accent)

local npcScroll = create("ScrollingFrame", {
    Parent = npcCard, LayoutOrder = 4,
    Size = UDim2.new(1, 0, 0, 210),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.accent,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
})
UI.refs.npcList = npcScroll
create("UIListLayout", {
    Parent = npcScroll, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

UI.refs.noclip.toggleButton.MouseButton1Click:Connect(toggleNoclip)
UI.refs.speed.toggleButton.MouseButton1Click:Connect(toggleSpeed)
UI.refs.jump.toggleButton.MouseButton1Click:Connect(toggleJump)
if UI.refs.jump.extraToggleButton then
    UI.refs.jump.extraToggleButton.MouseButton1Click:Connect(toggleRejump)
end
UI.refs.cast.toggleButton.MouseButton1Click:Connect(toggleCast)
UI.refs.shake.toggleButton.MouseButton1Click:Connect(toggleShake)
UI.refs.reel.toggleButton.MouseButton1Click:Connect(toggleAutoReel)
UI.refs.autoSell.toggle.hit.MouseButton1Click:Connect(toggleAutoSell)
UI.refs.sellButton.MouseButton1Click:Connect(runSellInHand)
UI.refs.sellAllButton.MouseButton1Click:Connect(runSellAll)

scanMapsButton.MouseEnter:Connect(function() tween(scanMapsButton, { BackgroundColor3 = Color3.fromRGB(68, 51, 20) }, 0.15) end)
scanMapsButton.MouseLeave:Connect(function() tween(scanMapsButton, { BackgroundColor3 = Color3.fromRGB(53, 40, 16) }, 0.15) end)
scanMapsButton.MouseButton1Click:Connect(function()
    createRipple(scanMapsButton, Theme.gold)
    scanMapsButton.Text = "⏳  Escaneando..."
    task.wait(0.2)
    refreshMaps()
    scanMapsButton.Text = "🔍  Escanear mapas"
end)

jackButton.MouseEnter:Connect(function() tween(jackButton, { BackgroundColor3 = Color3.fromRGB(24, 44, 66) }, 0.15) end)
jackButton.MouseLeave:Connect(function() tween(jackButton, { BackgroundColor3 = Color3.fromRGB(18, 34, 53) }, 0.15) end)
jackButton.MouseButton1Click:Connect(function()
    createRipple(jackButton, Theme.accent)
    teleportTo(Vector3.new(-2825, 215, 1515))
end)

scanNpcButton.MouseEnter:Connect(function() tween(scanNpcButton, { BackgroundColor3 = Color3.fromRGB(24, 44, 74) }, 0.15) end)
scanNpcButton.MouseLeave:Connect(function() tween(scanNpcButton, { BackgroundColor3 = Color3.fromRGB(18, 34, 62) }, 0.15) end)
scanNpcButton.MouseButton1Click:Connect(function()
    createRipple(scanNpcButton, Theme.accent)
    scanNpcButton.Text = "⏳  Scanning..."
    task.wait(0.15)
    rebuildNPCs()
    scanNpcButton.Text = "🔍  Scan Nearby NPCs"
end)

UI.search.tp:GetPropertyChangedSignal("Text"):Connect(renderTeleportList)
UI.search.rods:GetPropertyChangedSignal("Text"):Connect(renderRodList)

setupBind(UI.refs.noclip.bindButton, "noclip", function() return State.keys.noclip end, function(k) State.keys.noclip = k end)
setupBind(UI.refs.speed.bindButton, "speed", function() return State.keys.speed end, function(k) State.keys.speed = k end)
setupBind(UI.refs.jump.bindButton, "jump", function() return State.keys.jump end, function(k) State.keys.jump = k end)
setupBind(UI.refs.cast.bindButton, "cast", function() return State.keys.cast end, function(k) State.keys.cast = k end)
setupBind(UI.refs.shake.bindButton, "shake", function() return State.keys.shake end, function(k) State.keys.shake = k end)
setupBind(UI.refs.reel.bindButton, "reel", function() return State.keys.reel end, function(k) State.keys.reel = k end)
setupBind(sellBindButton, "sell", function() return State.keys.sell end, function(k) State.keys.sell = k end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or State.runtime.listening then return end
    local kc = input.KeyCode
    if kc == State.keys.toggleGui then setGuiVisible(not State.runtime.guiVisible)
    elseif kc == State.keys.noclip then toggleNoclip()
    elseif kc == State.keys.speed then toggleSpeed()
    elseif kc == State.keys.jump then toggleJump()
    elseif kc == State.keys.cast then toggleCast()
    elseif kc == State.keys.shake then toggleShake()
    elseif kc == State.keys.reel then toggleAutoReel()
    elseif kc == State.keys.sell then runSellInHand() end
end)

do
    local dragging = false
    local dragStart, startPos
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = i.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if State.flags.noclip then setNoclip(true) end
    if State.flags.speed then applySpeedOnce(); startSpeedLoop() end
    if State.flags.jump then startJumpLoop() end
    if State.flags.rejump and State.flags.jump then startRejumpLoop() end
end)

startTask("autosaveLearning", function()
    while true do task.wait(30); saveLearnData() end
end)

startTask("learningPanel", function()
    while true do task.wait(0.5); updateLearningPanel() end
end)

startTask("shakeStatus", function()
    local dots = { "", ".", "..", "..." }
    local i = 1
    while true do
        task.wait(0.2); i = i % #dots + 1
        if State.flags.shake then
            local t = State.runtime.shakeActive
                and ("● Enter pressing" .. dots[i])
                or ("○ waiting shake" .. dots[i])
            setStatus(UI.refs.shake.status, t, State.runtime.shakeActive and Theme.success or Theme.warning)
        else
            setStatus(UI.refs.shake.status, "", Theme.muted)
        end
    end
end)

startTask("castStatus", function()
    local dots = { "", ".", "..", "..." }
    local i = 1
    while true do
        task.wait(0.2); i = i % #dots + 1
        if State.flags.cast then
            if State.runtime.castActive then
                if State.runtime.castPhase == "holding" then
                    setStatus(UI.refs.cast.status, "▲ carregando" .. dots[i], Theme.cast)
                else
                    setStatus(UI.refs.cast.status, "↓ soltando" .. dots[i], Theme.success)
                end
            elseif State.runtime.castPhase == "cooldown" then
                setStatus(UI.refs.cast.status, "○ aguardando pesca" .. dots[i], Theme.warning)
            elseif State.runtime.castPhase == "arming" then
                setStatus(UI.refs.cast.status, "○ puxando vara [1]" .. dots[i], Theme.warning)
            elseif State.runtime.castPhase == "searching" then
                setStatus(UI.refs.cast.status, "⌕ aguardando verde" .. dots[i], Theme.warning)
            else
                setStatus(UI.refs.cast.status, "○ aguardando cast" .. dots[i], Theme.warning)
            end
        else
            setStatus(UI.refs.cast.status, "", Theme.muted)
        end
    end
end)

startTask("reelStatus", function()
    local dots = { "", ".", "..", "..." }
    local i = 1
    while true do
        task.wait(0.25); i = i % #dots + 1
        if State.flags.autoReel then
            if State.runtime.reelActive then
                setStatus(UI.refs.reel.status, "● pescando" .. dots[i], Theme.success)
            else
                setStatus(UI.refs.reel.status, "○ aguardando UI" .. dots[i], Theme.warning)
            end
        else
            setStatus(UI.refs.reel.status, "", Theme.muted)
        end
    end
end)

switchTab("Cheats")
renderTeleportList()
renderRodList()
refreshMaps()
updateLearningPanel()
refreshFrameSize()
updateActivityDot()

task.delay(0.08, refreshFrameSize)
TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0, 18, 0.5, WINDOW_Y_OFFSET),
    BackgroundTransparency = 0,
}):Play()