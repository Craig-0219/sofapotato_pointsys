-- ═══════════════════════════════════════════════════════════════════════════
--  sp-recharge  –  Main Entry Point  (v2)
-- ═══════════════════════════════════════════════════════════════════════════

ActivateBridge()

print('[sp-recharge] v2 started. Framework: ' .. (Config.Framework or 'standalone'))

-- ─────────────────────────────────────────────────────────────────────────────
--  Admin helpers
--  ACE: sp-recharge.admin（in-game 指令也需要 ACE 授權）
--  console（src == 0）永遠允許
-- ─────────────────────────────────────────────────────────────────────────────

local function isRcAdmin(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, 'sp-recharge.admin')
end

local function requireRcAdmin(src)
    if isRcAdmin(src) then return true end
    Bridge.Notify(src, '你沒有權限執行此指令。', 'error')
    return false
end

---解析指令輸入的玩家識別碼（支援 identifier 字串或 citizenid）
local function resolveRcIdentifier(input)
    if not input or input == '' then return nil, nil end

    -- 先嘗試直接當 identifier 查帳戶
    if Points.GetAccount(input) then
        return input, 'identifier'
    end

    -- 再嘗試對線上玩家做 citizenid 比對
    for _, playerSrc in ipairs(GetPlayers()) do
        local src      = tonumber(playerSrc)
        local citizenId = Bridge.GetCharacterId(src)
        if citizenId and tostring(citizenId) == tostring(input) then
            local identifier = Bridge.GetIdentifier(src)
            if identifier then return identifier, 'citizenid' end
        end
    end

    return input, 'identifier'
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Admin / Debug 指令
--  Config.Debug = false 可在正式環境關閉所有 rc_* 指令
-- ─────────────────────────────────────────────────────────────────────────────

if Config.Debug then

    -- rc_account <identifier|citizenid>
    -- 顯示完整帳戶（點數、累儲總額、會員等級）
    RegisterCommand('rc_account', function(src, args)
        if not requireRcAdmin(src) then return end
        local input = args[1]
        if not input then print('Usage: rc_account <identifier|citizenid>') return end

        local id, resolvedBy = resolveRcIdentifier(input)
        local acc  = id and Points.GetAccount(id) or nil
        if acc then
            local tier = Membership.GetTier(acc.recharge_total)
            print(('[sp-recharge] %s  (resolved via %s)'):format(id, resolvedBy))
            print(('  points        : %d'):format(acc.points))
            print(('  recharge_total: %d'):format(acc.recharge_total))
            print(('  member_tier   : %s (%s)  cashback=%.0f%%'):format(
                tier.id, tier.label, tier.cashback * 100
            ))
        else
            print('[sp-recharge] Account not found: ' .. input)
        end
    end, true)

    -- rc_addpoints <identifier|citizenid> <amount>
    RegisterCommand('rc_addpoints', function(src, args)
        if not requireRcAdmin(src) then return end
        local input  = args[1]
        local amount = tonumber(args[2])
        if not input or not amount then print('Usage: rc_addpoints <identifier|citizenid> <amount>') return end

        local id = select(1, resolveRcIdentifier(input))
        local ok, err = Points.Add(id, amount, 'admin_debug', { admin = tostring(src) })
        print(ok and ('[sp-recharge] +%d points → %s'):format(amount, id)
                  or ('[sp-recharge] ERROR: %s'):format(err))
    end, true)

    -- rc_addvouchers <identifier|citizenid> <amount>
    -- 舊指令相容保留，實際上改為加點數
    RegisterCommand('rc_addvouchers', function(src, args)
        if not requireRcAdmin(src) then return end
        local input  = args[1]
        local amount = tonumber(args[2])
        if not input or not amount then print('Usage: rc_addvouchers <identifier|citizenid> <amount>') return end

        local id = select(1, resolveRcIdentifier(input))
        local ok, err = Points.AddVouchers(id, amount, 'admin_debug_legacy_voucher', { admin = tostring(src) })
        print(ok and ('[sp-recharge] +%d points (legacy voucher alias) → %s'):format(amount, id)
                  or ('[sp-recharge] ERROR: %s'):format(err))
    end, true)

    -- rc_recharge <identifier|citizenid> <cashAmount> <pointAmount> [orderId]
    -- 模擬完整儲值（含回饋點數計算）
    RegisterCommand('rc_recharge', function(src, args)
        if not requireRcAdmin(src) then return end
        local input       = args[1]
        local cashAmount  = tonumber(args[2])
        local pointAmount = tonumber(args[3])
        local orderId     = args[4] or ('DEBUG_%d'):format(os.time())

        if not input or not cashAmount or not pointAmount then
            print('Usage: rc_recharge <identifier|citizenid> <cashAmount> <pointAmount> [orderId]')
            return
        end

        local id = select(1, resolveRcIdentifier(input))
        local r  = Recharge.ApplyRecharge({
            identifier  = id,
            cashAmount  = cashAmount,
            pointAmount = pointAmount,
            orderId     = orderId,
            provider    = 'debug_console',
            remark      = 'Debug recharge',
        })

        if r.success then
            print('[sp-recharge] Recharge OK')
            print(('  points    : %d → %d  (+%d recharge, +%d cashback)'):format(
                r.pointsBefore,
                r.pointsAfter,
                pointAmount,
                r.cashbackPoints or 0
            ))
            print(('  total     : %d  tier=%s (%s)'):format(r.rechargeTotal, r.memberTier, r.memberTierLabel))
            print(('  milestones: [%s]'):format(table.concat(r.newMilestones or {}, ', ')))
        else
            print(('[sp-recharge] FAILED: %s  duplicate=%s'):format(r.error, tostring(r.duplicate)))
        end
    end, true)

    -- rc_tier <identifier|citizenid>
    -- 顯示會員等級與升等進度
    RegisterCommand('rc_tier', function(src, args)
        if not requireRcAdmin(src) then return end
        local input = args[1]
        if not input then print('Usage: rc_tier <identifier|citizenid>') return end

        local id   = select(1, resolveRcIdentifier(input))
        local prog = Membership.GetProgress(id)
        print(('[sp-recharge] Member tier: %s'):format(id))
        print(('  current : %s (%s)  cashback=%.0f%%'):format(
            prog.currentTier.id, prog.currentTier.label, prog.currentTier.cashback * 100
        ))
        print(('  total   : %d'):format(prog.rechargeTotal))
        if prog.nextTier then
            print(('  next    : %s (%s)  需再累儲 %d'):format(
                prog.nextTier.id, prog.nextTier.label, prog.remainToNext
            ))
        else
            print('  next    : 已達最高等級')
        end
    end, true)

    -- rc_milestone <identifier|citizenid> [rewardGroup]
    -- 顯示累儲里程碑進度
    RegisterCommand('rc_milestone', function(src, args)
        if not requireRcAdmin(src) then return end
        local input = args[1]
        local group = args[2] or 'default'
        if not input then print('Usage: rc_milestone <identifier|citizenid> [rewardGroup]') return end

        local id   = select(1, resolveRcIdentifier(input))
        local prog = Rewards.GetRechargeProgress(id, group)
        if not prog then print('[sp-recharge] Group not found: ' .. group) return end

        print(('[sp-recharge] Milestones [%s] for %s  total=%d'):format(group, id, prog.rechargeTotal))
        for _, tier in ipairs(prog.tiers) do
            print(('  [%s] %s | need=%d | %s'):format(tier.id, tier.label, tier.threshold, tier.status))
        end
    end, true)

    -- rc_claim <identifier|citizenid> <tierId> [rewardGroup]
    RegisterCommand('rc_claim', function(src, args)
        if not requireRcAdmin(src) then return end
        local input = args[1]
        local tid   = args[2]
        local group = args[3] or 'default'
        if not input or not tid then print('Usage: rc_claim <identifier|citizenid> <tierId> [rewardGroup]') return end

        local id = select(1, resolveRcIdentifier(input))
        local ok, err = Rewards.ClaimReward(id, group, tid, nil)
        print(ok and ('[sp-recharge] Claimed %s/%s for %s'):format(group, tid, id)
                  or ('[sp-recharge] FAILED: %s'):format(tostring(err)))
    end, true)

end
