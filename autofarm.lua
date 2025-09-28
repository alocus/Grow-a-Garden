--[[
    @author depso (depthso)
    @description Grow a Garden auto-farm script (Rayfield UI version)
    https://www.roblox.com/games/126884695634066
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer:WaitForChild("leaderstats")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ShecklesCount = Leaderstats:WaitForChild("Sheckles")
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()

local Window = Rayfield:CreateWindow({
    Name = GameInfo.Name .. " | Depso",
    LoadingTitle = GameInfo.Name,
    LoadingSubtitle = "by depso",
    ConfigurationSaving = {
        Enabled = false
    }
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
    Normal = false,
    Gold = false,
    Rainbow = false
}

--// Dicts for eggs
local EggStock = {}
local OwnedEggs = {}

--// Globals
local SelectedSeed = ""
local SelectedSeedsToBuy = {}
local SelectedEggsToBuy = {}
local AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom, AutoSell, AutoBuyEggs, OnlyShowStock, OnlyShowEggStock, AutoWalk, AutoWalkMaxWait
local AutoWalkStatus = {Text = "None"}

-- UI element references for dynamic updating
local SeedDropdown, EggDropdown

--// Interface functions
local function Plant(Position: Vector3, Seed: string)
    ReplicatedStorage.GameEvents.Plant_RE:FireServer(Position, Seed)
    wait(.3)
end

local function GetFarms()
    return workspace.Farm:GetChildren()
end

local function GetFarmOwner(Farm: Folder): string
    local Important = Farm.Important
    local Data = Important.Data
    local Owner = Data.Owner
    return Owner.Value
end

local function GetFarm(PlayerName: string): Folder?
    local Farms = GetFarms()
    for _, Farm in next, Farms do
        local Owner = GetFarmOwner(Farm)
        if Owner == PlayerName then
            return Farm
        end
    end
    return
end

local IsSelling = false
local function SellInventory()
    local Character = LocalPlayer.Character
    local Previous = Character:GetPivot()
    local PreviousSheckles = ShecklesCount.Value

    if IsSelling then return end
    IsSelling = true

    Character:PivotTo(CFrame.new(62, 4, -26))
    while wait() do
        if ShecklesCount.Value ~= PreviousSheckles then break end
        ReplicatedStorage.GameEvents.Sell_Inventory:FireServer()
    end
    Character:PivotTo(Previous)

    wait(0.2)
    IsSelling = false
end

local function BuySeed(Seed: string)
    ReplicatedStorage.GameEvents.BuySeedStock:FireServer(Seed)
end

local function GetEggStock(IgnoreNoStock: boolean?): table
    local EggShop = PlayerGui:FindFirstChild("Egg_Shop")
    if not EggShop then return {} end
    local Items = EggShop:FindFirstChildWhichIsA("Frame", true)
    if not Items then return {} end

    local NewList = {}

    for _, Item in next, Items:GetChildren() do
        local MainFrame = Item:FindFirstChild("Main_Frame")
        if not MainFrame then continue end

        local StockText = MainFrame:FindFirstChild("Stock_Text")
        if not StockText then continue end
        local StockCount = tonumber(StockText.Text:match("%d+"))

        if IgnoreNoStock then
            if StockCount <= 0 then continue end
            table.insert(NewList, Item.Name)
            continue
        end

        EggStock[Item.Name] = StockCount
    end

    return IgnoreNoStock and NewList or EggStock
end

local function BuyEgg(Egg: string)
    local buyEggEvent = ReplicatedStorage.GameEvents:FindFirstChild("BuyEggStock")
    if buyEggEvent then
        buyEggEvent:FireServer(Egg)
    end
end

local function BuyAllSelectedSeeds()
    local stockTable = SeedStock
    for _, seedName in ipairs(SelectedSeedsToBuy) do
        local stock = stockTable[seedName]
        if stock and stock > 0 then
            for i = 1, stock do
                BuySeed(seedName)
            end
        end
    end
end

local function BuyAllSelectedEggs()
    local stockTable = EggStock
    for _, eggName in ipairs(SelectedEggsToBuy) do
        local stock = stockTable[eggName]
        if stock and stock > 0 then
            for i = 1, stock do
                BuyEgg(eggName)
            end
        end
    end
end

local function GetSeedInfo(Seed: Tool): number?
    local PlantName = Seed:FindFirstChild("Plant_Name")
    local Count = Seed:FindFirstChild("Numbers")
    if not PlantName then return end
    return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds: table)
    for _, Tool in next, Parent:GetChildren() do
        local Name, Count = GetSeedInfo(Tool)
        if not Name then continue end
        Seeds[Name] = {
            Count = Count,
            Tool = Tool
        }
    end
end

local function GetOwnedSeeds(): table
    local Character = LocalPlayer.Character
    for k in pairs(OwnedSeeds) do OwnedSeeds[k] = nil end -- clear table
    CollectSeedsFromParent(Backpack, OwnedSeeds)
    CollectSeedsFromParent(Character, OwnedSeeds)
    return OwnedSeeds
end

local function GetSeedStock(IgnoreNoStock: boolean?): table
    local SeedShop = PlayerGui:FindFirstChild("Seed_Shop")
    if not SeedShop then return {} end
    local Items = SeedShop:FindFirstChildWhichIsA("Frame", true)
    if not Items then return {} end

    local NewList = {}

    for _, Item in next, Items:GetChildren() do
        local MainFrame = Item:FindFirstChild("Main_Frame")
        if not MainFrame then continue end

        local StockText = MainFrame:FindFirstChild("Stock_Text")
        if not StockText then continue end
        local StockCount = tonumber(StockText.Text:match("%d+"))

        if IgnoreNoStock then
            if StockCount <= 0 then continue end
            table.insert(NewList, Item.Name)
            continue
        end

        SeedStock[Item.Name] = StockCount
    end

    return IgnoreNoStock and NewList or SeedStock
end

--// UI Setup (Rayfield)
local PlantTab = Window:CreateTab("Auto-Plant", 4483362458)
local HarvestTab = Window:CreateTab("Auto-Harvest", 4483362458)
local BuyTab = Window:CreateTab("Seed Shop", 4483362458)
local EggTab = Window:CreateTab("Egg Shop", 4483362458)
local SellTab = Window:CreateTab("Auto-Sell", 4483362458)
local WalkTab = Window:CreateTab("Auto-Walk", 4483362458)

-- Auto-Plant
SeedDropdown = PlantTab:CreateDropdown({
    Name = "Seed",
    Options = {},
    MultiSelect = false,
    CurrentOption = "",
    Callback = function(option)
        SelectedSeed = option
    end
})
AutoPlant = PlantTab:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Callback = function(val) AutoPlant = val end
})
AutoPlantRandom = PlantTab:CreateToggle({
    Name = "Plant at random points",
    CurrentValue = false,
    Callback = function(val) AutoPlantRandom = val end
})
PlantTab:CreateButton({
    Name = "Plant all",
    Callback = function()
        -- You may want to call your planting loop here
    end
})

-- Auto-Harvest
AutoHarvest = HarvestTab:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Callback = function(val) AutoHarvest = val end
})
HarvestTab:CreateParagraph({Title = "Ignores", Content = "Normal, Gold, Rainbow (edit code to change)"})

-- Seed Shop (Auto-Buy)
BuyTab:CreateParagraph({Title = "Tip", Content = "If you don't see seeds, open the Seed Shop in-game."})
local function getSeedOptions()
    local opts = {}
    for k, _ in pairs(SeedStock) do
        table.insert(opts, k)
    end
    table.sort(opts)
    return opts
end
SeedDropdown = BuyTab:CreateDropdown({
    Name = "Seeds",
    Options = {},
    MultiSelect = true,
    CurrentOption = {},
    Callback = function(selected)
        SelectedSeedsToBuy = selected
    end
})
AutoBuy = BuyTab:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Callback = function(val) AutoBuy = val end
})
OnlyShowStock = BuyTab:CreateToggle({
    Name = "Only list stock",
    CurrentValue = false,
    Callback = function(val) OnlyShowStock = val end
})
BuyTab:CreateButton({
    Name = "Buy all selected seeds",
    Callback = BuyAllSelectedSeeds
})

-- Egg Shop
EggTab:CreateParagraph({Title = "Tip", Content = "If you don't see eggs, open the Egg Shop in-game."})
local function getEggOptions()
    local opts = {}
    for k, _ in pairs(EggStock) do
        table.insert(opts, k)
    end
    table.sort(opts)
    return opts
end
EggDropdown = EggTab:CreateDropdown({
    Name = "Eggs",
    Options = {},
    MultiSelect = true,
    CurrentOption = {},
    Callback = function(selected)
        SelectedEggsToBuy = selected
    end
})
AutoBuyEggs = EggTab:CreateToggle({
    Name = "Auto-Buy Eggs",
    CurrentValue = false,
    Callback = function(val) AutoBuyEggs = val end
})
OnlyShowEggStock = EggTab:CreateToggle({
    Name = "Only list stock",
    CurrentValue = false,
    Callback = function(val) OnlyShowEggStock = val end
})
EggTab:CreateButton({
    Name = "Buy all selected eggs",
    Callback = BuyAllSelectedEggs
})

-- Auto-Sell
SellTab:CreateButton({
    Name = "Sell inventory",
    Callback = SellInventory
})
AutoSell = SellTab:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Callback = function(val) AutoSell = val end
})
SellThreshold = SellTab:CreateSlider({
    Name = "Crops threshold",
    Range = {1, 199},
    Increment = 1,
    CurrentValue = 15,
    Callback = function(val) SellThreshold = val end
})

-- Auto-Walk
AutoWalkStatus = WalkTab:CreateParagraph({Title = "Status", Content = "None"})
AutoWalk = WalkTab:CreateToggle({
    Name = "Enabled",
    CurrentValue = false,
    Callback = function(val) AutoWalk = val end
})
AutoWalkAllowRandom = WalkTab:CreateToggle({
    Name = "Allow random points",
    CurrentValue = true,
    Callback = function(val) AutoWalkAllowRandom = val end
})
NoClip = WalkTab:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Callback = function(val) NoClip = val end
})
AutoWalkMaxWait = WalkTab:CreateSlider({
    Name = "Max delay",
    Range = {1, 120},
    Increment = 1,
    CurrentValue = 10,
    Callback = function(val) AutoWalkMaxWait = val end
})

--// Connections and Loops (update as needed for Rayfield toggles)
RunService.Stepped:Connect(function()
    if NoClip then
        local Character = LocalPlayer.Character
        if Character then
            for _, Part in ipairs(Character:GetDescendants()) do
                if Part:IsA("BasePart") then
                    Part.CanCollide = false
                end
            end
        end
    end
end)

Backpack.ChildAdded:Connect(function()
    if AutoSell then
        SellInventory()
    end
end)

-- Main update loop: refresh stocks and UI dropdowns
coroutine.wrap(function()
    while wait(1) do
        -- Update stocks
        GetSeedStock()
        GetEggStock()
        GetOwnedSeeds()
        -- Recreate dropdowns with new options
        RefreshSeedDropdown()
        RefreshEggDropdown()
        -- Auto-buy logic
        if AutoBuy then
            BuyAllSelectedSeeds()
        end
        if AutoBuyEggs then
            BuyAllSelectedEggs()
        end
        -- Auto-sell logic
        if AutoSell then
            -- You can add logic to check crop count and call SellInventory if needed
        end
    end
end)()

-- Add your autofarm, autowalk, autoharvest, etc. loops here, using the Rayfield toggles as conditions
