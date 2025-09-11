-- 🎣 AUTO FISH WITH RAYFIELD UI — OFFICIAL VERSION
-- 💡 Remote: sleitnick_net@0.2.0 → RF/UpdateAutoFishingState
-- 🎨 UI by Rayfield (Official: https://sirius.menu/rayfield)

-- ⚙️ Load Rayfield dari sumber resmi
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 🎯 Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- ✅ Cari RemoteFunction
local function getRemote()
    local remotePath = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
    if not remotePath then return nil end
    return remotePath.net and remotePath.net["RF/UpdateAutoFishingState"]
end

local RFUpdateAutoFishingState = getRemote()

-- 🎨 Buat Window
local Window = Rayfield:CreateWindow({
    Name = "🎣 Auto Fishing Manager",
    Icon = "fish", -- Lucide icon "fish" (bisa ganti jadi angka ID juga)
    LoadingTitle = "Loading Auto Fish...",
    LoadingSubtitle = "by Your Assistant",
    Theme = "Ocean", -- Bisa ganti: "Default", "AmberGlow", "DarkBlue", dll
    ToggleUIKeybind = "K", -- Tekan K untuk toggle UI
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoFish",
        FileName = "Settings"
    }
})

-- 📁 Tab Utama
local Tab = Window:CreateTab("Main", "fish") -- Icon Lucide "fish"

-- 🧭 Section Controls
Tab:CreateSection("Auto Fishing Controls")

-- 🎚️ Toggle Auto Fishing
local Toggle = Tab:CreateToggle({
    Name = "Enable Auto Fishing",
    Description = "Toggle auto fishing ON/OFF",
    CurrentValue = false,
    Flag = "AutoFishToggle",
    Callback = function(Value)
        if RFUpdateAutoFishingState then
            local success = pcall(function()
                RFUpdateAutoFishingState:InvokeServer(Value)
            end)
            if success then
                print("🎣 Auto Fishing " .. (Value and "✅ ON" or "❌ OFF"))
            else
                warn("❌ Gagal mengubah status Auto Fishing!")
            end
        else
            warn("❌ Remote tidak ditemukan! Auto Fishing tidak bisa diaktifkan.")
        end
    end
})

-- 🔄 Slider Auto Refresh (detik)
local Slider = Tab:CreateSlider({
    Name = "Auto Refresh Delay",
    Description = "Jaga agar Auto Fishing tetap aktif (detik)",
    Range = {0, 30},
    Increment = 1,
    Suffix = "s",
    CurrentValue = 5,
    Flag = "RefreshDelay",
    Callback = function(Value)
        -- Hentikan loop lama
        if _G.AutoFishLoop then
            _G.AutoFishLoop:Disconnect()
            _G.AutoFishLoop = nil
        end

        if Value > 0 and Toggle.CurrentValue then
            _G.AutoFishLoop = game:GetService("RunService").Heartbeat:Connect(function()
                if tick() - (_G.LastAutoFish or 0) >= Value then
                    _G.LastAutoFish = tick()
                    if RFUpdateAutoFishingState then
                        pcall(function()
                            RFUpdateAutoFishingState:InvokeServer(true)
                        end)
                    end
                end
            end)
        end
    end
})

-- 🎯 Tombol Manual Trigger
Tab:CreateButton({
    Name = "▶️ Force Enable Now",
    Description = "Paksa aktifkan Auto Fishing sekarang",
    Callback = function()
        if RFUpdateAutoFishingState then
            local success = pcall(function()
                RFUpdateAutoFishingState:InvokeServer(true)
            end)
            if success then
                print("✅ Auto Fishing dipaksa aktif!")
            else
                warn("❌ Gagal memaksa Auto Fishing!")
            end
        else
            warn("❌ Remote tidak ditemukan!")
        end
    end
})

-- 🔁 Auto Refresh Loop (default 5 detik)
_G.AutoFishLoop = nil
_G.LastAutoFish = 0
Slider:SetValue(5)

-- 🔄 Cek ulang remote jika belum ada (anti error saat load lambat)
spawn(function()
    while not RFUpdateAutoFishingState do
        wait(2)
        RFUpdateAutoFishingState = getRemote()
        if RFUpdateAutoFishingState then
            print("✅ Remote Auto Fishing ditemukan!")
            break
        end
    end
end)

-- 🧹 Cleanup saat window ditutup
Window:OnClose(function()
    if _G.AutoFishLoop then
        _G.AutoFishLoop:Disconnect()
        _G.AutoFishLoop = nil
    end
end)

print("✅ Auto Fishing UI siap! Tekan [K] untuk toggle UI, lalu aktifkan Auto Fishing.")
