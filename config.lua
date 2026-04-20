Config = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Framework: 'standalone' | 'esx' | 'qbcore' | 'qbox'
-- ─────────────────────────────────────────────────────────────────────────────
Config.Framework = 'standalone'

-- 自動執行 sql/install.sql 建表（false 可關閉）
Config.AutoSQL = true

-- ─────────────────────────────────────────────────────────────────────────────
-- 幣種說明
--   點數    (points)   ── 儲值購入、里程碑獎勵皆統一回到這裡
--   點券    (vouchers) ── 會員回饋發放至點券，可用於 shop 消費
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- 會員等級 + 回饋制度
--
-- threshold : 累積儲值總額（cashAmount 累計）達到此值即升等
-- cashback  : 每次儲值後「自動」回饋 點券 的比例
--             計算基礎 = cashAmount（實際儲值金額），無條件捨去
--             例：cashback = 0.05，儲值 1000 → 自動回饋 50 點券
--
-- ⚠ 必須依 threshold 升序排列，第一筆為預設等級（threshold = 0）
-- ─────────────────────────────────────────────────────────────────────────────
Config.MemberTiers = {
    { id = 'normal',  label = '萌新會員', threshold = 0,     cashback = 0.00 },
    { id = 'normal',  label = ' 銀牌會員', threshold = 5000,  cashback = 0.01 },
    { id = 'bronze',  label = '金牌會員', threshold = 12000,   cashback = 0.03 },
    { id = 'silver',  label = '白金會員', threshold = 30000,  cashback = 0.05 },
    { id = 'gold',    label = '鑽石會員', threshold = 60000,  cashback = 0.06 },
    { id = 'diamond', label = '車神會員', threshold = 100000, cashback = 0.08 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- 累儲里程碑獎勵（一次性手動領取，與回饋制度相互獨立）
--
-- 支援的 reward type：
--   vouchers  – 舊設定相容，實際會給點數
--   points    – 給點數
--   item / money / bank / vehicle / vip_days（見 reward_dispatcher.lua）
-- ─────────────────────────────────────────────────────────────────────────────
Config.RewardGroups = {
    ['default'] = {
        enable = true,   -- false 可暫停整個群組（玩家看不到、也無法領取）
        label  = '累儲里程碑',
        tiers = {
            {
                id        = 'tier_4999',
                threshold = 4999,
                label     = '累儲 4999 里程碑',
                rewards   = { { type = 'points', amount = 50 } },
            },
            {
                id        = 'tier_9999',
                threshold = 9999,
                label     = '累儲 9999 里程碑',
                rewards   = { { type = 'points', amount = 250 } },
            },
            {
                id        = 'tier_19999',
                threshold = 19999,
                label     = '累儲 19999 里程碑',
                rewards   = {
                    { type = 'points', amount = 800 },
                    { type = 'item',     item = 'luxury_gift', amount = 1 },
                },
            },
            {
                id        = 'tier_29999',
                threshold = 29999,
                label     = '累儲 29999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
			{
                id        = 'tier_39999',
                threshold = 39999,
                label     = '累儲 39999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
			{
                id        = 'tier_49999',
                threshold = 49999,
                label     = '累儲 49999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
			{
                id        = 'tier_59999',
                threshold = 59999,
                label     = '累儲 59999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
			{
                id        = 'tier_69999',
                threshold = 69999,
                label     = '累儲 69999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
			{
                id        = 'tier_79999',
                threshold = 79999,
                label     = '累儲 79999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
			{
                id        = 'tier_89999',
                threshold = 89999,
                label     = '累儲 89999 里程碑',
                rewards   = {
                    { type = 'points', amount = 3000 },
                    { type = 'vip_days', days   = 30   },
                },
            },
        },
    },
    -- ['vip_pass'] = { label = 'VIP Pass 累儲', tiers = { ... } },
}

-- ─────────────────────────────────────────────────────────────────────────────
Config.Notifications = { Enable = true }
Config.Debug = true
