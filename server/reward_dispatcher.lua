-- ═══════════════════════════════════════════════════════════════════════════
--  Reward Dispatcher  (v2)
--
--  目前獎勵點數統一回到 points。
--  新增 reward type 只需呼叫 RewardDispatcher.Register(type, fn)。
-- ═══════════════════════════════════════════════════════════════════════════

RewardDispatcher = {}

local _handlers = {}

function RewardDispatcher.Register(rewardType, handler)
    _handlers[rewardType] = handler
end

function RewardDispatcher.Dispatch(source, identifier, rewards)
    local errors = {}
    local allOk  = true

    for _, reward in ipairs(rewards) do
        local handler = _handlers[reward.type]
        if not handler then
            local msg = ('No handler for reward type "%s"'):format(reward.type)
            table.insert(errors, msg)
            print(('[sp-recharge][RewardDispatcher] WARNING: %s'):format(msg))
            allOk = false
        else
            local ok, err = handler(source, identifier, reward)
            if not ok then
                table.insert(errors, ('%s: %s'):format(reward.type, err or 'unknown'))
                allOk = false
            end
        end
    end

    return allOk, errors
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Built-in handlers
-- ─────────────────────────────────────────────────────────────────────────────

local function grantRewardPoints(source, identifier, reward)
    local amount = tonumber(reward.amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end

    local ok, err = Points.Add(identifier, amount, '里程碑獎勵', { via = 'reward_dispatcher' })
    if ok and source and source > 0 then
        Bridge.Notify(source, ('已獲得 %d 點數（里程碑獎勵）'):format(amount), 'success')
    end
    return ok, err
end

-- ── vouchers（舊設定相容，實際發點數）────────────────────────────────────────
RewardDispatcher.Register('vouchers', grantRewardPoints)

-- ── points ───────────────────────────────────────────────────────────────────
RewardDispatcher.Register('points', grantRewardPoints)

-- ── item ─────────────────────────────────────────────────────────────────────
RewardDispatcher.Register('item', function(source, identifier, reward)
    local itemName = reward.item
    local amount   = tonumber(reward.amount) or 1

    if not itemName then return false, 'missing item name' end
    if not source or source <= 0 then return false, 'player must be online' end

    if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local xPlayer = exports['es_extended']:getSharedObject().GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, amount)
            Bridge.Notify(source, ('已獲得 %dx %s'):format(amount, itemName), 'success')
            return true
        end
        return false, 'ESX player not found'
    end

    if Config.Framework == 'qbcore' and GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
        if player then
            player.Functions.AddItem(itemName, amount)
            Bridge.Notify(source, ('已獲得 %dx %s'):format(amount, itemName), 'success')
            return true
        end
        return false, 'QB player not found'
    end

    if Config.Framework == 'qbox' and GetResourceState('qbx_core') == 'started' then
        local player = exports['qbx_core']:GetPlayer(source)
        if player then
            player.Functions.AddItem(itemName, amount)
            Bridge.Notify(source, ('已獲得 %dx %s'):format(amount, itemName), 'success')
            return true
        end
        return false, 'Qbox player not found'
    end

    print(('[sp-recharge][RewardDispatcher] item: no inventory bridge for "%s"'):format(Config.Framework))
    return false, 'inventory bridge not configured'
end)

-- ── money ────────────────────────────────────────────────────────────────────
RewardDispatcher.Register('money', function(source, identifier, reward)
    local amount = tonumber(reward.amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end
    if not source or source <= 0 then return false, 'player must be online' end

    if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local xPlayer = exports['es_extended']:getSharedObject().GetPlayerFromId(source)
        if xPlayer then xPlayer.addMoney(amount); Bridge.Notify(source, ('已獲得 $%d 現金'):format(amount), 'success'); return true end
        return false, 'ESX player not found'
    end
    if Config.Framework == 'qbcore' and GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
        if player then player.Functions.AddMoney('cash', amount); Bridge.Notify(source, ('已獲得 $%d 現金'):format(amount), 'success'); return true end
        return false, 'QB player not found'
    end
    if Config.Framework == 'qbox' and GetResourceState('qbx_core') == 'started' then
        local player = exports['qbx_core']:GetPlayer(source)
        if player then player.Functions.AddMoney('cash', amount); Bridge.Notify(source, ('已獲得 $%d 現金'):format(amount), 'success'); return true end
        return false, 'Qbox player not found'
    end
    return false, 'money: framework not supported'
end)

-- ── bank ─────────────────────────────────────────────────────────────────────
RewardDispatcher.Register('bank', function(source, identifier, reward)
    local amount = tonumber(reward.amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end
    if not source or source <= 0 then return false, 'player must be online' end

    if Config.Framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local xPlayer = exports['es_extended']:getSharedObject().GetPlayerFromId(source)
        if xPlayer then xPlayer.addAccountMoney('bank', amount); Bridge.Notify(source, ('已入帳 $%d 至銀行'):format(amount), 'success'); return true end
        return false, 'ESX player not found'
    end
    if Config.Framework == 'qbcore' and GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
        if player then player.Functions.AddMoney('bank', amount); Bridge.Notify(source, ('已入帳 $%d 至銀行'):format(amount), 'success'); return true end
        return false, 'QB player not found'
    end
    if Config.Framework == 'qbox' and GetResourceState('qbx_core') == 'started' then
        local player = exports['qbx_core']:GetPlayer(source)
        if player then player.Functions.AddMoney('bank', amount); Bridge.Notify(source, ('已入帳 $%d 至銀行'):format(amount), 'success'); return true end
        return false, 'Qbox player not found'
    end
    return false, 'bank: framework not supported'
end)

-- ── vehicle (stub) ───────────────────────────────────────────────────────────
RewardDispatcher.Register('vehicle', function(source, identifier, reward)
    -- TODO: 接入載具所有權系統
    print(('[sp-recharge][RewardDispatcher] STUB vehicle: %s model=%s — not implemented, reward NOT delivered'):format(identifier, tostring(reward.model)))
    return false, 'vehicle reward not implemented'
end)

-- ── vip_days (stub) ──────────────────────────────────────────────────────────
RewardDispatcher.Register('vip_days', function(source, identifier, reward)
    -- TODO: 接入 VIP 資源
    local days = tonumber(reward.days) or 0
    print(('[sp-recharge][RewardDispatcher] STUB vip_days: %s days=%d — not implemented, reward NOT delivered'):format(identifier, days))
    return false, 'vip_days reward not implemented'
end)
