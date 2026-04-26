local ENABLED_CONVAR_NAME = "web_always_run_cl_enabled"
local SET_KEY_COMMAND = "web_always_run_set_key"
local SET_KEY_CLI_COMMAND = "web_always_run_set_toggle_key"
local TOGGLE_COMMAND = "web_always_run_toggle"
local SAVE_FILE_PATH = "web_always_run_settings.txt"
local TOOL_TAB_NAME = "Utilities"
local TOOL_CATEGORY_NAME = "User"
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
local alwaysRunProtectedKeysEnabled = true
local isCapturingKey = false
local KEY_MIN, KEY_MAX = 1, 159
local keyButton
local mainCheckbox
local descriptionHelpLabel
local keyboardIcon = Material("icon16/keyboard.png")
local githubIcon = Material("icon32/github.png")
local SaveAlwaysRunSettings

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
        "\t\"version\": " .. tostring(data.version or SETTINGS_VERSION) .. ",",
        "\t\"profiles\": {"
    }

    local profileNames = {}
    for profileName in pairs(data.profiles or {}) do
        profileNames[#profileNames + 1] = profileName
    end
    table.sort(profileNames)

    for index, profileName in ipairs(profileNames) do
        local profile = data.profiles[profileName] or {}
        lines[#lines + 1] = "\t\t\"" .. EscapeJSONString(profileName) .. "\": {"
        lines[#lines + 1] = "\t\t\t\"toggled\": " .. tostring(profile.toggled ~= false) .. ","
        lines[#lines + 1] = "\t\t\t\"toggle_key\": " .. tostring(tonumber(profile.toggle_key) or DEFAULT_TOGGLE_KEY) .. ","
        lines[#lines + 1] = "\t\t\t\"mute_sound\": " .. tostring(profile.mute_sound ~= false) .. ","
        lines[#lines + 1] = "\t\t\t\"custom_key_enabled\": " .. tostring(profile.custom_key_enabled == true) .. ","
        lines[#lines + 1] = "\t\t\t\"protected_keys_enabled\": " .. tostring(profile.protected_keys_enabled ~= false)
        lines[#lines + 1] = "\t\t}" .. (index < #profileNames and "," or "")
    end

    lines[#lines + 1] = "\t}"
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
        custom_key_enabled = false,
        protected_keys_enabled = true
    }
end

local function GetKeyDisplayName(keyCode)
    return input.GetKeyName(keyCode) or ("KEY_" .. tostring(keyCode or DEFAULT_TOGGLE_KEY))
end

local function ResolveKeyCode(value)
    if not value or value == "" then
        return nil
    end

    local numericKeyCode = tonumber(value)
    if numericKeyCode and numericKeyCode >= KEY_MIN and numericKeyCode <= KEY_MAX then
        return numericKeyCode
    end

    local directKeyCode = input.GetKeyCode(string.upper(tostring(value)))
    if directKeyCode and directKeyCode >= KEY_MIN and directKeyCode <= KEY_MAX then
        return directKeyCode
    end

    local loweredValue = string.lower(tostring(value))
    for keyCode = KEY_MIN, KEY_MAX do
        local keyName = input.GetKeyName(keyCode)
        if keyName and string.lower(keyName) == loweredValue then
            return keyCode
        end
    end

    return nil
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

local function GetBoundKeyCode(command)
    local bindName = input.LookupBinding(command, true)
    if not bindName then
        return nil
    end

    local keyCode = input.GetKeyCode(bindName)
    if not keyCode or keyCode <= 0 then
        return nil
    end

    return keyCode
end

local function IsBoundCommandPressed(command)
    local keyCode = GetBoundKeyCode(command)
    return keyCode and input.IsKeyDown(keyCode) or false
end

local function IsMovementModifierPressed()
    return IsBoundCommandPressed("+speed") or IsBoundCommandPressed("+walk")
end

local function ShouldBypassAlwaysRun(player)
    local moveType = player:GetMoveType()
    return moveType == MOVETYPE_NOCLIP or moveType == MOVETYPE_OBSERVER or moveType == MOVETYPE_LADDER
end

local function GetForbiddenKeys()
    if not alwaysRunProtectedKeysEnabled then
        return {}
    end

    local forbidden = {
        [MOUSE_MIDDLE] = true,
        [KEY_RCONTROL] = true,
        [KEY_RSHIFT] = true
    }

    local binds = {
        "+forward", "+moveleft", "+back", "+moveright",
        "+lookup", "+lookdown", "+left", "+right",
        "+jump", "+duck",
        "+speed", "+walk",
        "noclip", "gmod_undo",
        "+menu_context", "+menu",
        "+attack", "+attack2",
        "lastinv", "invprev", "invnext",
        "+reload", "+use", "+zoom",
        "impulse 100", "impulse 201",
        "messagemode", "messagemode2",
        "+voicerecord", "+showscores",
        "toggleconsole", "pause", "cancelselect",
        "gm_showhelp", "gm_showteam",
        "gm_showspare1", "gm_showspare2",
        "jpeg", "save quick", "load quick",
        "slot0", "slot1", "slot2", "slot3", "slot4",
        "slot5", "slot6", "slot7", "slot8", "slot9"
    }
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

local function ApplyToggleState(newState, shouldPlaySound)
    alwaysRunToggled = newState
    SyncEnabledConVar()
    SaveAlwaysRunSettings()
    if shouldPlaySound then
        PlayToggleSound(alwaysRunToggled)
    end
end

local function ToggleAlwaysRun(shouldPlaySound)
    ApplyToggleState(not alwaysRunToggled, shouldPlaySound)
end

local function GetLocalizedPhrase(key)
    local lang = GetConVar("gmod_language"):GetString()
    return (localization[lang] and localization[lang][key]) or localization["en"][key]
end

local function GetPrettyKeyName(keyCode, fallback)
    local keyName = input.GetKeyName(keyCode or 0)
    if not keyName or keyName == "" then
        return fallback
    end

    keyName = tostring(keyName)
    if #keyName == 1 then
        return string.upper(keyName)
    end

    return string.upper(string.sub(keyName, 1, 1)) .. string.lower(string.sub(keyName, 2))
end

local function GetMovementModifierDisplayName(primaryCommand, secondaryCommand, fallback)
    local primaryKeyCode = GetBoundKeyCode(primaryCommand)
    if primaryKeyCode then
        return GetPrettyKeyName(primaryKeyCode, fallback)
    end

    local secondaryKeyCode = GetBoundKeyCode(secondaryCommand)
    if secondaryKeyCode then
        return GetPrettyKeyName(secondaryKeyCode, fallback)
    end

    return fallback
end

local function GetAlwaysRunDescription()
    local template = GetLocalizedPhrase("always_run_description")
    local speedKey = GetMovementModifierDisplayName("+speed", "+walk", "SHIFT")
    local walkKey = GetMovementModifierDisplayName("+walk", "+speed", "ALT")

    template = string.gsub(template, "{speed_key}", speedKey)
    template = string.gsub(template, "{walk_key}", walkKey)

    return template
end

local function CloseSpawnMenuForKeyCapture()
    RunConsoleCommand("-menu")

    if g_SpawnMenu and g_SpawnMenu.IsValid and g_SpawnMenu:IsValid() then
        g_SpawnMenu:Close()
        g_SpawnMenu:SetVisible(false)
    end

    if g_ContextMenu and g_ContextMenu.IsValid and g_ContextMenu:IsValid() then
        g_ContextMenu:Close()
        g_ContextMenu:SetVisible(false)
    end

    hook.Run("OnSpawnMenuClose")
    gui.EnableScreenClicker(false)
end

function SaveAlwaysRunSettings()
    local profileKey = GetCurrentProfileKey()
    local data = util.JSONToTable(file.Read(SAVE_FILE_PATH, "DATA") or "") or {}
    data.version = SETTINGS_VERSION
    data.profiles = data.profiles or {}
    data.profiles[profileKey] = {
        toggled = alwaysRunToggled,
        toggle_key = TOGGLE_KEY or DEFAULT_TOGGLE_KEY,
        mute_sound = alwaysRunMuteSound,
        custom_key_enabled = alwaysRunCustomKeyEnabled,
        protected_keys_enabled = alwaysRunProtectedKeysEnabled
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
            alwaysRunProtectedKeysEnabled = profile.protected_keys_enabled ~= false
        else
            local state, key, mute, custom = string.match(raw, "^(%d):(%d+):?(%d?):?(%d?)$")
            alwaysRunToggled = (state == "1")
            TOGGLE_KEY = tonumber(key) or DEFAULT_TOGGLE_KEY
            alwaysRunMuteSound = (mute == "1")
            alwaysRunCustomKeyEnabled = (custom == "1")
            alwaysRunProtectedKeysEnabled = true
            SaveAlwaysRunSettings()
        end
    else
        alwaysRunToggled = defaultProfile.toggled
        TOGGLE_KEY = defaultProfile.toggle_key
        alwaysRunMuteSound = defaultProfile.mute_sound
        alwaysRunCustomKeyEnabled = defaultProfile.custom_key_enabled
        alwaysRunProtectedKeysEnabled = defaultProfile.protected_keys_enabled
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
        ToggleAlwaysRun(true)
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
    if IsMovementModifierPressed() then
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
        ApplyToggleState(value, false)
    end
    mainCheckbox = checkbox

    descriptionHelpLabel = panel:Help(GetAlwaysRunDescription())

    local customKeyCheckbox = panel:CheckBox(GetLocalizedPhrase("always_run_custom_key_enable"))
    customKeyCheckbox:SetValue(alwaysRunCustomKeyEnabled)
    customKeyCheckbox:DockMargin(0, 8, 0, 0)
    local customKeyAssignHint = panel:Help(GetLocalizedPhrase("always_run_capslock_hint"))
    customKeyAssignHint:SetVisible(alwaysRunCustomKeyEnabled)
    local customKeyDescription = panel:Help(GetLocalizedPhrase("always_run_custom_key_description"))
    customKeyDescription:SetVisible(alwaysRunCustomKeyEnabled)
    local customKeyCancelHint = panel:Help(GetLocalizedPhrase("always_run_key_cancel_hint"))
    customKeyCancelHint:SetVisible(alwaysRunCustomKeyEnabled)
    local protectedKeysCheckbox = panel:CheckBox(GetLocalizedPhrase("always_run_protected_keys"))
    protectedKeysCheckbox:SetValue(alwaysRunProtectedKeysEnabled)
    protectedKeysCheckbox:SetVisible(alwaysRunCustomKeyEnabled)
    protectedKeysCheckbox:DockMargin(16, 0, 0, 0)
    local protectedKeysDescription = panel:Help(GetLocalizedPhrase("always_run_protected_keys_description"))
    protectedKeysDescription:SetVisible(alwaysRunCustomKeyEnabled)

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

    protectedKeysCheckbox.OnChange = function(_, value)
        alwaysRunProtectedKeysEnabled = value
        SaveAlwaysRunSettings()
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

    if descriptionHelpLabel and descriptionHelpLabel:IsValid() then
        local expectedText = GetAlwaysRunDescription()
        if descriptionHelpLabel:GetText() ~= expectedText then
            descriptionHelpLabel:SetText(expectedText)
            descriptionHelpLabel:SizeToContentsY()
            descriptionHelpLabel:InvalidateLayout(true)
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
    alwaysRunCustomKeyEnabled = true
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

        CloseSpawnMenuForKeyCapture()
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

concommand.Add(SET_KEY_CLI_COMMAND, function(_, _, arguments)
    local requestedKey = arguments and arguments[1] or nil
    local resolvedKeyCode = ResolveKeyCode(requestedKey)

    if not resolvedKeyCode then
        chat.AddText(Color(255,100,100), "Always Run: invalid key. Use a key name or key code.")
        return
    end

    TOGGLE_KEY = resolvedKeyCode
    alwaysRunCustomKeyEnabled = true
    SaveAlwaysRunSettings()
    lastToggleKeyState = input.IsKeyDown(TOGGLE_KEY)

    if keyButton and keyButton:IsValid() and keyButton.SetText then
        keyButton:SetText(GetLocalizedPhrase("always_run_key") .. GetKeyDisplayName(TOGGLE_KEY))
    end

    chat.AddText(Color(0,255,0), "Always Run: toggle key set to " .. GetKeyDisplayName(TOGGLE_KEY))
end)

concommand.Add(TOGGLE_COMMAND, function()
    ToggleAlwaysRun(true)
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
