-- ═══════════════════════════════════════════════════════════════════════════
--  Reward Dispatcher
--
--  Receives a player source (or identifier) + a reward definition table
--  and executes the appropriate action per reward type.
--
--  Adding a new reward type:
--    1. Register a handler below via RewardDispatcher.Register(type, fn)
--    2. Done – no other files need to change.
-- ═══════════════════════════════════════════════════════════════════════════

RewardDispatcher = {}

local _handlers = {}

---Register a reward handler for a given type.
---@param rewardType string
---@param handler    fun(source: number, identifier: string, reward: table): boolean, string
function RewardDispatcher.Register(rewardType, handler)
    _handlers[rewardType] = handler
end

---Dispatch a list of rewards to a player.
---@param source     number     Player server id (0 = offline / server-side only)
---@param identifier string     Player identifier
---@param rewards    table[]    List of reward definition tables from Config.RewardGroups
---@return boolean allSuccess, string[] errors
function RewardDispatcher.Dispatch(source, identifier, rewards)
    local errors = {}
    local allOk  = true

    for _, reward in ipairs(rewards) do
        local rType   = reward.type
        local handler = _handlers[rType]

        if not handler then
            local msg = ('No handler registered for reward type "%s"'):format(rType)
            table.insert(errors, msg)
            print(('[sp-recharge][RewardDispatcher] WARNING: %s'):format(msg))
            allOk = false
        else
            local ok, err = handler(source, identifier, reward)
            if not ok then
                table.insert(errors, ('%s: %s'):format(rType, err or 'unknown error'))
                allOk = false
            end
        end
    end

    return allOk, errors
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Built-in Handlers
-- ─────────────────────────────────────────────────────────────────────────────

-- ── points ───────────────────────────────────────────────────────────────────
RewardDispatcher.Register('points', function(source, identifier, reward)
    local amount = tonumber(reward.amount)
    if not amount or amount <= 0 then
        return false, 'invalid amount'
    end
    -- Delegate to Points module (loaded after this file, so call via global)
    local ok, err = Points.Add(identifier, amount, '累儲獎勵', { via = 'reward_dispatcher' })
    if ok then
        if source and source > 0 then
            Bridge.Notify(source, ('已獲得 %d 點數（累儲獎勵）'):format(amount), 'success')
        end
    end
    return ok, err
end)

-- ── item ─────────────────────────────────────────────────────────────────────
RewardDispatcher.Register('item', function(source, identifier, reward)
    local itemName = reward.item
    local amount   = tonumber(reward.amount) or 1

    if not itemName then return false, 'missing item name' end
    if not source or source <= 0 then
        return false, 'player must be online to receive items'
    end

    -- ESX
    if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, amount)
            Bridge.Notify(source, ('已獲得 %dx %s（累儲獎勵）'):format(amount, itemName), 'success')
            return true
        end
        return false, 'ESX player not found'
    end

    -- QB-Core / Qbox
    if (Config.Framework == 'qbcore' or Config.Framework == 'qbox') then
        local resourceName = Config.Framework == 'qbox' and 'qbx_core' or 'qb-core'
        if GetResourceState(resourceName) == 'started' then
            local core   = exports[resourceName]
            local player = (Config.Framework == 'qbox') and core:GetPlayer(source) or core:GetCoreObject().Functions.GetPlayer(source)
            if player then
                player.Functions.AddItem(itemName, amount)
                Bridge.Notify(source, ('已獲得 %dx %s（累儲獎勵）'):format(amount, itemName), 'success')
                return true
            end
            return false, 'QB player not found'
        end
    end

    -- TODO: add ox_inventory or other inventory system support here
    print(('[sp-recharge][RewardDispatcher] item handler: no inventory bridge for framework "%s"'):format(Config.Framework))
    return false, 'inventory bridge not configured'
end)

-- ── money (cash in hand) ─────────────────────────────────────────────────────
RewardDispatcher.Register('money', function(source, identifier, reward)
    local amount = tonumber(reward.amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end
    if not source or source <= 0 then return false, 'player must be online' end

    if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addMoney(amount)
            Bridge.Notify(source, ('已獲得 $%d 現金（累儲獎勵）'):format(amount), 'success')
            return true
        end
        return false, 'ESX player not found'
    end

    if Config.Framework == 'qbcore' and GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
        if player then
            player.Functions.AddMoney('cash', amount)
            Bridge.Notify(source, ('已獲得 $%d 現金（累儲獎勵）'):format(amount), 'success')
            return true
        end
        return false, 'QB player not found'
    end

    if Config.Framework == 'qbox' and GetResourceState('qbx_core') == 'started' then
        local player = exports['qbx_core']:GetPlayer(source)
        if player then
            player.Functions.AddMoney('cash', amount)
            Bridge.Notify(source, ('已獲得 $%d 現金（累儲獎勵）'):format(amount), 'success')
            return true
        end
        return false, 'Qbox player not found'
    end

    return false, 'money handler: framework not supported'
end)

-- ── bank ─────────────────────────────────────────────────────────────────────
RewardDispatcher.Register('bank', function(source, identifier, reward)
    local amount = tonumber(reward.amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end
    if not source or source <= 0 then return false, 'player must be online' end

    if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addAccountMoney('bank', amount)
            Bridge.Notify(source, ('已入帳 $%d 至銀行（累儲獎勵）'):format(amount), 'success')
            return true
        end
        return false, 'ESX player not found'
    end

    if Config.Framework == 'qbcore' and GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
        if player then
            player.Functions.AddMoney('bank', amount)
            Bridge.Notify(source, ('已入帳 $%d 至銀行（累儲獎勵）'):format(amount), 'success')
            return true
        end
        return false, 'QB player not found'
    end

    if Config.Framework == 'qbox' and GetResourceState('qbx_core') == 'started' then
        local player = exports['qbx_core']:GetPlayer(source)
        if player then
            player.Functions.AddMoney('bank', amount)
            Bridge.Notify(source, ('已入帳 $%d 至銀行（累儲獎勵）'):format(amount), 'success')
            return true
        end
        return false, 'Qbox player not found'
    end

    return false, 'bank handler: framework not supported'
end)

-- ── vehicle (stub) ───────────────────────────────────────────────────────────
RewardDispatcher.Register('vehicle', function(source, identifier, reward)
    -- TODO: integrate with a vehicle ownership resource (e.g. qb-vehiclekeys, ox_lib vehicle)
    print(('[sp-recharge][RewardDispatcher] STUB vehicle reward for %s: model=%s'):format(
        identifier, tostring(reward.model)
    ))
    if source and source > 0 then
        Bridge.Notify(source, '載具獎勵已記錄，請聯繫管理員領取。', 'info')
    end
    return true  -- non-fatal stub
end)

-- ── vip_days (stub) ──────────────────────────────────────────────────────────
RewardDispatcher.Register('vip_days', function(source, identifier, reward)
    -- TODO: integrate with your VIP resource
    local days = tonumber(reward.days) or 0
    print(('[sp-recharge][RewardDispatcher] STUB vip_days reward for %s: days=%d'):format(
        identifier, days
    ))
    if source and source > 0 then
        Bridge.Notify(source, ('VIP %d 天獎勵已記錄，請稍候系統更新。'):format(days), 'info')
    end
    return true  -- non-fatal stub
end)
