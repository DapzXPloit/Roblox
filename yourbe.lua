-- Marker Saver - DapzXPloit (Delta-ready)
-- Paste whole file as UTF-8 without BOM

-- ========= Services & Environment =========
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local placeId = tostring(game.PlaceId or 0)

-- ========= Executor capability detection =========
local has_writefile  = type(writefile) == "function"
local has_readfile   = type(readfile) == "function"
local has_isfolder   = type(isfolder) == "function"
local has_makefolder = type(makefolder) == "function"
local has_listfiles  = type(listfiles) == "function"
local has_isfile     = type(isfile) == "function"
local has_delfile    = type(delfile) == "function" or type(deletefile) == "function"
local can_clipboard  = (type(setclipboard) == "function") or (type(toclipboard) == "function")

local SAVE_ROOT = "MarkerSaver"
local SAVE_FOLDER = SAVE_ROOT .. "/" .. placeId
local INDEX_PATH = SAVE_FOLDER .. "/__files_index.json"
local LAST_FILE_PATH = SAVE_FOLDER .. "/__last_file.txt"

-- ========= Utilities =========
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

local function filepath(name)
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

-- index helpers (fallback when listfiles not available)
local function read_index()
    if not has_readfile then return {} end
    ensure_folder()
    local ok, content = pcall(readfile, INDEX_PATH)
    if not ok or not content or content == "" then return {} end
    local ok2, dec = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok2 or type(dec) ~= "table" then return {} end
    return dec
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

local function list_files()
    local out = {}
    if has_listfiles and has_isfolder and isfolder(SAVE_FOLDER) then
        local all = listfiles(SAVE_FOLDER)
        for _,f in ipairs(all) do
            local s = f:match("^" .. SAVE_FOLDER .. "/(.+)$")
            if s then table.insert(out, s) end
        end
    else
        local idx = read_index()
        for _,v in ipairs(idx) do table.insert(out, v) end
    end
    table.sort(out)
    return out
end

-- ========= Serialization =========
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
        table.insert(out, {Name = cp.Name or ("Checkpoint_"..i), Pos = {X = x, Y = y, Z = z}})
    end
    return HttpService:JSONEncode({Name="MarkerFile", Checkpoints=out})
end

local function deserialize_checkpoints(json)
    local ok, dec = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(dec) ~= "table" or type(dec.Checkpoints) ~= "table" then
        return nil, "Invalid JSON or no checkpoints"
    end
    local cps = {}
    for i,cp in ipairs(dec.Checkpoints) do
        local nm = cp.Name or ("Checkpoint "..i)
        local p = cp.Pos
        if type(p) == "table" and p.X and p.Y and p.Z then
            table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(tonumber(p.X) or 0, tonumber(p.Y) or 0, tonumber(p.Z) or 0)})
        else
            table.insert(cps, {Name = tostring(nm), Pos = Vector3.new(0,0,0)})
        end
    end
    return cps
end

-- save/load/delete wrappers
local function save_file(name, checkpoints, overwrite)
    if not has_writefile then return false, "writefile not supported" end
    ensure_folder()
    local fname = sanitize_name(name)
    local path = filepath(fname)
    if has_isfile and isfile(path) and not overwrite then
        return false, "file exists"
    end
    local data = serialize_checkpoints(checkpoints)
    local ok, err = pcall(writefile, path, data)
    if ok then index_add(fname .. ".json"); return true end
    return false, tostring(err)
end

local function load_file(name)
    if not has_readfile then return nil, "readfile not supported" end
    ensure_folder()
    local fname = sanitize_name(name)
    local path = filepath(fname)
    local ok, content = pcall(readfile, path)
    if not ok or not content or content == "" then return nil, "file missing or empty" end
    local cps, err = deserialize_checkpoints(content)
    if not cps then return nil, err end
    return cps
end

local function delete_saved_file(name)
    if not (has_writefile and has_readfile) then return false, "file ops not supported" end
    ensure_folder()
    local fname = sanitize_name(name)
    local path = filepath(fname)
    delete_file(path)
    index_remove(fname .. ".json")
    return true
end

-- ========= Globals / Defaults =========
local Checkpoints = {
    {Name = "Spawn", Pos = Vector3.new(-925.52,371.61,37.74)},
    {Name = "Checkpoint 1", Pos = Vector3.new(-903.17,364.01,-428.28)},
    {Name = "Checkpoint 2", Pos = Vector3.new(-602.62,421.12,-545.52)},
    {Name = "Summit", Pos = Vector3.new(2496.26,2223.81,15.70)},
}
local CurrentCheckpoint = 1
local AutoLoop = false
local AutoOnce = false
local IsRunning = false
local AutoDelay = 1
local AutoRespawn = false
local TeleportYOffset = 5

-- Autosave config
local AutoSaveEnabled = false
local AutoSaveInterval = 10 -- seconds
local AutoSaveTicker = nil

-- ========= UI Creation =========
local function buildUI()
    -- parent to PlayerGui if possible else CoreGui
    local parentGui = (localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")) or game:GetService("CoreGui")
    if not parentGui then return false, "No suitable GUI parent" end

    -- clean existing
    pcall(function()
        local old = parentGui:FindFirstChild("MarkerSaverGUI")
        if old then old:Destroy() end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MarkerSaverGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = parentGui

    -- main frame (center default)
    local frame = Instance.new("Frame", screenGui)
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0,420,0,320)
    frame.Position = UDim2.new(0.5,-210,0.5,-160)
    frame.AnchorPoint = Vector2.new(0,0)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,16)

    -- title bar
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1,0,0,36)
    title.Position = UDim2.new(0,0,0,0)
    title.BackgroundColor3 = Color3.fromRGB(45,45,60)
    title.Text = "Marker Saver - DapzXPloit"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.BorderSizePixel = 0
    Instance.new("UICorner", title).CornerRadius = UDim.new(0,16)

    -- close & minimize buttons
    local btnClose = Instance.new("TextButton", frame)
    btnClose.Size = UDim2.new(0,34,0,30)
    btnClose.Position = UDim2.new(1,-38,0,3)
    btnClose.Text = "✕"
    btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 16
    btnClose.BackgroundColor3 = Color3.fromRGB(190,60,60)
    btnClose.TextColor3 = Color3.new(1,1,1)
    btnClose.BorderSizePixel = 0
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0,12)

    local btnMin = Instance.new("TextButton", frame)
    btnMin.Size = UDim2.new(0,34,0,30)
    btnMin.Position = UDim2.new(1,-78,0,3)
    btnMin.Text = "—"
    btnMin.Font = Enum.Font.GothamBold
    btnMin.TextSize = 18
    btnMin.BackgroundColor3 = Color3.fromRGB(100,100,120)
    btnMin.TextColor3 = Color3.new(1,1,1)
    btnMin.BorderSizePixel = 0
    Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0,12)

    -- status label
    local statusLbl = Instance.new("TextLabel", frame)
    statusLbl.Size = UDim2.new(0.6,0,0,20)
    statusLbl.Position = UDim2.new(0,10,0,40)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = ""
    statusLbl.TextColor3 = Color3.fromRGB(200,200,200)
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 13
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left

    local function notify(text, dur)
        statusLbl.Text = text or ""
        dur = tonumber(dur) or 3
        spawn(function()
            local t0 = tick()
            while tick()-t0 < dur do
                task.wait(0.1)
            end
            if statusLbl.Text == text then statusLbl.Text = "" end
        end)
    end

    -- main buttons
    local function btnCreator(text, x, y, color)
        local b = Instance.new("TextButton", frame)
        b.Size = UDim2.new(0,120,0,36)
        b.Position = UDim2.new(0,x,0,y)
        b.BackgroundColor3 = color or Color3.fromRGB(70,70,90)
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Color3.new(1,1,1)
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        return b
    end

    local toggleLoopBtn = btnCreator("AutoLoop OFF", 10, 64, Color3.fromRGB(60,150,80))
    local saveCPBtn     = btnCreator("Save CP", 150, 64, Color3.fromRGB(70,120,200))
    local deleteAllBtn  = btnCreator("Delete All", 290, 64, Color3.fromRGB(200,80,80))

    local saveFileBtn   = btnCreator("Save File", 10, 110, Color3.fromRGB(90,150,200))
    local loadFileBtn   = btnCreator("Load File", 150, 110, Color3.fromRGB(80,180,140))
    local respawnBtn    = btnCreator("Respawn OFF", 290, 110, Color3.fromRGB(200,180,60))

    -- delay label and box
    local delayLbl = Instance.new("TextLabel", frame)
    delayLbl.Size = UDim2.new(0,80,0,22)
    delayLbl.Position = UDim2.new(0,10,0,150)
    delayLbl.BackgroundTransparency = 1
    delayLbl.Text = "Delay (s):"
    delayLbl.TextColor3 = Color3.fromRGB(230,230,230)
    delayLbl.Font = Enum.Font.Gotham
    delayLbl.TextSize = 13

    local delayBox = Instance.new("TextBox", frame)
    delayBox.Size = UDim2.new(0,60,0,22)
    delayBox.Position = UDim2.new(0,90,0,150)
    delayBox.BackgroundColor3 = Color3.fromRGB(45,45,60)
    delayBox.TextColor3 = Color3.fromRGB(255,255,255)
    delayBox.Text = tostring(AutoDelay)
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 13
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0,6)

    -- autosave toggle + interval
    local autosaveToggle = Instance.new("TextButton", frame)
    autosaveToggle.Size = UDim2.new(0,120,0,28)
    autosaveToggle.Position = UDim2.new(0,200,0,146)
    autosaveToggle.Text = "Autosave OFF"
    autosaveToggle.Font = Enum.Font.GothamBold
    autosaveToggle.TextSize = 13
    autosaveToggle.BackgroundColor3 = Color3.fromRGB(100,100,100)
    Instance.new("UICorner", autosaveToggle).CornerRadius = UDim.new(0,6)

    local autosaveIntervalBox = Instance.new("TextBox", frame)
    autosaveIntervalBox.Size = UDim2.new(0,60,0,22)
    autosaveIntervalBox.Position = UDim2.new(0,330,0,146)
    autosaveIntervalBox.BackgroundColor3 = Color3.fromRGB(45,45,60)
    autosaveIntervalBox.TextColor3 = Color3.fromRGB(255,255,255)
    autosaveIntervalBox.Text = tostring(AutoSaveInterval)
    autosaveIntervalBox.Font = Enum.Font.Gotham
    autosaveIntervalBox.TextSize = 13
    Instance.new("UICorner", autosaveIntervalBox).CornerRadius = UDim.new(0,6)

    -- save/load prompt boxes
    local savePrompt = Instance.new("TextBox", frame)
    savePrompt.Size = UDim2.new(0,150,0,26)
    savePrompt.Position = UDim2.new(0,10,0,186)
    savePrompt.PlaceholderText = "Save file name..."
    savePrompt.BackgroundColor3 = Color3.fromRGB(40,40,55)
    savePrompt.TextColor3 = Color3.fromRGB(230,230,230)
    savePrompt.Font = Enum.Font.Gotham
    savePrompt.TextSize = 14
    Instance.new("UICorner", savePrompt).CornerRadius = UDim.new(0,6)

    local loadPrompt = Instance.new("TextBox", frame)
    loadPrompt.Size = UDim2.new(0,150,0,26)
    loadPrompt.Position = UDim2.new(0,170,0,186)
    loadPrompt.PlaceholderText = "Load file name..."
    loadPrompt.BackgroundColor3 = Color3.fromRGB(40,40,55)
    loadPrompt.TextColor3 = Color3.fromRGB(230,230,230)
    loadPrompt.Font = Enum.Font.Gotham
    loadPrompt.TextSize = 14
    Instance.new("UICorner", loadPrompt).CornerRadius = UDim.new(0,6)

    local quickCopyBtn = Instance.new("TextButton", frame)
    quickCopyBtn.Size = UDim2.new(0,120,0,28)
    quickCopyBtn.Position = UDim2.new(0,330,0,186)
    quickCopyBtn.Text = "Copy All"
    quickCopyBtn.Font = Enum.Font.GothamBold
    quickCopyBtn.TextSize = 13
    quickCopyBtn.BackgroundColor3 = Color3.fromRGB(120,120,180)
    Instance.new("UICorner", quickCopyBtn).CornerRadius = UDim.new(0,6)

    -- scroll list
    local scroll = Instance.new("ScrollingFrame", frame)
    scroll.Size = UDim2.new(1,-40,0,110)
    scroll.Position = UDim2.new(0,20,0,220)
    scroll.BackgroundColor3 = Color3.fromRGB(35,35,45)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,8)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0,6)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    -- helper small button creator
    local function smallBtn(parent, text, w, col)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(0,w or 70,0,28)
        b.BackgroundColor3 = col or Color3.fromRGB(100,180,120)
        b.Text = text
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        return b
    end

    -- populate list refresh
    local function refresh_list()
        -- clear old rows
        for _,c in ipairs(scroll:GetChildren()) do
            if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
        end
        for i,cp in ipairs(Checkpoints) do
            local row = Instance.new("Frame", scroll)
            row.Size = UDim2.new(1,-24,0,34)
            row.BackgroundTransparency = 1
            row.LayoutOrder = i

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(0.5,0,1,0)
            nameLbl.Position = UDim2.new(0,6,0,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = cp.Name or ("Checkpoint "..i)
            nameLbl.TextColor3 = Color3.fromRGB(230,230,230)
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 14
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local tp = smallBtn(row, "TP", 56, Color3.fromRGB(60,170,90))
            tp.Position = UDim2.new(0.5, 6, 0, 3)
            tp.MouseButton1Click:Connect(function()
                local hrp = (localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")) or nil
                if not hrp then notify("Character not available",2); return end
                pcall(function() hrp.CFrame = CFrame.new(cp.Pos + Vector3.new(0, TeleportYOffset, 0)) end)
                notify("Teleported to "..tostring(cp.Name),1.5)
                CurrentCheckpoint = i
            end)

            local edit = smallBtn(row, "EDIT", 56, Color3.fromRGB(200,180,60))
            edit.Position = UDim2.new(0.5, 68, 0, 3)
            edit.MouseButton1Click:Connect(function()
                local hrp = (localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")) or nil
                if not hrp then notify("Character not available",2); return end
                Checkpoints[i].Pos = hrp.Position
                Checkpoints[i].Name = (Checkpoints[i].Name or ("Checkpoint "..i)) .. " (edited)"
                notify("Checkpoint "..i.." updated",2)
                refresh_list()
            end)

            local del = smallBtn(row, "DEL", 56, Color3.fromRGB(200,80,80))
            del.Position = UDim2.new(0.8, -10, 0, 3)
            del.MouseButton1Click:Connect(function()
                table.remove(Checkpoints, i)
                notify("Checkpoint "..i.." removed",1.2)
                refresh_list()
            end)
        end
        local count = #Checkpoints
        scroll.CanvasSize = UDim2.new(0,0,0, count * 42)
    end

    -- button behaviors
    toggleLoopBtn.MouseButton1Click:Connect(function()
        AutoLoop = not AutoLoop
        toggleLoopBtn.Text = AutoLoop and "AutoLoop ON" or "AutoLoop OFF"
        if AutoLoop then
            AutoOnce = false
            CurrentCheckpoint = 1
            spawn(function() -- safe spawn
                while AutoLoop do
                    local cp = Checkpoints[CurrentCheckpoint]
                    if cp and cp.Pos then
                        local hrp = (localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")) or nil
                        if hrp then pcall(function() hrp.CFrame = CFrame.new(cp.Pos + Vector3.new(math.random(-0.2,0.2), TeleportYOffset, math.random(-0.2,0.2))) end) end
                    end
                    task.wait(AutoDelay + math.random()*0.2)
                    if CurrentCheckpoint >= #Checkpoints then
                        if AutoRespawn then
                            pcall(function() if localPlayer and localPlayer.Character then localPlayer.Character:BreakJoints() end end)
                            if localPlayer then localPlayer.CharacterAdded:Wait() end
                            task.wait(0.1)
                        end
                        CurrentCheckpoint = 1
                    else
                        CurrentCheckpoint = CurrentCheckpoint + 1
                    end
                    task.wait(0.05)
                end
                notify("AutoLoop stopped",1.2)
            end)
            notify("AutoLoop started",1.2)
        else
            notify("AutoLoop stopped",1.2)
        end
    end)

    saveCPBtn.MouseButton1Click:Connect(function()
        local hrp = (localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")) or nil
        if not hrp then notify("Character not available",2); return end
        local idx = #Checkpoints + 1
        local name = "Checkpoint " .. tostring(idx)
        table.insert(Checkpoints, {Name = name, Pos = hrp.Position})
        refresh_list()
        notify("Saved "..name,1.5)
    end)

    deleteAllBtn.MouseButton1Click:Connect(function()
        Checkpoints = {}
        refresh_list()
        notify("All checkpoints removed",1.2)
    end)

    respawnBtn.MouseButton1Click:Connect(function()
        AutoRespawn = not AutoRespawn
        respawnBtn.Text = AutoRespawn and "Respawn ON" or "Respawn OFF"
        notify("Respawn "..(AutoRespawn and "enabled" or "disabled"),1.2)
    end)

    saveFileBtn.MouseButton1Click:Connect(function()
        local name = tostring(savePrompt.Text or "")
        if name == "" then notify("Enter filename",2); return end
        if has_writefile then
            local ok, err = save_file(name, Checkpoints, true)
            if ok then
                notify("Saved to "..name,2)
                pcall(function() writefile(LAST_FILE_PATH, name) end)
            else
                notify("Save failed: "..tostring(err),3)
            end
        else
            local js = serialize_checkpoints(Checkpoints)
            if can_clipboard then
                pcall(function() if setclipboard then setclipboard(js) elseif toclipboard then toclipboard(js) end end)
                notify("No writefile — JSON copied to clipboard",4)
            else
                notify("No writefile & no clipboard",4)
            end
        end
    end)

    loadFileBtn.MouseButton1Click:Connect(function()
        local name = tostring(loadPrompt.Text or "")
        if name == "" then notify("Enter filename to load",2); return end
        if has_readfile then
            local cps, err = load_file(name)
            if not cps then notify("Load failed: "..tostring(err),3); return end
            Checkpoints = cps
            refresh_list()
            notify("Loaded "..name,2)
            pcall(function() writefile(LAST_FILE_PATH, name) end)
        else
            notify("readfile unsupported. Use clipboard JSON to import",4)
        end
    end)

    quickCopyBtn.MouseButton1Click:Connect(function()
        local lines = {}
        for i,cp in ipairs(Checkpoints) do
            local p = cp.Pos
            table.insert(lines, string.format('{Name = "%s", Pos = Vector3.new(%.4f, %.4f, %.4f)},', cp.Name or ("CP_"..i), p.X, p.Y, p.Z))
        end
        local txt = table.concat(lines, "\n")
        if can_clipboard then pcall(function() if setclipboard then setclipboard(txt) elseif toclipboard then toclipboard(txt) end end); notify("Formatted checkpoints copied",2)
        else notify("Clipboard not available",2) end
    end)

    -- delay box update
    delayBox.FocusLost:Connect(function(enter)
        local v = tonumber(delayBox.Text)
        if v and v > 0 then AutoDelay = v; delayBox.Text = tostring(v); notify("Delay set to "..tostring(v),1)
        else delayBox.Text = tostring(AutoDelay); notify("Invalid delay",1) end
    end)

    -- autosave toggle
    local function start_autosave()
        if AutoSaveTicker then return end
        AutoSaveTicker = RunService.Heartbeat:Connect(function(dt)
            -- simple timer using os.time
        end)
        -- simpler: spawn a loop
        spawn(function()
            while AutoSaveEnabled do
                task.wait(tonumber(autosaveIntervalBox.Text) or AutoSaveInterval)
                if AutoSaveEnabled and has_writefile then
                    local name = "Autosave_" .. tostring(os.time())
                    pcall(function() save_file(name, Checkpoints, true) end)
                end
            end
            AutoSaveTicker = nil
        end)
    end

    autosaveToggle.MouseButton1Click:Connect(function()
        AutoSaveEnabled = not AutoSaveEnabled
        autosaveToggle.Text = AutoSaveEnabled and "Autosave ON" or "Autosave OFF"
        autosaveToggle.BackgroundColor3 = AutoSaveEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(100,100,100)
        if AutoSaveEnabled then
            start_autosave()
            notify("Autosave enabled",1.5)
        else
            notify("Autosave disabled",1.2)
        end
    end)

    autosaveIntervalBox.FocusLost:Connect(function()
        local v = tonumber(autosaveIntervalBox.Text)
        if v and v >= 5 then AutoSaveInterval = v; notify("Autosave interval set to "..tostring(v).."s",1) else autosaveIntervalBox.Text = tostring(AutoSaveInterval); notify("Invalid interval (min 5s)",2) end
    end)

    -- close & minimize
    local minimized = false
    btnClose.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    btnMin.MouseButton1Click:Connect(function()
        minimized = not minimized
        for _,c in ipairs(frame:GetChildren()) do
            if c ~= title and c ~= btnClose and c ~= btnMin then
                c.Visible = not minimized
            end
        end
        frame.Size = minimized and UDim2.new(0,200,0,40) or UDim2.new(0,420,0,320)
    end)

    -- try auto-load last file
    pcall(function()
        if has_readfile then
            local ok, last = pcall(readfile, LAST_FILE_PATH)
            if ok and last and last ~= "" then
                local cps = select(1, pcall(load_file, last))
                if type(cps) == "table" then Checkpoints = cps; refresh_list(); notify("Auto-loaded "..tostring(last),2) end
            end
        end
    end)

    -- initial refresh & notify
    refresh_list()
    notify("Marker Saver ready. Save/Load uses executor file API if available.",4)

    return true
end

-- ========= Build UI =========
local ok, err = pcall(buildUI)
if not ok then
    warn("[MarkerSaver] UI build error:", err)
else
    -- everything built
end