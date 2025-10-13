--============================--
--  Marker Saver - DapzXPloit
--  Delta Executor Compatible
--============================--

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local plr = Players.LocalPlayer

-- Global
getgenv().Checkpoints = {
    {Name="Spawn", Pos=Vector3.new(-925.52,371.61,37.74)},
    {Name="Checkpoint 1", Pos=Vector3.new(-903.17,364.01,-428.28)},
    {Name="Checkpoint 2", Pos=Vector3.new(-602.62,421.12,-545.52)},
    {Name="Summit", Pos=Vector3.new(2496.26,2223.81,15.70)},
}
getgenv().AutoSummitLoop=false
getgenv().AutoSummitOnce=false
getgenv().AutoSummitDelay=1
getgenv().AutoSummitRespawn=false
getgenv().TeleportYOffset=5
getgenv().AutoSummitRunning=false

----------------------------------------------------
--  Utility
----------------------------------------------------
local function SafeWait(t) local s,e=pcall(task.wait,t) end

local function getHRP()
    local c = plr.Character or plr.CharacterAdded:Wait()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function TeleportTo(pos)
    local hrp = getHRP()
    if hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(pos + Vector3.new(0,getgenv().TeleportYOffset,0))
        end)
    end
end

local function AutoSummit()
    if getgenv().AutoSummitRunning then return end
    getgenv().AutoSummitRunning=true
    spawn(function()
        repeat
            for i,cp in ipairs(getgenv().Checkpoints) do
                TeleportTo(cp.Pos)
                SafeWait(getgenv().AutoSummitDelay)
            end
            if getgenv().AutoSummitRespawn then
                pcall(function()
                    if plr.Character then plr.Character:BreakJoints() end
                end)
                plr.CharacterAdded:Wait()
                SafeWait(1)
            end
        until not getgenv().AutoSummitLoop
        getgenv().AutoSummitRunning=false
    end)
end

----------------------------------------------------
--  UI Core
----------------------------------------------------
local gui = Instance.new("ScreenGui", game:GetService("CoreGui"))
gui.Name="DapzXPloitUI"

-- Main Frame
local frame = Instance.new("Frame", gui)
frame.Size=UDim2.new(0,440,0,290)
frame.Position=UDim2.new(0.3,0,0.25,0)
frame.BackgroundColor3=Color3.fromRGB(30,30,45)
frame.BorderSizePixel=0
frame.Active=true
frame.Draggable=true
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,18)

-- Drop shadow
local shadow = Instance.new("ImageLabel", frame)
shadow.ZIndex=0
shadow.Position=UDim2.new(0, -10, 0, -10)
shadow.Size=UDim2.new(1, 20, 1, 20)
shadow.BackgroundTransparency=1
shadow.Image="rbxassetid://1316045217"
shadow.ImageColor3=Color3.fromRGB(0,0,0)
shadow.ImageTransparency=0.65

-- Header
local header = Instance.new("Frame", frame)
header.Size=UDim2.new(1,0,0,38)
header.BackgroundColor3=Color3.fromRGB(55,55,75)
header.BorderSizePixel=0
Instance.new("UICorner",header).CornerRadius=UDim.new(0,18)

local title = Instance.new("TextLabel", header)
title.Size=UDim2.new(1,-70,1,0)
title.Position=UDim2.new(0,15,0,0)
title.Text="Marker Saver - DapzXPloit"
title.TextColor3=Color3.fromRGB(255,255,255)
title.TextXAlignment=Enum.TextXAlignment.Left
title.Font=Enum.Font.GothamBold
title.TextSize=17
title.BackgroundTransparency=1

-- Minimize button
local minimizeBtn = Instance.new("TextButton", header)
minimizeBtn.Size=UDim2.new(0,32,0,32)
minimizeBtn.Position=UDim2.new(1,-38,0,3)
minimizeBtn.Text="-"
minimizeBtn.Font=Enum.Font.GothamBold
minimizeBtn.TextSize=18
minimizeBtn.TextColor3=Color3.new(1,1,1)
minimizeBtn.BackgroundColor3=Color3.fromRGB(70,70,100)
Instance.new("UICorner",minimizeBtn).CornerRadius=UDim.new(0,12)

----------------------------------------------------
--  Buttons Helper
----------------------------------------------------
local function makeButton(parent,text,posX,posY,color)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(0.28,0,0,34)
    b.Position=UDim2.new(0,posX,0,posY)
    b.BackgroundColor3=color or Color3.fromRGB(70,70,100)
    b.Font=Enum.Font.GothamBold
    b.TextSize=14
    b.TextColor3=Color3.new(1,1,1)
    b.Text=text
    b.AutoButtonColor=false
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
    -- Hover FX
    b.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(b,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(color.R*255+20,color.G*255+20,color.B*255+20)}):Play()
    end)
    b.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(b,TweenInfo.new(0.2),{BackgroundColor3=color}):Play()
    end)
    return b
end

----------------------------------------------------
--  Buttons + Functions
----------------------------------------------------
local loopBtn=makeButton(frame,"▶️ AutoLoop OFF",20,50,Color3.fromRGB(200,60,60))
local saveCP=makeButton(frame,"📌 Save CP",160,50,Color3.fromRGB(70,120,200))
local delAll=makeButton(frame,"🗑️ Delete All",300,50,Color3.fromRGB(200,120,40))
local saveFile=makeButton(frame,"💾 Save File",20,95,Color3.fromRGB(100,160,220))
local loadFile=makeButton(frame,"📂 Load File",160,95,Color3.fromRGB(90,200,160))
local respawn=makeButton(frame,"♻️ Respawn OFF",300,95,Color3.fromRGB(230,180,60))

local speedLabel=Instance.new("TextLabel",frame)
speedLabel.Text="Delay(s):"
speedLabel.Size=UDim2.new(0,70,0,24)
speedLabel.Position=UDim2.new(0,20,0,135)
speedLabel.BackgroundTransparency=1
speedLabel.Font=Enum.Font.GothamBold
speedLabel.TextSize=13
speedLabel.TextColor3=Color3.new(1,1,1)

local speedBox=Instance.new("TextBox",frame)
speedBox.Size=UDim2.new(0,40,0,20)
speedBox.Position=UDim2.new(0,95,0,138)
speedBox.Text=tostring(getgenv().AutoSummitDelay)
speedBox.BackgroundColor3=Color3.fromRGB(50,50,70)
speedBox.TextColor3=Color3.new(1,1,1)
speedBox.Font=Enum.Font.GothamBold
speedBox.TextSize=13
speedBox.ClearTextOnFocus=false
Instance.new("UICorner",speedBox).CornerRadius=UDim.new(0,6)

-- Scroll checkpoints
local scroll=Instance.new("ScrollingFrame",frame)
scroll.Size=UDim2.new(1,-40,0,115)
scroll.Position=UDim2.new(0,20,0,165)
scroll.BackgroundColor3=Color3.fromRGB(35,35,50)
scroll.BorderSizePixel=0
scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.ScrollBarThickness=6
Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,10)
local layout=Instance.new("UIListLayout",scroll)
layout.Padding=UDim.new(0,5)
layout.FillDirection=Enum.FillDirection.Vertical
layout.HorizontalAlignment=Enum.HorizontalAlignment.Center

----------------------------------------------------
--  Functional Buttons
----------------------------------------------------
loopBtn.MouseButton1Click:Connect(function()
    getgenv().AutoSummitLoop = not getgenv().AutoSummitLoop
    if getgenv().AutoSummitLoop then
        loopBtn.Text="⏸️ AutoLoop ON"
        loopBtn.BackgroundColor3=Color3.fromRGB(100,200,100)
        AutoSummit()
    else
        loopBtn.Text="▶️ AutoLoop OFF"
        loopBtn.BackgroundColor3=Color3.fromRGB(200,60,60)
    end
end)

respawn.MouseButton1Click:Connect(function()
    getgenv().AutoSummitRespawn = not getgenv().AutoSummitRespawn
    respawn.Text = getgenv().AutoSummitRespawn and "♻️ Respawn ON" or "♻️ Respawn OFF"
end)

saveCP.MouseButton1Click:Connect(function()
    local hrp=getHRP()
    if not hrp then return end
    local p=hrp.Position
    local name="Checkpoint "..tostring(#getgenv().Checkpoints+1)
    table.insert(getgenv().Checkpoints,{Name=name,Pos=p})
    local btn=makeButton(scroll,"📍 "..name,0,0,Color3.fromRGB(80,100,150))
    btn.MouseButton1Click:Connect(function() TeleportTo(p) end)
    scroll.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+10)
end)

delAll.MouseButton1Click:Connect(function()
    getgenv().Checkpoints={}
    for _,v in pairs(scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
end)

saveFile.MouseButton1Click:Connect(function()
    if writefile then
        local path="DapzXPloit_Save_"..game.PlaceId..".json"
        local enc=HttpService:JSONEncode(getgenv().Checkpoints)
        writefile(path,enc)
    end
end)

loadFile.MouseButton1Click:Connect(function()
    if readfile then
        local path="DapzXPloit_Save_"..game.PlaceId..".json"
        if isfile(path) then
            local data=HttpService:JSONDecode(readfile(path))
            getgenv().Checkpoints=data
        end
    end
end)

speedBox.FocusLost:Connect(function()
    local v=tonumber(speedBox.Text)
    if v then getgenv().AutoSummitDelay=v end
end)

----------------------------------------------------
--  Minimize System with Animation
----------------------------------------------------
local TweenService=game:GetService("TweenService")
local minimized=false

-- Bar collapsed
local miniBar=Instance.new("Frame",gui)
miniBar.Size=UDim2.new(0,240,0,40)
miniBar.Position=UDim2.new(0.37,0,0.05,0)
miniBar.BackgroundColor3=Color3.fromRGB(50,50,70)
miniBar.Visible=false
Instance.new("UICorner",miniBar).CornerRadius=UDim.new(1,0)

local barLabel=Instance.new("TextLabel",miniBar)
barLabel.Size=UDim2.new(1,0,1,0)
barLabel.Text="🌈 DapzXPloit - Tools Mount"
barLabel.Font=Enum.Font.GothamBold
barLabel.TextColor3=Color3.new(1,1,1)
barLabel.TextSize=15
barLabel.BackgroundTransparency=1

local glow=Instance.new("UIStroke",miniBar)
glow.Thickness=1.5
glow.Color=Color3.fromRGB(150,150,255)

spawn(function()
    while true do
        for h=0,255,5 do
            glow.Color=Color3.fromHSV(h/255,0.6,1)
            wait(0.05)
        end
    end
end)

minimizeBtn.MouseButton1Click:Connect(function()
    if minimized then return end
    minimized=true
    TweenService:Create(frame,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{Size=UDim2.new(0,440,0,0),Transparency=1}):Play()
    wait(0.3)
    frame.Visible=false
    miniBar.Visible=true
    TweenService:Create(miniBar,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{BackgroundTransparency=0}):Play()
end)

miniBar.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then
        miniBar.Visible=false
        frame.Visible=true
        frame.Size=UDim2.new(0,440,0,290)
        frame.Transparency=0
        minimized=false
        TweenService:Create(frame,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{Size=UDim2.new(0,440,0,290),Transparency=0}):Play()
    end
end)

----------------------------------------------------
--  Done
----------------------------------------------------
print("✅ DapzXPloit UI loaded successfully.")
