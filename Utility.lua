--[[
    UTILITY v18 — REFACTOR + GUI POLISH

    Melhorias desta versão:
    • Estrutura mais organizada e com menos repetição
    • GUI mais larga, mais limpa e com busca em TP/Rods
    • Toggle/status centralizados para reduzir flicker
    • Auto-cast e auto-reel com heurísticas mais seguras
    • Helpers reutilizáveis para cards, botões, sliders e binds
    • Mantém recursos do v17: auto-cast, auto-reel adaptativo, sell, maps e NPC scan
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
        noclip = false,
        speed = false,
        jump = false,
        rejump = false,
        shake = false,
        cast = false,
        autoSell = false,
        autoReel = false,
    },
    values = {
        speed = 45,
        jump = 80,
        autoSellDelay = 1.5,
        npcRange = 150,
        castReleasePct = 0.72,
    },
    keys = {
        noclip = Enum.KeyCode.F,
        speed = Enum.KeyCode.G,
        jump = Enum.KeyCode.H,
        shake = Enum.KeyCode.J,
        cast = Enum.KeyCode.U,
        sell = Enum.KeyCode.K,
        reel = Enum.KeyCode.L,
        toggleGui = Enum.KeyCode.V,
    },
    runtime = {
        currentTab = "Cheats",
        guiVisible = true,
        guiAnimating = false,
        listening = nil,
        shakeActive = false,
        reelActive = false,
        castActive = false,
        castPhase = "idle",
        reelMouseHeld = false,
        castMouseHeld = false,
        lastCastEquipAttempt = 0,
    },
    tasks = {},
    connections = {},
}

local UI = {
    tabs = {},
    pages = {},
    search = {},
    refs = {},
}

local ReelParams = {
    hold_far = 0.200,
    release_far = 0.025,
    hold_mid = 0.095,
    release_mid = 0.040,
    hold_inside = 0.042,
    release_inside = 0.055,
}

local LearnHistory = {
    sessions = {},
    totalWins = 0,
    totalLosses = 0,
    lastDiagnosis = "—",
    adjustCount = 0,
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
    shell = Color3.fromRGB(8, 11, 19),
    panel = Color3.fromRGB(14, 18, 31),
    surface = Color3.fromRGB(18, 24, 41),
    surfaceHover = Color3.fromRGB(24, 32, 54),
    surfaceAlt = Color3.fromRGB(12, 16, 28),
    accent = Color3.fromRGB(88, 164, 255),
    accentSoft = Color3.fromRGB(48, 94, 190),
    success = Color3.fromRGB(62, 215, 132),
    danger = Color3.fromRGB(236, 87, 97),
    warning = Color3.fromRGB(241, 192, 69),
    text = Color3.fromRGB(223, 230, 247),
    subtext = Color3.fromRGB(156, 170, 201),
    muted = Color3.fromRGB(104, 118, 152),
    border = Color3.fromRGB(31, 40, 70),
    gold = Color3.fromRGB(255, 191, 74),
    cyan = Color3.fromRGB(104, 230, 255),
    purple = Color3.fromRGB(152, 108, 255),
    cast = Color3.fromRGB(92, 255, 191),
    sell = Color3.fromRGB(22, 68, 45),
    sellHover = Color3.fromRGB(28, 84, 54),
}

local GUI_WIDTH = 226
local HEADER_HEIGHT = 38
local WINDOW_Y_OFFSET = -180

local BLOCKED_KEYS = {
    [Enum.KeyCode.Return] = true,
    [Enum.KeyCode.Escape] = true,
    [Enum.KeyCode.Tab] = true,
    [Enum.KeyCode.Backspace] = true,
    [Enum.KeyCode.LeftShift] = true,
    [Enum.KeyCode.RightShift] = true,
    [Enum.KeyCode.LeftControl] = true,
    [Enum.KeyCode.RightControl] = true,
    [Enum.KeyCode.LeftAlt] = true,
    [Enum.KeyCode.RightAlt] = true,
    [Enum.KeyCode.V] = true,
}

local function create(className, props)
    local parent = props.Parent
    props.Parent = nil
    local object = Instance.new(className)
    for key, value in pairs(props) do
        object[key] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function addCorner(parent, radius)
    create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius),
    })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Parent = parent,
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    })
end

local function addGradient(parent, rotation, colors)
    return create("UIGradient", {
        Parent = parent,
        Rotation = rotation or 0,
        Color = ColorSequence.new(colors),
    })
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        Parent = parent,
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
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

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function rnd(minValue, maxValue)
    return minValue + math.random() * (maxValue - minValue)
end

local function character()
    return LocalPlayer.Character
end

local function humanoid()
    local currentCharacter = character()
    return currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
end

local function rootPart()
    local currentCharacter = character()
    return currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
end

local function heldTool()
    local currentCharacter = character()
    return currentCharacter and currentCharacter:FindFirstChildOfClass("Tool")
end

local function setStatus(label, text, color)
    if not label then
        return
    end
    if label.Text ~= text then
        label.Text = text
    end
    if color and label.TextColor3 ~= color then
        label.TextColor3 = color
    end
end

local function startTask(name, callback)
    if State.tasks[name] then
        task.cancel(State.tasks[name])
    end
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
        LocalPlayer:SetAttribute("RP_hold_far", ReelParams.hold_far)
        LocalPlayer:SetAttribute("RP_release_far", ReelParams.release_far)
        LocalPlayer:SetAttribute("RP_hold_mid", ReelParams.hold_mid)
        LocalPlayer:SetAttribute("RP_release_mid", ReelParams.release_mid)
        LocalPlayer:SetAttribute("RP_hold_inside", ReelParams.hold_inside)
        LocalPlayer:SetAttribute("RP_release_inside", ReelParams.release_inside)
        LocalPlayer:SetAttribute("LH_wins", LearnHistory.totalWins)
        LocalPlayer:SetAttribute("LH_losses", LearnHistory.totalLosses)
        LocalPlayer:SetAttribute("LH_adjusts", LearnHistory.adjustCount)
        LocalPlayer:SetAttribute("LH_last", LearnHistory.lastDiagnosis)
    end)
end

local function loadLearnData()
    pcall(function()
        local function getAttribute(key, defaultValue)
            local value = LocalPlayer:GetAttribute(key)
            if value == nil then
                return defaultValue
            end
            return value
        end

        ReelParams.hold_far = getAttribute("RP_hold_far", 0.200)
        ReelParams.release_far = getAttribute("RP_release_far", 0.025)
        ReelParams.hold_mid = getAttribute("RP_hold_mid", 0.095)
        ReelParams.release_mid = getAttribute("RP_release_mid", 0.040)
        ReelParams.hold_inside = getAttribute("RP_hold_inside", 0.042)
        ReelParams.release_inside = getAttribute("RP_release_inside", 0.055)
        LearnHistory.totalWins = getAttribute("LH_wins", 0)
        LearnHistory.totalLosses = getAttribute("LH_losses", 0)
        LearnHistory.adjustCount = getAttribute("LH_adjusts", 0)
        LearnHistory.lastDiagnosis = getAttribute("LH_last", "—")
    end)
end

local function applyLearning(won, diagnosis)
    local step = 0.007
    local message = ""

    if not won then
        local total = math.max(diagnosis.timesFar + diagnosis.timesMid + diagnosis.timesInside, 1)
        local farPct = diagnosis.timesFar / total
        local overshootPct = diagnosis.timesOvershoots / math.max(diagnosis.timesInside + diagnosis.timesMid, 1)

        if farPct > 0.5 then
            ReelParams.hold_far = clamp(ReelParams.hold_far + step, 0.120, 0.280)
            ReelParams.release_far = clamp(ReelParams.release_far - step * 0.5, 0.010, 0.060)
            message = "lento -> aumentei força"
        elseif overshootPct > 0.3 then
            ReelParams.hold_far = clamp(ReelParams.hold_far - step, 0.120, 0.280)
            ReelParams.hold_mid = clamp(ReelParams.hold_mid - step * 0.7, 0.055, 0.150)
            ReelParams.release_inside = clamp(ReelParams.release_inside + step, 0.030, 0.100)
            message = "rápido demais -> reduzi força"
        elseif diagnosis.timesInside > 0 and overshootPct < 0.1 then
            ReelParams.hold_mid = clamp(ReelParams.hold_mid + step * 0.5, 0.055, 0.150)
            ReelParams.release_mid = clamp(ReelParams.release_mid - step * 0.3, 0.020, 0.075)
            message = "timing médio ajustado"
        else
            ReelParams.hold_inside = clamp(ReelParams.hold_inside + step * 0.4, 0.025, 0.080)
            message = "ajuste geral leve"
        end

        LearnHistory.totalLosses = LearnHistory.totalLosses + 1
    else
        if diagnosis.timesOvershoots > 2 then
            ReelParams.hold_far = clamp(ReelParams.hold_far - step * 0.3, 0.120, 0.280)
            message = "ganhou com overshoot -> refinando"
        else
            message = "perfeito ✓"
        end

        LearnHistory.totalWins = LearnHistory.totalWins + 1
    end

    LearnHistory.adjustCount = LearnHistory.adjustCount + 1
    LearnHistory.lastDiagnosis = (won and "✅ " or "❌ ") .. message
    table.insert(LearnHistory.sessions, 1, {
        won = won,
        msg = message,
        time = tick(),
    })

    if #LearnHistory.sessions > 20 then
        table.remove(LearnHistory.sessions)
    end

    saveLearnData()
end

local function getRecentScore(amount)
    amount = amount or 10
    local wins = 0
    local total = 0

    for index = 1, math.min(amount, #LearnHistory.sessions) do
        total += 1
        if LearnHistory.sessions[index].won then
            wins += 1
        end
    end

    return wins, total
end

local function bindConnection(name, connection)
    if State.connections[name] then
        State.connections[name]:Disconnect()
    end
    State.connections[name] = connection
end

local function disconnectConnection(name)
    if State.connections[name] then
        State.connections[name]:Disconnect()
        State.connections[name] = nil
    end
end

local function updateActivityDot()
    local anyActive = State.flags.noclip
        or State.flags.speed
        or State.flags.jump
        or State.flags.shake
        or State.flags.cast
        or State.flags.autoSell
        or State.flags.autoReel

    if UI.refs.activityDot then
        tween(UI.refs.activityDot, {
            BackgroundColor3 = anyActive and Theme.success or Theme.muted,
        }, 0.15)
    end
end

local function teleportTo(position)
    local root = rootPart()
    if not root then
        return false
    end

    root.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
    return true
end

local function setNoclip(enabled)
    State.flags.noclip = enabled
    disconnectConnection("noclip")

    if enabled then
        bindConnection("noclip", RunService.Stepped:Connect(function()
            local currentCharacter = character()
            if not currentCharacter then
                return
            end

            for _, part in ipairs(currentCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end))
    else
        local currentCharacter = character()
        if currentCharacter then
            for _, part in ipairs(currentCharacter:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function applySpeedOnce()
    local hum = humanoid()
    if hum then
        hum.WalkSpeed = State.flags.speed and State.values.speed or 16
    end
end

local function startSpeedLoop()
    disconnectConnection("speed")
    bindConnection("speed", RunService.Heartbeat:Connect(function()
        if not State.flags.speed then
            disconnectConnection("speed")
            return
        end

        local hum = humanoid()
        if hum and hum.WalkSpeed ~= State.values.speed then
            hum.WalkSpeed = State.values.speed
        end
    end))
end

local function stopSpeedLoop()
    disconnectConnection("speed")
    local hum = humanoid()
    if hum then
        hum.WalkSpeed = 16
    end
end

local function startJumpLoop()
    disconnectConnection("jump")
    bindConnection("jump", RunService.Heartbeat:Connect(function()
        if not State.flags.jump then
            disconnectConnection("jump")
            return
        end

        local hum = humanoid()
        if hum then
            hum.UseJumpPower = true
            if hum.JumpPower ~= State.values.jump then
                hum.JumpPower = State.values.jump
            end
        end
    end))
end

local function stopJumpLoop()
    disconnectConnection("jump")
    local hum = humanoid()
    if hum then
        hum.JumpPower = 50
    end
end

local function startRejumpLoop()
    disconnectConnection("rejump")
    bindConnection("rejump", RunService.Heartbeat:Connect(function()
        if not State.flags.rejump or not State.flags.jump then
            disconnectConnection("rejump")
            return
        end

        local hum = humanoid()
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.15)
        end
    end))
end

local function stopRejumpLoop()
    disconnectConnection("rejump")
end

local function shakeUiVisible()
    local shakeGui = PlayerGui:FindFirstChild("shakeui")
    return shakeGui and shakeGui.Enabled ~= false
end

local function tapKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    end)
    task.wait(0.02)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function pressEnter()
    tapKey(Enum.KeyCode.Return)
end

local function equipRodSlot()
    tapKey(Enum.KeyCode.One)
end

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
    if State.runtime.castMouseHeld then
        return
    end

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true, game, 0)
    end)
    State.runtime.castMouseHeld = true
end

local function sendMouseUp(x, y)
    if not State.runtime.castMouseHeld then
        return
    end

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0)
    end)
    State.runtime.castMouseHeld = false
end

local function forceCastRelease()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    State.runtime.castMouseHeld = false
end

local function findGuiByPatterns(names, includes, excludes)
    for _, name in ipairs(names) do
        local gui = PlayerGui:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") and gui.Enabled ~= false then
            return gui
        end
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local lowerName = gui.Name:lower()
            local matched = false
            for _, pattern in ipairs(includes) do
                if lowerName:find(pattern) then
                    matched = true
                    break
                end
            end

            if matched then
                local blocked = false
                for _, pattern in ipairs(excludes or {}) do
                    if lowerName:find(pattern) then
                        blocked = true
                        break
                    end
                end

                if not blocked then
                    return gui
                end
            end
        end
    end

    return nil
end

local function rectContains(parentObject, childObject)
    local parentPos = parentObject.AbsolutePosition
    local parentSize = parentObject.AbsoluteSize
    local childPos = childObject.AbsolutePosition
    local childSize = childObject.AbsoluteSize

    return childPos.X >= parentPos.X - 2
        and childPos.Y >= parentPos.Y - 2
        and childPos.X + childSize.X <= parentPos.X + parentSize.X + 2
        and childPos.Y + childSize.Y <= parentPos.Y + parentSize.Y + 2
end

local function findCastUI()
    return findGuiByPatterns(
        { "castui", "CastUI", "castbar", "CastBar", "powerui", "PowerUI", "chargeui", "ChargeUI", "castingui", "CastingUI", "throwui", "ThrowUI", "powerbar", "PowerBar" },
        { "cast", "power", "charge", "throw", "launch" },
        { "shake", "reel", "fish" }
    )
end

local function findCastBar(castGui)
    local bestBar
    local bestBarScore = -math.huge
    local greenCandidates = {}

    for _, descendant in ipairs(castGui:GetDescendants()) do
        if descendant:IsA("Frame") and descendant.Visible then
            local size = descendant.AbsoluteSize
            local lowerName = descendant.Name:lower()

            if size.Y > 36 and size.X > 6 and size.X < 100 then
                local ratio = size.Y / math.max(size.X, 1)
                if ratio > 1.5 then
                    local score = ratio * 3 + size.Y * 0.03
                    if lowerName:find("bar") or lowerName:find("meter") or lowerName:find("power") then
                        score += 4
                    end
                    if score > bestBarScore then
                        bestBarScore = score
                        bestBar = descendant
                    end
                end
            end

            local color = descendant.BackgroundColor3
            if color.G > color.R * 1.15 and color.G > color.B * 1.10 and color.G > 0.2 then
                table.insert(greenCandidates, descendant)
            elseif lowerName:find("fill") or lowerName:find("progress") or lowerName:find("green") then
                table.insert(greenCandidates, descendant)
            end
        end
    end

    if not bestBar then
        return nil, nil
    end

    local bestFill
    local bestFillScore = -math.huge

    for _, candidate in ipairs(greenCandidates) do
        if candidate.Parent and rectContains(bestBar, candidate) then
            local size = candidate.AbsoluteSize
            local score = size.Y + size.X * 0.2
            if candidate.Parent == bestBar then
                score += 20
            end
            if score > bestFillScore then
                bestFillScore = score
                bestFill = candidate
            end
        end
    end

    return bestBar, bestFill
end

local function getCastProgress(outerBar, greenFill)
    if not outerBar or not greenFill then
        return 0
    end

    local barHeight = math.max(outerBar.AbsoluteSize.Y, 1)
    local fillHeight = greenFill.AbsoluteSize.Y
    return math.clamp(fillHeight / barHeight, 0, 1)
end

local function startCast()
    forceCastRelease()
    State.runtime.lastCastEquipAttempt = 0
    State.runtime.castActive = false
    State.runtime.castPhase = "idle"

    startTask("cast", function()
        while State.flags.cast do
            local castGui = findCastUI()

            if castGui and castGui.Enabled then
                local outerBar, greenFill = findCastBar(castGui)
                if outerBar and greenFill then
                    local centerX = outerBar.AbsolutePosition.X + outerBar.AbsoluteSize.X * 0.5
                    local centerY = outerBar.AbsolutePosition.Y + outerBar.AbsoluteSize.Y * 0.5

                    State.runtime.castActive = true
                    State.runtime.castPhase = "holding"
                    sendMouseDown(centerX, centerY)

                    local elapsed = 0
                    local timeout = 3.5

                    while State.flags.cast and elapsed < timeout do
                        task.wait(0.02)
                        elapsed += 0.02

                        outerBar, greenFill = findCastBar(castGui)
                        local progress = getCastProgress(outerBar, greenFill)

                        if progress >= State.values.castReleasePct then
                            break
                        end

                        if not castGui.Parent or castGui.Enabled == false then
                            break
                        end
                    end

                    State.runtime.castPhase = "releasing"
                    sendMouseUp(centerX, centerY)
                    State.runtime.castActive = false
                    State.runtime.castPhase = "idle"
                    task.wait(0.45 + math.random() * 0.20)
                else
                    forceCastRelease()
                    State.runtime.castActive = false
                    State.runtime.castPhase = "searching"
                    task.wait(0.08)
                end
            else
                forceCastRelease()
                State.runtime.castActive = false
                State.runtime.castPhase = "arming"

                if tick() - State.runtime.lastCastEquipAttempt >= 0.75 then
                    State.runtime.lastCastEquipAttempt = tick()
                    equipRodSlot()
                    task.wait(0.22)
                else
                    task.wait(0.08)
                end
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

local function findReelUI()
    for _, name in ipairs({ "reelui", "ReelUI", "fishingrod", "FishingRod", "reelbar", "ReelBar", "Fishing", "FishingBar", "FishingUI" }) do
        local gui = PlayerGui:FindFirstChild(name)
        if gui and gui.Enabled ~= false then
            return gui
        end
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local lowerName = gui.Name:lower()
            if (lowerName:find("reel") or lowerName:find("fish")) and not lowerName:find("shake") then
                return gui
            end
        end
    end

    return nil
end

local function findReelElements(reelGui)
    local playerBar
    local fishBar

    for _, descendant in ipairs(reelGui:GetDescendants()) do
        if descendant:IsA("GuiObject") and descendant.Visible then
            local lowerName = descendant.Name:lower()
            if not playerBar and (lowerName == "playerbar" or lowerName == "player" or lowerName:find("playerbar")) then
                playerBar = descendant
            elseif not fishBar and (lowerName == "fish" or lowerName == "fishbar" or lowerName == "fishicon" or lowerName:find("fish") or lowerName:find("target")) then
                fishBar = descendant
            end
        end
    end

    return playerBar, fishBar
end

local function detectRewardGui()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local lowerName = gui.Name:lower()
            if lowerName:find("reward") or lowerName:find("catch") or lowerName:find("result") or lowerName:find("caught") then
                return true, "win"
            end
            if lowerName:find("fail") or lowerName:find("escape") or lowerName:find("lost") then
                return true, "lose"
            end
        end
    end

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, descendant in ipairs(gui:GetDescendants()) do
                if descendant:IsA("TextLabel") and descendant.Visible then
                    local text = descendant.Text:lower()
                    if text:find("got away") or text:find("escapou") or text:find("escaped") or text:find("failed") then
                        return true, "lose"
                    end
                    if text:find("caught") or text:find("capturou") or text:find("pescou") or text:find("hooked") then
                        return true, "win"
                    end
                end
            end
        end
    end

    return false, nil
end

local function reelMousePress(x, y)
    if State.runtime.reelMouseHeld then
        return
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, true, game, 0)
    end)
    State.runtime.reelMouseHeld = true
end

local function reelMouseRelease(x, y)
    if not State.runtime.reelMouseHeld then
        return
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(math.floor(x), math.floor(y), 0, false, game, 0)
    end)
    State.runtime.reelMouseHeld = false
end

local function reelForceRelease()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    State.runtime.reelMouseHeld = false
end

local function startAutoReel()
    reelForceRelease()
    State.runtime.reelActive = false

    startTask("autoReel", function()
        local wasActive = false
        local sessionStart = 0
        local sessionDiagnosis

        while State.flags.autoReel do
            local reelGui = findReelUI()

            if reelGui then
                if not wasActive then
                    wasActive = true
                    sessionStart = tick()
                    sessionDiagnosis = {
                        timesFar = 0,
                        timesOvershoots = 0,
                        timesInside = 0,
                        timesMid = 0,
                        startTime = tick(),
                    }
                end

                local playerBar, fishBar = findReelElements(reelGui)
                if not playerBar or not fishBar then
                    reelForceRelease()
                    State.runtime.reelActive = false
                    task.wait(0.08)
                else
                    State.runtime.reelActive = true

                    local centerX = playerBar.AbsolutePosition.X + playerBar.AbsoluteSize.X * 0.5
                    local centerY = playerBar.AbsolutePosition.Y + playerBar.AbsoluteSize.Y * 0.5
                    local barLeft = playerBar.AbsolutePosition.X
                    local barRight = playerBar.AbsolutePosition.X + playerBar.AbsoluteSize.X
                    local barWidth = math.max(playerBar.AbsoluteSize.X, 1)
                    local barCenter = barLeft + barWidth * 0.5
                    local fishCenterX = fishBar.AbsolutePosition.X + fishBar.AbsoluteSize.X * 0.5
                    local fishInside = fishCenterX >= barLeft and fishCenterX <= barRight
                    local distance = math.abs(fishCenterX - barCenter)
                    local ratio = distance / barWidth
                    local overshoot = fishCenterX < (barLeft - barWidth * 0.10) or fishCenterX > (barRight + barWidth * 0.10)

                    if sessionDiagnosis then
                        if fishInside then
                            sessionDiagnosis.timesInside += 1
                        elseif ratio < 0.30 then
                            sessionDiagnosis.timesMid += 1
                        else
                            sessionDiagnosis.timesFar += 1
                        end
                        if overshoot then
                            sessionDiagnosis.timesOvershoots += 1
                        end
                    end

                    if fishInside then
                        reelMousePress(centerX, centerY)
                        task.wait(ReelParams.hold_inside + rnd(-0.008, 0.018))
                        reelMouseRelease(centerX, centerY)
                        task.wait(ReelParams.release_inside + rnd(-0.010, 0.025))
                    elseif ratio < 0.30 then
                        reelMousePress(centerX, centerY)
                        task.wait(ReelParams.hold_mid + rnd(-0.015, 0.025))
                        reelMouseRelease(centerX, centerY)
                        task.wait(ReelParams.release_mid + rnd(-0.008, 0.018))
                    else
                        reelMousePress(centerX, centerY)
                        task.wait(ReelParams.hold_far + rnd(-0.020, 0.050))
                        reelMouseRelease(centerX, centerY)
                        task.wait(ReelParams.release_far + rnd(0, 0.015))
                    end
                end
            else
                if State.runtime.reelMouseHeld then
                    reelForceRelease()
                end
                State.runtime.reelActive = false

                if wasActive then
                    wasActive = false
                    local won = false
                    local detected = false
                    for _ = 1, 20 do
                        task.wait(0.1)
                        local found, result = detectRewardGui()
                        if found then
                            won = result == "win"
                            detected = true
                            break
                        end
                    end

                    if not detected then
                        won = (tick() - sessionStart) > 3.0
                    end

                    if sessionDiagnosis then
                        applyLearning(won, sessionDiagnosis)
                        sessionDiagnosis = nil
                    end

                    if UI.refs.reelScore then
                        local wins, total = getRecentScore(10)
                        local trend = ""
                        if total > 0 then
                            if wins >= total * 0.7 then
                                trend = " ↑"
                            elseif wins <= total * 0.3 then
                                trend = " ↓"
                            else
                                trend = " →"
                            end
                        end

                        UI.refs.reelScore.Text = string.format("Score %d/%d%s • %s", wins, total, trend, LearnHistory.lastDiagnosis)
                        UI.refs.reelScore.TextColor3 = won and Theme.success or Theme.warning
                    end

                    task.wait(1.5)
                else
                    task.wait(0.10)
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
    stopTask("autoReel")
end

local function getTreasureMaps()
    local maps = {}

    local function scan(container)
        if not container then
            return
        end

        for _, toolInstance in ipairs(container:GetChildren()) do
            if toolInstance:IsA("Tool") and (toolInstance.Name:lower():find("treasure") or toolInstance.Name:lower():find("map")) then
                local x
                local y
                local z

                for _, attr in ipairs({ "X", "x", "PosX", "CoordX", "TargetX" }) do
                    local value = toolInstance:GetAttribute(attr)
                    if value then
                        x = value
                        break
                    end
                end
                for _, attr in ipairs({ "Y", "y", "PosY", "CoordY", "TargetY" }) do
                    local value = toolInstance:GetAttribute(attr)
                    if value then
                        y = value
                        break
                    end
                end
                for _, attr in ipairs({ "Z", "z", "PosZ", "CoordZ", "TargetZ" }) do
                    local value = toolInstance:GetAttribute(attr)
                    if value then
                        z = value
                        break
                    end
                end

                if not (x and y and z) then
                    for _, descendant in ipairs(toolInstance:GetDescendants()) do
                        if descendant:IsA("Vector3Value") then
                            x = descendant.Value.X
                            y = descendant.Value.Y
                            z = descendant.Value.Z
                            break
                        end
                        if descendant:IsA("StringValue") then
                            local sx, sy, sz = descendant.Value:match("(%-?%d+)[,%s]+(%-?%d+)[,%s]+(%-?%d+)")
                            if sx then
                                x = tonumber(sx)
                                y = tonumber(sy)
                                z = tonumber(sz)
                                break
                            end
                        end
                    end
                end

                if x and y and z then
                    table.insert(maps, {
                        name = toolInstance.Name,
                        pos = Vector3.new(x, y, z),
                        fixed = true,
                        tool = toolInstance,
                    })
                else
                    table.insert(maps, {
                        name = toolInstance.Name .. " (não fixado)",
                        pos = nil,
                        fixed = false,
                        tool = toolInstance,
                    })
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

local function trySellTool(toolInstance)
    if not toolInstance then
        return false, "no_tool"
    end

    local events = ReplicatedStorage:FindFirstChild("events")
        or ReplicatedStorage:FindFirstChild("Events")
        or ReplicatedStorage:FindFirstChild("Remotes")

    if events then
        for _, name in ipairs({ "sell", "Sell", "appraise", "Appraise", "sellfish", "SellFish", "SellItem", "appraiseFish", "FishSell", "submitFish", "cashIn" }) do
            local remote = events:FindFirstChild(name)
            if remote then
                if remote:IsA("RemoteEvent") then
                    pcall(function()
                        remote:FireServer(toolInstance)
                    end)
                    return true, "RE:" .. name
                end
                if remote:IsA("RemoteFunction") then
                    local ok = pcall(function()
                        remote:InvokeServer(toolInstance)
                    end)
                    if ok then
                        return true, "RF:" .. name
                    end
                end
            end
        end

        for _, remote in ipairs(events:GetDescendants()) do
            local lowerName = remote.Name:lower()
            if (lowerName:find("sell") or lowerName:find("appraise") or lowerName:find("submit") or lowerName:find("cash")) and remote:IsA("RemoteEvent") then
                pcall(function()
                    remote:FireServer(toolInstance)
                end)
                return true, "RE:" .. remote.Name
            end
        end
    end

    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if object:IsA("GuiButton") and object.Visible then
            local lowerName = object.Name:lower()
            if lowerName:find("sell") or lowerName:find("appraise") or lowerName:find("submit") then
                local size = object.AbsoluteSize
                if size.X > 2 and size.Y > 2 then
                    pcall(function()
                        object.MouseButton1Click:Fire()
                    end)
                    return true, "GUI:" .. object.Name
                end
            end
        end
    end

    pcall(function()
        toolInstance:Activate()
    end)
    return false, "no_method"
end

local function sellFromHand()
    local toolInstance = heldTool()
    if not toolInstance then
        return false, "No item in hand"
    end
    return trySellTool(toolInstance)
end

local function sellAll()
    local sold = 0
    local failed = 0
    local items = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    if backpack then
        for _, toolInstance in ipairs(backpack:GetChildren()) do
            if toolInstance:IsA("Tool") and not (toolInstance.Name:lower():find("treasure") or toolInstance.Name:lower():find("map")) then
                table.insert(items, toolInstance)
            end
        end
    end

    local toolInstance = heldTool()
    if toolInstance and not (toolInstance.Name:lower():find("treasure") or toolInstance.Name:lower():find("map")) then
        table.insert(items, toolInstance)
    end

    for _, item in ipairs(items) do
        local ok = trySellTool(item)
        if ok then
            sold += 1
        else
            failed += 1
        end
        task.wait(0.15)
    end

    if sold == 0 and failed == 0 then
        return false, "Inventory empty"
    end

    return true, "Sold " .. sold .. (failed > 0 and (" | Failed " .. failed) or "")
end

local function startAutoSell()
    startTask("autoSell", function()
        while State.flags.autoSell do
            local ok, message = sellAll()
            setStatus(UI.refs.autoSellStatus, (ok and "✅ " or "⏳ ") .. message, ok and Theme.success or Theme.warning)
            task.wait(State.values.autoSellDelay)
        end
        setStatus(UI.refs.autoSellStatus, "Auto-sell off", Theme.muted)
    end)
end

local function stopAutoSell()
    stopTask("autoSell")
end

local function getNearbyNPCs()
    local root = rootPart()
    if not root then
        return {}
    end

    local results = {}
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Model") and object ~= LocalPlayer.Character then
            local hum = object:FindFirstChildOfClass("Humanoid")
            local part = object:FindFirstChild("HumanoidRootPart") or object:FindFirstChildOfClass("BasePart")
            if hum and part then
                local distance = (root.Position - part.Position).Magnitude
                if distance <= State.values.npcRange then
                    table.insert(results, {
                        name = object.Name,
                        part = part,
                        dist = math.floor(distance),
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return a.dist < b.dist
    end)
    return results
end

local function teleportToNPC(part)
    local root = rootPart()
    if not root then
        return
    end
    root.CFrame = CFrame.new((part.CFrame * CFrame.new(0, 0, -3.5)).Position + Vector3.new(0, 3, 0))
end

local function createRipple(button, color)
    local ripple = create("Frame", {
        Parent = button,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = color or Color3.new(1, 1, 1),
        BackgroundTransparency = 0.68,
        BorderSizePixel = 0,
        ZIndex = button.ZIndex + 1,
    })
    addCorner(ripple, 999)

    local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.2
    local tw = TweenService:Create(ripple, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, size, 0, size),
        BackgroundTransparency = 1,
    })
    tw:Play()
    tw.Completed:Connect(function()
        ripple:Destroy()
    end)
end

local function makeCard(parent, order, useAlt)
    local card = create("Frame", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = useAlt and Theme.surfaceAlt or Theme.surface,
        BorderSizePixel = 0,
    })
    addCorner(card, 10)
    addStroke(card, Theme.border, 1, 0.12)
    addPadding(card, 8, 8, 7, 7)
    create("UIListLayout", {
        Parent = card,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    })
    return card
end

local function makeDivider(parent, order)
    return create("Frame", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.border,
        BorderSizePixel = 0,
    })
end

local function makeToggle(trackParent, activeColor)
    local track = create("Frame", {
        Parent = trackParent,
        Size = UDim2.new(0, 36, 0, 18),
        BackgroundColor3 = Color3.fromRGB(24, 31, 55),
        BorderSizePixel = 0,
    })
    addCorner(track, 9)
    addStroke(track, Theme.border, 1)

    local knob = create("Frame", {
        Parent = track,
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 3, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(241, 245, 255),
        BorderSizePixel = 0,
    })
    addCorner(knob, 999)

    local hit = create("TextButton", {
        Parent = track,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
    })

    local function setState(on)
        tween(track, {
            BackgroundColor3 = on and activeColor or Color3.fromRGB(24, 31, 55),
        }, 0.16)
        spring(knob, {
            Position = on and UDim2.new(0, 21, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
        })
    end

    return {
        track = track,
        knob = knob,
        hit = hit,
        set = setState,
    }
end

local function makeSlider(parent, label, minimum, maximum, defaultValue, color, onChanged, order)
    local valueLabel = create("TextLabel", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 11),
        BackgroundTransparency = 1,
        Text = label .. ": " .. defaultValue,
        TextColor3 = color,
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local wrap = create("Frame", {
        Parent = parent,
        LayoutOrder = order + 1,
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
    })

    local bar = create("Frame", {
        Parent = wrap,
        Size = UDim2.new(1, 0, 0, 4),
        Position = UDim2.new(0, 0, 0.5, -2),
        BackgroundColor3 = Color3.fromRGB(22, 28, 49),
        BorderSizePixel = 0,
    })
    addCorner(bar, 3)

    local percent = (defaultValue - minimum) / (maximum - minimum)
    local fill = create("Frame", {
        Parent = bar,
        Size = UDim2.new(percent, 0, 1, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
    })
    addCorner(fill, 3)

    local knob = create("Frame", {
        Parent = bar,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(percent, 0, 0.5, 0),
        Size = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.fromRGB(247, 250, 255),
        BorderSizePixel = 0,
    })
    addCorner(knob, 999)

    local hit = create("TextButton", {
        Parent = bar,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
    })

    local dragging = false

    local function applyFromX(screenX)
        local pct = math.clamp((screenX - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local value = math.floor(minimum + pct * (maximum - minimum) + 0.5)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valueLabel.Text = label .. ": " .. value
        if onChanged then
            onChanged(value)
        end
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            applyFromX(input.Position.X)
        end
    end)

    hit.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            applyFromX(input.Position.X)
        end
    end)

    return {
        label = valueLabel,
        set = function(value)
            value = clamp(value, minimum, maximum)
            local pct = (value - minimum) / (maximum - minimum)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            valueLabel.Text = label .. ": " .. value
            if onChanged then
                onChanged(value)
            end
        end,
    }
end

local function makeBindRow(parent, keyCode, order)
    local row = create("Frame", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
    })

    create("TextLabel", {
        Parent = row,
        Size = UDim2.new(0, 32, 1, 0),
        BackgroundTransparency = 1,
        Text = "Key:",
        TextColor3 = Theme.muted,
        Font = Enum.Font.Gotham,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local button = create("TextButton", {
        Parent = row,
        Size = UDim2.new(0, 54, 0, 16),
        Position = UDim2.new(0, 32, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(20, 25, 47),
        BorderSizePixel = 0,
        Text = keyCode.Name,
        TextColor3 = Theme.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        AutoButtonColor = false,
    })
    addCorner(button, 5)
    addStroke(button, Theme.accentSoft, 1)

    return button
end

local function makeSearchBox(parent, placeholder, order)
    local wrap = create("Frame", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.surfaceAlt,
        BorderSizePixel = 0,
    })
    addCorner(wrap, 8)
    addStroke(wrap, Theme.border, 1)
    addPadding(wrap, 8, 8, 0, 0)

    local icon = create("TextLabel", {
        Parent = wrap,
        Size = UDim2.new(0, 16, 1, 0),
        BackgroundTransparency = 1,
        Text = "⌕",
        TextColor3 = Theme.muted,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local box = create("TextBox", {
        Parent = wrap,
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText = placeholder,
        Text = "",
        TextColor3 = Theme.text,
        PlaceholderColor3 = Theme.muted,
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    })

    return box
end

local function makeActionButton(parent, order, text, bgColor, textColor)
    local button = create("TextButton", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = bgColor,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = textColor,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        AutoButtonColor = false,
    })
    addCorner(button, 7)
    addStroke(button, Theme.border, 1)
    return button
end

local function makeStatusLabel(parent, order, fontSize, color)
    return create("TextLabel", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = color or Theme.muted,
        Font = Enum.Font.Code,
        TextSize = fontSize or 8,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function makeToggleSection(parent, options)
    local section = makeCard(parent, options.order, options.alt)

    local row = create("Frame", {
        Parent = section,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = string.format("%s  %s", options.icon, options.label),
        TextColor3 = Theme.subtext,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local toggle = makeToggle(row, options.toggleColor or Theme.accent)
    toggle.track.Position = UDim2.new(1, -36, 0.5, -9)
    toggle.hit.MouseButton1Click:Connect(function()
        createRipple(toggle.track, options.toggleColor or Theme.accent)
    end)

    local bindButton = makeBindRow(section, options.keyCode, 2)
    local status = options.showStatus and makeStatusLabel(section, 3, 8, Theme.muted) or nil
    local status2 = options.showStatus2 and makeStatusLabel(section, 4, 7, Theme.purple) or nil

    local lastOrder = options.showStatus2 and 4 or (options.showStatus and 3 or 2)

    local slider
    if options.slider then
        slider = makeSlider(
            section,
            options.slider.label,
            options.slider.min,
            options.slider.max,
            options.slider.value,
            options.slider.color or Theme.accent,
            options.slider.onChanged,
            lastOrder + 1
        )
        lastOrder += 2
    end

    local extraToggle
    if options.extraToggle then
        local extraRow = create("Frame", {
            Parent = section,
            LayoutOrder = lastOrder + 1,
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
        })

        create("TextLabel", {
            Parent = extraRow,
            Size = UDim2.new(1, -60, 1, 0),
            BackgroundTransparency = 1,
            Text = options.extraToggle.label,
            TextColor3 = Theme.subtext,
            Font = Enum.Font.GothamBold,
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        extraToggle = makeToggle(extraRow, options.extraToggle.color or Theme.accent)
        extraToggle.track.Position = UDim2.new(1, -36, 0.5, -9)
        extraToggle.hit.MouseButton1Click:Connect(function()
            createRipple(extraToggle.track, options.extraToggle.color or Theme.accent)
        end)
    end

    local function setEnabled(on)
        toggle.set(on)
        tween(label, {
            TextColor3 = on and Theme.text or Theme.subtext,
        }, 0.14)
    end

    local function setExtraEnabled(on)
        if extraToggle then
            extraToggle.set(on)
        end
    end

    return {
        section = section,
        label = label,
        bindButton = bindButton,
        status = status,
        status2 = status2,
        toggleButton = toggle.hit,
        extraToggleButton = extraToggle and extraToggle.hit or nil,
        setEnabled = setEnabled,
        setExtraEnabled = setExtraEnabled,
    }
end

local function refreshFrameSize()
    if not UI.refs.frame or not State.runtime.guiVisible then
        return
    end
    task.wait()
    UI.refs.frame.Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT + UI.refs.rootLayout.AbsoluteContentSize.Y)
end

local function switchTab(name)
    State.runtime.currentTab = name
    for tabName, page in pairs(UI.pages) do
        page.Visible = tabName == name
    end
    for tabName, button in pairs(UI.tabs) do
        tween(button, {
            BackgroundColor3 = tabName == name and Theme.accent or Theme.surfaceAlt,
            TextColor3 = tabName == name and Theme.shell or Theme.muted,
        }, 0.16)
    end
    refreshFrameSize()
end

local function setGuiVisible(visible)
    if State.runtime.guiAnimating or State.runtime.guiVisible == visible then
        return
    end

    State.runtime.guiAnimating = true
    State.runtime.guiVisible = visible

    if visible then
        UI.refs.content.Visible = true
        task.wait()
        tween(UI.refs.frame, {
            Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT + UI.refs.rootLayout.AbsoluteContentSize.Y),
            BackgroundTransparency = 0,
        }, 0.2)
        tween(UI.refs.hideHint, {
            TextColor3 = Theme.muted,
        }, 0.15)
        task.delay(0.24, function()
            State.runtime.guiAnimating = false
        end)
    else
        local shrink = tween(UI.refs.frame, {
            Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT),
        }, 0.18)
        tween(UI.refs.hideHint, {
            TextColor3 = Theme.accent,
        }, 0.15)
        shrink.Completed:Connect(function()
            if not State.runtime.guiVisible then
                UI.refs.content.Visible = false
            end
            task.delay(0.04, function()
                State.runtime.guiAnimating = false
            end)
        end)
    end
end

local function setupBind(button, bindId, getKey, setKey)
    button.MouseButton1Click:Connect(function()
        if State.runtime.listening then
            return
        end

        State.runtime.listening = bindId
        button.Text = "..."
        tween(button, { TextColor3 = Theme.warning }, 0.12)

        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end

            if input.KeyCode == Enum.KeyCode.Escape then
                button.Text = getKey().Name
                tween(button, { TextColor3 = Theme.accent }, 0.12)
                State.runtime.listening = nil
                connection:Disconnect()
                return
            end

            if BLOCKED_KEYS[input.KeyCode] then
                button.Text = "invalid!"
                tween(button, { TextColor3 = Theme.danger }, 0.12)
                task.wait(0.8)
                button.Text = getKey().Name
                tween(button, { TextColor3 = Theme.accent }, 0.12)
                State.runtime.listening = nil
                connection:Disconnect()
                return
            end

            setKey(input.KeyCode)
            button.Text = input.KeyCode.Name
            tween(button, { TextColor3 = Theme.accent }, 0.12)
            State.runtime.listening = nil
            connection:Disconnect()
        end)
    end)
end

local function updateLearningPanel()
    if not UI.refs.learnScore then
        return
    end

    local wins, total = getRecentScore(10)
    local trend = ""
    if total > 0 then
        local ratio = wins / total
        if ratio >= 0.7 then
            trend = " ↑"
        elseif ratio <= 0.3 then
            trend = " ↓"
        else
            trend = " →"
        end
    end

    UI.refs.learnScore.Text = string.format(
        "Score: %d/%d%s  |  ✅%d  ❌%d  |  ajustes:%d",
        wins,
        total,
        trend,
        LearnHistory.totalWins,
        LearnHistory.totalLosses,
        LearnHistory.adjustCount
    )

    if total > 0 then
        local ratio = wins / total
        UI.refs.learnScore.TextColor3 = ratio >= 0.6 and Theme.success or (ratio <= 0.3 and Theme.danger or Theme.warning)
    else
        UI.refs.learnScore.TextColor3 = Theme.warning
    end

    UI.refs.learnDiag.Text = "Último: " .. LearnHistory.lastDiagnosis
    UI.refs.learnParams.Text = string.format(
        "⚙ far %.0f/%.0f  mid %.0f/%.0f  in %.0f/%.0fms",
        ReelParams.hold_far * 1000,
        ReelParams.release_far * 1000,
        ReelParams.hold_mid * 1000,
        ReelParams.release_mid * 1000,
        ReelParams.hold_inside * 1000,
        ReelParams.release_inside * 1000
    )
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
    if State.flags.speed then
        applySpeedOnce()
        startSpeedLoop()
    else
        stopSpeedLoop()
    end
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
    if not State.flags.jump then
        return
    end
    State.flags.rejump = not State.flags.rejump
    UI.refs.jump.setExtraEnabled(State.flags.rejump)
    if State.flags.rejump then
        startRejumpLoop()
    else
        stopRejumpLoop()
    end
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

    if State.flags.shake then
        startShake()
    else
        stopShake()
    end

    updateActivityDot()
end

local function toggleAutoReel()
    State.flags.autoReel = not State.flags.autoReel
    UI.refs.reel.setEnabled(State.flags.autoReel)

    if State.flags.autoReel then
        startAutoReel()
    else
        stopAutoReel()
    end

    updateActivityDot()
end

local function toggleAutoSell()
    State.flags.autoSell = not State.flags.autoSell
    UI.refs.autoSell.toggle.set(State.flags.autoSell)
    tween(UI.refs.autoSell.label, {
        TextColor3 = State.flags.autoSell and Theme.text or Theme.subtext,
    }, 0.14)

    if State.flags.autoSell then
        startAutoSell()
    else
        stopAutoSell()
        setStatus(UI.refs.autoSellStatus, "Auto-sell off", Theme.muted)
    end

    updateActivityDot()
end

local function flashAction(button, baseColor, pulseColor)
    createRipple(button, pulseColor)
    tween(button, { BackgroundColor3 = pulseColor }, 0.08)
    task.delay(0.12, function()
        tween(button, { BackgroundColor3 = baseColor }, 0.15)
    end)
end

local function runSellInHand()
    task.spawn(function()
        flashAction(UI.refs.sellButton, Theme.sell, Theme.sellHover)
        local ok, message = sellFromHand()
        setStatus(UI.refs.sellStatus, (ok and "✅ " or "❌ ") .. message, ok and Theme.success or Theme.danger)
        task.wait(3)
        setStatus(UI.refs.sellStatus, "Waiting...", Theme.muted)
    end)
end

local function runSellAll()
    task.spawn(function()
        flashAction(UI.refs.sellAllButton, Color3.fromRGB(16, 57, 35), Theme.sellHover)
        local ok, message = sellAll()
        setStatus(UI.refs.sellStatus, (ok and "✅ " or "❌ ") .. message, ok and Theme.success or Theme.danger)
        task.wait(3)
        setStatus(UI.refs.sellStatus, "Waiting...", Theme.muted)
    end)
end

local function renderTeleportList()
    local holder = UI.refs.tpList
    if not holder then
        return
    end

    for _, child in ipairs(holder:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local query = (UI.search.tp and UI.search.tp.Text or ""):lower()
    local layoutOrder = 1

    for _, island in ipairs(ISLANDS) do
        local include = query == "" or island.name:lower():find(query, 1, true)
        if include then
            local textColor = Theme.subtext
            local baseColor = Theme.surface
            local hoverColor = Theme.surfaceHover

            if island.cat == "second" then
                textColor = Theme.cyan
                baseColor = Color3.fromRGB(14, 35, 46)
                hoverColor = Color3.fromRGB(18, 49, 63)
            elseif island.cat == "deep" then
                textColor = Color3.fromRGB(255, 132, 184)
                baseColor = Color3.fromRGB(40, 16, 35)
                hoverColor = Color3.fromRGB(57, 23, 49)
            end

            local button = makeActionButton(holder, layoutOrder, "📍  " .. island.name, baseColor, textColor)
            button.TextXAlignment = Enum.TextXAlignment.Left
            addPadding(button, 10, 10, 0, 0)

            button.MouseEnter:Connect(function()
                tween(button, { BackgroundColor3 = hoverColor, TextColor3 = Theme.text }, 0.15)
            end)
            button.MouseLeave:Connect(function()
                tween(button, { BackgroundColor3 = baseColor, TextColor3 = textColor }, 0.15)
            end)
            button.MouseButton1Click:Connect(function()
                createRipple(button, textColor)
                local ok = teleportTo(island.pos)
                setStatus(UI.refs.tpStatus, (ok and "✅ " or "❌ ") .. island.name, ok and Theme.success or Theme.danger)
                task.delay(3, function()
                    setStatus(UI.refs.tpStatus, "", Theme.success)
                end)
            end)

            layoutOrder += 1
        end
    end

    if layoutOrder == 1 then
        create("TextLabel", {
            Parent = holder,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = "Nada encontrado",
            TextColor3 = Theme.muted,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
end

local function renderRodList()
    local holder = UI.refs.rodList
    if not holder then
        return
    end

    for _, child in ipairs(holder:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local query = (UI.search.rods and UI.search.rods.Text or ""):lower()
    local layoutOrder = 1

    for _, rod in ipairs(RODS) do
        local searchable = (rod.name .. " " .. rod.loc):lower()
        if query == "" or searchable:find(query, 1, true) then
            local button = create("TextButton", {
                Parent = holder,
                LayoutOrder = layoutOrder,
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.surface,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
            })
            addCorner(button, 10)
            addStroke(button, Theme.border, 1)
            addPadding(button, 10, 10, 4, 4)

            create("TextLabel", {
                Parent = button,
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = "🎣  " .. rod.name,
                TextColor3 = Theme.cyan,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            create("TextLabel", {
                Parent = button,
                Position = UDim2.new(0, 0, 0, 16),
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,
                Text = rod.loc,
                TextColor3 = Theme.muted,
                Font = Enum.Font.Gotham,
                TextSize = 8,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            button.MouseEnter:Connect(function()
                tween(button, { BackgroundColor3 = Theme.surfaceHover }, 0.15)
            end)
            button.MouseLeave:Connect(function()
                tween(button, { BackgroundColor3 = Theme.surface }, 0.15)
            end)
            button.MouseButton1Click:Connect(function()
                createRipple(button, Theme.cyan)
                local ok = teleportTo(rod.pos)
                setStatus(UI.refs.rodStatus, (ok and "✅ TP -> " or "❌ ") .. rod.name, ok and Theme.success or Theme.danger)
                task.delay(3, function()
                    setStatus(UI.refs.rodStatus, "", Theme.success)
                end)
            end)

            layoutOrder += 1
        end
    end

    if layoutOrder == 1 then
        create("TextLabel", {
            Parent = holder,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = "Nada encontrado",
            TextColor3 = Theme.muted,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
end

local function refreshMaps()
    local holder = UI.refs.mapList
    if not holder then
        return
    end

    for _, child in ipairs(holder:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local maps = getTreasureMaps()
    if #maps == 0 then
        create("TextLabel", {
            Parent = holder,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            Text = "Nenhum mapa no inventário",
            TextColor3 = Theme.muted,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        refreshFrameSize()
        return
    end

    for index, map in ipairs(maps) do
        local button = create("TextButton", {
            Parent = holder,
            LayoutOrder = index,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = map.fixed and Theme.surface or Color3.fromRGB(48, 38, 22),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        })
        addCorner(button, 8)
        addStroke(button, Theme.border, 1)
        addPadding(button, 10, 10, 4, 4)

        create("TextLabel", {
            Parent = button,
            Size = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            Text = (map.fixed and "📜  " or "❔  ") .. map.name,
            TextColor3 = map.fixed and Theme.gold or Theme.warning,
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        create("TextLabel", {
            Parent = button,
            Position = UDim2.new(0, 0, 0, 14),
            Size = UDim2.new(1, 0, 0, 11),
            BackgroundTransparency = 1,
            Text = map.fixed
                and string.format("X=%d  Y=%d  Z=%d", map.pos.X, map.pos.Y, map.pos.Z)
                or "→ leve no Jack Marrow para fixar",
            TextColor3 = map.fixed and Theme.cyan or Theme.muted,
            Font = Enum.Font.Code,
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        if map.fixed then
            button.MouseEnter:Connect(function()
                tween(button, { BackgroundColor3 = Theme.surfaceHover }, 0.15)
            end)
            button.MouseLeave:Connect(function()
                tween(button, { BackgroundColor3 = Theme.surface }, 0.15)
            end)
            button.MouseButton1Click:Connect(function()
                createRipple(button, Theme.gold)
                teleportTo(map.pos)
            end)
        end
    end

    refreshFrameSize()
end

local function rebuildNPCs()
    local holder = UI.refs.npcList
    if not holder then
        return
    end

    for _, child in ipairs(holder:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local npcs = getNearbyNPCs()
    if #npcs == 0 then
        create("TextLabel", {
            Parent = holder,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = "No NPCs within " .. State.values.npcRange .. " studs",
            TextColor3 = Theme.muted,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        return
    end

    for index, npc in ipairs(npcs) do
        local button = makeActionButton(holder, index, "🧑  " .. npc.name .. "  (" .. npc.dist .. " st)", Theme.surface, Theme.subtext)
        button.TextXAlignment = Enum.TextXAlignment.Left
        addPadding(button, 10, 10, 0, 0)
        button.MouseEnter:Connect(function()
            tween(button, { BackgroundColor3 = Theme.surfaceHover, TextColor3 = Theme.text }, 0.15)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { BackgroundColor3 = Theme.surface, TextColor3 = Theme.subtext }, 0.15)
        end)
        button.MouseButton1Click:Connect(function()
            createRipple(button, Theme.accent)
            teleportToNPC(npc.part)
            task.delay(0.8, rebuildNPCs)
        end)
    end
end

loadLearnData()

pcall(function()
    for _, name in ipairs({ "UtilityGui", "NoclipGui" }) do
        local existing = PlayerGui:FindFirstChild(name)
        if existing then
            existing:Destroy()
        end
    end
end)

local gui = create("ScreenGui", {
    Parent = PlayerGui,
    Name = "UtilityGui",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    IgnoreGuiInset = true,
})

local frame = create("Frame", {
    Parent = gui,
    Size = UDim2.new(0, GUI_WIDTH, 0, HEADER_HEIGHT),
    Position = UDim2.new(0, -GUI_WIDTH, 0.5, WINDOW_Y_OFFSET),
    BackgroundColor3 = Theme.shell,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})
addCorner(frame, 14)
addGradient(frame, 90, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 14, 24)),
    ColorSequenceKeypoint.new(1, Theme.shell),
})
local frameStroke = addStroke(frame, Theme.border, 1.5, 0.06)

local header = create("Frame", {
    Parent = frame,
    Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    ZIndex = 2,
})
addGradient(header, 90, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 25, 54)),
    ColorSequenceKeypoint.new(1, Theme.panel),
})

local activityDot = create("Frame", {
    Parent = header,
    Size = UDim2.new(0, 7, 0, 7),
    Position = UDim2.new(0, 12, 0.5, -4),
    BackgroundColor3 = Theme.muted,
    BorderSizePixel = 0,
    ZIndex = 4,
})
addCorner(activityDot, 999)

create("TextLabel", {
    Parent = header,
    Size = UDim2.new(1, -70, 0, 16),
    Position = UDim2.new(0, 24, 0, 5),
    BackgroundTransparency = 1,
    Text = "UTILITY v18",
    TextColor3 = Theme.text,
    Font = Enum.Font.GothamBlack,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

create("TextLabel", {
    Parent = header,
    Size = UDim2.new(1, -70, 0, 11),
    Position = UDim2.new(0, 24, 0, 20),
    BackgroundTransparency = 1,
    Text = "compact + auto systems",
    TextColor3 = Theme.subtext,
    Font = Enum.Font.Gotham,
    TextSize = 7,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local hideHint = create("TextLabel", {
    Parent = header,
    Size = UDim2.new(0, 22, 0, 14),
    Position = UDim2.new(1, -30, 0.5, -7),
    BackgroundColor3 = Color3.fromRGB(22, 28, 54),
    BorderSizePixel = 0,
    Text = "V",
    TextColor3 = Theme.muted,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    ZIndex = 4,
})
addCorner(hideHint, 5)

local content = create("Frame", {
    Parent = frame,
    Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
    Size = UDim2.new(1, 0, 0, 9999),
    BackgroundTransparency = 1,
})

local rootLayout = create("UIListLayout", {
    Parent = content,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
})

UI.refs.frame = frame
UI.refs.frameStroke = frameStroke
UI.refs.activityDot = activityDot
UI.refs.content = content
UI.refs.hideHint = hideHint
UI.refs.rootLayout = rootLayout

local tabBar = create("Frame", {
    Parent = content,
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
})
addPadding(tabBar, 4, 4, 4, 3)

create("UIListLayout", {
    Parent = tabBar,
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local function createTab(name, title, order)
    local button = create("TextButton", {
        Parent = tabBar,
        LayoutOrder = order,
        Size = UDim2.new(0.2, -3, 1, 0),
        BackgroundColor3 = Theme.surfaceAlt,
        BorderSizePixel = 0,
        Text = title,
        TextColor3 = Theme.muted,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        AutoButtonColor = false,
    })
    addCorner(button, 7)
    UI.tabs[name] = button
    button.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

createTab("Cheats", "Cheats", 1)
createTab("TP", "Travel", 2)
createTab("Rods", "Rods", 3)
createTab("Maps", "Maps", 4)
createTab("NPCs", "NPCs", 5)

makeDivider(content, 2)

local function createPage(name, order)
    local page = create("Frame", {
        Parent = content,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    })
    create("UIListLayout", {
        Parent = page,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })
    UI.pages[name] = page
    return page
end

local cheatsPage = createPage("Cheats", 3)
local tpPage = createPage("TP", 4)
local rodsPage = createPage("Rods", 5)
local mapsPage = createPage("Maps", 6)
local npcsPage = createPage("NPCs", 7)

makeDivider(cheatsPage, 1)

UI.refs.noclip = makeToggleSection(cheatsPage, {
    order = 2,
    icon = "👻",
    label = "Noclip",
    keyCode = State.keys.noclip,
    toggleColor = Theme.success,
})
makeDivider(cheatsPage, 3)

UI.refs.speed = makeToggleSection(cheatsPage, {
    order = 4,
    icon = "💨",
    label = "Speed",
    keyCode = State.keys.speed,
    toggleColor = Theme.accent,
    slider = {
        label = "Speed",
        min = 16,
        max = 300,
        value = State.values.speed,
        color = Theme.accent,
        onChanged = function(value)
            State.values.speed = value
        end,
    },
})
makeDivider(cheatsPage, 5)

UI.refs.jump = makeToggleSection(cheatsPage, {
    order = 6,
    icon = "🦘",
    label = "High Jump",
    keyCode = State.keys.jump,
    toggleColor = Theme.warning,
    slider = {
        label = "Power",
        min = 50,
        max = 500,
        value = State.values.jump,
        color = Theme.warning,
        onChanged = function(value)
            State.values.jump = value
        end,
    },
    extraToggle = {
        label = "↩  Re-jump",
        color = Theme.warning,
    },
})
makeDivider(cheatsPage, 7)

UI.refs.cast = makeToggleSection(cheatsPage, {
    order = 8,
    icon = "🎯",
    label = "Auto Cast",
    keyCode = State.keys.cast,
    toggleColor = Theme.cast,
    showStatus = true,
})
makeDivider(cheatsPage, 9)

UI.refs.shake = makeToggleSection(cheatsPage, {
    order = 10,
    icon = "🔄",
    label = "Shake",
    keyCode = State.keys.shake,
    toggleColor = Theme.success,
    showStatus = true,
})
makeDivider(cheatsPage, 11)

UI.refs.reel = makeToggleSection(cheatsPage, {
    order = 12,
    icon = "🎣",
    label = "Auto-Reel  🧠",
    keyCode = State.keys.reel,
    toggleColor = Theme.purple,
    showStatus = true,
    showStatus2 = true,
})
UI.refs.reelScore = UI.refs.reel.status

local learningCard = makeCard(UI.refs.reel.section, 6, true)
addStroke(learningCard, Color3.fromRGB(76, 56, 130), 1)

create("TextLabel", {
    Parent = learningCard,
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "🧠  Aprendizado adaptativo",
    TextColor3 = Theme.purple,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.learnScore = create("TextLabel", {
    Parent = learningCard,
    LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundTransparency = 1,
    Text = "Score: —",
    TextColor3 = Theme.text,
    Font = Enum.Font.Code,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.learnDiag = create("TextLabel", {
    Parent = learningCard,
    LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundTransparency = 1,
    Text = "Último: —",
    TextColor3 = Theme.subtext,
    Font = Enum.Font.Code,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.learnParams = create("TextLabel", {
    Parent = learningCard,
    LayoutOrder = 4,
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.muted,
    Font = Enum.Font.Code,
    TextSize = 7,
    TextXAlignment = Enum.TextXAlignment.Left,
})

makeDivider(learningCard, 5).BackgroundColor3 = Color3.fromRGB(76, 56, 130)

local resetLearningButton = makeActionButton(learningCard, 6, "🔄  Resetar aprendizado", Color3.fromRGB(43, 18, 56), Theme.purple)
resetLearningButton.MouseEnter:Connect(function()
    tween(resetLearningButton, { BackgroundColor3 = Color3.fromRGB(59, 24, 74) }, 0.14)
end)
resetLearningButton.MouseLeave:Connect(function()
    tween(resetLearningButton, { BackgroundColor3 = Color3.fromRGB(43, 18, 56) }, 0.14)
end)
resetLearningButton.MouseButton1Click:Connect(function()
    createRipple(resetLearningButton, Theme.purple)
    ReelParams.hold_far = 0.200
    ReelParams.release_far = 0.025
    ReelParams.hold_mid = 0.095
    ReelParams.release_mid = 0.040
    ReelParams.hold_inside = 0.042
    ReelParams.release_inside = 0.055
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
    Parent = sellCard,
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "💰  Sell",
    TextColor3 = Theme.subtext,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})

UI.refs.sellStatus = create("TextLabel", {
    Parent = sellCard,
    LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "Waiting...",
    TextColor3 = Theme.muted,
    Font = Enum.Font.Code,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local sellBindButton = makeBindRow(sellCard, State.keys.sell, 3)

UI.refs.sellButton = makeActionButton(sellCard, 4, "💰  Sell Item in Hand", Theme.sell, Theme.success)
UI.refs.sellButton.MouseEnter:Connect(function()
    tween(UI.refs.sellButton, { BackgroundColor3 = Theme.sellHover }, 0.15)
end)
UI.refs.sellButton.MouseLeave:Connect(function()
    tween(UI.refs.sellButton, { BackgroundColor3 = Theme.sell }, 0.15)
end)

makeDivider(sellCard, 5)

UI.refs.sellAllButton = makeActionButton(sellCard, 6, "📦  Sell All (mantém mapas)", Color3.fromRGB(16, 57, 35), Theme.success)
UI.refs.sellAllButton.MouseEnter:Connect(function()
    tween(UI.refs.sellAllButton, { BackgroundColor3 = Theme.sellHover }, 0.15)
end)
UI.refs.sellAllButton.MouseLeave:Connect(function()
    tween(UI.refs.sellAllButton, { BackgroundColor3 = Color3.fromRGB(16, 57, 35) }, 0.15)
end)

makeDivider(sellCard, 7)

local autoSellRow = create("Frame", {
    Parent = sellCard,
    LayoutOrder = 8,
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
})

UI.refs.autoSell = {}
UI.refs.autoSell.label = create("TextLabel", {
    Parent = autoSellRow,
    Size = UDim2.new(1, -60, 1, 0),
    BackgroundTransparency = 1,
    Text = "🔁  Auto-Sell",
    TextColor3 = Theme.subtext,
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
})
UI.refs.autoSell.toggle = makeToggle(autoSellRow, Theme.success)
UI.refs.autoSell.toggle.track.Position = UDim2.new(1, -36, 0.5, -9)
UI.refs.autoSell.toggle.hit.MouseButton1Click:Connect(function()
    createRipple(UI.refs.autoSell.toggle.track, Theme.success)
end)

makeSlider(sellCard, "Delay", 5, 100, math.floor(State.values.autoSellDelay * 10), Theme.success, function(value)
    State.values.autoSellDelay = value / 10
end, 9)

UI.refs.autoSellStatus = makeStatusLabel(sellCard, 11, 8, Theme.muted)
makeDivider(cheatsPage, 15)

local tpCard = makeCard(tpPage, 1)
UI.refs.tpStatus = makeStatusLabel(tpCard, 1, 8, Theme.success)
UI.search.tp = makeSearchBox(tpCard, "Buscar ilha...", 2)

local tpScroll = create("ScrollingFrame", {
    Parent = tpCard,
    LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 250),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.accent,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
})
addPadding(tpScroll, 0, 0, 0, 0)
UI.refs.tpList = tpScroll
create("UIListLayout", {
    Parent = tpScroll,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local rodsCard = makeCard(rodsPage, 1)
UI.refs.rodStatus = makeStatusLabel(rodsCard, 1, 8, Theme.success)
UI.search.rods = makeSearchBox(rodsCard, "Buscar vara...", 2)

local rodsScroll = create("ScrollingFrame", {
    Parent = rodsCard,
    LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 250),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.accent,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
})
UI.refs.rodList = rodsScroll
create("UIListLayout", {
    Parent = rodsScroll,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local mapsCard = makeCard(mapsPage, 1)
create("TextLabel", {
    Parent = mapsCard,
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "📜  Treasure Maps no inventário",
    TextColor3 = Theme.gold,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})
create("TextLabel", {
    Parent = mapsCard,
    LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "Leva o mapa no Jack Marrow pra fixar as coords",
    TextColor3 = Theme.muted,
    Font = Enum.Font.Gotham,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local scanMapsButton = makeActionButton(mapsCard, 3, "🔍  Escanear mapas", Color3.fromRGB(53, 40, 16), Theme.gold)
local jackButton = makeActionButton(mapsCard, 4, "🏴  TP Jack Marrow (fixar mapas)", Color3.fromRGB(18, 34, 53), Theme.accent)

local mapList = create("Frame", {
    Parent = mapsCard,
    LayoutOrder = 5,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
})
UI.refs.mapList = mapList
create("UIListLayout", {
    Parent = mapList,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
})

local npcCard = makeCard(npcsPage, 1)
makeSlider(npcCard, "Scan range", 1, 1000, State.values.npcRange, Theme.accent, function(value)
    State.values.npcRange = value
end, 1)

local scanNpcButton = makeActionButton(npcCard, 3, "🔍  Scan Nearby NPCs", Color3.fromRGB(18, 34, 62), Theme.accent)

local npcScroll = create("ScrollingFrame", {
    Parent = npcCard,
    LayoutOrder = 4,
    Size = UDim2.new(1, 0, 0, 210),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.accent,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
})
UI.refs.npcList = npcScroll
create("UIListLayout", {
    Parent = npcScroll,
    SortOrder = Enum.SortOrder.LayoutOrder,
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

scanMapsButton.MouseEnter:Connect(function()
    tween(scanMapsButton, { BackgroundColor3 = Color3.fromRGB(68, 51, 20) }, 0.15)
end)
scanMapsButton.MouseLeave:Connect(function()
    tween(scanMapsButton, { BackgroundColor3 = Color3.fromRGB(53, 40, 16) }, 0.15)
end)
scanMapsButton.MouseButton1Click:Connect(function()
    createRipple(scanMapsButton, Theme.gold)
    scanMapsButton.Text = "⏳  Escaneando..."
    task.wait(0.2)
    refreshMaps()
    scanMapsButton.Text = "🔍  Escanear mapas"
end)

jackButton.MouseEnter:Connect(function()
    tween(jackButton, { BackgroundColor3 = Color3.fromRGB(24, 44, 66) }, 0.15)
end)
jackButton.MouseLeave:Connect(function()
    tween(jackButton, { BackgroundColor3 = Color3.fromRGB(18, 34, 53) }, 0.15)
end)
jackButton.MouseButton1Click:Connect(function()
    createRipple(jackButton, Theme.accent)
    teleportTo(Vector3.new(-2825, 215, 1515))
end)

scanNpcButton.MouseEnter:Connect(function()
    tween(scanNpcButton, { BackgroundColor3 = Color3.fromRGB(24, 44, 74) }, 0.15)
end)
scanNpcButton.MouseLeave:Connect(function()
    tween(scanNpcButton, { BackgroundColor3 = Color3.fromRGB(18, 34, 62) }, 0.15)
end)
scanNpcButton.MouseButton1Click:Connect(function()
    createRipple(scanNpcButton, Theme.accent)
    scanNpcButton.Text = "⏳  Scanning..."
    task.wait(0.15)
    rebuildNPCs()
    scanNpcButton.Text = "🔍  Scan Nearby NPCs"
end)

UI.search.tp:GetPropertyChangedSignal("Text"):Connect(renderTeleportList)
UI.search.rods:GetPropertyChangedSignal("Text"):Connect(renderRodList)

setupBind(UI.refs.noclip.bindButton, "noclip", function()
    return State.keys.noclip
end, function(keyCode)
    State.keys.noclip = keyCode
end)
setupBind(UI.refs.speed.bindButton, "speed", function()
    return State.keys.speed
end, function(keyCode)
    State.keys.speed = keyCode
end)
setupBind(UI.refs.jump.bindButton, "jump", function()
    return State.keys.jump
end, function(keyCode)
    State.keys.jump = keyCode
end)
setupBind(UI.refs.cast.bindButton, "cast", function()
    return State.keys.cast
end, function(keyCode)
    State.keys.cast = keyCode
end)
setupBind(UI.refs.shake.bindButton, "shake", function()
    return State.keys.shake
end, function(keyCode)
    State.keys.shake = keyCode
end)
setupBind(UI.refs.reel.bindButton, "reel", function()
    return State.keys.reel
end, function(keyCode)
    State.keys.reel = keyCode
end)
setupBind(sellBindButton, "sell", function()
    return State.keys.sell
end, function(keyCode)
    State.keys.sell = keyCode
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or State.runtime.listening then
        return
    end

    local keyCode = input.KeyCode

    if keyCode == State.keys.toggleGui then
        setGuiVisible(not State.runtime.guiVisible)
    elseif keyCode == State.keys.noclip then
        toggleNoclip()
    elseif keyCode == State.keys.speed then
        toggleSpeed()
    elseif keyCode == State.keys.jump then
        toggleJump()
    elseif keyCode == State.keys.cast then
        toggleCast()
    elseif keyCode == State.keys.shake then
        toggleShake()
    elseif keyCode == State.keys.reel then
        toggleAutoReel()
    elseif keyCode == State.keys.sell then
        runSellInHand()
    end
end)

do
    local dragging = false
    local dragStart
    local startPosition

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = frame.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if State.flags.noclip then
        setNoclip(true)
    end
    if State.flags.speed then
        applySpeedOnce()
        startSpeedLoop()
    end
    if State.flags.jump then
        startJumpLoop()
    end
    if State.flags.rejump and State.flags.jump then
        startRejumpLoop()
    end
end)

startTask("autosaveLearning", function()
    while true do
        task.wait(30)
        saveLearnData()
    end
end)

startTask("learningPanel", function()
    while true do
        task.wait(0.5)
        updateLearningPanel()
    end
end)

startTask("shakeStatus", function()
    local dots = { "", ".", "..", "..." }
    local index = 1
    while true do
        task.wait(0.2)
        index = index % #dots + 1

        if State.flags.shake then
            local text = State.runtime.shakeActive
                and ("● Enter pressing" .. dots[index])
                or ("○ waiting shake" .. dots[index])
            setStatus(UI.refs.shake.status, text, State.runtime.shakeActive and Theme.success or Theme.warning)
        else
            setStatus(UI.refs.shake.status, "", Theme.muted)
        end
    end
end)

startTask("castStatus", function()
    local dots = { "", ".", "..", "..." }
    local index = 1
    while true do
        task.wait(0.2)
        index = index % #dots + 1

        if State.flags.cast then
            if State.runtime.castActive then
                if State.runtime.castPhase == "holding" then
                    setStatus(UI.refs.cast.status, "▲ carregando" .. dots[index], Theme.cast)
                else
                    setStatus(UI.refs.cast.status, "↓ soltando" .. dots[index], Theme.success)
                end
            elseif State.runtime.castPhase == "arming" then
                setStatus(UI.refs.cast.status, "○ puxando vara [1]" .. dots[index], Theme.warning)
            elseif State.runtime.castPhase == "searching" then
                setStatus(UI.refs.cast.status, "⌕ aguardando verde" .. dots[index], Theme.warning)
            else
                setStatus(UI.refs.cast.status, "○ aguardando cast" .. dots[index], Theme.warning)
            end
        else
            setStatus(UI.refs.cast.status, "", Theme.muted)
        end
    end
end)

startTask("reelStatus", function()
    local dots = { "", ".", "..", "..." }
    local index = 1
    while true do
        task.wait(0.25)
        index = index % #dots + 1

        if State.flags.autoReel then
            if State.runtime.reelActive then
                setStatus(UI.refs.reel.status, "● pescando" .. dots[index], Theme.success)
            else
                setStatus(UI.refs.reel.status, "○ aguardando UI" .. dots[index], Theme.warning)
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
