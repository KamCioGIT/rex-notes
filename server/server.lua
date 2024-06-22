local RSGCore = exports['rsg-core']:GetCoreObject()
local PropsLoaded = false

---------------------------------------------
-- use notebook
---------------------------------------------
RSGCore.Functions.CreateUseableItem(Config.NoteBookItem, function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    TriggerClientEvent('rex-notes:client:createnote', src, Config.NoteBookItem, Config.NoteProp)
    TriggerEvent('rsg-log:server:CreateLog', 'notes', 'Note Created', 'green', firstname .. ' ' .. lastname .. ' has created a note.')
end)

---------------------------------------------
-- use note
---------------------------------------------
RSGCore.Functions.CreateUseableItem(Config.NoteItem, function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname

    if item.info and item.info.noteid then
        TriggerClientEvent('rex-notes:client:readcopiednote', src, item.info.noteid, item.info.title, item.info.content)
        TriggerEvent('rsg-log:server:CreateLog', 'notes', 'Note Read', 'blue', firstname .. ' ' .. lastname .. ' has read a note: ' .. item.info.title)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Note Empty', description = 'this note is empty!', type = 'inform', duration = 7000 })
    end
end)

---------------------------------------------
-- get all prop data
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-notes:server:getallpropdata', function(source, cb, propid)
    MySQL.query('SELECT * FROM rex_notes WHERE propid = ?', {propid}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

---------------------------------------------
-- count props
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-notes:server:countprop', function(source, cb, proptype)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM rex_notes WHERE citizenid = ? AND proptype = ?", { citizenid, proptype })
    if result then
        cb(result)
    else
        cb(nil)
    end
end)

---------------------------------------------
-- update prop data
---------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            TriggerClientEvent('rex-notes:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

---------------------------------------------
-- get props
---------------------------------------------
CreateThread(function()
    TriggerEvent('rex-notes:server:getProps')
    PropsLoaded = true
end)

---------------------------------------------
-- save props
---------------------------------------------
RegisterServerEvent('rex-notes:server:saveProp')
AddEventHandler('rex-notes:server:saveProp', function(data, propId, citizenid, proptype, title, note)
    local datas = json.encode(data)

    MySQL.Async.execute('INSERT INTO rex_notes (properties, propid, citizenid, proptype, title, note) VALUES (@properties, @propid, @citizenid, @proptype, @title, @note)',
    {
        ['@properties'] = datas,
        ['@propid'] = propId,
        ['@citizenid'] = citizenid,
        ['@proptype'] = proptype,
        ['@title'] = title,
        ['@note'] = note,
    })
end)

---------------------------------------------
-- new prop
---------------------------------------------
RegisterServerEvent('rex-notes:server:newProp')
AddEventHandler('rex-notes:server:newProp', function(proptype, location, heading, hash, title, note)
    local src = source
    local propId = CreateNoteNumber()
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid

    local PropData =
    {
        id = propId,
        proptype = proptype,
        x = location.x,
        y = location.y,
        z = location.z,
        h = heading,
        hash = hash,
        builder = Player.PlayerData.citizenid,
        buildttime = os.time()
    }

    table.insert(Config.PlayerProps, PropData)
    TriggerEvent('rex-notes:server:saveProp', PropData, propId, citizenid, proptype, title, note)
    TriggerEvent('rex-notes:server:updateProps')
end)

---------------------------------------------
-- copy note
---------------------------------------------
RegisterServerEvent('rex-notes:server:copynote')
AddEventHandler('rex-notes:server:copynote', function(data)

    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    -- Fetch the note content from the database
    MySQL.Async.fetchAll('SELECT title, note FROM rex_notes WHERE propid = ?', { data.noteid }, function(result)
        if result and #result > 0 then
            local title = result[1].title
            local content = result[1].note

            -- Add the note item with metadata
            Player.Functions.AddItem('note', 1, false, {
                noteid = data.noteid,
                title = title,
                content = content
            })
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['note'], 'add')
        else
            TriggerClientEvent('ox_lib:notify', src, {title = 'Not Found', description = 'note data not found!', type = 'inform', duration = 7000 })
        end
    end)

end)

---------------------------------------------
-- distory note
---------------------------------------------
RegisterServerEvent('rex-notes:server:distroynote')
AddEventHandler('rex-notes:server:distroynote', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    for k, v in pairs(Config.PlayerProps) do
        if v.id == propid then
            table.remove(Config.PlayerProps, k)
        end
    end

    TriggerClientEvent('rex-notes:client:removePropObject', src, propid)
    TriggerEvent('rex-notes:server:PropRemoved', propid)
    TriggerEvent('rex-notes:server:updateProps')
end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterServerEvent('rex-notes:server:updateProps')
AddEventHandler('rex-notes:server:updateProps', function()
    local src = source
    TriggerClientEvent('rex-notes:client:updatePropData', src, Config.PlayerProps)
end)

---------------------------------------------
-- remove props
---------------------------------------------
RegisterServerEvent('rex-notes:server:PropRemoved')
AddEventHandler('rex-notes:server:PropRemoved', function(propId)
    local result = MySQL.query.await('SELECT * FROM rex_notes')

    if not result then return end

    for i = 1, #result do
        local propData = json.decode(result[i].properties)

        if propData.id == propId then

            MySQL.Async.execute('DELETE FROM rex_notes WHERE id = @id', { ['@id'] = result[i].id })

            for k, v in pairs(Config.PlayerProps) do
                if v.id == propId then
                    table.remove(Config.PlayerProps, k)
                end
            end
        end
    end
end)

---------------------------------------------
-- get props
---------------------------------------------
RegisterServerEvent('rex-notes:server:getProps')
AddEventHandler('rex-notes:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM rex_notes')

    if not result[1] then return end

    for i = 1, #result do
        local propData = json.decode(result[i].properties)
        print('loading '..propData.proptype..' prop with ID: '..propData.id)
        table.insert(Config.PlayerProps, propData)
    end
end)

---------------------------------------------
-- create note unique number
--------------------------------------------
function CreateNoteNumber()
    local UniqueFound = false
    local NoteNumber = nil
    while not UniqueFound do
        NoteNumber = math.random(11111111, 99999999)
        local query = "%" .. NoteNumber .. "%"
        local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM rex_notes WHERE propid LIKE ?", { query })
        if result == 0 then
            UniqueFound = true
        end
    end
    return NoteNumber
end
