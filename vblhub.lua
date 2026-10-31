--[[ ══════════════════════════════════════════════════════════════
     VBL HUB  ·  Volleyball Legends
     Place ID: 73956553001240
     Tipo: hub cliente para ejecutor (Delta / Wave / Xeno / Solara / AWP)
     ══════════════════════════════════════════════════════════════ ]]

if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref = cloneref or function(o) return o end
local Players            = cloneref(game:GetService("Players"))
local RunService         = cloneref(game:GetService("RunService"))
local ReplicatedStorage  = cloneref(game:GetService("ReplicatedStorage"))

local LOCAL_PLAYER = Players.LocalPlayer
local PLACE_ID     = 73956553001240

if game.PlaceId ~= PLACE_ID then
    warn("[VBL] No estás en Volleyball Legends.")
end

if _G.VBL_HUB_LOADED then
    pcall(function() _G.VBL_HUB_UNLOAD() end)
    task.wait(0.35)
end
_G.VBL_HUB_LOADED = true

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "VBL Hub",
    LoadingTitle = "VBL Hub",
    LoadingSubtitle = "cargando módulos...",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local HITBOX_ACTIONS = {"Spike", "Set", "JumpSet", "Serve", "Dive", "Bump", "Block"}
local BALL_PREFIX    = "CLIENT_BALL_"
local CONFIG_DIR     = "VBLHub"
local CONFIG_FILE    = CONFIG_DIR .. "/config.json"

local CODES = {
    "UPDATE_93", "CURSED", "TOURNAMENT",
    "UPDATE_92", "MAMORI", "PARRY",
    "UPDATE_91", "REPLAYS", "MVP",
    "UPDATE_90", "JINX", "SKELETON_BUNDLE",
}

local State = {
    HitboxEnabled = true,
    BallEnabled   = true,
    PerfectServe  = false,
    HitboxSize    = {},
    BallScale     = 2,
    OnlyMine      = true,

    RollInterval  = 0.25,
    RollMode      = 2,       -- 2 = lucky
    TargetName    = "",
    RollCount     = 0,
    AutoRoll      = { style = false, ability = false },
}

for _, action in ipairs(HITBOX_ACTIONS) do
    State.HitboxSize[action] = 4
end

local originals, ballBase = {}, {}
local loaded = true

local function fsAvailable()
    return typeof(writefile) == "function" and typeof(isfile) == "function"
end

local function saveConfig()
    if not fsAvailable() then return end
    pcall(function()
        if typeof(isfolder) == "function" and not isfolder(CONFIG_DIR) then
            makefolder(CONFIG_DIR)
        end
        writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode({
            HitboxSize    = State.HitboxSize,
            BallScale     = State.BallScale,
            HitboxEnabled = State.HitboxEnabled,
            BallEnabled   = State.BallEnabled,
            RollInterval  = State.RollInterval,
            RollMode      = State.RollMode,
            TargetName    = State.TargetName,
        }))
    end)
end

local function loadConfig()
    if not fsAvailable() or not isfile(CONFIG_FILE) then return end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
    end)
    if not ok or type(data) ~= "table" then return end
    if type(data.HitboxSize) == "table" then
        for action, size in pairs(data.HitboxSize) do
            if State.HitboxSize[action] and type(size) == "number" then
                State.HitboxSize[action] = size
            end
        end
    end
    if type(data.BallScale) == "number" then State.BallScale = data.BallScale end
    if type(data.HitboxEnabled) == "boolean" then State.HitboxEnabled = data.HitboxEnabled end
    if type(data.BallEnabled) == "boolean" then State.BallEnabled = data.BallEnabled end
    if type(data.RollInterval) == "number" then State.RollInterval = data.RollInterval end
    if type(data.RollMode) == "number" then State.RollMode = data.RollMode end
    if type(data.TargetName) == "string" then State.TargetName = data.TargetName end
end

loadConfig()

local function hitboxesFolder()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Hitboxes")
end

local function ownsModel(model)
    if not State.OnlyMine then return true end
    local char = LOCAL_PLAYER.Character
    return char ~= nil and model:IsDescendantOf(char)
end

local function applyHitboxes()
    local folder = hitboxesFolder()
    if not folder then return end
    for _, action in ipairs(HITBOX_ACTIONS) do
        local container = folder:FindFirstChild(action)
        if container then
            for _, part in ipairs(container:GetDescendants()) do
                if part:IsA("BasePart") and ownsModel(part) then
                    originals[part] = originals[part] or part.Size
                    local size = State.HitboxSize[action]
                    local target = Vector3.new(size, size, size)
                    if (part.Size - target).Magnitude > 0.05 then
                        part.Size = target
                    end
                    part.CanTouch = true
                    part.CanQuery = true
                end
            end
        end
    end
end

local function restoreHitboxes()
    for part, size in pairs(originals) do
        if part.Parent then part.Size = size end
    end
    table.clear(originals)
end

local function applyBalls()
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:sub(1, #BALL_PREFIX) == BALL_PREFIX then
            for _, child in ipairs(model:GetChildren()) do
                if child:IsA("BasePart") then
                    ballBase[child] = ballBase[child] or child.Size
                    local target = ballBase[child] * State.BallScale
                    if (child.Size - target).Magnitude > 0.05 then
                        child.Size = target
                    end
                    child.CanTouch = true
                end
            end
        end
    end
end

local function restoreBalls()
    for part, size in pairs(ballBase) do
        if part.Parent then part.Size = size end
    end
    table.clear(ballBase)
end

local accumulator, ACCUM_MAX = 0, 0.15

local loopConn = RunService.RenderStepped:Connect(function(dt)
    if not loaded then return end
    accumulator += dt
    if accumulator < ACCUM_MAX then return end
    accumulator = 0
    if State.HitboxEnabled then
        local ok, err = pcall(applyHitboxes)
        if not ok then warn("[VBL] hitbox:", err) end
    end
    if State.BallEnabled then
        pcall(applyBalls)
    end
end)

local serveRF
pcall(function()
    serveRF = ReplicatedStorage.Packages._Index["sleitnick_knit@1.7.0"]
        .knit.Services.GameService.RF.Serve
end)

local oldNamecall
if serveRF and typeof(hookmetamethod) == "function" then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if loaded and getnamecallmethod() == "InvokeServer"
            and self == serveRF and State.PerfectServe then
            return oldNamecall(self, nil, 0.95)
        end
        return oldNamecall(self, ...)
    end)
end

-- ══════════════════════════════════════════════════════════════
--  GACHA
-- ══════════════════════════════════════════════════════════════
local KNIT = {"Packages", "_Index", "sleitnick_knit@1.7.0", "knit", "Services"}

local function knitServices()
    local node = ReplicatedStorage
    for _, k in ipairs(KNIT) do
        if not node then return nil end
        node = node:FindFirstChild(k)
    end
    return node
end

local VARIANTS = {
    { id = "normal (yen)",  invoke = function(rf) return rf:InvokeServer(false) end },
    { id = "lucky",         invoke = function(rf) return rf:InvokeServer(true) end },
    { id = "sin args",      invoke = function(rf) return rf:InvokeServer() end },
    { id = "3",             invoke = function(rf) return rf:InvokeServer(3) end },
    { id = "normal,3",      invoke = function(rf) return rf:InvokeServer(false, 3) end },
    { id = "lucky,3",       invoke = function(rf) return rf:InvokeServer(true, 3) end },
    { id = "3,lucky",       invoke = function(rf) return rf:InvokeServer(3, true) end },
}

local function variantIds()
    local out = {}
    for _, v in ipairs(VARIANTS) do out[#out + 1] = v.id end
    return out
end

local RollRF = {}
local Rolling = { style = false, ability = false }

local function resolveRF(kind)
    local cached = RollRF[kind]
    if cached and cached.Parent then return cached end

    local services = knitServices()
    if not services then return nil end

    local pattern = (kind == "style") and "style" or "abilit"
    for _, svc in ipairs(services:GetChildren()) do
        if svc.Name:lower():find(pattern) then
            local rf = svc:FindFirstChild("RF")
            if rf then
                local roll = rf:FindFirstChild("Roll") or rf:FindFirstChild("Rolls")
                if roll and roll:IsA("RemoteFunction") then
                    RollRF[kind] = roll
                    return roll
                end
            end
        end
    end
    return nil
end

local function currentName(kind)
    local gui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
    local iface = gui and gui:FindFirstChild("Interface")
    local lobby = iface and iface:FindFirstChild("Lobby")
    if not lobby then return nil end
    local panel = lobby:FindFirstChild((kind == "style") and "Styles" or "Abilities")
    local top = panel and panel:FindFirstChild("TopPanel")
    local lbl = top and top:FindFirstChild("DisplayName")
    return lbl and lbl.Text or nil
end

local function fire(kind)
    local rf = resolveRF(kind)
    if not rf then return false end
    local variant = VARIANTS[State.RollMode] or VARIANTS[2]
    local ok = pcall(variant.invoke, rf)
    if ok then State.RollCount += 1 end
    return ok
end

local function rollLoop(kind)
    if Rolling[kind] then return end
    Rolling[kind] = true

    task.spawn(function()
        while Rolling[kind] and loaded do
            if fire(kind) then
                local target = State.TargetName:lower()
                if target ~= "" then
                    task.wait(0.6)
                    local name = currentName(kind)
                    if name and name:lower():find(target, 1, true) then
                        Rolling[kind] = false
                        State.AutoRoll[kind] = false
                        Rayfield:Notify({ Title = "Objetivo obtenido", Content = name, Duration = 8 })
                        break
                    end
                end
            end
            task.wait(State.RollInterval)
        end
        Rolling[kind] = false
    end)
end

local function burst(kind, count)
    task.spawn(function()
        for _ = 1, count do
            if not loaded then break end
            fire(kind)
            task.wait(0.06)
        end
        Rayfield:Notify({ Title = "Ráfaga terminada", Content = count .. " intentos", Duration = 4 })
    end)
end

local function probe(kind)
    task.spawn(function()
        local rf = resolveRF(kind)
        if not rf then
            Rayfield:Notify({ Title = "Remoto no encontrado", Content = "Usa listar remotos.", Duration = 6 })
            return
        end

        print("════ [VBL] probando argumentos en", kind, "════")
        local wins = {}

        for _, v in ipairs(VARIANTS) do
            if not loaded then break end
            local before = currentName(kind)
            local ok, err = pcall(v.invoke, rf)
            task.wait(0.9)
            local after = currentName(kind)
            local changed = before ~= after

            print(string.format("[VBL] %-12s ok=%s cambio=%s resultado=%s",
                v.id, tostring(ok), tostring(changed), tostring(after)))
            if not ok then print("[VBL]   error:", tostring(err)) end
            if changed then
                wins[#wins + 1] = v.id
                print("[VBL]   >>> FUNCIONA")
            end
            task.wait(0.25)
        end

        print("[VBL] ganadores:", #wins > 0 and table.concat(wins, ", ") or "ninguno")
        Rayfield:Notify({
            Title = "Prueba terminada",
            Content = #wins > 0 and ("Funciona: " .. table.concat(wins, ", ")) or "Ninguno, revisa tus spins",
            Duration = 10,
        })
    end)
end

-- ── obtención de spins gratis ─────────────────────────────────
local function codesRF()
    local services = knitServices()
    if not services then return nil end
    for _, svc in ipairs(services:GetChildren()) do
        if svc.Name:lower():find("code") then
            local rf = svc:FindFirstChild("RF")
            if rf then
                for _, name in ipairs({"Redeem", "UseCode", "Claim", "Code", "RedeemCode"}) do
                    local r = rf:FindFirstChild(name)
                    if r and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then
                        return r
                    end
                end
            end
        end
    end
    return nil
end

local function redeemAll()
    local rf = codesRF()
    if not rf then
        Rayfield:Notify({
            Title = "Remoto de códigos no encontrado",
            Content = "Usa listar remotos y mándame la salida.",
            Duration = 8,
        })
        return
    end

    task.spawn(function()
        local sent, worked = 0, 0
        for _, code in ipairs(CODES) do
            if not loaded then break end
            local ok, result = pcall(function()
                if rf:IsA("RemoteFunction") then
                    return rf:InvokeServer(code)
                end
                rf:FireServer(code)
            end)
            sent += 1
            if ok and result ~= false then worked += 1 end
            print("[VBL] código:", code, "->", tostring(result))
            task.wait(0.7)
        end
        Rayfield:Notify({
            Title = "Códigos enviados",
            Content = sent .. " enviados, " .. worked .. " aceptados",
            Duration = 8,
        })
    end)
end

local rewardRF
pcall(function()
    rewardRF = ReplicatedStorage.Packages._Index["sleitnick_knit@1.7.0"]
        .knit.Services.RewardService.RF.RequestPlayWithDeveloperAward
end)

local function spamRewards(times)
    if not rewardRF then
        Rayfield:Notify({ Title = "RewardService no encontrado", Duration = 6 })
        return
    end
    task.spawn(function()
        local hits = 0
        for _ = 1, times do
            if not loaded then break end
            if pcall(function() rewardRF:InvokeServer() end) then
                hits += 1
            end
            task.wait(0.04)
        end
        Rayfield:Notify({ Title = "Recompensas", Content = hits .. " peticiones", Duration = 5 })
    end)
end

-- ── pestañas ──────────────────────────────────────────────────
local TabMain = Window:CreateTab("Hitbox", 4483362458)
TabMain:CreateSection("Cubo de golpeo")

TabMain:CreateToggle({
    Name = "Activar hitboxes",
    CurrentValue = State.HitboxEnabled,
    Flag = "hitbox_master",
    Callback = function(value)
        State.HitboxEnabled = value
        if not value then restoreHitboxes() end
        saveConfig()
    end,
})

for _, action in ipairs(HITBOX_ACTIONS) do
    TabMain:CreateSlider({
        Name = action,
        Range = {1, 30},
        Increment = 0.5,
        Suffix = " studs",
        CurrentValue = State.HitboxSize[action],
        Flag = "hitbox_" .. action,
        Callback = function(value)
            State.HitboxSize[action] = value
            saveConfig()
        end,
    })
end

TabMain:CreateButton({
    Name = "Resetear a valores del juego",
    Callback = function()
        restoreHitboxes()
        Rayfield:Notify({ Title = "Hitboxes", Content = "Tamaños restaurados", Duration = 3 })
    end,
})

local TabBall = Window:CreateTab("Balón", 4483362458)
TabBall:CreateSection("Escalado del balón")

TabBall:CreateToggle({
    Name = "Inflar balón",
    CurrentValue = State.BallEnabled,
    Flag = "ball_master",
    Callback = function(value)
        State.BallEnabled = value
        if not value then restoreBalls() end
        saveConfig()
    end,
})

TabBall:CreateSlider({
    Name = "Escala",
    Range = {1, 6},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = State.BallScale,
    Flag = "ball_scale",
    Callback = function(value)
        State.BallScale = value
        saveConfig()
    end,
})

local TabGacha = Window:CreateTab("Gacha", 4483362458)

TabGacha:CreateSection("Spins gratis")
TabGacha:CreateParagraph({
    Title = "Lucky Spins",
    Content = "El servidor los entrega por códigos, recompensas y eventos. Reclama y luego gira en modo lucky.",
})

TabGacha:CreateButton({
    Name = "Reclamar códigos activos",
    Callback = redeemAll,
})

TabGacha:CreateButton({
    Name = "Spamear recompensas x100",
    Callback = function() spamRewards(100) end,
})

TabGacha:CreateSection("Giros")

TabGacha:CreateDropdown({
    Name = "Modo de giro",
    Options = variantIds(),
    CurrentOption = { VARIANTS[State.RollMode] and VARIANTS[State.RollMode].id or "lucky" },
    Callback = function(opt)
        for i, v in ipairs(VARIANTS) do
            if v.id == opt then
                State.RollMode = i
                saveConfig()
                return
            end
        end
    end,
})

TabGacha:CreateToggle({
    Name = "Auto giro de estilo",
    CurrentValue = false,
    Callback = function(v)
        State.AutoRoll.style = v
        if v then rollLoop("style") else Rolling.style = false end
    end,
})

TabGacha:CreateToggle({
    Name = "Auto giro de habilidad",
    CurrentValue = false,
    Callback = function(v)
        State.AutoRoll.ability = v
        if v then rollLoop("ability") else Rolling.ability = false end
    end,
})

TabGacha:CreateSlider({
    Name = "Intervalo",
    Range = {0, 0.8},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = State.RollInterval,
    Callback = function(v)
        State.RollInterval = v
        saveConfig()
    end,
})

TabGacha:CreateButton({
    Name = "Ráfaga x50 estilos",
    Callback = function() burst("style", 50) end,
})

TabGacha:CreateButton({
    Name = "Ráfaga x50 habilidades",
    Callback = function() burst("ability", 50) end,
})

pcall(function()
    TabGacha:CreateInput({
        Name = "Parar al obtener",
        PlaceholderText = "ej: Oikawa",
        CurrentValue = State.TargetName,
        RemoveTextAfterFocusLost = false,
        Callback = function(v)
            State.TargetName = v
            saveConfig()
        end,
    })
end)

TabGacha:CreateSection("Diagnóstico")

TabGacha:CreateButton({
    Name = "Probar argumentos · estilo",
    Callback = function() probe("style") end,
})

TabGacha:CreateButton({
    Name = "Probar argumentos · habilidad",
    Callback = function() probe("ability") end,
})

TabGacha:CreateButton({
    Name = "Listar remotos",
    Callback = function()
        print("[VBL] codesRF:", codesRF())
        print("[VBL] rewardRF:", rewardRF)
        local services = knitServices()
        if services then
            for _, svc in ipairs(services:GetChildren()) do
                if svc:FindFirstChild("RF") then
                    print("[VBL] servicio:", svc.Name, "->", svc.RF:GetChildren())
                end
            end
        end
    end,
})

local TabMisc = Window:CreateTab("Extras", 4483362458)
TabMisc:CreateSection("Atributos locales")

local function multiplier(name, attr, min, max, def)
    TabMisc:CreateSlider({
        Name = name,
        Range = {min, max},
        Increment = 0.1,
        CurrentValue = def,
        Callback = function(value)
            LOCAL_PLAYER:SetAttribute(attr, value)
        end,
    })
end

multiplier("Potencia de remate", "GameSpikePowerMultiplier", 0, 20, 1)
multiplier("Potencia de saque", "GameServePowerMultiplier", 0, 20, 1)
multiplier("Potencia de bloqueo", "GameBlockPowerMultiplier", 0, 20, 1)
multiplier("Potencia de recepción", "GameBumpPowerMultiplier", 0, 20, 1)
multiplier("Velocidad", "GameSpeedMultiplier", 0.5, 3, 1)
multiplier("Salto", "GameJumpPowerMultiplier", 0.5, 5, 1)

TabMisc:CreateSection("Remoto")

TabMisc:CreateToggle({
    Name = "Saque perfecto",
    Description = serveRF and "Potencia máxima en cada saque" or "Remoto no encontrado",
    CurrentValue = false,
    Disabled = not serveRF,
    Callback = function(value)
        State.PerfectServe = value
    end,
})

_G.VBL_HUB_UNLOAD = function()
    loaded = false
    Rolling.style, Rolling.ability = false, false
    loopConn:Disconnect()
    restoreHitboxes()
    restoreBalls()
    pcall(function()
        if oldNamecall then
            hookmetamethod(game, "__namecall", function(self, ...)
                return oldNamecall(self, ...)
            end)
        end
    end)
    pcall(function() Rayfield:Destroy() end)
    _G.VBL_HUB_LOADED = nil
    print("[VBL] hub descargado")
end

Rayfield:Notify({
    Title = "VBL Hub",
    Content = "Gacha -> Reclamar códigos, luego gira en modo lucky.",
    Duration = 7,
})