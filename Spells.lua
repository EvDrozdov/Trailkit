-- Таблицы спеллов. ranks — ID всех рангов по возрастанию;
-- на кнопку ставится старший изученный ранг, подсветка аспекта проверяет все ранги.
local _, ns = ...

-- Ретейл (Midnight): тестовые спеллы, по одному рангу
ns.Spells = {
    aspects = {
        { key = "cheetah", ranks = { 186257 } }, -- Aspect of the Cheetah
        { key = "turtle",  ranks = { 186265 } }, -- Aspect of the Turtle
    },
    traps = {
        { key = "freezing", ranks = { 187650 } }, -- Freezing Trap
        { key = "tar",      ranks = { 187698 } }, -- Tar Trap
    },
}

--[[ Заготовка для WoW Forever. ID взяты из классики — сверить на Forever.
ns.Spells = {
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
]]
