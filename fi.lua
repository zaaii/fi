-- 🎣 AUTO FISH PRO (FIXED) — Rayfield + Safe Logging
-- Docs: https://docs.sirius.menu/rayfield

-- 1) Load Rayfield (resmi + fallback)
local Rayfield
do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    if not ok or not lib then
        ok, lib = pcall(function()
            return loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/source.lua'))()
        end)
    end
    if not ok or not lib then
        warn("❌ Rayfield gagal di-load.")
        return
    end
    Rayfield = lib
end

-- 2) Buat Window SEBELUM logika lain (agar UI pasti muncul)
local Window = Rayfield:CreateWindow({
    Name = "🎣 Auto Fishing Pro",
    Icon = "fish",                                 -- Lucide icon oke (docs)
    LoadingTitle = "Loading Auto Fish Pro...",
    LoadingSubtitle = "by Your Assistant",
    ShowText = "Toggle: [K]",                      -- teks tombol show utk mobile
    Theme = "Default",                             -- lihat daftar tema di docs
    ToggleUIKeybind = "K",                         -- sesuai docs
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoFishPro",
        FileName = "Settings"
    },
    Discord = { Enabled = false }
})

-- 3) Buat Tab/Section/Controls minimal lebih dulu (UI ready)
local Main = Window:CreateTab("Main", "fish")
Main:CreateSection("Auto Fishing")

-- State flags (Rayfield.Flags juga bisa, tapi kita simpan ref element)
local ToggleAutoFish, TogglePerfect, ToggleAutoClick, ToggleAutoRestart, SliderDelay

ToggleAutoFish = Main:CreateToggle({
    Name = "Enable Auto Fishing",
    Description = "Aktifkan sistem auto fishing",
    CurrentValue = false,
    Flag = "AutoFishToggle",
    Callback = function(val) end -- diisi setelah remotes siap
})

TogglePerfect = Main:CreateToggle({
    Name = "Auto Perfect Catch",
    Description = "Auto klik saat minigame muncul",
    CurrentValue = true,
    Flag = "AutoPerfect"
})

ToggleAutoClick = Main:CreateToggle({
    Name = "Auto Click Reel",
    Description = "Auto klik saat ikan melawan",
    CurrentValue = true,
    Flag = "AutoClickReel"
})

ToggleAutoRestart = Main:CreateToggle({
    Name = "Auto Restart Fishing",
    Description = "Otomatis lempar lagi setelah selesai",
    CurrentValue = true,
    Flag = "AutoRestart"
})

SliderDelay = Main:CreateSlider({
    Name = "Delay Between Casts (detik)",
    Description = "Jeda sebelum lempar umpan lagi",
    Range = {0.5, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "CastDelay"
})

Main:CreateButton({
    Name = "▶️ Force Start Fishing",
    Description = "Paksa mulai fishing sekarang",
    Callback = function() end -- diisi setelah remotes siap
})

Main:CreateButton({
    Name = "🪝 Equip Rod Slot 1",
    Description = "Manual equip fishing rod di slot 1",
    Callback = function() end -- diisi setelah remotes siap
})

-- Muat config yg tersimpan (kalau ada); aman dipanggil setelah elemen dibuat
pcall(function() Rayfield:LoadConfiguration() end)

-- 4) Services & pencarian remote (tidak blok UI)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local remotes = {}
local function findRemotes()
    local idx = ReplicatedStorage:FindFirstChild("Packages")
        and ReplicatedStorage.Packages:FindFirstChild("_Index")
    if not idx then return end

    local pack = idx:FindFirstChild("sleitnick_net@0.2.0")
    if not pack or not pack:FindFirstChild("net") then return end
    local net = pack.net

    remotes.UpdateAutoFishingState   = net:FindFirstChild("RF/UpdateAutoFishingState")
    remotes.EquipToolFromHotbar      = net:FindFirstChild("RE/EquipToolFromHotbar")
    remotes.ChargeFishingRod         = net:FindFirstChild("RF/ChargeFishingRod")
    remotes.FishingCompleted         = net:FindFirstChild("RE/FishingCompleted")
    remotes.FishCaught               = net:FindFirstChild("RE/FishCaught")
    remotes.UpdateChargeState        = net:FindFirstChild("RE/UpdateChargeState")
    remotes.BaitSpawned              = net:FindFirstChild("RE/BaitSpawned")
    remotes.ObtainedNewFishNotification = net:FindFirstChild("RE/ObtainedNewFishNotification")

    -- (Opsional) Cari RF minigame kalau developer game pakai nama custom
    for _, obj in ipairs(net:GetChildren()) do
        if obj:IsA("RemoteFunction") and obj.Name:lower():find("minigame") then
            remotes.RequestFishingMinigameStarted = obj
            break
        end
    end
end

-- jalankan awal + retry ringan
findRemotes()
task.spawn(function()
    local t0 = os.clock()
    while (not remotes.UpdateAutoFishingState or not remotes.EquipToolFromHotbar) and os.clock()-t0 < 15 do
        task.wait(1.5)
        findRemotes()
    end
end)

-- 5) Isi callback setelah remote ada (callback aman terhadap nil)
local function safeInvokeRF(rf, ...)
    if rf and rf:IsA("RemoteFunction") then
        local ok, res = pcall(function() return rf:InvokeServer(...) end)
        if not ok then warn("RF error:", res) end
        return ok, res
    end
    return false, "No RF"
end

local function safeFireRE(re, ...)
    if re and re:IsA("RemoteEvent") then
        local ok, err = pcall(function() re:FireServer(...) end)
        if not ok then warn("RE error:", err) end
        return ok
    end
    return false
end

-- Toggle Auto Fishing
ToggleAutoFish.Callback = function(Value)
    local ok = safeInvokeRF(remotes.UpdateAutoFishingState, Value)
    if ok and Value then
        safeFireRE(remotes.EquipToolFromHotbar, 1) -- equip rod slot 1
    end
end

-- Force Start
Main.Elements["▶️ Force Start Fishing"].Callback = function()
    safeInvokeRF(remotes.ChargeFishingRod, Workspace:GetServerTimeNow())
end

-- Equip slot 1
Main.Elements["🪝 Equip Rod Slot 1"].Callback = function()
    safeFireRE(remotes.EquipToolFromHotbar, 1)
end

-- Hook FishCaught -> Auto restart
task.spawn(function()
    -- tunggu RE tersedia
    local t0 = os.clock()
    while not remotes.FishCaught and os.clock()-t0 < 15 do
        task.wait(1)
    end
    if remotes.FishCaught and remotes.FishCaught:IsA("RemoteEvent") then
        remotes.FishCaught.OnClientEvent:Connect(function(fishId, data)
            if ToggleAutoRestart.CurrentValue and ToggleAutoFish.CurrentValue then
                task.delay(SliderDelay.CurrentValue, function()
                    safeInvokeRF(remotes.ChargeFishingRod, Workspace:GetServerTimeNow())
                end)
            end
        end)
    end
end)

-- (Opsional) Auto Perfect: kalau ada RF minigame yang dipanggil ke client
-- NOTE: tidak mencoba menimpa OnClientInvoke milik object non-RemoteFunction.
task.spawn(function()
    local t0 = os.clock()
    while not remotes.RequestFishingMinigameStarted and os.clock()-t0 < 10 do
        task.wait(1)
        findRemotes()
    end
    local rf = remotes.RequestFishingMinigameStarted
    if rf and rf:IsA("RemoteFunction") then
        -- Simpel: saat RF dipanggil server -> kita balas sukses cepat (simulasi perfect)
        local old = rf.OnClientInvoke
        rf.OnClientInvoke = function(...)
            if TogglePerfect.CurrentValue then
                -- Bila game dev mengharapkan nilai return tertentu, sesuaikan di sini
                -- Default: kembalikan apapun dari old atau true
                if old then
                    local ok, ret = pcall(old, ...)
                    if ok then return ret end
                end
                return true
            else
                if old then
                    local ok, ret = pcall(old, ...)
                    if ok then return ret end
                end
                return nil
            end
        end
    end
end)

-- Selesai
print("✅ Auto Fishing Pro loaded. Tekan [K] untuk toggle UI.")
