-- [[ KRALLDEN SPY v9.9.0 - DUAL-HOOK HYBRID BYPASS (DEBUG EDITION) ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TextService = game:GetService("TextService")

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

-- Основные переменные и таблицы
local MainMemory = {}
local PathFilter = {}
local ManualBannedPaths = {}
local AntiSpamCooldowns = {}
local AntiSpamCounts = {}

local selfMode = true
local controlMode = true
local antiSpam = true

local spyFS = true
local spyFC = false
local spyIS = false

local sortEnabled = false
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
    if not button or activeFeedbacks[button] then 
        return 
    end
    
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

local function updateDetailsCanvas()
    if DetailsScroll and Details then
        task.defer(function()
            DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, Details.TextBounds.Y + 40)
        end)
    end
end

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then 
        return 
    end
    
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

-- Форматирование данных
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

local function getSortedDetails(d)
    local prefix = d.prefix or ""
    if not sortEnabled then 
        return prefix .. d.fullText 
    end
    
    local displayArgs = formatTableVisual(d.rawArgs)
    local methodName = ""
    if d.type == "IS" then
        methodName = "InvokeServer"
    elseif d.type == "FC" then
        methodName = "FireClient"
    else
        methodName = "FireServer"
    end
    
    return prefix .. string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", d.type, d.path, displayArgs, d.path, methodName, d.argsStr)
end

-- Логика Бан-листа (UI)
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
            Details.Text = getSortedDetails(data)
            updateDetailsCanvas()
            refreshSelectionColors()
        end)
    end
end

-- ================= PATH LOGIC =================
local function getSafePath(obj)
    local p = ""
    local success, err = pcall(function() 
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
    
    if not success then
        warn("[KRALLDEN SPY ERROR] Ошибка внутри вычисления пути getSafePath: " .. tostring(err))
    end
    
    local finalPath = "game." .. p
    return finalPath:gsub("%.%[", "[") 
end

-- ================= ADD LOG =================
local function addLog(rem, args, isSelf, typeLabel)
    if typeLabel == "FS" and not spyFS then return end
    if typeLabel == "FC" and not spyFC then return end
    if typeLabel == "IS" and not spyIS then return end
    
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
            local i = 0
            for k, val in pairs(v) do 
                i = i + 1
                if i > 15 then res = res .. "... " break end
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

    local methodName = (typeLabel == "IS") and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer")
    local displayArgs = (finalArgsStr == "") and "None" or finalArgsStr
    local logDetails = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, displayArgs, eventPath, methodName, finalArgsStr)

    -- Anti-Spam
    if not isSelf and not controlMode and antiSpam then
        local currentTime = tick()
        if (currentTime - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {
                    guid = generateGUID(), prefix = "AUTO-BANNED\n\n", fullText = logDetails,
                    rawArgs = args, type = typeLabel, path = eventPath, argsStr = finalArgsStr
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

    -- Добавление в память
    local newLog = { 
        guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, 
        fullText = logDetails, path = eventPath, argsStr = finalArgsStr, rawArgs = args 
    }
    table.insert(MainMemory, 1, newLog)
    if #MainMemory > 150 then table.remove(MainMemory, 151) end
end

-- ================= ГИБРИДНЫЙ ПЕРЕХВАТ ОЧЕРЕДИ (__namecall + __index) =================
local targetMethods = {
    ["fireserver"] = "FS", ["fireserver"] = "FS",
    ["fireclient"] = "FC", ["fireclient"] = "FC",
    ["invokeserver"] = "IS", ["invokeserver"] = "IS"
}

local logQueue = {}

task.spawn(function()
    while true do
        if #logQueue > 0 then
            local data = table.remove(logQueue, 1)
            -- Обновленный pcall, выводящий ошибку логирования в консоль (F9)
            local success, err = pcall(function()
                addLog(data.rem, data.args, data.isSelf, data.typeLabel)
            end)
            if not success then
                warn("[KRALLDEN SPY ERROR] Сбой обработки лога в очереди: " .. tostring(err))
            end
        end
        task.wait()
    end
end)

local oldNamecall
local oldIndex

-- Ловушка №1: Перехват через __namecall (для стандартных вызовов через ":")
local hook1Success, hook1Err = pcall(function()
    if hookmetamethod then
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local logType = nil
            
            -- Защита от детекта строк и изменения регистра
            if type(method) == "string" then
                logType = targetMethods[string.lower(method)]
            end
            
            if logType then
                local checkSuccess, isInstance = pcall(function() return typeof(self) == "Instance" end)
                if checkSuccess and isInstance then
                    table.insert(logQueue, {rem = self, args = {...}, isSelf = checkcaller(), typeLabel = logType})
                elseif not checkSuccess then
                    warn("[KRALLDEN SPY ERROR] Ошибка проверки self в __namecall: " .. tostring(isInstance))
                end
            end
            return oldNamecall(self, ...)
        end))
        print("[KRALLDEN SPY] Хук __namecall успешно инициализирован.")
    else
        warn("[KRALLDEN SPY WARNING] hookmetamethod недоступен в этом эксплойте.")
    end
end)
if not hook1Success then
    warn("[KRALLDEN SPY ERROR] Критическая ошибка при установке хука __namecall: " .. tostring(hook1Err))
end

-- Ловушка №2: Перехват через __index (Байпассит оптимизированные кэш-вызовы вида RemoteEvent.FireServer)
local hook2Success, hook2Err = pcall(function()
    if hookmetamethod then
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            local checkSuccess, isInstance = pcall(function() return typeof(self) == "Instance" end)
            if checkSuccess and isInstance then
                local logType = nil
                
                -- Защита от детекта строк в индексах
                if type(key) == "string" then
                    logType = targetMethods[string.lower(key)]
                end
                
                if logType then
                    -- Возвращаем прокси-функцию, которая запишет логи при вызове кэшированного метода
                    return newcclosure(function(obj, ...)
                        local innerSuccess, innerInstance = pcall(function() return typeof(obj) == "Instance" end)
                        if innerSuccess and innerInstance then
                            table.insert(logQueue, {rem = obj, args = {...}, isSelf = checkcaller(), typeLabel = logType})
                        elseif not innerSuccess then
                            warn("[KRALLDEN SPY ERROR] Сбой прокси-функции в __index: " .. tostring(innerInstance))
                        end
                        return oldIndex(obj, key)(obj, ...)
                    end)
                end
            end
            return oldIndex(self, key)
        end))
        print("[KRALLDEN SPY] Хук __index успешно инициализирован.")
    end
end)
if not hook2Success then
    warn("[KRALLDEN SPY ERROR] Критическая ошибка при установке хука __index: " .. tostring(hook2Err))
end

-- Резервный вариант, если hookmetamethod сломан во всем эксплойте
if (not oldNamecall and not oldIndex) then
    local fallbackSuccess, fallbackErr = pcall(function()
        local mt = getrawmetatable(game)
        if mt and mt.__namecall then
            oldNamecall = hookfunction(mt.__namecall, newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local logType = nil
                
                if type(method) == "string" then
                    logType = targetMethods[string.lower(method)]
                end
                
                if logType then
                    local checkSuccess, isInstance = pcall(function() return typeof(self) == "Instance" end)
                    if checkSuccess and isInstance then
                        table.insert(logQueue, {rem = self, args = {...}, isSelf = checkcaller(), typeLabel = logType})
                    end
                end
                return oldNamecall(self, ...)
            end))
            print("[KRALLDEN SPY] Аварийный хук применен через getrawmetatable.__namecall.")
        else
            warn("[KRALLDEN SPY ERROR] Не удалось получить метатаблицу игры или метод __namecall.")
        end
    end)
    if not fallbackSuccess then
        warn("[KRALLDEN SPY ERROR] Сбой резервного метода перехвата: " .. tostring(fallbackErr))
    end
end

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

            if foundInBanList then 
                feedback(DelBtn, "UNBANNED") 
            else 
                feedback(DelBtn, "DELETED") 
            end
            
            lastCount = -1
            currentSelectionGUID = nil
            Details.Text = ""
            updateDetailsCanvas()
        end
    end
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                ManualBannedPaths[d.path] = {
                    guid = d.guid, 
                    prefix = "MANUAL BANNED:\n\n", 
                    fullText = d.fullText, 
                    rawArgs = d.rawArgs, 
                    type = d.type, 
                    path = d.path, 
                    argsStr = d.argsStr
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
                updateDetailsCanvas()
                feedback(BlockBtn, "BANNED")
                break
            end
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX = Main.AbsolutePosition.X + Main.AbsoluteSize.X
    local curY = Main.AbsolutePosition.Y
    
    if isMin then
        ContentFrame.Visible = false
        ControlBtn.Visible = false
        SelfBtn.Visible = false
        AntiSpamBtn.Visible = false
        BlockBtn.Visible = false
        DelBtn.Visible = false
        
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true)
        MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible = true
            ControlBtn.Visible = true
            SelfBtn.Visible = true
            DelBtn.Visible = true
            if not controlMode then
                AntiSpamBtn.Visible = true
                BlockBtn.Visible = true
            end
        end)
        MinBtn.Text = "_"
        lastCount = -1
    end
end)

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
        
        for _, v in pairs(Scroll:GetChildren()) do 
            if v:IsA("TextButton") then v:Destroy() end 
        end
        
        local sortedMemory = {}
        for _, d in ipairs(MainMemory) do if d.isSelf then sortedMemory[#sortedMemory + 1] = d end end
        for _, d in ipairs(MainMemory) do if not d.isSelf then sortedMemory[#sortedMemory + 1] = d end end
        
        for i, d in ipairs(sortedMemory) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -6, 0, 30)
            b.LayoutOrder = i
            
            local cleanName = d.name:match("[^%.%[%]]+$") or d.name
            cleanName = cleanName:gsub('^"', ''):gsub('"$', ''):gsub('%]$', '')
            
            local display = string.format("[%s]%s [%s]", d.type, (d.isSelf and " [S]" or ""), cleanName)
            b.Text = display
            
            if currentSelectionGUID == d.guid then
                b.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                if d.isSelf then
                    b.BackgroundColor3 = Color3.fromRGB(45, 90, 45)
                else
                    b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                end
            end
            
            b.TextColor3 = Color3.new(1, 1, 1)
            b.BorderSizePixel = 0
            b.ClipsDescendants = true
            b.Parent = Scroll
            
            b:SetAttribute("GUID", d.guid)
            b:SetAttribute("IsSelf", d.isSelf)
            
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid
                Details.Text = getSortedDetails(d)
                updateDetailsCanvas()
                refreshSelectionColors()
            end)
        end
    end
end)

-- ================= BOTTOM BUTTONS =================
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton")
    b.Size = size or UDim2.new(0, 220, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 14
    b.BorderSizePixel = 0
    b.Parent = ContentFrame
    return b
end

local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 95, 0, 58), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript")
    if a then 
        setclipboard(a) 
        feedback(CopyArgsBtn, "COPIED!")
    end
end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 305, 0.68, 0), UDim2.new(0, 120, 0, 58), Color3.fromRGB(80, 80, 85))
SortBtn.MouseButton1Click:Connect(function()
    sortEnabled = not sortEnabled
    SortBtn.Text = "SORT: " .. (sortEnabled and "ON" or "OFF")
    SortBtn.BackgroundColor3 = sortEnabled and Color3.fromRGB(0, 140, 140) or Color3.fromRGB(80, 80, 85)
    
    if currentSelectionGUID then
        local foundData = nil
        for _, m in pairs(MainMemory) do if m.guid == currentSelectionGUID then foundData = m break end end
        if not foundData then
            for _, d in pairs(ManualBannedPaths) do if d.guid == currentSelectionGUID then foundData = d break end end
        end
        if foundData then
            Details.Text = getSortedDetails(foundData)
            updateDetailsCanvas()
        end
    end
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)")
    if s then 
        setclipboard(s) 
        feedback(CopyScriptBtn, "COPIED!")
    end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if m.isSelf then nM[#nM + 1] = m end end
    MainMemory = nM
    lastCount = -1
    feedback(ClearLogBtn, "CLEARED")
end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if not m.isSelf then nM[#nM + 1] = m end end
    MainMemory = nM
    lastCount = -1
    feedback(ClearSelfBtn, "CLEARED")
end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
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

-- ================= ТРИ КНОПКИ (FS, FC, IS) =================
local function createTypeBtn(text, pos, state, color, varName)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 150, 0, 35)
    b.Position = pos
    b.BackgroundColor3 = state and color or Color3.fromRGB(40, 40, 45)
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.Parent = ContentFrame
    
    b.MouseButton1Click:Connect(function()
        if varName == "FS" then spyFS = not spyFS 
        elseif varName == "FC" then spyFC = not spyFC 
        elseif varName == "IS" then spyIS = not spyIS end

        local currentState = (varName == "FS" and spyFS) or (varName == "FC" and spyFC) or (varName == "IS" and spyIS)
        b.Text = varName .. " SPY: " .. (currentState and "ON" or "OFF")
        b.BackgroundColor3 = currentState and color or Color3.fromRGB(40, 40, 45)
    end)
end

createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
