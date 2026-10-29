-- Таблицы спеллов по клиентам. ranks — ID всех рангов по возрастанию;
-- на кнопку ставится старший изученный ранг, подсветка аспекта проверяет все ранги.
-- Неизученные спеллы (талант другого спека и т.п.) на панели не показываются.
local _, ns = ...

-- Клиент определяем по номеру интерфейса из GetBuildInfo(): он уникален для каждого
-- клиента и совпадает с номерами в TOC (Forever — 16001, ретейл — 12xxxx).
-- WOW_PROJECT_ID для Forever не задокументирован (клиент на Mainline-коде может
-- вернуть WOW_PROJECT_MAINLINE), а проверка API не различает клиенты с общим API.
local interface = select(4, GetBuildInfo())
ns.client = interface < 100000 and "forever" or "midnight"

local SETS = {}

-- Midnight (ретейл)
SETS.midnight = {
    aspects = {
        { key = "cheetah", ranks = { 186257 } }, -- Aspect of the Cheetah
        { key = "turtle",  ranks = { 186265 } }, -- Aspect of the Turtle
        { key = "eagle",   ranks = { 186289 } }, -- Aspect of the Eagle (Survival)
    },
    traps = {
        { key = "freezing",      ranks = { 187650 } }, -- Freezing Trap
        { key = "tar",           ranks = { 187698 } }, -- Tar Trap
        { key = "highexplosive", ranks = { 236776 } }, -- High Explosive Trap
        { key = "implosive",     ranks = { 462031 } }, -- Implosive Trap
        { key = "steel",         ranks = { 162488 } }, -- Steel Trap (Survival)
    },
}

-- WoW Forever. ID взяты из классики — сверить на Forever.
SETS.forever = {
    aspects = {
        { key = "monkey",  ranks = { 13163 } },                                           -- Aspect of the Monkey
        { key = "hawk",    ranks = { 13165, 14318, 14319, 14320, 14321, 14322, 25296 } }, -- Aspect of the Hawk
        { key = "cheetah", ranks = { 5118 } },                                            -- Aspect of the Cheetah
        { key = "pack",    ranks = { 13159 } },                                           -- Aspect of the Pack
        { key = "beast",   ranks = { 13161 } },                                           -- Aspect of the Beast
        { key = "wild",    ranks = { 20043, 20190 } },                                    -- Aspect of the Wild
    },
    traps = {
        { key = "immolation", ranks = { 13795, 14302, 14303, 14304, 14305 } }, -- Immolation Trap
        { key = "freezing",   ranks = { 1499, 14310, 14311 } },                -- Freezing Trap
        { key = "frost",      ranks = { 13809 } },                             -- Frost Trap
        { key = "explosive",  ranks = { 13813, 14316, 14317 } },               -- Explosive Trap
    },
}

ns.Spells = SETS[ns.client]
