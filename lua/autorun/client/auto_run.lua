hook.Add("InitPostEntity", "AutoRunScript", function()
    timer.Simple(1, function()
        LocalPlayer():ConCommand("+speed")
    end)
end)
-- Created 20.11.2023 04:20 | steamID64 76561198115550963