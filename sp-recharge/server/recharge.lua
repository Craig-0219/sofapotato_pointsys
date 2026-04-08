-- ═══════════════════════════════════════════════════════════════════════════
--  Recharge Module
--
--  Handles the complete recharge flow:
--    1. Validate input
--    2. Idempotency check  (duplicate order guard)
--    3. Ensure account exists
--    4. Credit points + recharge_total atomically
--    5. Write transaction log
--    6. Record order
--    7. Trigger cumulative-reward threshold check
--    8. Return result
-- ═══════════════════════════════════════════════════════════════════════════

Recharge = {}

local function debugLog(msg)
    if Config.Debug then
        print(('[sp-recharge][Recharge] %s'):format(msg))
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  ApplyRecharge
-- ─────────────────────────────────────────────────────────────────────────────

---Process a completed recharge payment.
---
---@param data table
---  .identifier      string   player identifier (required)
---  .cashAmount      number   real-money value  (required, > 0)
---  .pointAmount     number   points to credit  (required, > 0)
---  .orderId         string   unique order id   (required)
---  .provider        string?  payment provider name      (default: 'manual')
---  .providerTradeNo string?  provider transaction ref
---  .remark          string?  arbitrary note
---  .rewardGroup     string?  which reward group to check (default: 'default')
---
---@return table result
---  .success        boolean
---  .error          string?         present on failure
---  .duplicate      boolean?        true when orderId already processed
---  .pointsBefore   number
---  .pointsAfter    number
---  .rechargeTotal  number          new lifetime total
---  .newThresholds  string[]        tier ids that became claimable from this recharge
function Recharge.ApplyRecharge(data)
    -- ── 1. Validate ──────────────────────────────────────────────────────────
    if type(data) ~= 'table' then
        return { success = false, error = 'data must be a table' }
    end

    local identifier = data.identifier
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

    -- ── 2. Idempotency check ─────────────────────────────────────────────────
    if DB.OrderExists(orderId) then
        debugLog(('Duplicate orderId rejected: %s'):format(orderId))
        return { success = false, duplicate = true, error = 'order already processed' }
    end

    -- ── 3. Ensure account ────────────────────────────────────────────────────
    local account = DB.EnsureAccount(identifier)
    local ptsBefore   = account.points
    local totalBefore = account.recharge_total

    -- ── 4. Atomic credit ─────────────────────────────────────────────────────
    local ok, updatedAccount = DB.ApplyRechargeCredit(identifier, pointAmount, cashAmount)
    if not ok then
        return { success = false, error = 'database credit failed' }
    end

    local ptsAfter   = updatedAccount.points
    local totalAfter = updatedAccount.recharge_total

    -- ── 5. Transaction log ───────────────────────────────────────────────────
    DB.InsertTransaction({
        identifier     = identifier,
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

    -- ── 6. Record order ──────────────────────────────────────────────────────
    DB.InsertOrder({
        identifier      = identifier,
        orderId         = orderId,
        provider        = data.provider or 'manual',
        providerTradeNo = data.providerTradeNo,
        cashAmount      = cashAmount,
        pointAmount     = pointAmount,
        remark          = data.remark,
    })

    debugLog(('Applied recharge %s: +%d pts, +%d cash  [pts %d→%d, total %d→%d]'):format(
        orderId, pointAmount, cashAmount, ptsBefore, ptsAfter, totalBefore, totalAfter
    ))

    -- ── 7. Threshold check ───────────────────────────────────────────────────
    local rewardGroup  = data.rewardGroup or 'default'
    local newThresholds = Rewards.CheckNewThresholds(identifier, rewardGroup, totalBefore, totalAfter)

    return {
        success        = true,
        pointsBefore   = ptsBefore,
        pointsAfter    = ptsAfter,
        rechargeTotal  = totalAfter,
        newThresholds  = newThresholds,
    }
end
