-- Панели: secure-кнопки спеллов, подсветка активного аспекта, кулдауны, перемещение
local _, ns = ...
local L = ns.L

local Bar = {}
ns.Bar = Bar

local BUTTON_SIZE = 36
local SPACING = 4
local PADDING = 4
local PLACEHOLDER_ICON = 134400 -- знак вопроса

-- issecretvalue может отсутствовать в клиенте без secret values
local issecret = issecretvalue or function() return false end

Bar.frames = {}
Bar.pending = false -- пересборка отложена до выхода из боя

local function Cfg(bar) return ns.db.bars[bar.name] end

local function IsKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    return IsPlayerSpell(spellID)
end

-- Старший изученный ранг или nil
local function HighestKnownRank(ranks)
    for i = #ranks, 1, -1 do
        if IsKnown(ranks[i]) then return ranks[i] end
    end
end

-- Записи из Spells.lua в порядке пользователя; новые ключи — в конце
local function OrderedEntries(bar)
    local pos = {}
    for i, key in ipairs(Cfg(bar).order) do pos[key] = i end
    local list, fallback = {}, {}
    for i, entry in ipairs(ns.Spells[bar.name]) do
        list[i] = entry
        fallback[entry.key] = 1000 + i
    end
    table.sort(list, function(a, b)
        return (pos[a.key] or fallback[a.key]) < (pos[b.key] or fallback[b.key])
    end)
    return list
end

-- Перемещение панелей: при снятом замке и вне боя
function Bar.CanMovePanel()
    return not ns.db.locked and not InCombatLockdown()
end

-- Перестановка иконок: вне боя, если не запрещена галочкой (замок панелей не влияет)
function Bar.CanReorder()
    return not ns.db.lockIcons and not InCombatLockdown()
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellID then
        GameTooltip:SetSpellByID(self.spellID)
    else
        GameTooltip:SetSpellByID(self.entry.ranks[1])
        GameTooltip:AddLine(L.TOOLTIP_TEST, 1, 0.82, 0)
    end
    if not InCombatLockdown() then
        if Bar.CanReorder() then
            GameTooltip:AddLine(L.TOOLTIP_REORDER, 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine(L.TOOLTIP_MENU, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function OnMouseUp(self, button)
    if button == "RightButton" then ns.Menu.Open(self.bar) end
end

-- Shift + перетаскивание: поменять иконку местами с той, над которой отпустили
local function OnDragStart(self)
    if not (IsShiftKeyDown() and Bar.CanReorder()) then return end
    Bar.dragging = self
    self:SetAlpha(0.5)
end

local function OnDragStop(self)
    if Bar.dragging ~= self then return end
    Bar.dragging = nil
    self:SetAlpha(1)
    if not Bar.CanReorder() then return end
    for _, target in ipairs(self.bar.buttons) do
        if target ~= self and target:IsShown() and target:IsMouseOver() then
            Bar.Swap(self.bar, self, target)
            return
        end
    end
end

local function CreateButton(bar, i)
    local btn = CreateFrame("Button", bar:GetName() .. "Button" .. i, bar, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Up и Down: secure-шаблон сам выбирает по CVar ActionButtonUseKeyDown
    btn:RegisterForClicks("AnyUp", "AnyDown")
    -- Shift+клик не кастует: пустой тип перекрывает type=spell
    btn:SetAttribute("shift-type1", "")
    btn:RegisterForDrag("LeftButton")
    btn.bar = bar

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.cooldown:SetHideCountdownNumbers(false)

    -- Рамка активного аспекта поверх затемнения кулдауна
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1)
    btn.glow = overlay:CreateTexture(nil, "OVERLAY")
    btn.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetAllPoints()
    btn.glow:Hide()

    btn:SetScript("OnEnter", OnEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnMouseUp", OnMouseUp)
    btn:SetScript("OnDragStart", OnDragStart)
    btn:SetScript("OnDragStop", OnDragStop)
    return btn
end

function Bar.Create(name, title)
    local bar = CreateFrame("Frame", "TrailkitBar_" .. name, UIParent)
    bar.name, bar.title, bar.buttons = name, title, {}
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetDontSavePosition(true)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Menu.Open(bar) end
    end)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.4)

    -- Заголовок-ручка для перетаскивания, виден только при снятом замке
    local handle = CreateFrame("Frame", nil, bar)
    handle:SetPoint("BOTTOMLEFT", bar, "TOPLEFT")
    handle:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT")
    handle:SetHeight(16)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    local hbg = handle:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.67, 0.83, 0.45, 0.5)
    local text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(title)
    handle:SetScript("OnDragStart", function()
        if Bar.CanMovePanel() then
            bar.moving = true
            bar:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        if not bar.moving then return end
        bar.moving = false
        bar:StopMovingOrSizing()
        Bar.SavePosition(bar)
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Menu.Open(bar) end
    end)
    bar.handle = handle

    Bar.frames[name] = bar
    return bar
end

function Bar.SavePosition(bar)
    local cfg = Cfg(bar)
    local point, _, relPoint, x, y = bar:GetPoint(1)
    cfg.point, cfg.relPoint, cfg.x, cfg.y = point, relPoint, x, y
    ns.DB.Save()
end

-- Только визуал замка, secure-фреймы не трогает — можно и в бою
function Bar.UpdateLock(bar)
    local unlocked = not ns.db.locked
    bar.handle:SetShown(unlocked)
    bar.bg:SetShown(unlocked)
end

-- Пересобрать кнопки панели. Только вне боя.
function Bar.Rebuild(bar)
    local cfg = Cfg(bar)
    local count = 0
    for _, entry in ipairs(OrderedEntries(bar)) do
        local spellID = not ns.testMode and HighestKnownRank(entry.ranks) or nil
        if ns.testMode or spellID then
            count = count + 1
            local btn = bar.buttons[count] or CreateButton(bar, count)
            bar.buttons[count] = btn
            if btn.entry ~= entry then btn.active = nil end
            btn.entry, btn.spellID = entry, spellID
            btn:SetAttribute("type", spellID and "spell" or nil)
            btn:SetAttribute("spell", spellID)
            btn.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or PLACEHOLDER_ICON)
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", bar, "LEFT", PADDING + (count - 1) * (BUTTON_SIZE + SPACING), 0)
            btn:Show()
        end
    end
    for i = count + 1, #bar.buttons do
        local btn = bar.buttons[i]
        btn:Hide()
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn.entry, btn.spellID, btn.active = nil, nil, nil
    end

    bar:SetSize(PADDING * 2 + count * BUTTON_SIZE + math.max(count - 1, 0) * SPACING, BUTTON_SIZE + PADDING * 2)
    bar:SetScale(cfg.scale)
    bar:ClearAllPoints()
    bar:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    bar:SetShown(count > 0 and not cfg.hidden)
    Bar.UpdateLock(bar)
end

function Bar.RebuildAll()
    if InCombatLockdown() then
        Bar.pending = true
        return
    end
    Bar.pending = false
    for _, bar in pairs(Bar.frames) do Bar.Rebuild(bar) end
    Bar.UpdateCooldowns()
    Bar.UpdateAuras()
end

-- Значения кулдауна могут быть secret: не сравниваем, отдаём во фрейм Blizzard как есть
function Bar.UpdateCooldowns()
    for _, bar in pairs(Bar.frames) do
        for _, btn in ipairs(bar.buttons) do
            local info = btn.spellID and C_Spell.GetSpellCooldown(btn.spellID)
            if info then
                btn.cooldown:SetCooldown(info.startTime, info.duration, info.modRate)
            else
                btn.cooldown:Clear()
            end
        end
    end
end

-- true/false — активен ли аспект; nil — неизвестно (аура secret)
local function AuraState(ranks)
    for _, id in ipairs(ranks) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if issecret(aura) then return nil end
        if aura then return true end
    end
    return false
end

-- При неизвестном состоянии держим последнее известное
function Bar.UpdateAuras()
    for _, btn in ipairs(Bar.frames.aspects.buttons) do
        if btn.spellID then
            local state = AuraState(btn.entry.ranks)
            if state ~= nil then btn.active = state end
        else
            btn.active = false
        end
        btn.glow:SetShown(btn.active == true)
    end
end

-- Поменять две иконки панели местами
function Bar.Swap(bar, btn, other)
    local keys, a, b = {}, nil, nil
    for i, entry in ipairs(OrderedEntries(bar)) do
        keys[i] = entry.key
        if entry == btn.entry then a = i elseif entry == other.entry then b = i end
    end
    keys[a], keys[b] = keys[b], keys[a]
    Cfg(bar).order = keys
    ns.DB.Save()
    Bar.RebuildAll()
end
