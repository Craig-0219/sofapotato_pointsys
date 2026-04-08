-- ═══════════════════════════════════════════════════════════════════════════
--  Database Layer  –  All oxmysql calls live here.
--  All functions are synchronous from the caller's perspective
--  (uses MySQL.Sync or Await wrappers).
-- ═══════════════════════════════════════════════════════════════════════════

DB = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function tbl(name)
    return Config.Tables[name]
end

local function debugLog(msg)
    if Config.Debug then
        print(('[fb-recharge-core][DB] %s'):format(msg))
    end
end

-- ── Account ──────────────────────────────────────────────────────────────────

---Fetch account row.  Returns nil if not found.
---@param identifier string
---@return table|nil
function DB.GetAccount(identifier)
    local result = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `identifier` = ?'):format(tbl('Accounts')),
        { identifier }
    )
    return result
end

---Ensure an account row exists.  Returns the account (created or existing).
---@param identifier string
---@return table
function DB.EnsureAccount(identifier)
    local existing = DB.GetAccount(identifier)
    if existing then return existing end

    MySQL.insert.await(
        ('INSERT IGNORE INTO `%s` (`identifier`, `points`, `recharge_total`) VALUES (?, 0, 0)')
            :format(tbl('Accounts')),
        { identifier }
    )
    return DB.GetAccount(identifier)
end

-- ── Points mutations (atomic) ─────────────────────────────────────────────────

---Add points to an account.
---@param identifier string
---@param amount     number  positive integer
---@return boolean success, table|nil account
function DB.AddPoints(identifier, amount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `points` = `points` + ? WHERE `identifier` = ?')
            :format(tbl('Accounts')),
        { amount, identifier }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

---Remove points from an account.  Will not go below 0.
---@param identifier string
---@param amount     number  positive integer
---@return boolean success, table|nil account
function DB.RemovePoints(identifier, amount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `points` = GREATEST(0, `points` - ?) WHERE `identifier` = ? AND `points` >= ?')
            :format(tbl('Accounts')),
        { amount, identifier, amount }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

---Credit both points and recharge_total atomically.
---@param identifier   string
---@param pointAmount  number  points to credit
---@param cashAmount   number  cash equivalent (for recharge_total tracking)
---@return boolean success, table|nil account
function DB.ApplyRechargeCredit(identifier, pointAmount, cashAmount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `points` = `points` + ?, `recharge_total` = `recharge_total` + ? WHERE `identifier` = ?')
            :format(tbl('Accounts')),
        { pointAmount, cashAmount, identifier }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

-- ── Transaction log ───────────────────────────────────────────────────────────

---Insert a transaction log entry.
---@param params table { identifier, type, amount, balance_before, balance_after, reason, metadata }
---@return number  inserted id
function DB.InsertTransaction(params)
    local metaJson = params.metadata and json.encode(params.metadata) or nil
    return MySQL.insert.await(
        ('INSERT INTO `%s` (`identifier`,`type`,`amount`,`balance_before`,`balance_after`,`reason`,`metadata`) VALUES (?,?,?,?,?,?,?)')
            :format(tbl('Transactions')),
        {
            params.identifier,
            params.type,
            params.amount,
            params.balance_before,
            params.balance_after,
            params.reason or nil,
            metaJson,
        }
    )
end

---Fetch recent transaction log entries for a player.
---@param identifier string
---@param limit      number
---@return table[]
function DB.GetTransactions(identifier, limit)
    return MySQL.query.await(
        ('SELECT * FROM `%s` WHERE `identifier` = ? ORDER BY `created_at` DESC LIMIT ?')
            :format(tbl('Transactions')),
        { identifier, limit or 50 }
    ) or {}
end

-- ── Orders ────────────────────────────────────────────────────────────────────

---Check if an order already exists (idempotency guard).
---@param orderId string
---@return boolean
function DB.OrderExists(orderId)
    local row = MySQL.single.await(
        ('SELECT `id` FROM `%s` WHERE `order_id` = ?'):format(tbl('Orders')),
        { orderId }
    )
    return row ~= nil
end

---Insert a completed recharge order record.
---@param params table
---@return number  inserted id
function DB.InsertOrder(params)
    return MySQL.insert.await(
        ('INSERT INTO `%s` (`identifier`,`order_id`,`provider`,`provider_trade_no`,`cash_amount`,`point_amount`,`remark`) VALUES (?,?,?,?,?,?,?)')
            :format(tbl('Orders')),
        {
            params.identifier,
            params.orderId,
            params.provider or 'manual',
            params.providerTradeNo or nil,
            params.cashAmount or 0,
            params.pointAmount or 0,
            params.remark or nil,
        }
    )
end

-- ── Reward Claims ─────────────────────────────────────────────────────────────

---Returns true if this tier has already been claimed.
---@param identifier  string
---@param rewardGroup string
---@param tierId      string
---@return boolean
function DB.IsRewardClaimed(identifier, rewardGroup, tierId)
    local row = MySQL.single.await(
        ('SELECT `id` FROM `%s` WHERE `identifier` = ? AND `reward_group` = ? AND `tier_id` = ?')
            :format(tbl('RewardClaims')),
        { identifier, rewardGroup, tierId }
    )
    return row ~= nil
end

---Insert a reward claim record.  Returns false if a duplicate-key conflict occurs.
---@param identifier  string
---@param rewardGroup string
---@param tierId      string
---@return boolean
function DB.InsertRewardClaim(identifier, rewardGroup, tierId)
    local ok, err = pcall(function()
        MySQL.insert.await(
            ('INSERT INTO `%s` (`identifier`,`reward_group`,`tier_id`) VALUES (?,?,?)')
                :format(tbl('RewardClaims')),
            { identifier, rewardGroup, tierId }
        )
    end)
    if not ok then
        debugLog(('InsertRewardClaim conflict or error: %s'):format(tostring(err)))
        return false
    end
    return true
end

---Return all claimed tier_ids for a player + group.
---@param identifier  string
---@param rewardGroup string
---@return string[]
function DB.GetClaimedTiers(identifier, rewardGroup)
    local rows = MySQL.query.await(
        ('SELECT `tier_id` FROM `%s` WHERE `identifier` = ? AND `reward_group` = ?')
            :format(tbl('RewardClaims')),
        { identifier, rewardGroup }
    ) or {}
    local claimed = {}
    for _, row in ipairs(rows) do
        claimed[row.tier_id] = true
    end
    return claimed
end
