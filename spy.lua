-- [[ KRALLDEN SPY v9.9.1 - FIXED BE PHANTOM + SCALE DRIFT ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

-- Проверка на мобильное устройство (Touch есть, Клавиатуры нет)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Очистка старых версий
if playerGui:FindFirstChild("KralldenSpyUI") then 
    playerGui.KralldenSpyUI:Destroy() 
end

for _, gui in ipairs(game.CoreGui:GetChildren()) do
    pcall(function()
        if gui.Name == "KralldenSpyUI" then 
            gui:Destroy()
        elseif gui:FindFirstChild("KralldenSpyUI") then 
            gui.KralldenSpyUI:Destroy() 
        end
    end)
end

local targetParent = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or playerGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KralldenSpyUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 10
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

-- Anti-Hide
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then 
            ScreenGui.Enabled = true 
        end 
    end
end)

local Main = Instance.new("Frame")
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220)
Main.Active = true
Main.Draggable = true
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = Main

-- === МАСШТАБ ДЛЯ МОБИЛОК (1.5x меньше) ===
local uiScale = Instance.new("UIScale")
uiScale.Name = "AutoScale"
uiScale.Scale = isMobile and (2/3) or 1
uiScale.Parent = Main

-- === КНОПКА ТЕСТА МАСШТАБА (справа от окна) ===
local TestScaleBtn = Instance.new("TextButton")
TestScaleBtn.Name = "TestScaleBtn"
TestScaleBtn.Size = UDim2.new(0, 44, 0, 44)
TestScaleBtn.Position = UDim2.new(1, 8, 0, 0)
TestScaleBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 160)
TestScaleBtn.Text = isMobile and "66%" or "100%"
TestScaleBtn.TextColor3 = Color3.new(1, 1, 1)
TestScaleBtn.Font = Enum.Font.SourceSansBold
TestScaleBtn.TextSize = 13
TestScaleBtn.BorderSizePixel = 0
TestScaleBtn.ZIndex = 30
TestScaleBtn.Parent = Main

local tsCorner = Instance.new("UICorner")
tsCorner.CornerRadius = UDim.new(0, 6)
tsCorner.Parent = TestScaleBtn

local scaleModes = {1, 2/3}
local scaleIdx = isMobile and 2 or 1

TestScaleBtn.MouseButton1Click:Connect(function()
    scaleIdx = (scaleIdx % #scaleModes) + 1
    uiScale.Scale = scaleModes[scaleIdx]
    TestScaleBtn.Text = tostring(math.floor(scaleModes[scaleIdx] * 100 + 0.5)) .. "%"
end)

-- Основные переменные и таблицы
local MainMemory = {}
local ManualBannedPaths = {}
local AntiSpamCooldowns = {}
local AntiSpamCounts = {}

local pathCache = setmetatable({}, {__mode = "k"})

local selfMode = true
local controlMode = true
local antiSpam = true

local spyFS = true
local spyFC = false
local spyIS = false
local spyBE = false  -- BindableEvent

local sortArgs = false
local currentSelectionGUID = nil
local lastCount = 0
local lastRedCount = 0 
local isMin = false

local function generateGUID() 
    return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) 
end

local RedListScroll
local Scroll
local Details
local ContentFrame
local DetailsScroll

-- Вспомогательные функции UI
local activeFeedbacks = {}
local function feedback(button, tempText)
    if not button or activeFeedbacks[button] then return end
    activeFeedbacks[button] = true
    local oldText = button.Text
    button.Text = tempText
    task.delay(1, function()
        if button and button.Parent then 
            button.Text = oldText 
            activeFeedbacks[button] = nil
        end
    end)
end

local function forceUpdateCanvas()
    if not Details or not DetailsScroll then return end
    local width = DetailsScroll.AbsoluteSize.X - 45 
    if width <= 0 then width = 413 end
    
    local cleanText = Details.Text:gsub("%z", "") 
    local size = TextService:GetTextSize(cleanText, Details.TextSize, Details.Font, Vector2.new(width, math.huge))
    local textHeight = size.Y + 60
    Details.Size = UDim2.new(1, -10, 0, textHeight)
    DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, textHeight)
end

local function updateDetailsView()
    if not currentSelectionGUID then 
        Details.Text = ""
        forceUpdateCanvas()
        return 
    end
    
    local found = false
    for _, d in ipairs(MainMemory) do
        if d.guid == currentSelectionGUID then 
            Details.Text = sortArgs and d.fullTextPretty or d.fullText
            found = true
            break 
        end
    end
    
    if not found then
        for _, data in pairs(ManualBannedPaths) do
            if data.guid == currentSelectionGUID then 
                Details.Text = sortArgs and (data.fullTextPretty or data.fullText) or data.fullText
                found = true
                break 
            end
        end
    end
    forceUpdateCanvas()
end

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then return end
    
    for _, v in pairs(Scroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            if isSelected then
                v.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                if v:GetAttribute("IsSelf") then
                    v.BackgroundColor3 = Color3.fromRGB(45, 90, 45)
                else
                    v.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                end
            end
        end
    end
    
    for _, v in pairs(RedListScroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            if isSelected then
                v.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                v.BackgroundColor3 = Color3.fromRGB(100, 35, 35)
            end
        end
    end
end

local function formatTableVisual(val, indent)
    indent = indent or 0
    local tab = string.rep("    ", indent)
    local t = typeof(val)
    
    if t == "table" then
        local res = "{\n"
        local isArray = true
        local count = 0
        
        for k, v in pairs(val) do 
            count = count + 1
            if type(k) ~= "number" or k ~= count then 
                isArray = false 
                break 
            end 
        end
       
        for k, v in pairs(val) do
            local keyStr = ""
            if not isArray then
                if type(k) == "string" then
                    keyStr = k .. " = "
                else
                    keyStr = "[" .. tostring(k) .. "] = "
                end
            end
            res = res .. tab .. "    " .. keyStr .. formatTableVisual(v, indent + 1) .. ",\n"
        end
        return res .. tab .. "}"
    elseif t == "string" then 
        return '"' .. val .. '"'
    elseif t == "Vector3" then 
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then 
        return "CFrame.new(" .. tostring(val) .. ")"
    else 
        return tostring(val) 
    end
end

local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do 
        if v:IsA("TextButton") then v:Destroy() end 
    end
    
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 25)
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        b.ClipsDescendants = true
        
        local displayPath = path:match("[^%.%[%]]+$") or path
        displayPath = displayPath:gsub('^"', ''):gsub('"$', ''):gsub('%]$', '')
        b.Text = " [X] " .. displayPath
        b.Parent = RedListScroll
        
        b:SetAttribute("GUID", data.guid)
        b:SetAttribute("Path", path)
        
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            updateDetailsView()
            refreshSelectionColors()
        end)
    end
end

-- ================= HEADER =================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Header.ZIndex = 10
Header.BorderSizePixel = 0
Header.Parent = Main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 200, 1, 0)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.9.1"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.ZIndex = 11
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 45, 0, 35)
MinBtn.Position = UDim2.new(1, -45, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.TextSize = 22
MinBtn.ZIndex = 12
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, sizeX or 100, 0, 24)
    b.Position = UDim2.new(1, offset, 0.5, -12)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 11
    b.ZIndex = 11
    b.BorderSizePixel = 0
    b.Parent = Header
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)

local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

local KeybindBtn = nil
local ClearKeybindBtn = nil

if not isMobile then
    KeybindBtn = Instance.new("TextButton")
    KeybindBtn.Size = UDim2.new(0, 65, 0, 22)
    KeybindBtn.Position = UDim2.new(0, 150, 0.5, -11)
    KeybindBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    KeybindBtn.Text = "BIND: NONE"
    KeybindBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
    KeybindBtn.Font = Enum.Font.SourceSansBold
    KeybindBtn.TextSize = 11
    KeybindBtn.BorderSizePixel = 0
    KeybindBtn.ZIndex = 12
    KeybindBtn.Parent = Header

    local kbC = Instance.new("UICorner")
    kbC.CornerRadius = UDim.new(0, 4)
    kbC.Parent = KeybindBtn

    ClearKeybindBtn = Instance.new("TextButton")
    ClearKeybindBtn.Size = UDim2.new(0, 22, 0, 22)
    ClearKeybindBtn.Position = UDim2.new(0, 220, 0.5, -11)
    ClearKeybindBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 150)
    ClearKeybindBtn.Text = "X"
    ClearKeybindBtn.TextColor3 = Color3.new(1, 1, 1)
    ClearKeybindBtn.Font = Enum.Font.SourceSansBold
    ClearKeybindBtn.TextSize = 11
    ClearKeybindBtn.BorderSizePixel = 0
    ClearKeybindBtn.ZIndex = 12
    ClearKeybindBtn.Parent = Header

    local ckC = Instance.new("UICorner")
    ckC.CornerRadius = UDim.new(0, 4)
    ckC.Parent = ClearKeybindBtn
end

-- ================= TAB BAR =================
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 35)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 9
TabBar.Parent = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 4)
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Parent = TabBar

local TabPad = Instance.new("UIPadding")
TabPad.PaddingLeft = UDim.new(0, 8)
TabPad.Parent = TabBar

local activeTabName = "LOG"

local function makeTab(name)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 110, 0, 22)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    b.Text = name
    b.TextColor3 = Color3.fromRGB(200, 200, 200)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.Parent = TabBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    return b
end

local LogTabBtn = makeTab("LOG")
local SettingsTabBtn = makeTab("SETTINGS")

-- ================= CONTENT =================
ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, 0, 1, -63)
ContentFrame.Position = UDim2.new(0, 0, 0, 63)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = Main

-- ==== LOG PANEL ====
Scroll = Instance.new("ScrollingFrame")
Scroll.Position = UDim2.new(0, 8, 0, 8)
Scroll.Size = UDim2.new(0, 190, 1, -16)
Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.Parent = ContentFrame

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 4)
ScrollCorner.Parent = Scroll

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Parent = Scroll

DetailsScroll = Instance.new("ScrollingFrame")
DetailsScroll.Name = "DetailsScroll"
DetailsScroll.Position = UDim2.new(0, 205, 0, 8)
DetailsScroll.Size = UDim2.new(0, 448, 0, 240)
DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
DetailsScroll.BorderSizePixel = 0
DetailsScroll.ScrollBarThickness = 6
DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
DetailsScroll.Parent = ContentFrame

local dsCorner = Instance.new("UICorner")
dsCorner.CornerRadius = UDim.new(0, 4)
dsCorner.Parent = DetailsScroll

local detailPad = Instance.new("UIPadding")
detailPad.PaddingLeft = UDim.new(0, 10)
detailPad.PaddingRight = UDim.new(0, 10)
detailPad.PaddingTop = UDim.new(0, 10)
detailPad.PaddingBottom = UDim.new(0, 10)
detailPad.Parent = DetailsScroll

Details = Instance.new("TextBox")
Details.Size = UDim2.new(1, 0, 0, 0)
Details.BackgroundTransparency = 1
Details.TextColor3 = Color3.new(1, 1, 1)
Details.TextWrapped = true
Details.MultiLine = true
Details.ClearTextOnFocus = false
Details.Font = Enum.Font.Code
Details.TextSize = 13
Details.TextXAlignment = Enum.TextXAlignment.Left
Details.TextYAlignment = Enum.TextYAlignment.Top
Details.Text = ""
Details.Parent = DetailsScroll

Details:GetPropertyChangedSignal("Text"):Connect(forceUpdateCanvas)

local BanListTitle = Instance.new("TextLabel")
BanListTitle.Size = UDim2.new(0, 150, 0, 20)
BanListTitle.Position = UDim2.new(0, 662, 0, 118)
BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"
BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
BanListTitle.Font = Enum.Font.SourceSansBold
BanListTitle.TextSize = 14
BanListTitle.Parent = ContentFrame

RedListScroll = Instance.new("ScrollingFrame")
RedListScroll.Position = UDim2.new(0, 662, 0, 140)
RedListScroll.Size = UDim2.new(0, 150, 0, 225)
RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
RedListScroll.BorderSizePixel = 0
RedListScroll.ScrollBarThickness = 4
RedListScroll.Parent = ContentFrame

local rlsCorner = Instance.new("UICorner")
rlsCorner.CornerRadius = UDim.new(0, 4)
rlsCorner.Parent = RedListScroll

local RedListLayout = Instance.new("UIListLayout")
RedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
RedListLayout.Parent = RedListScroll

-- ================= PATH LOGIC =================
local function getSafePath(obj)
    if not obj then return "nil" end
    if pathCache[obj] then return pathCache[obj] end
    
    local p = ""
    pcall(function() 
        local t = obj
        while t and t ~= game do 
            local n = tostring(t.Name)
            local safeName = ""
            if n:match("^%d") or n:match("[%s%W]") then
                safeName = '["' .. n .. '"]'
            else
                safeName = n
            end
       
            if p == "" then 
                p = safeName 
            else 
                if safeName:sub(1,1) == "[" then
                    p = safeName .. "." .. p 
                else
                    p = safeName .. "." .. p
                end
            end
            t = t.Parent 
        end 
    end)
    
    local finalPath = "game." .. p
    finalPath = finalPath:gsub("%.%[", "[") 
    pathCache[obj] = finalPath
    return finalPath
end

-- ================= ADD LOG =================
local function addLog(rem, args, isSelf, typeLabel)
    if typeLabel == "FS" and not spyFS then return end
    if typeLabel == "FC" and not spyFC then return end
    if typeLabel == "IS" and not spyIS then return end
    if typeLabel == "BE" and not spyBE then return end
    
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0
        if d > 4 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local isArray = true
            local count = 0
            for k, val in pairs(v) do count = count + 1 if type(k) ~= "number" or k ~= count then isArray = false break end end
            local res = "{"
            for k, val in pairs(v) do 
                if isArray then res = res .. parseValue(val, d + 1) .. ", " 
                else 
                    local key = (type(k) == "number") and "["..k.."]" or '["'..tostring(k)..'"]'
                    res = res .. key .. " = " .. parseValue(val, d + 1) .. ", " 
                end
            end
            local result = res:gsub(", $", "") .. "}"
            return (result == "}") and "{}" or result
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList = {}
    for _, v in ipairs(args) do argList[#argList + 1] = parseValue(v) end
    local finalArgsStr = table.concat(argList, ", ")
    
    local alreadyExists = false
    for _, m in pairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if isSelf then if selfMode or m.argsStr == finalArgsStr then alreadyExists = true break end
            else if controlMode or m.argsStr == finalArgsStr then alreadyExists = true break end end
        end
    end
    if alreadyExists then return end

    local methodName
    if typeLabel == "IS" then methodName = "InvokeServer"
    elseif typeLabel == "FC" then methodName = "FireClient"
    elseif typeLabel == "BE" then methodName = "Fire"
    else methodName = "FireServer" end

    local displayArgs = (finalArgsStr == "") and "None" or finalArgsStr
    local displayArgsPretty = formatTableVisual(args)
    
    local logDetails = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, displayArgs, eventPath, methodName, finalArgsStr)
    local logDetailsPretty = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, displayArgsPretty, eventPath, methodName, finalArgsStr)

    if not isSelf and not controlMode and antiSpam then
        local currentTime = tick()
        if (currentTime - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {
                    guid = generateGUID(),
                    type = typeLabel, path = eventPath, argsStr = finalArgsStr,
                    fullText = "AUTO-BANNED\n\n" .. logDetails,
                    fullTextPretty = "AUTO-BANNED\n\n" .. logDetailsPretty
                }
                local nM = {}
                for _, m in ipairs(MainMemory) do if not (m.path == eventPath and not m.isSelf) then nM[#nM + 1] = m end end
                MainMemory = nM
                lastCount = -1 
                return 
            end
        else AntiSpamCounts[eventPath] = 0 end
        AntiSpamCooldowns[eventPath] = currentTime
    end

    local newLog = { 
        guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, 
        fullText = logDetails, fullTextPretty = logDetailsPretty, path = eventPath, argsStr = finalArgsStr
    }
    table.insert(MainMemory, 1, newLog)
    if #MainMemory > 150 then table.remove(MainMemory, 151) end
end

-- ================= ПЕРЕХВАТ (HOOKS) =================
local oldNamecall
local oldIndex

local function processEvent(self, method, args, isSelf)
    if not self or typeof(self) ~= "Instance" then return end
    
    local lowerM = method:lower()
    if lowerM == "fireserver" and self:IsA("RemoteEvent") then
        task.spawn(addLog, self, args, isSelf, "FS")
    elseif lowerM == "fireclient" and self:IsA("RemoteEvent") then
        task.spawn(addLog, self, args, isSelf, "FC")
    elseif lowerM == "invokeserver" and self:IsA("RemoteFunction") then
        task.spawn(addLog, self, args, isSelf, "IS")
    elseif lowerM == "fire" and self:IsA("BindableEvent") then
        -- ФИКС: фильтруем фантомный BindableEvent, который эксплойт-окружение
        -- подсовывает как прямой child of game (у настоящих игр таких нет).
        if self.Parent == game then return end
        task.spawn(addLog, self, args, isSelf, "BE")
    end
end

-- 1. ХУК ДЛЯ КЛАССИЧЕСКИХ ВЫЗОВОВ
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local isSelf = checkcaller()
    
    local args = {...}
    task.spawn(function()
        processEvent(self, method, args, isSelf)
    end)
        
    return oldNamecall(self, ...)
end))

-- 2. ХУК ДЛЯ ВЫЗОВОВ ЧЕРЕЗ ТОЧКУ
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    local originalResult = oldIndex(self, key)
    
    if typeof(self) == "Instance" and type(key) == "string" then
        local lowerKey = key:lower()
        if lowerKey == "fireserver" or lowerKey == "fireclient" or lowerKey == "invokeserver" then
            return newcclosure(function(instanceSelf, ...)
                local isSelf = checkcaller()
                local args = {...}
                task.spawn(function()
                    processEvent(instanceSelf, key, args, isSelf)
                end)
                return originalResult(instanceSelf, ...)
            end)
        elseif lowerKey == "fire" and self:IsA("BindableEvent") then
            -- ФИКС: тот же фильтр фантомного game.Event
            if self.Parent == game then
                return originalResult
            end
            return newcclosure(function(instanceSelf, ...)
                local isSelf = checkcaller()
                local args = {...}
                task.spawn(function()
                    processEvent(instanceSelf, key, args, isSelf)
                end)
                return originalResult(instanceSelf, ...)
            end)
        end
    end
    
    return originalResult
end))

-- ================= INTERACTIONS =================
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    if controlMode then
        ControlBtn.Text = "CONTROL: ON"
        ControlBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 190)
        AntiSpamBtn.Visible = false
        BlockBtn.Visible = false
    else
        ControlBtn.Text = "CONTROL: OFF"
        ControlBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
        AntiSpamBtn.Visible = true
        BlockBtn.Visible = true
    end
    lastCount = -1 
end)

DelBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        local targetData = nil
        local foundInBanList = false
        
        for path, data in pairs(ManualBannedPaths) do
            if data.guid == currentSelectionGUID then 
                targetData = {path = path, guid = data.guid}
                foundInBanList = true
                break 
            end
        end
        
        if not foundInBanList then
            local nM = {}
            for _, m in ipairs(MainMemory) do 
                if m.guid == currentSelectionGUID then 
                    targetData = m 
                else 
                    nM[#nM + 1] = m 
                end 
            end
            if targetData then MainMemory = nM end
        end
        
        if targetData then
            if ManualBannedPaths[targetData.path] then
                ManualBannedPaths[targetData.path] = nil
            end
            
            AntiSpamCooldowns[targetData.path] = 0
            AntiSpamCounts[targetData.path] = 0

            if foundInBanList then feedback(DelBtn, "UNBANNED") else feedback(DelBtn, "DELETED") end
            
            lastCount = -1
            currentSelectionGUID = nil
            Details.Text = ""
            forceUpdateCanvas()
        end
    end
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                ManualBannedPaths[d.path] = {
                    guid = d.guid, 
                    type = d.type, path = d.path, argsStr = d.argsStr,
                    fullText = "MANUAL BANNED:\n\n" .. d.fullText, 
                    fullTextPretty = "MANUAL BANNED:\n\n" .. d.fullTextPretty
                }
                
                local nM = {}
                for _, m in ipairs(MainMemory) do 
                    if not (m.path == d.path and not m.isSelf) then 
                        nM[#nM + 1] = m 
                    end 
                end
                
                MainMemory = nM
                lastCount = -1
                currentSelectionGUID = nil
                Details.Text = "Banned."
                forceUpdateCanvas()
                feedback(BlockBtn, "BANNED")
                break
            end
        end
    end
end)

-- ================= MINIMIZE / RESTORE (ФИКС UISCALE DRIFT) =================
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX = Main.AbsolutePosition.X + Main.AbsoluteSize.X
    local curY = Main.AbsolutePosition.Y
    local s = uiScale.Scale or 1
    if s <= 0 then s = 1 end
    
    if isMin then
        ContentFrame.Visible = false
        TabBar.Visible = false
        ControlBtn.Visible = false
        SelfBtn.Visible = false
        AntiSpamBtn.Visible = false
        BlockBtn.Visible = false
        DelBtn.Visible = false
        
        if KeybindBtn then KeybindBtn.Visible = false end
        if ClearKeybindBtn then ClearKeybindBtn.Visible = false end
       
        local w = 250
        -- UIScale масштабирует и offset от AnchorPoint, поэтому делим на s
        Main:TweenSizeAndPosition(
            UDim2.new(0, w, 0, 35), 
            UDim2.new(0, curX / s - w, 0, curY / s), 
            "Out", "Quad", 0.15, true
        )
        MinBtn.Text = "+"
    else
        local w = 820
        Main:TweenSizeAndPosition(
            UDim2.new(0, w, 0, 440), 
            UDim2.new(0, curX / s - w, 0, curY / s), 
            "Out", "Quad", 0.15, true, function()
                ContentFrame.Visible = true
                TabBar.Visible = true
                ControlBtn.Visible = true
                SelfBtn.Visible = true
                DelBtn.Visible = true
                
                if KeybindBtn then KeybindBtn.Visible = true end
                if ClearKeybindBtn then ClearKeybindBtn.Visible = true end
                
                if not controlMode then
                    AntiSpamBtn.Visible = true
                    BlockBtn.Visible = true
                end
            end
        )
        MinBtn.Text = "_"
        lastCount = -1
    end
end)

if not isMobile and KeybindBtn and ClearKeybindBtn then
    local currentKeybind = nil
    local isBinding = false

    KeybindBtn.MouseButton1Click:Connect(function()
        isBinding = true
        KeybindBtn.Text = "..."
    end)

    ClearKeybindBtn.MouseButton1Click:Connect(function()
        currentKeybind = nil
        KeybindBtn.Text = "BIND: NONE"
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if isBinding then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                currentKeybind = input.KeyCode
                isBinding = false
                KeybindBtn.Text = "BIND: " .. input.KeyCode.Name:upper()
            end
            return
        end
        
        if currentKeybind and input.KeyCode == currentKeybind then
            local events = getconnections(MinBtn.MouseButton1Click)
            for _, connection in ipairs(events) do
                connection:Fire()
            end
        end
    end)
end

-- ================= BOTTOM BUTTONS (LOG PANEL) =================
local function createBotBtn(text, pos, size, color, parentOverride)
    local b = Instance.new("TextButton")
    b.Size = size or UDim2.new(0, 220, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 14
    b.BorderSizePixel = 0
    b.Parent = parentOverride or ContentFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    return b
end

local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0, 256), UDim2.new(0, 95, 0, 55), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript")
    if a then 
        setclipboard(a) 
        feedback(CopyArgsBtn, "COPIED!")
    end
end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 305, 0, 256), UDim2.new(0, 120, 0, 55), Color3.fromRGB(80, 80, 85))
SortBtn.MouseButton1Click:Connect(function()
    sortArgs = not sortArgs
    SortBtn.Text = "SORT: " .. (sortArgs and "ON" or "OFF")
    SortBtn.BackgroundColor3 = sortArgs and Color3.fromRGB(0, 140, 140) or Color3.fromRGB(80, 80, 85)
    updateDetailsView()
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0, 318), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)")
    if s then 
        setclipboard(s) 
        feedback(CopyScriptBtn, "COPIED!")
    end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0, 256), UDim2.new(0, 108, 0, 55), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if m.isSelf then nM[#nM + 1] = m end end
    MainMemory = nM
    lastCount = -1
    feedback(ClearLogBtn, "CLEARED")
end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0, 256), UDim2.new(0, 108, 0, 55), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if not m.isSelf then nM[#nM + 1] = m end end
    MainMemory = nM
    lastCount = -1
    feedback(ClearSelfBtn, "CLEARED")
end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0, 318), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)") or Details.Text
    if s and s ~= "" then 
        local f = loadstring(s)
        if f then 
            task.spawn(f) 
            feedback(ExecuteBtn, "EXECUTED!")
        end
    end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode
    SelfBtn.Text = "SELF: " .. (selfMode and "ON" or "OFF")
    SelfBtn.BackgroundColor3 = selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50)
    lastCount = -1
end)

AntiSpamBtn.MouseButton1Click:Connect(function() 
    antiSpam = not antiSpam
    AntiSpamBtn.Text = "ANTI-SPAM: " .. (antiSpam and "ON" or "OFF")
    AntiSpamBtn.BackgroundColor3 = antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85)
end)

-- ================= SETTINGS PANEL =================
local SettingsPanel = Instance.new("Frame")
SettingsPanel.Name = "SettingsPanel"
SettingsPanel.Size = UDim2.new(1, 0, 1, 0)
SettingsPanel.Position = UDim2.new(0, 0, 0, 0)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.Visible = false
SettingsPanel.ZIndex = 15
SettingsPanel.Parent = ContentFrame

local settingsScroll = Instance.new("ScrollingFrame")
settingsScroll.Size = UDim2.new(1, 0, 1, 0)
settingsScroll.Position = UDim2.new(0, 0, 0, 0)
settingsScroll.BackgroundTransparency = 1
settingsScroll.BorderSizePixel = 0
settingsScroll.ScrollBarThickness = 4
settingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
settingsScroll.Parent = SettingsPanel

local settingsList = Instance.new("UIListLayout")
settingsList.SortOrder = Enum.SortOrder.LayoutOrder
settingsList.Padding = UDim.new(0, 8)
settingsList.Parent = settingsScroll

local settingsPad = Instance.new("UIPadding")
settingsPad.PaddingTop = UDim.new(0, 12)
settingsPad.PaddingLeft = UDim.new(0, 14)
settingsPad.PaddingRight = UDim.new(0, 14)
settingsPad.PaddingBottom = UDim.new(0, 12)
settingsPad.Parent = settingsScroll

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Size = UDim2.new(1, 0, 0, 26)
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Text = "SETTINGS — Здесь можно добавлять новые функции"
SettingsTitle.TextColor3 = Color3.fromRGB(180, 180, 210)
SettingsTitle.Font = Enum.Font.SourceSansBold
SettingsTitle.TextSize = 13
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
SettingsTitle.LayoutOrder = 0
SettingsTitle.Parent = settingsScroll

local function createToggleRow(label, initialState, activeColor, onToggle, order)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = initialState and activeColor or Color3.fromRGB(40, 40, 45)
    row.Text = ""
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = settingsScroll

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. (initialState and "ON" or "OFF")
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    row.MouseButton1Click:Connect(function()
        local state = onToggle()
        row.BackgroundColor3 = state and activeColor or Color3.fromRGB(40, 40, 45)
        lbl.Text = label .. ": " .. (state and "ON" or "OFF")
    end)

    return row
end

-- Оставлены только типы перехвата (CONTROL/ANTI-SPAM/SELF теперь только в шапке)
createToggleRow("FS SPY (FireServer)", spyFS, Color3.fromRGB(130, 70, 220), function()
    spyFS = not spyFS
    return spyFS
end, 1)

createToggleRow("FC SPY (FireClient)", spyFC, Color3.fromRGB(50, 150, 255), function()
    spyFC = not spyFC
    return spyFC
end, 2)

createToggleRow("IS SPY (InvokeServer)", spyIS, Color3.fromRGB(255, 150, 50), function()
    spyIS = not spyIS
    return spyIS
end, 3)

createToggleRow("BE SPY (BindableEvent)", spyBE, Color3.fromRGB(50, 200, 150), function()
    spyBE = not spyBE
    return spyBE
end, 4)

-- Placeholder для будущих функций
local Placeholder = Instance.new("TextLabel")
Placeholder.Size = UDim2.new(1, 0, 0, 60)
Placeholder.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Placeholder.Text = "⬇ Будущие функции можно добавлять сюда ⬇"
Placeholder.TextColor3 = Color3.fromRGB(120, 120, 140)
Placeholder.Font = Enum.Font.SourceSans
Placeholder.TextSize = 12
Placeholder.LayoutOrder = 999
Placeholder.Parent = settingsScroll

local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 6)
pc.Parent = Placeholder

-- ================= TAB SWITCHING =================
local function updateTabVisuals()
    if activeTabName == "LOG" then
        SettingsPanel.Visible = false
        LogTabBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
        LogTabBtn.TextColor3 = Color3.new(1, 1, 1)
        SettingsTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        SettingsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    else
        SettingsPanel.Visible = true
        LogTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        LogTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        SettingsTabBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
        SettingsTabBtn.TextColor3 = Color3.new(1, 1, 1)
    end
end

LogTabBtn.MouseButton1Click:Connect(function()
    activeTabName = "LOG"
    updateTabVisuals()
end)

SettingsTabBtn.MouseButton1Click:Connect(function()
    activeTabName = "SETTINGS"
    updateTabVisuals()
end)

updateTabVisuals()

-- ================= RENDER LOOP =================
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame or not ContentFrame.Visible then continue end
        
        local currentRedCount = 0
        for _ in pairs(ManualBannedPaths) do currentRedCount = currentRedCount + 1 end
        if currentRedCount ~= lastRedCount then
            lastRedCount = currentRedCount
            updateRedListUI()
        end

        if #MainMemory == lastCount then continue end
        lastCount = #MainMemory
        
        local sortedMemory = {}
        for _, d in ipairs(MainMemory) do if d.isSelf then sortedMemory[#sortedMemory + 1] = d end end
        for _, d in ipairs(MainMemory) do if not d.isSelf then sortedMemory[#sortedMemory + 1] = d end end
        
        local currentButtons = {}
        for _, v in pairs(Scroll:GetChildren()) do 
            if v:IsA("TextButton") then 
                table.insert(currentButtons, v)
            end 
        end
        
        if #currentButtons > #sortedMemory then
            for i = #sortedMemory + 1, #currentButtons do
                currentButtons[i]:Destroy()
                currentButtons[i] = nil
            end
        end
        
        for i, d in ipairs(sortedMemory) do
            local b = currentButtons[i]
            
            if not b then
                b = Instance.new("TextButton")
                b.TextColor3 = Color3.new(1, 1, 1)
                b.BorderSizePixel = 0
                b.ClipsDescendants = true
                b.Parent = Scroll
                
                local bcorner = Instance.new("UICorner")
                bcorner.CornerRadius = UDim.new(0, 4)
                bcorner.Parent = b
                
                b.MouseButton1Click:Connect(function()
                    local buttonGUID = b:GetAttribute("GUID")
                    if buttonGUID then
                        currentSelectionGUID = buttonGUID
                        updateDetailsView()
                        refreshSelectionColors()
                    end
                end)
            end
            
            b.Size = UDim2.new(1, -6, 0, 30)
            b.LayoutOrder = i
            
            local cleanName = d.name:match("[^%.%[%]]+$") or d.name
            cleanName = cleanName:gsub('^"', ''):gsub('"$', ''):gsub('%]$', '')
            
            b.Text = string.format("[%s]%s [%s]", d.type, (d.isSelf and " [S]" or ""), cleanName)
            
            if currentSelectionGUID == d.guid then
                b.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                b.BackgroundColor3 = d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45)
            end
            
            b:SetAttribute("GUID", d.guid)
            b:SetAttribute("IsSelf", d.isSelf)
        end
    end
end)
