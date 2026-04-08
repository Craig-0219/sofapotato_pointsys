-- ═══════════════════════════════════════════════════════════════════════════
--  fb-recharge-core  –  Database Schema
--  Run once before starting the resource.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Player Accounts ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `fb_recharge_accounts` (
    `id`             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `identifier`     VARCHAR(64)     NOT NULL                COMMENT 'Player identifier (license/steam/…)',
    `points`         INT UNSIGNED    NOT NULL DEFAULT 0      COMMENT 'Current spendable points',
    `recharge_total` INT UNSIGNED    NOT NULL DEFAULT 0      COMMENT 'Lifetime cumulative recharge amount (cash units)',
    `created_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 2. Transaction Ledger ───────────────────────────────────────────────────
--  Records every point addition, deduction, and recharge event.
CREATE TABLE IF NOT EXISTS `fb_recharge_transactions` (
    `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`     VARCHAR(64)     NOT NULL,
    `type`           VARCHAR(32)     NOT NULL                COMMENT 'add | remove | recharge | reward',
    `amount`         INT             NOT NULL                COMMENT 'Positive = credit, Negative = debit (points)',
    `balance_before` INT UNSIGNED    NOT NULL,
    `balance_after`  INT UNSIGNED    NOT NULL,
    `reason`         VARCHAR(255)    DEFAULT NULL,
    `metadata`       JSON            DEFAULT NULL            COMMENT 'Arbitrary extra data (order_id, source, …)',
    `created_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_identifier`  (`identifier`),
    KEY `idx_type`        (`type`),
    KEY `idx_created_at`  (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 3. Recharge Orders ──────────────────────────────────────────────────────
--  One row per completed payment – orderId is the idempotency key.
CREATE TABLE IF NOT EXISTS `fb_recharge_orders` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`        VARCHAR(64)     NOT NULL,
    `order_id`          VARCHAR(128)    NOT NULL             COMMENT 'Unique order ID from the payment gateway / back-end',
    `provider`          VARCHAR(64)     NOT NULL DEFAULT 'manual',
    `provider_trade_no` VARCHAR(128)    DEFAULT NULL         COMMENT 'Third-party transaction reference',
    `cash_amount`       INT UNSIGNED    NOT NULL DEFAULT 0   COMMENT 'Real-money value (smallest currency unit or custom)',
    `point_amount`      INT UNSIGNED    NOT NULL DEFAULT 0   COMMENT 'Points credited to the player',
    `remark`            VARCHAR(255)    DEFAULT NULL,
    `created_at`        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_order_id` (`order_id`),
    KEY `idx_identifier`     (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 4. Cumulative-Recharge Reward Claims ────────────────────────────────────
--  Prevents duplicate reward claims (one row = one claim forever).
CREATE TABLE IF NOT EXISTS `fb_recharge_reward_claims` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(64)  NOT NULL,
    `reward_group` VARCHAR(64)  NOT NULL,
    `tier_id`      VARCHAR(64)  NOT NULL,
    `claimed_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_claim` (`identifier`, `reward_group`, `tier_id`),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
