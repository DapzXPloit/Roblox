-- Marker Saver - DapzXPloit (V3.5)
-- Delta-ready. Save as UTF-8 without BOM.

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local PLACE_ID = tostring(game.PlaceId or 0)

-- Executor capability detection
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

-- Defaults
local Checkpoints = {
    {Name="Spawn", Pos=Vector3.new(-925.52,371.61,37.74)},
    {Name="Checkpoint 1", Pos=Vector3.new(-903.17,364.01,-428.28)},
    {Name="Checkpoint 2", Pos=Vector3.new(-602.62,421.12,-545.52)},
    {Name="Summit", Pos=Vector3.new(2496.26,2223.81,15.70)},
}
local AutoLoop = false
local AutoDelay = 1
local AutoRespawn = false

-- Utility: safe wait
local function safe_wait(t)
    if type(t) ~= "number" then t = 0.1 end
    pcall(task.wait, t)
end

-- File helpers
local function ensure_folder()
    if has_isfolder and has_makefolder then
        pcall(function()
            if not isfolder(SAVE_ROOT) then makefolder(SAVE_ROOT) end
            if not isfolder(SAVE_FOLDER) then makefolder(SAVE_FOLDER) end
        end)
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
        pcall(function() if type(delfile)=="function" then delfile(path) end end)
        pcall(function() if type(deletefile)=="function" then deletefile(path) end end)
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

-- Serialization helpers
local function serialize_checkpoints(tbl)
    local out = {}
    for i,cp in ipairs(tbl) do
        local pos = cp.Pos
        local x,y,z = 0,0,0
        pcall(function() x = tonumber(pos.X) or x; y = tonumber(pos.Y) or y; z = tonumber(pos.Z) or z end)
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
    if has_isfile and isfile(path) and not overwrite then return false, "file exists" end
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
    local ok, content = pcall(readfile, path)
    if not ok or not content or content == "" then return nil, "file missing/empty" end
    local cps, err = deserialize_checkpoints(content)
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

-- Teleport helper
local function get_hrp()
    if not localPlayer then localPlayer = Players.LocalPlayer end
    if not localPlayer then return nil end
    local ch = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
end

local function teleport_to(pos)
    local hrp = get_hrp()
    if hrp then pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0,5,0)) end) end
end

-- Notification helper (use StarterGui SetCore if available)
local function notify_default(title, text, duration)
    duration = tonumber(duration) or 3
    local success, _ = pcall(function()
        StarterGui:SetCore("SendNotification", {Title = tostring(title or "Notification"), Text = tostring(text or ""); Duration = duration})
    end)
    if not success then
        -- fallback: print or small on-gui status (we'll have status label)
        warn("[MarkerSaver] "..tostring(title)..": "..tostring(text))
    end
end

-- Build UI
local function buildUI()
    local parent = (localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")) or game:GetService("CoreGui")
    if not parent then error("No GUI parent") end

    -- remove old if exists
    pcall(function() local old=parent:FindFirstChild("MarkerSaverGUI"); if old then old:Destroy() end end)

    local screen = Instance.new("ScreenGui")
    screen.Name = "MarkerSaverGUI"
    screen.ResetOnSpawn = false
    screen.Parent = parent

    -- main frame
    local frame = Instance.new("Frame", screen)
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0,380,0,300)
    frame.Position = UDim2.new(0.5,-190,0.45,-150)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,32)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)

    -- header
    local header = Instance.new("Frame", frame)
    header.Size = UDim2.new(1,0,0,36)
    header.Position = UDim2.new(0,0,0,0)
    header.BackgroundColor3 = Color3.fromRGB(44,44,64)
    header.BorderSizePixel = 0
    Instance.new("UICorner", header).CornerRadius = UDim.new(0,12)

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1,-80,1,0)
    title.Position = UDim2.new(0,12,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Marker Saver - DapzXPloit"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.TextXAlignment = Enum.TextXAlignment.Left

    -- minimize button
    local btnMin = Instance.new("TextButton", header)
    btnMin.Size = UDim2.new(0,36,0,28)
    btnMin.Position = UDim2.new(1,-44,0,4)
    btnMin.Text = "—"
    btnMin.Font = Enum.Font.GothamBold
    btnMin.TextSize = 20
    btnMin.TextColor3 = Color3.fromRGB(255,255,255)
    btnMin.BackgroundColor3 = Color3.fromRGB(95,95,115)
    btnMin.BorderSizePixel = 0
    Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0,8)

    -- status label (fallback)
    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(0.6,0,0,18)
    status.Position = UDim2.new(0,12,0,42)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextColor3 = Color3.fromRGB(200,200,200)
    status.Text = ""

    local function status_notify(str, t)
        status.Text = tostring(str or "")
        t = tonumber(t) or 3
        spawn(function()
            local s = tick()
            while tick()-s < t do task.wait(0.1) end
            if status.Text == str then status.Text = "" end
        end)
    end

    local function notify(title, text, dur)
        -- primary: default notification
        local ok = pcall(function()
            StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 3})
        end)
        if not ok then
            -- fallback small status
            status_notify("["..tostring(title).."] "..tostring(text), dur or 3)
        end
    end

    -- Buttons row 1
    local function makeBtn(parent, txt, x, y, col)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(0,112,0,34)
        b.Position = UDim2.new(0,x,0,y)
        b.BackgroundColor3 = col or Color3.fromRGB(75,75,105)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        -- hover effect
        b.MouseEnter:Connect(function()
            pcall(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = b.BackgroundColor3:Lerp(Color3.fromRGB(255,255,255), 0.03)}):Play() end)
        end)
        b.MouseLeave:Connect(function()
            pcall(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = col}):Play() end)
        end)
        return b
    end

    local btnAuto = makeBtn(frame, "⛳ AutoLoop OFF", 10, 66, Color3.fromRGB(190,70,70))
    local btnSaveCP = makeBtn(frame, "📍 Save CP", 136, 66, Color3.fromRGB(70,120,200))
    local btnDelAll = makeBtn(frame, "🗑️ Delete All", 262, 66, Color3.fromRGB(200,120,60))

    -- Save box
    local lblSave = Instance.new("TextLabel", frame)
    lblSave.Size = UDim2.new(0,120,0,18)
    lblSave.Position = UDim2.new(0,12,0,106)
    lblSave.BackgroundTransparency = 1
    lblSave.Text = "Masukkan nama file"
    lblSave.Font = Enum.Font.GothamBold
    lblSave.TextSize = 12
    lblSave.TextColor3 = Color3.fromRGB(220,220,220)

    local inputBox = Instance.new("TextBox", frame)
    inputBox.Size = UDim2.new(0,210,0,24)
    inputBox.Position = UDim2.new(0,136,0,102)
    inputBox.BackgroundColor3 = Color3.fromRGB(36,36,48)
    inputBox.TextColor3 = Color3.fromRGB(240,240,240)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 13
    inputBox.PlaceholderText = "Contoh: MarVGunungPertama"
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0,6)

    local btnSaveFile = makeBtn(frame, "💾 Save Sekarang", 12, 138, Color3.fromRGB(90,150,220))
    local btnLoadFile = makeBtn(frame, "📂 Load Sekarang", 136, 138, Color3.fromRGB(80,190,140))
    local btnPickSave = makeBtn(frame, "Pilih File ▼", 262, 138, Color3.fromRGB(120,120,140))

    -- Delay / Respawn / Copy All
    local lblDelay = Instance.new("TextLabel", frame)
    lblDelay.Size = UDim2.new(0,70,0,18)
    lblDelay.Position = UDim2.new(0,12,0,178)
    lblDelay.BackgroundTransparency = 1
    lblDelay.Text = "Delay (s)"
    lblDelay.Font = Enum.Font.GothamBold
    lblDelay.TextSize = 12
    lblDelay.TextColor3 = Color3.fromRGB(220,220,220)

    local delayBox = Instance.new("TextBox", frame)
    delayBox.Size = UDim2.new(0,60,0,22)
    delayBox.Position = UDim2.new(0,90,0,174)
    delayBox.BackgroundColor3 = Color3.fromRGB(36,36,48)
    delayBox.TextColor3 = Color3.fromRGB(240,240,240)
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 13
    delayBox.Text = tostring(AutoDelay)
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0,6)

    local btnRespawn = makeBtn(frame, "♻️ Respawn OFF", 180, 174, Color3.fromRGB(200,170,60))
    local btnCopyAll = makeBtn(frame, "📋 Copy All", 260, 174, Color3.fromRGB(130,110,200))

    -- checkpoint scroll
    local scroll = Instance.new("ScrollingFrame", frame)
    scroll.Size = UDim2.new(1,-24,0,96)
    scroll.Position = UDim2.new(0,12,0,206)
    scroll.BackgroundColor3 = Color3.fromRGB(30,30,40)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,8)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0,6)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    -- populating cp list
    local function refresh_cp_list()
        for _,c in ipairs(scroll:GetChildren()) do
            if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
        end
        for i,cp in ipairs(Checkpoints) do
            local row = Instance.new("Frame", scroll)
            row.Size = UDim2.new(1,-12,0,28)
            row.LayoutOrder = i
            row.BackgroundTransparency = 1

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(0.5,0,1,0)
            nameLbl.Position = UDim2.new(0,6,0,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.Text = tostring(cp.Name or ("Checkpoint "..i))
            nameLbl.TextSize = 13
            nameLbl.TextColor3 = Color3.fromRGB(235,235,235)
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local tpBtn = Instance.new("TextButton", row)
            tpBtn.Size = UDim2.new(0,56,0,24)
            tpBtn.Position = UDim2.new(0.5, 6, 0, 2)
            tpBtn.Text = "TP"
            tpBtn.Font = Enum.Font.GothamBold
            tpBtn.TextSize = 12
            tpBtn.BackgroundColor3 = Color3.fromRGB(70,160,90)
            tpBtn.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0,6)
            tpBtn.MouseButton1Click:Connect(function()
                teleport_to(cp.Pos)
                notify("Teleport", "Teleported to "..tostring(cp.Name), 2)
            end)

            local editBtn = Instance.new("TextButton", row)
            editBtn.Size = UDim2.new(0,56,0,24)
            editBtn.Position = UDim2.new(0.5,68,0,2)
            editBtn.Text = "EDIT"
            editBtn.Font = Enum.Font.GothamBold
            editBtn.TextSize = 12
            editBtn.BackgroundColor3 = Color3.fromRGB(200,170,60)
            editBtn.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", editBtn).CornerRadius = UDim.new(0,6)
            editBtn.MouseButton1Click:Connect(function()
                local hrp = get_hrp()
                if not hrp then notify("Edit", "Character not available", 2); return end
                Checkpoints[i].Pos = hrp.Position
                Checkpoints[i].Name = tostring(Checkpoints[i].Name or ("Checkpoint "..i)) .. " (edited)"
                notify("Edit", "Checkpoint updated", 1.5)
                refresh_cp_list()
            end)

            local delBtn = Instance.new("TextButton", row)
            delBtn.Size = UDim2.new(0,56,0,24)
            delBtn.Position = UDim2.new(0.78,-10,0,2)
            delBtn.Text = "DEL"
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 12
            delBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
            delBtn.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0,6)
            delBtn.MouseButton1Click:Connect(function()
                table.remove(Checkpoints, i)
                notify("Delete", "Checkpoint removed", 1.2)
                refresh_cp_list()
            end)
        end
        scroll.CanvasSize = UDim2.new(0,0,0, math.max(0,#Checkpoints * 36))
    end

    refresh_cp_list()

    -- Dropdown helper (small)
    local function makeDropdown(anchorInstance, optionsFunc, onSelect)
        -- removes existing dropdown if any
        local parent = screen
        if parent:FindFirstChild("MarkerDropdown") then parent:FindFirstChild("MarkerDropdown"):Destroy() end

        local absPos = anchorInstance.AbsolutePosition
        local absSize = anchorInstance.AbsoluteSize

        local dropdown = Instance.new("Frame", parent)
        dropdown.Name = "MarkerDropdown"
        dropdown.Size = UDim2.new(0, 240, 0, 24)
        dropdown.Position = UDim2.new(0, absPos.X - 6, 0, absPos.Y + absSize.Y + 4)
        dropdown.BackgroundColor3 = Color3.fromRGB(28,28,36)
        dropdown.BorderSizePixel = 0
        dropdown.ZIndex = 100
        Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0,8)
        dropdown.Active = true

        local list = Instance.new("ScrollingFrame", dropdown)
        list.Size = UDim2.new(1, -8, 0, 160)
        list.Position = UDim2.new(0,4,0,4)
        list.BackgroundTransparency = 1
        list.ScrollBarThickness = 8
        Instance.new("UICorner", list).CornerRadius = UDim.new(0,6)
        list.ZIndex = 101

        local layout = Instance.new("UIListLayout", list)
        layout.Padding = UDim.new(0,6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder

        local options = optionsFunc() or {}
        if #options == 0 then
            dropdown.Size = UDim2.new(0,240,0,40)
            list.Size = UDim2.new(1,-8,0,28)
            local info = Instance.new("TextLabel", list)
            info.Size = UDim2.new(1,0,1,0)
            info.BackgroundTransparency = 1
            info.Text = "Belum ada file tersimpan."
            info.Font = Enum.Font.Gotham
            info.TextColor3 = Color3.fromRGB(200,200,200)
            info.TextSize = 13
        else
            for i,f in ipairs(options) do
                local btn = Instance.new("TextButton", list)
                btn.Size = UDim2.new(1, -12, 0, 28)
                btn.Position = UDim2.new(0,6,0,(i-1)*34)
                btn.BackgroundColor3 = Color3.fromRGB(40,40,52)
                btn.Font = Enum.Font.GothamBold
                btn.TextColor3 = Color3.fromRGB(240,240,240)
                btn.TextSize = 13
                btn.Text = f:gsub("%.json$","")
                btn.AutoButtonColor = true
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
                btn.LayoutOrder = i

                btn.MouseButton1Click:Connect(function()
                    -- call select callback
                    onSelect(btn.Text)
                    -- destroy dropdown
                    pcall(function() dropdown:Destroy() end)
                end)
            end
            -- set size based on count (max 6 items visible)
            local visible = math.min(#options, 6)
            dropdown.Size = UDim2.new(0,240,0, 8 + visible * 34)
            list.Size = UDim2.new(1,-8,0, visible * 34)
        end

        -- click outside to close
        local conn
        conn = screen.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local pos = inp.Position
                local gx, gy = pos.X, pos.Y
                local p0 = dropdown.AbsolutePosition
                local s0 = dropdown.AbsoluteSize
                if not (gx >= p0.X and gx <= p0.X + s0.X and gy >= p0.Y and gy <= p0.Y + s0.Y) then
                    pcall(function() dropdown:Destroy() end)
                    conn:Disconnect()
                end
            end
        end)
        return dropdown
    end

    -- Button behaviors
    btnSaveCP.MouseButton1Click:Connect(function()
        local hrp = get_hrp()
        if not hrp then notify("Save CP", "Character not available", 2); return end
        local idx = #Checkpoints + 1
        local name = "Checkpoint "..idx
        table.insert(Checkpoints, {Name = name, Pos = hrp.Position})
        refresh_cp_list()
        notify("Save CP", "Checkpoint saved: "..name, 2)
    end)

    btnDelAll.MouseButton1Click:Connect(function()
        Checkpoints = {}
        refresh_cp_list()
        notify("Delete All", "All checkpoints removed", 2)
    end)

    btnAuto.MouseButton1Click:Connect(function()
        AutoLoop = not AutoLoop
        btnAuto.Text = AutoLoop and "⏸️ AutoLoop ON" or "⛳ AutoLoop OFF"
        btnAuto.BackgroundColor3 = AutoLoop and Color3.fromRGB(80,200,100) or Color3.fromRGB(190,70,70)
        if AutoLoop then
            spawn(function()
                local i = 1
                while AutoLoop do
                    local cp = Checkpoints[i]
                    if cp and cp.Pos then teleport_to(cp.Pos) end
                    safe_wait(AutoDelay)
                    i = i + 1
                    if i > #Checkpoints then
                        if AutoRespawn then pcall(function() if localPlayer and localPlayer.Character then localPlayer.Character:BreakJoints() end end); if localPlayer then localPlayer.CharacterAdded:Wait() end end
                        i = 1
                    end
                end
            end)
        end
    end)

    btnRespawn.MouseButton1Click:Connect(function()
        AutoRespawn = not AutoRespawn
        btnRespawn.Text = AutoRespawn and "♻️ Respawn ON" or "♻️ Respawn OFF"
        notify("Respawn", AutoRespawn and "Enabled" or "Disabled", 1.4)
    end)

    delayBox.FocusLost:Connect(function()
        local v = tonumber(delayBox.Text)
        if v and v > 0 then AutoDelay = v; delayBox.Text = tostring(v); notify("Delay", "Delay set to "..tostring(v),1.2)
        else delayBox.Text = tostring(AutoDelay); notify("Delay", "Invalid value",1.2) end
    end)

    btnCopyAll.MouseButton1Click:Connect(function()
        local lines = {}
        for i,cp in ipairs(Checkpoints) do
            local p = cp.Pos
            table.insert(lines, string.format('{Name = "%s", Pos = Vector3.new(%.4f, %.4f, %.4f)},', cp.Name or ("CP_"..i), p.X, p.Y, p.Z))
        end
        local txt = table.concat(lines, "\n")
        if can_clipboard then pcall(function() if setclipboard then setclipboard(txt) elseif toclipboard then toclipboard(txt) end end); notify("Copy", "Formatted checkpoints copied",2)
        else notify("Copy", "Clipboard not available",2) end
    end)

    -- Save file: dropdown fill
    btnPickSave.MouseButton1Click:Connect(function()
        makeDropdown(btnPickSave, list_saved_files, function(selected)
            inputBox.Text = tostring(selected)
            notify("File Selected", selected, 1.2)
        end)
    end)

    btnSaveFile.MouseButton1Click:Connect(function()
        local name = tostring(inputBox.Text or "")
        if name == "" then notify("Save", "Masukkan nama file terlebih dahulu",2); return end
        if has_writefile then
            local ok,err = pcall(function() return save_file(name, Checkpoints, true) end)
            if ok then notify("Save", "Saved: "..tostring(name),2)
            else notify("Save", "Failed: "..tostring(err),3) end
        else
            local js = serialize_checkpoints(Checkpoints)
            if can_clipboard then pcall(function() if setclipboard then setclipboard(js) elseif toclipboard then toclipboard(js) end end); notify("Save", "No writefile — JSON copied to clipboard",4)
            else notify("Save", "No writefile & no clipboard",4) end
        end
    end)

    -- Load file: dropdown then load
    btnLoadFile.MouseButton1Click:Connect(function()
        makeDropdown(btnLoadFile, list_saved_files, function(selected)
            local cps, err = load_file(selected)
            if not cps then notify("Load", "Failed: "..tostring(err),3) return end
            Checkpoints = cps
            refresh_cp_list()
            notify("Load", "Loaded "..tostring(selected),2)
        end)
    end)

    -- try auto-load last (NOT auto-enabled per your request) - skipped

    -- Minimize system
    local minimized = false
    local miniBar = Instance.new("Frame", screen)
    miniBar.Name = "MiniBar"
    miniBar.Size = UDim2.new(0,260,0,44)
    miniBar.Position = UDim2.new(0.5,-130,0.06,0)
    miniBar.AnchorPoint = Vector2.new(0.5,0)
    miniBar.BackgroundColor3 = Color3.fromRGB(46,46,66)
    miniBar.BorderSizePixel = 0
    miniBar.ZIndex = 90
    miniBar.Active = true
    miniBar.Draggable = true
    Instance.new("UICorner", miniBar).CornerRadius = UDim.new(0,22)
    miniBar.Visible = false

    local miniLabel = Instance.new("TextLabel", miniBar)
    miniLabel.Size = UDim2.new(1,-16,1,0)
    miniLabel.Position = UDim2.new(0,12,0,0)
    miniLabel.BackgroundTransparency = 1
    miniLabel.Text = "🌈 DapzXPloit - Tools Mount"
    miniLabel.Font = Enum.Font.GothamBold
    miniLabel.TextSize = 14
    miniLabel.TextColor3 = Color3.fromRGB(240,240,240)
    miniLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- stroke RGB
    local stroke = Instance.new("UIStroke", miniBar)
    stroke.Thickness = 1.3
    stroke.Color = Color3.fromRGB(160,160,255)

    -- animate stroke color slowly (non-blocking)
    spawn(function()
        while miniBar and miniBar.Parent do
            for h = 0, 1, 0.02 do
                if not miniBar.Parent then return end
                stroke.Color = Color3.fromHSV(h, 0.6, 1)
                safe_wait(0.03)
            end
        end
    end)

    -- minimize behavior
    btnMin.MouseButton1Click:Connect(function()
        if minimized then return end
        minimized = true
        TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Size = UDim2.new(0,380,0,0)}):Play()
        wait(0.28)
        frame.Visible = false
        miniBar.Visible = true
    end)

    -- restore behavior (click or drag end)
    miniBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            if not minimized then return end
            minimized = false
            miniBar.Visible = false
            frame.Visible = true
            frame.Size = UDim2.new(0,380,0,0)
            TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Size = UDim2.new(0,380,0,300)}):Play()
        end
    end)

    -- return api if needed
    return {
        Screen = screen,
        Frame = frame,
        MiniBar = miniBar,
        Notify = notify
    }
end

-- Run
local ok, ret = pcall(buildUI)
if not ok then warn("[MarkerSaver] UI build failed:", ret) else print("[MarkerSaver] Ready (V3.5)") end
