Config = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Framework
-- 'standalone' | 'esx' | 'qbcore' | 'qbox'
-- ─────────────────────────────────────────────────────────────────────────────
Config.Framework = 'standalone'

-- ─────────────────────────────────────────────────────────────────────────────
-- Database table names  (change if you need a custom prefix)
-- ─────────────────────────────────────────────────────────────────────────────
Config.Tables = {
    Accounts     = 'fb_recharge_accounts',
    Transactions = 'fb_recharge_transactions',
    Orders       = 'fb_recharge_orders',
    RewardClaims = 'fb_recharge_reward_claims',
}


-- ─────────────────────────────────────────────────────────────────────────────
-- Auto SQL (自動執行安裝 SQL)
-- Enable=false 可關閉自動建表
-- File 預設使用 sql/install.sql
-- ─────────────────────────────────────────────────────────────────────────────
Config.AutoSQL = {
    Enable = true,
    File = 'sql/install.sql',
    LogEachStatement = false,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Cumulative-recharge reward groups
--
-- Each group is an independent tier ladder that tracks its own threshold.
-- Multiple groups allow different reward tracks (e.g. 'default', 'vip_pass').
--
-- Reward types handled by reward_dispatcher:
--   points   – add points to the player's recharge account
--   item     – give an inventory item  (requires framework item support)
--   money    – give cash in hand
--   bank     – deposit to bank account
--   vehicle  – spawn / give a vehicle  (stub)
--   vip_days – grant VIP duration      (stub)
-- ─────────────────────────────────────────────────────────────────────────────
Config.RewardGroups = {
    ['default'] = {
        label = '累儲獎勵',
        -- Thresholds are compared against recharge_total (cumulative, permanent)
        tiers = {
            {
                id        = 'tier_300',
                threshold = 300,
                label     = '累儲 300 獎勵',
                rewards   = {
                    { type = 'points', amount = 30 },
                },
            },
            {
                id        = 'tier_1000',
                threshold = 1000,
                label     = '累儲 1000 獎勵',
                rewards   = {
                    { type = 'points', amount = 150 },
                    { type = 'item',   item = 'black_money', amount = 5 },
                },
            },
            {
                id        = 'tier_3000',
                threshold = 3000,
                label     = '累儲 3000 獎勵',
                rewards   = {
                    { type = 'points',   amount = 600 },
                    { type = 'vip_days', days = 30   },
                },
            },
        },
    },
    -- ['vip_pass'] = { label = 'VIP Pass 累儲', tiers = { ... } },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Notifications
-- ─────────────────────────────────────────────────────────────────────────────
Config.Notifications = {
    Enable = true,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Debug logging  (set false in production)
-- ─────────────────────────────────────────────────────────────────────────────
Config.Debug = true
