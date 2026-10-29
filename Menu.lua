-- Контекстное меню панели (правый клик по панели или иконке)
local _, ns = ...
local L = ns.L

local Menu = {}
ns.Menu = Menu

local SCALES = { 0.75, 1, 1.25, 1.5 }

local function OutOfCombat() return not InCombatLockdown() end

-- btn передаётся при клике по иконке — тогда добавляются пункты перестановки
function Menu.Open(bar, btn)
    MenuUtil.CreateContextMenu(bar, function(_, root)
        local cfg = ns.db.bars[bar.name]
        root:CreateTitle(bar.title)

        root:CreateCheckbox(L.LOCK,
            function() return ns.db.locked end,
            function() ns.SetLocked(not ns.db.locked) end)

        local scale = root:CreateButton(L.SCALE)
        scale:SetEnabled(OutOfCombat)
        for _, value in ipairs(SCALES) do
            scale:CreateRadio(string.format("%d%%", value * 100),
                function() return cfg.scale == value end,
                function() ns.SetScale(bar, value) end)
        end

        root:CreateButton(L.HIDE_PANEL, function() ns.HideBar(bar) end):SetEnabled(OutOfCombat)
        root:CreateButton(L.RESET_POSITION, function() ns.ResetBars(bar) end):SetEnabled(OutOfCombat)

        if btn then
            root:CreateDivider()
            root:CreateButton(L.MOVE_LEFT, function() ns.Bar.Move(bar, btn, -1) end)
                :SetEnabled(function() return ns.Bar.CanMove(bar, btn, -1) end)
            root:CreateButton(L.MOVE_RIGHT, function() ns.Bar.Move(bar, btn, 1) end)
                :SetEnabled(function() return ns.Bar.CanMove(bar, btn, 1) end)
        end
    end)
end
