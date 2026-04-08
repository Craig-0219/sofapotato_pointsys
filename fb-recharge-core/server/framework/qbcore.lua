-- ═══════════════════════════════════════════════════════════════════════════
--  Framework Adapter: QB-Core
-- ═══════════════════════════════════════════════════════════════════════════

local QBCore = nil

local function getQB()
    if not QBCore then
        if GetResourceState('qb-core') == 'started' then
            QBCore = exports['qb-core']:GetCoreObject()
        end
    end
    return QBCore
end

RegisterBridgeAdapter('qbcore', {
    GetIdentifier = function(source)
        local QB = getQB()
        if not QB then return nil end
        local player = QB.Functions.GetPlayer(source)
        return player and player.PlayerData.license or nil
    end,

    GetCharacterId = function(source)
        local QB = getQB()
        if not QB then return nil end
        local player = QB.Functions.GetPlayer(source)
        -- citizenid is the unique character identifier in QB
        return player and player.PlayerData.citizenid or nil
    end,

    GetPlayerName = function(source)
        local QB = getQB()
        if QB then
            local player = QB.Functions.GetPlayer(source)
            if player then
                local info = player.PlayerData.charinfo
                if info then
                    return ('%s %s'):format(info.firstname or '', info.lastname or ''):match('^%s*(.-)%s*$')
                end
            end
        end
        return GetPlayerName(tonumber(source)) or ('Player %d'):format(source)
    end,

    Notify = function(source, msg, notifType)
        if not Config.Notifications.Enable then return end
        local QB = getQB()
        if QB then
            QB.Functions.Notify(source, msg,
                notifType == 'error'   and 'error'
                or notifType == 'success' and 'success'
                or 'primary')
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '[儲值]', msg } })
        end
    end,

    IsPlayerLoaded = function(source)
        local QB = getQB()
        if not QB then return false end
        return QB.Functions.GetPlayer(source) ~= nil
    end,
})
