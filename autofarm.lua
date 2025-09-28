--[[
    Grow a Garden Auto-Farm (Rayfield UI)
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
if not loadstring then
    error("Your executor does not support loadstring.")
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = GameInfo.Name .. " | Depso",
    LoadingTitle = GameInfo.Name,
    LoadingSubtitle = "by depso",
    ConfigurationSaving = {Enabled = false}
})

--// Data
local SeedStock, EggStock = {}, {}
local SelectedSeedsToBuy, SelectedEggsToBuy = {}, {}
local AutoBuy, AutoBuyEggs = false, false

--// UI References
local SeedDropdown, EggDropdown

--// Utility Functions
local function GetSeedStock()
    local shop = PlayerGui:FindFirstChild("Seed_Shop")
    if not shop then return {} end
    local items = shop:FindFirstChildWhichIsA("Frame", true)
    if not items then return {} end
    for _, item in ipairs(items:GetChildren()) do
        local mf = item:FindFirstChild("Main_Frame")
        if mf then
            local st = mf:FindFirstChild("Stock_Text")
            if st then
                local count = tonumber(st.Text:match("%d+"))
                SeedStock[item.Name] = count or 0
            end
        end
    end
    return SeedStock
end

local function GetEggStock()
    local shop = PlayerGui:FindFirstChild("Egg_Shop")
    if not shop then return {} end
    local items = shop:FindFirstChildWhichIsA("Frame", true)
    if not items then return {} end
    for _, item in ipairs(items:GetChildren()) do
        local mf = item:FindFirstChild("Main_Frame")
        if mf then
            local st = mf:FindFirstChild("Stock_Text")
            if st then
                local count = tonumber(st.Text:match("%d+"))
                EggStock[item.Name] = count or 0
            end
        end
    end
    return EggStock
end

local function BuySeed(seed)
    ReplicatedStorage.GameEvents.BuySeedStock:FireServer(seed)
end

local function BuyEgg(egg)
    local evt = ReplicatedStorage.GameEvents:FindFirstChild("BuyEggStock")
    if evt then evt:FireServer(egg) end
end

local function BuyAllSelectedSeeds()
    for _, seed in ipairs(SelectedSeedsToBuy) do
        local stock = SeedStock[seed]
        if stock and stock > 0 then
            for _ = 1, stock do BuySeed(seed) end
        end
    end
end

local function BuyAllSelectedEggs()
    for _, egg in ipairs(SelectedEggsToBuy) do
        local stock = EggStock[egg]
        if stock and stock > 0 then
            for _ = 1, stock do BuyEgg(egg) end
        end
    end
end

local function GetSortedKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

--// UI Setup
local BuyTab = Window:CreateTab("Seed Shop", 4483362458)
local EggTab = Window:CreateTab("Egg Shop", 4483362458)

SeedDropdown = BuyTab:CreateDropdown({
    Name = "Seeds",
    Options = {},
    MultiSelect = true,
    CurrentOption = {},
    Callback = function(selected) SelectedSeedsToBuy = selected end
})
BuyTab:CreateButton({
    Name = "Buy all selected seeds",
    Callback = BuyAllSelectedSeeds
})
AutoBuy = BuyTab:CreateToggle({
    Name = "Auto-Buy",
    CurrentValue = false,
    Callback = function(val) AutoBuy = val end
})

EggDropdown = EggTab:CreateDropdown({
    Name = "Eggs",
    Options = {},
    MultiSelect = true,
    CurrentOption = {},
    Callback = function(selected) SelectedEggsToBuy = selected end
})
EggTab:CreateButton({
    Name = "Buy all selected eggs",
    Callback = BuyAllSelectedEggs
})
AutoBuyEggs = EggTab:CreateToggle({
    Name = "Auto-Buy Eggs",
    CurrentValue = false,
    Callback = function(val) AutoBuyEggs = val end
})

--// Dropdown Refresh Helpers
local function RefreshSeedDropdown()
    if SeedDropdown and SeedDropdown.Destroy then SeedDropdown:Destroy() end
    SeedDropdown = BuyTab:CreateDropdown({
        Name = "Seeds",
        Options = GetSortedKeys(SeedStock),
        MultiSelect = true,
        CurrentOption = SelectedSeedsToBuy,
        Callback = function(selected) SelectedSeedsToBuy = selected end
    })
end

local function RefreshEggDropdown()
    if EggDropdown and EggDropdown.Destroy then EggDropdown:Destroy() end
    EggDropdown = EggTab:CreateDropdown({
        Name = "Eggs",
        Options = GetSortedKeys(EggStock),
        MultiSelect = true,
        CurrentOption = SelectedEggsToBuy,
        Callback = function(selected) SelectedEggsToBuy = selected end
    })
end

--// Main Loop
task.spawn(function()
    while task.wait(1) do
        GetSeedStock()
        GetEggStock()
        RefreshSeedDropdown()
        RefreshEggDropdown()
        if AutoBuy then BuyAllSelectedSeeds() end
        if AutoBuyEggs then BuyAllSelectedEggs() end
    end
end)
