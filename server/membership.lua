-- ═══════════════════════════════════════════════════════════════════════════
--  Membership Module
--
--  根據 recharge_total（累計儲值總額）計算會員等級，
--  並提供回饋點數的試算方法。
--
--  會員等級：在 Config.MemberTiers 設定，依 threshold 升序排列。
--  回饋計算：每次儲值後依當下等級的 cashback % 自動發放點數。
-- ═══════════════════════════════════════════════════════════════════════════

Membership = {}

-- ─────────────────────────────────────────────────────────────────────────────
--  GetTier  –  依 rechargeTotal 取得對應等級設定
-- ─────────────────────────────────────────────────────────────────────────────

---依累計儲值總額回傳最高符合的會員等級。
---@param rechargeTotal number
---@return table  Config.MemberTiers 中的某一筆
function Membership.GetTier(rechargeTotal)
    local result = Config.MemberTiers[1]
    for _, tier in ipairs(Config.MemberTiers) do
        if rechargeTotal >= tier.threshold then
            result = tier
        end
    end
    return result
end

---依玩家 identifier 查詢帳戶後回傳等級。
---@param identifier string
---@return table tier, number rechargeTotal
function Membership.GetTierByIdentifier(identifier)
    local account = DB.EnsureAccount(identifier)
    local total   = account and account.recharge_total or 0
    return Membership.GetTier(total), total
end

-- ─────────────────────────────────────────────────────────────────────────────
--  CalculateCashback  –  計算本次儲值應回饋的點數數量
-- ─────────────────────────────────────────────────────────────────────────────

---計算回饋點數（無條件捨去）。
---@param cashAmount    number  本次儲值金額
---@param rechargeTotal number  儲值後的新累計總額（用此決定等級）
---@return number pointAmount, table tier
function Membership.CalculateCashback(cashAmount, rechargeTotal)
    local tier   = Membership.GetTier(rechargeTotal)
    local amount = 0
    if tier.cashback > 0 then
        amount = math.floor(cashAmount * tier.cashback)
    end
    return amount, tier
end

-- ─────────────────────────────────────────────────────────────────────────────
--  GetProgress  –  查詢距下一等級還差多少
-- ─────────────────────────────────────────────────────────────────────────────

---@param identifier string
---@return table
---  .currentTier     table   目前等級設定
---  .nextTier        table|nil  nil 表示已是最高等級
---  .rechargeTotal   number
---  .remainToNext    number|nil  距下一等級還需累儲多少
function Membership.GetProgress(identifier)
    local account = DB.EnsureAccount(identifier)
    local total   = account and account.recharge_total or 0
    local current = Membership.GetTier(total)

    -- 找下一個等級
    local next    = nil
    local remain  = nil
    for _, tier in ipairs(Config.MemberTiers) do
        if tier.threshold > total then
            next   = tier
            remain = tier.threshold - total
            break
        end
    end

    return {
        currentTier   = current,
        nextTier      = next,
        rechargeTotal = total,
        remainToNext  = remain,
    }
end
