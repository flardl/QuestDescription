-- Saved variables (add "AddQuestInfoSaved" to your TOC: ## SavedVariables: AddQuestInfoSaved)
AddQuestInfoSaved = AddQuestInfoSaved or {}

-- 1. Create the Main Container Frame
local DescModule = CreateFrame("Frame", "QuestObjectiveDescriptionTracker", UIParent)
DescModule:SetWidth(250)
DescModule:SetFrameStrata("LOW")
DescModule.isCollapsed = AddQuestInfoSaved.isCollapsed or false
DescModule:Hide()

-- 2. Header
DescModule.Header = CreateFrame("Frame", nil, DescModule)
DescModule.Header:SetSize(250, 25)
DescModule.Header:SetPoint("TOPLEFT", 0, 0)

DescModule.Header.Bar = DescModule.Header:CreateTexture(nil, "BACKGROUND")
DescModule.Header.Bar:SetTexture("Interface\\LFGFrame\\UI-LFG-SEPARATOR")
DescModule.Header.Bar:SetTexCoord(0, 0.664, 0, 0.31)
DescModule.Header.Bar:SetVertexColor(1, 0.9, 0, 0.4)
DescModule.Header.Bar:SetPoint("TOPLEFT", 0, 0)
DescModule.Header.Bar:SetPoint("BOTTOMRIGHT", 0, 0)

DescModule.Header.Text = DescModule.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
DescModule.Header.Text:SetPoint("LEFT", 25, 1)
DescModule.Header.Text:SetTextColor(1, 0.82, 0)
DescModule.Header.Text:SetJustifyH("LEFT")
DescModule.Header.Text:SetWordWrap(false)

DescModule.Header.Line = DescModule.Header:CreateTexture(nil, "ARTWORK")
DescModule.Header.Line:SetSize(240, 1)
DescModule.Header.Line:SetPoint("BOTTOMLEFT", 5, 1)
DescModule.Header.Line:SetColorTexture(1, 0.82, 0, 0.5)

-- Minimize Button using ObjectiveTracker's own collapse button textures
DescModule.Header.MinimizeButton = CreateFrame("Button", nil, DescModule.Header)
DescModule.Header.MinimizeButton:SetSize(16, 16)
DescModule.Header.MinimizeButton:SetPoint("RIGHT", -4, 0)
-- Constrain title text so it never overlaps the button
DescModule.Header.Text:SetPoint("RIGHT", DescModule.Header.MinimizeButton, "LEFT", -4, 0)

local function UpdateMinimizeButtonTexture()
    local btn = DescModule.Header.MinimizeButton
    if DescModule.isCollapsed then
        btn:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Expand", true)
        btn:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Expand", true)
    else
        btn:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Collapse", true)
        btn:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Collapse", true)
    end
    btn:SetHighlightAtlas("UI-QuestTrackerButton-Secondary-Collapse")
end

UpdateMinimizeButtonTexture()

-- 3. Description Text
DescModule.Text = DescModule:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
DescModule.Text:SetPoint("TOPLEFT", DescModule.Header, "BOTTOMLEFT", 20, -8)
DescModule.Text:SetWidth(215)
DescModule.Text:SetJustifyH("LEFT")
DescModule.Text:SetWordWrap(true)
DescModule.Text:SetSpacing(2)

-- 4. Background Gradient
DescModule.bg = DescModule:CreateTexture(nil, "BACKGROUND")
DescModule.bg:SetPoint("TOPLEFT", DescModule, "TOPLEFT")
DescModule.bg:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.4), CreateColor(0, 0, 0, 0))

-- 5. Hidden measurement FontString (anchored so GetStringHeight works)
-- Use a dedicated hidden frame as parent to avoid tainting UIParent's
-- coordinate space. The frame is moved off-screen so it is never visible.
local MeasureFrame = CreateFrame("Frame")
MeasureFrame:SetSize(215, 1)
MeasureFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
MeasureFrame:Hide()
local MeasureString = MeasureFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
MeasureString:SetWidth(215)
MeasureString:SetWordWrap(true)
MeasureString:SetSpacing(2)
MeasureString:SetAllPoints(MeasureFrame)

-- 6. Quest description lookup
local function GetBestQuestDescription(questID)
    if not questID or questID <= 0 then return nil, nil end
    if C_QuestLog.IsWorldQuest(questID) then return nil, nil end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    local questIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local description = ""

    if questIndex then
        local text, objectiveText = GetQuestLogQuestText(questIndex)
        description = text or objectiveText or ""
    end

    if not description or description == "" then
        description = C_QuestLog.GetQuestDescription(questID) or ""
    end

    if description == "" or description:len() < 2 then
        return nil, nil
    end

    return title, description
end

-- 7. Module anchoring
-- Use ObjectiveTrackerFrame.modules directly so we catch ALL modules
-- including dynamic ones like Achievements that aren't named globals.
local blizzardModules = {
    ScenarioObjectiveTracker,
    UIWidgetObjectiveTracker,
    CampaignQuestObjectiveTracker,
    QuestObjectiveTracker,
    WorldQuestObjectiveTracker,
    BonusObjectiveTracker
}

local function GetFirstVisibleTrackerModule()
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.modules then
        for _, mod in ipairs(ObjectiveTrackerFrame.modules) do
            if mod and mod:IsVisible() then
                return mod
            end
        end
    end
    return nil
end

-- Anchoring: enforce first module position every frame via OnUpdate.
-- SetPoint hooks fail during combat (Blizzard resets from protected code).
-- OnUpdate re-applies every frame, so the anchor always holds.
local anchorFrame = CreateFrame("Frame")
local lastEnforcedModule = nil

anchorFrame:SetScript("OnUpdate", function()
    if not DescModule:IsVisible() then
        -- If we previously forced an anchor, restore native on hide
        if lastEnforcedModule then
            lastEnforcedModule:ClearAllPoints()
            lastEnforcedModule:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
            lastEnforcedModule = nil
        end
        return
    end

    local firstVisible = GetFirstVisibleTrackerModule()
    if not firstVisible then return end

    -- Always enforce the anchor below DescModule
    if lastEnforcedModule ~= firstVisible then
        -- Module changed, clear old one
        if lastEnforcedModule then
            lastEnforcedModule:ClearAllPoints()
            lastEnforcedModule:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
        end
        lastEnforcedModule = firstVisible
    end

    local descBottom = DescModule:GetBottom()
    local moduleTop = firstVisible:GetTop()
    if descBottom and moduleTop and math.abs(moduleTop - (descBottom - 10)) > 2 then
        firstVisible:ClearAllPoints()
        firstVisible:SetPoint("TOP", DescModule, "BOTTOM", 0, -10)
    end
end)

local function ForceAnchorToDesc()
    if not DescModule:IsVisible() then return end
    local firstVisible = GetFirstVisibleTrackerModule()
    if firstVisible then
        firstVisible:ClearAllPoints()
        firstVisible:SetPoint("TOP", DescModule, "BOTTOM", 0, -10)
    end
end

-- 8. HEIGHT RESERVATION
--
-- cachedReservedHeight is computed OUTSIDE of combat (in UpdateContent)
-- and used inside LayoutContents/BeginLayout hooks.
-- We never call MeasureString:GetStringHeight() during combat because
-- touching frame geometry during protected execution causes taint.
local cachedReservedHeight = 0

local function UpdateCachedReservedHeight(description)
    if not description or DescModule.isCollapsed then
        cachedReservedHeight = DescModule.isCollapsed and (25 + 10) or 0
        return
    end
    MeasureString:SetText(description)
    local textHeight = MeasureString:GetStringHeight()
    MeasureString:SetText("")
    cachedReservedHeight = 25 + textHeight + 15 + 10
end

-- The full tracker height budget (editModeHeight minus paddings).
-- LayoutContents should only ever see availableHeight near this value
-- before we subtract. We store it so we can detect if a subtraction
-- has already been applied this cycle.
local FULL_BUDGET = ObjectiveTrackerFrame.editModeHeight or 730

-- Keep FULL_BUDGET updated whenever editModeHeight changes (Edit Mode)
hooksecurefunc(ObjectiveTrackerFrame, "UpdateHeight", function(self)
    FULL_BUDGET = self.editModeHeight or FULL_BUDGET
end)

local function HookModule(module)
    if not module then return end
    -- Per-module flag: did we already subtract this layout cycle?
    -- Reset by BeginLayout (full UpdateAll path) or by the UpdateAll
    -- wrapper below. LayoutContents checks it before subtracting.
    module._aqiSubtracted = false

    if type(module.LayoutContents) == "function" then
        local origLC = module.LayoutContents
        module.LayoutContents = function(self, ...)
            -- Subtract once per LayoutContents call. availableHeight is
            -- set fresh before each call (by BeginLayout or UpdateSingle),
            -- so we subtract, call the original, then restore availableHeight
            -- to the pre-subtracted value so the next call sees the full
            -- budget again and can subtract correctly.
            local reserved = cachedReservedHeight
            local originalAvailable = self.availableHeight
            if reserved > 0 and originalAvailable and originalAvailable > 0 then
                self.availableHeight = originalAvailable - reserved
            end
            local result = origLC(self, ...)
            -- Restore so next independent call (e.g. combat UpdateSingle)
            -- gets the correct starting value
            if originalAvailable then
                self.availableHeight = originalAvailable
            end
            return result
        end
    end

    if type(module.BeginLayout) == "function" then
        local origBL = module.BeginLayout
        module.BeginLayout = function(self, ...)
            -- BeginLayout runs before LayoutContents in the UpdateAll path.
            -- It sets availableHeight — LayoutContents hook handles subtraction.
            return origBL(self, ...)
        end
    end
end

if ObjectiveTrackerFrame.modules then
    for _, module in ipairs(ObjectiveTrackerFrame.modules) do
        HookModule(module)
    end
end
for _, module in ipairs(blizzardModules) do
    HookModule(module)
end

-- Forward declaration so UpdateAll wrapper can reference UpdateContent
-- before it is fully defined below.
local UpdateContent

-- Single consolidated UpdateAll wrapper:
--   1. Clears the double-subtraction guard so each layout pass starts fresh
--   2. Runs UpdateContent first if world-entry re-init is needed
local needsInitUpdate = false
local origUpdateAll = ObjectiveTrackerManager.UpdateAll
ObjectiveTrackerManager.UpdateAll = function(self, ...)
    -- Reset per-module subtraction flags so each full layout pass
    -- gets a fresh subtraction on every module.
    if ObjectiveTrackerFrame.modules then
        for _, m in ipairs(ObjectiveTrackerFrame.modules) do
            m._aqiSubtracted = false
        end
    end
    if needsInitUpdate then
        needsInitUpdate = false
        UpdateContent()
    end
    return origUpdateAll(self, ...)
end

local function RequestTrackerLayout()
    if InCombatLockdown() then return end
    ObjectiveTrackerManager:UpdateAll()
end

-- 9. Content update
-- In combat: only update text content and height cache (safe operations).
-- Out of combat: also reposition frames and trigger layout passes.
UpdateContent = function()
    local inCombat = InCombatLockdown()

    local OTF = ObjectiveTrackerFrame
    if not OTF or not OTF:IsVisible() or (OTF.collapsed or OTF.isCollapsed) then
        if not inCombat then DescModule:Hide() end
        return
    end

    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    local title, description = GetBestQuestDescription(questID)

    if title and description then
        -- Always safe: update text and height cache
        UpdateCachedReservedHeight(description)
        DescModule.Header.Text:SetText(title)
        DescModule.Text:SetText(description)
        DescModule.Text:SetShown(not DescModule.isCollapsed)

        -- DescModule frame ops (SetHeight, SetPoint, Show) are safe in combat.
        -- Only RequestTrackerLayout (which calls UpdateAll) must be deferred.
        local headerHeight = 25
        local textHeight = DescModule.isCollapsed and 0 or (DescModule.Text:GetStringHeight() + 15)
        local totalHeight = headerHeight + textHeight

        local wasVisible = DescModule:IsVisible()
        local oldHeight = DescModule:GetHeight()

        DescModule:SetHeight(totalHeight)
        DescModule.bg:SetSize(250, totalHeight)
        DescModule:ClearAllPoints()
        DescModule:SetPoint("TOPLEFT", OTF, "TOPLEFT", 0, -30)
        DescModule:Show()

        if not inCombat then
            for _, module in ipairs(blizzardModules) do
                if module and module:IsVisible() then
                    ForceAnchorToDesc()
                    break
                end
            end

            if not wasVisible or math.abs(oldHeight - totalHeight) > 1 then
                C_Timer.After(0, RequestTrackerLayout)
            end
        end
    else
        cachedReservedHeight = 0
        if not inCombat then
            local wasVisible = DescModule:IsVisible()
            DescModule:Hide()
            if wasVisible then
                isApplyingLayout = true
                local firstVisible = GetFirstVisibleTrackerModule()
                if firstVisible then
                    firstVisible:ClearAllPoints()
                    firstVisible:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
                end
                isApplyingLayout = false
                C_Timer.After(0, RequestTrackerLayout)
            end
        end
    end
end

-- When leaving combat, run a full update to reposition everything that
-- was skipped during combat.
local CombatFrame = CreateFrame("Frame")
CombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
CombatFrame:SetScript("OnEvent", function()
    C_Timer.After(0, UpdateContent)
    C_Timer.After(0, RequestTrackerLayout)
end)

-- 10. Minimize Toggle
DescModule.Header.MinimizeButton:SetScript("OnClick", function()
    DescModule.isCollapsed = not DescModule.isCollapsed
    AddQuestInfoSaved.isCollapsed = DescModule.isCollapsed
    UpdateMinimizeButtonTexture()
    UpdateContent()
    C_Timer.After(0, RequestTrackerLayout)
end)

-- 11. Events
-- IMPORTANT: UpdateContent must never run synchronously inside a secure
-- execution chain (e.g. SUPER_TRACKING_CHANGED fires from QuestSuperTracking
-- which is a protected system). Calling frame:SetPoint/Show directly inside
-- the event handler taints the secure context and causes ADDON_ACTION_BLOCKED.
-- We always defer UpdateContent by one frame using C_Timer.After(0, ...).
local function DeferredUpdateContent()
    C_Timer.After(0, UpdateContent)
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
EventFrame:RegisterEvent("VARIABLES_LOADED")
EventFrame:SetScript("OnEvent", function(_, event)
    if event == "VARIABLES_LOADED" then
        DescModule.isCollapsed = AddQuestInfoSaved.isCollapsed or false
        UpdateMinimizeButtonTexture()
    elseif event == "PLAYER_ENTERING_WORLD" then
        needsInitUpdate = true
    else
        DeferredUpdateContent()
    end
end)

if type(ObjectiveTracker_Update) == "function" then
    hooksecurefunc("ObjectiveTracker_Update", UpdateContent)
elseif ObjectiveTrackerFrame and type(ObjectiveTrackerFrame.Update) == "function" then
    hooksecurefunc(ObjectiveTrackerFrame, "Update", UpdateContent)
end

hooksecurefunc(ObjectiveTrackerFrame, "SetCollapsed", function(_, collapsed)
    if collapsed then
        DescModule:Hide()
    else
        UpdateContent()
    end
end)
