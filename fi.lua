-- 🎣 AUTO FISH PRO + RAYFIELD + DEBUG LOGGING — UNTUK ANALISIS ERROR
-- 💡 Remote: sleitnick_net@0.2.0 → RF/UpdateAutoFishingState, RF/ChargeFishingRod, dll
-- 🎨 UI by Rayfield (Official: https://sirius.menu/rayfield)

warn("✅ Script dimulai...")

-- ⚙️ Load Rayfield dari sumber resmi + fallback
local success, rayfield = pcall(function()
    warn("📥 Mencoba load Rayfield dari sirius.menu...")
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not rayfield then
    warn("❌ Gagal load dari sirius.menu, mencoba fallback...")
    success, rayfield = pcall(function()
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/Build.lua'))()
    end)
end

if not success or not rayfield then
    warn("❌ Rayfield gagal di-load! Menggunakan UI fallback sederhana.")
    
    -- 🧩 Fallback UI Sederhana (TextButton + ScreenGui)
    local ScreenGui = Instance.new("ScreenGui")
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local ToggleBtn = Instance.new("TextButton")

    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.Name = "AutoFishFallbackUI"
    ScreenGui.ResetOnSpawn = false

    Frame.Parent = ScreenGui
    Frame.Size = UDim2.new(0, 220, 0, 100)
    Frame.Position = UDim2.new(0.5, -110, 0.5, -50)
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
    ToggleBtn.Position = UDim2.new(0, 10, 0, 50)
    ToggleBtn.Text = "Auto Fishing: OFF"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ToggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)

    warn("✅ Fallback UI dibuat!")

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

    warn("✅ Fallback UI aktif! Auto Fishing siap digunakan.")
    return -- Hentikan script agar tidak lanjut ke Rayfield
end

warn("✅ Rayfield berhasil di-load!")

-- 🎯 Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- ✅ Cari RemoteFunction & RemoteEvent
local function getRemotes()
    warn("🔍 Mencari remote...")
    local remotePath = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
    if not remotePath then
        warn("❌ remotePath tidak ditemukan!")
        return {}, nil
    end
    if not remotePath.net then
        warn("❌ remotePath.net tidak ditemukan!")
        return {}, nil
    end
    
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
            warn("✅ Dynamic Minigame Remote ditemukan:", key)
            break
        end
    end
    remotes.RequestFishingMinigameStarted = minigameRemote

    warn("✅ Semua remote dicari!")
    return remotes, remotePath
end

local remotes, remotePath = getRemotes()

-- 🔄 Coba ulang jika belum dimuat
spawn(function()
    while not remotes.UpdateAutoFishingState or not remotes.EquipToolFromHotbar do
        wait(2)
        remotes, remotePath = getRemotes()
        if remotes.UpdateAutoFishingState and remotes.EquipToolFromHotbar then
            warn("✅ Semua remote utama ditemukan!")
            break
        end
    end
end)

-- 🎨 Buat Window
warn("🎨 Membuat window...")
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

warn("✅ Window dibuat!")

-- 📁 Tab Utama
local Tab = Window:CreateTab("Main", "fish")
warn("✅ Tab dibuat!")

-- 🧭 Section Controls
Tab:CreateSection("Auto Fishing")
warn("✅ Section dibuat!")

-- 🎚️ Toggle Auto Fishing
local ToggleAutoFish = Tab:CreateToggle({
    Name = "Enable Auto Fishing",
    Description = "Aktifkan sistem auto fishing",
    CurrentValue = false,
    Flag = "AutoFishToggle",
    Callback = function(Value)
        warn("🎣 Toggle Auto Fishing:", Value)
        local remote = remotes.UpdateAutoFishingState
        if remote then
            local success = pcall(function()
                remote:InvokeServer(Value)
            end)
            if success then
                warn("✅ Auto Fishing " .. (Value and "ON" or "OFF"))
                if Value and remotes.EquipToolFromHotbar then
                    pcall(function()
                        remotes.EquipToolFromHotbar:FireServer(1)
                        warn("🪝 Rod slot 1 otomatis di-equip!")
                    end)
                end
            else
                warn("❌ Gagal mengubah status Auto Fishing!")
            end
        else
            warn("❌ Remote Auto Fishing tidak ditemukan!")
        end
    end
})

warn("✅ Toggle Auto Fishing dibuat!")

-- 🎯 Toggle Auto Perfect Catch
local TogglePerfect = Tab:CreateToggle({
    Name = "Auto Perfect Catch",
    Description = "Auto klik saat mini game muncul untuk perfect catch",
    CurrentValue = true,
    Flag = "AutoPerfect",
    Callback = function(Value)
        warn("🎯 Auto Perfect Catch:", Value)
    end
})

warn("✅ Toggle Auto Perfect dibuat!")

-- 🖱️ Toggle Auto Click Reel
local ToggleAutoClick = Tab:CreateToggle({
    Name = "Auto Click Reel",
    Description = "Auto klik saat ikan mulai melawan",
    CurrentValue = true,
    Flag = "AutoClickReel",
    Callback = function(Value)
        warn("🖱️ Auto Click Reel:", Value)
    end
})

warn("✅ Toggle Auto Click dibuat!")

-- 🔄 Toggle Auto Restart
local ToggleAutoRestart = Tab:CreateToggle({
    Name = "Auto Restart Fishing",
    Description = "Otomatis lempar umpan lagi setelah selesai",
    CurrentValue = true,
    Flag = "AutoRestart",
    Callback = function(Value)
        warn("🔄 Auto Restart Fishing:", Value)
    end
})

warn("✅ Toggle Auto Restart dibuat!")

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
        warn("🕒 Delay lempar:", Value)
    end
})

warn("✅ Slider Delay dibuat!")

-- 🎯 Tombol Manual Trigger
Tab:CreateButton({
    Name = "▶️ Force Start Fishing",
    Description = "Paksa mulai fishing sekarang",
    Callback = function()
        warn("▶️ Force Start Fishing ditekan!")
        if remotes.ChargeFishingRod then
            local success = pcall(function()
                remotes.ChargeFishingRod:InvokeServer(Workspace:GetServerTimeNow())
            end)
            if success then
                warn("✅ Fishing dipaksa mulai!")
            else
                warn("❌ Gagal memulai fishing!")
            end
        else
            warn("❌ Remote ChargeFishingRod tidak ditemukan!")
        end
    end
})

warn("✅ Tombol Force Start dibuat!")

-- 🪝 Tombol Manual Equip Rod
Tab:CreateButton({
    Name = "🪝 Equip Rod Slot 1",
    Description = "Manual equip fishing rod di slot 1",
    Callback = function()
        warn("🪝 Equip Rod ditekan!")
        if remotes.EquipToolFromHotbar then
            pcall(function()
                remotes.EquipToolFromHotbar:FireServer(1)
                warn("✅ Rod slot 1 berhasil di-equip!")
            end)
        else
            warn("❌ Remote Equip Tool tidak ditemukan!")
        end
    end
})

warn("✅ Tombol Equip Rod dibuat!")

-- 🎯 Hook Event: Saat mini game dimulai → auto perfect
if remotePath and remotePath.net then
    for key, remote in pairs(remotePath.net) do
        if typeof(remote) == "RBXScriptSignal" and (
            key:find("RequestFishingMinigameStarted") or 
            key:find("Sigma") or 
            key:find("RIFT") or 
            key:find("Phonk")
        ) then
            warn("🔗 Hooking dynamic minigame remote:", key)
            local oldInvoke = remote.OnClientInvoke
            remote.OnClientInvoke = function(...)
                if TogglePerfect.CurrentValue then
                    warn("🎯 Mini game terdeteksi! Mencoba perfect catch...")
                    wait(0.1)
                    if remotes.FishingCompleted then
                        pcall(function()
                            remotes.FishingCompleted:FireServer()
                            warn("✅ Perfect catch berhasil!")
                        end)
                    end
                end
                if oldInvoke then
                    return oldInvoke(remote, ...)
                end
            end
            warn("✅ Berhasil hook dynamic minigame remote:", key)
        end
    end
else
    warn("❌ remotePath.net tidak tersedia untuk hook!")
end

warn("✅ Semua hook dipasang!")

-- 🎣 Hook Event: Saat ikan tertangkap → auto restart
if remotes.FishCaught then
    remotes.FishCaught.OnClientEvent:Connect(function(fishId, data)
        warn("🐟 Ikan tertangkap! ID:", fishId, "Berat:", data.Weight)
        if ToggleAutoRestart.CurrentValue then
            spawn(function()
                wait(SliderDelay.CurrentValue)
                if ToggleAutoFish.CurrentValue then
                    if remotes.ChargeFishingRod then
                        pcall(function()
                            remotes.ChargeFishingRod:InvokeServer(Workspace:GetServerTimeNow())
                        end)
                    end
                end
            end)
        end
    end)
    warn("✅ Hook FishCaught dipasang!")
else
    warn("❌ Remote FishCaught tidak ditemukan!")
end

warn("🎉 Script selesai di-load! UI seharusnya muncul.")
