-- ═══════════════════════════════════════════════════════════════════════════
--  Points Module
--
--  All point balance mutations go through this module so that:
--    • The account is auto-created if missing
--    • Every mutation is logged to the transaction ledger
-- ═══════════════════════════════════════════════════════════════════════════

Points = {}

local function debugLog(msg)
    if Config.Debug then
        print(('[sp-recharge][Points] %s'):format(msg))
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Internal: write a transaction entry after a mutation
-- ─────────────────────────────────────────────────────────────────────────────
local function logTx(identifier, txType, amount, before, after, reason, metadata)
    DB.InsertTransaction({
        identifier    = identifier,
        type          = txType,
        amount        = amount,
        balance_before = before,
        balance_after  = after,
        reason        = reason,
        metadata      = metadata,
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Public API
-- ─────────────────────────────────────────────────────────────────────────────

---Retrieve current point balance.
---Auto-creates the account if it does not exist.
---@param identifier string
---@return number points
function Points.Get(identifier)
    local account = DB.EnsureAccount(identifier)
    return account and account.points or 0
end

---Retrieve cumulative recharge total.
---@param identifier string
---@return number recharge_total
function Points.GetRechargeTotal(identifier)
    local account = DB.EnsureAccount(identifier)
    return account and account.recharge_total or 0
end

---Get full account data table.
---@param identifier string
---@return table account
function Points.GetAccount(identifier)
    return DB.EnsureAccount(identifier)
end

---Check whether the player can afford `amount` points.
---@param identifier string
---@param amount     number
---@return boolean
function Points.CanAfford(identifier, amount)
    local balance = Points.Get(identifier)
    return balance >= amount
end

---Add points to a player's account.
---@param identifier string
---@param amount     number  must be > 0
---@param reason     string|nil
---@param metadata   table|nil
---@return boolean ok, string|nil err
function Points.Add(identifier, amount, reason, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, 'amount must be a positive number'
    end

    DB.EnsureAccount(identifier)

    local before      = Points.Get(identifier)
    local ok, account = DB.AddPoints(identifier, amount)

    if not ok then
        return false, 'database update failed'
    end

    local after = account and account.points or (before + amount)
    logTx(identifier, 'add', amount, before, after, reason, metadata)
    debugLog(('Add %d pts to %s  [%d → %d]  reason=%s'):format(amount, identifier, before, after, reason or ''))

    return true, nil
end

---Remove points from a player's account.
---Fails if balance is insufficient.
---@param identifier string
---@param amount     number  must be > 0
---@param reason     string|nil
---@param metadata   table|nil
---@return boolean ok, string|nil err
function Points.Remove(identifier, amount, reason, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, 'amount must be a positive number'
    end

    DB.EnsureAccount(identifier)

    local before = Points.Get(identifier)
    if before < amount then
        return false, ('insufficient points: have %d, need %d'):format(before, amount)
    end

    local ok, account = DB.RemovePoints(identifier, amount)
    if not ok then
        return false, 'insufficient points or database update failed'
    end

    local after = account and account.points or (before - amount)
    logTx(identifier, 'remove', -amount, before, after, reason, metadata)
    debugLog(('Remove %d pts from %s  [%d → %d]  reason=%s'):format(amount, identifier, before, after, reason or ''))

    return true, nil
end
