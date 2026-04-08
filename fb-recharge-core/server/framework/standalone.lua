-- ═══════════════════════════════════════════════════════════════════════════
--  Framework Adapter: Standalone / Generic
--
--  Uses only native FiveM built-ins.
--  Identifier priority: license2 → license → steam → net:<id>
-- ═══════════════════════════════════════════════════════════════════════════

local function resolveIdentifier(source)
    local src = tonumber(source)
    if not src then return nil end

    local priority = { 'license2', 'license', 'steam', 'discord', 'xbl', 'live' }
    for _, idType in ipairs(priority) do
        local id = GetPlayerIdentifierByType(src, idType)
        if id and id ~= '' then return id end
    end

    -- Fallback: net ID string
    return ('net:%d'):format(src)
end

RegisterBridgeAdapter('standalone', {
    ---Returns the primary identifier string for a connected player.
    ---@param source number
    ---@return string|nil
    GetIdentifier = function(source)
        return resolveIdentifier(source)
    end,

    ---Returns an internal character/player DB id.
    ---Standalone has no character concept; returns nil.
    ---@param source number
    ---@return number|nil
    GetCharacterId = function(source)
        return nil
    end,

    ---Returns the player's display name.
    ---@param source number
    ---@return string
    GetPlayerName = function(source)
        return GetPlayerName(tonumber(source)) or ('Player %d'):format(source)
    end,

    ---Send a notification to the player via chat or a generic event.
    ---@param source   number
    ---@param msg      string
    ---@param notifType string  'success'|'error'|'info'
    Notify = function(source, msg, notifType)
        if not Config.Notifications.Enable then return end
        -- Generic: push a chat message.  Replace with your UI export if needed.
        TriggerClientEvent('chat:addMessage', source, {
            color  = notifType == 'error' and { 255, 80, 80 }
                  or notifType == 'success' and { 80, 200, 80 }
                  or { 80, 180, 255 },
            multiline = false,
            args      = { '[儲值系統]', msg },
        })
    end,

    ---Returns true if the player is fully connected and has a valid identifier.
    ---@param source number
    ---@return boolean
    IsPlayerLoaded = function(source)
        return resolveIdentifier(source) ~= nil
    end,
})
