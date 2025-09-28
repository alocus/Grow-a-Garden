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

print("[AutoFarm] Services and player variables initialized.")

--// Rayfield UI
if not loadstring then
    error("Your executor does not support loadstring.")
end

print("[AutoFarm] Loading Rayfield UI library...")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
print("[AutoFarm] Rayfield UI loaded.")

local Window = Rayfield:CreateWindow({
    Name = GameInfo.Name .. " | Depso",
    LoadingTitle = GameInfo.Name,
    LoadingSubtitle = "by depso",
    ConfigurationSaving = {Enabled = false}
})
print("[AutoFarm] Rayfield window created.")

--// Data
local SeedStock, EggStock = {}, {}
local SelectedSeedsToBuy, SelectedEggsToBuy = {}, {}
local AutoBuy, AutoBuyEggs = false, false

-- Add this global toggle at the top of your script (after your data section)
local RunInLoop = false -- Set to true for loop, false for one-time run

--// UI References
local SeedDropdown, EggDropdown

--// Utility Functions
local function GetSeedStock()
    print("[AutoFarm] Fetching seed stock from Seed Shop UI...")
    -- Clear the SeedStock table before repopulating
    for k in pairs(SeedStock) do
        SeedStock[k] = nil
    end

    local shop = PlayerGui:FindFirstChild("Seed_Shop")
    if not shop then print("[AutoFarm] Seed_Shop UI not found."); return {} end
    local blueberry = shop:FindFirstChild("Blueberry", true)
    if not blueberry then print("[AutoFarm] Could not find 'Blueberry' seed frame."); return {} end
    local items = blueberry.Parent
    for _, item in ipairs(items:GetChildren()) do
        print(string.format("[AutoFarm] --- Properties for item: %s ---", item.Name))
        for _, prop in ipairs(item:GetChildren()) do
            if prop:IsA("Instance") then
                for _, subprop in ipairs(prop:GetChildren()) do
                    if subprop:IsA("ValueBase") then
                        print(string.format("  %s.%s = %s", prop.Name, subprop.Name, tostring(subprop.Value)))
                    elseif subprop:IsA("Instance") then
                        print(string.format("  %s.%s = %s", prop.Name, subprop.Name, tostring(subprop)))
                    end
                end
            end
            if prop:IsA("ValueBase") then
                print(string.format("  %s = %s", prop.Name, tostring(prop.Value)))
            elseif prop:IsA("Instance") then
                print(string.format("  %s = %s", prop.Name, tostring(prop)))
            end
        end
        -- Print attributes as well
        local attributes = item:GetAttributes()
        for key, value in pairs(attributes) do
            print(string.format("  [Attribute] %s = %s", key, tostring(value)))
        end
        print("[AutoFarm] --- End of properties ---")
        local mf = item:FindFirstChild("Main_Frame")
        if mf then
            local st = mf:FindFirstChild("Stock_Text")
            if st then
                local count = tonumber(st.Text:match("%d+"))
                SeedStock[item.Name] = count or 0
                print(string.format("[AutoFarm] Seed: %s | Stock: %d", item.Name, count or 0))
            end
        end
    end
    return SeedStock
end

local function GetEggStock()
    print("[AutoFarm] Fetching egg stock from Egg Shop UI...")
    local shop = PlayerGui:FindFirstChild("Egg_Shop")
    if not shop then print("[AutoFarm] Egg_Shop UI not found."); return {} end
    local items = shop:FindFirstChildWhichIsA("Frame", true)
    if not items then print("[AutoFarm] Egg_Shop items frame not found."); return {} end
    for _, item in ipairs(items:GetChildren()) do
        local mf = item:FindFirstChild("Main_Frame")
        if mf then
            local st = mf:FindFirstChild("Stock_Text")
            if st then
                local count = tonumber(st.Text:match("%d+"))
                EggStock[item.Name] = count or 0
                print(string.format("[AutoFarm] Egg: %s | Stock: %d", item.Name, count or 0))
            end
        end
    end
    return EggStock
end

local function BuySeed(seed)
    print("[AutoFarm] Attempting to buy seed:", seed)
    ReplicatedStorage.GameEvents.BuySeedStock:FireServer(seed)
end

local function BuyEgg(egg)
    print("[AutoFarm] Attempting to buy egg:", egg)
    local evt = ReplicatedStorage.GameEvents:FindFirstChild("BuyEggStock")
    if evt then evt:FireServer(egg) end
end

local function BuyAllSelectedSeeds()
    print("[AutoFarm] Buying all selected seeds...")
    for _, seed in ipairs(SelectedSeedsToBuy) do
        local stock = SeedStock[seed]
        print(string.format("[AutoFarm] Selected seed: %s | Stock: %s", seed, tostring(stock)))
        if stock and stock > 0 then
            for i = 1, stock do
                print(string.format("[AutoFarm] Buying %s (%d/%d)", seed, i, stock))
                BuySeed(seed)
            end
        else
            print(string.format("[AutoFarm] No stock for seed: %s", seed))
        end
    end
end

local function BuyAllSelectedEggs()
    print("[AutoFarm] Buying all selected eggs...")
    for _, egg in ipairs(SelectedEggsToBuy) do
        local stock = EggStock[egg]
        print(string.format("[AutoFarm] Selected egg: %s | Stock: %s", egg, tostring(stock)))
        if stock and stock > 0 then
            for i = 1, stock do
                print(string.format("[AutoFarm] Buying %s (%d/%d)", egg, i, stock))
                BuyEgg(egg)
            end
        else
            print(string.format("[AutoFarm] No stock for egg: %s", egg))
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
print("[AutoFarm] Creating UI tabs and dropdowns...")
local BuyTab = Window:CreateTab("Seed Shop", 4483362458)
local EggTab = Window:CreateTab("Egg Shop", 4483362458)

SeedDropdown = BuyTab:CreateDropdown({
    Name = "Seeds",
    Options = {},
    MultiSelect = true,
    CurrentOption = {},
    Callback = function(selected)
        print("[AutoFarm] Seeds selected:", table.concat(selected, ", "))
        SelectedSeedsToBuy = selected
    end
})
BuyTab:CreateButton({
    Name = "Buy all selected seeds",
    Callback = BuyAllSelectedSeeds
})
AutoBuy = BuyTab:CreateToggle({
    Name = "Auto-Buy",
    CurrentValue = false,
    Callback = function(val)
        print("[AutoFarm] Auto-Buy toggled:", val)
        AutoBuy = val
    end
})

EggDropdown = EggTab:CreateDropdown({
    Name = "Eggs",
    Options = {},
    MultiSelect = true,
    CurrentOption = {},
    Callback = function(selected)
        print("[AutoFarm] Eggs selected:", table.concat(selected, ", "))
        SelectedEggsToBuy = selected
    end
})
EggTab:CreateButton({
    Name = "Buy all selected eggs",
    Callback = BuyAllSelectedEggs
})
AutoBuyEggs = EggTab:CreateToggle({
    Name = "Auto-Buy Eggs",
    CurrentValue = false,
    Callback = function(val)
        print("[AutoFarm] Auto-Buy Eggs toggled:", val)
        AutoBuyEggs = val
    end
})

--// Dropdown Refresh Helpers
local function RefreshSeedDropdown()
    print("[AutoFarm] Refreshing seed dropdown options...")
    if SeedDropdown and SeedDropdown.Destroy then SeedDropdown:Destroy() end
    SeedDropdown = BuyTab:CreateDropdown({
        Name = "Seeds",
        Options = GetSortedKeys(SeedStock),
        MultiSelect = true,
        CurrentOption = SelectedSeedsToBuy,
        Callback = function(selected)
            print("[AutoFarm] Seeds selected:", table.concat(selected, ", "))
            SelectedSeedsToBuy = selected
        end
    })
end

local function RefreshEggDropdown()
    print("[AutoFarm] Refreshing egg dropdown options...")
    if EggDropdown and EggDropdown.Destroy then EggDropdown:Destroy() end
    EggDropdown = EggTab:CreateDropdown({
        Name = "Eggs",
        Options = GetSortedKeys(EggStock),
        MultiSelect = true,
        CurrentOption = SelectedEggsToBuy,
        Callback = function(selected)
            print("[AutoFarm] Eggs selected:", table.concat(selected, ", "))
            SelectedEggsToBuy = selected
        end
    })
end

--// Main Loop
task.spawn(function()
    print("[AutoFarm] Main loop started.")
    local function mainStep()
        print("[AutoFarm] --- Loop Start ---")
        GetSeedStock()
        GetEggStock()
        RefreshSeedDropdown()
        RefreshEggDropdown()
        if AutoBuy then
            print("[AutoFarm] Auto-Buy is enabled.")
            BuyAllSelectedSeeds()
        end
        if AutoBuyEggs then
            print("[AutoFarm] Auto-Buy Eggs is enabled.")
            BuyAllSelectedEggs()
        end
        print("[AutoFarm] --- Loop End ---")
    end

    if RunInLoop then
        while task.wait(1) do
            mainStep()
        end
    else
        mainStep()
    end
end)
