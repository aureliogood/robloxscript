--[[ ══════════════════════════════════════════════════════════════
     VBL HUB  ·  Volleyball Legends
     Place ID: 73956553001240
     Tipo: hub cliente para ejecutor (Delta / Wave / Xeno / Solara / AWP)

     Módulos:
       · Hitbox   -> cubos de golpeo por acción
       · Balón    -> escalado del balón
       · Extras   -> multiplicadores y saque perfecto
       · Gacha    -> auto giro de estilos y habilidades
     ══════════════════════════════════════════════════════════════ ]]

if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref = cloneref or function(o) return o end
local Players            = cloneref(game:GetService("Players"))
local RunService         = cloneref(game:GetService("RunService"))
local ReplicatedStorage  = cloneref(game:GetService("ReplicatedStorage"))

local LOCAL_PLAYER = Players.LocalPlayer
local PLACE_ID     = 73956553001240

if game.PlaceId ~= PLACE_ID then
    warn("[VBL] No estás en Volleyball Legends. El hub seguirá cargando igual.")
end

-- ── anti doble ejecución ───────────────────────────────────────
if _G.VBL_HUB_LOADED then
    pcall(function() _G.VBL_HUB_UNLOAD() end)
    task.wait(0.35)
end
_G.VBL_HUB_LOADED = true

-- ── UI ─────────────────────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "VBL Hub",
    LoadingTitle = "VBL Hub",
    LoadingSubtitle = "cargando módulos...",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- ── estado global ──────────────────────────────────────────────
local HITBOX_ACTIONS = {"Spike", "Set", "JumpSet", "Serve", "Dive", "Bump", "Block"}
local BALL_PREFIX    = "CLIENT_BALL_"
local CONFIG_DIR     = "VBLHub"
local CONFIG_FILE    = CONFIG_DIR .. "/config.json"

local State = {
    HitboxEnabled = true,
    BallEnabled   = true,
    PerfectServe  = false,
    HitboxSize    = {},   -- [acción] = número
    BallScale     = 2,
    OnlyMine      = true, -- no tocar hitboxes de otros jugadores

    RollInterval  = 0.15,
    FreeArg       = true,
    TargetName    = "",
    RollCount     = 0,
    AutoRoll      = { style = false, ability = false },
}

for _, action in ipairs(HITBOX_ACTIONS) do
    State.HitboxSize[action] = 4
end

local originals = {}  -- [part] = Vector3
local ballBase  = {}  -- [part] = Vector3
local loaded    = true

-- ── filesystem opcional ────────────────────────────────────────
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
            FreeArg       = State.FreeArg,
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
    if type(data.FreeArg) == "boolean" then State.FreeArg = data.FreeArg end
    if type(data.TargetName) == "string" then State.TargetName = data.TargetName end
end

loadConfig()

-- ── helpers del juego ──────────────────────────────────────────
local function hitboxesFolder()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Hitboxes")
end

local function myCharacter()
    return LOCAL_PLAYER.Character
end

local function ownsModel(model)
    if not State.OnlyMine then return true end
    local char = myCharacter()
    if not char then return false end
    return model:IsDescendantOf(char)
end

-- ── módulo: hitboxes ───────────────────────────────────────────
local function applyHitboxes()
    local folder = hitboxesFolder()
    if not folder then return end

    for _, action in ipairs(HITBOX_ACTIONS) do
        local container = folder:FindFirstChild(action)
        if not container then continue end

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

local function restoreHitboxes()
    for part, size in pairs(originals) do
        if part.Parent then part.Size = size end
    end
    table.clear(originals)
end

-- ── módulo: balón ──────────────────────────────────────────────
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

-- ── loop ───────────────────────────────────────────────────────
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

-- ── módulo: serve perfecto (hook del remoto) ───────────────────
local serveRF
pcall(function()
    serveRF = ReplicatedStorage.Packages._Index["sleitnick_knit@1.7.0"]
        .knit.Services.GameService.RF.Serve
end)

local oldNamecall
if serveRF and typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not loaded then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if method == "InvokeServer" and self == serveRF and State.PerfectServe then
            return oldNamecall(self, nil, 0.95)
        end
        return oldNamecall(self, ...)
    end)
end

-- ── módulo: gacha ──────────────────────────────────────────────
local KNIT = {"Packages", "_Index", "sleitnick_knit@1.7.0", "knit", "Services"}

local function knitServices()
    local node = ReplicatedStorage
    for _, k in ipairs(KNIT) do
        if not node then return nil end
        node = node:FindFirstChild(k)
    end
    return node
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
            local roll = rf and rf:FindFirstChild("Roll")
            if roll and roll:IsA("RemoteFunction") then
                RollRF[kind] = roll
                return roll
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
    pcall(function() rf:InvokeServer(State.FreeArg) end)
    State.RollCount += 1
    return true
end

local function rollLoop(kind)
    if Rolling[kind] then return end
    Rolling[kind] = true

    task.spawn(function()
        while Rolling[kind] and loaded do
            if fire(kind) then
                local target = State.TargetName:lower()
                if target ~= "" then
                    task.wait(0.5)
                    local name = currentName(kind)
                    if name and name:lower():find(target, 1, true) then
                        Rolling[kind] = false
                        State.AutoRoll[kind] = false
                        Rayfield:Notify({
                            Title = "Objetivo obtenido",
                            Content = name,
                            Duration = 8,
                        })
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
            task.wait(0.05)
        end
        Rayfield:Notify({ Title = "Ráfaga terminada", Content = count .. " giros", Duration = 4 })
    end)
end

-- ── pestañas ───────────────────────────────────────────────────
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
        Rayfield:Notify({ Title = "Hitboxes", Content = "Tamaños originales restaurados", Duration = 3 })
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
TabGacha:CreateSection("Giros automáticos")

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
    Name = "Intervalo entre giros",
    Range = {0, 0.6},
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

TabGacha:CreateSection("Avanzado")

TabGacha:CreateToggle({
    Name = "Enviar flag de giro gratis",
    Description = "El remoto recibe 'true'. Si no giran, desactívalo",
    CurrentValue = State.FreeArg,
    Callback = function(v)
        State.FreeArg = v
        saveConfig()
    end,
})

TabGacha:CreateButton({
    Name = "Listar remotos de roll detectados",
    Callback = function()
        print("[VBL] stylesRF:", resolveRF("style"))
        print("[VBL] abilityRF:", resolveRF("ability"))
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
    Description = serveRF and "Fuerza potencia máxima en cada saque" or "Remoto no encontrado",
    CurrentValue = false,
    Disabled = not serveRF,
    Callback = function(value)
        State.PerfectServe = value
    end,
})

TabMisc:CreateButton({
    Name = "Imprimir rutas de depuración",
    Callback = function()
        print("[VBL] Assets:", ReplicatedStorage:FindFirstChild("Assets"))
        print("[VBL] Hitboxes:", hitboxesFolder())
        print("[VBL] ServeRF:", serveRF)
    end,
})

-- ── unload ─────────────────────────────────────────────────────
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
    Content = "Cargado. Pestañas: Hitbox, Balón, Gacha, Extras.",
    Duration = 5,
})