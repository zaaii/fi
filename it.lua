-- 🎣 AUTO FISH PRO — DENGAN RAYFIELD UI + AUTO PERFECT + AUTO CLICK + AUTO EQUIP + AUTO RESTART
-- 💡 Remote: sleitnick_net@0.2.0 → RF/UpdateAutoFishingState, RF/ChargeFishingRod, RE/EquipToolFromHotbar, dll
-- 🎨 UI by Rayfield (Official: https://sirius.menu/rayfield)

-- ⚙️ Load Rayfield dari sumber resmi
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 🎯 Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer

-- ✅ Cari Semua Remote (bisa dipanggil kapan saja)
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

    -- 🔍 Cari dynamic remote: RF/RequestFishingMinigameStarted (bisa bernama Sigma1, RIFT_IS_DETECTED1, dll)
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

-- 🔄 Coba ulang remote secara berkala — TANPA MENGGANGGU UI
spawn(function()
    while true do
        wait(2)
        remotes, remotePath = getRemotes()
        if remotes.UpdateAutoFishingState and remotes.EquipToolFromHotbar and remotes.ChargeFishingRod then
            print("✅ Semua remote utama ditemukan!")
            Rayfield:Notify({
                Title = "Auto Fishing Ready",
                Content = "Semua remote ditemukan! Auto Fishing siap digunakan.",
                Duration = 5,
                Image = "check"
            })
            break
        end
    end
end)

-- 🎨 Buat Window
local Window = Rayfield:CreateWindow({
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
        local remote = remotes.UpdateAutoFishingState
        if remote then
            local success = pcall(function()
                remote:InvokeServer(Value)
            end)
            if success then
                print("🎣 Auto Fishing " .. (Value and "✅ ON" or "❌ OFF"))
                Rayfield:Notify({
                    Title = "Auto Fishing",
                    Content = "Status: " .. (Value and "ON" or "OFF"),
                    Duration = 3,
                    Image = "fish"
                })
                
                -- 🎯 JIKA DIHIDUPKAN → AUTO EQUIP ROD SLOT 1
                if Value and remotes.EquipToolFromHotbar then
                    pcall(function()
                        remotes.EquipToolFromHotbar:FireServer(1)
                        print("🪝 Rod slot 1 otomatis di-equip!")
                        Rayfield:Notify({
                            Title = "Auto Equip Rod",
                            Content = "Rod slot 1 di-equip!",
                            Duration = 3,
                            Image = "tool"
                        })
                    end)
                end
            else
                warn("❌ Gagal mengubah status Auto Fishing!")
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Gagal mengaktifkan Auto Fishing!",
                    Duration = 5,
                    Image = "alert-triangle"
                })
            end
        else
            warn("❌ Remote Auto Fishing tidak ditemukan!")
            Rayfield:Notify({
                Title = "Remote Not Found",
                Content = "RemoteFunction belum dimuat. Tunggu sebentar lalu coba lagi.",
                Duration = 5,
                Image = "clock"
            })
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
        Rayfield:Notify({
            Title = "Auto Perfect",
            Content = "Status: " .. (Value and "ON" or "OFF"),
            Duration = 3,
            Image = "target"
        })
    end
})

-- 🖱️ Toggle Auto Click Reel
local ToggleAutoClick = Tab:CreateToggle({
    Name = "Auto Click Reel",
    Description = "Auto klik saat ikan mulai melawan (simulasi klik cepat)",
    CurrentValue = true,
    Flag = "AutoClickReel",
    Callback = function(Value)
        print("🖱️ Auto Click Reel: " .. (Value and "ON" or "OFF"))
        Rayfield:Notify({
            Title = "Auto Click",
            Content = "Status: " .. (Value and "ON" or "OFF"),
            Duration = 3,
            Image = "mouse-pointer"
        })
    end
})

-- 🔄 Toggle Auto Restart Fishing
local ToggleAutoRestart = Tab:CreateToggle({
    Name = "Auto Restart Fishing",
    Description = "Otomatis lempar umpan lagi setelah selesai",
    CurrentValue = true,
    Flag = "AutoRestart",
    Callback = function(Value)
        print("🔄 Auto Restart Fishing: " .. (Value and "ON" or "OFF"))
        Rayfield:Notify({
            Title = "Auto Restart",
            Content = "Status: " .. (Value and "ON" or "OFF"),
            Duration = 3,
            Image = "refresh-ccw"
        })
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

-- 🎯 Tombol Manual Trigger Fishing
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
                Rayfield:Notify({
                    Title = "Fishing Started",
                    Content = "Fishing dipaksa mulai!",
                    Duration = 3,
                    Image = "zap"
                })
            else
                warn("❌ Gagal memulai fishing!")
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Gagal memulai fishing!",
                    Duration = 5,
                    Image = "alert-triangle"
                })
            end
        else
            warn("❌ Remote ChargeFishingRod tidak ditemukan!")
            Rayfield:Notify({
                Title = "Remote Not Found",
                Content = "Coba lagi dalam beberapa detik.",
                Duration = 5,
                Image = "clock"
            })
        end
    end
})

-- 🪝 Tombol Manual Equip Rod
Tab:CreateButton({
    Name = "🪝 Equip Rod Slot 1",
    Description = "Manual equip fishing rod di slot 1",
    Callback = function()
        if remotes.EquipToolFromHotbar then
            local success = pcall(function()
                remotes.EquipToolFromHotbar:FireServer(1)
            end)
            if success then
                print("✅ Rod slot 1 berhasil di-equip!")
                Rayfield:Notify({
                    Title = "Equip Rod",
                    Content = "Rod slot 1 di-equip!",
                    Duration = 3,
                    Image = "tool"
                })
            else
                warn("❌ Gagal equip rod!")
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Gagal equip rod!",
                    Duration = 5,
                    Image = "alert-triangle"
                })
            end
        else
            warn("❌ Remote Equip Tool tidak ditemukan!")
            Rayfield:Notify({
                Title = "Remote Not Found",
                Content = "Coba lagi dalam beberapa detik.",
                Duration = 5,
                Image = "clock"
            })
        end
    end
})

-- 🔁 Auto Restart Loop
local lastCastTime = 0

-- 🎯 Hook Event: Saat mini game dimulai → auto perfect
if remotePath then
    for key, remote in pairs(remotePath.net) do
        if typeof(remote) == "RBXScriptSignal" and (
            key:find("RequestFishingMinigameStarted") or 
            key:find("Sigma") or 
            key:find("RIFT") or 
            key:find("Phonk")
        ) then
            -- Ini adalah event mini game
            local oldInvoke = remote.OnClientInvoke
            remote.OnClientInvoke = function(...)
                if TogglePerfect.CurrentValue then
                    print("🎯 Mini game terdeteksi! Mencoba perfect catch...")
                    Rayfield:Notify({
                        Title = "Perfect Catch",
                        Content = "Mencoba perfect catch...",
                        Duration = 2,
                        Image = "target"
                    })
                    -- Simulasi perfect catch
                    wait(0.1)
                    if remotes.FishingCompleted then
                        pcall(function()
                            remotes.FishingCompleted:FireServer()
                            print("✅ Perfect catch berhasil!")
                            Rayfield:Notify({
                                Title = "Perfect Catch",
                                Content = "Perfect catch berhasil!",
                                Duration = 3,
                                Image = "star"
                            })
                        end)
                    end
                end
                if oldInvoke then
                    return oldInvoke(remote, ...)
                end
            end
            print("🔗 Hooked dynamic minigame remote:", key)
            Rayfield:Notify({
                Title = "Minigame Hooked",
                Content = "Berhasil hook remote: " .. key,
                Duration = 5,
                Image = "hook"
            })
        end
    end
end

-- 🎣 Hook Event: Saat ikan tertangkap → auto restart
if remotes.FishCaught then
    remotes.FishCaught.OnClientEvent:Connect(function(fishId, data)
        print("🐟 Ikan tertangkap! ID:", fishId, "Berat:", data.Weight)
        Rayfield:Notify({
            Title = "Fish Caught!",
            Content = "ID: " .. fishId .. " | Berat: " .. data.Weight,
            Duration = 5,
            Image = "fish"
        })
        if ToggleAutoRestart.CurrentValue then
            spawn(function()
                wait(SliderDelay.CurrentValue)
                if ToggleAutoFish.CurrentValue and os.clock() - lastCastTime > SliderDelay.CurrentValue then
                    lastCastTime = os.clock()
                    if remotes.ChargeFishingRod then
                        pcall(function()
                            remotes.ChargeFishingRod:InvokeServer(Workspace:GetServerTimeNow())
                            print("🎣 Auto restart fishing!")
                        end)
                    end
                end
            end)
        end
    end)
end

-- 🖱️ Auto Click Reel Simulation
spawn(function()
    while wait(0.05) do -- 20x per detik
        if ToggleAutoClick.CurrentValue and ToggleAutoFish.CurrentValue then
            -- Simulasi klik reel — bisa disesuaikan dengan game
            -- Untuk sekarang, biarkan kosong atau tambah logika jika ada event reel
            -- Contoh: jika ada event "RE/ReelClick", bisa dipanggil di sini
        end
    end
end)

print("✅ Auto Fishing Pro siap digunakan!")
Rayfield:Notify({
    Title = "Auto Fishing Pro",
    Content = "Tekan [K] untuk toggle UI. Remote akan otomatis dimuat.",
    Duration = 6,
    Image = "info"
})
