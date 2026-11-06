-- Панели: secure-кнопки спеллов, подсветка активного аспекта, кулдауны, перемещение
local _, ns = ...
local L = ns.L

local Bar = {}
ns.Bar = Bar

-- Кнопки в обоих стилях — как кнопки основной панели действий
local BUTTON_SIZE = 45
local SPACING = 2
local PLACEHOLDER_ICON = 134400 -- знак вопроса
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DROP_COLOR = { 0.56, 0.89, 0.84 } -- бирюзовая подсветка цели при Shift+drag (#8FE3D6)

-- Рамка-ветка стиля «Ночные эльфы»: interface/unitpowerbaralt/druid_horizontal_frame.blp.
-- Нарезка в три части, координаты — в пикселях текстуры; подгоняются руками.
local BRANCH_FILE = 525287
local BRANCH_TEX_W, BRANCH_TEX_H = 256, 64
local BRANCH_LEFT = 48   -- ширина левого конца с листьями
local BRANCH_RIGHT = 48  -- ширина правого конца с листьями
local BRANCH_TOP = 0     -- верх используемой области текстуры
local BRANCH_BOTTOM = 64 -- низ используемой области текстуры
-- Отступы кнопок от краёв рамки, в экранных пикселях
local BRANCH_PAD_X = 40
local BRANCH_PAD_Y = 18

-- Рамка 1px из WHITE8X8 (+ фон, если задан)
local function StyleBackdrop(frame, bg, border)
    frame:SetBackdrop({ bgFile = bg and WHITE or nil, edgeFile = WHITE, edgeSize = 1 })
    if bg then frame:SetBackdropColor(unpack(bg)) end
    frame:SetBackdropBorderColor(unpack(border))
end

local function IsNightElf() return ns.db.style == "nightelf" end

-- issecretvalue может отсутствовать в клиенте без secret values
local issecret = issecretvalue or function() return false end

Bar.frames = {}
Bar.pending = false -- пересборка отложена до выхода из боя
Bar.branchAvailable = false -- загрузилась ли текстура ветки (проверяется в Bar.Create)

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

-- Эффект нажатия: родная рамка нажатия вместо обычной
local function SetPressed(btn, pressed)
    btn.pushed:SetShown(pressed)
    btn.normal:SetShown(not pressed)
end

-- С зажатым Shift эффект нажатия не показываем: Shift+клик не кастует
local function OnMouseDown(self, button)
    if button == "LeftButton" and not IsShiftKeyDown() then SetPressed(self, true) end
end

local function OnMouseUp(self, button)
    SetPressed(self, false)
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
    -- После отпускания кнопка всегда в обычном виде
    SetPressed(self, false)
    if Bar.dragging ~= self then return end
    local target = FindDropTarget(self)
    Bar.dragging = nil
    SetDropTarget(nil)
    ghost:Hide()
    self:SetAlpha(1)
    if target and Bar.CanReorder() then
        Bar.Swap(self.bar, self, target)
    end
end

-- Текстура размером с рамку ActionButtonTemplate (46x45 от левого верхнего угла)
local function ActionFrameTexture(parent, layer, sublevel, atlas)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetAtlas(atlas)
    tex:SetSize(46, 45)
    tex:SetPoint("TOPLEFT")
    return tex
end

-- Кнопка с оформлением ActionButtonTemplate: маска иконки, рамка, нажатие, подсветка, «checked»
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
    btn.mask = btn:CreateMaskTexture()
    btn.mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
    btn.mask:SetAllPoints(btn.icon)
    btn.icon:AddMaskTexture(btn.mask)

    btn.normal = ActionFrameTexture(btn, "ARTWORK", 1, "UI-HUD-ActionBar-IconFrame")
    btn.pushed = ActionFrameTexture(btn, "ARTWORK", 1, "UI-HUD-ActionBar-IconFrame-Down")
    btn.pushed:Hide()
    btn.checked = ActionFrameTexture(btn, "ARTWORK", 2, "UI-HUD-ActionBar-IconFrame-Mouseover")
    btn.checked:SetBlendMode("ADD")
    btn.checked:Hide()
    local highlight = ActionFrameTexture(btn, "HIGHLIGHT", 0, "UI-HUD-ActionBar-IconFrame-Mouseover")
    highlight:SetBlendMode("ADD")

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetPoint("TOPLEFT", btn.icon, 3, -3)
    btn.cooldown:SetPoint("BOTTOMRIGHT", btn.icon, -3, 3)
    btn.cooldown:SetHideCountdownNumbers(false)

    -- Подсветка цели при Shift+drag поверх затемнения кулдауна
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1)
    btn.dropGlow = ActionFrameTexture(overlay, "OVERLAY", 0, "UI-HUD-ActionBar-IconFrame-Mouseover")
    btn.dropGlow:SetBlendMode("ADD")
    btn.dropGlow:SetVertexColor(unpack(DROP_COLOR))
    btn.dropGlow:Hide()

    btn:SetScript("OnEnter", OnEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnMouseDown", OnMouseDown)
    btn:SetScript("OnMouseUp", OnMouseUp)
    btn:SetScript("OnDragStart", OnDragStart)
    btn:SetScript("OnDragStop", OnDragStop)
    return btn
end

-- Вспышка прока: шаблон и анимации те же, что у кнопок панелей Blizzard
-- (ActionButtonSpellAlertManager). Свой фрейм вместо вызова менеджера — не пишем
-- наши кнопки в его таблицу, чтобы не затронуть стандартные панели.
local function SetAlert(btn, show)
    local alert = btn.spellAlert
    if show then
        if not alert then
            alert = CreateFrame("Frame", nil, btn, "ActionButtonSpellAlertTemplate")
            alert:SetSize(BUTTON_SIZE * 1.4, BUTTON_SIZE * 1.4)
            alert:SetPoint("CENTER")
            alert:SetFrameLevel(btn.cooldown:GetFrameLevel() + 2)
            btn.spellAlert = alert
        end
        if alert:IsShown() then return end
        alert:Show()
        alert.ProcStartAnim:Play()
    elseif alert and alert:IsShown() then
        alert:Hide()
        alert.ProcStartAnim:Stop()
    end
end

-- Рамка-ветка из трёх частей: концы фиксированной ширины, середина тянется.
-- Возвращает false, если текстура не загрузилась.
local function CreateBranch(bar)
    local k = (BUTTON_SIZE + BRANCH_PAD_Y * 2) / (BRANCH_BOTTOM - BRANCH_TOP)
    local top, bottom = BRANCH_TOP / BRANCH_TEX_H, BRANCH_BOTTOM / BRANCH_TEX_H
    local l, r = BRANCH_LEFT / BRANCH_TEX_W, 1 - BRANCH_RIGHT / BRANCH_TEX_W

    local left = bar:CreateTexture(nil, "BACKGROUND")
    local ok = left:SetTexture(BRANCH_FILE)
    left:SetTexCoord(0, l, top, bottom)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(BRANCH_LEFT * k)

    local right = bar:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(BRANCH_FILE)
    right:SetTexCoord(r, 1, top, bottom)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(BRANCH_RIGHT * k)

    local middle = bar:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture(BRANCH_FILE)
    middle:SetTexCoord(l, r, top, bottom)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

    bar.branch = { left, middle, right }
    bar.branchMinWidth = (BRANCH_LEFT + BRANCH_RIGHT) * k
    return ok ~= false and left:GetTexture() ~= nil
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

    Bar.branchAvailable = CreateBranch(bar)

    -- Заголовок-ручка для перетаскивания, виден только при снятом замке
    local handle = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    handle:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 1)
    handle:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 1)
    handle:SetHeight(16)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    StyleBackdrop(handle, { 0, 0, 0, 0.6 }, { 0.5, 0.5, 0.5, 1 })
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
    local entries = {}
    for _, entry in ipairs(OrderedEntries(bar)) do
        local spellID = not ns.testMode and HighestKnownRank(entry.ranks) or nil
        if ns.testMode or spellID then
            entries[#entries + 1] = { entry = entry, spellID = spellID }
        end
    end
    local count = #entries

    -- Размер панели: в стиле «Ночные эльфы» кнопки внутри рамки-ветки
    local nightElf = IsNightElf()
    local contentWidth = count * BUTTON_SIZE + math.max(count - 1, 0) * SPACING
    local width, height = contentWidth, BUTTON_SIZE
    if nightElf then
        width = math.max(contentWidth + BRANCH_PAD_X * 2, bar.branchMinWidth)
        height = BUTTON_SIZE + BRANCH_PAD_Y * 2
    end
    local x0 = (width - contentWidth) / 2
    for _, tex in ipairs(bar.branch) do tex:SetShown(nightElf) end

    for i, item in ipairs(entries) do
        local btn = bar.buttons[i] or CreateButton(bar, i)
        bar.buttons[i] = btn
        if btn.entry ~= item.entry then btn.active = nil end
        btn.entry, btn.spellID = item.entry, item.spellID
        btn:SetAttribute("type", item.spellID and "spell" or nil)
        btn:SetAttribute("spell", item.spellID)
        btn.icon:SetTexture(item.spellID and C_Spell.GetSpellTexture(item.spellID) or PLACEHOLDER_ICON)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", bar, "LEFT", x0 + (i - 1) * (BUTTON_SIZE + SPACING), 0)
        btn:Show()
    end
    for i = count + 1, #bar.buttons do
        local btn = bar.buttons[i]
        btn:Hide()
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn.entry, btn.spellID, btn.active = nil, nil, nil
        SetAlert(btn, false)
    end

    bar:SetSize(width, height)
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
    Bar.UpdateSpellAlerts()
end

-- Объект длительности (Midnight): принимает secret-значения из аддона, как CustomAuraButton Blizzard
local GetCooldownDuration = C_Spell.GetSpellCooldownDuration

local function UpdateCooldown(btn)
    local cd = btn.cooldown
    if not btn.spellID then
        cd:Clear()
    elseif GetCooldownDuration and cd.SetCooldownFromDurationObject then
        local duration = GetCooldownDuration(btn.spellID)
        if duration then
            cd:SetCooldownFromDurationObject(duration, true)
        else
            cd:Clear()
        end
    else
        -- Старый путь: SetCooldown из аддона не принимает secret — тогда пропускаем обновление
        local info = C_Spell.GetSpellCooldown(btn.spellID)
        if not info then
            cd:Clear()
        elseif not (issecret(info.startTime) or issecret(info.duration) or issecret(info.modRate)) then
            cd:SetCooldown(info.startTime, info.duration, info.modRate)
        end
    end
end

-- Вызывается только по SPELL_UPDATE_COOLDOWN и при пересборке панелей
function Bar.UpdateCooldowns()
    for _, bar in pairs(Bar.frames) do
        for _, btn in ipairs(bar.buttons) do UpdateCooldown(btn) end
    end
end

-- В Forever одновременно активен только один аспект; в Midnight аспекты — независимые
-- временные баффы, каждый проверяется сам по себе
local EXCLUSIVE_ASPECTS = ns.client == "forever"

-- Отладка подсветки (/tk debug on|off), строки не локализуются
local function Debug(msg)
    if ns.debug then ns.Print("[debug] " .. msg) end
end

-- Значение API для отладки: true/false/nil/secret
local function Show(v)
    if issecret(v) then return "secret" end
    return tostring(v)
end

-- Разрешён ли сейчас полный просмотр баффов. При засекреченных аурах GetAuraDataByIndex
-- (RequiresUnitAuraAccess) бросает ошибку, а не возвращает secret. Без C_Secrets — только вне боя
local function CanScanAuras()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and not issecret(secret) then return not secret end
    end
    return not InCombatLockdown()
end

-- Полный просмотр баффов игрока. true — аспект найден; false — однозначно нет;
-- nil — неизвестно (secret, ошибка API, пустой список при живом игроке — данные могли не прийти)
local function ScanAuras(ranks)
    local wanted = {}
    for _, id in ipairs(ranks) do wanted[id] = true end
    local count = 0
    while true do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", count + 1, "HELPFUL")
        if not ok or issecret(data) then return nil end
        if not data then break end
        if issecret(data.spellId) then return nil end
        if wanted[data.spellId] then return true end
        count = count + 1
    end
    -- аспекты слетают при смерти; иначе пустой список не считаем ответом
    if count == 0 and not UnitIsDeadOrGhost("player") then return nil end
    return false
end

-- true/false — активен ли аспект; nil — неизвестно. Второе значение — строка для отладки.
-- nil и secret от GetPlayerAuraBySpellID ответом «нет» не считаются: «нет» даёт только ScanAuras.
-- GetPlayerAuraBySpellID (RequiresNonSecretAura) при секретной ауре не бросает, а возвращает nil —
-- поэтому его зовём и в бою; ошибка (pcall) — «неизвестно».
local function AuraState(ranks)
    for _, id in ipairs(ranks) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok then return nil, "byID=error" end
        if issecret(aura) then return nil, "byID=secret" end
        if aura then return true, "byID=true" end
    end
    if not CanScanAuras() then return nil, "byID=nil scan=skipped (secret)" end
    local state = ScanAuras(ranks)
    return state, "byID=nil scan=" .. Show(state)
end

-- Активный аспект — стандартная подсветка «checked»; при неизвестном состоянии держим последнее.
-- Возвращает true, если для всех кнопок получен однозначный ответ.
function Bar.UpdateAuras()
    local buttons = Bar.frames.aspects.buttons
    local states, info = {}, {}
    local anyActive = false
    for i, btn in ipairs(buttons) do
        if btn.spellID then
            states[i], info[i] = AuraState(btn.entry.ranks)
        else
            states[i], info[i] = false, "no spell"
        end
        if states[i] then anyActive = true end
    end

    local resolved = true
    for i, btn in ipairs(buttons) do
        local state = states[i]
        -- Forever: одновременно активен только один аспект — найденный однозначно гасит остальные
        if state == nil and anyActive and EXCLUSIVE_ASPECTS then
            state, info[i] = false, info[i] .. " (other aspect active)"
        end
        if state == nil then resolved = false end
        local name = btn.entry and btn.entry.key or tostring(i)
        if info[i] ~= btn.lastInfo then
            btn.lastInfo = info[i]
            Debug(name .. ": " .. info[i])
        end
        if state ~= nil and state ~= btn.active then
            Debug(name .. ": highlight " .. Show(btn.active) .. " -> " .. Show(state))
            btn.active = state
        end
        btn.checked:SetShown(btn.active == true)
    end
    return resolved
end

-- После боя данные аур приходят не сразу: сразу, через 0.5 с и через 2 с, пока нет ответа
local RECHECK_DELAYS = { 0.5, 1.5 } -- интервалы между попытками (итого 0.5 и 2 с)
local recheckToken = 0

function Bar.RecheckAuras()
    recheckToken = recheckToken + 1
    local token = recheckToken
    local function Try(step)
        if token ~= recheckToken then return end -- запущена новая серия
        local resolved = Bar.UpdateAuras()
        Debug("recheck #" .. step .. (resolved and ": resolved" or ": unknown"))
        if not resolved and RECHECK_DELAYS[step] then
            C_Timer.After(RECHECK_DELAYS[step], function() Try(step + 1) end)
        end
    end
    Try(1)
end

local function HasRank(btn, spellID)
    for _, id in ipairs(btn.entry.ranks) do
        if id == spellID then return true end
    end
    return false
end

-- UNIT_SPELLCAST_SUCCEEDED игрока: смена аспекта по касту, работает и в бою, когда ауры secret.
-- spellID игрока не secret (SecretWhenUnitSpellCastRestricted — только чужие юниты),
-- но спелл может быть помечен «всегда secret» — такой пропускаем.
-- Найденный аспект включаем; в Forever (активен только один) остальные гасим
function Bar.OnPlayerCast(spellID)
    if issecret(spellID) then return end
    local buttons = Bar.frames.aspects.buttons
    local cast
    for _, btn in ipairs(buttons) do
        if btn.entry and HasRank(btn, spellID) then cast = btn break end
    end
    if not cast then return end
    Debug("cast: " .. cast.entry.key)
    for _, btn in ipairs(buttons) do
        if btn == cast or EXCLUSIVE_ASPECTS then
            btn.active = btn == cast
            btn.checked:SetShown(btn.active)
        end
    end
end

-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE. Secret spellID не сравниваем — пропускаем
function Bar.SetSpellAlert(spellID, show)
    if issecret(spellID) then return end
    for _, bar in pairs(Bar.frames) do
        for _, btn in ipairs(bar.buttons) do
            if btn.spellID and HasRank(btn, spellID) then SetAlert(btn, show) end
        end
    end
end

-- true/false — горит ли прок на любом ранге; nil — неизвестно (ответ secret)
local IsOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed

local function OverlayState(ranks)
    for _, id in ipairs(ranks) do
        local overlayed = IsOverlayed(id)
        if issecret(overlayed) then return nil end
        if overlayed then return true end
    end
    return false
end

-- Текущее состояние вспышек (загрузка, /reload, пересборка); при неизвестном — не трогаем
function Bar.UpdateSpellAlerts()
    for _, bar in pairs(Bar.frames) do
        for _, btn in ipairs(bar.buttons) do
            local state = false
            if btn.spellID and IsOverlayed then state = OverlayState(btn.entry.ranks) end
            if state ~= nil then SetAlert(btn, state) end
        end
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
