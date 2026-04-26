local RADIUS = 82

local function GVH_UpdateMinimapPosition(btn)
    GuildVillageDB.mini = GuildVillageDB.mini or {}
    local angle = GuildVillageDB.mini.angle or 210
    local x = math.cos(math.rad(angle)) * RADIUS
    local y = math.sin(math.rad(angle)) * RADIUS
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function GuildVillage_CreateMinimapButton()
    if GuildVillageMinimapButton then
        GVH_UpdateMinimapPosition(GuildVillageMinimapButton)
        GuildVillageMinimapButton:Show()
        return
    end

    local btn = CreateFrame("Button", "GuildVillageMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("LOW")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\AddOns\\GuildVillageHelper\\Textures\\border")
    border:SetSize(32, 32)
    border:SetPoint("CENTER")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", 0, -1)
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\GuildVillageHelper\\Textures\\gv_icon")

    -- Tooltip (cs/en)
    local function GVH_Minimap_L(cs, en)
        local lang = "cs"
        if GuildVillageDB and (GuildVillageDB.language == "cs" or GuildVillageDB.language == "en") then
            lang = GuildVillageDB.language
        end
        if lang == "en" then return en else return cs end
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(GVH_Minimap_L("Guild Village Helper", "Guild Village Helper"), 1, 1, 1)
        GameTooltip:AddLine(GVH_Minimap_L("Levý klik: otevřít/zavřít panel", "Left click: open/close panel"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(GVH_Minimap_L("Pravý klik: teleport do vesnice", "Right click: teleport to village"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Kliky
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        SendChatMessage(".v tp", "SAY")
    else
        if GuildVillageFrame:IsShown() then
            GuildVillageFrame:Hide()
        else
            GuildVillageFrame:Show()

            if GuildVillage_RequestStatus then
                GuildVillage_RequestStatus()
            end
        end
    end
end)


    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx, cy = cx/scale, cy/scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            if angle < 0 then angle = angle + 360 end
            GuildVillageDB.mini = GuildVillageDB.mini or {}
            GuildVillageDB.mini.angle = angle
            GVH_UpdateMinimapPosition(self)
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    GVH_UpdateMinimapPosition(btn)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name)
    if name == "GuildVillageHelper" then
        GuildVillage_CreateMinimapButton()
    end
end)
