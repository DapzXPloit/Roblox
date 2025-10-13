-- Marker Saver - DapzXPloit (V2)
-- Delta-friendly final version
-- Save file as UTF-8 (no BOM). Paste whole file.

-- ========== Services & Env ==========
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local PLACE_ID = tostring(game.PlaceId or 0)

-- ========== Executor capability detection ==========
local has_writefile  = type(writefile) == "function"
local has_readfile   = type(readfile) == "function"
local has_isfolder   = type(isfolder) == "function"
local has_makefolder = type(makefolder) == "function"
local has_listfiles  = type(listfiles) == "function"
local has_isfile     = type(isfile) == "function"
local has_delfile    = type(delfile) == "function" or type(deletefile) == "function"
local can_clipboard  = (type(setclipboard) == "function") or (type(toclipboard) == "function")

local SAVE_ROOT = "DapzXPloit"
local SAVE_FOLDER = SAVE_ROOT .. "/" .. PLACE_ID
local INDEX_PATH = SAVE_FOLDER .. "/__index.json"
local LAST_PATH = SAVE_FOLDER .. "/__last.txt"

-- ========== Helpers: file system & index ==========
local function ensure_folder()
    if has_isfolder and has_makefolder then
        if not isfolder(SAVE_ROOT) then pcall(makefolder, SAVE_ROOT) end
        if not isfolder(SAVE_FOLDER) then pcall(makefolder, SAVE_FOLDER) end
    end
end

local function sanitize_name(n)
    n = tostring(n or "")
    n = n:match("^%s*(.-)%s*$")
    n = n:gsub("[/\\:%%%*%?%\"<>|]", "")
    n = n:gsub("%s+", "_")
    if n == "" then n = "file" end
    return n
end

local function file_path(name)
    return SAVE_FOLDER .. "/" .. sanitize_name(name) .. ".json"
end

local function delete_file(path)
    if has_delfile then
        if type(delfile) == "function" then pcall(delfile, path) end
        if type(deletefile) == "function" then pcall(deletefile, path) end
    else
        if has_writefile then pcall(writefile, path, "") end
    end
end

local function read_index()
    if not has_readfile then return {} end
    ensure_folder()
    local ok, cont = pcall(readfile, INDEX_PATH)
    if not ok or not cont or cont == "" then return {} end
    local ok2, dec = pcall(HttpService.JSONDecode, HttpService, cont)
    if ok2 and type(dec) == "table" then return dec end
    return {}
end

local function write_index(tbl)
    if not has_writefile then return end
    ensure_folder()
    pcall(function() writefile(INDEX_PATH, HttpService:JSONEncode(tbl)) end)
end

local function index_add(fname)
    if not (has_writefile and has_readfile) then return end
    local tbl = read_index()
    for _,v in ipairs(tbl) do if v == fname then return end end
    table.insert(tbl, fname)
    write_index(tbl)
end

local function index_remove(fname)
    if not (has_writefile and has_readfile) then return end
    local tbl = read_index()
    local out = {}
    for _,v in ipairs(tbl) do if v ~= fname then table.insert(out, v) end end
    write_index(out)
end

local function list_saved_files()
    local out = {}
    if has_listfiles and has_isfolder and isfolder(SAVE_FOLDER) then
        local all = listfiles(SAVE_FOLDER)
        for _,p in ipairs(all) do
            local short = p:match("^" .. SAVE_FOLDER .. "/(.+)$")
            if short then table.insert(out, short) end
        end
    else
        local idx = read_index()
        for _,v in ipairs(idx) do table.insert(out, v) end
    end
    table.sort(out)
    return out
end

-- ========== Checkpoint serialization ==========
local function serialize_checkpoints(tbl)
    local out = {}
    for i,cp in ipairs(tbl) do
        local pos = cp.Pos
        local x,y,z = 0,0,0
        pcall(function()
            x = tonumber(pos.X) or x
            y = tonumber(pos.Y) or y
            z = tonumber(pos.Z) or z
        end)
        table.insert(out, {Name = tostring(cp.Name or ("Checkpoint_"..i)), Pos = {X=x,Y=y,Z=z}})
    end
    return HttpService:JSONEncode({Name="MarkerFile", Checkpoints=out})
end

local function deserialize_checkpoints(json)
    local ok, dec = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(dec) ~= "table" or type(dec.Checkpoints) ~= "table" then
        return nil, "invalid json"
    end
    local cps = {}
    for i,cp in ipairs(dec.Checkpoints) do
        local nm = cp.Name or ("Checkpoint "..i)
        local p = cp.Pos
        if type(p)=="table" and p.X and p.Y and p.Z then
            table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(tonumber(p.X) or 0, tonumber(p.Y) or 0, tonumber(p.Z) or 0)})
        else
            table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(0,0,0)})
        end
    end
    return cps
end

local function save_file(name, checkpoints, overwrite)
    if not has_writefile then return false, "writefile unsupported" end
    ensure_folder()
    local fn = sanitize_name(name)
    local path = file_path(fn)
    if has_isfile and isfile(path) and not overwrite then
        return false, "file exists"
    end
    local data = serialize_checkpoints(checkpoints)
    local ok,err = pcall(writefile, path, data)
    if ok then index_add(fn .. ".json"); return true end
    return false, tostring(err)
end

local function load_file(name)
    if not has_readfile then return nil, "readfile unsupported" end
    ensure_folder()
    local fn = sanitize_name(name)
    local path = file_path(fn)
    local ok,content = pcall(readfile, path)
    if not ok or not content or content == "" then return nil, "file missing/empty" end
    local cps,err = deserialize_checkpoints(content)
    if not cps then return nil, err end
    return cps
end

local function delete_saved(name)
    if not (has_readfile and has_writefile) then return false, "file ops unsupported" end
    ensure_folder()
    local fn = sanitize_name(name)
    local path = file_path(fn)
    delete_file(path)
    index_remove(fn .. ".json")
    return true
end

-- ========== Globals & Defaults ==========
local Checkpoints = {
    {Name="Spawn", Pos=Vector3.new(-925.52,371.61,37.74)},
    {Name="Checkpoint 1", Pos=Vector3.new(-903.17,364.01,-428.28)},
    {Name="Checkpoint 2", Pos=Vector3.new(-602.62,421.12,-545.52)},
    {Name="Summit", Pos=Vector3.new(2496.26,2223.81,15.70)},
}
local CurrentCheckpoint = 1
local AutoLoop = false
local AutoOnce = false
local IsRunning = false
local AutoDelay = 1
local AutoRespawn = false
local TeleportYOffset = 5

-- ========== Small safe utilities ==========
local function safe_wait(t)
    if type(t) ~= "number" then t = 0.2 end
    pcall(function() task.wait(t) end)
end

local function get_hrp()
    if not localPlayer then localPlayer = Players.LocalPlayer end
    if not localPlayer then return nil end
    local ch = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
end

local function teleport_to(pos)
    local hrp = get_hrp()
    if hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, TeleportYOffset, 0))
        end)
    end
end

-- ========== UI Building ==========
local function makeUI()
    -- parent: try PlayerGui first, else CoreGui
    local parent = (localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")) or game:GetService("CoreGui")
    if not parent then warn("[MarkerSaver] No GUI parent"); return end

    -- clear old
    pcall(function()
        local old = parent:FindFirstChild("MarkerSaverGUI")
        if old then old:Destroy() end
    end)

    local screen = Instance.new("ScreenGui")
    screen.Name = "MarkerSaverGUI"
    screen.ResetOnSpawn = false
    screen.Parent = parent

    -- main frame (compact)
    local frame = Instance.new("Frame", screen)
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0,380,0,300)
    frame.Position = UDim2.new(0.5, -190, 0.45, -150)
    frame.BackgroundColor3 = Color3.fromRGB(24,24,34)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)

    -- header
    local header = Instance.new("Frame", frame)
    header.Size = UDim2.new(1,0,0,36)
    header.Position = UDim2.new(0,0,0,0)
    header.BackgroundColor3 = Color3.fromRGB(40,40,60)
    header.BorderSizePixel = 0
    Instance.new("UICorner", header).CornerRadius = UDim.new(0,14)

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1,-80,1,0)
    title.Position = UDim2.new(0,12,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Marker Saver - DapzXPloit"
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left

    -- minimize button (will minimize to bar)
    local btnMin = Instance.new("TextButton", header)
    btnMin.Size = UDim2.new(0,36,0,28)
    btnMin.Position = UDim2.new(1,-44,0,4)
    btnMin.Text = "—"
    btnMin.Font = Enum.Font.GothamBold
    btnMin.TextSize = 20
    btnMin.TextColor3 = Color3.new(1,1,1)
    btnMin.BackgroundColor3 = Color3.fromRGB(90,90,110)
    btnMin.BorderSizePixel = 0
    Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0,10)

    -- status label
    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(0.6,0,0,20)
    status.Position = UDim2.new(0,12,0,42)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextColor3 = Color3.fromRGB(200,200,200)
    status.Text = ""

    local function notify(txt, dur)
        status.Text = tostring(txt or "")
        dur = tonumber(dur) or 3
        spawn(function()
            local t0 = tick()
            while tick()-t0 < dur do task.wait(0.1) end
            if status.Text == txt then status.Text = "" end
        end)
    end

    -- Buttons row 1
    local function createBtn(p, text, x, y, col)
        local b = Instance.new("TextButton", p)
        b.Size = UDim2.new(0,110,0,34)
        b.Position = UDim2.new(0,x,0,y)
        b.BackgroundColor3 = col or Color3.fromRGB(80,80,110)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.Text = text
        b.TextColor3 = Color3.new(1,1,1)
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        -- hover tween
        b.MouseEnter:Connect(function()
            pcall(function()
                TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = b.BackgroundColor3:Lerp(Color3.fromRGB(255,255,255), 0.03)}):Play()
            end)
        end)
        b.MouseLeave:Connect(function()
            pcall(function()
                TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = col}):Play()
            end)
        end)
        return b
    end

    local btnAuto = createBtn(frame, "⛳ AutoLoop OFF", 10, 66, Color3.fromRGB(200,70,70))
    local btnSaveCP = createBtn(frame, "📍 Save CP", 137, 66, Color3.fromRGB(70,120,200))
    local btnDelAll = createBtn(frame, "🗑️ Delete All", 264, 66, Color3.fromRGB(200,120,60))

    -- Buttons row 2 + save name input
    local inputLabel = Instance.new("TextLabel", frame)
    inputLabel.Size = UDim2.new(0,110,0,18)
    inputLabel.Position = UDim2.new(0,12,0,108)
    inputLabel.BackgroundTransparency = 1
    inputLabel.Font = Enum.Font.GothamBold
    inputLabel.TextSize = 12
    inputLabel.TextColor3 = Color3.fromRGB(220,220,220)
    inputLabel.Text = "Masukkan nama file..."

    local inputBox = Instance.new("TextBox", frame)
    inputBox.Size = UDim2.new(0,220,0,24)
    inputBox.Position = UDim2.new(0,135,0,104)
    inputBox.BackgroundColor3 = Color3.fromRGB(38,38,50)
    inputBox.TextColor3 = Color3.fromRGB(240,240,240)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 13
    inputBox.PlaceholderText = "Contoh: MarVGunungPertama"
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0,6)

    local btnSaveFile = createBtn(frame, "💾 Save Sekarang", 12, 138, Color3.fromRGB(90,150,220))
    local btnLoadFile = createBtn(frame, "📂 Load Sekarang", 137, 138, Color3.fromRGB(80,190,140))
    local btnCopyAll = createBtn(frame, "📋 Copy All", 264, 138, Color3.fromRGB(130,110,200))

    -- Delay input
    local lblDelay = Instance.new("TextLabel", frame)
    lblDelay.Size = UDim2.new(0,70,0,18)
    lblDelay.Position = UDim2.new(0,12,0,178)
    lblDelay.BackgroundTransparency = 1
    lblDelay.Font = Enum.Font.GothamBold
    lblDelay.TextSize = 12
    lblDelay.TextColor3 = Color3.fromRGB(220,220,220)
    lblDelay.Text = "Delay (s):"

    local delayBox = Instance.new("TextBox", frame)
    delayBox.Size = UDim2.new(0,60,0,22)
    delayBox.Position = UDim2.new(0,90,0,174)
    delayBox.BackgroundColor3 = Color3.fromRGB(38,38,50)
    delayBox.TextColor3 = Color3.fromRGB(240,240,240)
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 13
    delayBox.Text = tostring(AutoDelay)
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0,6)

    local respawnBtn = createBtn(frame, "♻️ Respawn OFF", 182, 174, Color3.fromRGB(200,170,60))
    local autosaveBtn = createBtn(frame, "Autosave OFF", 264, 174, Color3.fromRGB(110,110,110))

    -- scroll area for checkpoints
    local scroll = Instance.new("ScrollingFrame", frame)
    scroll.Size = UDim2.new(1,-28,0,92)
    scroll.Position = UDim2.new(0,12,0,206)
    scroll.BackgroundColor3 = Color3.fromRGB(34,34,46)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,8)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0,6)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    -- helper small button for cp rows
    local function smallBtn(parent, txt, w, color)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(0,w or 72,0,26)
        b.BackgroundColor3 = color or Color3.fromRGB(100,170,120)
        b.Font = Enum.Font.GothamBold
        b.Text = txt
        b.TextSize = 13
        b.TextColor3 = Color3.new(1,1,1)
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        return b
    end

    -- populate checkpoint list
    local function refresh_cp_list()
        -- remove old rows
        for _,c in ipairs(scroll:GetChildren()) do
            if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
        end
        for i,cp in ipairs(Checkpoints) do
            local row = Instance.new("Frame", scroll)
            row.Size = UDim2.new(1,-12,0,28)
            row.BackgroundTransparency = 1
            row.LayoutOrder = i

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(0.5,0,1,0)
            nameLbl.Position = UDim2.new(0,6,0,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = cp.Name or ("Checkpoint "..i)
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 13
            nameLbl.TextColor3 = Color3.fromRGB(235,235,235)
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local tp = smallBtn(row, "TP", 56, Color3.fromRGB(60,170,90))
            tp.Position = UDim2.new(0.5, 6, 0, 1)
            tp.MouseButton1Click:Connect(function()
                teleport_to(cp.Pos)
                notify("Teleported to "..tostring(cp.Name), 1.2)
                CurrentCheckpoint = i
            end)

            local edit = smallBtn(row, "EDIT", 56, Color3.fromRGB(200,180,60))
            edit.Position = UDim2.new(0.5, 70, 0, 1)
            edit.MouseButton1Click:Connect(function()
                local hrp = get_hrp()
                if not hrp then notify("Karakter tidak tersedia",2); return end
                Checkpoints[i].Pos = hrp.Position
                Checkpoints[i].Name = tostring(Checkpoints[i].Name or ("Checkpoint "..i)) .. " (edited)"
                notify("Checkpoint "..i.." updated",1.5)
                refresh_cp_list()
            end)

            local del = smallBtn(row, "DEL", 56, Color3.fromRGB(200,80,80))
            del.Position = UDim2.new(0.78, -10, 0, 1)
            del.MouseButton1Click:Connect(function()
                table.remove(Checkpoints, i)
                notify("Checkpoint "..i.." removed",1.1)
                refresh_cp_list()
            end)
        end
        scroll.CanvasSize = UDim2.new(0,0,0, (math.max(0,#Checkpoints) * 36))
    end

    -- initial populate
    refresh_cp_list()

    -- ========== Button behaviors (core) ==========
    btnSaveCP.MouseButton1Click:Connect(function()
        local hrp = get_hrp()
        if not hrp then notify("Karakter tidak tersedia",2); return end
        local idx = #Checkpoints + 1
        local name = "Checkpoint "..tostring(idx)
        table.insert(Checkpoints, {Name = name, Pos = hrp.Position})
        refresh_cp_list()
        notify("Saved "..name,1.3)
    end)

    btnDelAll.MouseButton1Click:Connect(function()
        Checkpoints = {}
        refresh_cp_list()
        notify("All checkpoints removed",1.2)
    end)

    btnAuto.MouseButton1Click:Connect(function()
        AutoLoop = not AutoLoop
        btnAuto.Text = AutoLoop and "⏸️ AutoLoop ON" or "⛳ AutoLoop OFF"
        btnAuto.BackgroundColor3 = AutoLoop and Color3.fromRGB(80,200,100) or Color3.fromRGB(200,70,70)
        if AutoLoop then
            spawn(function()
                IsRunning = true
                CurrentCheckpoint = 1
                while AutoLoop do
                    local cp = Checkpoints[CurrentCheckpoint]
                    if cp and cp.Pos then
                        teleport_to(cp.Pos)
                    end
                    safe_wait(AutoDelay + math.random()*0.2)
                    if CurrentCheckpoint >= #Checkpoints then
                        if AutoRespawn then
                            pcall(function() if localPlayer and localPlayer.Character then localPlayer.Character:BreakJoints() end end)
                            if localPlayer then localPlayer.CharacterAdded:Wait() end
                            safe_wait(0.1)
                        end
                        CurrentCheckpoint = 1
                    else
                        CurrentCheckpoint = CurrentCheckpoint + 1
                    end
                    task.wait(0.05)
                end
                IsRunning = false
            end)
        end
    end)

    respawnBtn.MouseButton1Click:Connect(function()
        AutoRespawn = not AutoRespawn
        respawnBtn.Text = AutoRespawn and "♻️ Respawn ON" or "♻️ Respawn OFF"
        notify("Respawn "..(AutoRespawn and "enabled" or "disabled"),1.2)
    end)

    delayBox.FocusLost:Connect(function(enter)
        local v = tonumber(delayBox.Text)
        if v and v > 0 then AutoDelay = v; delayBox.Text = tostring(v); notify("Delay set to "..tostring(v),1)
        else delayBox.Text = tostring(AutoDelay); notify("Invalid delay",1) end
    end)

    autosaveBtn.MouseButton1Click:Connect(function()
        -- simple autosave toggle, default OFF; save to autosave timestamp file
        local enabled = autosaveBtn:GetAttribute("Enabled") or false
        enabled = not enabled
        autosaveBtn:SetAttribute("Enabled", enabled)
        autosaveBtn.Text = enabled and "Autosave ON" or "Autosave OFF"
        autosaveBtn.BackgroundColor3 = enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(110,110,110)
        notify("Autosave "..(enabled and "enabled" or "disabled"),1.2)
        if enabled then
            spawn(function()
                while autosaveBtn:GetAttribute("Enabled") do
                    task.wait(10)
                    if has_writefile then
                        local ok,err = pcall(function() save_file("Autosave_"..tostring(os.time()), Checkpoints, true) end)
                    else
                        -- fallback: copy JSON to clipboard
                        if can_clipboard then pcall(function() if setclipboard then setclipboard(serialize_checkpoints(Checkpoints)) elseif toclipboard then toclipboard(serialize_checkpoints(Checkpoints)) end end) end
                    end
                end
            end)
        end
    end)

    btnSaveFile.MouseButton1Click:Connect(function()
        local name = tostring(inputBox.Text or "")
        if name == "" then notify("Masukkan nama file terlebih dahulu",2); return end
        if has_writefile then
            local ok, err = pcall(function() return save_file(name, Checkpoints, true) end)
            if ok then notify("Saved: "..tostring(name),2); pcall(function() writefile(LAST_PATH, name) end)
            else notify("Save failed: "..tostring(err),3) end
        else
            local js = serialize_checkpoints(Checkpoints)
            if can_clipboard then
                pcall(function() if setclipboard then setclipboard(js) elseif toclipboard then toclipboard(js) end end)
                notify("No writefile. JSON copied to clipboard",4)
            else
                notify("No writefile & no clipboard available",4)
            end
        end
    end)

    -- Popup for file selector (Load)
    local function showLoadPopup()
        -- overlay
        local overlay = Instance.new("Frame", screen)
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.Position = UDim2.new(0,0,0,0)
        overlay.BackgroundTransparency = 0.5
        overlay.BackgroundColor3 = Color3.fromRGB(8,8,12)
        overlay.ZIndex = 50

        local popup = Instance.new("Frame", overlay)
        popup.Size = UDim2.new(0,300,0,260)
        popup.Position = UDim2.new(0.5,-150,0.5,-130)
        popup.BackgroundColor3 = Color3.fromRGB(28,28,38)
        popup.BorderSizePixel = 0
        popup.ZIndex = 51
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0,12)
        popup.Active = true
        popup.Draggable = true

        local heading = Instance.new("TextLabel", popup)
        heading.Size = UDim2.new(1, -24, 0, 36)
        heading.Position = UDim2.new(0,12,0,8)
        heading.BackgroundTransparency = 1
        heading.Text = "📂 Pilih File untuk Dimuat"
        heading.Font = Enum.Font.GothamBold
        heading.TextColor3 = Color3.new(1,1,1)
        heading.TextSize = 15
        heading.TextXAlignment = Enum.TextXAlignment.Left

        local closeBtn = Instance.new("TextButton", popup)
        closeBtn.Size = UDim2.new(0,28,0,28)
        closeBtn.Position = UDim2.new(1, -40, 0, 6)
        closeBtn.BackgroundColor3 = Color3.fromRGB(140,60,60)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)

        local listFrame = Instance.new("ScrollingFrame", popup)
        listFrame.Size = UDim2.new(1, -24, 1, -64)
        listFrame.Position = UDim2.new(0,12,0,48)
        listFrame.BackgroundTransparency = 1
        listFrame.ScrollBarThickness = 8
        listFrame.CanvasSize = UDim2.new(0,0,0,0)
        listFrame.ZIndex = 51

        local lfLayout = Instance.new("UIListLayout", listFrame)
        lfLayout.Padding = UDim.new(0,6)
        lfLayout.FillDirection = Enum.FillDirection.Vertical
        lfLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- populate list with saved files
        local files = list_saved_files()
        if #files == 0 then
            local info = Instance.new("TextLabel", listFrame)
            info.Size = UDim2.new(1, -20, 0, 28)
            info.BackgroundTransparency = 1
            info.Text = "Belum ada file tersimpan."
            info.Font = Enum.Font.Gotham
            info.TextColor3 = Color3.fromRGB(200,200,200)
            info.TextSize = 13
            info.LayoutOrder = 1
        else
            for i,f in ipairs(files) do
                local btn = Instance.new("TextButton", listFrame)
                btn.Size = UDim2.new(1, -20, 0, 32)
                btn.Position = UDim2.new(0,10,0, (i-1)*38)
                btn.BackgroundColor3 = Color3.fromRGB(46,46,60)
                btn.Font = Enum.Font.GothamBold
                btn.TextColor3 = Color3.new(1,1,1)
                btn.TextSize = 13
                btn.Text = f:gsub("%.json$","")
                btn.AutoButtonColor = true
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
                btn.LayoutOrder = i

                btn.MouseButton1Click:Connect(function()
                    -- load file
                    local name = btn.Text
                    local cps, err = load_file(name)
                    if not cps then
                        notify("Load failed: "..tostring(err), 3)
                    else
                        Checkpoints = cps
                        refresh_cp_list()
                        notify("Loaded "..name, 2)
                        -- save last
                        if has_writefile then pcall(function() writefile(LAST_PATH, name) end) end
                    end
                    overlay:Destroy()
                end)
            end
        end

        closeBtn.MouseButton1Click:Connect(function() overlay:Destroy() end)
        -- update canvas size
        listFrame.CanvasSize = UDim2.new(0,0,0, lfLayout.AbsoluteContentSize.Y + 12)
    end

    btnLoadFile.MouseButton1Click:Connect(function()
        showLoadPopup()
    end)

    btnCopyAll.MouseButton1Click:Connect(function()
        local lines = {}
        for i,cp in ipairs(Checkpoints) do
            local p = cp.Pos
            table.insert(lines, string.format('{Name = "%s", Pos = Vector3.new(%.4f, %.4f, %.4f)},', cp.Name or ("CP_"..i), p.X, p.Y, p.Z))
        end
        local txt = table.concat(lines, "\n")
        if can_clipboard then pcall(function() if setclipboard then setclipboard(txt) elseif toclipboard then toclipboard(txt) end end); notify("Formatted checkpoints copied",2)
        else notify("Clipboard not available",2) end
    end)

    -- load last file automatically if exists
    pcall(function()
        if has_readfile then
            local ok, last = pcall(readfile, LAST_PATH)
            if ok and last and last ~= "" then
                local cps = select(1, pcall(load_file, last))
                if type(cps) == "table" then Checkpoints = cps; refresh_cp_list(); notify("Auto-loaded "..tostring(last),2) end
            end
        end
    end)

    -- ========== Minimize system (draggable bar) ==========
    local minimized = false
    local miniBar = Instance.new("Frame", screen)
    miniBar.Size = UDim2.new(0,240,0,44)
    miniBar.Position = UDim2.new(0.5, -120, 0.06, 0)
    miniBar.AnchorPoint = Vector2.new(0.5,0)
    miniBar.BackgroundColor3 = Color3.fromRGB(42,42,62)
    miniBar.BorderSizePixel = 0
    miniBar.ZIndex = 80
    Instance.new("UICorner", miniBar).CornerRadius = UDim.new(0,22)
    miniBar.Active = true
    miniBar.Draggable = true
    miniBar.Visible = false

    local miniLabel = Instance.new("TextLabel", miniBar)
    miniLabel.Size = UDim2.new(1,-12,1,0)
    miniLabel.Position = UDim2.new(0,8,0,0)
    miniLabel.BackgroundTransparency = 1
    miniLabel.Text = "🌈 DapzXPloit - Tools Mount"
    miniLabel.Font = Enum.Font.GothamBold
    miniLabel.TextSize = 14
    miniLabel.TextColor3 = Color3.new(1,1,1)
    miniLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- subtle stroke (rgb cycling)
    local stroke = Instance.new("UIStroke", miniBar)
    stroke.Thickness = 1.2
    stroke.Color = Color3.fromRGB(150,150,255)

    -- animate stroke color slowly (non-blocking)
    spawn(function()
        while miniBar and miniBar.Parent do
            for h=0,1,0.02 do
                if not miniBar.Parent then return end
                stroke.Color = Color3.fromHSV(h, 0.6, 1)
                safe_wait(0.03)
            end
        end
    end)

    -- minimize action
    btnMin.MouseButton1Click:Connect(function()
        if minimized then return end
        minimized = true
        -- tween scale/alpha
        TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Size = UDim2.new(0,380,0,0), Position = UDim2.new(0.5, -190, 0.45, -150)}):Play()
        wait(0.28)
        frame.Visible = false
        miniBar.Visible = true
    end)

    -- clicking miniBar restores
    miniBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            if not minimized then return end
            minimized = false
            miniBar.Visible = false
            frame.Visible = true
            frame.Size = UDim2.new(0,380,0,0)
            frame.Position = UDim2.new(0.5, -190, 0.45, -150)
            TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Size = UDim2.new(0,380,0,300)}):Play()
        end
    end)

    -- make miniBar draggable but confined: already draggable via property
    -- ensure text isn't clipped by decreasing main font if necessary (already sized)

    -- return controls if needed
    return {
        Refresh = refresh_cp_list,
        Notify = notify,
        Screen = screen,
        Frame = frame,
        MiniBar = miniBar
    }
end

-- ========== Build and expose ==========
local ok, res = pcall(makeUI)
if not ok then
    warn("[MarkerSaver] UI build failed:", res)
else
    print("[MarkerSaver] UI ready.")
end

-- end of file
