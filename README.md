# sp-recharge

FiveM RX點數／累儲獎勵核心，支援 `oxmysql` 與多框架 bridge（standalone / ESX / QBCore / Qbox）。

商城橋接預設對應：

- `point:rx`   → `points`（RX點數）

舊 `vouchers`／`point:rx_voucher` 僅保留相容，系統啟動後會自動併入 `points`。

## 新增功能：AutoSQL


資源啟動時會自動讀取並執行 `sql/install.sql`，用於自動建立所需資料表（`CREATE TABLE IF NOT EXISTS ...`）。

- 自動執行檔案：`sql/install.sql`
- 載入模組：`server/autosql.lua`
- 設定位置：`config.lua -> Config.AutoSQL`

## AutoSQL 設定

```lua
Config.AutoSQL = {
    Enable = true,
    File = 'sql/install.sql',
    LogEachStatement = false,
}
```

## Server Exports（完整）

> 全部為 server-side exports，資源名預設為 `sp-recharge`。

### 查詢類

- `exports['sp-recharge']:GetPoints(identifier)`
- `exports['sp-recharge']:GetPointsBySource(source)`
- `exports['sp-recharge']:GetRechargeTotal(identifier)`
- `exports['sp-recharge']:GetRechargeTotalBySource(source)`
- `exports['sp-recharge']:GetAccountData(identifier)`
- `exports['sp-recharge']:GetAccountDataBySource(source)`

### 可用性／異動類

- `exports['sp-recharge']:CanAffordPoints(identifier, amount)`
- `exports['sp-recharge']:CanAffordPointsBySource(source, amount)`
- `exports['sp-recharge']:AddPoints(identifier, amount, reason, metadata)`
- `exports['sp-recharge']:RemovePoints(identifier, amount, reason, metadata)`

### 儲值／累儲獎勵類

- `exports['sp-recharge']:ApplyRecharge(data)`
- `exports['sp-recharge']:GetRechargeProgress(identifier, rewardGroup)`
- `exports['sp-recharge']:GetAvailableRechargeRewards(identifier, rewardGroup)`
- `exports['sp-recharge']:ClaimRechargeReward(identifier, rewardGroup, tierId)`
- `exports['sp-recharge']:ClaimRechargeRewardBySource(source, rewardGroup, tierId)`

### 紀錄與擴充類

- `exports['sp-recharge']:GetTransactionLogs(identifier, limit)`
- `exports['sp-recharge']:RegisterRewardHandler(rewardType, handler)`
- `exports['sp-recharge']:SetBridgeFunction(key, fn)`

## Console Commands（Debug 模式）

> 以下指令僅在 `Config.Debug = true` 時註冊。
> 使用者需具備 ACE 權限：`sp-recharge.admin`（console 預設可用）。

- `/rc_points <identifier|citizenid>`：查看點數與累儲（支援直接輸入 citizenid，會自動轉 identifier）。
- `/rc_addpoints <identifier|citizenid> <amount>`：手動加點。
- `/rc_recharge <identifier|citizenid> <cashAmount> <pointAmount> [orderId]`：模擬儲值。
- `/rc_progress <identifier|citizenid> [rewardGroup]`：查看累儲進度。
- `/rc_claim <identifier|citizenid> <tierId> [rewardGroup]`：手動領取指定 tier。

ACE 設定範例（`server.cfg`）：
```cfg
add_ace group.admin sp-recharge.admin allow
```

## 安裝步驟

1. 確認已安裝並啟動 `oxmysql`。
2. 將本資源加入 `server.cfg`：
   ```cfg
   ensure oxmysql
   ensure sp-recharge
   ```
3. 首次啟動時，AutoSQL 會自動建立資料表。

## 注意事項

- AutoSQL 目前以 `;` 作為 SQL 語句切分符號。
- 建議 `sql/install.sql` 維持 schema 建表用途，避免放入高風險資料異動語句。
