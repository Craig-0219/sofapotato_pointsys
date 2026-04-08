-- ═══════════════════════════════════════════════════════════════════════════
--  sp-recharge  –  Main Entry Point
-- ═══════════════════════════════════════════════════════════════════════════

-- Activate the framework bridge after all adapter files are loaded
ActivateBridge()

print('[sp-recharge] Resource started. Framework: ' .. (Config.Framework or 'standalone'))

-- ─────────────────────────────────────────────────────────────────────────────
--  Admin / Debug commands
--  (Remove or ACL-protect in production)
-- ─────────────────────────────────────────────────────────────────────────────

if Config.Debug then
    --- /rc_points <id>  – print point balance in server console
    RegisterCommand('rc_points', function(src, args)
        if src ~= 0 then return end  -- console only
        local identifier = args[1]
        if not identifier then
            print('Usage: rc_points <identifier>')
            return
        end
        local account = Points.GetAccount(identifier)
        if account then
            print(('[sp-recharge] %s | points=%d | recharge_total=%d'):format(
                identifier, account.points, account.recharge_total
            ))
        else
            print('[sp-recharge] Account not found: ' .. identifier)
        end
    end, true)

    --- /rc_addpoints <identifier> <amount>
    RegisterCommand('rc_addpoints', function(src, args)
        if src ~= 0 then return end
        local identifier = args[1]
        local amount     = tonumber(args[2])
        if not identifier or not amount then
            print('Usage: rc_addpoints <identifier> <amount>')
            return
        end
        local ok, err = Points.Add(identifier, amount, 'admin_debug', { admin = 'console' })
        print(ok and ('[sp-recharge] Added %d pts to %s'):format(amount, identifier)
                  or ('[sp-recharge] Error: %s'):format(err))
    end, true)

    --- /rc_recharge <identifier> <cashAmount> <pointAmount> <orderId>
    RegisterCommand('rc_recharge', function(src, args)
        if src ~= 0 then return end
        local identifier  = args[1]
        local cashAmount  = tonumber(args[2])
        local pointAmount = tonumber(args[3])
        local orderId     = args[4] or ('DEBUG_%d'):format(os.time())

        if not identifier or not cashAmount or not pointAmount then
            print('Usage: rc_recharge <identifier> <cashAmount> <pointAmount> [orderId]')
            return
        end

        local result = Recharge.ApplyRecharge({
            identifier      = identifier,
            cashAmount      = cashAmount,
            pointAmount     = pointAmount,
            orderId         = orderId,
            provider        = 'debug_console',
            remark          = 'Debug recharge from console',
        })

        if result.success then
            print(('[sp-recharge] Recharge OK | pts %d→%d | total=%d | newTiers=%s'):format(
                result.pointsBefore, result.pointsAfter, result.rechargeTotal,
                table.concat(result.newThresholds or {}, ',')
            ))
        else
            print(('[sp-recharge] Recharge FAILED: %s (duplicate=%s)'):format(
                result.error, tostring(result.duplicate)
            ))
        end
    end, true)

    --- /rc_progress <identifier> [rewardGroup]
    RegisterCommand('rc_progress', function(src, args)
        if src ~= 0 then return end
        local identifier  = args[1]
        local rewardGroup = args[2] or 'default'
        if not identifier then
            print('Usage: rc_progress <identifier> [rewardGroup]')
            return
        end
        local progress = Rewards.GetRechargeProgress(identifier, rewardGroup)
        if not progress then
            print('[sp-recharge] Group not found: ' .. rewardGroup)
            return
        end
        print(('[sp-recharge] Progress for %s [%s] – total=%d'):format(
            identifier, rewardGroup, progress.rechargeTotal
        ))
        for _, tier in ipairs(progress.tiers) do
            print(('  [%s] %s | threshold=%d | status=%s'):format(
                tier.id, tier.label, tier.threshold, tier.status
            ))
        end
    end, true)

    --- /rc_claim <identifier> <tierId> [rewardGroup]
    RegisterCommand('rc_claim', function(src, args)
        if src ~= 0 then return end
        local identifier  = args[1]
        local tierId      = args[2]
        local rewardGroup = args[3] or 'default'
        if not identifier or not tierId then
            print('Usage: rc_claim <identifier> <tierId> [rewardGroup]')
            return
        end
        local ok, err = Rewards.ClaimReward(identifier, rewardGroup, tierId, nil)
        print(ok and ('[sp-recharge] Claimed %s/%s for %s'):format(rewardGroup, tierId, identifier)
                  or ('[sp-recharge] Claim FAILED: %s'):format(tostring(err)))
    end, true)
end
