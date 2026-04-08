-- ═══════════════════════════════════════════════════════════════════════════
--  Framework Adapter: ESX
--
--  Compatible with ESX Legacy (esx_core / es_extended).
--  Lazy-initialises ESX via the shared object export so that this file can
--  be loaded without ESX being started yet.
-- ═══════════════════════════════════════════════════════════════════════════

local ESX = nil

local function getESX()
    if not ESX then
        if GetResourceState('es_extended') == 'started' then
            ESX = exports['es_extended']:getSharedObject()
        end
    end
    return ESX
end

RegisterBridgeAdapter('esx', {
    GetIdentifier = function(source)
        local esx = getESX()
        if not esx then return nil end
        local xPlayer = esx.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    end,

    GetCharacterId = function(source)
        -- ESX (single character) does not expose a separate char id.
        -- Return nil; multi-char extensions can override this.
        return nil
    end,

    GetPlayerName = function(source)
        local esx = getESX()
        if esx then
            local xPlayer = esx.GetPlayerFromId(source)
            if xPlayer then
                return xPlayer.getName()
            end
        end
        return GetPlayerName(tonumber(source)) or ('Player %d'):format(source)
    end,

    Notify = function(source, msg, notifType)
        if not Config.Notifications.Enable then return end
        local esx = getESX()
        if esx then
            local xPlayer = esx.GetPlayerFromId(source)
            if xPlayer then
                xPlayer.showNotification(msg)
                return
            end
        end
        -- Fallback to chat message
        TriggerClientEvent('chat:addMessage', source, { args = { '[儲值]', msg } })
    end,

    IsPlayerLoaded = function(source)
        local esx = getESX()
        if not esx then return false end
        return esx.GetPlayerFromId(source) ~= nil
    end,
})
