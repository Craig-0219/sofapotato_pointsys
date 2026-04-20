-- ═══════════════════════════════════════════════════════════════════════════
--  Exports  (v2)  –  所有 server-side exports
--
--  呼叫範例：
--    exports['sp-recharge']:GetPoints('license:xxxx')
-- ═══════════════════════════════════════════════════════════════════════════

local function callSpBridgeExport(exportName, source)
    if GetResourceState('sp_bridge') ~= 'started' then
        return nil
    end

    local bridgeExports = exports['sp_bridge']
    local fn = bridgeExports and bridgeExports[exportName]
    if type(fn) ~= 'function' then
        return nil
    end

    local ok, result = pcall(fn, bridgeExports, source)
    if not ok then
        return nil
    end

    return result
end

local function resolveId(source)
    local src = tonumber(source)
    if not src then return nil end

    local candidates = {}
    local seen = {}
    local function push(value)
        if value == nil then
            return
        end

        local text = tostring(value)
        if text == '' or seen[text] then
            return
        end

        seen[text] = true
        candidates[#candidates + 1] = text
    end

    -- Prefer the same source of truth as sofapotato_shop when available.
    push(callSpBridgeExport('GetCitizenId', src))
    push(callSpBridgeExport('GetCharacterId', src))
    push(callSpBridgeExport('GetFrameworkIdentifier', src))

    push(Bridge.GetCharacterId and Bridge.GetCharacterId(src) or nil)
    push(Bridge.GetIdentifier and Bridge.GetIdentifier(src) or nil)

    for i = 1, #candidates do
        local candidate = candidates[i]
        if DB.GetAccount(candidate) then
            return candidate
        end
    end

    return candidates[1]
end

-- ─────────────────────────────────────────────────────────────────────────────
--  帳戶查詢
-- ─────────────────────────────────────────────────────────────────────────────

exports('GetPoints', function(identifier)
    return Points.Get(identifier)
end)

exports('GetPointsBySource', function(source)
    local id = resolveId(source); if not id then return 0 end
    return Points.Get(id)
end)

exports('GetVouchers', function(identifier)
    return Points.GetVouchers(identifier)
end)

exports('GetVouchersBySource', function(source)
    local id = resolveId(source); if not id then return 0 end
    return Points.GetVouchers(id)
end)

exports('GetRechargeTotal', function(identifier)
    return Points.GetRechargeTotal(identifier)
end)

exports('GetRechargeTotalBySource', function(source)
    local id = resolveId(source); if not id then return 0 end
    return Points.GetRechargeTotal(id)
end)

---@return table|nil  { identifier, points, vouchers, recharge_total, created_at, updated_at }
exports('GetAccountData', function(identifier)
    return Points.GetAccount(identifier)
end)

exports('GetAccountDataBySource', function(source)
    local id = resolveId(source); if not id then return nil end
    return Points.GetAccount(id)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  點數（points）操作
-- ─────────────────────────────────────────────────────────────────────────────

exports('CanAffordPoints', function(identifier, amount)
    return Points.CanAfford(identifier, tonumber(amount) or 0)
end)

exports('CanAffordPointsBySource', function(source, amount)
    local id = resolveId(source); if not id then return false end
    return Points.CanAfford(id, tonumber(amount) or 0)
end)

exports('AddPoints', function(identifier, amount, reason, metadata)
    return Points.Add(identifier, amount, reason, metadata)
end)

exports('RemovePoints', function(identifier, amount, reason, metadata)
    return Points.Remove(identifier, amount, reason, metadata)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  點券（vouchers）舊接口相容
-- ─────────────────────────────────────────────────────────────────────────────

exports('CanAffordVouchers', function(identifier, amount)
    return Points.CanAffordVouchers(identifier, tonumber(amount) or 0)
end)

exports('CanAffordVouchersBySource', function(source, amount)
    local id = resolveId(source); if not id then return false end
    return Points.CanAffordVouchers(id, tonumber(amount) or 0)
end)

exports('AddVouchers', function(identifier, amount, reason, metadata)
    return Points.AddVouchers(identifier, amount, reason, metadata)
end)

exports('RemoveVouchers', function(identifier, amount, reason, metadata)
    return Points.RemoveVouchers(identifier, amount, reason, metadata)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  會員等級
-- ─────────────────────────────────────────────────────────────────────────────

---@return table  { id, label, threshold, cashback }
exports('GetMemberTier', function(identifier)
    local tier, _ = Membership.GetTierByIdentifier(identifier)
    return tier
end)

exports('GetMemberTierBySource', function(source)
    local id = resolveId(source)
    if not id then return Config.MemberTiers[1] end
    local tier, _ = Membership.GetTierByIdentifier(id)
    return tier
end)

---@return table  { currentTier, nextTier, rechargeTotal, remainToNext }
exports('GetMemberProgress', function(identifier)
    return Membership.GetProgress(identifier)
end)

exports('GetMemberProgressBySource', function(source)
    local id = resolveId(source)
    if not id then return nil end
    return Membership.GetProgress(id)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  儲值（ApplyRecharge）
-- ─────────────────────────────────────────────────────────────────────────────

---@param data table  見 Recharge.ApplyRecharge 說明
---@return table result
exports('ApplyRecharge', function(data)
    return Recharge.ApplyRecharge(data)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  累儲里程碑
-- ─────────────────────────────────────────────────────────────────────────────

exports('GetRechargeProgress', function(identifier, rewardGroup)
    return Rewards.GetRechargeProgress(identifier, rewardGroup or 'default')
end)

exports('GetAvailableRechargeRewards', function(identifier, rewardGroup)
    return Rewards.GetAvailableRechargeRewards(identifier, rewardGroup or 'default')
end)

exports('ClaimRechargeReward', function(identifier, rewardGroup, tierId)
    return Rewards.ClaimReward(identifier, rewardGroup or 'default', tierId, nil)
end)

exports('ClaimRechargeRewardBySource', function(source, rewardGroup, tierId)
    local id = resolveId(source)
    if not id then return false, 'could not resolve identifier' end
    return Rewards.ClaimReward(id, rewardGroup or 'default', tierId, tonumber(source))
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  交易紀錄
-- ─────────────────────────────────────────────────────────────────────────────

---@param identifier string
---@param currency   string|nil  'points' | 'vouchers' | nil（全部，含舊資料）
---@param limit      number|nil
---@return table[]
exports('GetTransactionLogs', function(identifier, currency, limit)
    return DB.GetTransactions(identifier, currency, limit or 50)
end)

-- ─────────────────────────────────────────────────────────────────────────────
--  擴充接口
-- ─────────────────────────────────────────────────────────────────────────────

exports('RegisterRewardHandler', function(rewardType, handler)
    RewardDispatcher.Register(rewardType, handler)
end)

exports('SetBridgeFunction', function(key, fn)
    Bridge[key] = fn
end)
