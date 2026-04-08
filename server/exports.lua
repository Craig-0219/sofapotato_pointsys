-- ═══════════════════════════════════════════════════════════════════════════
--  Exports  –  Public API surface for other resources
--
--  All exports are server-side.
--  Usage from another resource:
--    exports['sp-recharge']:GetPoints('license:xxxx')
-- ═══════════════════════════════════════════════════════════════════════════

local function resolveIdentifier(source)
    return Bridge.GetIdentifier(tonumber(source))
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Query exports
-- ─────────────────────────────────────────────────────────────────────────────

---@return number  current point balance (0 if account not found)
exports('GetPoints', function(identifier)
    return Points.Get(identifier)
end)

---@return number
exports('GetPointsBySource', function(source)
    local id = resolveIdentifier(source)
    if not id then return 0 end
    return Points.Get(id)
end)

---@return number  lifetime recharge total
exports('GetRechargeTotal', function(identifier)
    return Points.GetRechargeTotal(identifier)
end)

---@return number
exports('GetRechargeTotalBySource', function(source)
    local id = resolveIdentifier(source)
    if not id then return 0 end
    return Points.GetRechargeTotal(id)
end)

---@return table|nil  full account row { identifier, points, recharge_total, created_at, updated_at }
exports('GetAccountData', function(identifier)
    return Points.GetAccount(identifier)
end)

---@return table|nil
exports('GetAccountDataBySource', function(source)
    local id = resolveIdentifier(source)
    if not id then return nil end
    return Points.GetAccount(id)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Affordability / mutation exports
-- ─────────────────────────────────────────────────────────────────────────────

---@return boolean
exports('CanAffordPoints', function(identifier, amount)
    return Points.CanAfford(identifier, tonumber(amount) or 0)
end)

---@return boolean
exports('CanAffordPointsBySource', function(source, amount)
    local id = resolveIdentifier(source)
    if not id then return false end
    return Points.CanAfford(id, tonumber(amount) or 0)
end)

---Add points to a player's account.
---@param identifier string
---@param amount     number
---@param reason     string|nil
---@param metadata   table|nil
---@return boolean ok, string|nil err
exports('AddPoints', function(identifier, amount, reason, metadata)
    return Points.Add(identifier, amount, reason, metadata)
end)

---Remove points from a player's account.
---@param identifier string
---@param amount     number
---@param reason     string|nil
---@param metadata   table|nil
---@return boolean ok, string|nil err
exports('RemovePoints', function(identifier, amount, reason, metadata)
    return Points.Remove(identifier, amount, reason, metadata)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Recharge / cumulative reward exports
-- ─────────────────────────────────────────────────────────────────────────────

---Process a completed recharge.
---@param data table  See Recharge.ApplyRecharge for full field list
---@return table result { success, error?, duplicate?, pointsBefore, pointsAfter, rechargeTotal, newThresholds }
exports('ApplyRecharge', function(data)
    return Recharge.ApplyRecharge(data)
end)

---Get full progress for a reward group (all tiers with status).
---@param identifier  string
---@param rewardGroup string  (default 'default')
---@return table|nil
exports('GetRechargeProgress', function(identifier, rewardGroup)
    return Rewards.GetRechargeProgress(identifier, rewardGroup or 'default')
end)

---Get only tiers in 'available' state (reached threshold, not yet claimed).
---@param identifier  string
---@param rewardGroup string  (default 'default')
---@return table[]
exports('GetAvailableRechargeRewards', function(identifier, rewardGroup)
    return Rewards.GetAvailableRechargeRewards(identifier, rewardGroup or 'default')
end)

---Claim a reward tier by identifier.  Works even if the player is offline.
---@param identifier  string
---@param rewardGroup string
---@param tierId      string
---@return boolean ok, string|nil err
exports('ClaimRechargeReward', function(identifier, rewardGroup, tierId)
    return Rewards.ClaimReward(identifier, rewardGroup or 'default', tierId, nil)
end)

---Claim a reward tier by source (player must be online).
---@param source      number
---@param rewardGroup string
---@param tierId      string
---@return boolean ok, string|nil err
exports('ClaimRechargeRewardBySource', function(source, rewardGroup, tierId)
    local id = resolveIdentifier(source)
    if not id then return false, 'could not resolve identifier from source' end
    return Rewards.ClaimReward(id, rewardGroup or 'default', tierId, tonumber(source))
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Log exports
-- ─────────────────────────────────────────────────────────────────────────────

---@param identifier string
---@param limit      number|nil  (default 50)
---@return table[]
exports('GetTransactionLogs', function(identifier, limit)
    return DB.GetTransactions(identifier, limit or 50)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  Framework bridge extension point
-- ─────────────────────────────────────────────────────────────────────────────

---Allow external resources to register custom reward type handlers at runtime.
---@param rewardType string
---@param handler    fun(source: number, identifier: string, reward: table): boolean, string
exports('RegisterRewardHandler', function(rewardType, handler)
    RewardDispatcher.Register(rewardType, handler)
end)

---Allow external resources to override or extend the framework bridge.
---@param key   string  Bridge function name
---@param fn    function
exports('SetBridgeFunction', function(key, fn)
    Bridge[key] = fn
end)
