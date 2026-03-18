local ADDON_NAME = ...

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local TEXTURES = {
    [1] = [[Interface\Cooldown\star4]],
    [2] = [[Interface\Buttons\UI-Quickslot-Depress]],
    [3] = [[Interface\Buttons\ButtonHilight-Square]],
    [4] = [[Interface\SpellActivationOverlay\IconOverlay]],
    [5] = [[Interface\Buttons\UI-Panel-Button-Highlight]],
    [6] = [[Interface\Buttons\UI-Common-MouseHilight]],
    [7] = [[Interface\Glowbox\Glowbox]],
}

local STYLE_NAMES = {
    [1] = "Star (Animated)",
    [2] = "Border (Clean)",
    [3] = "Square (Soft)",
    [4] = "Glow (Magic)",
    [5] = "Yellow Highlight",
    [6] = "Soft White",
    [7] = "Box Glow",
}

local DEFAULTS = {
    style = 1,
    color = {r = 1, g = 1, b = 1, a = 1},
    alpha = 1.0,
    scale = 1.2,
    pulse = true,
    fadeOut = true,
}

local DB
local activeButtons = {}
local settingsCategory = nil

local function UpdateButtonVisuals(button)
    if not button or not button.kpOverlay then return end
    
    local overlay = button.kpOverlay
    local texture = TEXTURES[DB.style] or TEXTURES[1]
    
    overlay:SetTexture(texture)
    overlay:SetVertexColor(DB.color.r, DB.color.g, DB.color.b, DB.color.a * DB.alpha)

    local offset = 5 * DB.scale
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", -offset, offset)
    overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", offset, -offset)
end

local function CreateButtonEffects(button)
    if not button or button.kpOverlay then return end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetBlendMode("ADD")
    overlay:SetDrawLayer("OVERLAY", 7)
    overlay:Hide()
    button.kpOverlay = overlay

    local pulseGroup = overlay:CreateAnimationGroup()
    pulseGroup:SetLooping("BOUNCE")
    local pulseScale = pulseGroup:CreateAnimation("Scale")
    pulseScale:SetScale(1.05, 1.05)
    pulseScale:SetDuration(0.4)
    pulseScale:SetSmoothing("IN_OUT")
    button.kpPulseAnim = pulseGroup

    local fadeGroup = overlay:CreateAnimationGroup()
    local fadeAlpha = fadeGroup:CreateAnimation("Alpha")
    fadeAlpha:SetFromAlpha(1.0)
    fadeAlpha:SetToAlpha(0.0)
    fadeAlpha:SetDuration(0.3)
    fadeAlpha:SetSmoothing("OUT")
    
    fadeGroup:SetScript("OnFinished", function()
        overlay:Hide()
        overlay:SetAlpha(1.0)
    end)
    button.kpFadeAnim = fadeGroup

    table.insert(activeButtons, button)
    UpdateButtonVisuals(button)
end

local function HookButtonState(button)
    if not button or button.kpHooked then return end

    if button.SetButtonState then
        hooksecurefunc(button, "SetButtonState", function(self, state)
            if not self.kpOverlay then return end
            
            if state == "PUSHED" then
                if self.kpFadeAnim:IsPlaying() then
                    self.kpFadeAnim:Stop()
                    self.kpOverlay:SetAlpha(1.0)
                end
                
                self.kpOverlay:Show()
                
                if DB.pulse then
                    self.kpPulseAnim:Play()
                end
            else
                if self.kpPulseAnim:IsPlaying() then
                    self.kpPulseAnim:Stop()
                end

                if DB.fadeOut then
                    self.kpFadeAnim:Play()
                else
                    self.kpOverlay:Hide()
                end
            end
        end)
    end
    button.kpHooked = true
end

local function ScanBars()
    local bars = {
        "Action", "MultiBarBottomLeft", "MultiBarBottomRight",
        "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
        "StanceBar", "PetActionBar"
    }

    for _, barName in ipairs(bars) do
        for i = 1, 12 do
            local button = _G[barName .. "Button" .. i]
            if not button and barName == "Action" then
                button = _G["ActionButton" .. i]
            end
            
            if button then
                CreateButtonEffects(button)
                HookButtonState(button)
            end
        end
    end
end

local function TryOpenSettingsCategory()
    if not (settingsCategory and Settings and Settings.OpenToCategory) then
        print("KeyPressed: Settings panel not available.")
        return
    end
    Settings.OpenToCategory(settingsCategory:GetID())
end

local function RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    local panel = CreateFrame("Frame")
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("KeyPressed Settings")

    local y = -60
    
    local function CreateCheckbox(text, tooltip, getFunc, setFunc)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20, y)
        check.Text:SetText(text)
        check.tooltip = tooltip
        check:SetScript("OnClick", function(self)
            setFunc(self:GetChecked())
        end)
        check:SetScript("OnShow", function(self) self:SetChecked(getFunc()) end)
        y = y - 30
        return check
    end

    local function CreateSlider(text, key, minVal, maxVal, step)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 20, y)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        
        if not slider.ValueText then
            slider.ValueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            slider.ValueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)
        end
        
        slider.Text:SetText(text)
        slider.Low:SetText("")
        slider.High:SetText("")

        slider:SetScript("OnValueChanged", function(self, value)
            DB[key] = value
            self.ValueText:SetText(string.format("%.2f", value))
            for _, btn in ipairs(activeButtons) do UpdateButtonVisuals(btn) end
        end)
        
        slider:SetScript("OnShow", function(self)
            self:SetValue(DB[key])
            self.ValueText:SetText(string.format("%.2f", DB[key]))
        end)
        
        y = y - 50
        return slider
    end

    CreateCheckbox("Enable Pulse Animation", "The glow will pulse while holding the key.", 
        function() return DB.pulse end, function(v) DB.pulse = v end)
    
    CreateCheckbox("Enable Fade Out", "The glow will fade out smoothly on release.", 
        function() return DB.fadeOut end, function(v) DB.fadeOut = v end)

    y = y - 10

    CreateSlider("Glow Intensity", "alpha", 0.1, 1.0, 0.05)
    CreateSlider("Glow Size", "scale", 0.5, 3.0, 0.1)

    local styleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 20, y)
    styleLabel:SetText("Glow Style:")
    y = y - 20

    local styleDropdown = CreateFrame("Frame", "KP_StyleDropdown", panel, "UIDropDownMenuTemplate")
    styleDropdown:SetPoint("TOPLEFT", 15, y)
    
    local function Dropdown_OnClick(self, arg1)
        DB.style = arg1
        UIDropDownMenu_SetText(styleDropdown, STYLE_NAMES[arg1])
        for _, btn in ipairs(activeButtons) do UpdateButtonVisuals(btn) end
    end

    local function Dropdown_Initialize()
        for i, name in ipairs(STYLE_NAMES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.arg1 = i
            info.func = Dropdown_OnClick
            UIDropDownMenu_AddButton(info)
        end
    end
    
    UIDropDownMenu_Initialize(styleDropdown, Dropdown_Initialize)
    UIDropDownMenu_SetWidth(styleDropdown, 180)
    UIDropDownMenu_SetText(styleDropdown, STYLE_NAMES[DB.style])
    y = y - 40

    local colorHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorHeader:SetPoint("TOPLEFT", 20, y)
    colorHeader:SetText("Glow Color (RGB & Alpha):")
    y = y - 25

    local colorSwatch = panel:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetSize(30, 30)
    colorSwatch:SetPoint("TOPLEFT", 20, y)
    
    local function UpdateSwatch()
        colorSwatch:SetColorTexture(DB.color.r, DB.color.g, DB.color.b, DB.color.a)
    end

    local rSlider = CreateSlider("Red", "r", 0, 1, 0.05)
    rSlider:SetScript("OnValueChanged", function(self, value)
        DB.color.r = value
        self.ValueText:SetText(string.format("%.2f", value))
        UpdateSwatch()
        for _, btn in ipairs(activeButtons) do UpdateButtonVisuals(btn) end
    end)
    rSlider:SetScript("OnShow", function(self)
        self:SetValue(DB.color.r)
        self.ValueText:SetText(string.format("%.2f", DB.color.r))
    end)

    local gSlider = CreateSlider("Green", "g", 0, 1, 0.05)
    gSlider:SetScript("OnValueChanged", function(self, value)
        DB.color.g = value
        self.ValueText:SetText(string.format("%.2f", value))
        UpdateSwatch()
        for _, btn in ipairs(activeButtons) do UpdateButtonVisuals(btn) end
    end)
    gSlider:SetScript("OnShow", function(self)
        self:SetValue(DB.color.g)
        self.ValueText:SetText(string.format("%.2f", DB.color.g))
    end)

    local bSlider = CreateSlider("Blue", "b", 0, 1, 0.05)
    bSlider:SetScript("OnValueChanged", function(self, value)
        DB.color.b = value
        self.ValueText:SetText(string.format("%.2f", value))
        UpdateSwatch()
        for _, btn in ipairs(activeButtons) do UpdateButtonVisuals(btn) end
    end)
    bSlider:SetScript("OnShow", function(self)
        self:SetValue(DB.color.b)
        self.ValueText:SetText(string.format("%.2f", DB.color.b))
    end)

    local aSlider = CreateSlider("Color Alpha", "a", 0, 1, 0.05)
    aSlider:SetScript("OnValueChanged", function(self, value)
        DB.color.a = value
        self.ValueText:SetText(string.format("%.2f", value))
        UpdateSwatch()
        for _, btn in ipairs(activeButtons) do UpdateButtonVisuals(btn) end
    end)
    aSlider:SetScript("OnShow", function(self)
        self:SetValue(DB.color.a)
        self.ValueText:SetText(string.format("%.2f", DB.color.a))
    end)

    panel:SetScript("OnShow", function()
        UpdateSwatch()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "KeyPressed")
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

local function InitializeSettings()
    if not KeyPressedDB then KeyPressedDB = {} end
    for k, v in pairs(DEFAULTS) do
        if KeyPressedDB[k] == nil then KeyPressedDB[k] = v end
    end
    if not KeyPressedDB.color then KeyPressedDB.color = {r=1, g=1, b=1, a=1} end
    DB = KeyPressedDB
end

SLASH_KEYPRESSED1 = "/kp"
SlashCmdList["KEYPRESSED"] = function(msg)
    TryOpenSettingsCategory()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeSettings()
        ScanBars()
        
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            RegisterSettings()
        end)
        
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
