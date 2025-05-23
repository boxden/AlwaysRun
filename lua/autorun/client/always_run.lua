local alwaysRunEnabled = CreateConVar("always_run_enabled", "1", {FCVAR_REPLICATED}, "Enable or disable always run")
local localization = include("always_run_localization.lua")
local saveFilePath = "always_run_settings.txt"
local DEFAULT_TOGGLE_KEY = KEY_CAPSLOCK
local TOGGLE_KEY = DEFAULT_TOGGLE_KEY
local alwaysRunToggled = true
local lastToggleKeyState = false
local alwaysRunMuteSound = false
local alwaysRunCustomKeyEnabled = false
local isCapturingKey = false

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
        "+speed",
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

local forbidden = GetForbiddenKeys()

local function GetLocalizedPhrase(key)
    local lang = GetConVar("gmod_language"):GetString()
    return (localization[lang] and localization[lang][key]) or localization["en"][key]
end

local function SaveAlwaysRunSettings()
    file.Write(saveFilePath, table.concat({
        alwaysRunToggled and "1" or "0",
        tostring(TOGGLE_KEY or DEFAULT_TOGGLE_KEY),
        alwaysRunMuteSound and "1" or "0",
        alwaysRunCustomKeyEnabled and "1" or "0"
    }, ":"))
end

local function LoadAlwaysRunSettings()
    if file.Exists(saveFilePath, "DATA") then
        local state, key, mute, custom = string.match(file.Read(saveFilePath, "DATA") or "", "^(%d):(%d+):?(%d?):?(%d?)$")
        alwaysRunToggled = (state == "1")
        TOGGLE_KEY = tonumber(key) or DEFAULT_TOGGLE_KEY
        alwaysRunMuteSound = (mute == "1")
        alwaysRunCustomKeyEnabled = (custom == "1")
    else
        alwaysRunToggled, TOGGLE_KEY, alwaysRunMuteSound, alwaysRunCustomKeyEnabled = true, DEFAULT_TOGGLE_KEY, false, false
        SaveAlwaysRunSettings()
    end
    RunConsoleCommand("always_run_enabled", alwaysRunToggled and "1" or "0")
    lastToggleKeyState = input.IsKeyDown(TOGGLE_KEY)
end

hook.Add("Think", "AlwaysRunToggleKey", function()
    if isCapturingKey then return end
    if not alwaysRunCustomKeyEnabled then lastToggleKeyState = false return end
    local keyDown = input.IsKeyDown(TOGGLE_KEY)
    if keyDown and not lastToggleKeyState then
        alwaysRunToggled = not alwaysRunToggled
        RunConsoleCommand("always_run_enabled", alwaysRunToggled and "1" or "0")
        SaveAlwaysRunSettings()
        if not alwaysRunMuteSound then
            surface.PlaySound(alwaysRunToggled and "buttons/button14.wav" or "buttons/button19.wav")
        end
    end
    lastToggleKeyState = keyDown
end)

hook.Add("CreateMove", "AlwaysRun", function(cmd)
    if not alwaysRunToggled then return end
    if LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP then return end
    if input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_LSHIFT) then
        cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_SPEED)))
    else
        cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))
    end
end)

hook.Add("PopulateToolMenu", "AlwaysRunSettings", function()
    spawnmenu.AddToolMenuOption("Utilities", GetLocalizedPhrase("utilities_server"), "AlwaysRunSettings", GetLocalizedPhrase("always_run_menu"), "", "", function(panel)
        panel:ClearControls()
        local checkbox = panel:CheckBox(GetLocalizedPhrase("always_run_enabled"), "always_run_enabled")
        checkbox:SetValue(alwaysRunToggled)
        checkbox.OnChange = function(_, value)
            alwaysRunToggled = value
            RunConsoleCommand("always_run_enabled", value and "1" or "0")
            SaveAlwaysRunSettings()
        end

        panel:Help(GetLocalizedPhrase("always_run_description"))
        panel:Help(GetLocalizedPhrase("always_run_capslock_hint"))

        local customKeyCheckbox = panel:CheckBox(GetLocalizedPhrase("always_run_custom_key_enable"), "always_run_custom_key_enable")
        customKeyCheckbox:SetValue(alwaysRunCustomKeyEnabled)
        customKeyCheckbox:DockMargin(0, 8, 0, 0)

        local keyButton = vgui.Create("DButton")
        keyButton:SetText("  " .. GetLocalizedPhrase("always_run_key") .. input.GetKeyName(TOGGLE_KEY))
        keyButton:SetTall(32)
        keyButton:SetTextColor(Color(255,255,255))
        keyButton:Dock(TOP)
        keyButton:DockMargin(0, 4, 0, 8)
        keyButton.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(36, 41, 46))
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(56, 61, 66, 180))
            end
        end
        keyButton.DoClick = function() RunConsoleCommand("always_run_set_key") end
        keyButton:SetToolTip(GetLocalizedPhrase("always_run_select_key_hint"))
        keyButton.PaintOver = function(self, w, h)
            surface.SetDrawColor(255,255,255,255)
            surface.SetMaterial(Material("icon16/keyboard.png"))
            surface.DrawTexturedRect(6, h/2-8, 16, 16)
        end
        _G.AlwaysRunKeyButton = keyButton
        panel:AddItem(keyButton)
        keyButton:SetVisible(alwaysRunCustomKeyEnabled)

        customKeyCheckbox.OnChange = function(_, value)
            alwaysRunCustomKeyEnabled = value
            keyButton:SetVisible(value)
            if not value then
                local savedKey = DEFAULT_TOGGLE_KEY
                if file.Exists(saveFilePath, "DATA") then
                    local _, key = string.match(file.Read(saveFilePath, "DATA") or "", "^(%d):(%d+):?(%d?):?(%d?)$")
                    savedKey = tonumber(key) or DEFAULT_TOGGLE_KEY
                end
                TOGGLE_KEY = savedKey
                if isCapturingKey then
                    isCapturingKey = false
                    hook.Remove("Think", "AlwaysRunKeyCapture")
                    if _G.AlwaysRunKeyButton and _G.AlwaysRunKeyButton.SetText then
                        _G.AlwaysRunKeyButton:SetText(GetLocalizedPhrase("always_run_key") .. input.GetKeyName(TOGGLE_KEY))
                    end
                    chat.AddText(Color(255,100,100), GetLocalizedPhrase("always_run_key_cancelled"))
                end
            end
            SaveAlwaysRunSettings()
        end

        local muteCheckbox = panel:CheckBox(GetLocalizedPhrase("always_run_mute_sound"))
        muteCheckbox:SetValue(alwaysRunMuteSound)
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
            surface.SetMaterial(Material("icon32/github.png"))
            surface.DrawTexturedRect(6, h/2-8, 16, 16)
        end
        panel:AddItem(githubButton)
    end)
end)

concommand.Add("always_run_set_key", function()
    if _G.AlwaysRunKeyButton and _G.AlwaysRunKeyButton.SetText then
        _G.AlwaysRunKeyButton:SetText(GetLocalizedPhrase("always_run_key") .. "...")
    end
    chat.AddText(Color(255,255,0), GetLocalizedPhrase("always_run_press_key_hint"))
    local pressed = {}
    for i = 1, 159 do if input.IsKeyDown(i) then pressed[i] = true end end
    isCapturingKey = true

    hook.Add("PreRender", "AlwaysRunBlockEscMenu", function()
        if isCapturingKey and input.IsKeyDown(KEY_ESCAPE) then
            gui.HideGameUI()
        end
    end)

    hook.Add("Think", "AlwaysRunKeyCapture", function()
        if input.IsKeyDown(KEY_ESCAPE) then
            if _G.AlwaysRunKeyButton and _G.AlwaysRunKeyButton.SetText then
                _G.AlwaysRunKeyButton:SetText(GetLocalizedPhrase("always_run_key") .. input.GetKeyName(TOGGLE_KEY))
            end
            chat.AddText(Color(255,100,100), "Отмена выбора клавиши.")
            isCapturingKey = false
            hook.Remove("Think", "AlwaysRunKeyCapture")
            hook.Remove("PreRender", "AlwaysRunBlockEscMenu")
            return
        end
        local forbidden = GetForbiddenKeys()
        for i = 1, 159 do
            if input.IsKeyDown(i) and not pressed[i] and not forbidden[i] then
                TOGGLE_KEY = i
                SaveAlwaysRunSettings()
                chat.AddText(Color(0,255,0), GetLocalizedPhrase("always_run_key_selected") .. input.GetKeyName(i))
                if _G.AlwaysRunKeyButton and _G.AlwaysRunKeyButton.SetText then
                    _G.AlwaysRunKeyButton:SetText(GetLocalizedPhrase("always_run_key") .. input.GetKeyName(i))
                end
                isCapturingKey = false
                lastToggleKeyState = input.IsKeyDown(TOGGLE_KEY)
                hook.Remove("Think", "AlwaysRunKeyCapture")
                hook.Remove("PreRender", "AlwaysRunBlockEscMenu")
                return
            end
        end
    end)
end)

hook.Add("Initialize", "AlwaysRunLoadSettings", LoadAlwaysRunSettings)
hook.Add("InitPostEntity", "AlwaysRunLoadSettingsPost", LoadAlwaysRunSettings)
hook.Add("OnGamemodeLoaded", "AlwaysRunEnsureConVar", function()
    local savedValue = GetConVar("always_run_enabled"):GetString()
    RunConsoleCommand("always_run_enabled", savedValue)
    alwaysRunToggled = alwaysRunEnabled:GetBool()
end)