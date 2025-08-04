local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled and not UIS.MouseEnabled and not UIS.KeyboardEnabled then
    getgenv().bypass_adonis = true
    loadstring(game:HttpGet('https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/PasteWareMobile.lua'))()
    return
end

if not game:IsLoaded() then 
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

if bypass_adonis then
    task.spawn(function()
        local g = getinfo or debug.getinfo
        local d = false
        local h = {}

        local x, y

        setthreadidentity(2)

        for i, v in getgc(true) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")
            
                if typeof(a) == "function" and not x then
                    x = a
                    local o; o = hookfunction(x, function(c, f, n)
                        if c ~= "_" then
                            if d then
                                warn(`Adonis AntiCheat flagged\nMethod: {c}\nInfo: {f}`)
                            end
                        end
                        
                        return true
                    end)
                    table.insert(h, x)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                    y = b
                    local o; o = hookfunction(y, function(f)
                        if d then
                            warn(`Adonis AntiCheat tried to kill (fallback): {f}`)
                        end
                    end)
                    table.insert(h, y)
                end
            end
        end

        local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local a, f = ...

            if x and a == x then
                if d then
                    warn(`zins | adonis bypassed`)
                end
                return coroutine.yield(coroutine.running())
            end
            
            return o(...)
        end))

        setthreadidentity(7)
    end)
end

local SilentAimSettings = {
    Enabled = false,
    ClassName = "чекать тимейтов",
    ToggleKey = "U",
    TeamCheck = false,
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false,
    HitChance = 100,
    BulletTP = false,
    MultiplyUnitBy = 1,
    BlockedMethods = {},
    Include = {},
    Origin = "Camera"
}

getgenv().SilentAimSettings = SilentAimSettings

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = SilentAimSettings.FOVRadius
fov_circle.Filled = false
fov_circle.Visible = SilentAimSettings.FOVVisible
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    ViewportPointToRay = {ArgCountRequired = 2, Args = {"number", "number"}},
    ScreenPointToRay = {ArgCountRequired = 2, Args = {"number", "number"}},
    Raycast = {ArgCountRequired = 3, Args = {"Instance", "Vector3", "Vector3", "RaycastParams"}},
    FindPartOnRay = {ArgCountRequired = 2, Args = {"Ray", "Instance", "boolean", "boolean"}},
    FindPartOnRayWithIgnoreList = {ArgCountRequired = 3, Args = {"Ray", "table", "boolean", "boolean"}},
    FindPartOnRayWithWhitelist = {ArgCountRequired = 3, Args = {"Ray", "table", "boolean", "boolean"}}
}

function CalculateChance(Percentage)
    Percentage = math.floor(Percentage)
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100
    return chance <= Percentage / 100
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * SilentAimSettings.MultiplyUnitBy
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, SilentAimSettings.TargetPart) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not SilentAimSettings.TargetPart then return end
    local Closest
    local DistanceToMouse
    local ignoredPlayers = SilentAimSettings.PlayerDropdown or {}

    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if ignoredPlayers and ignoredPlayers[Player.Name] then continue end
        if SilentAimSettings.TeamCheck and Player.Team == LocalPlayer.Team then continue end
        local Character = Player.Character
        if not Character then continue end
        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end
        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end
        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or SilentAimSettings.FOVRadius or 2000) then
            Closest = ((SilentAimSettings.TargetPart == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[SilentAimSettings.TargetPart])
            DistanceToMouse = Distance
        end
    end
    return Closest
end

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/linoralib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/manage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/manager.lua"))()

Library.KeybindFrame.Visible = true

local Window = Library:CreateWindow({
    Title = 'By Kotik',
    Center = true,
    AutoShow = true,  
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local GeneralTab = Window:AddTab("Main")
local MainBOX = GeneralTab:AddLeftTabbox("Silent Aim")
local Main = MainBOX:AddTab("сайлент аим")
local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View")
local FieldOfView = FieldOfViewBOX:AddTab("визуалы")
local settingsTab = Window:AddTab("Settings")

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)

Main:AddToggle("aim_Enabled", {Text = "включить"})
    :AddKeyPicker("aim_Enabled_KeyPicker", {
        Default = SilentAimSettings.ToggleKey, 
        SyncToggleState = true, 
        Mode = "Toggle", 
        Text = "включить", 
        NoUI = false
    })

Options.aim_Enabled_KeyPicker:OnClick(function()
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
    Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
    Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
end)

Main:AddToggle("TeamCheck", {
    Text = "чекать тимейтов", 
    Default = SilentAimSettings.TeamCheck
}):OnChanged(function()
    SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
end)

Main:AddToggle("BulletTP", {
    Text = "пуля телепортируется",
    Default = SilentAimSettings.BulletTP,
    Tooltip = "ну че не понятного пуля телепортируется в чела"
}):OnChanged(function()
    SilentAimSettings.BulletTP = Toggles.BulletTP.Value
end)

Main:AddToggle("CheckForFireFunc", {
    Text = "проверка стрельбы типа",
    Default = SilentAimSettings.CheckForFireFunc,
    Tooltip = "проверяет ты ли стреляешь?"
}):OnChanged(function()
    SilentAimSettings.CheckForFireFunc = Toggles.CheckForFireFunc.Value
end)

Main:AddDropdown("TargetPart", {
    AllowNull = true, 
    Text = "куда стрелять?", 
    Default = SilentAimSettings.TargetPart, 
    Values = {"голова", "торс", "на рандом"}
}):OnChanged(function()
    SilentAimSettings.TargetPart = Options.TargetPart.Value
end)

Main:AddDropdown("Method", {
    AllowNull = true,
    Text = "способ работы",
    Default = SilentAimSettings.SilentAimMethod,
    Values = {
        "ViewportPointToRay",
        "ScreenPointToRay",
        "Raycast",
        "FindPartOnRay",
        "FindPartOnRayWithIgnoreList"
    }
}):OnChanged(function() 
    SilentAimSettings.SilentAimMethod = Options.Method.Value 
end)

Main:AddDropdown("Blocked Methods", {
    AllowNull = true,
    Multi = true,
    Text = "обход античита",
    Default = SilentAimSettings.BlockedMethods,
    Values = {
        "Destroy",
        "BulkMoveTo",
        "PivotTo",
        "TranslateBy",
        "SetPrimaryPartCFrame"
    }
}):OnChanged(function()
    SilentAimSettings.BlockedMethods = Options["Blocked Methods"].Value
end)

Main:AddDropdown("Include", {
    AllowNull = true,
    Multi = true,
    Text = "чтобы неубивал себя",
    Default = SilentAimSettings.Include,
    Values = {"камера", "хз"},
    Tooltip = "эта функция чтобы ты не убивал себя"
}):OnChanged(function()
    SilentAimSettings.Include = Options.Include.Value
end)

Main:AddDropdown("Origin", {
    AllowNull = true,
    Multi = true,
    Text = "откуда он будет стрелять",
    Default = SilentAimSettings.Origin,
    Values = {"камера", "кастомная"},
    Tooltip = "она стрелять с того места которое ты выберишь в функциях"
}):OnChanged(function()
    SilentAimSettings.Origin = Options.Origin.Value
end)

Main:AddSlider("MultiplyUnitBy", {
    Text = "как далеко он будет стрелять",
    Default = SilentAimSettings.MultiplyUnitBy,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Compact = false,
    Tooltip = "чем больше тем дальше чем меньше тем короче"
}):OnChanged(function()
    SilentAimSettings.MultiplyUnitBy = Options.MultiplyUnitBy.Value
end)

Main:AddSlider("HitChance", {
    Text = "шанс попадания",
    Default = SilentAimSettings.HitChance,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Compact = false,
}):OnChanged(function()
    SilentAimSettings.HitChance = Options.HitChance.Value
end)

FieldOfView:AddToggle("Visible", {Text = "размер круга"})
    :AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)})
    :OnChanged(function()
        fov_circle.Visible = Toggles.Visible.Value
        SilentAimSettings.FOVVisible = Toggles.Visible.Value
    end)

FieldOfView:AddSlider("Radius", {
    Text = "радиус круга", 
    Min = 0, 
    Max = 360, 
    Default = SilentAimSettings.FOVRadius, 
    Rounding = 0
}):OnChanged(function()
    fov_circle.Radius = Options.Radius.Value
    SilentAimSettings.FOVRadius = Options.Radius.Value
end)

FieldOfView:AddToggle("MousePosition", {Text = "подсвечивает цель"})
    :AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)})
    :OnChanged(function()
        SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value
    end)

FieldOfView:AddDropdown("PlayerDropdown", {
    SpecialType = "Player",
    Text = "игнорировать",
    Tooltip = "кентов в лист добавь чтобы не убивал их:)",
    Multi = true
})

local previousHighlight = nil
local function removeOldHighlight()
    if previousHighlight then
        previousHighlight:Destroy()
        previousHighlight = nil
    end
end

resume(create(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value then
            local closestPlayer = getClosestPlayer()
            if closestPlayer then 
                local Root = closestPlayer.Parent.PrimaryPart or closestPlayer
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position)
                removeOldHighlight()
                if IsOnScreen then
                    local highlight = closestPlayer.Parent:FindFirstChildOfClass("Highlight")
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Parent = closestPlayer.Parent
                        highlight.Adornee = closestPlayer.Parent
                    end
                    highlight.FillColor = Options.MouseVisualizeColor.Value
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Options.MouseVisualizeColor.Value
                    highlight.OutlineTransparency = 0
                    previousHighlight = highlight
                end
            else 
                removeOldHighlight()
            end
        end
        
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = getMousePosition()
        end
    end)
end))

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method, Arguments = getnamecallmethod(), {...}
    local self, chance = Arguments[1], CalculateChance(SilentAimSettings.HitChance)

    local BlockedMethods = SilentAimSettings.BlockedMethods or {}
    if Method == "Destroy" and self == LocalPlayer then
        return
    end
    if table.find(BlockedMethods, Method) then
        return
    end

    local CanContinue = false
    if SilentAimSettings.CheckForFireFunc and (Method == "FindPartOnRay" or Method == "FindPartOnRayWithWhitelist" or Method == "FindPartOnRayWithIgnoreList" or Method == "Raycast" or Method == "ViewportPointToRay" or Method == "ScreenPointToRay") then
        local Traceback = tostring(debug.traceback()):lower()
        if Traceback:find("bullet") or Traceback:find("gun") or Traceback:find("fire") then
            CanContinue = true
        else
            return oldNamecall(...)
        end
    end

    if Toggles.aim_Enabled and Toggles.aim_Enabled.Value and self == workspace and not checkcaller() and chance then
        local HitPart = getClosestPlayer()
        if HitPart then
            local function modifyRay(Origin)
                if SilentAimSettings.BulletTP then
                    Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                end
                return Origin, getDirection(Origin, HitPart.Position)
            end

            if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                    local Origin, Direction = modifyRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                    local Origin, Direction = modifyRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                    local Origin, Direction = modifyRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "Raycast" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                    local Origin, Direction = modifyRay(Arguments[2])
                    Arguments[2], Arguments[3] = Origin, Direction
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "ViewportPointToRay" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.ViewportPointToRay) then
                    local Origin = Camera.CFrame.p
                    if SilentAimSettings.BulletTP then
                        Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                    end
                    Arguments[2] = Camera:WorldToScreenPoint(HitPart.Position)
                    return Ray.new(Origin, (HitPart.Position - Origin).Unit * SilentAimSettings.MultiplyUnitBy)
                end
            elseif Method == "ScreenPointToRay" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.ScreenPointToRay) then
                    local Origin = Camera.CFrame.p
                    if SilentAimSettings.BulletTP then
                        Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                    end
                    Arguments[2] = Camera:WorldToScreenPoint(HitPart.Position)
                    return Ray.new(Origin, (HitPart.Position - Origin).Unit * SilentAimSettings.MultiplyUnitBy)
                end
            end
        end
    end

    return oldNamecall(...)
end))

ThemeManager:LoadDefaultTheme()
