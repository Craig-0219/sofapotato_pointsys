-- ═══════════════════════════════════════════════════════════════════════════
--  Framework Adapter: Qbox  (qbx_core)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterBridgeAdapter('qbox', {
    GetIdentifier = function(source)
        if GetResourceState('qbx_core') ~= 'started' then return nil end
        local player = exports['qbx_core']:GetPlayer(source)
        return player and player.PlayerData.license or nil
    end,

    GetCharacterId = function(source)
        if GetResourceState('qbx_core') ~= 'started' then return nil end
        local player = exports['qbx_core']:GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end,

    GetPlayerName = function(source)
        if GetResourceState('qbx_core') == 'started' then
            local player = exports['qbx_core']:GetPlayer(source)
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
        if GetResourceState('qbx_core') == 'started' then
            exports['qbx_core']:Notify(source, msg,
                notifType == 'error'   and 'error'
                or notifType == 'success' and 'success'
                or 'inform')
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '[儲值]', msg } })
        end
    end,

    IsPlayerLoaded = function(source)
        if GetResourceState('qbx_core') ~= 'started' then return false end
        return exports['qbx_core']:GetPlayer(source) ~= nil
    end,
})
