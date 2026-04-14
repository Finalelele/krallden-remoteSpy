-- [[ KRALLDEN SPY v9.5.3 - FINAL BUFFER FIX & RECOVERY ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui", playerGui)
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 2147483647

-- АВТОВКЛЮЧЕНИЕ ПРИ ПОПЫТКЕ СКРЫТЬ
ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if ScreenGui.Enabled == false then ScreenGui.Enabled = true end
end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam, spyBuffer = true, true, true, true
local spyFS, spyFC, spyIS = true, false, false
local currentSelectionGUID, lastCount = nil, 0
local isMin = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, Details, ContentFrame

local activeFeedbacks = {}
local function feedback(button, tempText)
    if not button or type(button) ~= "userdata" then return end
    if activeFeedbacks[button] then return end
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

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then return end
    for _, v in pairs(Scroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            local isSelf = v:GetAttribute("IsSelf")
            v.BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or (isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
        end
    end
end

local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton", RedListScroll)
        b.Size = UDim2.new(1, -6, 0, 25); b.BorderSizePixel = 0
        b:SetAttribute("GUID", data.guid)
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10
        b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path)
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            Details.Text = data.details 
            refreshSelectionColors()
        end)
    end
end

-- HEADER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.ZIndex = 10; Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.5.3"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35); MinBtn.Position = UDim2.new(1, -45, 0, 0); MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180); MinBtn.Text = "_"; MinBtn.TextColor3 = Color3.new(1, 1, 1); MinBtn.TextSize = 22; MinBtn.BorderSizePixel = 0

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, sizeX or 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.BorderSizePixel = 0
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

Details = Instance.new("TextBox", ContentFrame)
Details.Position = UDim2.new(0, 205, 0, 8); Details.Size = UDim2.new(0, 448, 0, 255); Details.BackgroundColor3 = Color3.fromRGB(10, 10, 12); Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = true; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0; Details.ClearTextOnFocus = false

local BufferBtn = Instance.new("TextButton", ContentFrame)
BufferBtn.Size = UDim2.new(0, 90, 0, 20); BufferBtn.Position = UDim2.new(0, 558, 0, 12); BufferBtn.ZIndex = 15; BufferBtn.BorderSizePixel = 0
BufferBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 150); BufferBtn.Text = "BUFFER: ON"; BufferBtn.TextColor3 = Color3.new(1,1,1); BufferBtn.Font = Enum.Font.SourceSansBold; BufferBtn.TextSize = 10

local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20); BanListTitle.Position = UDim2.new(0, 662, 0, 125); BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"; BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); BanListTitle.Font = Enum.Font.SourceSansBold; BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- SMART PARSER
local function getSafePath(obj)
    local p = ""
    pcall(function() 
        local t = obj 
        while t and t ~= game do 
            local n = tostring(t.Name)
            local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            p = (p == "" and safeName or safeName .. "." .. p)
            t = t.Parent 
        end 
    end)
    return ("game." .. p):gsub("%.%[", "[")
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0; if d > 4 then return "..." end
        local t = type(v)
        
        if t == "buffer" then
            if spyBuffer then
                local bLen = buffer.len(v)
                local hex, str = "", ""
                -- Пытаемся прочитать как текст
                pcall(function() str = buffer.tostring(v):gsub("[%c%z]", ".") end)
                -- Пытаемся вытащить первые байты (Hex)
                for i = 0, math.min(bLen - 1, 7) do
                    hex = hex .. string.format("%02X ", buffer.readu8(v, i))
                end
                -- Попытка найти координаты (если буфер >= 12 байт)
                local extra = ""
                if bLen >= 12 then
                    pcall(function()
                        local x, y, z = buffer.readf32(v, 0), buffer.readf32(v, 4), buffer.readf32(v, 8)
                        extra = string.format("\n[Pos?]: %.2f, %.2f, %.2f", x, y, z)
                    end)
                end
                return string.format("buffer(%d) [%s...] '%s'%s", bLen, hex, str, extra)
            end
            return "buffer(" .. buffer.len(v) .. ")"
        elseif t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local res, i = "{", 0
            for k, val in pairs(v) do i = i + 1; if i > 10 then res = res .. "... " break end
                res = res .. (type(k) == "number" and "" or '["'..tostring(k)..'"] = ') .. parseValue(val, d+1) .. ", "
            end
            return res:gsub(", $", "") .. "}"
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList = {}
    for i, v in ipairs(args) do argList[#argList + 1] = parseValue(v) end
    local finalArgsStr = table.concat(argList, ", ")
    
    local alreadyExists = false
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf and (controlMode or m.argsStr == finalArgsStr) then
            alreadyExists = true break
        end
    end
    if alreadyExists then return end

    -- ANTI-SPAM
    if not isSelf and not controlMode and antiSpam then
        if (tick() - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {guid = generateGUID(), details = "SPAM BANNED"}
                updateRedListUI(); return 
            end
        else AntiSpamCounts[eventPath] = 0 end
        AntiSpamCooldowns[eventPath] = tick()
    end

    local methodName = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer"))
    local logDetails = string.format("Type: %s\nPath: %s\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, (finalArgsStr == "" and "None" or finalArgsStr), eventPath, methodName, finalArgsStr)

    table.insert(MainMemory, 1, { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, fullText = logDetails, path = eventPath, argsStr = finalArgsStr })
    if #MainMemory > 100 then table.remove(MainMemory, 101) end
end

-- HOOKS
local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod():lower(); local a = {...}; local s = checkcaller()
    if m == "fireserver" then task.spawn(addLog, self, a, s, "FS")
    elseif m == "fireclient" then task.spawn(addLog, self, a, s, "FC")
    elseif m == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    return old(self, ...)
end); setreadonly(mt, true)

-- INTERACTIONS
BufferBtn.MouseButton1Click:Connect(function()
    spyBuffer = not spyBuffer
    BufferBtn.Text = "BUFFER: " .. (spyBuffer and "ON" or "OFF")
    BufferBtn.BackgroundColor3 = spyBuffer and Color3.fromRGB(70, 70, 150) or Color3.fromRGB(80, 80, 85)
    lastCount = -1 
end)

ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible = not controlMode; BlockBtn.Visible = not controlMode
    lastCount = -1 
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        ContentFrame.Visible = false; Main:TweenSize(UDim2.new(0, 250, 0, 35), "Out", "Quad", 0.15, true); MinBtn.Text = "+"
    else
        Main:TweenSize(UDim2.new(0, 820, 0, 440), "Out", "Quad", 0.15, true, function() ContentFrame.Visible = true end); MinBtn.Text = "_"
    end
end)

-- RENDER LOOP
task.spawn(function()
    while task.wait(0.5) do
        if #MainMemory == lastCount then continue end
        lastCount = #MainMemory
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for i, d in ipairs(MainMemory) do
            local b = Instance.new("TextButton", Scroll)
            b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i; b.BorderSizePixel = 0
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3 = Color3.new(1,1,1)
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid
                -- ФИКС: Принудительно ставим текст именно из ЭТОГО ивента
                Details.Text = "" -- Сначала очищаем
                Details.Text = d.fullText
                refreshSelectionColors()
            end)
        end
    end
end)

-- BOTTOM BUTTONS (COPY, CLEAR, EXECUTE)
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), nil, Color3.fromRGB(45, 90, 45)).MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript"); if a then setclipboard(a) end
end)

createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)"); if s then setclipboard(s) end
end)

createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85)).MouseButton1Click:Connect(function()
    MainMemory = {}; lastCount = -1; Details.Text = ""
end)

createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)") or Details.Text; if s then loadstring(s)() end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode; lastCount = -1
    SelfBtn.Text = "SELF: "..(selfMode and "ON" or "OFF")
    SelfBtn.BackgroundColor3 = selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50) 
end)

local function createTypeBtn(text, pos, color, varName)
    local b = Instance.new("TextButton", ContentFrame); b.Size = UDim2.new(0, 150, 0, 35); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 12; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        if varName == "FS" then spyFS = not spyFS elseif varName == "FC" then spyFC = not spyFC else spyIS = not spyIS end
        local st = (varName == "FS" and spyFS or varName == "FC" and spyFC or spyIS)
        b.Text = varName.." SPY: "..(st and "ON" or "OFF"); b.BackgroundColor3 = st and color or Color3.fromRGB(40, 40, 45)
    end)
end
createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), Color3.fromRGB(255, 150, 50), "IS")
