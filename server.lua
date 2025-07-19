local RSGCore = exports['rsg-core']:GetCoreObject()

-- Server Events
RegisterNetEvent('rsg-tobacco:server:craftItem', function(recipe)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Verify player has all required ingredients
    local hasAll = true
    for _, ingredient in ipairs(recipe.ingredients) do
        local hasItem = Player.Functions.GetItemByName(ingredient.item)
        if not hasItem or hasItem.amount < ingredient.amount then
            hasAll = false
            break
        end
    end
    
    if not hasAll then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Missing Ingredients',
            description = 'You don\'t have the required ingredients!',
            type = 'error'
        })
        return
    end
    
    -- Remove ingredients
    for _, ingredient in ipairs(recipe.ingredients) do
        Player.Functions.RemoveItem(ingredient.item, ingredient.amount)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[ingredient.item], "remove", ingredient.amount)
    end
    
    -- Add crafted item
    Player.Functions.AddItem(recipe.output.item, recipe.output.amount)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[recipe.output.item], "add", recipe.output.amount)
    
    -- Add experience (if you have a skill system)
    -- TriggerEvent('rsg-skills:server:addExperience', src, 'crafting', recipe.experience)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Crafting Complete',
        description = 'Successfully crafted ' .. recipe.label .. '!',
        type = 'success'
    })
end)

RegisterNetEvent('rsg-tobacco:server:returnStation', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Return the tobacco station item to inventory
    Player.Functions.AddItem('tobacco_station', 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['tobacco_station'], "add", 1)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Station Retrieved',
        description = 'Tobacco station returned to inventory',
        type = 'success'
    })
end)

-- Usable item for tobacco station
RSGCore.Functions.CreateUseableItem('tobacco_station', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Remove the item from inventory when placing
    Player.Functions.RemoveItem('tobacco_station', 1)
    TriggerClientEvent('inventory:client:ItemBox', source, RSGCore.Shared.Items['tobacco_station'], "remove", 1)
    
    -- Trigger client to show station placement menu
    TriggerClientEvent('rsg-tobacco:client:openStationMenu', source)
end)