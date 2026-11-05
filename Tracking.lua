-- Глазок отслеживания у миникарты. Только Forever: в других клиентах файл ничего не создаёт.
-- Независим от панелей: свои настройки ns.db.tracking и свой фрейм событий.
-- Из общих настроек читает только замок панелей (перемещение при снятом замке).
local _, ns = ...
if ns.client ~= "forever" then return end

local L = ns.L

local Tracking = {}
ns.Tracking = Tracking

-- subType спеллов охотника в C_Minimap.GetTrackingInfo (HUNTER_TRACKING из Blizzard_Minimap)
local HUNTER_TRACKING = HUNTER_TRACKING or 1
-- Ability_EyeOfTheOwl — нейтральный глаз, когда ничего не включено
local EYE_ICON = 132150
local SIZE = 31

local button, events

-- Виды отслеживания охотника; список строится заново, без зашитых ID
local function HunterTypes()
    local list = {}
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if info and info.subType == HUNTER_TRACKING then
            info.index = index
            list[#list + 1] = info
        end
    end
    return list
end

local function ActiveType(list)
    for _, info in ipairs(list) do
        if info.active then return info end
    end
end

local function Update()
    local list = HunterTypes()
    local active = ActiveType(list)
    button.icon:SetTexture(active and active.texture or EYE_ICON)
    button:SetShown(#list > 0)
end

-- Позиция по углу на краю круглой миникарты
local function UpdatePosition()
    local angle = math.rad(ns.db.tracking.angle)
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragOnUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.tracking.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    UpdatePosition()
end

-- Клик по активному виду выключает его, по неактивному — включает.
-- В бою не переключаем: каст отслеживания может быть заблокирован
local function ToggleType(info)
    if InCombatLockdown() then
        ns.Print(L.MSG_COMBAT)
        return
    end
    C_Minimap.SetTracking(info.index, not info.active)
end

local function OpenMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.TRACKING)
        for _, info in ipairs(HunterTypes()) do
            local text = ("|T%s:16:16:0:0:64:64:4:60:4:60|t %s"):format(info.texture, info.name)
            root:CreateCheckbox(text,
                function() return info.active end,
                function()
                    ToggleType(info)
                    return MenuResponse.Close
                end)
        end
    end)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local active = ActiveType(HunterTypes())
    GameTooltip:SetText(active and active.name or L.TRACKING_NONE)
    if not ns.db.locked then
        GameTooltip:AddLine(L.TOOLTIP_TRACKING_MOVE, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function OnDragStart(self)
    if ns.db.locked or not IsShiftKeyDown() then return end
    GameTooltip:Hide()
    self:SetScript("OnUpdate", DragOnUpdate)
end

local function OnDragStop(self)
    if not self:GetScript("OnUpdate") then return end
    self:SetScript("OnUpdate", nil)
    ns.DB.Save()
end

-- Круглая кнопка в стиле стандартных кнопок миникарты
local function CreateButton()
    button = CreateFrame("Button", "TrailkitTrackingButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(17, 17)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(button.icon)
    button.icon:AddMaskTexture(mask)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", OpenMenu)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)
end

-- Выключенный модуль скрыт и не слушает события
local function Apply()
    if ns.db.tracking.enabled then
        if not button then CreateButton() end
        events:RegisterEvent("MINIMAP_UPDATE_TRACKING")
        events:RegisterEvent("SPELLS_CHANGED")
        UpdatePosition()
        Update()
    else
        events:UnregisterAllEvents()
        if button then button:Hide() end
    end
end

function Tracking.Init()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", Update)
    Apply()
end

function Tracking.SetEnabled(enabled)
    ns.db.tracking.enabled = enabled
    ns.DB.Save()
    Apply()
    ns.Print(enabled and L.MSG_TRACKING_ON or L.MSG_TRACKING_OFF)
end
