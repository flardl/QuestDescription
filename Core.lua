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

local isApplyingLayout = false
local function ForceAnchorToDesc(module)
    if isApplyingLayout or InCombatLockdown() then return end
    if not DescModule:IsVisible() then return end

    local firstVisible = GetFirstVisibleTrackerModule()

    if module == firstVisible then
        isApplyingLayout = true
        module:ClearAllPoints()
        module:SetPoint("TOP", DescModule, "BOTTOM", 0, -10)
        isApplyingLayout = false
    end
end

-- Hook SetPoint on all tracker modules (named globals + any dynamic ones)
local hookedModules = {}
local function HookModuleSetPoint(module)
    if not module or hookedModules[module] then return end
    hookedModules[module] = true
    hooksecurefunc(module, "SetPoint", function()
        ForceAnchorToDesc(module)
    end)
end

for _, module in ipairs(blizzardModules) do
    HookModuleSetPoint(module)
end
if ObjectiveTrackerFrame.modules then
    for _, module in ipairs(ObjectiveTrackerFrame.modules) do
        HookModuleSetPoint(module)
    end
end

-- 8. HEIGHT RESERVATION
local function ComputeReservedHeight()
    local OTF = ObjectiveTrackerFrame
    if not OTF or not OTF:IsVisible() or (OTF.collapsed or OTF.isCollapsed) then
        return 0
    end

    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    local title, description = GetBestQuestDescription(questID)
    if not title or not description then return 0 end

    if DescModule.isCollapsed then
        return 25 + 10
    end

    MeasureString:SetText(description)
    local textHeight = MeasureString:GetStringHeight()
    MeasureString:SetText("")

    return 25 + textHeight + 15 + 10
end

local function HookModule(module)
    if not module then return end

    if type(module.LayoutContents) == "function" then
        local origLC = module.LayoutContents
        module.LayoutContents = function(self, ...)
            local reserved = ComputeReservedHeight()
            if reserved > 0 and self.availableHeight and self.availableHeight > 0 then
                self.availableHeight = self.availableHeight - reserved
            end
            return origLC(self, ...)
        end
    end

    if type(module.BeginLayout) == "function" then
        local origBL = module.BeginLayout
        module.BeginLayout = function(self, ...)
            local result = origBL(self, ...)
            local reserved = ComputeReservedHeight()
            if reserved > 0 and self.availableHeight and self.availableHeight > 0 then
                self.availableHeight = self.availableHeight - reserved
            end
            return result
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

local function RequestTrackerLayout()
    if InCombatLockdown() then return end
    ObjectiveTrackerManager:UpdateAll()
end

-- 9. Content update
local function UpdateContent()
    if InCombatLockdown() then return end

    local OTF = ObjectiveTrackerFrame
    if not OTF or not OTF:IsVisible() or (OTF.collapsed or OTF.isCollapsed) then
        DescModule:Hide()
        return
    end

    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    local title, description = GetBestQuestDescription(questID)

    if title and description then
        DescModule.Header.Text:SetText(title)
        DescModule.Text:SetText(description)
        DescModule.Text:SetShown(not DescModule.isCollapsed)

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

        for _, module in ipairs(blizzardModules) do
            if module and module:IsVisible() then
                ForceAnchorToDesc(module)
                break
            end
        end

        if not wasVisible or math.abs(oldHeight - totalHeight) > 1 then
            C_Timer.After(0, RequestTrackerLayout)
        end
    else
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

-- 10. Minimize Toggle
DescModule.Header.MinimizeButton:SetScript("OnClick", function()
    DescModule.isCollapsed = not DescModule.isCollapsed
    AddQuestInfoSaved.isCollapsed = DescModule.isCollapsed
    UpdateMinimizeButtonTexture()
    UpdateContent()
    C_Timer.After(0, RequestTrackerLayout)
end)

-- 11. Events
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
EventFrame:SetScript("OnEvent", function() UpdateContent() end)

-- Restore saved collapse state after variables are loaded
EventFrame:RegisterEvent("VARIABLES_LOADED")
EventFrame:SetScript("OnEvent", function(_, event)
    if event == "VARIABLES_LOADED" then
        DescModule.isCollapsed = AddQuestInfoSaved.isCollapsed or false
        UpdateMinimizeButtonTexture()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local done = false
        local origUA = ObjectiveTrackerManager.UpdateAll
        ObjectiveTrackerManager.UpdateAll = function(self, ...)
            if not done then
                done = true
                ObjectiveTrackerManager.UpdateAll = origUA
                UpdateContent()
            end
            return origUA(self, ...)
        end
    else
        UpdateContent()
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
