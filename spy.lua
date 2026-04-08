local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local Main = Instance.new("Frame", ScreenGui)
local Title = Instance.new("TextLabel", Main)
local Scroll = Instance.new("ScrollingFrame", Main)
local Details = Instance.new("TextBox", Main)
local Copy = Instance.new("TextButton", Main)

Main.Name = "QSpy"; Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.Position = UDim2.new(0.5, -200, 0.5, -150); Main.Size = UDim2.new(0, 400, 0, 300)
Main.Active = true; Main.Draggable = true

Title.Size = UDim2.new(1, 0, 0, 30); Title.Text = "QuantumSpy v2.2 (Delta)"; Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

Scroll.Position = UDim2.new(0, 5, 0, 35); Scroll.Size = UDim2.new(0, 150, 1, -40)
Scroll.CanvasSize = UDim2.new(0, 0, 50, 0); Scroll.ScrollBarThickness = 3
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

Details.Position = UDim2.new(0, 160, 0, 35); Details.Size = UDim2.new(1, -165, 0.8, 0)
Details.BackgroundColor3 = Color3.fromRGB(20, 20, 20); Details.TextColor3 = Color3.new(0.8, 0.8, 0.8)
Details.MultiLine = true; Details.TextXAlignment = 0; Details.TextYAlignment = 0
Details.Text = "Ожидание ивентов..."; Details.ClearTextOnFocus = false; Details.TextWrapped = true

Copy.Position = UDim2.new(0, 160, 0.85, 5); Copy.Size = UDim2.new(1, -165, 0.1, 0)
Copy.BackgroundColor3 = Color3.fromRGB(60, 100, 60); Copy.Text = "COPY ARGS"; Copy.TextColor3 = Color3.new(1, 1, 1)

local function addLog(rem, args)
    local b = Instance.new("TextButton", Scroll)
    b.Size = UDim2.new(1, 0, 0, 25); b.Text = rem.Name; b.BackgroundColor3 = Color3.fromRGB(50, 50, 50); b.TextColor3 = Color3.new(1, 1, 1)
    b.MouseButton1Click:Connect(function()
        local s = "Path: "..rem:GetFullName().."\n\nArgs: "
        for i, v in pairs(args) do s = s.."\n["..i.."] ("..typeof(v).."): "..tostring(v) end
        Details.Text = s
    end)
end

Copy.MouseButton1Click:Connect(function() setclipboard(Details.Text) end)

local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if (m == "FireServer" or m == "fireServer") and not checkcaller() then
        addLog(self, {...})
    end
    return old(self, ...)
end)
setreadonly(mt, true)
