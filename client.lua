local RSGCore = exports['rsg-core']:GetCoreObject()

local CHECK_RADIUS = 2.0
local TOBACCO_MAKER_PROPS = {
    {
        label = "Portable tobacco Kit",
        model = `p_tablevoodoo01x`, -- Using toolbox as portable kit
        offset = vector3(0.0, -0.1, 0.0)
    }
}

-- Tobacco recipes configuration
local TOBACCO_RECIPES = {
    cigarettes = {
        {
            name = "cigarette",
            label = "Cheap Cigarette",
            description = "Basic tobacco cigarette",
            ingredients = {
                {item = "tobacco", amount = 10}
                
            },
            craftTime = 3000,
            output = {item = "cigarette10", amount = 1},
            experience = 5
        }
        
    },
    cigars = {
        {
            name = "cigar_basic",
            label = "Basic Cigar",
            description = "Simple hand-rolled cigar",
            ingredients = {
                {item = "tobacco", amount = 5}
                
            },
            craftTime = 8000,
            output = {item = "cigar", amount = 1},
            experience = 15
        },
		{
            name = "indian cigar",
            label = "Indian Cigar",
            description = "Simple  cigar",
            ingredients = {
                {item = "indtobacco", amount = 5}
                
            },
            craftTime = 8000,
            output = {item = "indiancigar", amount = 1},
            experience = 15
        }
        
    }
}

-- Variables
local deployedStation = nil
local deployedOwner = nil
local isUsingStation = false
local currentStationData = nil
local currentRecipeCategory = nil

-- Utility Functions
local function HasRequiredItems(recipe)
    local hasAll = true
    local missingItems = {}
    
    for _, ingredient in ipairs(recipe.ingredients) do
        local hasItem = RSGCore.Functions.HasItem(ingredient.item, ingredient.amount)
        if not hasItem then
            hasAll = false
            table.insert(missingItems, {
                item = ingredient.item,
                amount = ingredient.amount
            })
        end
    end
    
    return hasAll, missingItems
end

local function GetItemLabel(itemName)
    local item = RSGCore.Shared.Items[itemName]
    return item and item.label or itemName
end

-- Menu Functions
local function ShowStationMenu()
    local stationOptions = {}
    
    for i, station in ipairs(TOBACCO_MAKER_PROPS) do
        table.insert(stationOptions, {
            title = station.label,
            description = "Deploy a " .. station.label,
            icon = 'fas fa-smoking',
            onSelect = function()
                TriggerEvent('rsg-tobacco:client:placeStation', i)
            end
        })
    end

    lib.registerContext({
        id = 'tobacco_station_menu',
        title = 'Select Tobacco Station',
        options = stationOptions
    })
    
    lib.showContext('tobacco_station_menu')
end

local function ShowCraftingMenu()
    if not deployedStation then return end
    
    local craftingOptions = {
        {
            title = "Cigarettes",
            description = "Craft various types of cigarettes",
            icon = 'fas fa-smoking',
            onSelect = function()
                currentRecipeCategory = 'cigarettes'
                TriggerEvent('rsg-tobacco:client:showRecipeMenu')
            end
        },
        {
            title = "Cigars",
            description = "Craft premium cigars",
            icon = 'fas fa-fire',
            onSelect = function()
                currentRecipeCategory = 'cigars'
                TriggerEvent('rsg-tobacco:client:showRecipeMenu')
            end
        }
    }

    lib.registerContext({
        id = 'tobacco_crafting_menu',
        title = 'Tobacco Crafting Station',
        options = craftingOptions
    })
    
    lib.showContext('tobacco_crafting_menu')
end

local function ShowRecipeMenu()
    if not currentRecipeCategory or not TOBACCO_RECIPES[currentRecipeCategory] then return end
    
    local recipeOptions = {}
    
    for _, recipe in ipairs(TOBACCO_RECIPES[currentRecipeCategory]) do
        local hasItems, missingItems = HasRequiredItems(recipe)
        local ingredientsList = ""
        local statusIcon = hasItems and "✅" or "❌"
        
        for i, ingredient in ipairs(recipe.ingredients) do
            if i > 1 then ingredientsList = ingredientsList .. ", " end
            ingredientsList = ingredientsList .. ingredient.amount .. "x " .. GetItemLabel(ingredient.item)
        end
        
        table.insert(recipeOptions, {
            title = statusIcon .. " " .. recipe.label,
            description = "Requires: " .. ingredientsList,
            icon = hasItems and 'fas fa-check' or 'fas fa-times',
            disabled = not hasItems,
            onSelect = function()
                if hasItems then
                    TriggerEvent('rsg-tobacco:client:craftItem', recipe)
                end
            end
        })
    end
    
    -- Add back button
    table.insert(recipeOptions, {
        title = "⬅️ Back",
        description = "Return to main crafting menu",
        icon = 'fas fa-arrow-left',
        onSelect = function()
            TriggerEvent('rsg-tobacco:client:showCraftingMenu')
        end
    })

    lib.registerContext({
        id = 'tobacco_recipe_menu',
        title = 'Craft ' .. (currentRecipeCategory == 'cigarettes' and 'Cigarettes' or 'Cigars'),
        options = recipeOptions
    })
    
    lib.showContext('tobacco_recipe_menu')
end

-- Targeting Functions
local function RegisterStationTargeting()
    local models = {}
    for _, station in ipairs(TOBACCO_MAKER_PROPS) do
        table.insert(models, station.model)
    end

    exports['ox_target']:addModel(models, {
        {
            name = 'use_tobacco_station',
            event = 'rsg-tobacco:client:showCraftingMenu',
            icon = "fas fa-smoking",
            label = "Use Tobacco Station",
            distance = 2.0,
            canInteract = function(entity)
                return not isUsingStation and deployedStation == entity
            end
        },
        {
            name = 'pickup_tobacco_station',
            event = 'rsg-tobacco:client:pickupStation',
            icon = "fas fa-hand",
            label = "Pick Up Station",
            distance = 2.0,
            canInteract = function(entity)
                return not isUsingStation and deployedStation == entity
            end
        }
    })
end

-- Event Handlers
RegisterNetEvent('rsg-tobacco:client:placeStation', function(stationIndex)
    if deployedStation then
        lib.notify({
            title = "Station Already Placed",
            description = "You already have a tobacco station placed.",
            type = 'error'
        })
        return
    end

    local stationData = TOBACCO_MAKER_PROPS[stationIndex]
    if not stationData then return end

    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local forward = GetEntityForwardVector(PlayerPedId())
    
    local offsetDistance = 1.5
    local x = coords.x + forward.x * offsetDistance
    local y = coords.y + forward.y * offsetDistance
    local z = coords.z

    RequestModel(stationData.model)
    while not HasModelLoaded(stationData.model) do
        Wait(100)
    end

    -- Setup animation
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    
    lib.notify({
        title = "Setting Up Station",
        description = "Setting up your tobacco crafting station...",
        type = 'info'
    })
    
    Wait(3000)

    local stationObject = CreateObject(stationData.model, x, y, z, true, false, false)
    PlaceObjectOnGroundProperly(stationObject)
    SetEntityHeading(stationObject, heading)
    FreezeEntityPosition(stationObject, true)
    
    deployedStation = stationObject
    currentStationData = stationData
    deployedOwner = GetPlayerServerId(PlayerId())
    
    Wait(500)
    ClearPedTasks(PlayerPedId())
    
    lib.notify({
        title = "Station Ready",
        description = "Your tobacco station is ready for use!",
        type = 'success'
    })
end)

RegisterNetEvent('rsg-tobacco:client:pickupStation', function()
    if not deployedStation then
        lib.notify({
            title = "No Station!",
            description = "There's no station to pick up.",
            type = 'error'
        })
        return
    end

    if isUsingStation then
        lib.notify({
            title = "Station In Use",
            description = "You can't pick up the station while it's being used.",
            type = 'error'
        })
        return
    end

    local ped = PlayerPedId()
    
    LocalPlayer.state:set('inv_busy', true, true)
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    
    lib.notify({
        title = "Packing Up",
        description = "Packing up your tobacco station...",
        type = 'info'
    })
    
    Wait(3000)

    if deployedStation then
        DeleteObject(deployedStation)
        deployedStation = nil
        currentStationData = nil
        TriggerServerEvent('rsg-tobacco:server:returnStation')
        deployedOwner = nil
    end

    ClearPedTasks(ped)
    LocalPlayer.state:set('inv_busy', false, true)

    lib.notify({
        title = 'Station Packed',
        description = 'You have retrieved your tobacco station.',
        type = 'success'
    })
end)

RegisterNetEvent('rsg-tobacco:client:showCraftingMenu', function()
    ShowCraftingMenu()
end)

RegisterNetEvent('rsg-tobacco:client:showRecipeMenu', function()
    ShowRecipeMenu()
end)

RegisterNetEvent('rsg-tobacco:client:craftItem', function(recipe)
    if isUsingStation then
        lib.notify({
            title = "Station Busy",
            description = "The tobacco station is already being used.",
            type = 'error'
        })
        return
    end

    local hasItems, missingItems = HasRequiredItems(recipe)
    if not hasItems then
        local missingText = ""
        for i, missing in ipairs(missingItems) do
            if i > 1 then missingText = missingText .. ", " end
            missingText = missingText .. missing.amount .. "x " .. GetItemLabel(missing.item)
        end
        
        lib.notify({
            title = "Missing Ingredients",
            description = "You need: " .. missingText,
            type = 'error'
        })
        return
    end

    isUsingStation = true
    LocalPlayer.state:set('inv_busy', true, true)

    -- Start crafting animation
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_STAND_MOBILE'), -1, true, false, false, false)
    
    -- Progress bar for crafting
    local success = lib.progressBar({
        duration = recipe.craftTime,
        label = 'Crafting ' .. recipe.label .. '...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    })

    if success then
        TriggerServerEvent('rsg-tobacco:server:craftItem', recipe)
        lib.notify({
            title = "Crafting Complete",
            description = "You successfully crafted " .. recipe.label .. "!",
            type = 'success'
        })
    else
        lib.notify({
            title = "Crafting Cancelled",
            description = "You stopped crafting.",
            type = 'error'
        })
    end

    ClearPedTasks(PlayerPedId())
    LocalPlayer.state:set('inv_busy', false, true)
    isUsingStation = false
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if deployedStation then
        DeleteObject(deployedStation)
    end
end)

-- Initialize targeting
CreateThread(function()
    RegisterStationTargeting()
end)

-- Command to open tobacco station menu
RegisterNetEvent('rsg-tobacco:client:openStationMenu', function()
    ShowStationMenu()
end)