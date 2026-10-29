-- Панели: secure-кнопки спеллов, подсветка активного аспекта, кулдауны, перемещение
local _, ns = ...
local L = ns.L

local Bar = {}
ns.Bar = Bar

local BUTTON_SIZE = 36
local SPACING = 4
local PADDING = 6
local PLACEHOLDER_ICON = 134400 -- знак вопроса
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Hex(hex, a)
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        a or 1,
    }
end

-- Палитра в стиле ночных эльфов
local COLORS = {
    border = Hex("AEBBD2"),       -- лунное серебро
    inner = Hex("1B1430"),        -- внутренняя тёмная обводка
    hover = Hex("8FE3D6"),        -- бирюзовое свечение
    active = Hex("A47CFF"),       -- свечение активного аспекта
    activeBorder = Hex("D7C8FF"), -- рамка активного аспекта
    panelBg = Hex("241842", 0.6),
    panelBorder = Hex("8C98B4"),
    panelLine = Hex("A47CFF", 0.35),
}

-- Рамка 1px из WHITE8X8 (+ фон, если задан)
local function StyleBackdrop(frame, bg, border)
    frame:SetBackdrop({ bgFile = bg and WHITE or nil, edgeFile = WHITE, edgeSize = 1 })
    if bg then frame:SetBackdropColor(unpack(bg)) end
    frame:SetBackdropBorderColor(unpack(border))
end

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

-- Нажатие: затемнение иконки
local function OnMouseDown(self, button)
    if button == "LeftButton" then self.icon:SetVertexColor(0.5, 0.5, 0.5) end
end

local function OnMouseUp(self, button)
    self.icon:SetVertexColor(1, 1, 1)
    if button == "RightButton" then ns.Menu.Open(self.bar) end
end

-- Shift + перетаскивание: поменять иконку местами с той, над которой отпустили.
-- Копия иконки (ghost) едет за курсором, цель под курсором подсвечивается.
local ghost

local function FindDropTarget(src)
    for _, target in ipairs(src.bar.buttons) do
        if target ~= src and target:IsShown() and target:IsMouseOver() then return target end
    end
end

local function SetDropTarget(target)
    if Bar.dropTarget == target then return end
    if Bar.dropTarget then Bar.dropTarget.dropGlow:Hide() end
    Bar.dropTarget = target
    if target then target.dropGlow:Show() end
end

local function GhostOnUpdate(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    SetDropTarget(FindDropTarget(Bar.dragging))
end

local function ShowGhost(src)
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP")
        ghost:SetAlpha(0.85)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
        ghost.icon:SetAllPoints()
        ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        ghost:SetScript("OnUpdate", GhostOnUpdate)
    end
    local size = src.icon:GetWidth() * src:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ghost:SetSize(size, size)
    ghost.icon:SetTexture(src.icon:GetTexture())
    ghost:Show()
end

local function OnDragStart(self)
    if not (IsShiftKeyDown() and Bar.CanReorder()) then return end
    Bar.dragging = self
    self:SetAlpha(0.35)
    ShowGhost(self)
end

local function OnDragStop(self)
    if Bar.dragging ~= self then return end
    local target = FindDropTarget(self)
    Bar.dragging = nil
    SetDropTarget(nil)
    ghost:Hide()
    self:SetAlpha(1)
    self.icon:SetVertexColor(1, 1, 1)
    if target and Bar.CanReorder() then
        Bar.Swap(self.bar, self, target)
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

    -- Серебряная рамка 2px, под ней тёмная обводка 1px, затем иконка
    btn.border = btn:CreateTexture(nil, "BACKGROUND")
    btn.border:SetTexture(WHITE)
    btn.border:SetAllPoints()
    btn.border:SetVertexColor(unpack(COLORS.border))
    local inner = btn:CreateTexture(nil, "BORDER")
    inner:SetTexture(WHITE)
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    inner:SetVertexColor(unpack(COLORS.inner))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 3, -3)
    btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:GetHighlightTexture():SetVertexColor(unpack(COLORS.hover))

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetHideCountdownNumbers(false)

    -- Свечение активного аспекта поверх затемнения кулдауна
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1)
    btn.glow = overlay:CreateTexture(nil, "OVERLAY")
    btn.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetVertexColor(unpack(COLORS.active))
    btn.glow:SetAllPoints()
    btn.glow:Hide()

    -- Подсветка цели при Shift+drag
    btn.dropGlow = overlay:CreateTexture(nil, "OVERLAY")
    btn.dropGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn.dropGlow:SetBlendMode("ADD")
    btn.dropGlow:SetVertexColor(unpack(COLORS.hover))
    btn.dropGlow:SetAllPoints()
    btn.dropGlow:Hide()

    btn:SetScript("OnEnter", OnEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnMouseDown", OnMouseDown)
    btn:SetScript("OnMouseUp", OnMouseUp)
    btn:SetScript("OnDragStart", OnDragStart)
    btn:SetScript("OnDragStop", OnDragStop)
    return btn
end

function Bar.Create(name, title)
    local bar = CreateFrame("Frame", "TrailkitBar_" .. name, UIParent, "BackdropTemplate")
    bar.name, bar.title, bar.buttons = name, title, {}
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetDontSavePosition(true)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Menu.Open(bar) end
    end)

    -- Подложка: тёмно-фиолетовый фон, рамка и тонкая внутренняя фиолетовая линия
    StyleBackdrop(bar, COLORS.panelBg, COLORS.panelBorder)
    local line = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    line:SetPoint("TOPLEFT", 2, -2)
    line:SetPoint("BOTTOMRIGHT", -2, 2)
    StyleBackdrop(line, nil, COLORS.panelLine)

    -- Заголовок-ручка для перетаскивания, виден только при снятом замке
    local handle = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    handle:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 1)
    handle:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 1)
    handle:SetHeight(16)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    StyleBackdrop(handle, Hex("241842", 0.85), COLORS.panelBorder)
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
    bar.handle:SetShown(not ns.db.locked)
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
        local active = btn.active == true
        btn.glow:SetShown(active)
        btn.border:SetVertexColor(unpack(active and COLORS.activeBorder or COLORS.border))
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
