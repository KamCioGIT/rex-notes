local RSGCore = exports['rsg-core']:GetCoreObject()
local SpawnedProps = {}
local isBusy = false
local fx_group = "scr_dm_ftb"
local fx_name = "scr_mp_chest_spawn_smoke"
local fx_scale = 0.3

---------------------------------------------
-- spawn props
---------------------------------------------
Citizen.CreateThread(function()
    while true do
        Wait(150)

        local pos = GetEntityCoords(cache.ped)
        local InRange = false

        for i = 1, #Config.PlayerProps do
            local prop = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
            local dist = #(pos - prop)
            if dist >= 50.0 then goto continue end

            local hasSpawned = false
            InRange = true

            for z = 1, #SpawnedProps do
                local p = SpawnedProps[z]

                if p.id == Config.PlayerProps[i].id then
                    hasSpawned = true
                end
            end

            if hasSpawned then goto continue end

            local modelHash = Config.PlayerProps[i].hash
            local data = {}
            
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Wait(1)
                end
            end
            
            data.id = Config.PlayerProps[i].id
            data.obj = CreateObject(modelHash, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z -1.2, false, false, false)
            SetEntityHeading(data.obj, Config.PlayerProps[i].h)
            SetEntityAsMissionEntity(data.obj, true)
            PlaceObjectOnGroundProperly(data.obj)
            Wait(1000)
            FreezeEntityPosition(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)

            if Config.EnableVegModifier then
                -- veg modifiy
                local veg_modifier_sphere = 0
                
                if veg_modifier_sphere == nil or veg_modifier_sphere == 0 then
                    local veg_radius = 3.0
                    local veg_Flags =  1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256
                    local veg_ModType = 1
                    
                    veg_modifier_sphere = AddVegModifierSphere(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, veg_radius, veg_ModType, veg_Flags, 0)
                    
                else
                    RemoveVegModifierSphere(Citizen.PointerValueIntInitialized(veg_modifier_sphere), 0)
                    veg_modifier_sphere = 0
                end
            end

            SpawnedProps[#SpawnedProps + 1] = data
            hasSpawned = false

            -- create target for the entity
            exports['rsg-target']:AddTargetEntity(data.obj, {
                options = {
                    {
                        type = 'client',
                        icon = 'far fa-eye',
                        label = 'Open Note',
                        action = function()
                            TriggerEvent('rex-notes:client:opennotes', data.id, data.obj)
                        end
                    },
                },
                distance = 3
            })
            -- end of target

            ::continue::
        end

        if not InRange then
            Wait(5000)
        end
    end
end)

---------------------------------------------
-- open note menu
---------------------------------------------
RegisterNetEvent('rex-notes:client:opennotes', function(noteid, entity)
    lib.registerContext({
        id = 'note_menu',
        title = 'Note Menu',
        options = {
            {
                title = 'Read Note',
                icon = 'fa-solid fa-book',
                event = 'rex-notes:client:readnote',
                args = {
                    noteid = noteid
                },
                arrow = true
            },
            {
                title = 'Copy Note',
                icon = 'fa-solid fa-hand-paper',
                serverEvent = 'rex-notes:server:copynote',
                args = {
                    noteid = noteid
                },
                arrow = true
            },
            {
                title = 'Distroy Note',
                icon = 'fa-solid fa-fire',
                event = 'rex-notes:client:distroynote',
                args = {
                    noteid = noteid,
                    entity = entity,
                }
            },
        }
    })
    lib.showContext('note_menu')
end)

---------------------------------------------
-- create note
---------------------------------------------
RegisterNetEvent('rex-notes:client:setupnote', function(proptype, PropHash, pPos, heading)

    local input = lib.inputDialog('Create Note', {
        { 
            type = 'input',
            label = 'Title',
            required = true
        },
        { 
            type = 'textarea',
            label = 'Note',
            autosize = true,
            required = true
        },
    })
    
    if not input then
        return
    end

    TriggerEvent('rex-notes:client:placeNewProp', proptype, PropHash, pPos, heading, input[1], input[2])

end)

---------------------------------------------
-- read note
---------------------------------------------
RegisterNetEvent('rex-notes:client:readnote', function(data)

    RSGCore.Functions.TriggerCallback('rex-notes:server:getallpropdata', function(result)
        lib.registerContext({
            id = 'read_note',
            title = 'Read Note',
            menu = 'note_menu',
            options = {
                {
                    title = result[1].title,
                    description = result[1].note,
                    readOnly = true
                }
            }
        })
        lib.showContext('read_note')
    end, data.noteid)

end)

---------------------------------------------
-- read copied note
---------------------------------------------
RegisterNetEvent('rex-notes:client:readcopiednote', function(noteid, title, content)
    lib.registerContext({
        id = 'read_copied_note',
        title = 'Saved Note : '..noteid,
        options = {
            {
                title = title or 'Untitled Note',
                description = content or 'No content available.',
                readOnly = true
            }
        }
    })
    lib.showContext('read_copied_note')
end)

---------------------------------------------
-- distroy note
---------------------------------------------
RegisterNetEvent('rex-notes:client:distroynote', function(data)

    if not isBusy then
        isBusy = true
        local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
        FreezeEntityPosition(cache.ped, true)
        TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
        Wait(3000)
        ClearPedTasks(cache.ped)
        local boxcoords = GetEntityCoords(data.entity)
        local fxcoords = vector3(boxcoords.x, boxcoords.y, boxcoords.z)
        UseParticleFxAsset(fx_group)
        smoke = StartParticleFxNonLoopedAtCoord(fx_name, fxcoords, 0.0, 0.0, 0.0, fx_scale, false, false, false, true)

        TriggerServerEvent('rex-notes:server:distroynote', data.noteid)

        FreezeEntityPosition(cache.ped, false)
        isBusy = false
        return
    else
        lib.notify({ title = 'You are busy doing someting!', type = 'error', duration = 7000 })
    end

end)

---------------------------------------------
-- remove prop object
---------------------------------------------
RegisterNetEvent('rex-notes:client:removePropObject')
AddEventHandler('rex-notes:client:removePropObject', function(prop)
    for i = 1, #SpawnedProps do
        local o = SpawnedProps[i]

        if o.id == prop then
            SetEntityAsMissionEntity(o.obj, false)
            FreezeEntityPosition(o.obj, false)
            DeleteObject(o.obj)
        end
    end
end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterNetEvent('rex-notes:client:updatePropData')
AddEventHandler('rex-notes:client:updatePropData', function(data)
    Config.PlayerProps = data
end)

---------------------------------------------
-- place prop
---------------------------------------------
RegisterNetEvent('rex-notes:client:placeNewProp')
AddEventHandler('rex-notes:client:placeNewProp', function(proptype, pHash, pos, heading, title, note)
    RSGCore.Functions.TriggerCallback('rex-notes:server:countprop', function(result)

        if result > Config.MaxNotes then
            lib.notify({ title = 'Max Notes Reached', type = 'error', duration = 7000 })
            return
        end

        if CanPlacePropHere(pos) and not IsPedInAnyVehicle(PlayerPedId(), false) and not isBusy then
            isBusy = true
            local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
            FreezeEntityPosition(cache.ped, true)
            TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
            Wait(3000)
            ClearPedTasks(cache.ped)
            FreezeEntityPosition(cache.ped, false)
            TriggerServerEvent('rex-notes:server:newProp', proptype, pos, heading, pHash, title, note)
            isBusy = false
            return
        else
            lib.notify({ title = 'Can\'t Place Here', type = 'error', duration = 7000 })
        end

    end, proptype)

end)

---------------------------------------------
-- check to see if prop can be place here
---------------------------------------------
function CanPlacePropHere(pos)
    local canPlace = true

    for i = 1, #Config.PlayerProps do
        local checkprops = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
        local dist = #(pos - checkprops)
        if dist < 3 then
            canPlace = false
        end
    end
    return canPlace
end

---------------------------------------------
-- clean up
---------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #SpawnedProps do
        local props = SpawnedProps[i].obj
        SetEntityAsMissionEntity(props, false)
        FreezeEntityPosition(props, false)
        DeleteObject(props)
    end
end)
