-- ═══════════════════════════════════════════════════════════════════════════
--  Points Module  (v2)
--
--  幣種：
--    points   – 儲值購入、里程碑皆回到這裡
--    vouchers – 會員回饋發放至點券，可用於 shop 消費
--
--  所有異動均自動寫入交易流水。
-- ═══════════════════════════════════════════════════════════════════════════

Points = {}

local function debugLog(msg)
    if Config.Debug then print(('[sp-recharge][Points] %s'):format(msg)) end
end

local function logTx(identifier, currency, txType, amount, before, after, reason, metadata)
    DB.InsertTransaction({
        identifier     = identifier,
        currency       = currency,
        type           = txType,
        amount         = amount,
        balance_before = before,
        balance_after  = after,
        reason         = reason,
        metadata       = metadata,
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
--  帳戶查詢
-- ─────────────────────────────────────────────────────────────────────────────

function Points.GetAccount(identifier)
    return DB.EnsureAccount(identifier)
end

function Points.Get(identifier)
    local account = DB.EnsureAccount(identifier)
    return account and account.points or 0
end

function Points.GetVouchers(identifier)
    local account = DB.EnsureAccount(identifier)
    return account and account.vouchers or 0
end

function Points.GetRechargeTotal(identifier)
    local account = DB.EnsureAccount(identifier)
    return account and account.recharge_total or 0
end

function Points.CanAfford(identifier, amount)
    return Points.Get(identifier) >= amount
end

function Points.CanAffordVouchers(identifier, amount)
    return Points.GetVouchers(identifier) >= amount
end

-- ─────────────────────────────────────────────────────────────────────────────
--  點數（points）異動
-- ─────────────────────────────────────────────────────────────────────────────

---新增點數
---@param identifier string
---@param amount     number
---@param reason     string|nil
---@param metadata   table|nil
---@return boolean ok, string|nil err
function Points.Add(identifier, amount, reason, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'amount must be > 0' end

    local before      = (DB.EnsureAccount(identifier) or {}).points or 0
    local ok, account = DB.AddPoints(identifier, amount)
    if not ok then return false, 'database update failed' end

    local after = account and account.points or (before + amount)
    logTx(identifier, 'points', 'add', amount, before, after, reason, metadata)
    debugLog(('Add points %d to %s  [%d→%d]'):format(amount, identifier, before, after))
    return true, nil
end

---扣除點數（餘額不足則拒絕）
---@return boolean ok, string|nil err
function Points.Remove(identifier, amount, reason, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'amount must be > 0' end

    local before = (DB.EnsureAccount(identifier) or {}).points or 0
    if before < amount then
        return false, ('點數不足：現有 %d，需要 %d'):format(before, amount)
    end

    local ok, account = DB.RemovePoints(identifier, amount)
    if not ok then return false, '點數不足或資料庫更新失敗' end

    local after = account and account.points or (before - amount)
    logTx(identifier, 'points', 'remove', -amount, before, after, reason, metadata)
    debugLog(('Remove points %d from %s  [%d→%d]'):format(amount, identifier, before, after))
    return true, nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  點券（vouchers）異動
-- ─────────────────────────────────────────────────────────────────────────────

---新增點券
---@param identifier string
---@param amount     number
---@param reason     string|nil
---@param metadata   table|nil
---@return boolean ok, string|nil err
function Points.AddVouchers(identifier, amount, reason, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'amount must be > 0' end

    local before      = (DB.EnsureAccount(identifier) or {}).vouchers or 0
    local ok, account = DB.AddVouchers(identifier, amount)
    if not ok then return false, 'database update failed' end

    local after = account and account.vouchers or (before + amount)
    logTx(identifier, 'vouchers', 'add', amount, before, after, reason, metadata)
    debugLog(('Add vouchers %d to %s  [%d→%d]'):format(amount, identifier, before, after))
    return true, nil
end

---扣除點券（餘額不足則拒絕）
---@return boolean ok, string|nil err
function Points.RemoveVouchers(identifier, amount, reason, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'amount must be > 0' end

    local before = (DB.EnsureAccount(identifier) or {}).vouchers or 0
    if before < amount then
        return false, ('點券不足：現有 %d，需要 %d'):format(before, amount)
    end

    local ok, account = DB.RemoveVouchers(identifier, amount)
    if not ok then return false, '點券不足或資料庫更新失敗' end

    local after = account and account.vouchers or (before - amount)
    logTx(identifier, 'vouchers', 'remove', -amount, before, after, reason, metadata)
    debugLog(('Remove vouchers %d from %s  [%d→%d]'):format(amount, identifier, before, after))
    return true, nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  回饋點券（儲值流程內部呼叫）
--  發放至 vouchers，type 固定為 'cashback'
-- ─────────────────────────────────────────────────────────────────────────────

---@param identifier string
---@param amount     number
---@param metadata   table|nil  建議帶入 { orderId, memberTier }
---@return boolean ok, string|nil err
function Points.IssueCashback(identifier, amount, metadata)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'amount must be > 0' end

    local before      = (DB.EnsureAccount(identifier) or {}).vouchers or 0
    local ok, account = DB.AddVouchers(identifier, amount)
    if not ok then return false, 'database update failed' end

    local after = account and account.vouchers or (before + amount)
    logTx(identifier, 'vouchers', 'cashback', amount, before, after, '儲值回饋', metadata)
    debugLog(('Cashback %d vouchers to %s  [%d→%d]'):format(amount, identifier, before, after))
    return true, nil
end

