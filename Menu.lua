-- Контекстное меню панели (правый клик по панели или иконке)
local _, ns = ...
local L = ns.L

local Menu = {}
ns.Menu = Menu

local SCALES = { 0.75, 1, 1.25, 1.5 }

local function OutOfCombat() return not InCombatLockdown() end

function Menu.Open(bar)
    MenuUtil.CreateContextMenu(bar, function(_, root)
        local cfg = ns.db.bars[bar.name]
        root:CreateTitle(bar.title)

        root:CreateCheckbox(L.LOCK,
            function() return ns.db.locked end,
            function() ns.SetLocked(not ns.db.locked) end)

        root:CreateCheckbox(L.LOCK_ICONS,
            function() return ns.db.lockIcons end,
            function()
                ns.db.lockIcons = not ns.db.lockIcons
                ns.DB.Save()
            end)

        local scale = root:CreateButton(L.SCALE)
        scale:SetEnabled(OutOfCombat)
        for _, value in ipairs(SCALES) do
            scale:CreateRadio(string.format("%d%%", value * 100),
                function() return cfg.scale == value end,
                function() ns.SetScale(bar, value) end)
        end

        root:CreateButton(L.HIDE_PANEL, function() ns.HideBar(bar) end):SetEnabled(OutOfCombat)
        root:CreateButton(L.RESET_POSITION, function() ns.ResetBars(bar) end):SetEnabled(OutOfCombat)
    end)
end
