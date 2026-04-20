-- ═══════════════════════════════════════════════════════════════════════════
--  Database Layer  (v2)
--  幣種：points（儲值購入／里程碑）、vouchers（會員回饋）
-- ═══════════════════════════════════════════════════════════════════════════

DB = {}

local TBL = {
    Accounts     = 'sp_recharge_accounts',
    Transactions = 'sp_recharge_transactions',
    Orders       = 'sp_recharge_orders',
    RewardClaims = 'sp_recharge_reward_claims',
}

local function tbl(name) return TBL[name] end

local function debugLog(msg)
    if Config.Debug then print(('[sp-recharge][DB] %s'):format(msg)) end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Account
-- ─────────────────────────────────────────────────────────────────────────────

---@param identifier string
---@return table|nil
function DB.GetAccount(identifier)
    return MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `identifier` = ?'):format(tbl('Accounts')),
        { identifier }
    )
end

---建立帳戶（若不存在）並回傳帳戶資料。
---@param identifier string
---@return table
function DB.EnsureAccount(identifier)
    local existing = DB.GetAccount(identifier)
    if existing then
        return existing
    end

    MySQL.insert.await(
        ('INSERT IGNORE INTO `%s` (`identifier`,`points`,`vouchers`,`recharge_total`) VALUES (?,0,0,0)')
            :format(tbl('Accounts')),
        { identifier }
    )
    return DB.GetAccount(identifier)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Points mutations
-- ─────────────────────────────────────────────────────────────────────────────

---@return boolean, table|nil
function DB.AddPoints(identifier, amount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `points` = `points` + ? WHERE `identifier` = ?')
            :format(tbl('Accounts')),
        { amount, identifier }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

---不允許低於 0，且餘額必須 >= amount 才執行。
---@return boolean, table|nil
function DB.RemovePoints(identifier, amount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `points` = GREATEST(0, `points` - ?) WHERE `identifier` = ? AND `points` >= ?')
            :format(tbl('Accounts')),
        { amount, identifier, amount }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Vouchers mutations（會員回饋點券）
-- ─────────────────────────────────────────────────────────────────────────────

---@return boolean, table|nil
function DB.AddVouchers(identifier, amount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `vouchers` = `vouchers` + ? WHERE `identifier` = ?')
            :format(tbl('Accounts')),
        { amount, identifier }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

---不允許低於 0，且餘額必須 >= amount 才執行。
---@return boolean, table|nil
function DB.RemoveVouchers(identifier, amount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `vouchers` = GREATEST(0, `vouchers` - ?) WHERE `identifier` = ? AND `vouchers` >= ?')
            :format(tbl('Accounts')),
        { amount, identifier, amount }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Recharge credit（points + recharge_total 同步更新）
-- ─────────────────────────────────────────────────────────────────────────────

---@return boolean, table|nil
function DB.ApplyRechargeCredit(identifier, pointAmount, cashAmount)
    local affected = MySQL.update.await(
        ('UPDATE `%s` SET `points` = `points` + ?, `recharge_total` = `recharge_total` + ? WHERE `identifier` = ?')
            :format(tbl('Accounts')),
        { pointAmount, cashAmount, identifier }
    )
    if (affected or 0) == 0 then return false, nil end
    return true, DB.GetAccount(identifier)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Transaction log
-- ─────────────────────────────────────────────────────────────────────────────

---@param params table
---  .identifier    string
---  .currency      string   'points'（舊資料可能仍有 vouchers）
---  .type          string
---  .amount        number
---  .balance_before number
---  .balance_after  number
---  .reason        string|nil
---  .metadata      table|nil
function DB.InsertTransaction(params)
    local metaJson = params.metadata and json.encode(params.metadata) or nil
    MySQL.insert.await(
        ('INSERT INTO `%s` (`identifier`,`currency`,`type`,`amount`,`balance_before`,`balance_after`,`reason`,`metadata`) VALUES (?,?,?,?,?,?,?,?)')
            :format(tbl('Transactions')),
        {
            params.identifier,
            params.currency or 'points',
            params.type,
            params.amount,
            params.balance_before,
            params.balance_after,
            params.reason or nil,
            metaJson,
        }
    )
end

---@param identifier string
---@param currency   string|nil  'points' | 'vouchers' | nil (全部，含舊資料)
---@param limit      number
---@return table[]
function DB.GetTransactions(identifier, currency, limit)
    if currency then
        return MySQL.query.await(
            ('SELECT * FROM `%s` WHERE `identifier` = ? AND `currency` = ? ORDER BY `created_at` DESC LIMIT ?')
                :format(tbl('Transactions')),
            { identifier, currency, limit or 50 }
        ) or {}
    else
        return MySQL.query.await(
            ('SELECT * FROM `%s` WHERE `identifier` = ? ORDER BY `created_at` DESC LIMIT ?')
                :format(tbl('Transactions')),
            { identifier, limit or 50 }
        ) or {}
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Orders
-- ─────────────────────────────────────────────────────────────────────────────

---@param orderId string
---@return boolean
function DB.OrderExists(orderId)
    return MySQL.single.await(
        ('SELECT `id` FROM `%s` WHERE `order_id` = ?'):format(tbl('Orders')),
        { orderId }
    ) ~= nil
end

---@param params table
---@return boolean
function DB.InsertOrder(params)
    local id = MySQL.insert.await(
        ('INSERT INTO `%s` (`identifier`,`order_id`,`provider`,`provider_trade_no`,`cash_amount`,`point_amount`,`voucher_cashback`,`member_tier`,`remark`) VALUES (?,?,?,?,?,?,?,?,?)')
            :format(tbl('Orders')),
        {
            params.identifier,
            params.orderId,
            params.provider        or 'manual',
            params.providerTradeNo or nil,
            params.cashAmount      or 0,
            params.pointAmount     or 0,
            params.voucherCashback or 0,
            params.memberTier      or nil,
            params.remark          or nil,
        }
    )
    return (id or 0) > 0
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Reward Claims
-- ─────────────────────────────────────────────────────────────────────────────

---@return boolean
function DB.IsRewardClaimed(identifier, rewardGroup, tierId)
    return MySQL.single.await(
        ('SELECT `id` FROM `%s` WHERE `identifier` = ? AND `reward_group` = ? AND `tier_id` = ?')
            :format(tbl('RewardClaims')),
        { identifier, rewardGroup, tierId }
    ) ~= nil
end

---@return boolean  false = 重複或錯誤
function DB.InsertRewardClaim(identifier, rewardGroup, tierId)
    local ok, err = pcall(function()
        MySQL.insert.await(
            ('INSERT INTO `%s` (`identifier`,`reward_group`,`tier_id`) VALUES (?,?,?)')
                :format(tbl('RewardClaims')),
            { identifier, rewardGroup, tierId }
        )
    end)
    if not ok then
        debugLog(('InsertRewardClaim conflict: %s'):format(tostring(err)))
        return false
    end
    return true
end

---@return table  { [tier_id] = true }
function DB.GetClaimedTiers(identifier, rewardGroup)
    local rows = MySQL.query.await(
        ('SELECT `tier_id` FROM `%s` WHERE `identifier` = ? AND `reward_group` = ?')
            :format(tbl('RewardClaims')),
        { identifier, rewardGroup }
    ) or {}
    local claimed = {}
    for _, row in ipairs(rows) do claimed[row.tier_id] = true end
    return claimed
end
