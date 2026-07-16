--[[
    ███╗   ███╗██╗██╗  ██╗██╗    ██╗ █████╗ ██████╗ ███████╗
    ████╗ ████║██║╚██╗██╔╝██║    ██║██╔══██╗██╔══██╗██╔════╝
    ██╔████╔██║██║ ╚███╔╝ ██║ █╗ ██║███████║██████╔╝█████╗  
    ██║╚██╔╝██║██║ ██╔██╗ ██║███╗██║██╔══██║██╔══██╗██╔══╝  
    ██║ ╚═╝ ██║██║██╔╝ ██╗╚███╔███╔╝██║  ██║██║  ██║███████╗
    ╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
    
    MIXWARE.LOL - Ultimate Roblox Script
    Created by: kt471 & Lmrbro
    Version: 11.0.0 - Dynamic Key Loading via HttpGet
--]]

-- Загрузка Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- ============ ДИНАМИЧЕСКАЯ ЗАГРУЗКА КЛЮЧЕЙ ============
-- ============================================================
local HttpService = game:GetService("HttpService")
local API_URL = "http://93.115.101.161:9781/key/list"

local function FetchKeys()
    local success, response = pcall(function()
        return game:HttpGet(API_URL)
    end)
    
    if not success then
        warn("Не удалось загрузить ключи с сервера, используются запасные")
        return {"MIX2026", "KT471_LMR", "MIXWARE_ULTRA"}
    end
    
    local data
    success, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success or not data or not data.keys then
        warn("Ошибка парсинга JSON, используются запасные ключи")
        return {"MIX2026", "KT471_LMR", "MIXWARE_ULTRA"}
    end
    
    local keys = {}
    for _, k in ipairs(data.keys) do
        if not k.used then
            table.insert(keys, k.key)
        end
    end
    
    if #keys == 0 then
        warn("Нет доступных ключей, используются запасные")
        return {"MIX2026", "KT471_LMR", "MIXWARE_ULTRA"}
    end
    
    return keys
end

-- Загружаем ключи синхронно (скрипт подождёт)
local Keys = FetchKeys()

-- ============================================================
-- ============ ОСТАЛЬНОЙ КОД (ESP, Aimbot, UI) ============
-- ============================================================
-- Основные сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- ============ ESP СИСТЕМА ============
-- ============================================================
local ESPObjects = {}
local ESPEnabled = false
local ESPColor = Color3.fromRGB(180, 80, 255)
local ESPMaxDistance = 500
local ShowBoxes = false
local ShowNames = false
local ShowHealth = false
local ShowDistance = false
local ShowTracers = false
local ShowHeadDots = false
local ShowSkeletons = false
local ShowInventory = false
local TracerPosition = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135)
local TeamCheck = false

-- ============ ПОЛУЧЕНИЕ ИНВЕНТАРЯ ============
local function GetPlayerInventory(Player)
    local Inventory = {}
    local Character = Player.Character
    if not Character then return Inventory end
    
    local Tool = Character:FindFirstChildOfClass("Tool")
    if Tool then
        table.insert(Inventory, {
            Name = Tool.Name,
            Icon = "🔫",
            Active = true
        })
    end
    
    if Player:FindFirstChild("Backpack") then
        for _, item in pairs(Player.Backpack:GetChildren()) do
            if item:IsA("Tool") and (not Tool or item ~= Tool) then
                table.insert(Inventory, {
                    Name = item.Name,
                    Icon = "📦",
                    Active = false
                })
            end
        end
    end
    
    for _, part in pairs(Character:GetChildren()) do
        if part:IsA("Accessory") or part:IsA("Clothing") then
            table.insert(Inventory, {
                Name = part.Name,
                Icon = "👕",
                Active = true
            })
        end
    end
    
    return Inventory
end

-- ============ СОЗДАНИЕ ОБЪЕКТОВ ============
local function CreatePlayerObjects(Player)
    if ESPObjects[Player] then return end
    
    local Objects = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Health = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        TracerOutline = Drawing.new("Line"),
        HeadDot = Drawing.new("Circle"),
        Skeleton = {
            Head = Drawing.new("Line"),
            Torso = Drawing.new("Line"),
            LeftArm = Drawing.new("Line"),
            RightArm = Drawing.new("Line"),
            LeftLeg = Drawing.new("Line"),
            RightLeg = Drawing.new("Line")
        },
        Inventory = {}
    }
    
    Objects.Box.Thickness = 2
    Objects.Box.Filled = false
    Objects.Box.Color = ESPColor
    Objects.Box.Visible = false
    
    Objects.BoxOutline.Thickness = 1
    Objects.BoxOutline.Filled = false
    Objects.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    Objects.BoxOutline.Visible = false
    
    Objects.Name.Size = 16
    Objects.Name.Center = true
    Objects.Name.Outline = true
    Objects.Name.OutlineColor = Color3.fromRGB(0, 0, 0)
    Objects.Name.Color = ESPColor
    Objects.Name.Visible = false
    
    Objects.Health.Size = 14
    Objects.Health.Center = true
    Objects.Health.Outline = true
    Objects.Health.OutlineColor = Color3.fromRGB(0, 0, 0)
    Objects.Health.Visible = false
    
    Objects.Distance.Size = 14
    Objects.Distance.Center = true
    Objects.Distance.Outline = true
    Objects.Distance.OutlineColor = Color3.fromRGB(0, 0, 0)
    Objects.Distance.Visible = false
    
    Objects.Tracer.Thickness = 2
    Objects.Tracer.Color = ESPColor
    Objects.Tracer.Visible = false
    
    Objects.TracerOutline.Thickness = 4
    Objects.TracerOutline.Color = Color3.fromRGB(0, 0, 0)
    Objects.TracerOutline.Visible = false
    
    Objects.HeadDot.Radius = 4
    Objects.HeadDot.Filled = true
    Objects.HeadDot.NumSides = 20
    Objects.HeadDot.Color = ESPColor
    Objects.HeadDot.Visible = false
    
    for _, line in pairs(Objects.Skeleton) do
        line.Thickness = 2
        line.Color = ESPColor
        line.Visible = false
    end
    
    ESPObjects[Player] = Objects
end

-- ============ УДАЛЕНИЕ ОБЪЕКТОВ ============
local function RemovePlayerObjects(Player)
    if ESPObjects[Player] then
        local Objects = ESPObjects[Player]
        pcall(function() Objects.Box:Remove() end)
        pcall(function() Objects.BoxOutline:Remove() end)
        pcall(function() Objects.Name:Remove() end)
        pcall(function() Objects.Health:Remove() end)
        pcall(function() Objects.Distance:Remove() end)
        pcall(function() Objects.Tracer:Remove() end)
        pcall(function() Objects.TracerOutline:Remove() end)
        pcall(function() Objects.HeadDot:Remove() end)
        for _, line in pairs(Objects.Skeleton) do
            pcall(function() line:Remove() end)
        end
        for _, obj in pairs(Objects.Inventory) do
            pcall(function() obj:Remove() end)
        end
        ESPObjects[Player] = nil
    end
end

-- ============ ОЧИСТКА ВСЕГО ============
local function ClearAllESP()
    for Player, _ in pairs(ESPObjects) do
        RemovePlayerObjects(Player)
    end
    ESPObjects = {}
end

-- ============ ОБНОВЛЕНИЕ ESP ============
local function UpdateESP()
    if not ESPEnabled then
        for Player, Objects in pairs(ESPObjects) do
            Objects.Box.Visible = false
            Objects.BoxOutline.Visible = false
            Objects.Name.Visible = false
            Objects.Health.Visible = false
            Objects.Distance.Visible = false
            Objects.Tracer.Visible = false
            Objects.TracerOutline.Visible = false
            Objects.HeadDot.Visible = false
            for _, line in pairs(Objects.Skeleton) do
                line.Visible = false
            end
            for _, obj in pairs(Objects.Inventory) do
                obj.Visible = false
            end
        end
        return
    end
    
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then 
            if ESPObjects[Player] then
                local Objects = ESPObjects[Player]
                Objects.Box.Visible = false
                Objects.BoxOutline.Visible = false
                Objects.Name.Visible = false
                Objects.Health.Visible = false
                Objects.Distance.Visible = false
                Objects.Tracer.Visible = false
                Objects.TracerOutline.Visible = false
                Objects.HeadDot.Visible = false
                for _, line in pairs(Objects.Skeleton) do
                    line.Visible = false
                end
                for _, obj in pairs(Objects.Inventory) do
                    obj.Visible = false
                end
            end
            goto continue
        end
        
        CreatePlayerObjects(Player)
        local Objects = ESPObjects[Player]
        
        local Character = Player.Character
        if not Character then
            Objects.Box.Visible = false
            Objects.BoxOutline.Visible = false
            Objects.Name.Visible = false
            Objects.Health.Visible = false
            Objects.Distance.Visible = false
            Objects.Tracer.Visible = false
            Objects.TracerOutline.Visible = false
            Objects.HeadDot.Visible = false
            for _, line in pairs(Objects.Skeleton) do
                line.Visible = false
            end
            for _, obj in pairs(Objects.Inventory) do
                obj.Visible = false
            end
            goto continue
        end
        
        local Head = Character:FindFirstChild("Head")
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        
        if not Head or not Humanoid or not RootPart then
            Objects.Box.Visible = false
            Objects.BoxOutline.Visible = false
            Objects.Name.Visible = false
            Objects.Health.Visible = false
            Objects.Distance.Visible = false
            Objects.Tracer.Visible = false
            Objects.TracerOutline.Visible = false
            Objects.HeadDot.Visible = false
            for _, line in pairs(Objects.Skeleton) do
                line.Visible = false
            end
            for _, obj in pairs(Objects.Inventory) do
                obj.Visible = false
            end
            goto continue
        end
        
        local Distance = (Camera.CFrame.Position - Head.Position).Magnitude
        if Distance > ESPMaxDistance then
            Objects.Box.Visible = false
            Objects.BoxOutline.Visible = false
            Objects.Name.Visible = false
            Objects.Health.Visible = false
            Objects.Distance.Visible = false
            Objects.Tracer.Visible = false
            Objects.TracerOutline.Visible = false
            Objects.HeadDot.Visible = false
            for _, line in pairs(Objects.Skeleton) do
                line.Visible = false
            end
            for _, obj in pairs(Objects.Inventory) do
                obj.Visible = false
            end
            goto continue
        end
        
        local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Head.Position)
        if not OnScreen or ScreenPos.Z < 0 then
            Objects.Box.Visible = false
            Objects.BoxOutline.Visible = false
            Objects.Name.Visible = false
            Objects.Health.Visible = false
            Objects.Distance.Visible = false
            Objects.Tracer.Visible = false
            Objects.TracerOutline.Visible = false
            Objects.HeadDot.Visible = false
            for _, line in pairs(Objects.Skeleton) do
                line.Visible = false
            end
            for _, obj in pairs(Objects.Inventory) do
                obj.Visible = false
            end
            goto continue
        end
        
        local Color = ESPColor
        if TeamCheck and Player.Team == LocalPlayer.Team then
            Color = Color3.fromRGB(0, 255, 0)
        end
        
        local ScreenX, ScreenY = ScreenPos.X, ScreenPos.Y
        
        -- Бокс
        if ShowBoxes then
            local Size = Head.Size.Y * 2.5
            local TopPos = Camera:WorldToViewportPoint((Head.CFrame * CFrame.new(0, Size/2, 0)).Position)
            local BottomPos = Camera:WorldToViewportPoint((Head.CFrame * CFrame.new(0, -Size/2, 0)).Position)
            local Width = math.abs(TopPos.X - BottomPos.X) / 2
            
            Objects.Box.Visible = true
            Objects.Box.Color = Color
            Objects.Box.Position = Vector2.new(ScreenX - Width, ScreenY - Size/2)
            Objects.Box.Size = Vector2.new(Width * 2, Size)
            
            Objects.BoxOutline.Visible = true
            Objects.BoxOutline.Position = Objects.Box.Position + Vector2.new(-1, -1)
            Objects.BoxOutline.Size = Objects.Box.Size + Vector2.new(2, 2)
        else
            Objects.Box.Visible = false
            Objects.BoxOutline.Visible = false
        end
        
        -- Имя
        if ShowNames then
            Objects.Name.Visible = true
            Objects.Name.Color = Color
            Objects.Name.Text = Player.Name
            Objects.Name.Position = Vector2.new(ScreenX, ScreenY - 60)
        else
            Objects.Name.Visible = false
        end
        
        -- Здоровье
        if ShowHealth then
            Objects.Health.Visible = true
            local Percent = Humanoid.Health / Humanoid.MaxHealth * 100
            local HealthColor = Percent > 50 and Color3.fromRGB(0, 255, 0) or 
                              Percent > 25 and Color3.fromRGB(255, 255, 0) or 
                              Color3.fromRGB(255, 0, 0)
            Objects.Health.Color = HealthColor
            Objects.Health.Text = string.format("[%d/%d]", Humanoid.Health, Humanoid.MaxHealth)
            Objects.Health.Position = Vector2.new(ScreenX, ScreenY - 40)
        else
            Objects.Health.Visible = false
        end
        
        -- Дистанция
        if ShowDistance then
            Objects.Distance.Visible = true
            Objects.Distance.Text = string.format("[%dm]", math.floor(Distance))
            Objects.Distance.Position = Vector2.new(ScreenX, ScreenY - 25)
        else
            Objects.Distance.Visible = false
        end
        
        -- Трассер
        if ShowTracers then
            Objects.Tracer.Visible = true
            Objects.Tracer.Color = Color
            Objects.Tracer.From = TracerPosition
            Objects.Tracer.To = Vector2.new(ScreenX, ScreenY)
            
            Objects.TracerOutline.Visible = true
            Objects.TracerOutline.From = TracerPosition
            Objects.TracerOutline.To = Vector2.new(ScreenX, ScreenY)
        else
            Objects.Tracer.Visible = false
            Objects.TracerOutline.Visible = false
        end
        
        -- Точка на голове
        if ShowHeadDots then
            Objects.HeadDot.Visible = true
            Objects.HeadDot.Color = Color
            Objects.HeadDot.Position = Vector2.new(ScreenX, ScreenY)
        else
            Objects.HeadDot.Visible = false
        end
        
        -- Скелет
        if ShowSkeletons then
            local function GetPartPos(Part)
                if not Part then return nil end
                local Pos, Vis = Camera:WorldToViewportPoint(Part.Position)
                if Vis and Pos.Z > 0 then
                    return Vector2.new(Pos.X, Pos.Y)
                end
                return nil
            end
            
            local HeadPos = GetPartPos(Head)
            local Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
            local LeftArm = Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftUpperArm")
            local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightUpperArm")
            local LeftLeg = Character:FindFirstChild("Left Leg") or Character:FindFirstChild("LeftLowerLeg")
            local RightLeg = Character:FindFirstChild("Right Leg") or Character:FindFirstChild("RightLowerLeg")
            
            local TorsoPos = GetPartPos(Torso)
            local LeftArmPos = GetPartPos(LeftArm)
            local RightArmPos = GetPartPos(RightArm)
            local LeftLegPos = GetPartPos(LeftLeg)
            local RightLegPos = GetPartPos(RightLeg)
            
            local SkeletonLines = {
                {Objects.Skeleton.Head, HeadPos, TorsoPos},
                {Objects.Skeleton.Torso, TorsoPos, RootPart and GetPartPos(RootPart)},
                {Objects.Skeleton.LeftArm, TorsoPos, LeftArmPos},
                {Objects.Skeleton.RightArm, TorsoPos, RightArmPos},
                {Objects.Skeleton.LeftLeg, TorsoPos, LeftLegPos},
                {Objects.Skeleton.RightLeg, TorsoPos, RightLegPos}
            }
            
            for _, data in ipairs(SkeletonLines) do
                local Line, From, To = data[1], data[2], data[3]
                if From and To then
                    Line.Visible = true
                    Line.Color = Color
                    Line.From = From
                    Line.To = To
                else
                    Line.Visible = false
                end
            end
        else
            for _, line in pairs(Objects.Skeleton) do
                line.Visible = false
            end
        end
        
        -- ============ ИНВЕНТАРНАЯ ТАБЛИЦА ============
        if ShowInventory then
            local InventoryItems = GetPlayerInventory(Player)
            
            for _, obj in pairs(Objects.Inventory) do
                pcall(function() obj:Remove() end)
            end
            Objects.Inventory = {}
            
            if #InventoryItems > 0 then
                local TableWidth = 200
                local RowHeight = 20
                local Padding = 5
                local Rows = #InventoryItems + 1
                local TableHeight = Rows * RowHeight + Padding * 2
                
                local TablePos = Vector2.new(
                    ScreenX + 10,
                    ScreenY - TableHeight / 2 - 10
                )
                
                TablePos = Vector2.new(
                    math.clamp(TablePos.X, 10, Camera.ViewportSize.X - TableWidth - 10),
                    math.clamp(TablePos.Y, 10, Camera.ViewportSize.Y - TableHeight - 10)
                )
                
                -- Фон
                local Background = Drawing.new("Square")
                Background.Visible = true
                Background.Filled = true
                Background.Color = Color3.fromRGB(15, 15, 30)
                Background.Transparency = 0.9
                Background.Position = TablePos
                Background.Size = Vector2.new(TableWidth, TableHeight)
                table.insert(Objects.Inventory, Background)
                
                -- Рамка
                local Border = Drawing.new("Square")
                Border.Visible = true
                Border.Filled = false
                Border.Color = Color
                Border.Thickness = 2
                Border.Position = TablePos
                Border.Size = Vector2.new(TableWidth, TableHeight)
                table.insert(Objects.Inventory, Border)
                
                -- Заголовок
                local Title = Drawing.new("Text")
                Title.Visible = true
                Title.Text = "🎒 " .. Player.Name
                Title.Color = Color
                Title.Size = 14
                Title.Center = true
                Title.Outline = true
                Title.OutlineColor = Color3.fromRGB(0, 0, 0)
                Title.Position = Vector2.new(TablePos.X + TableWidth / 2, TablePos.Y + 3)
                table.insert(Objects.Inventory, Title)
                
                -- Разделитель
                local Divider = Drawing.new("Line")
                Divider.Visible = true
                Divider.Color = Color
                Divider.Thickness = 1
                Divider.Transparency = 0.5
                Divider.From = Vector2.new(TablePos.X + 10, TablePos.Y + RowHeight + 2)
                Divider.To = Vector2.new(TablePos.X + TableWidth - 10, TablePos.Y + RowHeight + 2)
                table.insert(Objects.Inventory, Divider)
                
                -- Строки
                for i, item in ipairs(InventoryItems) do
                    local Y = TablePos.Y + Padding + i * RowHeight
                    
                    local Icon = Drawing.new("Text")
                    Icon.Visible = true
                    Icon.Text = item.Icon
                    Icon.Color = Color3.fromRGB(255, 255, 255)
                    Icon.Size = 12
                    Icon.Position = Vector2.new(TablePos.X + 5, Y)
                    table.insert(Objects.Inventory, Icon)
                    
                    local Name = Drawing.new("Text")
                    Name.Visible = true
                    Name.Text = item.Name
                    Name.Color = item.Active and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(200, 200, 200)
                    Name.Size = 12
                    Name.Position = Vector2.new(TablePos.X + 22, Y)
                    Name.Outline = true
                    Name.OutlineColor = Color3.fromRGB(0, 0, 0)
                    table.insert(Objects.Inventory, Name)
                    
                    if item.Active then
                        local ActiveTag = Drawing.new("Text")
                        ActiveTag.Visible = true
                        ActiveTag.Text = "⚡"
                        ActiveTag.Color = Color3.fromRGB(0, 255, 0)
                        ActiveTag.Size = 11
                        ActiveTag.Position = Vector2.new(TablePos.X + TableWidth - 15, Y)
                        table.insert(Objects.Inventory, ActiveTag)
                    end
                end
            end
        else
            for _, obj in pairs(Objects.Inventory) do
                pcall(function() obj:Remove() end)
            end
            Objects.Inventory = {}
        end
        
        ::continue::
    end
end

-- ============================================================
-- ============ АИМБОТ БИБЛИОТЕКА ============
-- ============================================================
local AimbotLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/Aimbot/Aimbot"))()
local Aimbot = AimbotLibrary.new()

-- ============================================================
-- ============ КОНФИГУРАЦИЯ ============
-- ============================================================
local Config = {
    ESPEnabled = false,
    ShowBoxes = false,
    ShowNames = false,
    ShowHealth = false,
    ShowDistance = false,
    ShowTracers = false,
    ShowHeadDots = false,
    ShowSkeletons = false,
    ShowInventory = false,
    ESPColor = Color3.fromRGB(180, 80, 255),
    ESPMaxDistance = 500,
    TeamCheck = false,
    
    AimbotEnabled = false,
    AimbotKey = Enum.UserInputType.MouseButton2,
    AimbotSmoothness = 0.3,
    AimbotFOV = 150,
    AimbotPriority = "Distance",
    AimbotTeamCheck = false,
    AimbotVisibleCheck = true,
    AimbotLockPart = "Head",
    
    NoClipEnabled = false,
    SpeedEnabled = false,
    SpeedValue = 50,
    JumpPowerEnabled = false,
    JumpPowerValue = 50,
    TriggerbotEnabled = false,
    TriggerbotDelay = 0.1,
    
    MenuKey = Enum.KeyCode.K
}

local OriginalFOV = Camera.FieldOfView

-- ============================================================
-- ============ ТЕМА MIXWARE ============
-- ============================================================
local MixwareTheme = {
    TextColor = Color3.fromRGB(220, 200, 255),
    Background = Color3.fromRGB(20, 10, 35),
    Topbar = Color3.fromRGB(40, 20, 60),
    Shadow = Color3.fromRGB(15, 5, 25),
    NotificationBackground = Color3.fromRGB(30, 15, 50),
    NotificationActionsBackground = Color3.fromRGB(60, 30, 90),
    TabBackground = Color3.fromRGB(45, 25, 65),
    TabStroke = Color3.fromRGB(80, 40, 120),
    TabBackgroundSelected = Color3.fromRGB(180, 80, 255),
    TabTextColor = Color3.fromRGB(200, 180, 220),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
    ElementBackground = Color3.fromRGB(35, 20, 55),
    ElementBackgroundHover = Color3.fromRGB(50, 30, 75),
    SecondaryElementBackground = Color3.fromRGB(25, 15, 40),
    ElementStroke = Color3.fromRGB(80, 40, 120),
    SecondaryElementStroke = Color3.fromRGB(60, 30, 90),
    SliderBackground = Color3.fromRGB(180, 80, 255),
    SliderProgress = Color3.fromRGB(200, 100, 255),
    SliderStroke = Color3.fromRGB(220, 120, 255),
    ToggleBackground = Color3.fromRGB(30, 15, 50),
    ToggleEnabled = Color3.fromRGB(180, 80, 255),
    ToggleDisabled = Color3.fromRGB(80, 40, 120),
    ToggleEnabledStroke = Color3.fromRGB(200, 100, 255),
    ToggleDisabledStroke = Color3.fromRGB(100, 50, 150),
    ToggleEnabledOuterStroke = Color3.fromRGB(150, 70, 220),
    ToggleDisabledOuterStroke = Color3.fromRGB(60, 30, 90),
    DropdownSelected = Color3.fromRGB(50, 30, 75),
    DropdownUnselected = Color3.fromRGB(30, 15, 50),
    InputBackground = Color3.fromRGB(30, 15, 50),
    InputStroke = Color3.fromRGB(80, 40, 120),
    PlaceholderColor = Color3.fromRGB(150, 130, 180)
}

-- ============================================================
-- ============ НАСТРОЙКА АИМБОТА ============
-- ============================================================
Aimbot:SetSmoothness(Config.AimbotSmoothness)
Aimbot:SetFOV(Config.AimbotFOV)
Aimbot:SetPriority(Config.AimbotPriority)
Aimbot:SetTeamCheck(Config.AimbotTeamCheck)
Aimbot:SetVisibleCheck(Config.AimbotVisibleCheck)
Aimbot:SetLockPart(Config.AimbotLockPart)
Aimbot:SetEnabled(Config.AimbotEnabled)

-- ============================================================
-- ============ СОЗДАНИЕ ОКНА RAYFIELD ============
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "💜 MIXWARE.LOL [kt471 | Lmrbro]",
    LoadingTitle = "MIXWARE LOADING...",
    LoadingSubtitle = "Created by kt471 & Lmrbro",
    Theme = MixwareTheme,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MixwareConfig",
        FileName = "MixwareSettings"
    },
    Discord = {
        Enabled = true,
        Invite = "mixware",
        RememberJoins = true
    },
    KeySystem = true,
    KeySettings = {
        Title = "💜 MIXWARE Auth",
        Subtitle = "Введите ключ для доступа",
        Note = "Ключи динамически загружены с сервера",
        FileName = "MixwareKey",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = Keys -- Динамически загруженные ключи
    }
})

-- ============================================================
-- ============ ВКЛАДКИ (полный функционал) ============
-- ============================================================
local MovementTab = Window:CreateTab("🚀 Движение", 4483362458)
local VisualTab = Window:CreateTab("👁️ Визуал", 4483362458)
local CombatTab = Window:CreateTab("🎯 Бой", 4483362458)
local SettingsTab = Window:CreateTab("⚙️ Настройки", 4483362458)
local ScriptTab = Window:CreateTab("📜 Скрипты", 4483362458)
local ThemeTab = Window:CreateTab("🎨 Оформление", 4483362458)

-- ============================================================
-- ============ ВКЛАДКА ДВИЖЕНИЕ ============
-- ============================================================
MovementTab:CreateSection("Скорость")

local SpeedToggle = MovementTab:CreateToggle({
    Name = "⚡ Скорость",
    CurrentValue = Config.SpeedEnabled,
    Flag = "SpeedToggle",
    Callback = function(Value)
        Config.SpeedEnabled = Value
    end
})

local SpeedSlider = MovementTab:CreateSlider({
    Name = "Скорость ходьбы",
    Range = {16, 100},
    Increment = 1,
    Suffix = "ед.",
    CurrentValue = Config.SpeedValue,
    Flag = "SpeedValue",
    Callback = function(Value)
        Config.SpeedValue = Value
    end
})

MovementTab:CreateSection("Прыжок")

local JumpToggle = MovementTab:CreateToggle({
    Name = "🦘 Высокий прыжок",
    CurrentValue = Config.JumpPowerEnabled,
    Flag = "JumpToggle",
    Callback = function(Value)
        Config.JumpPowerEnabled = Value
    end
})

local JumpSlider = MovementTab:CreateSlider({
    Name = "Сила прыжка",
    Range = {50, 200},
    Increment = 1,
    Suffix = "ед.",
    CurrentValue = Config.JumpPowerValue,
    Flag = "JumpValue",
    Callback = function(Value)
        Config.JumpPowerValue = Value
    end
})

MovementTab:CreateSection("NoClip")

local NoClipToggle = MovementTab:CreateToggle({
    Name = "👻 Сквозь стены (NoClip)",
    CurrentValue = Config.NoClipEnabled,
    Flag = "NoClipToggle",
    Callback = function(Value)
        Config.NoClipEnabled = Value
        if Value and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        elseif LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
})

-- ============================================================
-- ============ ВКЛАДКА ВИЗУАЛ ============
-- ============================================================
VisualTab:CreateSection("Основные настройки ESP")

local ESPToggle = VisualTab:CreateToggle({
    Name = "👁️ Включить ESP",
    CurrentValue = Config.ESPEnabled,
    Flag = "ESPToggle",
    Callback = function(Value)
        Config.ESPEnabled = Value
        ESPEnabled = Value
        if not Value then
            ClearAllESP()
        end
    end
})

VisualTab:CreateSection("Типы ESP")

local ESPBoxesToggle = VisualTab:CreateToggle({
    Name = "📦 Боксы",
    CurrentValue = Config.ShowBoxes,
    Flag = "ESPBoxes",
    Callback = function(Value)
        Config.ShowBoxes = Value
        ShowBoxes = Value
    end
})

local ESPNamesToggle = VisualTab:CreateToggle({
    Name = "🏷️ Имена",
    CurrentValue = Config.ShowNames,
    Flag = "ESPNames",
    Callback = function(Value)
        Config.ShowNames = Value
        ShowNames = Value
    end
})

local ESPHealthToggle = VisualTab:CreateToggle({
    Name = "❤️ Здоровье",
    CurrentValue = Config.ShowHealth,
    Flag = "ESPHealth",
    Callback = function(Value)
        Config.ShowHealth = Value
        ShowHealth = Value
    end
})

local ESPDistanceToggle = VisualTab:CreateToggle({
    Name = "📏 Дистанция",
    CurrentValue = Config.ShowDistance,
    Flag = "ESPDistance",
    Callback = function(Value)
        Config.ShowDistance = Value
        ShowDistance = Value
    end
})

local ESPTracersToggle = VisualTab:CreateToggle({
    Name = "🔺 Трейсеры",
    CurrentValue = Config.ShowTracers,
    Flag = "ESPTracers",
    Callback = function(Value)
        Config.ShowTracers = Value
        ShowTracers = Value
    end
})

local ESPHeadDotsToggle = VisualTab:CreateToggle({
    Name = "🔴 Точка на голове",
    CurrentValue = Config.ShowHeadDots,
    Flag = "ESPHeadDots",
    Callback = function(Value)
        Config.ShowHeadDots = Value
        ShowHeadDots = Value
    end
})

local ESPSkeletonsToggle = VisualTab:CreateToggle({
    Name = "💀 Скелетоны",
    CurrentValue = Config.ShowSkeletons,
    Flag = "ESPSkeletons",
    Callback = function(Value)
        Config.ShowSkeletons = Value
        ShowSkeletons = Value
    end
})

local ESPInventoryToggle = VisualTab:CreateToggle({
    Name = "🎒 Инвентарь (таблица рядом с игроком)",
    CurrentValue = Config.ShowInventory,
    Flag = "ESPInventory",
    Callback = function(Value)
        Config.ShowInventory = Value
        ShowInventory = Value
    end
})

VisualTab:CreateSection("Настройки цвета")

local ESPColorPicker = VisualTab:CreateColorPicker({
    Name = "🎨 Цвет ESP",
    Color = Config.ESPColor,
    Flag = "ESPColor",
    Callback = function(Color)
        Config.ESPColor = Color
        ESPColor = Color
    end
})

VisualTab:CreateSection("Дополнительные настройки")

local ESPDistanceSlider = VisualTab:CreateSlider({
    Name = "📏 Макс. дистанция",
    Range = {0, 1000},
    Increment = 50,
    Suffix = "studs",
    CurrentValue = Config.ESPMaxDistance,
    Flag = "ESPMaxDistance",
    Callback = function(Value)
        Config.ESPMaxDistance = Value
        ESPMaxDistance = Value
    end
})

local ESPTeamCheckToggle = VisualTab:CreateToggle({
    Name = "👥 Командный цвет (зелёный)",
    CurrentValue = Config.TeamCheck,
    Flag = "ESPTeamCheck",
    Callback = function(Value)
        Config.TeamCheck = Value
        TeamCheck = Value
    end
})

VisualTab:CreateSection("Настройки камеры")

local CameraFOVSlider = VisualTab:CreateSlider({
    Name = "📷 FOV камеры",
    Range = {10, 120},
    Increment = 5,
    Suffix = "°",
    CurrentValue = Camera.FieldOfView,
    Flag = "CameraFOV",
    Callback = function(Value)
        Camera.FieldOfView = Value
    end
})

local ResetFOVButton = VisualTab:CreateButton({
    Name = "🔄 Сброс FOV",
    Callback = function()
        Camera.FieldOfView = OriginalFOV
        CameraFOVSlider:Set(OriginalFOV)
    end
})

-- ============================================================
-- ============ ВКЛАДКА БОЙ ============
-- ============================================================
CombatTab:CreateSection("Аимбот")

local AimbotToggle = CombatTab:CreateToggle({
    Name = "🎯 Аимбот (ПКМ)",
    CurrentValue = Config.AimbotEnabled,
    Flag = "AimbotToggle",
    Callback = function(Value)
        Config.AimbotEnabled = Value
        Aimbot:SetEnabled(Value)
    end
})

CombatTab:CreateSection("Настройки аимбота")

local SmoothnessSlider = CombatTab:CreateSlider({
    Name = "Плавность",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "ед.",
    CurrentValue = Config.AimbotSmoothness,
    Flag = "Smoothness",
    Callback = function(Value)
        Config.AimbotSmoothness = Value
        Aimbot:SetSmoothness(Value)
    end
})

local FOVSlider = CombatTab:CreateSlider({
    Name = "Поле зрения (FOV)",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = Config.AimbotFOV,
    Flag = "AimbotFOV",
    Callback = function(Value)
        Config.AimbotFOV = Value
        Aimbot:SetFOV(Value)
    end
})

local PriorityDropdown = CombatTab:CreateDropdown({
    Name = "Приоритет цели",
    Options = {"Distance", "Health", "ClosestToCrosshair"},
    CurrentOption = Config.AimbotPriority,
    Flag = "Priority",
    Callback = function(Option)
        Config.AimbotPriority = Option
        Aimbot:SetPriority(Option)
    end
})

local LockPartDropdown = CombatTab:CreateDropdown({
    Name = "Часть тела для прицела",
    Options = {"Head", "Torso", "HumanoidRootPart"},
    CurrentOption = Config.AimbotLockPart,
    Flag = "LockPart",
    Callback = function(Option)
        Config.AimbotLockPart = Option
        Aimbot:SetLockPart(Option)
    end
})

local TeamCheckToggle = CombatTab:CreateToggle({
    Name = "🚫 Игнорировать тиммейтов",
    CurrentValue = Config.AimbotTeamCheck,
    Flag = "TeamCheck",
    Callback = function(Value)
        Config.AimbotTeamCheck = Value
        Aimbot:SetTeamCheck(Value)
    end
})

local VisibleCheckToggle = CombatTab:CreateToggle({
    Name = "👁️ Только видимые цели",
    CurrentValue = Config.AimbotVisibleCheck,
    Flag = "VisibleCheck",
    Callback = function(Value)
        Config.AimbotVisibleCheck = Value
        Aimbot:SetVisibleCheck(Value)
    end
})

CombatTab:CreateSection("Триггербот")

local TriggerbotToggle = CombatTab:CreateToggle({
    Name = "🔫 Триггербот",
    CurrentValue = Config.TriggerbotEnabled,
    Flag = "Triggerbot",
    Callback = function(Value)
        Config.TriggerbotEnabled = Value
    end
})

local TriggerbotDelaySlider = CombatTab:CreateSlider({
    Name = "Задержка",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "сек.",
    CurrentValue = Config.TriggerbotDelay,
    Flag = "TriggerbotDelay",
    Callback = function(Value)
        Config.TriggerbotDelay = Value
    end
})

-- ============================================================
-- ============ ВКЛАДКА СКРИПТЫ ============
-- ============================================================
ScriptTab:CreateSection("Запуск скриптов")

local Script99n = ScriptTab:CreateButton({
    Name = "🏕 99 ночей",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/VapeVoidware/VW-Add/main/nightsintheforest.lua", true))()
    end
})

local ScriptMM2 = ScriptTab:CreateButton({
    Name = "🔪 MM2",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/vertex-peak/vertex/refs/heads/main/loadstring"))()
    end
})

-- ============================================================
-- ============ ВКЛАДКА НАСТРОЙКИ ============
-- ============================================================
SettingsTab:CreateSection("Управление меню")

local HideMenuButton = SettingsTab:CreateButton({
    Name = "👁️ Скрыть меню (K)",
    Callback = function()
        Rayfield:SetVisibility(false)
    end
})

local ShowMenuButton = SettingsTab:CreateButton({
    Name = "👁️ Показать меню",
    Callback = function()
        Rayfield:SetVisibility(true)
    end
})

-- ============================================================
-- ============ ВКЛАДКА ОФОРМЛЕНИЕ ============
-- ============================================================
ThemeTab:CreateSection("Настройки темы")

local ThemeDropdown = ThemeTab:CreateDropdown({
    Name = "🎨 Выбор темы",
    Options = {"MIXWARE (Фиолетовая)", "Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity"},
    CurrentOption = "MIXWARE (Фиолетовая)",
    Flag = "ThemeDropdown",
    Callback = function(Option)
        if Option == "MIXWARE (Фиолетовая)" then
            Window:ModifyTheme(MixwareTheme)
        else
            Window:ModifyTheme(Option)
        end
    end
})

-- ============================================================
-- ============ ОБРАБОТЧИКИ КЛАВИШ ============
-- ============================================================
UserInputService.InputBegan:Connect(function(input)
    if Config.AimbotEnabled and input.UserInputType == Config.AimbotKey then
        Aimbot:Start()
    end
    
    if input.KeyCode == Enum.KeyCode.N then
        Config.NoClipEnabled = not Config.NoClipEnabled
        NoClipToggle:Set(Config.NoClipEnabled)
        if Config.NoClipEnabled and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        elseif LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
    
    if input.KeyCode == Config.MenuKey then
        Rayfield:SetVisibility(not Rayfield.Visible)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if Config.AimbotEnabled and input.UserInputType == Config.AimbotKey then
        Aimbot:Stop()
    end
end)

-- ============================================================
-- ============ ОСНОВНОЙ ЦИКЛ ============
-- ============================================================
RunService.Heartbeat:Connect(function()
    if Config.SpeedEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Config.SpeedValue
        end
    end
    
    if Config.JumpPowerEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = Config.JumpPowerValue
        end
    end
    
    if Config.NoClipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    if Config.TriggerbotEnabled then
        local target = Aimbot:GetTarget()
        if target then
            pcall(function()
                mouse1press()
                wait(Config.TriggerbotDelay)
                mouse1release()
            end)
        end
    end
    
    UpdateESP()
end)

-- ============================================================
-- ============ ЗАПУСК ============
-- ============================================================
Rayfield:LoadConfiguration()

task.spawn(function()
    wait(2)
    Rayfield:Notify({
        Title = "💜 MIXWARE.LOL",
        Content = "Загружено! kt471 & Lmrbro",
        Duration = 5
    })
    Rayfield:Notify({
        Title = "🎮 Управление",
        Content = "K - меню | N - NoClip | ПКМ - аимбот",
        Duration = 5
    })
end)
