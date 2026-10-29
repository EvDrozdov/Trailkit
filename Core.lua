-- Инициализация, события, действия с настройками и слэш-команды
local addonName, ns = ...
local L = ns.L
local Bar = ns.Bar

ns.testMode = false

function ns.Print(msg)
    print("|cffaad372Trailkit|r: " .. msg)
end

local function CombatBlocked()
    if InCombatLockdown() then
        ns.Print(L.MSG_COMBAT)
        return true
    end
end

function ns.SetLocked(locked)
    ns.db.locked = locked
    ns.DB.Save()
    for _, bar in pairs(Bar.frames) do Bar.UpdateLock(bar) end
    ns.Print(locked and L.MSG_LOCKED or L.MSG_UNLOCKED)
end

-- bar = nil — для обеих панелей
function ns.SetScale(bar, value)
    if CombatBlocked() then return end
    for name, b in pairs(Bar.frames) do
        if not bar or b == bar then ns.db.bars[name].scale = value end
    end
    ns.DB.Save()
    Bar.RebuildAll()
    ns.Print(L.MSG_SCALE:format(value))
end

function ns.SetStyle(style)
    if CombatBlocked() then return end
    ns.db.style = style
    ns.DB.Save()
    Bar.RebuildAll()
end

function ns.HideBar(bar)
    if CombatBlocked() then return end
    ns.db.bars[bar.name].hidden = true
    ns.DB.Save()
    Bar.RebuildAll()
    ns.Print(L.MSG_HIDDEN)
end

-- bar = nil — сбросить обе панели
function ns.ResetBars(bar)
    if CombatBlocked() then return end
    for name, b in pairs(Bar.frames) do
        if not bar or b == bar then ns.DB.ResetBar(name) end
    end
    ns.DB.Save()
    Bar.RebuildAll()
    if not bar then ns.Print(L.MSG_RESET) end
end

local function ToggleTest()
    if CombatBlocked() then return end
    ns.testMode = not ns.testMode
    Bar.RebuildAll()
    ns.Print(ns.testMode and L.MSG_TEST_ON or L.MSG_TEST_OFF)
end

local function PrintHelp()
    ns.Print(L.HELP_TITLE)
    print("  /tk lock — " .. L.HELP_LOCK)
    print("  /tk unlock — " .. L.HELP_UNLOCK)
    print("  /tk scale <0.5–2> — " .. L.HELP_SCALE)
    print("  /tk reset — " .. L.HELP_RESET)
    print("  /tk test — " .. L.HELP_TEST)
    print("  /tk help — " .. L.HELP_HELP)
end

SLASH_TRAILKIT1 = "/trailkit"
SLASH_TRAILKIT2 = "/tk"
SlashCmdList.TRAILKIT = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg or ""):lower(), 2)
    if cmd == "lock" then
        ns.SetLocked(true)
    elseif cmd == "unlock" then
        ns.SetLocked(false)
    elseif cmd == "scale" then
        -- принимаем и «1,5», и «1.5»
        local value = tonumber(arg and (arg:gsub(",", ".")))
        if value and value >= 0.5 and value <= 2 then
            ns.SetScale(nil, value)
        else
            ns.Print(L.MSG_SCALE_BAD)
        end
    elseif cmd == "reset" then
        ns.ResetBars(nil)
    elseif cmd == "test" then
        ToggleTest()
    else
        PrintHelp()
    end
end

local frame = CreateFrame("Frame")
local handlers = {}

-- Регистрируем только существующие в клиенте события
local function Register(event)
    if C_EventUtils.IsEventValid(event) then frame:RegisterEvent(event) end
end

function handlers.ADDON_LOADED(name)
    if name ~= addonName then return end
    frame:UnregisterEvent("ADDON_LOADED")
    ns.DB.Load()
    Bar.Create("aspects", L.ASPECTS)
    Bar.Create("traps", L.TRAPS)

    Register("PLAYER_LOGIN")
    Register("SPELLS_CHANGED")
    Register("PLAYER_SPECIALIZATION_CHANGED")
    Register("PLAYER_REGEN_ENABLED")
    Register("SPELL_UPDATE_COOLDOWN")
    Register("PLAYER_LOGOUT")
    frame:RegisterUnitEvent("UNIT_AURA", "player")
end

function handlers.PLAYER_LOGIN()
    Bar.RebuildAll()
    if ns.DB.restored then ns.Print(L.MSG_RESTORED) end
end

-- Изучение спеллов/рангов и смена спека
function handlers.SPELLS_CHANGED() Bar.RebuildAll() end
function handlers.PLAYER_SPECIALIZATION_CHANGED() Bar.RebuildAll() end

function handlers.PLAYER_REGEN_ENABLED()
    if Bar.pending then Bar.RebuildAll() end
end

function handlers.SPELL_UPDATE_COOLDOWN() Bar.UpdateCooldowns() end
function handlers.UNIT_AURA() Bar.UpdateAuras() end
function handlers.PLAYER_LOGOUT() ns.DB.Backup() end

frame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
frame:RegisterEvent("ADDON_LOADED")
