--[[ ══════════════════════════════════════════════════════════════
     VBL HITBOX HUB  ·  Volleyball Legends
     Place ID: 73956553001240
     Tipo: hub cliente para ejecutor (Delta / Wave / Xeno / Solara / AWP)

     Estructura pensada para que la publiques tú:
       · loader  -> loadstring(game:HttpGet("TU_RAW_URL"))()
       · config  -> archivo JSON persistente
       · módulos -> tabs aislados, cada uno con su propio restore
     ══════════════════════════════════════════════════════════════ ]]

if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref = cloneref or function(o) return o end
local Players            = cloneref(game:GetService("Players"))
local RunService         = cloneref(game:GetService("RunService"))
local ReplicatedStorage  = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService   = cloneref(game:GetService("UserInputService"))

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
    Name = "VBL Hitbox Hub",
    LoadingTitle = "VBL Hitbox Hub",
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
            HitboxSize = State.HitboxSize,
            BallScale  = State.BallScale,
            HitboxEnabled = State.HitboxEnabled,
            BallEnabled   = State.BallEnabled,
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
    Title = "VBL Hitbox Hub",
    Content = "Cargado. Cambia de pestaña para configurar.",
    Duration = 5,
})