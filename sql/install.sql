-- ═══════════════════════════════════════════════════════════════════════════
--  sp-recharge  –  Database Schema  (v2)
--
--  幣種：
--    points   = 點數，儲值購入／里程碑使用
--    vouchers = 點券，會員回饋發放至此，可用於 shop 消費
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. 玩家帳戶 ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sp_recharge_accounts` (
    `id`             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `identifier`     VARCHAR(64)   NOT NULL                 COMMENT '玩家識別碼',
    `points`         INT UNSIGNED  NOT NULL DEFAULT 0       COMMENT '點數餘額（儲值購入／里程碑）',
    `vouchers`       INT UNSIGNED  NOT NULL DEFAULT 0       COMMENT '點券餘額（會員回饋）',
    `recharge_total` INT UNSIGNED  NOT NULL DEFAULT 0       COMMENT '累計儲值總額（永久不重置）',
    `created_at`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 2. 交易流水 ───────────────────────────────────────────────────────────────
--  currency = 'points'   → balance_before/after 為點數餘額
--  currency = 'vouchers' → balance_before/after 為點券餘額
--
--  type 說明：
--    points 幣種   ： add | remove | recharge | reward
--    vouchers 幣種 ： add | remove | cashback
CREATE TABLE IF NOT EXISTS `sp_recharge_transactions` (
    `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`     VARCHAR(64)     NOT NULL,
    `currency`       VARCHAR(20)     NOT NULL DEFAULT 'points'  COMMENT 'points | vouchers',
    `type`           VARCHAR(32)     NOT NULL,
    `amount`         INT             NOT NULL                   COMMENT '正數=入帳，負數=扣帳',
    `balance_before` INT UNSIGNED    NOT NULL,
    `balance_after`  INT UNSIGNED    NOT NULL,
    `reason`         VARCHAR(255)    DEFAULT NULL,
    `metadata`       JSON            DEFAULT NULL,
    `created_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_currency`   (`currency`),
    KEY `idx_type`       (`type`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 3. 儲值訂單 ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sp_recharge_orders` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`        VARCHAR(64)     NOT NULL,
    `order_id`          VARCHAR(128)    NOT NULL,
    `provider`          VARCHAR(64)     NOT NULL DEFAULT 'manual',
    `provider_trade_no` VARCHAR(128)    DEFAULT NULL,
    `cash_amount`       INT UNSIGNED    NOT NULL DEFAULT 0,
    `point_amount`      INT UNSIGNED    NOT NULL DEFAULT 0,
    `voucher_cashback`  INT UNSIGNED    NOT NULL DEFAULT 0       COMMENT '本筆儲值自動回饋的點券數量',
    `member_tier`       VARCHAR(32)     DEFAULT NULL            COMMENT '儲值當下的會員等級 id',
    `remark`            VARCHAR(255)    DEFAULT NULL,
    `created_at`        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_order_id`  (`order_id`),
    KEY `idx_identifier`      (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 4. 累儲里程碑領取紀錄 ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sp_recharge_reward_claims` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(64)  NOT NULL,
    `reward_group` VARCHAR(64)  NOT NULL,
    `tier_id`      VARCHAR(64)  NOT NULL,
    `claimed_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_claim`       (`identifier`, `reward_group`, `tier_id`),
    KEY `idx_identifier`        (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
