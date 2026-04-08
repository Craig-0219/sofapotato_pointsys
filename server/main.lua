-- ═══════════════════════════════════════════════════════════════════════════
--  sp-recharge  –  Main Entry Point
-- ═══════════════════════════════════════════════════════════════════════════

-- Activate the framework bridge after all adapter files are loaded
ActivateBridge()

print('[sp-recharge] Resource started. Framework: ' .. (Config.Framework or 'standalone'))


local function isRcAdmin(src)
    if src == 0 then return true end -- console
    return IsPlayerAceAllowed(src, 'sp-recharge.admin')
end

local function requireRcAdmin(src)
    if isRcAdmin(src) then return true end
    Bridge.Notify(src, 'You do not have permission to use this command.', 'error')
    return false
end

local function resolveRcIdentifier(input)
    if not input or input == '' then return nil, nil end

    -- Direct match (license/identifier already stored in DB)
    if Points.GetAccount(input) then
        return input, 'identifier'
    end

    -- citizenid fallback (online players only)
    for _, playerSrc in ipairs(GetPlayers()) do
        local src = tonumber(playerSrc)
        local citizenId = Bridge.GetCharacterId(src)
        if citizenId and citizenId == input then
            local identifier = Bridge.GetIdentifier(src)
            if identifier then
                return identifier, 'citizenid'
            end
        end
    end

    return input, 'identifier'
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Admin / Debug commands
--  (Remove or ACL-protect in production)
-- ─────────────────────────────────────────────────────────────────────────────

if Config.Debug then
    --- /rc_points <id>  – print point balance in server console
    RegisterCommand('rc_points', function(src, args)
        if not requireRcAdmin(src) then return end
        local input = args[1]
        if not input then
            print('Usage: rc_points <identifier|citizenid>')
            return
        end

        local identifier, resolvedBy = resolveRcIdentifier(input)
        local account = identifier and Points.GetAccount(identifier) or nil
        if account then
            print(('[sp-recharge] %s (%s) | points=%d | recharge_total=%d'):format(
                identifier, resolvedBy, account.points, account.recharge_total
            ))
        else
            print('[sp-recharge] Account not found (identifier/citizenid): ' .. input)
        end
    end, true)

    --- /rc_addpoints <identifier> <amount>
    RegisterCommand('rc_addpoints', function(src, args)
        if not requireRcAdmin(src) then return end
        local input      = args[1]
        local amount     = tonumber(args[2])
        if not input or not amount then
            print('Usage: rc_addpoints <identifier|citizenid> <amount>')
            return
        end

        local identifier = select(1, resolveRcIdentifier(input))
        local ok, err = Points.Add(identifier, amount, 'admin_debug', { admin = tostring(src) })
        print(ok and ('[sp-recharge] Added %d pts to %s'):format(amount, identifier)
                  or ('[sp-recharge] Error: %s'):format(err))
    end, true)

    --- /rc_recharge <identifier> <cashAmount> <pointAmount> <orderId>
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

        local identifier = select(1, resolveRcIdentifier(input))

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
        if not requireRcAdmin(src) then return end
        local input       = args[1]
        local rewardGroup = args[2] or 'default'
        if not input then
            print('Usage: rc_progress <identifier|citizenid> [rewardGroup]')
            return
        end
        local identifier = select(1, resolveRcIdentifier(input))
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
        if not requireRcAdmin(src) then return end
        local input       = args[1]
        local tierId      = args[2]
        local rewardGroup = args[3] or 'default'
        if not input or not tierId then
            print('Usage: rc_claim <identifier|citizenid> <tierId> [rewardGroup]')
            return
        end
        local identifier = select(1, resolveRcIdentifier(input))
        local ok, err = Rewards.ClaimReward(identifier, rewardGroup, tierId, nil)
        print(ok and ('[sp-recharge] Claimed %s/%s for %s'):format(rewardGroup, tierId, identifier)
                  or ('[sp-recharge] Claim FAILED: %s'):format(tostring(err)))
    end, true)
end
