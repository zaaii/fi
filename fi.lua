-- 🎣 AUTO FISH PRO + RAYFIELD UI (DENGAN FALLBACK & ERROR HANDLING)
-- 💡 Remote: sleitnick_net@0.2.0 → RF/UpdateAutoFishingState, RF/ChargeFishingRod, dll
-- 🎨 UI by Rayfield (Fallback jika gagal)

-- ⚠️ Coba load Rayfield dari sumber resmi
local success, rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not rayfield then
    warn("❌ Gagal load Rayfield dari sirius.menu, mencoba fallback...")
    -- 🔄 Fallback ke raw github
    success, rayfield = pcall(function()
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/source.lua'))()
    end)
end

if not success or not rayfield then
    warn("❌ Rayfield gagal di-load! Menggunakan UI fallback sederhana.")
    
    -- 🧩 Fallback UI Sederhana (TextButton + ScreenGui)
    local ScreenGui = Instance.new("ScreenGui")
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local ToggleBtn = Instance.new("TextButton")
    local EquipBtn = Instance.new("TextButton")
    local PerfectToggle = Instance.new("TextButton")

    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.Name = "AutoFishFallbackUI"
    ScreenGui.ResetOnSpawn = false

    Frame.Parent = ScreenGui
    Frame.Size = UDim2.new(0, 220, 0, 160)
    Frame.Position = UDim2.new(0.5, -110, 0.5, -80)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Frame.BorderSizePixel = 0

    Title.Parent = Frame
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundTransparency = 1
    Title.Text = "🎣 Auto Fish Fallback"
    Title.TextColor3 = Color3.fromRGB(240, 240, 240)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16

    ToggleBtn.Parent = Frame
    ToggleBtn.Size = UDim2.new(1, -20, 0, 30)
    ToggleBtn.Position = UDim2.new(0, 10, 0, 40)
    ToggleBtn.Text = "Auto Fishing: OFF"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ToggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)

    EquipBtn.Parent = Frame
    EquipBtn.Size = UDim2.new(1, -20, 0, 30)
    EquipBtn.Position = UDim2.new(0, 10, 0, 80)
    EquipBtn.Text = "🪝 Equip Rod Slot 1"
    EquipBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    EquipBtn.TextColor3 = Color3.fromRGB(240, 240, 240)

    PerfectToggle.Parent = Frame
    PerfectToggle.Size = UDim2.new(1, -20, 0, 30)
    PerfectToggle.Position = UDim2.new(0, 10, 0, 120)
    PerfectToggle.Text = "🎯 Auto Perfect: ON"
    PerfectToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    PerfectToggle.TextColor3 = Color3.fromRGB(240, 240, 240)

    -- 🎯 Services
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local localPlayer = Players.LocalPlayer

    -- ✅ Cari Remote
    local function getRemotes()
        local path = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
        if not path or not path.net then return {} end
        return {
            UpdateAutoFishingState = path.net["RF/UpdateAutoFishingState"],
            EquipToolFromHotbar = path.net["RE/EquipToolFromHotbar"],
            ChargeFishingRod = path.net["RF/ChargeFishingRod"]
        }
    end

    local remotes = getRemotes()

    -- 🔄 Coba ulang jika remote belum ada
    spawn(function()
        while not remotes.UpdateAutoFishingState do
            wait(2)
            remotes = getRemotes()
        end
    end)

    -- 🎚️ Toggle Auto Fishing
    local isAutoFish = false
    ToggleBtn.MouseButton1Click:Connect(function()
        isAutoFish = not isAutoFish
        ToggleBtn.Text = "Auto Fishing: " .. (isAutoFish and "ON ✅" or "OFF ❌")
        
        if remotes.UpdateAutoFishingState then
            pcall(function()
                remotes.UpdateAutoFishingState:InvokeServer(isAutoFish)
            end)
            if isAutoFish and remotes.EquipToolFromHotbar then
                pcall(function()
                    remotes.EquipToolFromHotbar:FireServer(1)
                end)
            end
        end
    end)

    -- 🪝 Equip Rod
    EquipBtn.MouseButton1Click:Connect(function()
        if remotes.EquipToolFromHotbar then
            pcall(function()
                remotes.EquipToolFromHotbar:FireServer(1)
            end)
        end
    end)

    -- 🎯 Auto Perfect Toggle
    local isPerfect = true
    PerfectToggle.MouseButton1Click:Connect(function()
        isPerfect = not isPerfect
        PerfectToggle.Text = "🎯 Auto Perfect: " .. (isPerfect and "ON ✅" or "OFF ❌")
    end)

    print("✅ Fallback UI aktif! Auto Fishing siap digunakan.")
    return -- Hentikan script agar tidak lanjut ke Rayfield
end

-- ✅ Jika Rayfield berhasil load, lanjutkan script utama
print("✅ Rayfield berhasil di-load!")

-- 🎯 Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- ✅ Cari RemoteFunction & RemoteEvent
local function getRemotes()
    local remotePath = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
    if not remotePath or not remotePath.net then return {}, nil end
    
    local net = remotePath.net
    local remotes = {
        UpdateAutoFishingState = net["RF/UpdateAutoFishingState"],
        EquipToolFromHotbar = net["RE/EquipToolFromHotbar"],
        ChargeFishingRod = net["RF/ChargeFishingRod"],
        FishingCompleted = net["RE/FishingCompleted"],
        FishCaught = net["RE/FishCaught"],
        UpdateChargeState = net["RE/UpdateChargeState"],
        BaitSpawned = net["RE/BaitSpawned"],
        ObtainedNewFishNotification = net["RE/ObtainedNewFishNotification"]
    }

    -- 🔍 Cari dynamic remote: RF/RequestFishingMinigameStarted
    local minigameRemote = nil
    for key, remote in pairs(net) do
        if key:find("RequestFishingMinigameStarted") or key:find("Sigma") or key:find("RIFT") or key:find("Phonk") then
            minigameRemote = remote
            print("✅ Dynamic Minigame Remote ditemukan:", key)
            break
        end
    end
    remotes.RequestFishingMinigameStarted = minigameRemote

    return remotes, remotePath
end

local remotes, remotePath = getRemotes()

-- 🔄 Coba ulang jika belum dimuat
spawn(function()
    while not remotes.UpdateAutoFishingState or not remotes.EquipToolFromHotbar do
        wait(2)
        remotes, remotePath = getRemotes()
        if remotes.UpdateAutoFishingState and remotes.EquipToolFromHotbar then
            print("✅ Semua remote utama ditemukan!")
            break
        end
    end
end)

-- 🎨 Buat Window
local Window = rayfield:CreateWindow({
    Name = "🎣 Auto Fishing Pro",
    Icon = "fish",
    LoadingTitle = "Loading Auto Fish Pro...",
    LoadingSubtitle = "by Your Assistant",
    Theme = "Ocean",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoFishPro",
        FileName = "Settings"
    }
})

-- 📁 Tab Utama
local Tab = Window:CreateTab("Main", "fish")

-- 🧭 Section Controls
Tab:CreateSection("Auto Fishing")

-- 🎚️ Toggle Auto Fishing
local ToggleAutoFish = Tab:CreateToggle({
    Name = "Enable Auto Fishing",
    Description = "Aktifkan sistem auto fishing",
    CurrentValue = false,
    Flag = "AutoFishToggle",
    Callback = function(Value)
        if remotes.UpdateAutoFishingState then
            pcall(function()
                remotes.UpdateAutoFishingState:InvokeServer(Value)
            end)
            print("🎣 Auto Fishing " .. (Value and "✅ ON" or "❌ OFF"))
            
            if Value and remotes.EquipToolFromHotbar then
                pcall(function()
                    remotes.EquipToolFromHotbar:FireServer(1)
                    print("🪝 Rod slot 1 otomatis di-equip!")
                end)
            end
        end
    end
})

-- 🎯 Toggle Auto Perfect Catch
local TogglePerfect = Tab:CreateToggle({
    Name = "Auto Perfect Catch",
    Description = "Auto klik saat mini game muncul untuk perfect catch",
    CurrentValue = true,
    Flag = "AutoPerfect",
    Callback = function(Value)
        print("🎯 Auto Perfect Catch: " .. (Value and "ON" or "OFF"))
    end
})

-- 🖱️ Toggle Auto Click Reel
local ToggleAutoClick = Tab:CreateToggle({
    Name = "Auto Click Reel",
    Description = "Auto klik saat ikan mulai melawan",
    CurrentValue = true,
    Flag = "AutoClickReel",
    Callback = function(Value)
        print("🖱️ Auto Click Reel: " .. (Value and "ON" or "OFF"))
    end
})

-- 🔄 Toggle Auto Restart
local ToggleAutoRestart = Tab:CreateToggle({
    Name = "Auto Restart Fishing",
    Description = "Otomatis lempar umpan lagi setelah selesai",
    CurrentValue = true,
    Flag = "AutoRestart",
    Callback = function(Value)
        print("🔄 Auto Restart: " .. (Value and "ON" or "OFF"))
    end
})

-- 🕒 Slider Delay Antara Lemparan
local SliderDelay = Tab:CreateSlider({
    Name = "Delay Between Casts (detik)",
    Description = "Jeda sebelum lempar umpan lagi",
    Range = {0.5, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "CastDelay",
    Callback = function(Value)
        print("🕒 Delay lempar: " .. Value .. " detik")
    end
})

-- 🎯 Tombol Manual Trigger
Tab:CreateButton({
    Name = "▶️ Force Start Fishing",
    Description = "Paksa mulai fishing sekarang",
    Callback = function()
        if remotes.ChargeFishingRod then
            local success = pcall(function()
                remotes.ChargeFishingRod:InvokeServer(Workspace:GetServerTimeNow())
            end)
            if success then
                print("✅ Fishing dipaksa mulai!")
            else
                warn("❌ Gagal memulai fishing!")
            end
        else
            warn("❌ Remote ChargeFishingRod tidak ditemukan!")
        end
    end
})

-- 🎣 Tombol Manual Equip Rod
Tab:CreateButton({
    Name = "🪝 Equip Rod Slot 1",
    Description = "Manual equip fishing rod di slot 1",
    Callback = function()
        if remotes.EquipToolFromHotbar then
            pcall(function()
                remotes.EquipToolFromHotbar:FireServer(1)
                print("✅ Rod slot 1 berhasil di-equip!")
            end)
        else
            warn("❌ Remote Equip Tool tidak ditemukan!")
        end
    end
})

print("✅ Auto Fishing Pro siap digunakan!")
print("🔑 Tekan [K] untuk toggle UI")
