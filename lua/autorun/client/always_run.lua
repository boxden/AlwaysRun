-- Создаём переменную для хранения состояния постоянного бега
local alwaysRunEnabled = CreateConVar("always_run_enabled", "1", {FCVAR_REPLICATED}, "Enable or disable always run")

-- Таблица локализации
local localization = include("always_run_localization.lua")

-- Путь к файлу для сохранения состояния
local saveFilePath = "always_run_settings.txt"

-- Функция для получения перевода
local function GetLocalizedPhrase(key)
    local lang = GetConVar("gmod_language"):GetString()
    return localization[lang] and localization[lang][key] or localization["en"][key]
end

-- Функция для сохранения состояния в файл
local function SaveAlwaysRunState()
    local state = alwaysRunEnabled:GetBool() and "1" or "0"
    file.Write(saveFilePath, state)
end

-- Функция для загрузки состояния из файла
local function LoadAlwaysRunState()
    if file.Exists(saveFilePath, "DATA") then
        local state = file.Read(saveFilePath, "DATA")
        RunConsoleCommand("always_run_enabled", state)
    else
        SaveAlwaysRunState() -- Сохраняем текущее значение, если файл отсутствует
    end
end

-- Функция для обновления меню настроек
local function RefreshToolMenu()
    spawnmenu.ClearToolMenus() -- Очищаем меню
    hook.Run("AddToolMenuTabs") -- Пересоздаём вкладки
    hook.Run("AddToolMenuCategories") -- Пересоздаём категории
    hook.Run("PopulateToolMenu") -- Пересоздаём пункты меню
end

-- Отслеживаем изменения языка
hook.Add("Think", "AlwaysRunLanguageUpdate", function()
    local newLanguage = GetConVar("gmod_language"):GetString()
    if newLanguage ~= currentLanguage then
        currentLanguage = newLanguage
        RefreshToolMenu() -- Обновляем меню настроек
    end
end)

-- Хук для управления постоянным бегом
hook.Add("CreateMove", "AlwaysRun", function(cmd)
    if not LocalPlayer():IsValid() then return end

    -- Проверяем, включён ли постоянный бег
    if not alwaysRunEnabled:GetBool() then return end

    -- Проверяем, находится ли игрок в режиме noclip
    if LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP then return end

    -- Проверяем, зажаты ли клавиши Alt или Shift
    if input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_LSHIFT) then
        cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_SPEED))) -- Отключаем бег
    else
        cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED)) -- Включаем бег
    end
end)

-- Добавляем опцию в меню настроек
hook.Add("PopulateToolMenu", "AlwaysRunSettings", function()
    spawnmenu.AddToolMenuOption("Utilities", GetLocalizedPhrase("utilities_server"), "AlwaysRunSettings", GetLocalizedPhrase("always_run_menu"), "", "", function(panel)
        panel:ClearControls()

        -- Чекбокс для включения/выключения постоянного бега
        local checkbox = panel:CheckBox(GetLocalizedPhrase("always_run_enabled"), "always_run_enabled")

        -- Обработчик изменения состояния чекбокса
        checkbox.OnChange = function(_, value)
            RunConsoleCommand("always_run_enabled", value and "1" or "0") -- Обновляем значение ConVar
            SaveAlwaysRunState() -- Сохраняем состояние
        end

        -- Описание под чекбоксом
        panel:Help(GetLocalizedPhrase("always_run_description"))
    end)
end)

-- Загружаем состояние при инициализации
hook.Add("Initialize", "AlwaysRunLoadState", LoadAlwaysRunState)

-- Убедимся, что значение ConVar не сбрасывается
hook.Add("OnGamemodeLoaded", "AlwaysRunEnsureConVar", function()
    -- Принудительно загружаем сохранённое значение из config.cfg
    local savedValue = GetConVar("always_run_enabled"):GetString()
    RunConsoleCommand("always_run_enabled", savedValue)
end)

-- Created 20.11.2023 04:20 (UTC+2) | steamID64 76561198115550963
-- Updated 12.05.2025 07:20 (UTC+3) | steamID64 76561198115550963