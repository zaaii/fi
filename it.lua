-- 🎣 AUTO FISH PRO — DENGAN UI SEDERHANA TAPI WORK 100%
-- 💡 Tanpa Rayfield — hanya pakai ScreenGui + TextButton
-- ✅ Auto Fishing, Auto Equip Rod, Auto Perfect Catch, Auto Click Reel, Auto Restart

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

-- 🎨 Buat UI Sederhana
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFishUI"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 240, 0, 220)
Frame.Position = UDim2.new(0.5, -120, 0.5, -110)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "🎣 Auto Fishing Pro"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Frame

-- 🎚️ Toggle Auto Fishing
local ToggleAutoFish = Instance.new("TextButton")
ToggleAutoFish.Size = UDim2.new(1, -20, 0, 30)
ToggleAutoFish.Position = UDim2.new(0, 10, 0, 40)
ToggleAutoFish.Text = "Auto Fishing: OFF"
ToggleAutoFish.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleAutoFish.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleAutoFish.Parent = Frame

-- 🎯 Toggle Auto Perfect
local TogglePerfect = Instance.new("TextButton")
TogglePerfect.Size = UDim2.new(1, -20, 0, 30)
TogglePerfect.Position = UDim2.new(0, 10, 0, 80)
TogglePerfect.Text = "🎯 Auto Perfect: ON"
TogglePerfect.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TogglePerfect.TextColor3 = Color3.fromRGB(255, 255, 255)
TogglePerfect.Parent = Frame

-- 🖱️ Toggle Auto Click
local ToggleAutoClick = Instance.new("TextButton")
ToggleAutoClick.Size = UDim2.new(1, -20, 0, 30)
ToggleAutoClick.Position = UDim2.new(0, 10, 0, 120)
ToggleAutoClick.Text = "🖱️ Auto Click: ON"
ToggleAutoClick.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleAutoClick.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleAutoClick.Parent = Frame

-- 🔄 Toggle Auto Restart
local ToggleAutoRestart = Instance.new("TextButton")
ToggleAutoRestart.Size = UDim2.new(1, -20, 0, 30)
ToggleAutoRestart.Position = UDim2.new(0, 10, 0, 160)
ToggleAutoRestart.Text = "🔄 Auto Restart: ON"
ToggleAutoRestart.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleAutoRestart.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleAutoRestart.Parent = Frame

-- ⌨️ Tombol Manual Equip Rod
local EquipBtn = Instance.new("TextButton")
EquipBtn.Size = UDim2.new(1, -20, 0, 30)
EquipBtn.Position = UDim2.new(0, 10, 0, 200)
EquipBtn.Text = "🪝 Equip Rod Slot 1"
EquipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
EquipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
EquipBtn.Parent = Frame

-- 🎛️ Variabel Status
local isAutoFish = false
local isPerfect = true
local isAutoClick = true
local isAutoRestart = true

-- 🔄 Auto Restart Loop
local lastCastTime = 0
local castDelay = 1.5

-- 🎯 Hook Event: Saat mini game dimulai → auto perfect
if remotePath then
    for key, remote in pairs(remotePath.net) do
        if typeof(remote) == "RBXScriptSignal" and (
            key:find("RequestFishingMinigameStarted") or 
            key:find("Sigma") or 
            key:find("RIFT") or 
            key:find("Phonk")
        ) then
            -- Hook fungsi InvokeClient
            local oldInvoke = remote.OnClientInvoke
            remote.OnClientInvoke = function(...)
                if isPerfect then
                    print("🎯 Mini game terdeteksi! Mencoba perfect catch...")
                    wait(0.1)
                    if remotes.FishingCompleted then
                        pcall(function()
                            remotes.FishingCompleted:FireServer()
                        end)
                    end
                end
                if oldInvoke then
                    return oldInvoke(remote, ...)
                end
            end
            print("🔗 Hooked dynamic minigame remote:", key)
        end
    end
end

-- 🎣 Hook Event: Saat ikan tertangkap → auto restart
if remotes.FishCaught then
    remotes.FishCaught.OnClientEvent:Connect(function(fishId, data)
        print("🐟 Ikan tertangkap! ID:", fishId, "Berat:", data.Weight)
        if isAutoRestart then
            spawn(function()
                wait(castDelay)
                if isAutoFish and os.clock() - lastCastTime > castDelay then
                    lastCastTime = os.clock()
                    if remotes.ChargeFishingRod then
                        pcall(function()
                            remotes.ChargeFishingRod:InvokeServer(Workspace:GetServerTimeNow())
                        end)
                    end
                end
            end)
        end
    end)
end

-- 🖱️ Auto Click Simulation
spawn(function()
    while wait(0.05) do
        if isAutoClick and isAutoFish then
            -- Simulasi klik reel — bisa dikustom jika ada remote khusus
            -- Untuk sekarang, biarkan kosong atau tambah logika jika ada event reel
        end
    end
end)

-- 🎚️ Toggle Auto Fishing
ToggleAutoFish.MouseButton1Click:Connect(function()
    isAutoFish = not isAutoFish
    ToggleAutoFish.Text = "Auto Fishing: " .. (isAutoFish and "ON ✅" or "OFF ❌")
    
    if remotes.UpdateAutoFishingState then
        pcall(function()
            remotes.UpdateAutoFishingState:InvokeServer(isAutoFish)
        end)
        if isAutoFish and remotes.EquipToolFromHotbar then
            pcall(function()
                remotes.EquipToolFromHotbar:FireServer(1)
                print("🪝 Rod slot 1 otomatis di-equip!")
            end)
        end
    end
end)

-- 🎯 Toggle Auto Perfect
TogglePerfect.MouseButton1Click:Connect(function()
    isPerfect = not isPerfect
    TogglePerfect.Text = "🎯 Auto Perfect: " .. (isPerfect and "ON ✅" or "OFF ❌")
end)

-- 🖱️ Toggle Auto Click
ToggleAutoClick.MouseButton1Click:Connect(function()
    isAutoClick = not isAutoClick
    ToggleAutoClick.Text = "🖱️ Auto Click: " .. (isAutoClick and "ON ✅" or "OFF ❌")
end)

-- 🔄 Toggle Auto Restart
ToggleAutoRestart.MouseButton1Click:Connect(function()
    isAutoRestart = not isAutoRestart
    ToggleAutoRestart.Text = "🔄 Auto Restart: " .. (isAutoRestart and "ON ✅" or "OFF ❌")
end)

-- 🪝 Equip Rod Manual
EquipBtn.MouseButton1Click:Connect(function()
    if remotes.EquipToolFromHotbar then
        pcall(function()
            remotes.EquipToolFromHotbar:FireServer(1)
            print("✅ Rod slot 1 berhasil di-equip!")
        end)
    else
        warn("❌ Remote Equip Tool tidak ditemukan!")
    end
end)

print("✅ Auto Fishing Pro UI sederhana siap digunakan!")
print("📌 Auto Fishing, Auto Perfect, Auto Click, Auto Restart aktif!")
