local ENABLED_CONVAR_NAME = "web_always_run_cl_enabled"
local SET_KEY_COMMAND = "web_always_run_set_key"
local SAVE_FILE_PATH = "web_always_run_settings.txt"
local TOOL_TAB_NAME = "Utilities"
local TOOL_CATEGORY_NAME = "Server"
local TOOL_CLASS_NAME = "web_always_run_settings"

local alwaysRunEnabled = CreateClientConVar(ENABLED_CONVAR_NAME, "1", true, false, "Internal client toggle state for the Always Run addon")
local localization = include("always_run_localization.lua")
local SETTINGS_VERSION = 2
local DEFAULT_TOGGLE_KEY = KEY_CAPSLOCK
local TOGGLE_KEY = DEFAULT_TOGGLE_KEY
local alwaysRunToggled = true
local lastToggleKeyState = false
local alwaysRunMuteSound = true
local alwaysRunCustomKeyEnabled = false
local isCapturingKey = false
local KEY_MIN, KEY_MAX = 1, 159
local keyButton
local mainCheckbox
local keyboardIcon = Material("icon16/keyboard.png")
local githubIcon = Material("icon32/github.png")

local function SyncEnabledConVar()
    RunConsoleCommand(ENABLED_CONVAR_NAME, alwaysRunToggled and "1" or "0")
end

local function EscapeJSONString(value)
    local escaped = tostring(value)
    escaped = escaped:gsub("\\", "\\\\")
    escaped = escaped:gsub("\"", "\\\"")
    escaped = escaped:gsub("\r", "\\r")
    escaped = escaped:gsub("\n", "\\n")
    escaped = escaped:gsub("\t", "\\t")
    return escaped
end

local function SerializeAlwaysRunSettings(data)
    local lines = {
        "{",
        "  \"version\": " .. tostring(data.version or SETTINGS_VERSION) .. ",",
        "  \"profiles\": {"
    }

    local profileNames = {}
    for profileName in pairs(data.profiles or {}) do
        profileNames[#profileNames + 1] = profileName
    end
    table.sort(profileNames)

    for index, profileName in ipairs(profileNames) do
        local profile = data.profiles[profileName] or {}
        lines[#lines + 1] = "    \"" .. EscapeJSONString(profileName) .. "\": {"
        lines[#lines + 1] = "      \"toggled\": " .. tostring(profile.toggled ~= false) .. ","
        lines[#lines + 1] = "      \"toggle_key\": " .. tostring(tonumber(profile.toggle_key) or DEFAULT_TOGGLE_KEY) .. ","
        lines[#lines + 1] = "      \"mute_sound\": " .. tostring(profile.mute_sound ~= false) .. ","
        lines[#lines + 1] = "      \"custom_key_enabled\": " .. tostring(profile.custom_key_enabled == true)
        lines[#lines + 1] = "    }" .. (index < #profileNames and "," or "")
    end

    lines[#lines + 1] = "  }"
    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end

local function GetCurrentProfileKey()
    if engine and engine.ActiveGamemode then
        local gameMode = engine.ActiveGamemode()
        if gameMode and gameMode ~= "" then
            return gameMode
        end
    end
    return "global"
end

local function BuildDefaultProfile()
    return {
        toggled = true,
        toggle_key = DEFAULT_TOGGLE_KEY,
        mute_sound = true,
        custom_key_enabled = false
    }
end

local function GetKeyDisplayName(keyCode)
    return input.GetKeyName(keyCode) or ("KEY_" .. tostring(keyCode or DEFAULT_TOGGLE_KEY))
end

local function PlayToggleSound(isEnabled)
    if alwaysRunMuteSound then return end
    local toggleSound = isEnabled and "garrysmod/ui_click.wav" or "garrysmod/ui_return.wav"
    sound.PlayFile("sound/" .. toggleSound, "noplay noblock", function(channel)
        if channel then
            channel:SetVolume(1)
            channel:Play()
            return
        end
        surface.PlaySound(toggleSound)
    end)
end

local function IsSpeedModifierPressed()
    if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
        return true
    end
    local speedBind = input.LookupBinding("+speed", true)
    if not speedBind then return false end
    local speedCode = input.GetKeyCode(speedBind)
    return speedCode and speedCode > 0 and input.IsKeyDown(speedCode) or false
end

local function ShouldBypassAlwaysRun(player)
    local moveType = player:GetMoveType()
    return moveType == MOVETYPE_NOCLIP or moveType == MOVETYPE_OBSERVER or moveType == MOVETYPE_LADDER
end

local function GetForbiddenKeys()
    local forbidden = {
        [KEY_ESCAPE] = true, [KEY_F1] = true, [KEY_F2] = true, [KEY_F3] = true, [KEY_F4] = true,
        [KEY_F5] = true, [KEY_F6] = true, [KEY_F7] = true, [KEY_F8] = true, [KEY_F9] = true,
        [KEY_F10] = true, [KEY_F11] = true, [KEY_F12] = true,
        [MOUSE_LEFT] = true, [MOUSE_RIGHT] = true, [MOUSE_MIDDLE] = true
    }
    local binds = {
        "+forward", "+moveleft", "+back", "+moveright",
        "+menu_context", "+menu",
        "noclip",
        "gmod_undo",
        "+jump",
        "+duck",
        "+attack",
        "+attack2",
        "+speed",
        "+walk",
        "+reload",
        "+use",
        "impulse 100",
        "impulse 201",
        "+zoom",
        "messagemode",
        "messagemode2",
        "+voicerecord",
        "+showscores",
        "toggleconsole",
        "pause"
    }
    for i = 0, 9 do
        table.insert(binds, "slot" .. i)
    end
    for _, bind in ipairs(binds) do
        local key = input.LookupBinding(bind, true)
        if key then
            local keycode = input.GetKeyCode(key)
            if keycode and keycode > 0 then
                forbidden[keycode] = true
            end
        end
    end
    return forbidden
end

local function GetLocalizedPhrase(key)
    local lang = GetConVar("gmod_language"):GetString()
    return (localization[lang] and localization[lang][key]) or localization["en"][key]
end

local function SaveAlwaysRunSettings()
    local profileKey = GetCurrentProfileKey()
    local data = util.JSONToTable(file.Read(SAVE_FILE_PATH, "DATA") or "") or {}
    data.version = SETTINGS_VERSION
    data.profiles = data.profiles or {}
    data.profiles[profileKey] = {
        toggled = alwaysRunToggled,
        toggle_key = TOGGLE_KEY or DEFAULT_TOGGLE_KEY,
        mute_sound = alwaysRunMuteSound,
        custom_key_enabled = alwaysRunCustomKeyEnabled
    }
    file.Write(SAVE_FILE_PATH, SerializeAlwaysRunSettings(data))
end

local function LoadAlwaysRunSettings()
    local profileKey = GetCurrentProfileKey()
    local defaultProfile = BuildDefaultProfile()
    if file.Exists(SAVE_FILE_PATH, "DATA") then
        local raw = file.Read(SAVE_FILE_PATH, "DATA") or ""
        local parsed = util.JSONToTable(raw)
        if parsed and parsed.profiles then
            local profile = parsed.profiles[profileKey] or parsed.profiles["global"] or defaultProfile
            alwaysRunToggled = profile.toggled ~= false
            TOGGLE_KEY = tonumber(profile.toggle_key) or DEFAULT_TOGGLE_KEY
            alwaysRunMuteSound = profile.mute_sound ~= false
            alwaysRunCustomKeyEnabled = profile.custom_key_enabled == true
        else
            local state, key, mute, custom = string.match(raw, "^(%d):(%d+):?(%d?):?(%d?)$")
            alwaysRunToggled = (state == "1")
            TOGGLE_KEY = tonumber(key) or DEFAULT_TOGGLE_KEY
            alwaysRunMuteSound = (mute == "1")
            alwaysRunCustomKeyEnabled = (custom == "1")
            SaveAlwaysRunSettings()
        end
    else
        alwaysRunToggled = defaultProfile.toggled
        TOGGLE_KEY = defaultProfile.toggle_key
        alwaysRunMuteSound = defaultProfile.mute_sound
        alwaysRunCustomKeyEnabled = defaultProfile.custom_key_enabled
        SaveAlwaysRunSettings()
    end
    SyncEnabledConVar()
    lastToggleKeyState = input.IsKeyDown(TOGGLE_KEY)
end

hook.Add("Think", "web_AlwaysRunToggleKey", function()
    if isCapturingKey then return end
    if not alwaysRunCustomKeyEnabled then lastToggleKeyState = false return end
    local keyDown = input.IsKeyDown(TOGGLE_KEY)
    if keyDown and not lastToggleKeyState then
        alwaysRunToggled = not alwaysRunToggled
        SyncEnabledConVar()
        SaveAlwaysRunSettings()
        PlayToggleSound(alwaysRunToggled)
    end
    lastToggleKeyState = keyDown
end)

hook.Add("CreateMove", "web_AlwaysRun", function(cmd)
    if not alwaysRunToggled then return end
    local player = LocalPlayer()
    if not IsValid(player) then return end
    if ShouldBypassAlwaysRun(player) then
        -- Do not alter +speed for noclip/observer/ladder and ragdoll-like move states.
        return
    end
    if input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT) or IsSpeedModifierPressed() then
        cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_SPEED)))
    else
        cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))
    end
end)

local function RebuildPanel(panel)
    panel:ClearControls()
    local checkbox = panel:CheckBox(GetLocalizedPhrase("always_run_enabled"))
    checkbox:SetValue(alwaysRunToggled)
    checkbox.OnChange = function(_, value)
        alwaysRunToggled = value
        SyncEnabledConVar()
        SaveAlwaysRunSettings()
    end
    mainCheckbox = checkbox

    panel:Help(GetLocalizedPhrase("always_run_description"))
    panel:Help(GetLocalizedPhrase("always_run_capslock_hint"))

    local customKeyCheckbox = panel:CheckBox(GetLocalizedPhrase("always_run_custom_key_enable"))
    customKeyCheckbox:SetValue(alwaysRunCustomKeyEnabled)
    customKeyCheckbox:DockMargin(0, 8, 0, 0)
    local customKeyDescription = panel:Help(GetLocalizedPhrase("always_run_custom_key_description"))
    customKeyDescription:SetVisible(alwaysRunCustomKeyEnabled)
    local customKeyCancelHint = panel:Help(GetLocalizedPhrase("always_run_key_cancel_hint"))
    customKeyCancelHint:SetVisible(alwaysRunCustomKeyEnabled)

    if keyButton then keyButton:Remove() end
    keyButton = vgui.Create("DButton")
    keyButton:SetText("  " .. GetLocalizedPhrase("always_run_key") .. GetKeyDisplayName(TOGGLE_KEY))
    keyButton:SetTall(32)
    keyButton:SetTextColor(Color(255,255,255))
    keyButton:Dock(TOP)
    keyButton:DockMargin(16, 4, 60, 8)
    keyButton.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(36, 41, 46))
        if self:IsHovered() then
            draw.RoundedBox(6, 0, 0, w, h, Color(56, 61, 66, 180))
        end
    end
    keyButton.DoClick = function() RunConsoleCommand(SET_KEY_COMMAND) end
    keyButton:SetToolTip(GetLocalizedPhrase("always_run_select_key_hint"))
    keyButton.PaintOver = function(self, w, h)
        surface.SetDrawColor(255,255,255,255)
        surface.SetMaterial(keyboardIcon)
        surface.DrawTexturedRect(6, h/2-8, 16, 16)
    end
    panel:AddItem(keyButton)
    keyButton:SetVisible(alwaysRunCustomKeyEnabled)

    customKeyCheckbox.OnChange = function(_, value)
        alwaysRunCustomKeyEnabled = value
        SaveAlwaysRunSettings()
        RebuildPanel(panel)
    end

    local muteCheckbox = panel:CheckBox(GetLocalizedPhrase("always_run_mute_sound"))
    muteCheckbox:SetValue(alwaysRunMuteSound)
    muteCheckbox:SetVisible(alwaysRunCustomKeyEnabled)
    muteCheckbox:DockMargin(16, 0, 0, 0)
    muteCheckbox.OnChange = function(_, value)
        alwaysRunMuteSound = value
        SaveAlwaysRunSettings()
    end

    local githubButton = vgui.Create("DButton")
    githubButton:SetText("  " .. GetLocalizedPhrase("always_run_github"))
    githubButton:SetTall(32)
    githubButton:SetTextColor(Color(255,255,255))
    githubButton:Dock(TOP)
    githubButton.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(36, 41, 46))
        if self:IsHovered() then
            draw.RoundedBox(6, 0, 0, w, h, Color(56, 61, 66, 180))
        end
    end
    githubButton.DoClick = function() gui.OpenURL("https://github.com/boxden/AlwaysRun") end
    githubButton.PaintOver = function(self, w, h)
        surface.SetDrawColor(255,255,255,255)
        surface.SetMaterial(githubIcon)
        surface.DrawTexturedRect(6, h/2-8, 16, 16)
    end
    panel:AddItem(githubButton)
end

hook.Add("PopulateToolMenu", "web_AlwaysRunSettings", function()
    LoadAlwaysRunSettings()
    spawnmenu.AddToolMenuOption(TOOL_TAB_NAME, TOOL_CATEGORY_NAME, TOOL_CLASS_NAME, GetLocalizedPhrase("always_run_menu"), "", "", function(panel)
        RebuildPanel(panel)
    end)
end)

if timer.Exists("web_AlwaysRunSyncCheckbox") then timer.Remove("web_AlwaysRunSyncCheckbox") end

timer.Create("web_AlwaysRunSyncCheckbox", 0.1, 0, function()
    if mainCheckbox and mainCheckbox:IsValid() then
        if mainCheckbox:GetChecked() ~= alwaysRunToggled then
            mainCheckbox:SetChecked(alwaysRunToggled)
        end
    end
end)

local function FinishKeyCapture(newKey)
    isCapturingKey = false
    hook.Remove("Think", "web_AlwaysRunKeyCapture")

    if newKey == KEY_ESCAPE then
        if keyButton and keyButton:IsValid() and keyButton.SetText then
            keyButton:SetText(GetLocalizedPhrase("always_run_key") .. GetKeyDisplayName(TOGGLE_KEY))
        end
        chat.AddText(Color(255,100,100), GetLocalizedPhrase("always_run_key_cancelled"))
        return
    end

    local forbidden = GetForbiddenKeys()
    if forbidden[newKey] then
        if keyButton and keyButton:IsValid() and keyButton.SetText then
            keyButton:SetText(GetLocalizedPhrase("always_run_key") .. GetKeyDisplayName(TOGGLE_KEY))
        end
        chat.AddText(Color(255,100,100), GetLocalizedPhrase("always_run_key_forbidden"))
        return
    end

    TOGGLE_KEY = newKey
    SaveAlwaysRunSettings()
    chat.AddText(Color(0,255,0), GetLocalizedPhrase("always_run_key_selected") .. GetKeyDisplayName(newKey))
    if keyButton and keyButton:IsValid() and keyButton.SetText then
        keyButton:SetText(GetLocalizedPhrase("always_run_key") .. GetKeyDisplayName(newKey))
    end
    lastToggleKeyState = input.IsKeyDown(TOGGLE_KEY)
end

concommand.Add(SET_KEY_COMMAND, function()
    if isCapturingKey then return end
    if keyButton and keyButton:IsValid() and keyButton.SetText then
        keyButton:SetText(GetLocalizedPhrase("always_run_key") .. "...")
    end
    isCapturingKey = true

    timer.Simple(0, function()
        if not isCapturingKey then return end

        RunConsoleCommand("-menu")
        gui.EnableScreenClicker(false)
        chat.AddText(Color(255,255,0), GetLocalizedPhrase("always_run_press_key_hint"))
        input.StartKeyTrapping()

        hook.Add("Think", "web_AlwaysRunKeyCapture", function()
            local trappedKey = input.CheckKeyTrapping()
            if trappedKey and trappedKey ~= 0 then
                FinishKeyCapture(trappedKey)
            end
        end)
    end)
end)

cvars.AddChangeCallback(ENABLED_CONVAR_NAME, function(_, _, newValue)
    alwaysRunToggled = tonumber(newValue) == 1
end, "web_AlwaysRunEnabledSync")

hook.Add("ShutDown", "web_AlwaysRunCleanup", function()
    if isCapturingKey then
        hook.Remove("Think", "web_AlwaysRunKeyCapture")
        if keyButton and keyButton:IsValid() and keyButton.SetText then
            keyButton:SetText(GetLocalizedPhrase("always_run_key") .. GetKeyDisplayName(TOGGLE_KEY))
        end
    end
end)

hook.Add("Initialize", "web_AlwaysRunLoadSettings", LoadAlwaysRunSettings)
hook.Add("InitPostEntity", "web_AlwaysRunLoadSettingsPost", LoadAlwaysRunSettings)
hook.Add("OnGamemodeLoaded", "web_AlwaysRunEnsureConVar", function()
    local savedValue = GetConVar(ENABLED_CONVAR_NAME):GetString()
    RunConsoleCommand(ENABLED_CONVAR_NAME, savedValue)
    alwaysRunToggled = alwaysRunEnabled:GetBool()
end)
