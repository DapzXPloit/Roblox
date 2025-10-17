-- MarkerSaverClient (LocalScript)
-- Put this in StarterGui
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("MarkerSaverRemotes")

local remoteSave = remotesFolder:WaitForChild("SaveFile")
local remoteLoad = remotesFolder:WaitForChild("LoadFile")
local remoteList = remotesFolder:WaitForChild("ListFiles")
local remoteDelete = remotesFolder:WaitForChild("DeleteFile")

-- Default checkpoints (example)
local Checkpoints = {
    {Name="Spawn", Pos=Vector3.new(-925.52,371.61,37.74)},
    {Name="Checkpoint 1", Pos=Vector3.new(-903.17,364.01,-428.28)},
    {Name="Checkpoint 2", Pos=Vector3.new(-602.62,421.12,-545.52)},
    {Name="Summit", Pos=Vector3.new(2496.26,2223.81,15.70)},
}

local AutoLoop = false
local AutoDelay = 0.8
local AutoRespawn = false

-- Utility: notifications (use SetCore if available)
local function notify_default(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 3})
    end)
end

-- Helper: get player HRP
local function getHRP()
    if not player.Character then return nil end
    return player.Character:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(vec)
    local hrp = getHRP()
    if hrp then
        pcall(function() hrp.CFrame = CFrame.new(vec + Vector3.new(0,5,0)) end)
    end
end

-- Build GUI (replica look + buttons)
local function buildGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MarkerSaverGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    -- Main frame (compact like image)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,420,0,320)
    frame.Position = UDim2.new(0.12,0,0.55,0)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    frame.Active = true
    frame.Draggable = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,18)

    -- header
    local header = Instance.new("Frame", frame)
    header.Size = UDim2.new(1,0,0,44)
    header.BackgroundColor3 = Color3.fromRGB(48,48,66)
    header.Position = UDim2.new(0,0,0,0)
    Instance.new("UICorner", header).CornerRadius = UDim.new(0,18)

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1,-100,1,0)
    title.Position = UDim2.new(0,20,0,0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Marker Saver - DapzXPloit"
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(245,245,245)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local btnMin = Instance.new("TextButton", header)
    btnMin.Size = UDim2.new(0,36,0,36)
    btnMin.Position = UDim2.new(1,-46,0,4)
    btnMin.Text = "—"
    btnMin.Font = Enum.Font.GothamBold
    btnMin.TextColor3 = Color3.fromRGB(255,255,255)
    btnMin.BackgroundColor3 = Color3.fromRGB(88,88,110)
    btnMin.BorderSizePixel = 0
    Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0,16)

    -- Top row buttons (AutoLoop, Save CP, Delete All)
    local function newBtn(parent, text, posX)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(0,120,0,38)
        b.Position = UDim2.new(0,posX,0,60)
        b.BackgroundColor3 = Color3.fromRGB(70,110,180)
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.TextSize = 16
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,12)
        return b
    end

    local btnAuto = newBtn(frame, "⛳ AutoLoop OFF", 12)
    btnAuto.BackgroundColor3 = Color3.fromRGB(55,180,90)
    local btnSaveCP = newBtn(frame, "📍 Save CP", 150)
    btnSaveCP.BackgroundColor3 = Color3.fromRGB(70,120,200)
    local btnDelAll = newBtn(frame, "🗑️ Delete All", 288)
    btnDelAll.BackgroundColor3 = Color3.fromRGB(210,120,60)

    -- Second row (Save File, Load File, Respawn)
    local btnSaveFile = newBtn(frame, "💾 Save File", 12)
    btnSaveFile.BackgroundColor3 = Color3.fromRGB(100,150,205)
    local btnLoadFile = newBtn(frame, "📂 Load File", 150)
    btnLoadFile.BackgroundColor3 = Color3.fromRGB(90,200,140)
    local btnRespawn = newBtn(frame, "♻️ Respawn OFF", 288)
    btnRespawn.BackgroundColor3 = Color3.fromRGB(200,180,60)

    -- small label "Ganti Delay(: 0.01)"
    local delayLabel = Instance.new("TextLabel", frame)
    delayLabel.Size = UDim2.new(0,300,0,20)
    delayLabel.Position = UDim2.new(0,12,0,140)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 14
    delayLabel.TextColor3 = Color3.fromRGB(235,235,235)
    delayLabel.Text = "Ganti Delay(: 0.01)"

    -- Save/Load panels (hidden dropdown style)
    local function makeSmallPanel(parent)
        local p = Instance.new("Frame", parent)
        p.Size = UDim2.new(0,360,0,150)
        p.Position = UDim2.new(0,20,0,160)
        p.BackgroundColor3 = Color3.fromRGB(24,24,34)
        p.BorderSizePixel = 0
        p.Visible = false
        Instance.new("UICorner", p).CornerRadius = UDim.new(0,12)
        return p
    end

    local savePanel = makeSmallPanel(frame)
    local loadPanel = makeSmallPanel(frame)

    -- Save Panel contents
    local saveTitle = Instance.new("TextLabel", savePanel)
    saveTitle.Size = UDim2.new(1, -16, 0, 28)
    saveTitle.Position = UDim2.new(0,8,0,8)
    saveTitle.BackgroundTransparency = 1
    saveTitle.Font = Enum.Font.GothamBold
    saveTitle.Text = "Save File"
    saveTitle.TextColor3 = Color3.fromRGB(230,230,230)
    saveTitle.TextSize = 16

    local saveInput = Instance.new("TextBox", savePanel)
    saveInput.Size = UDim2.new(1,-32,0,30)
    saveInput.Position = UDim2.new(0,8,0,42)
    saveInput.PlaceholderText = "Masukkan nama file..."
    saveInput.Font = Enum.Font.Gotham
    saveInput.TextSize = 14
    saveInput.TextColor3 = Color3.fromRGB(245,245,245)
    saveInput.BackgroundColor3 = Color3.fromRGB(38,38,48)
    Instance.new("UICorner", saveInput).CornerRadius = UDim.new(0,8)

    local saveNow = Instance.new("TextButton", savePanel)
    saveNow.Size = UDim2.new(1,-32,0,36)
    saveNow.Position = UDim2.new(0,8,0,78)
    saveNow.Text = "Save Sekarang"
    saveNow.Font = Enum.Font.GothamBold
    saveNow.TextSize = 16
    saveNow.BackgroundColor3 = Color3.fromRGB(64,130,220)
    saveNow.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", saveNow).CornerRadius = UDim.new(0,10)

    -- small choose file dropdown for save panel
    local saveChoose = Instance.new("TextButton", savePanel)
    saveChoose.Size = UDim2.new(1,-32,0,30)
    saveChoose.Position = UDim2.new(0,8,0,118)
    saveChoose.Text = "Pilih File..."
    saveChoose.Font = Enum.Font.Gotham
    saveChoose.TextSize = 14
    saveChoose.BackgroundColor3 = Color3.fromRGB(38,38,48)
    saveChoose.TextColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", saveChoose).CornerRadius = UDim.new(0,8)

    -- Load Panel contents
    local loadTitle = Instance.new("TextLabel", loadPanel)
    loadTitle.Size = UDim2.new(1, -16, 0, 28)
    loadTitle.Position = UDim2.new(0,8,0,8)
    loadTitle.BackgroundTransparency = 1
    loadTitle.Font = Enum.Font.GothamBold
    loadTitle.Text = "Load File"
    loadTitle.TextColor3 = Color3.fromRGB(230,230,230)
    loadTitle.TextSize = 16

    local loadChoose = Instance.new("TextButton", loadPanel)
    loadChoose.Size = UDim2.new(1,-32,0,30)
    loadChoose.Position = UDim2.new(0,8,0,42)
    loadChoose.Text = "Pilih File..."
    loadChoose.Font = Enum.Font.Gotham
    loadChoose.TextSize = 14
    loadChoose.BackgroundColor3 = Color3.fromRGB(38,38,48)
    loadChoose.TextColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", loadChoose).CornerRadius = UDim.new(0,8)

    local loadNow = Instance.new("TextButton", loadPanel)
    loadNow.Size = UDim2.new(1,-32,0,36)
    loadNow.Position = UDim2.new(0,8,0,84)
    loadNow.Text = "Load Sekarang"
    loadNow.Font = Enum.Font.GothamBold
    loadNow.TextSize = 16
    loadNow.BackgroundColor3 = Color3.fromRGB(64,130,220)
    loadNow.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", loadNow).CornerRadius = UDim.new(0,10)

    local loadListFrame = Instance.new("Frame", loadPanel)
    loadListFrame.Size = UDim2.new(1,-32,0,40)
    loadListFrame.Position = UDim2.new(0,8,0,128)
    loadListFrame.BackgroundTransparency = 1

    -- Small dropdown implementation (reusable)
    local currentDropdown = nil
    local function showDropdown(anchorButton, options, onSelect)
        -- clean existing
        if currentDropdown and currentDropdown.Parent then currentDropdown:Destroy() end
        currentDropdown = Instance.new("Frame", gui)
        currentDropdown.Size = UDim2.new(0,320,0,28)
        local aPos = anchorButton.AbsolutePosition
        currentDropdown.Position = UDim2.new(0, aPos.X, 0, aPos.Y + anchorButton.AbsoluteSize.Y + 6)
        currentDropdown.BackgroundColor3 = Color3.fromRGB(30,30,40)
        currentDropdown.BorderSizePixel = 0
        Instance.new("UICorner", currentDropdown).CornerRadius = UDim.new(0,8)
        -- list frame
        local sc = Instance.new("ScrollingFrame", currentDropdown)
        sc.Size = UDim2.new(1,-8,1, -8)
        sc.Position = UDim2.new(0,4,0,4)
        sc.BackgroundTransparency = 1
        sc.ScrollBarThickness = 8
        local layout = Instance.new("UIListLayout", sc)
        layout.Padding = UDim.new(0,6)
        -- add items
        local maxShow = 6
        for i,opt in ipairs(options) do
            local b = Instance.new("TextButton", sc)
            b.Size = UDim2.new(1,-12,0,30)
            b.Position = UDim2.new(0,6,0,(i-1)*36)
            b.BackgroundColor3 = Color3.fromRGB(38,38,48)
            b.Font = Enum.Font.Gotham
            b.Text = tostring(opt)
            b.TextSize = 14
            b.TextColor3 = Color3.fromRGB(245,245,245)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
            b.LayoutOrder = i
            b.MouseButton1Click:Connect(function()
                onSelect(tostring(opt))
                if currentDropdown then currentDropdown:Destroy(); currentDropdown = nil end
            end)
        end
        -- resize dropdown height based on items
        local visible = math.min(#options, maxShow)
        local totalH = visible * 36 + 8
        currentDropdown.Size = UDim2.new(0,320,0,totalH)
        sc.CanvasSize = UDim2.new(0,0,0,#options * 36)
        -- close when click outside
        local conn
        conn = gui.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                if currentDropdown and currentDropdown.Parent then
                    local p0 = currentDropdown.AbsolutePosition
                    local s0 = currentDropdown.AbsoluteSize
                    local gx, gy = inp.Position.X, inp.Position.Y
                    if not (gx >= p0.X and gx <= p0.X + s0.X and gy >= p0.Y and gy <= p0.Y + s0.Y) then
                        currentDropdown:Destroy()
                        currentDropdown = nil
                        conn:Disconnect()
                    end
                end
            end
        end)
    end

    -- fill dropdown helper: ask server for list
    local function getServerFileList()
        local ok, res = pcall(function() return remoteList:InvokeServer() end)
        if not ok then
            notify_default("Error", "Failed fetching file list", 3)
            return {}
        end
        return res or {}
    end

    -- Save actions
    saveNow.MouseButton1Click:Connect(function()
        local name = tostring(saveInput.Text or "")
        if name == "" then
            notify_default("Save", "Masukkan nama file dulu", 2); return
        end
        -- send to server
        local ok, res = pcall(function() return remoteSave:InvokeServer(name, Checkpoints) end)
        if not ok then notify_default("Save", "Save failed", 3); return end
        if res == true or res[1] == true then
            notify_default("Save", "File tersimpan: "..tostring(name), 2)
        else
            notify_default("Save", "Save failed: "..tostring(res), 3)
        end
    end)

    saveChoose.MouseButton1Click:Connect(function()
        local list = getServerFileList()
        if #list == 0 then
            notify_default("Save", "Belum ada file tersimpan", 2); return
        end
        showDropdown(saveChoose, list, function(chosen)
            saveInput.Text = tostring(chosen)
            notify_default("Save", "File dipilih: "..tostring(chosen), 1.6)
        end)
    end)

    -- Load actions
    loadNow.MouseButton1Click:Connect(function()
        notify_default("Load", "Pilih file lewat dropdown", 2)
    end)

    loadChoose.MouseButton1Click:Connect(function()
        local list = getServerFileList()
        if #list == 0 then notify_default("Load", "Belum ada file tersimpan", 2); return end
        showDropdown(loadChoose, list, function(chosen)
            -- ask server for that file
            local ok, res = pcall(function() return remoteLoad:InvokeServer(chosen) end)
            if not ok or not res then
                notify_default("Load", "Load failed: "..tostring(res or "error"), 3); return
            end
            -- res is checkpoint table
            Checkpoints = res
            refreshCPList()
            notify_default("Load", "Loaded: "..tostring(chosen), 2)
        end)
    end)

    -- Delete from dropdown (long press on dropdown selection would be better, but provide a right-click alternative)
    -- For simplicity, add a small "Delete File" when dropdown shows? We'll provide a separate UI button when a file is selected in Save panel:
    local btnDeleteSelected = Instance.new("TextButton", savePanel)
    btnDeleteSelected.Size = UDim2.new(0,120,0,30)
    btnDeleteSelected.Position = UDim2.new(1,-128,0,118)
    btnDeleteSelected.Text = "Hapus File"
    btnDeleteSelected.Font = Enum.Font.GothamBold
    btnDeleteSelected.TextSize = 13
    btnDeleteSelected.BackgroundColor3 = Color3.fromRGB(170,60,60)
    btnDeleteSelected.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", btnDeleteSelected).CornerRadius = UDim.new(0,6)

    btnDeleteSelected.MouseButton1Click:Connect(function()
        local name = tostring(saveInput.Text or "")
        if name == "" then notify_default("Delete", "Pilih atau ketik nama file", 2); return end
        local ok, res = pcall(function() return remoteDelete:InvokeServer(name) end)
        if not ok then notify_default("Delete", "Delete failed", 3); return end
        if res == true or res[1] == true then
            notify_default("Delete", "File dihapus: "..name, 2)
        else
            notify_default("Delete", "Delete failed: "..tostring(res), 3)
        end
    end)

    -- Checkpoint list area (populate rows)
    local listArea = Instance.new("Frame", frame)
    listArea.Size = UDim2.new(1,-24,0,120)
    listArea.Position = UDim2.new(0,12,0,184)
    listArea.BackgroundTransparency = 1
    Instance.new("UICorner", listArea).CornerRadius = UDim.new(0,8)

    local sc = Instance.new("ScrollingFrame", listArea)
    sc.Size = UDim2.new(1,0,1,0)
    sc.BackgroundColor3 = Color3.fromRGB(26,26,34)
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 8
    Instance.new("UICorner", sc).CornerRadius = UDim.new(0,8)

    local layout = Instance.new("UIListLayout", sc)
    layout.Padding = UDim.new(0,6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    function refreshCPList()
        for _,c in ipairs(sc:GetChildren()) do
            if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
        end
        for i,cp in ipairs(Checkpoints) do
            local row = Instance.new("Frame", sc)
            row.Size = UDim2.new(1,-12,0,36)
            row.BackgroundColor3 = Color3.fromRGB(38,38,48)
            row.LayoutOrder = i
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(0.5,0,1,0)
            nameLbl.Position = UDim2.new(0,8,0,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.Text = tostring(cp.Name)
            nameLbl.TextSize = 15
            nameLbl.TextColor3 = Color3.fromRGB(245,245,245)
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left

            -- TP button
            local tp = Instance.new("TextButton", row)
            tp.Size = UDim2.new(0,72,0,28)
            tp.Position = UDim2.new(0.5,6,0,4)
            tp.Text = "TP"
            tp.Font = Enum.Font.GothamBold
            tp.TextSize = 14
            tp.BackgroundColor3 = Color3.fromRGB(70,200,120)
            Instance.new("UICorner", tp).CornerRadius = UDim.new(0,8)
            tp.MouseButton1Click:Connect(function() teleportTo(cp.Pos) notify_default("Teleport", "Teleported to "..tostring(cp.Name), 2) end)

            -- EDIT
            local edit = Instance.new("TextButton", row)
            edit.Size = UDim2.new(0,72,0,28)
            edit.Position = UDim2.new(0.7, -30,0,4)
            edit.Text = "EDIT"
            edit.Font = Enum.Font.GothamBold
            edit.TextSize = 14
            edit.BackgroundColor3 = Color3.fromRGB(205,180,70)
            Instance.new("UICorner", edit).CornerRadius = UDim.new(0,8)
            edit.MouseButton1Click:Connect(function()
                local hrp = getHRP()
                if not hrp then notify_default("Edit","Karakter tidak tersedia",2); return end
                Checkpoints[i].Pos = hrp.Position
                Checkpoints[i].Name = tostring(Checkpoints[i].Name or ("CP "..i)) .. " (edited)"
                refreshCPList()
                notify_default("Edit","Checkpoint updated",1.6)
            end)

            -- DEL
            local del = Instance.new("TextButton", row)
            del.Size = UDim2.new(0,72,0,28)
            del.Position = UDim2.new(0.9, -78,0,4)
            del.Text = "DEL"
            del.Font = Enum.Font.GothamBold
            del.TextSize = 14
            del.BackgroundColor3 = Color3.fromRGB(200,80,80)
            Instance.new("UICorner", del).CornerRadius = UDim.new(0,8)
            del.MouseButton1Click:Connect(function()
                table.remove(Checkpoints, i)
                refreshCPList()
                notify_default("Delete", "Checkpoint removed", 1.6)
            end)
        end
        sc.CanvasSize = UDim2.new(0,0,0, math.max(0,#Checkpoints*44))
    end

    refreshCPList()

    -- buttons functionality
    btnSaveCP.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        if not hrp then notify_default("Save CP", "Character not available", 2); return end
        local idx = #Checkpoints+1
        table.insert(Checkpoints, {Name = "Checkpoint "..idx, Pos = hrp.Position})
        refreshCPList()
        notify_default("Save CP", "Checkpoint saved", 1.6)
    end)

    btnDelAll.MouseButton1Click:Connect(function()
        Checkpoints = {}
        refreshCPList()
        notify_default("Delete All", "All checkpoints removed", 2)
    end)

    btnAuto.MouseButton1Click:Connect(function()
        AutoLoop = not AutoLoop
        btnAuto.Text = AutoLoop and "⏸️ AutoLoop ON" or "⛳ AutoLoop OFF"
        if AutoLoop then
            spawn(function()
                local i = 1
                while AutoLoop do
                    if Checkpoints[i] and Checkpoints[i].Pos then teleportTo(Checkpoints[i].Pos) end
                    task.wait(AutoDelay)
                    i = i + 1
                    if i > #Checkpoints then
                        if AutoRespawn and player.Character then pcall(function() player.Character:BreakJoints() end) end
                        i = 1
                    end
                end
            end)
        end
    end)

    btnRespawn.MouseButton1Click:Connect(function()
        AutoRespawn = not AutoRespawn
        btnRespawn.Text = AutoRespawn and "♻️ Respawn ON" or "♻️ Respawn OFF"
        notify_default("Respawn", AutoRespawn and "Enabled" or "Disabled", 1.4)
    end)

    delayLabel.InputBegan:Connect(function() end) -- no-op

    -- Save/Load panel toggles (open dropdown-style panels below main buttons)
    local showingSave = false
    local showingLoad = false

    btnSaveFile.MouseButton1Click:Connect(function()
        showingSave = not showingSave
        savePanel.Visible = showingSave
        if showingSave then
            loadPanel.Visible = false
            showingLoad = false
        end
    end)
    btnLoadFile.MouseButton1Click:Connect(function()
        showingLoad = not showingLoad
        loadPanel.Visible = showingLoad
        if showingLoad then
            savePanel.Visible = false
            showingSave = false
        end
    end)

    -- minimize bar: create top bar (draggable & clickable to restore)
    local miniBar = Instance.new("Frame", gui)
    miniBar.Size = UDim2.new(0,420,0,46)
    miniBar.Position = UDim2.new(0.5,-210,0.03,0)
    miniBar.AnchorPoint = Vector2.new(0.5,0)
    miniBar.BackgroundColor3 = Color3.fromRGB(30,30,40)
    miniBar.Visible = false
    miniBar.BorderSizePixel = 0
    miniBar.Active = true
    miniBar.Draggable = true
    Instance.new("UICorner", miniBar).CornerRadius = UDim.new(0,22)

    local miniLabel = Instance.new("TextLabel", miniBar)
    miniLabel.Size = UDim2.new(1,-24,1,0)
    miniLabel.Position = UDim2.new(0,12,0,0)
    miniLabel.BackgroundTransparency = 1
    miniLabel.Text = "🌈 DapzXPloit - Tools Mount"
    miniLabel.Font = Enum.Font.GothamBold
    miniLabel.TextSize = 16
    miniLabel.TextColor3 = Color3.fromRGB(240,240,240)
    miniLabel.TextXAlignment = Enum.TextXAlignment.Left

    btnMin.MouseButton1Click:Connect(function()
        frame.Visible = false
        miniBar.Visible = true
    end)
    miniBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            if not miniBar.Visible then return end
            miniBar.Visible = false
            frame.Visible = true
        end
    end)

    -- initial nice tween (pop in)
    frame.Size = UDim2.new(0,420,0,0)
    frame.Visible = true
    TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {Size = UDim2.new(0,420,0,320)}):Play()

    -- Return some APIs
    return {
        Refresh = refreshCPList,
        Gui = gui
    }
end

local api = buildGUI()
local refreshCPList = api.Refresh
