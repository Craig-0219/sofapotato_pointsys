-- ═══════════════════════════════════════════════════════════════════════════
--  Rewards Module  –  Cumulative-recharge tier rewards
--
--  Design:
--    • Thresholds compare against recharge_total (lifetime, never reset).
--    • Each tier can be claimed exactly once per player per group.
--    • Manual-claim model: player chooses when to claim via UI / command.
--    • ClaimReward dispatches the reward and records the claim atomically.
-- ═══════════════════════════════════════════════════════════════════════════

Rewards = {}

local function debugLog(msg)
    if Config.Debug then
        print(('[sp-recharge][Rewards] %s'):format(msg))
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────────────────────────────────────

---回傳 group，若不存在或 enable = false 則回傳 nil。
local function getGroup(rewardGroup)
    local g = Config.RewardGroups[rewardGroup]
    if not g or g.enable == false then return nil end
    return g
end

local function getTier(group, tierId)
    for _, tier in ipairs(group.tiers) do
        if tier.id == tierId then return tier end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  CheckNewThresholds
--  Called by Recharge.ApplyRecharge to find tiers that newly became claimable.
-- ─────────────────────────────────────────────────────────────────────────────

---Returns a list of tier ids that crossed the threshold between totalBefore and totalAfter.
---@param identifier  string
---@param rewardGroup string
---@param totalBefore number
---@param totalAfter  number
---@return string[]   tier ids (may be empty)
function Rewards.CheckNewThresholds(identifier, rewardGroup, totalBefore, totalAfter)
    local group = getGroup(rewardGroup)
    if not group then return {} end

    local newlyReached = {}
    for _, tier in ipairs(group.tiers) do
        -- Crossed this tier's threshold with this recharge
        if totalBefore < tier.threshold and totalAfter >= tier.threshold then
            if not DB.IsRewardClaimed(identifier, rewardGroup, tier.id) then
                table.insert(newlyReached, tier.id)
                debugLog(('New claimable tier for %s: %s/%s'):format(identifier, rewardGroup, tier.id))
            end
        end
    end
    return newlyReached
end

-- ─────────────────────────────────────────────────────────────────────────────
--  GetRechargeProgress
-- ─────────────────────────────────────────────────────────────────────────────

---Returns progress info for a reward group.
---@param identifier  string
---@param rewardGroup string
---@return table|nil
---  .group         string
---  .label         string
---  .rechargeTotal number
---  .tiers         table[]  each with .id .threshold .label .status ('claimed'|'available'|'locked')
function Rewards.GetRechargeProgress(identifier, rewardGroup)
    local group = getGroup(rewardGroup)
    if not group then return nil end

    local rechargeTotal = Points.GetRechargeTotal(identifier)
    local claimed       = DB.GetClaimedTiers(identifier, rewardGroup)

    local tiers = {}
    for _, tier in ipairs(group.tiers) do
        local status
        if claimed[tier.id] then
            status = 'claimed'
        elseif rechargeTotal >= tier.threshold then
            status = 'available'
        else
            status = 'locked'
        end

        table.insert(tiers, {
            id        = tier.id,
            threshold = tier.threshold,
            label     = tier.label,
            status    = status,
            rewards   = tier.rewards,
        })
    end

    return {
        group         = rewardGroup,
        label         = group.label,
        rechargeTotal = rechargeTotal,
        tiers         = tiers,
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
--  GetAvailableRechargeRewards
-- ─────────────────────────────────────────────────────────────────────────────

---Returns only tiers in 'available' state (reached but not yet claimed).
---@param identifier  string
---@param rewardGroup string
---@return table[]
function Rewards.GetAvailableRechargeRewards(identifier, rewardGroup)
    local progress = Rewards.GetRechargeProgress(identifier, rewardGroup)
    if not progress then return {} end

    local available = {}
    for _, tier in ipairs(progress.tiers) do
        if tier.status == 'available' then
            table.insert(available, tier)
        end
    end
    return available
end

-- ─────────────────────────────────────────────────────────────────────────────
--  ClaimReward  (identifier version – offline-safe)
-- ─────────────────────────────────────────────────────────────────────────────

---Claim a single tier reward for the specified identifier.
---@param identifier  string
---@param rewardGroup string
---@param tierId      string
---@param source      number|nil  player server id (0 or nil = offline / server-only)
---@return boolean ok, string|nil err
function Rewards.ClaimReward(identifier, rewardGroup, tierId, source)
    local group = getGroup(rewardGroup)
    if not group then
        return false, ('reward group "%s" not found in Config'):format(rewardGroup)
    end

    local tier = getTier(group, tierId)
    if not tier then
        return false, ('tier "%s" not found in group "%s"'):format(tierId, rewardGroup)
    end

    -- Check threshold
    local rechargeTotal = Points.GetRechargeTotal(identifier)
    if rechargeTotal < tier.threshold then
        return false, ('recharge total %d < required %d'):format(rechargeTotal, tier.threshold)
    end

    -- Atomically insert claim (duplicate-key = already claimed)
    local inserted = DB.InsertRewardClaim(identifier, rewardGroup, tierId)
    if not inserted then
        return false, 'reward already claimed'
    end

    -- Dispatch rewards
    local src              = source or 0
    local allOk, dispErrs  = RewardDispatcher.Dispatch(src, identifier, tier.rewards)

    if not allOk then
        -- Claim record already inserted; log errors but don't roll back
        -- (partial delivery is better than silent loss)
        local errMsg = table.concat(dispErrs, '; ')
        print(('[sp-recharge][Rewards] Partial dispatch error for %s %s/%s: %s')
            :format(identifier, rewardGroup, tierId, errMsg))
    end

    debugLog(('Claimed %s/%s for %s (online=%s)'):format(rewardGroup, tierId, identifier, tostring(src > 0)))

    if src > 0 then
        Bridge.Notify(src, ('已領取「%s」獎勵！'):format(tier.label), 'success')
    end

    return true, nil
end
