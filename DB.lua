-- Настройки: TrailkitDB (аккаунт) + TrailkitBackupDB (персонаж).
-- При загрузке берётся копия с большим rev, каждое поле проверяется по типу.
local _, ns = ...

local DB = {}
ns.DB = DB

local DEFAULTS = {
    locked = true,
    lockIcons = false,
    bars = {
        aspects = { point = "BOTTOMRIGHT", relPoint = "BOTTOM", x = -20, y = 160, scale = 1, hidden = false },
        traps   = { point = "BOTTOMLEFT",  relPoint = "BOTTOM", x = 20,  y = 160, scale = 1, hidden = false },
    },
}

local POINTS = {
    TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- v == v отсекает NaN
local function IsNumber(v) return type(v) == "number" and v == v end
local function IsBool(v) return type(v) == "boolean" end
local function IsPoint(v) return type(v) == "string" and POINTS[v] == true end
local function IsScale(v) return IsNumber(v) and v >= 0.5 and v <= 2 end

local function IsOrder(v)
    if type(v) ~= "table" then return false end
    for _, key in ipairs(v) do
        if type(key) ~= "string" then return false end
    end
    return true
end

local function Rev(t)
    return type(t) == "table" and IsNumber(t.rev) and t.rev or -1
end

-- Безопасный доступ к вложенным полям
local function Sub(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[select(i, ...)]
    end
    return t
end

-- Первое валидное значение из двух источников, иначе значение по умолчанию
local function Pick(sources, key, check, default)
    for i = 1, 2 do
        local t = sources[i]
        if type(t) == "table" and check(t[key]) then return t[key] end
    end
    return default
end

function DB.Load()
    local main, backup = TrailkitDB, TrailkitBackupDB
    local first, second = main, backup
    if Rev(backup) > Rev(main) then
        first, second = backup, main
        DB.restored = true
    end

    local db = { rev = math.max(Rev(main), Rev(backup), 0), bars = {} }
    db.locked = Pick({ first, second }, "locked", IsBool, DEFAULTS.locked)
    db.lockIcons = Pick({ first, second }, "lockIcons", IsBool, DEFAULTS.lockIcons)
    for name, def in pairs(DEFAULTS.bars) do
        local s = { Sub(first, "bars", name), Sub(second, "bars", name) }
        db.bars[name] = {
            point = Pick(s, "point", IsPoint, def.point),
            relPoint = Pick(s, "relPoint", IsPoint, def.relPoint),
            x = Pick(s, "x", IsNumber, def.x),
            y = Pick(s, "y", IsNumber, def.y),
            scale = Pick(s, "scale", IsScale, def.scale),
            hidden = Pick(s, "hidden", IsBool, def.hidden),
            order = CopyTable(Pick(s, "order", IsOrder, {})),
        }
    end

    TrailkitDB = db
    ns.db = db
    DB.Backup()
end

-- Копия в персонажную переменную
function DB.Backup()
    TrailkitBackupDB = CopyTable(ns.db)
end

-- Вызывать после каждого изменения настроек
function DB.Save()
    ns.db.rev = ns.db.rev + 1
    DB.Backup()
end

-- Позиция и видимость панели по умолчанию (масштаб и порядок не трогаем)
function DB.ResetBar(name)
    local def, cfg = DEFAULTS.bars[name], ns.db.bars[name]
    cfg.point, cfg.relPoint, cfg.x, cfg.y = def.point, def.relPoint, def.x, def.y
    cfg.hidden = false
end
