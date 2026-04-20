-- ═══════════════════════════════════════════════════════════════════════════
--  Recharge Module  (v2)
--
--  完整儲值流程：
--    1. 驗證輸入
--    2. 重複訂單檢查（冪等保護）
--    3. 確保帳戶存在
--    4. 原子性入點（points + recharge_total）
--    5. 計算並發放回饋點券至 vouchers（依儲值後的會員等級）
--    6. 寫交易流水（由 Points 模組負責）
--    7. 記錄訂單
--    8. 觸發累儲里程碑門檻檢查
--    9. 回傳結果
-- ═══════════════════════════════════════════════════════════════════════════

Recharge = {}

local function debugLog(msg)
    if Config.Debug then print(('[sp-recharge][Recharge] %s'):format(msg)) end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  ApplyRecharge
-- ─────────────────────────────────────────────────────────────────────────────

---處理一筆已完成的儲值付款。
---
---@param data table
---  .identifier      string   玩家識別碼（必填）
---  .cashAmount      number   實際儲值金額，用於計算 recharge_total 及回饋（必填，> 0）
---  .pointAmount     number   入帳點數（必填，> 0）
---  .orderId         string   唯一訂單號（必填，冪等 key）
---  .provider        string?  付款來源（預設 'manual'）
---  .providerTradeNo string?  第三方流水號
---  .remark          string?  備註
---  .rewardGroup     string?  里程碑群組（預設 'default'）
---
---@return table result
---  .success          boolean
---  .error            string?
---  .duplicate        boolean?  true = 訂單已處理過
---  .pointsBefore     number
---  .pointsAfter      number
---  .voucherCashback  number   本次回饋點券數量（0 = 等級無回饋）
---  .rechargeTotal    number   新累計總額
---  .memberTier       string   儲值後的會員等級 id
---  .memberTierLabel  string
---  .newMilestones    string[] 本次新達成的里程碑 tier id 列表
function Recharge.ApplyRecharge(data)
    -- ── 1. 驗證 ──────────────────────────────────────────────────────────────
    if type(data) ~= 'table' then
        return { success = false, error = 'data must be a table' }
    end

    local identifier  = data.identifier
    local cashAmount  = tonumber(data.cashAmount)
    local pointAmount = tonumber(data.pointAmount)
    local orderId     = data.orderId

    if not identifier or identifier == '' then
        return { success = false, error = 'identifier is required' }
    end
    if not cashAmount or cashAmount <= 0 then
        return { success = false, error = 'cashAmount must be > 0' }
    end
    if not pointAmount or pointAmount <= 0 then
        return { success = false, error = 'pointAmount must be > 0' }
    end
    if not orderId or orderId == '' then
        return { success = false, error = 'orderId is required' }
    end

    -- ── 2. 冪等檢查 ───────────────────────────────────────────────────────────
    if DB.OrderExists(orderId) then
        debugLog(('Duplicate orderId rejected: %s'):format(orderId))
        return { success = false, duplicate = true, error = 'order already processed' }
    end

    -- ── 3. 確保帳戶 ───────────────────────────────────────────────────────────
    local account      = DB.EnsureAccount(identifier)
    local ptsBefore    = account.points
    local totalBefore  = account.recharge_total

    -- ── 4. 原子性入點 ─────────────────────────────────────────────────────────
    local ok, updated = DB.ApplyRechargeCredit(identifier, pointAmount, cashAmount)
    if not ok then
        return { success = false, error = 'database credit failed' }
    end

    local ptsAfter   = updated.points
    local totalAfter = updated.recharge_total

    -- 寫點數交易流水
    DB.InsertTransaction({
        identifier     = identifier,
        currency       = 'points',
        type           = 'recharge',
        amount         = pointAmount,
        balance_before = ptsBefore,
        balance_after  = ptsAfter,
        reason         = data.remark or ('儲值入點 orderId=%s'):format(orderId),
        metadata       = {
            orderId         = orderId,
            provider        = data.provider or 'manual',
            providerTradeNo = data.providerTradeNo,
            cashAmount      = cashAmount,
        },
    })

    -- ── 5. 計算並發放回饋點券至 vouchers ────────────────────────────────────────
    --  使用儲值「後」的 totalAfter 決定等級，讓升等立即享受新回饋比例
    local cashbackPoints, tier = Membership.CalculateCashback(cashAmount, totalAfter)

    if cashbackPoints > 0 then
        local cashbackOk = Points.IssueCashback(identifier, cashbackPoints, {
            orderId    = orderId,
            memberTier = tier.id,
            cashAmount = cashAmount,
        })
        if not cashbackOk then
            -- 回饋失敗不中斷流程，記 log 即可
            print(('[sp-recharge][Recharge] WARNING: cashback vouchers issuance failed for %s orderId=%s'):format(
                identifier, orderId
            ))
        end
    end

    -- ── 6. 記錄訂單 ───────────────────────────────────────────────────────────
    DB.InsertOrder({
        identifier      = identifier,
        orderId         = orderId,
        provider        = data.provider or 'manual',
        providerTradeNo = data.providerTradeNo,
        cashAmount      = cashAmount,
        pointAmount     = pointAmount,
        voucherCashback = cashbackPoints,
        memberTier      = tier.id,
        remark          = data.remark,
    })

    debugLog(('Recharge %s | +%d pts, +%d vouchers | tier=%s | total %d→%d'):format(
        orderId, pointAmount, cashbackPoints, tier.id, totalBefore, totalAfter
    ))

    -- ── 7. 里程碑門檻檢查 ─────────────────────────────────────────────────────
    local rewardGroup  = data.rewardGroup or 'default'
    local newMilestones = Rewards.CheckNewThresholds(identifier, rewardGroup, totalBefore, totalAfter)

    return {
        success          = true,
        pointsBefore     = ptsBefore,
        pointsAfter      = ptsAfter,
        voucherCashback  = cashbackPoints,
        rechargeTotal    = totalAfter,
        memberTier       = tier.id,
        memberTierLabel  = tier.label,
        newMilestones    = newMilestones,
    }
end
