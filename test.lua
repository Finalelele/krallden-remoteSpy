-- [[ KRALLDEN SPY v9.4.9 - PRETTY PRINT & SCROLL UPDATE ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Очистка старых версий
if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end
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
local ScreenGui = Instance.new("ScreenGui", targetParent)
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 10; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Переменные состояния
local sortEnabled = false
local currentSelectionGUID, lastCount = nil, 0
local currentData = nil

-- Anti-Hide
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then
            ScreenGui.Enabled = true
        end
    end
end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, ManualBannedPaths = {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam = true, true, true
local spyFS, spyFC, spyIS = true, false, false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

-- ФУНКЦИЯ КРАСИВОГО ВЫВОДА (PRETTY PRINT)
local function formatTable(t, indent)
    indent = indent or 0
    local spacing = string.rep("    ", indent + 1)
    local result = "{\n"
    
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    
    for _, k in ipairs(keys) do
        local v = t[k]
        local keyStr = type(k) == "string" and '["'..k..'"]' or "["..tostring(k).."]"
        result = result .. spacing .. keyStr .. " = "
        
        if type(v) == "table" then
            result = result .. formatTable(v, indent + 1) .. ",\n"
        elseif typeof(v) == "CFrame" then
            result = result .. "CFrame.new(" .. tostring(v) .. "),\n"
        elseif typeof(v) == "Vector3" then
            result = result .. "Vector3.new(" .. tostring(v) .. "),\n"
        elseif type(v) == "string" then
            result = result .. '"' .. v .. '",\n'
        else
            result = result .. tostring(v) .. ",\n"
        end
    end
    
    return result .. string.rep("    ", indent) .. "}"
end

local RedListScroll, Scroll, Details, DetailsScroll, ContentFrame

-- Фидбек
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

-- HEADER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.ZIndex = 10; Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.4.9"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.ZIndex = 11; Title.TextXAlignment = 0

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, sizeX or 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.ZIndex = 11; b.BorderSizePixel = 0
    return b
end

local MinBtn = createHeaderBtn("_", -45, Color3.fromRGB(60, 60, 180), 45)
local SortBtn = createHeaderBtn("SORT: OFF", -150, Color3.fromRGB(40, 60, 150), 90) -- Та самая синяя кнопка

ContentFrame = Instance.new("Frame", Main)
ContentFrame.Name = "ContentFrame"; ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

-- Scroll для списка ивентов
Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0; Scroll.ScrollBarThickness = 4
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

-- НОВЫЙ DETAILS СО СКРОЛЛОМ
DetailsScroll = Instance.new("ScrollingFrame", ContentFrame)
DetailsScroll.Position = UDim2.new(0, 205, 0, 8); DetailsScroll.Size = UDim2.new(0, 448, 0, 255); DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12); DetailsScroll.BorderSizePixel = 0; DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; DetailsScroll.ScrollBarThickness = 6

Details = Instance.new("TextBox", DetailsScroll)
Details.Size = UDim2.new(1, -10, 1, 0); Details.BackgroundTransparency = 1; Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = true; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0; Details.ClearTextOnFocus = false; Details.AutomaticSize = Enum.AutomaticSize.Y

-- Функции обновления
local function updateDetailsText(data)
    if not data then return end
    currentData = data
    local argDisplay = ""
    
    if sortEnabled and type(data.rawArgs) == "table" then
        argDisplay = formatTable(data.rawArgs)
    else
        argDisplay = data.argsStr
    end
    
    local fullLog = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", data.type, data.path, argDisplay, data.path, data.method, data.argsStr)
    Details.Text = fullLog
end

SortBtn.MouseButton1Click:Connect(function()
    sortEnabled = not sortEnabled
    SortBtn.Text = "SORT: " .. (sortEnabled and "ON" or "OFF")
    SortBtn.BackgroundColor3 = sortEnabled and Color3.fromRGB(30, 120, 255) or Color3.fromRGB(40, 60, 150)
    if currentData then updateDetailsText(currentData) end
end)

-- Остальной UI (Ban List и кнопки)
local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20); BanListTitle.Position = UDim2.new(0, 662, 0, 125); BanListTitle.BackgroundTransparency = 1; BanListTitle.Text = "BAN LIST"; BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); BanListTitle.Font = Enum.Font.SourceSansBold; BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0; RedListScroll.ScrollBarThickness = 4
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- SMART PARSER (Оригинальный)
local function getSafePath(obj)
    local p = ""; 
    pcall(function() 
        local t = obj; 
        while t and t ~= game do 
            local n = tostring(t.Name); 
            local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            if p == "" then p = safeName else p = safeName .. (safeName:sub(1,1) == "[" and "" or ".") .. p end
            t = t.Parent 
        end 
    end)
    return "game." .. p
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0; if d > 4 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local res, i = "{", 0
            for k, val in pairs(v) do i = i + 1; if i > 15 then res = res .. "... " break end
                local key = type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]'
                res = res .. key .. " = " .. parseValue(val, d + 1) .. ", "
            end
            return res:gsub(", $", "") .. "}"
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList = {}
    for i, v in ipairs(args) do argList[#argList + 1] = parseValue(v) end
    local finalArgsStr = table.concat(argList, ", ")
    
    local data = { 
        guid = generateGUID(), 
        name = tostring(rem.Name), 
        type = typeLabel, 
        isSelf = isSelf, 
        path = eventPath, 
        argsStr = finalArgsStr,
        rawArgs = args,
        method = (typeLabel == "IS" and "InvokeServer" or "FireServer")
    }
    
    table.insert(MainMemory, 1, data)
    if #MainMemory > 100 then table.remove(MainMemory, 101) end
end

-- HOOKS
local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod(); local a = {...}; local s = checkcaller()
    if m:lower() == "fireserver" then task.spawn(addLog, self, a, s, "FS")
    elseif m:lower() == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    return old(self, ...)
end); setreadonly(mt, true)

-- BOTTOM BUTTONS
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

-- РАЗДЕЛЕННЫЕ КНОПКИ
local CopyArgsBtn = createBotBtn("COPY ARGS (RAW)", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(45, 90, 45))
local SortCopyBtn = createBotBtn("SORT ARGS", UDim2.new(0, 317, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(30, 80, 150))

CopyArgsBtn.MouseButton1Click:Connect(function() 
    if currentData then setclipboard(currentData.argsStr); feedback(CopyArgsBtn, "COPIED!") end
end)

SortCopyBtn.MouseButton1Click:Connect(function()
    if currentData then setclipboard(formatTable(currentData.rawArgs)); feedback(SortCopyBtn, "SORTED!") end
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() 
    if currentData then setclipboard(string.format("%s:%s(%s)", currentData.path, currentData.method, currentData.argsStr)); feedback(CopyScriptBtn, "SCRIPT COPIED!") end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 220, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function() MainMemory = {}; lastCount = -1; Details.Text = ""; feedback(ClearLogBtn, "CLEARED") end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function() 
    if currentData then 
        local scr = string.format("%s:%s(unpack(%s))", currentData.path, currentData.method, formatTable(currentData.rawArgs))
        local f = loadstring(scr); if f then task.spawn(f); feedback(ExecuteBtn, "EXECUTED!") end
    end 
end)

-- RENDER LOOP
task.spawn(function()
    while task.wait(0.5) do
        if #MainMemory == lastCount then continue end
        lastCount = #MainMemory
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for i, d in ipairs(MainMemory) do
            local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i
            b.Text = "["..d.type.."] "..d.name; b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(40, 40, 45)
            b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid; updateDetailsText(d)
                for _, btn in pairs(Scroll:GetChildren()) do if btn:IsA("TextButton") then btn.BackgroundColor3 = (btn == b) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(40, 40, 45) end end
            end)
        end
    end
end)
