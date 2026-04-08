# sp-recharge

FiveM 儲值點數／累儲獎勵核心，支援 `oxmysql` 與多框架 bridge（standalone / ESX / QBCore / Qbox）。

## 新增功能：AutoSQL

現在資源啟動時會自動讀取並執行 `sql/install.sql`，用於自動建立所需資料表（`CREATE TABLE IF NOT EXISTS ...`）。

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

### 欄位說明

- `Enable`：是否啟用自動 SQL（`false` 時不執行）。
- `File`：要載入的 SQL 相對路徑。
- `LogEachStatement`：是否逐條輸出執行 log。

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
