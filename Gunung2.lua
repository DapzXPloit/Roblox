-- =========================
-- Marker Saver - DapzXPloit (Final Full)
-- Features:
--  - Per-map persistent files (MarkerSaver/<PlaceId>/)
--  - Auto-load last file per map
--  - Save / Load / Delete / Merge / Overwrite confirm
--  - UI (Rayfield) with Checkpoint list: TP / EDIT / DEL
--  - Auto loop / once / respawn / delay / quick save
-- =========================

-- === Configuration ===
local webhookURL = "" -- optional: isi jika mau webhook
local SAVE_ROOT = "MarkerSaver" -- root folder in executor filesystem

-- === Services / env ===
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer

local placeId = tostring(game.PlaceId or 0)
local SaveFolder = SAVE_ROOT .. "/" .. placeId

-- === Executor capability detection ===
local can_writefile   = type(writefile) == "function"
local can_readfile    = type(readfile) == "function"
local can_isfolder    = type(isfolder) == "function"
local can_makefolder  = type(makefolder) == "function"
local can_listfiles   = type(listfiles) == "function"
local can_isfile      = type(isfile) == "function"
local can_delfile     = type(delfile) == "function" or type(deletefile) == "function"

-- helper to call appropriate delete
local function delete_file(path)
    if can_delfile then
        if type(delfile) == "function" then
            pcall(function() delfile(path) end)
        elseif type(deletefile) == "function" then
            pcall(function() deletefile(path) end)
        end
    else
        -- fallback: overwrite with empty
        pcall(function() writefile(path, "") end)
    end
end

-- ensure folder
local function ensure_save_folder()
    if can_isfolder and can_makefolder then
        if not isfolder(SAVE_ROOT) then
            pcall(function() makefolder(SAVE_ROOT) end)
        end
        if not isfolder(SaveFolder) then
            pcall(function() makefolder(SaveFolder) end)
        end
    else
        -- if no folder apis, we still use filenames with prefix SaveFolder/
        -- no action needed
    end
end

-- sanitize filename
local function sanitize_name(name)
    name = tostring(name or "")
    name = name:match("^%s*(.-)%s*$") -- trim
    name = name:gsub("[/\\:%%%*%?%\"<>|]", "") -- remove invalid chars
    name = name:gsub("%s+", "_")
    if name == "" then name = "file" end
    return name
end

-- filepath for name
local function filepath(name)
    return SaveFolder .. "/" .. sanitize_name(name) .. ".json"
end

-- serialize checkpoints to JSON (Vector3 -> {X,Y,Z})
local function serialize_checkpoints(tbl)
    local out = {}
    for i, cp in ipairs(tbl) do
        local pos = cp.Pos
        local posobj = nil
        if typeof(pos) == "Vector3" then
            posobj = {X = tonumber(string.format("%.4f", pos.X)), Y = tonumber(string.format("%.4f", pos.Y)), Z = tonumber(string.format("%.4f", pos.Z))}
        elseif type(pos) == "table" and pos.X and pos.Y and pos.Z then
            posobj = {X = pos.X, Y = pos.Y, Z = pos.Z}
        elseif type(pos) == "table" and #pos == 3 then
            posobj = {X = pos[1], Y = pos[2], Z = pos[3]}
        else
            posobj = {X = 0, Y = 0, Z = 0}
        end
        table.insert(out, {Name = tostring(cp.Name or ("CP_"..i)), Pos = posobj})
    end
    return HttpService:JSONEncode({Name = "MarkerFile", Checkpoints = out})
end

-- deserialize JSON -> checkpoints table with Vector3
local function deserialize_checkpoints(jsonstr)
    local ok, dec = pcall(function() return HttpService:JSONDecode(jsonstr) end)
    if not ok or type(dec) ~= "table" then return nil, "Invalid JSON" end
    local cps = {}
    if dec.Checkpoints and type(dec.Checkpoints) == "table" then
        for i, cp in ipairs(dec.Checkpoints) do
            local nm = cp.Name or ("Checkpoint "..tostring(i))
            local pos = cp.Pos
            if type(pos) == "table" and pos.X and pos.Y and pos.Z then
                table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(tonumber(pos.X) or 0, tonumber(pos.Y) or 0, tonumber(pos.Z) or 0)})
            elseif type(pos) == "table" and #pos >= 3 then
                table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(tonumber(pos[1]) or 0, tonumber(pos[2]) or 0, tonumber(pos[3]) or 0)})
            else
                table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(0,0,0)})
            end
        end
        return cps
    else
        return nil, "No checkpoints array"
    end
end

-- file list for current map
local function list_files()
    local out = {}
    if can_listfiles and can_isfolder and isfolder(SaveFolder) then
        local all = listfiles(SaveFolder)
        for _, f in ipairs(all) do
            local short = f:match("^" .. SaveFolder .. "/(.+)$")
            if short then table.insert(out, short) end
        end
    else
        -- fallback: try all files via readfile? Not possible. We'll attempt to check common pattern by trying to read index file
        local indexPath = SaveFolder .. "/__files_index.json"
        if can_readfile then
            local ok, content = pcall(function() return readfile(indexPath) end)
            if ok and content then
                local s, dec = pcall(function() return HttpService:JSONDecode(content) end)
                if s and type(dec) == "table" then
                    for _, v in ipairs(dec) do table.insert(out, v) end
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- maintain index fallback
local function index_add(filename)
    if not can_writefile or not can_readfile then return end
    local indexPath = SaveFolder .. "/__files_index.json"
    local tbl = {}
    pcall(function()
        if readfile(indexPath) then
            local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(indexPath)) end)
            if ok and type(dec) == "table" then tbl = dec end
        end
    end)
    for _, v in ipairs(tbl) do if v == filename then return end end
    table.insert(tbl, filename)
    pcall(function() writefile(indexPath, HttpService:JSONEncode(tbl)) end)
end

local function index_remove(filename)
    if not can_writefile or not can_readfile then return end
    local indexPath = SaveFolder .. "/__files_index.json"
    local tbl = {}
    pcall(function()
        if readfile(indexPath) then
            local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(indexPath)) end)
            if ok and type(dec) == "table" then tbl = dec end
        end
    end)
    local newtbl = {}
    for _, v in ipairs(tbl) do if v ~= filename then table.insert(newtbl, v) end end
    pcall(function() writefile(indexPath, HttpService:JSONEncode(newtbl)) end)
end

-- save checkpoints to file
local function save_file(name, checkpoints, overwrite)
    if not can_writefile then return false, "Executor tidak mendukung writefile." end
    ensure_save_folder()
    local fname = sanitize_name(name)
    local path = filepath(fname)
    -- check exist
    if can_isfile and isfile(path) and not overwrite then
        return false, "File sudah ada. Gunakan opsi overwrite."
    end
    local data = serialize_checkpoints(checkpoints)
    local ok, err = pcall(function() writefile(path, data) end)
    if ok then
        index_add(fname .. ".json") -- index uses .json names
        return true
    else
        return false, tostring(err)
    end
end

-- load file -> returns checkpoints or error
local function load_file(name)
    if not can_readfile then return nil, "Executor tidak mendukung readfile." end
    ensure_save_folder()
    local fname = sanitize_name(name)
    local path = filepath(fname)
    local ok, content = pcall(function() return readfile(path) end)
    if not ok or not content or content == "" then
        return nil, "File tidak ditemukan atau kosong."
    end
    local cps, err = deserialize_checkpoints(content)
    if not cps then return nil, err end
    return cps
end

-- delete file
local function delete_saved_file(name)
    if not can_readfile or not can_writefile then return false, "Executor tidak mendukung operasi file." end
    ensure_save_folder()
    local fname = sanitize_name(name)
    local path = filepath(fname)
    local ok, err = pcall(function() delete_file(path) end)
    index_remove(fname .. ".json")
    return ok, err
end

-- === Globals for script behavior ===
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
getgenv().AutoSummitDelay = 1 -- seconds
getgenv().AutoSummitRespawn = false
getgenv().TeleportYOffset = 5

-- last-used file per map (auto-load)
local LastFileIndexPath = SaveFolder .. "/__last_file.txt"
local function save_last_file(name)
    if not can_writefile then return end
    pcall(function() writefile(LastFileIndexPath, tostring(name)) end)
end
local function read_last_file()
    if not can_readfile then return nil end
    local ok, content = pcall(function() return readfile(LastFileIndexPath) end)
    if ok and content and content ~= "" then return tostring(content) end
    return nil
end

-- === Rayfield UI ===
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "[Marker Saver] ⛰️ DapzXPloit",
    LoadingTitle = "Loading Marker Saver...",
    LoadingSubtitle = "DapzXTeam",
    ConfigurationSaving = { Enabled = false },
    DisableRayfieldPrompts = true,
})

local MainTab = Window:CreateTab("🗻 Main")
local CPListTab = Window:CreateTab("📍 Checkpoints")
local FileTab = Window:CreateTab("💾 Files")
local CopyTab = Window:CreateTab("📋 CopyPos")

-- notify helper
local lastNotify = {}
local function SafeNotify(data)
    local now = tick()
    if not data or type(data.Title) ~= "string" then return end
    if lastNotify[data.Title] and now - lastNotify[data.Title] < 1.2 then return end
    lastNotify[data.Title] = now
    pcall(function() Rayfield:Notify(data) end)
end

-- === Auto Summit Handler ===
local function get_current_hrp()
    local pl = Players.LocalPlayer
    if not pl then return nil end
    local ch = pl.Character or pl.CharacterAdded:Wait()
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
end

local function AutoSummitHandler()
    if getgenv().AutoSummitRunning then return end
    getgenv().AutoSummitRunning = true
    SafeNotify({Title = "Auto Summit", Content = (getgenv().AutoSummitLoop and "Loop started" or "Once started"), Duration = 2})
    spawn(function()
        if getgenv().AutoSummitOnce then
            getgenv().CurrentCheckpoint = 1
            for i = getgenv().CurrentCheckpoint, #getgenv().Checkpoints do
                local cp = getgenv().Checkpoints[i]
                if cp and cp.Pos then
                    local hrp = get_current_hrp()
                    if hrp then
                        pcall(function()
                            hrp.CFrame = CFrame.new(cp.Pos + Vector3.new(math.random(-0.2,0.2), getgenv().TeleportYOffset, math.random(-0.2,0.2)))
                        end)
                    end
                    task.wait(getgenv().AutoSummitDelay + math.random()*0.2)
                end
            end
            getgenv().AutoSummitOnce = false
            getgenv().AutoSummitRunning = false
            SafeNotify({Title = "Auto Summit", Content = "Completed once", Duration = 2})
            return
        end

        if getgenv().AutoSummitLoop then
            getgenv().CurrentCheckpoint = 1
            while getgenv().AutoSummitLoop do
                local i = getgenv().CurrentCheckpoint
                local cp = getgenv().Checkpoints[i]
                if cp and cp.Pos then
                    local hrp = get_current_hrp()
                    if hrp then
                        pcall(function()
                            hrp.CFrame = CFrame.new(cp.Pos + Vector3.new(math.random(-0.2,0.2), getgenv().TeleportYOffset, math.random(-0.2,0.2)))
                        end)
                    end
                    task.wait(getgenv().AutoSummitDelay + math.random()*0.2)
                end

                if getgenv().CurrentCheckpoint >= #getgenv().Checkpoints then
                    if getgenv().AutoSummitRespawn then
                        pcall(function()
                            if Players.LocalPlayer and Players.LocalPlayer.Character then
                                Players.LocalPlayer.Character:BreakJoints()
                            end
                        end)
                        Players.LocalPlayer.CharacterAdded:Wait()
                        task.wait(0.15)
                    end
                    getgenv().CurrentCheckpoint = 1
                else
                    getgenv().CurrentCheckpoint = getgenv().CurrentCheckpoint + 1
                end
                task.wait(0.05)
            end
            getgenv().AutoSummitRunning = false
            SafeNotify({Title = "Auto Summit", Content = "Loop stopped", Duration = 2})
        else
            getgenv().AutoSummitRunning = false
        end
    end)
end

-- === Checkpoint UI management ===
local createdCPButtons = {} -- track created indexes

local function refresh_cp_ui(dropdown_refresh_callback)
    -- create UI entries for each checkpoint if not exist
    for i = 1, #getgenv().Checkpoints do
        if not createdCPButtons[i] then
            local cpName = getgenv().Checkpoints[i].Name or ("Checkpoint "..i)
            local labelTitle = "Checkpoint " .. tostring(i) .. " - " .. tostring(cpName)
            -- label
            CPListTab:CreateLabel(labelTitle)
            -- TP button
            CPListTab:CreateButton({
                Name = "🚀 TP " .. tostring(i),
                Callback = (function(idx) return function()
                    local cp = getgenv().Checkpoints[idx]
                    if not cp or not cp.Pos then SafeNotify({Title="TP", Content="Checkpoint tidak ada!", Duration=2}); return end
                    local hrp = get_current_hrp()
                    if not hrp then SafeNotify({Title="TP", Content="Karakter tidak tersedia!", Duration=2}); return end
                    pcall(function()
                        hrp.CFrame = CFrame.new(cp.Pos + Vector3.new(0, getgenv().TeleportYOffset, 0))
                    end)
                    SafeNotify({Title="TP", Content="Teleported to "..tostring(cp.Name), Duration=1.5})
                end end)(i)
            })
            -- Edit button (rename & update to current position)
            CPListTab:CreateButton({
                Name = "✏️ EDIT " .. tostring(i),
                Callback = (function(idx) return function()
                    local cp = getgenv().Checkpoints[idx]
                    if not cp then SafeNotify({Title="Edit", Content="Checkpoint tidak ditemukan", Duration=2}); return end
                    -- simple edit: update name and optionally update pos to current
                    local newName = cp.Name
                    -- ask via prompt: Rayfield doesn't provide prompt; use quick behavior: toggle update pos
                    -- We'll update position to current HRP and append timestamp to name to reflect change
                    local hrp = get_current_hrp()
                    if hrp then
                        local old = cp.Pos
                        getgenv().Checkpoints[idx].Pos = hrp.Position
                        getgenv().Checkpoints[idx].Name = tostring(cp.Name) .. " (edited)"
                        SafeNotify({Title="Edit", Content="Position updated to your current position", Duration=2})
                    else
                        SafeNotify({Title="Edit", Content="Tidak dapat edit: karakter tidak ada", Duration=2})
                    end
                    -- optionally trigger dropdown refresh in FileTab
                    if type(dropdown_refresh_callback) == "function" then pcall(dropdown_refresh_callback) end
                end end)(i)
            })
            -- Delete button
            CPListTab:CreateButton({
                Name = "🗑️ DEL " .. tostring(i),
                Callback = (function(idx) return function()
                    if not getgenv().Checkpoints[idx] then SafeNotify({Title="Delete", Content="Checkpoint tidak ditemukan", Duration=2}); return end
                    table.remove(getgenv().Checkpoints, idx)
                    SafeNotify({Title="Delete", Content="Checkpoint dihapus", Duration=1.5})
                    -- allow UI to reflect removed: we won't remove old labels but we can recreate the remainder on next refresh
                    createdCPButtons = {} -- reset so we recreate full list
                    CPListTab:CreateParagraph({Title="Refreshing...", Content="UI akan direfresh otomatis."})
                    task.delay(0.2, function() refresh_cp_ui(dropdown_refresh_callback) end)
                end end)(i)
            })
            createdCPButtons[i] = true
        end
    end
end

-- === Files UI & logic ===
ensure_save_folder()
local selectedFile = nil
local inputFileName = ""
local fileDropdownObj = nil

local function get_display_file_list()
    local raw = list_files()
    local out = {}
    for _, f in ipairs(raw) do
        local short = f:gsub("%.json$", "")
        table.insert(out, short)
    end
    table.sort(out)
    return out
end

-- Build FileTab UI
FileTab:CreateParagraph({Title="Persistent Save Files (per map)", Content="Simpan checkpoint per map. Nama file tanpa ekstensi. Auto-load last file di-map aktif."})

local nameBox = FileTab:CreateTextBox({
    Name = "Masukkan nama file...",
    Placeholder = "Contoh: MarVGunungPertama",
    Value = "",
    Flag = "FileNameBox",
    Callback = function(v) inputFileName = tostring(v or "") end
})

local saveOverwriteConfirm = false
local function confirm_and_save(name)
    if not name or name == "" then SafeNotify({Title="Save", Content="Masukkan nama file terlebih dahulu.", Duration=2}) return end
    local fname = sanitize_name(name)
    local path = filepath(fname)
    local exists = false
    if can_isfile and isfile(path) then exists = true end
    if exists and not saveOverwriteConfirm then
        -- ask for overwrite by second press
        saveOverwriteConfirm = true
        SafeNotify({Title="Save", Content="File ada. Tekan lagi Save untuk konfirmasi overwrite.", Duration=3})
        task.delay(4, function() saveOverwriteConfirm = false end)
        return
    end
    local ok, err = save_file(name, getgenv().Checkpoints, true)
    if ok then
        SafeNotify({Title="Save", Content="Berhasil menyimpan: "..tostring(name), Duration=2})
        save_last_file(name)
        -- refresh dropdown
        local opts = get_display_file_list()
        if fileDropdownObj and type(fileDropdownObj.Update) == "function" then pcall(function() fileDropdownObj:Update(opts) end) end
    else
        SafeNotify({Title="Save", Content="Gagal menyimpan: "..tostring(err), Duration=3})
    end
end

local saveBtn = FileTab:CreateButton({
    Name = "Save Sekarang",
    Callback = function()
        confirm_and_save(inputFileName)
    end
})

fileDropdownObj = FileTab:CreateDropdown({
    Name = "Pilih File...",
    Options = get_display_file_list(),
    CurrentOption = nil,
    Flag = "FileDropdown",
    Callback = function(option) selectedFile = tostring(option or "") end
})

local loadModeMerge = false
local loadBtn = FileTab:CreateButton({
    Name = "Load Sekarang",
    Callback = function()
        if not selectedFile or selectedFile == "" then SafeNotify({Title="Load", Content="Pilih file terlebih dahulu.", Duration=2}); return end
        local cps, err = load_file(selectedFile)
        if not cps then SafeNotify({Title="Load", Content="Gagal load: "..tostring(err), Duration=3}); return end
        if loadModeMerge then
            -- merge: append loaded cps (avoid duplicate names by suffix)
            for _, cp in ipairs(cps) do
                local nm = cp.Name
                -- ensure unique name
                local base = nm
                local idx = 1
                local exists = true
                while exists do
                    exists = false
                    for _, existing in ipairs(getgenv().Checkpoints) do
                        if existing.Name == nm then exists = true; break end
                    end
                    if exists then
                        idx = idx + 1
                        nm = base .. "_" .. tostring(idx)
                    end
                end
                table.insert(getgenv().Checkpoints, {Name = nm, Pos = cp.Pos})
            end
            SafeNotify({Title="Load", Content="File dimuat (merge): "..selectedFile, Duration=2})
        else
            -- replace
            getgenv().Checkpoints = cps
            SafeNotify({Title="Load", Content="File dimuat (replace): "..selectedFile, Duration=2})
        end
        save_last_file(selectedFile)
        -- refresh CP list UI
        createdCPButtons = {}
        refresh_cp_ui(function() 
            if fileDropdownObj and type(fileDropdownObj.Update) == "function" then fileDropdownObj:Update(get_display_file_list()) end
        end)
    end
})

local deleteBtn = FileTab:CreateButton({
    Name = "Delete File Terpilih",
    Callback = function()
        if not selectedFile or selectedFile == "" then SafeNotify({Title="Delete", Content="Pilih file terlebih dahulu.", Duration=2}); return end
        local ok, err = delete_saved_file(selectedFile)
        if ok then
            SafeNotify({Title="Delete", Content="File dihapus: "..selectedFile, Duration=2})
            selectedFile = nil
            if fileDropdownObj and type(fileDropdownObj.Update) == "function" then fileDropdownObj:Update(get_display_file_list()) end
        else
            SafeNotify({Title="Delete", Content="Gagal hapus: "..tostring(err), Duration=3})
        end
    end
})

FileTab:CreateToggle({
    Name = "Merge saat Load (jangan centang = replace)",
    CurrentValue = false,
    Callback = function(v) loadModeMerge = v end
})

FileTab:CreateButton({
    Name = "Refresh Daftar File",
    Callback = function()
        if fileDropdownObj and type(fileDropdownObj.Update) == "function" then
            fileDropdownObj:Update(get_display_file_list())
        end
        SafeNotify({Title="Files", Content="Daftar file diperbarui.", Duration=1.2})
    end
})

-- auto-load last file for this map if exists
task.delay(0.6, function()
    if can_readfile then
        local last = read_last_file()
        if last and last ~= "" then
            if table.find(get_display_file_list(), last) then
                local cps, err = load_file(last)
                if cps then
                    getgenv().Checkpoints = cps
                    SafeNotify({Title="Auto Load", Content="File terakhir dimuat: "..tostring(last), Duration=2})
                    createdCPButtons = {}
                    refresh_cp_ui(function() if fileDropdownObj and type(fileDropdownObj.Update) == "function" then fileDropdownObj:Update(get_display_file_list()) end end)
                end
            end
        end
    end
end)

-- === CopyPos tab ===
local CopyBuffer = {}

CopyTab:CreateParagraph({Title="CopyPosition", Content="Tambahkan checkpoint dari posisi saat ini. Data juga bisa disalin ke clipboard."})
CopyTab:CreateButton({
    Name = "📍 Save Current Position as Checkpoint",
    Callback = function()
        local hrp = get_current_hrp()
        if not hrp then SafeNotify({Title="CopyPos", Content="Karakter tidak tersedia!", Duration=2}); return end
        local pos = hrp.Position
        local idx = #getgenv().Checkpoints + 1
        local name = "Checkpoint " .. tostring(idx)
        table.insert(getgenv().Checkpoints, {Name = name, Pos = pos})
        table.insert(CopyBuffer, {Name = name, Pos = pos})
        createdCPButtons = {} -- refresh UI
        refresh_cp_ui(function() end)
        -- copy formatted string to clipboard if supported
        local formatted = string.format('{Name = "%s", Pos = Vector3.new(%.4f, %.4f, %.4f)},', name, pos.X, pos.Y, pos.Z)
        if setclipboard then pcall(function() setclipboard(formatted) end) elseif toclipboard then pcall(function() toclipboard(formatted) end) end
        SafeNotify({Title="CopyPos", Content="Checkpoint ditambahkan & disalin.", Duration=2})
    end
})

CopyTab:CreateButton({
    Name = "📋 Copy All Buffer",
    Callback = function()
        if #CopyBuffer == 0 then SafeNotify({Title="CopyAll", Content="Buffer kosong.", Duration=1.5); return end
        local lines = {}
        for _, v in ipairs(CopyBuffer) do
            table.insert(lines, string.format('{Name = "%s", Pos = Vector3.new(%.4f, %.4f, %.4f)},', v.Name, v.Pos.X, v.Pos.Y, v.Pos.Z))
        end
        local all = table.concat(lines, "\n")
        if setclipboard then pcall(function() setclipboard(all) end) elseif toclipboard then pcall(function() toclipboard(all) end) end
        SafeNotify({Title="CopyAll", Content="Semua checkpoint di-buffer disalin.", Duration=2})
    end
})

-- === Main tab (controls) ===
MainTab:CreateParagraph({Title="Controls", Content="Atur AutoLoop, Delay, Respawn, serta Quick Save / Delete All."})

MainTab:CreateToggle({
    Name = "⛳ Auto Summit Loop",
    CurrentValue = false,
    Callback = function(v)
        getgenv().AutoSummitLoop = v
        if v then
            getgenv().AutoSummitOnce = false
            getgenv().CurrentCheckpoint = 1
            AutoSummitHandler()
        else
            SafeNotify({Title="AutoLoop", Content="Loop dimatikan.", Duration=1.2})
        end
    end
})

MainTab:CreateButton({
    Name = "🎯 Auto Summit Sekali",
    Callback = function()
        getgenv().AutoSummitOnce = true
        getgenv().CurrentCheckpoint = 1
        AutoSummitHandler()
    end
})

MainTab:CreateSlider({
    Name = "⏳ Summit Delay (detik)",
    Range = {0.1, 10},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = getgenv().AutoSummitDelay,
    Callback = function(v) getgenv().AutoSummitDelay = v end
})

MainTab:CreateToggle({
    Name = "🛌 Respawn setelah Summit",
    CurrentValue = getgenv().AutoSummitRespawn,
    Callback = function(v) getgenv().AutoSummitRespawn = v; SafeNotify({Title="Respawn", Content = v and "Aktif" or "Nonaktif", Duration=1.2}) end
})

MainTab:CreateButton({
    Name = "📥 Save Current Checkpoints to Quick File",
    Callback = function()
        local name = "QuickSave_" .. tostring(os.time())
        local ok, err = save_file(name, getgenv().Checkpoints, true)
        if ok then
            SafeNotify({Title="Quick Save", Content="Tersimpan sebagai "..name, Duration=2})
            if fileDropdownObj and type(fileDropdownObj.Update) == "function" then fileDropdownObj:Update(get_display_file_list()) end
            save_last_file(name)
        else
            SafeNotify({Title="Quick Save", Content="Gagal: "..tostring(err), Duration=3})
        end
    end
})

MainTab:CreateButton({
    Name = "🗑️ Delete All Checkpoints",
    Callback = function()
        getgenv().Checkpoints = {}
        createdCPButtons = {}
        SafeNotify({Title="DeleteAll", Content="Semua checkpoint dihapus.", Duration=1.5})
    end
})

-- initial cp UI population
task.delay(0.4, function() refresh_cp_ui(function() if fileDropdownObj and type(fileDropdownObj.Update) == "function" then fileDropdownObj:Update(get_display_file_list()) end end) end)

-- final ready notify
SafeNotify({Title="✅ Marker Saver Ready", Content = "Per-map save aktif. Pastikan executor mendukung writefile/readfile untuk persistence.", Duration = 3})
