-- =============== Status proměnné ===============
local GVH_Materials = {
    { name = "Materiál 1", value = 0, fs = nil },
    { name = "Materiál 2", value = 0, fs = nil },
    { name = "Materiál 3", value = 0, fs = nil },
    { name = "Materiál 4", value = 0, fs = nil },
}

-- výroba (produkce)
local GVH_Production = {
    activeMaterial = "",
    rate = "",
}

local GVH_WaitingProduction = false
local GVH_ProductionIndex = 0

-- expedice
local GVH_Expeditions = {
    count = 0,
    list = {},
}
local GVH_WaitingExpeditions = false

-- bossové
local GVH_Bosses = {
    count = 0,
    list = {},
}
local GVH_WaitingBosses = false

-- úkoly (denní / týdenní)
local GVH_Quests = {
    daily  = { available = false, name = "", progress = "" },
    weekly = { available = false, name = "", progress = "" },
}
local GVH_WaitingQuestDaily  = false
local GVH_WaitingQuestWeekly = false

local GVH_WaitingCurrency = false
local GVH_CurrencyIndex  = 0

local GVH_SilentInfo  = false
local GVH_SilentTimer = 0

-- stav hlavního okna (normál / bez guildy / bez vesnice)
local GVH_MainState = "normal"

local GVH_SilentFrame = CreateFrame("Frame")
GVH_SilentFrame:SetScript("OnUpdate", function(self, elapsed)
    if GVH_SilentTimer > 0 then
        GVH_SilentTimer = GVH_SilentTimer - elapsed
        if GVH_SilentTimer <= 0 then
            GVH_SilentTimer = 0
            GVH_SilentInfo = false
            self:Hide()
        end
    end
end)

-- =============== SavedVariables ===============
local defaultState = {
    mini = { angle = 210 },
}
GuildVillageDB = GuildVillageDB or {}
for k, v in pairs(defaultState) do
    if GuildVillageDB[k] == nil then
        if type(v) == "table" then
            local copy = {}
            for kk, vv in pairs(v) do copy[kk] = vv end
            GuildVillageDB[k] = copy
        else
            GuildVillageDB[k] = v
        end
    end
end

-- =============== Lokalizace (cs/en) ===============
local GVH_Locale = "cs"

local function GVH_L(cs, en)
    if GVH_Locale == "en" then
        return en
    else
        return cs
    end
end

local function GVH_SendCommand(cmd)
    SendChatMessage(cmd, "SAY")
end

-- =============== Vlastní fonty pro okno Guild Village ===============
local GVH_FONT_PATH = "Interface\\AddOns\\GuildVillageHelper\\Fonts\\FRIZQT.ttf"

local GVH_Font_Title     = CreateFont("GVH_Font_Title")
GVH_Font_Title:SetFont(GVH_FONT_PATH, 16, "OUTLINE")
GVH_Font_Title:SetTextColor(1, 1, 1)

local GVH_Font_Highlight = CreateFont("GVH_Font_Highlight")
GVH_Font_Highlight:SetFont(GVH_FONT_PATH, 13, "OUTLINE")
GVH_Font_Highlight:SetTextColor(1, 1, 1)

local GVH_Font_Normal    = CreateFont("GVH_Font_Normal")
GVH_Font_Normal:SetFont(GVH_FONT_PATH, 12, "")
GVH_Font_Normal:SetTextColor(0.95, 0.78, 0.0)

-- =============== Hlavní frame ===============
GuildVillageFrame = CreateFrame("Frame", "GuildVillageFrame", UIParent)
GuildVillageFrame:SetSize(390, 380)
GuildVillageFrame:SetPoint("CENTER")
GuildVillageFrame:Hide()
GuildVillageFrame:SetMovable(true)
GuildVillageFrame:EnableMouse(true)
GuildVillageFrame:RegisterForDrag("LeftButton")
GuildVillageFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
GuildVillageFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

GuildVillageFrame:SetBackdrop({
  bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

-- Titulek
local title = GuildVillageFrame:CreateFontString(nil, "OVERLAY", "GVH_Font_Title")
title:SetPoint("TOP", 0, -14)
title:SetText("Guild Village")

-- Zavírací křížek
local closeButton = CreateFrame("Button", nil, GuildVillageFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)

-- Vnitřní tělo
local body = CreateFrame("Frame", "GuildVillageBody", GuildVillageFrame)
body:SetPoint("TOPLEFT", 12, -40)
body:SetPoint("BOTTOMRIGHT", -12, 12)

-- =============== Tlačítko: Teleport do vesnice (.v tp) ===============
local tpButton = CreateFrame("Button", "GuildVillageTeleportButton", body, "UIPanelButtonTemplate")
tpButton:SetSize(80, 30)
tpButton:SetPoint("TOP", -140, 0)
tpButton:SetText("Do vesnice")

tpButton:SetScript("OnClick", function()
    GVH_SendCommand(".v tp")
end)

-- =============== Tlačítko: AoE Loot: ON/OFF (.v aoeloot) ===============
local GVH_AoeLootEnabled = false

local aoeButton = CreateFrame("Button", "GuildVillageAoeLootButton", body, "UIPanelButtonTemplate")
aoeButton:SetSize(110, 30)
aoeButton:SetPoint("LEFT", tpButton, "RIGHT", 10, 0)

local function GVH_UpdateAoeLootButton()
    if GVH_AoeLootEnabled then
        aoeButton:SetText("AoE Loot: |cff00ff00ON|r")
    else
        aoeButton:SetText("AoE Loot: |cff808080OFF|r")
    end
end

GVH_UpdateAoeLootButton()

aoeButton:SetScript("OnClick", function()
    GVH_SendCommand(".v aoeloot")
    GVH_AoeLootEnabled = not GVH_AoeLootEnabled
    GVH_UpdateAoeLootButton()
end)

-- =============== Tlačítko: Teleport zpátky (.v back) ===============
local backButton = CreateFrame("Button", "GuildVillageBackButton", body, "UIPanelButtonTemplate")
backButton:SetSize(80, 30)
backButton:SetPoint("TOP", 70, 0)
backButton:SetText("Zpátky")

backButton:SetScript("OnClick", function()
    GVH_SendCommand(".v back")
end)

-- =============== Přepínač jazyka (Czech / English) ===============
local langButton = CreateFrame("Button", "GuildVillageLanguageButton", body, "UIPanelButtonTemplate")
langButton:SetSize(80, 20)
langButton:SetPoint("BOTTOM", tpButton, "TOP", 0, 4)

local function GVH_UpdateLanguageButton()
    if GVH_Locale == "cs" then
        langButton:SetText("English")
    else
        langButton:SetText("Czech")
    end
end

local function GVH_SetLocale(locale)
    if locale ~= "cs" and locale ~= "en" then
        return
    end

    GVH_Locale = locale
    GuildVillageDB.language = locale

    GVH_UpdateLanguageButton()
    GVH_UpdateStaticTexts()
end

local GVH_InitFrame = CreateFrame("Frame")
GVH_InitFrame:RegisterEvent("ADDON_LOADED")
GVH_InitFrame:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "GuildVillageHelper" then
        return
    end

    GuildVillageDB = GuildVillageDB or {}

    if not GuildVillageDB.language then
        GuildVillageDB.language = "cs"
    end

    GVH_Locale = GuildVillageDB.language or "cs"

    GVH_SetLocale(GVH_Locale)

    self:UnregisterEvent("ADDON_LOADED")
end)

langButton:SetScript("OnClick", function()
    if GVH_Locale == "cs" then
        GVH_SetLocale("en")
    else
        GVH_SetLocale("cs")
    end
end)

GVH_UpdateLanguageButton()

-- =============== LEVÝ SLOUPEC: Bossové + Expedice ===============

local infoText = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Highlight")
infoText:SetPoint("TOPLEFT", tpButton, "BOTTOMLEFT", 0, -12)
infoText:SetText("Bossové:")

local bossTexts = {}
local bossSubTexts = {}

for i = 1, 4 do
    local fs = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
    if i == 1 then
        fs:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -4)
    else
        fs:SetPoint("TOPLEFT", bossSubTexts[i-1], "BOTTOMLEFT", 0, -7)
    end
    fs:SetText("")
    bossTexts[i] = fs

    local sub = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
    sub:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
    sub:SetText("")
    bossSubTexts[i] = sub
end

local expTitle = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Highlight")
expTitle:SetPoint("TOPLEFT", bossTexts[4], "BOTTOMLEFT", 0, -20)
expTitle:SetText("Expedice:")

local expTexts = {}
for i = 1, 5 do
    local fs = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
    if i == 1 then
        fs:SetPoint("TOPLEFT", expTitle, "BOTTOMLEFT", 0, -4)
    else
        fs:SetPoint("TOPLEFT", expTexts[i-1], "BOTTOMLEFT", 0, -4)
    end
    fs:SetText("")
    expTexts[i] = fs
end

-- =============== PRAVÝ SLOUPEC: Stav materiálu + Výroba ===============

local matTitle = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Highlight")
matTitle:SetPoint("TOPLEFT", backButton, "BOTTOMLEFT", 0, -12)
matTitle:SetText("Stav materiálu:")

local mat1Text = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
mat1Text:SetPoint("TOPLEFT", matTitle, "BOTTOMLEFT", 0, -4)
mat1Text:SetText("Materiál 1: 0")

local mat2Text = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
mat2Text:SetPoint("TOPLEFT", mat1Text, "BOTTOMLEFT", 0, -4)
mat2Text:SetText("Materiál 2: 0")

local mat3Text = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
mat3Text:SetPoint("TOPLEFT", mat2Text, "BOTTOMLEFT", 0, -4)
mat3Text:SetText("Materiál 3: 0")

local mat4Text = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
mat4Text:SetPoint("TOPLEFT", mat3Text, "BOTTOMLEFT", 0, -4)
mat4Text:SetText("Materiál 4: 0")

GVH_Materials[1].fs = mat1Text
GVH_Materials[2].fs = mat2Text
GVH_Materials[3].fs = mat3Text
GVH_Materials[4].fs = mat4Text

local prodTitle = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Highlight")
prodTitle:SetPoint("TOPLEFT", mat4Text, "BOTTOMLEFT", 0, -12)
prodTitle:SetText("Výroba:")

local prodActiveText = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
prodActiveText:SetPoint("TOPLEFT", prodTitle, "BOTTOMLEFT", 0, -4)
prodActiveText:SetText("…")

local prodRateText = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
prodRateText:SetPoint("TOPLEFT", prodActiveText, "BOTTOMLEFT", 0, -4)
prodRateText:SetText("")

-- Úkoly pod výrobou
local questsTitle = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Highlight")
questsTitle:SetPoint("TOPLEFT", prodRateText, "BOTTOMLEFT", 0, -12)
questsTitle:SetText("Úkoly:")

local questUnavailableFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questUnavailableFS:SetPoint("TOPLEFT", questsTitle, "BOTTOMLEFT", 0, 4)
questUnavailableFS:SetText("")

-- Denní
local questDailyTitleFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questDailyTitleFS:SetPoint("TOPLEFT", questUnavailableFS, "BOTTOMLEFT", 0, -4)
questDailyTitleFS:SetText("")

local questDailyTagFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questDailyTagFS:SetPoint("TOPLEFT", questDailyTitleFS, "BOTTOMLEFT", 0, -2)
questDailyTagFS:SetText("")

local questDailyNameFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questDailyNameFS:SetPoint("TOPLEFT", questDailyTagFS, "BOTTOMLEFT", 0, -2)
questDailyNameFS:SetText("")

local questDailyProgFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questDailyProgFS:SetPoint("TOPLEFT", questDailyNameFS, "BOTTOMLEFT", 0, -4)
questDailyProgFS:SetText("")

-- Týdenní
local questWeeklyTitleFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questWeeklyTitleFS:SetPoint("TOPLEFT", questDailyProgFS, "BOTTOMLEFT", 0, -8)
questWeeklyTitleFS:SetText("")

local questWeeklyTagFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questWeeklyTagFS:SetPoint("TOPLEFT", questWeeklyTitleFS, "BOTTOMLEFT", 0, -2)
questWeeklyTagFS:SetText("")

local questWeeklyNameFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questWeeklyNameFS:SetPoint("TOPLEFT", questWeeklyTagFS, "BOTTOMLEFT", 0, -2)
questWeeklyNameFS:SetText("")

local questWeeklyProgFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Normal")
questWeeklyProgFS:SetPoint("TOPLEFT", questWeeklyNameFS, "BOTTOMLEFT", 0, -4)
questWeeklyProgFS:SetText("")

-- =============== Stavové info (no guild / no village) ===============
local centerInfoFS = body:CreateFontString(nil, "OVERLAY", "GVH_Font_Highlight")
centerInfoFS:SetPoint("CENTER", body, "CENTER", 0, 0)
centerInfoFS:SetText("")
centerInfoFS:Hide()

-- =============== Update funkce ===============
local function GuildVillage_UpdateStatusText()
    for i = 1, 4 do
        local m = GVH_Materials[i]
        local label = m.name or ("Materiál " .. i)
        local val   = m.value or 0
        if m.fs then
            m.fs:SetText(label .. ": " .. val)
        end
    end
end

local function GVH_ParseTimeToSeconds(str)
    local h, m, s = str:match("(%d+)h%s*(%d+)m%s*(%d+)s")
    h = tonumber(h) or 0
    m = tonumber(m) or 0
    s = tonumber(s) or 0
    return h * 3600 + m * 60 + s
end

local function GVH_FormatSeconds(sec)
    if sec <= 0 then
        return "0s"
    end

    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)

    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    else
        return string.format("%dm %ds", m, s)
    end
end

local function GuildVillage_UpdateExpeditionsText()
    for i = 1, 5 do
        expTexts[i]:SetText("")
    end

    if GVH_Expeditions.count == 0 then
        expTexts[1]:SetText(GVH_L("Žádná aktivní expedice", "No active expeditions"))
        return
    end

    for i = 1, GVH_Expeditions.count do
        local e = GVH_Expeditions.list[i]
        if e and expTexts[i] then
            local timeText

            if e.seconds and e.seconds >= 0 then
                timeText = GVH_FormatSeconds(e.seconds)
            else
                timeText = e.time or ""
            end

            expTexts[i]:SetText(e.name .. " - " .. timeText)
        end
    end
end

local function GVH_Trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local GVH_BOSS_ARROW = "> "

local function GuildVillage_UpdateBossesText()
    for i = 1, 4 do
        bossTexts[i]:SetText("")
        bossSubTexts[i]:SetText("")
    end

    if GVH_Bosses.count == 0 then
        return
    end

    for i = 1, GVH_Bosses.count do
        local b = GVH_Bosses.list[i]
        if b then
            local name   = GVH_Trim(b.name)
            local status = GVH_Trim(b.status)

            if status:find("Respawn:") or status:find("Respawns at:") then
                local respTime =
                    status:match("Respawn:%s*(.+)") or
                    status:match("Respawns at:%s*(.+)")

                respTime = GVH_Trim(respTime or "")

                bossTexts[i]:SetText(name .. ": " .. GVH_L("Mrtvý", "Dead"))

                bossSubTexts[i]:SetText(
                    GVH_BOSS_ARROW ..
                    GVH_L("Respawn: ", "Respawn: ") ..
                    respTime
                )
            else
                bossTexts[i]:SetText(name .. ": " .. status)
                bossSubTexts[i]:SetText("")
            end
        end
    end
end

local function GVH_SplitQuestName(full)
    if not full or full == "" then
        return "", ""
    end

    local tag, rest = full:match("^(%b[])%s*(.*)")
    if tag then
        return tag, rest
    end

    return "", full
end

local function GuildVillage_UpdateQuestsText()
    questUnavailableFS:SetText("")
    questDailyTitleFS:SetText("")
    questDailyTagFS:SetText("")
    questDailyNameFS:SetText("")
    questDailyProgFS:SetText("")
    questWeeklyTitleFS:SetText("")
    questWeeklyTagFS:SetText("")
    questWeeklyNameFS:SetText("")
    questWeeklyProgFS:SetText("")

    local haveDaily  = GVH_Quests.daily.available  and GVH_Quests.daily.name ~= ""
    local haveWeekly = GVH_Quests.weekly.available and GVH_Quests.weekly.name ~= ""

    if not haveDaily and not haveWeekly then
        questUnavailableFS:SetText("\n" .. GVH_L("Nedostupné", "Unavailable"))
        return
    end

    if haveDaily then
        questDailyTitleFS:SetText(GVH_L("Denní úkol", "Daily quest"))

        local tag, rest = GVH_SplitQuestName(GVH_Quests.daily.name)
        questDailyTagFS:SetText(tag)
        questDailyNameFS:SetText(rest)

        if GVH_Quests.daily.progress ~= "" then
            questDailyProgFS:SetText(GVH_L("Postup: ", "Progress: ") .. GVH_Quests.daily.progress)
        end
    end

    if haveWeekly then
        questWeeklyTitleFS:SetText(GVH_L("Týdenní úkol", "Weekly quest"))

        local tag, rest = GVH_SplitQuestName(GVH_Quests.weekly.name)
        questWeeklyTagFS:SetText(tag)
        questWeeklyNameFS:SetText(rest)

        if GVH_Quests.weekly.progress ~= "" then
            questWeeklyProgFS:SetText(GVH_L("Postup: ", "Progress: ") .. GVH_Quests.weekly.progress)
        end
    end
end

-- =============== Zobrazení / skrytí hlavního obsahu ===============
local function GVH_UpdateMainVisibility()
    if GVH_MainState == "normal" then
        tpButton:Show()
        aoeButton:Show()
        backButton:Show()

        infoText:Show()
        expTitle:Show()
        matTitle:Show()
        prodTitle:Show()
        questsTitle:Show()
        questUnavailableFS:Show()

        for i = 1, 4 do
            bossTexts[i]:Show()
            bossSubTexts[i]:Show()
        end
        for i = 1, 5 do
            expTexts[i]:Show()
        end

        mat1Text:Show()
        mat2Text:Show()
        mat3Text:Show()
        mat4Text:Show()

        prodActiveText:Show()
        prodRateText:Show()

        questDailyTitleFS:Show()
        questDailyTagFS:Show()
        questDailyNameFS:Show()
        questDailyProgFS:Show()

        questWeeklyTitleFS:Show()
        questWeeklyTagFS:Show()
        questWeeklyNameFS:Show()
        questWeeklyProgFS:Show()

        centerInfoFS:Hide()
    else
        tpButton:Hide()
        aoeButton:Hide()
        backButton:Hide()

        infoText:Hide()
        expTitle:Hide()
        matTitle:Hide()
        prodTitle:Hide()
        questsTitle:Hide()
        questUnavailableFS:Hide()

        for i = 1, 4 do
            bossTexts[i]:Hide()
            bossSubTexts[i]:Hide()
        end
        for i = 1, 5 do
            expTexts[i]:Hide()
        end

        mat1Text:Hide()
        mat2Text:Hide()
        mat3Text:Hide()
        mat4Text:Hide()

        prodActiveText:Hide()
        prodRateText:Hide()

        questDailyTitleFS:Hide()
        questDailyTagFS:Hide()
        questDailyNameFS:Hide()
        questDailyProgFS:Hide()

        questWeeklyTitleFS:Hide()
        questWeeklyTagFS:Hide()
        questWeeklyNameFS:Hide()
        questWeeklyProgFS:Hide()

        if GVH_MainState == "no_guild" then
            centerInfoFS:SetText(GVH_L("Nejsi v žádné guildě", "You are not in a guild"))
        elseif GVH_MainState == "no_village" then
            centerInfoFS:SetText(GVH_L("Guilda nemá zakoupenou vesnici", "Your guild does not own a guild village."))
        else
            centerInfoFS:SetText("")
        end
        centerInfoFS:Show()
    end
end

function GVH_UpdateStaticTexts()
    title:SetText(GVH_L("Guildovní vesnice", "Guild Village"))

    tpButton:SetText(GVH_L("Do vesnice", "To village"))
    backButton:SetText(GVH_L("Zpátky", "Back"))

    infoText:SetText(GVH_L("Bossové:", "Bosses:"))
    expTitle:SetText(GVH_L("Expedice:", "Expeditions:"))
    matTitle:SetText(GVH_L("Stav materiálu:", "Materials:"))
    prodTitle:SetText(GVH_L("Výroba:", "Production:"))
    questsTitle:SetText(GVH_L("Úkoly:", "Quests:"))

    GVH_UpdateAoeLootButton()
    GVH_UpdateLanguageButton()

    GuildVillage_UpdateStatusText()
    GuildVillage_UpdateExpeditionsText()
    GuildVillage_UpdateBossesText()
    GuildVillage_UpdateQuestsText()

    GVH_UpdateMainVisibility()
end

-- =============== Ticker (sekundové odpočítávání + auto-refresh) ===============
local GVH_TickerFrame = CreateFrame("Frame")
local GVH_TickerElapsed = 0
local GVH_TickerRefreshElapsed = 0
local GVH_TICK_REFRESH = 30

GVH_TickerFrame:SetScript("OnUpdate", function(self, elapsed)
    if not GuildVillageFrame:IsShown() then
        return
    end

    GVH_TickerElapsed        = GVH_TickerElapsed + elapsed
    GVH_TickerRefreshElapsed = GVH_TickerRefreshElapsed + elapsed

    -------------------------------------------------
    -- 1) Sekundový odpočet pro expedice
    -------------------------------------------------
    local changed = false

    if GVH_TickerElapsed >= 1 then
        GVH_TickerElapsed = 0

        for i = 1, GVH_Expeditions.count do
            local e = GVH_Expeditions.list[i]
            if e and e.seconds and e.seconds > 0 then
                e.seconds = e.seconds - 1
                if e.seconds < 0 then
                    e.seconds = 0
                end
                changed = true
            end
        end

        if changed then
            GuildVillage_UpdateExpeditionsText()
        end
    end

    -------------------------------------------------
    -- 2) Periodické plné obnovení (.v info)
    -------------------------------------------------
    if GVH_TickerRefreshElapsed >= GVH_TICK_REFRESH then
        GVH_TickerRefreshElapsed = 0
        GuildVillage_RequestStatus()
    end
end)

-- =============== Vyžádání statusu z modulu (.v info) ===============
function GuildVillage_RequestStatus()
    GVH_SilentInfo  = true
    GVH_SilentTimer = 2
    GVH_SilentFrame:Show()

    GVH_SendCommand(".v info")
    GVH_SendCommand(".v qd")
    GVH_SendCommand(".v qw")
end

-- =============== Slash command ===============
SLASH_GUILDVILLAGEHELPER1 = "/gvillage"
SLASH_GUILDVILLAGEHELPER2 = "/gvh"
SlashCmdList["GUILDVILLAGEHELPER"] = function()
    if GuildVillageFrame:IsShown() then
        GuildVillageFrame:Hide()
    else
        GuildVillageFrame:Show()
        if GuildVillage_RequestStatus then
            GuildVillage_RequestStatus()
        end
    end
end

DEFAULT_CHAT_FRAME:AddMessage(GVH_L(
    "|cff00ff00[GuildVillageHelper]|r načten. /gvillage nebo ikona u minimapy.",
    "|cff00ff00[GuildVillageHelper]|r loaded. /gvillage or minimap icon."
))

local function GVH_StripColorCodes(s)
    if not s then return s end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    return s
end

-- =============== Event: čtení CHAT_MSG_SYSTEM a parsování výpisu =================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")

eventFrame:SetScript("OnEvent", function(self, event, msg)

    -------------------------------------------------------------
    -- -1) Bez guildy / bez vesnice
    -------------------------------------------------------------
    if msg:find("Nejsi v žádné guildě") or msg:find("You are not in a guild") then
        GVH_MainState = "no_guild"
        GVH_UpdateMainVisibility()
        return
    end

    if msg:find("Tvá guilda nevlastní guildovní vesnici") or
       msg:find("Your guild does not own a guild village") then
        GVH_MainState = "no_village"
        GVH_UpdateMainVisibility()
        return
    end

    -------------------------------------------------------------
    -- 0) ÚKOLY – special hláška, nejsou zakoupené rozšíření
    -------------------------------------------------------------
    if msg:find("nemá zakoupené rozšíření na úkoly") or
       msg:find("Your guild hasn't purchased the Quests expansion") or
       msg:find("Your guild hasn't purchased the \"Quests\" expansion") then
        GVH_Quests.daily.available  = false
        GVH_Quests.weekly.available = false
        GuildVillage_UpdateQuestsText()
        return
    end

    -------------------------------------------------------------
    -- 0a) ÚKOLY – detekce začátku bloků (Denní / Týdenní)
    -------------------------------------------------------------
    if msg:find("^Denní úkol") or msg:find("^Daily quest") then
        GVH_WaitingQuestDaily = true
        GVH_Quests.daily.available = true
        GVH_Quests.daily.name = ""
        GVH_Quests.daily.progress = ""
        GuildVillage_UpdateQuestsText()
        return
    end

    if msg:find("^Týdenní úkol") or msg:find("^Weekly quest") then
        GVH_WaitingQuestWeekly = true
        GVH_Quests.weekly.available = true
        GVH_Quests.weekly.name = ""
        GVH_Quests.weekly.progress = ""
        GuildVillage_UpdateQuestsText()
        return
    end

    -------------------------------------------------------------
    -- 0b) ÚKOLY – parsování řádků
    -------------------------------------------------------------
    if GVH_WaitingQuestDaily then
        local qname = msg:match("^Úkol:%s*(.+)$") or msg:match("^Quest:%s*(.+)$")
        if qname then
            qname = GVH_StripColorCodes(qname)
            GVH_Quests.daily.name = qname
            GuildVillage_UpdateQuestsText()
            return
        end

        local prog = msg:match("^Postup:%s*(.+)$") or msg:match("^Progress:%s*(.+)$")
        if prog then
            GVH_Quests.daily.progress = prog
            GuildVillage_UpdateQuestsText()
            return
        end

        if msg:find("^Stav:") or msg:find("^Status:") then
            GVH_WaitingQuestDaily = false
            return
        end
    end

    if GVH_WaitingQuestWeekly then
        local qname = msg:match("^Úkol:%s*(.+)$") or msg:match("^Quest:%s*(.+)$")
        if qname then
            qname = GVH_StripColorCodes(qname)
            GVH_Quests.weekly.name = qname
            GuildVillage_UpdateQuestsText()
            return
        end

        local prog = msg:match("^Postup:%s*(.+)$") or msg:match("^Progress:%s*(.+)$")
        if prog then
            GVH_Quests.weekly.progress = prog
            GuildVillage_UpdateQuestsText()
            return
        end

        if msg:find("^Stav:") or msg:find("^Status:") then
            GVH_WaitingQuestWeekly = false
            return
        end
    end

    -------------------------------------------------------------
    -- 1) DETEKCE ZAČÁTKU CURRENCY BLOKU
    -------------------------------------------------------------
    if msg:find("%[Materi") or msg:find("%[Materials%]") then
        GVH_MainState = "normal"
        GVH_UpdateMainVisibility()

        GVH_WaitingCurrency = true
        GVH_CurrencyIndex  = 0
        GVH_WaitingProduction = false
        GVH_WaitingExpeditions = false
        GVH_WaitingBosses = false
        return
    end

    -------------------------------------------------------------
    -- 2) PARSOVÁNÍ CURRENCY
    -------------------------------------------------------------
    if GVH_WaitingCurrency then
        local name, valueStr = msg:match("^|cff00ffff([^:]+):|r%s*(%d+)")
        if name and valueStr then
            GVH_CurrencyIndex = GVH_CurrencyIndex + 1
            local idx = GVH_CurrencyIndex

            if idx >= 1 and idx <= 4 then
                GVH_Materials[idx].name  = name
                GVH_Materials[idx].value = tonumber(valueStr) or 0
            end

            if GVH_CurrencyIndex >= 4 then
                GVH_WaitingCurrency = false
                GuildVillage_UpdateStatusText()
            end
        end

        return
    end

    -------------------------------------------------------------
    -- 3) DETEKCE ZAČÁTKU EXPEDIC
    -------------------------------------------------------------
    if GVH_WaitingExpeditions then
        if msg:find("%[Boss") or msg:find("%[Bosses%]") then
            GVH_WaitingExpeditions = false
            GuildVillage_UpdateExpeditionsText()

            GVH_WaitingBosses = true
            GVH_Bosses.count = 0
            GVH_Bosses.list = {}
            return
        end
    end

    if msg:find("%[Expedice%]") or msg:find("%[Expeditions%]") then
        GVH_WaitingExpeditions = true
        GVH_Expeditions.count = 0
        GVH_Expeditions.list = {}
        return
    end

    -------------------------------------------------------------
    -- 4) PARSOVÁNÍ EXPEDIC
    -------------------------------------------------------------
    if GVH_WaitingExpeditions then
        if msg:find("%[Produkc") or msg:find("%[Production%]") or msg:find("%[Materi") then
            GVH_WaitingExpeditions = false
            GuildVillage_UpdateExpeditionsText()
            return
        end

        if msg:find("Žádná aktivní expedice") or msg:find("No active expeditions") then
            GVH_Expeditions.count = 0
            GVH_WaitingExpeditions = false
            GuildVillage_UpdateExpeditionsText()
            return
        end

        local name, time = msg:match("^(.+)%s%-%s(.+)$")
        if name and time then
            local idx = GVH_Expeditions.count + 1
            if idx <= 5 then
                local seconds = GVH_ParseTimeToSeconds(time)
                GVH_Expeditions.list[idx] = {
                    name    = name,
                    time    = time,
                    seconds = seconds,
                }
                GVH_Expeditions.count = idx
            end

            if GVH_Expeditions.count >= 5 then
                GVH_WaitingExpeditions = false
            end

            GuildVillage_UpdateExpeditionsText()
            return
        end
    end

    -------------------------------------------------------------
    -- 5) DETEKCE ZAČÁTKU PRODUKČNÍHO BLOKU
    -------------------------------------------------------------
    if msg:find("%[Produkc") or msg:find("%[Production%]") then
        GVH_WaitingProduction = true
        GVH_ProductionIndex = 0
        return
    end

    -------------------------------------------------------------
    -- 6) PARSOVÁNÍ PRODUKCE
    -------------------------------------------------------------
    if GVH_WaitingProduction then

        if msg:find("Není aktivní žádná výroba")
                or msg:find("No active production")
                or msg:find("No production is currently running") then
            GVH_Production.activeMaterial = GVH_L("Žádná výroba", "No active production")
            GVH_Production.rate = ""

            prodActiveText:SetText(GVH_L("Žádná výroba", "No active production"))
            prodRateText:SetText("")

            GVH_WaitingProduction = false
            return
        end

        local mat = msg:match("Právě je aktivní produkce:%s*(.+)")
                or msg:match("Currently producing:%s*(.+)")
        if mat then
            GVH_Production.activeMaterial = mat
            prodActiveText:SetText(mat)
            GVH_ProductionIndex = 1
            return
        end

        local rate = msg:match("Produkuje:%s*(.+)")
                or msg:match("Producing:%s*(.+)")
        if rate then
            GVH_Production.rate = rate
            prodRateText:SetText(rate)

            GVH_WaitingProduction = false
            return
        end
    end

    -------------------------------------------------------------
    -- 7) DETEKCE ZAČÁTKU BOSS BLOKU
    -------------------------------------------------------------
    if msg:find("%[Bossov") or msg:find("%[Bosses%]") then
        GVH_WaitingBosses = true
        GVH_Bosses.count = 0
        GVH_Bosses.list = {}
        return
    end

    -------------------------------------------------------------
    -- 8) PARSOVÁNÍ BOSSŮ
    -------------------------------------------------------------
    if GVH_WaitingBosses then
        local name, status = msg:match("^|cff00ffff([^:]+):|r%s*(.+)$")
        if not name then
            name, status = msg:match("^([^:]+):%s*(.+)$")
        end

        if name and status then
            local idx = GVH_Bosses.count + 1
            if idx <= 4 then
                GVH_Bosses.list[idx] = { name = name, status = status }
                GVH_Bosses.count = idx
            end

            if GVH_Bosses.count >= 4 then
                GVH_WaitingBosses = false
            end

            GuildVillage_UpdateBossesText()
            return
        end
    end
end)

-- =============== Tichý filtr pro hlášky z Guild Village ===============
local function GVH_ChatFilter(self, event, msg, ...)
    if not GVH_SilentInfo then
        return false
    end

    -- hlavička guildovní vesnice
    if msg:find("Guildovní vesnice") or msg:find("Guild Village") then
        return true
    end

    -- bloky
    if msg:find("%[Materi") or msg:find("%[Materials%]") then
        return true
    end
    if msg:find("%[Produkc") or msg:find("%[Production%]") then
        return true
    end
    if msg:find("%[Expedice%]") or msg:find("%[Expeditions%]") then
        return true
    end
    if msg:find("%[Bossov") or msg:find("%[Bosses%]") then
        return true
    end

    -- výroba
    if msg:find("Právě je aktivní produkce") or msg:find("Currently producing") then
        return true
    end
    if msg:find("Produkuje:") or msg:find("Producing:") then
        return true
    end
    if msg:find("Není aktivní žádná výroba")
            or msg:find("No active production")
            or msg:find("No production is currently running") then
        return true
    end

    -- expedice
    if msg:find("Žádná aktivní expedice") or msg:find("No active expeditions") then
        return true
    end
    if msg:match("^.+%s%-%s.+$") then
        return true
    end

    -- bossové
    if msg:find("Naživu") or msg:find("Respawn:") or msg:find("Respawns at:") then
        return true
    end

    -- detaily
    if msg:match("^|cff00ffff") then
        return true
    end

    -- bez guildy / bez vesnice
    if msg:find("Nejsi v žádné guildě") or msg:find("You are not in a guild") then
        return true
    end
    if msg:find("Tvá guilda nevlastní guildovní vesnici") or
       msg:find("Your guild does not own a guild village") then
        return true
    end

    -- úkoly (Denní / Týdenní)
    if msg:find("Denní úkol") or msg:find("Daily quest") then
        return true
    end
    if msg:find("Týdenní úkol") or msg:find("Weekly quest") then
        return true
    end
    if msg:find("nemá zakoupené rozšíření na úkoly") or
       msg:find("Your guild hasn't purchased the Quests expansion") or
       msg:find("Your guild hasn't purchased the \"Quests\" expansion") then
        return true
    end
    if msg:match("^Úkol:") or msg:match("^Quest:") then
        return true
    end
    if msg:match("^Info:") then
        return true
    end
    if msg:match("^Postup:") or msg:match("^Progress:") then
        return true
    end
    if msg:match("^Odměna:") or msg:match("^Reward:") then
        return true
    end
    if msg:match("^Stav:") or msg:match("^Status:") then
        return true
    end

    return false
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", GVH_ChatFilter)
