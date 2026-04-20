-- ═══════════════════════════════════════════════════════════════════════════
--  Custom Exports
--  自訂橋接 exports，供外部資源整合使用
--  不影響核心模組，可安全新增或停用
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
--  sofapotato_shop 橋接
--  對應 sofapotato_shop/server/server_config.lua ExternalProvider 介面
-- ─────────────────────────────────────────────────────────────────────────────

local SHOP_CURRENCY_MAP = {
    ['point:rx'] = {
        label = 'RX點數',
        getBalance = function(identifier)
            return Points.Get(identifier)
        end,
        add = function(identifier, amount, reason)
            return Points.Add(identifier, amount, reason or 'shop_add')
        end,
        remove = function(identifier, amount, reason)
            return Points.Remove(identifier, amount, reason or 'shop_remove')
        end,
    },
    ['point:rx_voucher'] = {
        label = 'RX點券',
        getBalance = function(identifier)
            return Points.GetVouchers(identifier)
        end,
        add = function(identifier, amount, reason)
            return Points.AddVouchers(identifier, amount, reason or 'shop_add')
        end,
        remove = function(identifier, amount, reason)
            return Points.RemoveVouchers(identifier, amount, reason or 'shop_remove')
        end,
    }
}

local LEGACY_SHOP_CURRENCY_ALIASES = {
    ['point:recharge'] = 'point:rx',
    ['point:rx_points'] = 'point:rx',
    ['point:recharge_points'] = 'point:rx',
    ['point:recharge_voucher'] = 'point:rx_voucher'
}

local function normalizeShopCurrencyCode(currencyCode)
    if type(currencyCode) ~= 'string' then
        return nil
    end

    local normalized = currencyCode:gsub('^%s+', ''):gsub('%s+$', ''):lower()
    if normalized == '' then
        return nil
    end

    return LEGACY_SHOP_CURRENCY_ALIASES[normalized] or normalized
end

local function getShopCurrencyHandler(currencyCode)
    local normalizedCode = normalizeShopCurrencyCode(currencyCode)
    if not normalizedCode then
        return nil
    end

    return SHOP_CURRENCY_MAP[normalizedCode]
end

---回傳幣種清單給 sofapotato_shop
exports('GetShopCurrencies', function()
    local rows = {}

    for code, data in pairs(SHOP_CURRENCY_MAP) do
        rows[#rows + 1] = {
            code = code,
            label = data.label,
            currencyType = 'point'
        }
    end

    table.sort(rows, function(a, b)
        return a.code < b.code
    end)

    return rows
end)

---查詢商城幣種餘額
---@param source       number  玩家 source（外部傳入，不使用）
---@param identifier   string  玩家識別碼
---@param currencyCode string  幣種代碼（如 point:rx）
---@return number
exports('GetShopCurrencyBalance', function(source, identifier, currencyCode)
    local handler = getShopCurrencyHandler(currencyCode)
    if not handler then
        return nil
    end

    return handler.getBalance(identifier)
end)

---新增商城幣種
---@param source       number
---@param identifier   string
---@param currencyCode string
---@param amount       number
---@param reason       string|nil
---@return boolean
exports('AddShopCurrency', function(source, identifier, currencyCode, amount, reason)
    local handler = getShopCurrencyHandler(currencyCode)
    if not handler then
        return nil
    end

    local ok, _ = handler.add(identifier, amount, reason)
    return ok == true
end)

---扣除商城幣種
---@param source       number
---@param identifier   string
---@param currencyCode string
---@param amount       number
---@param reason       string|nil
---@return boolean
exports('RemoveShopCurrency', function(source, identifier, currencyCode, amount, reason)
    local handler = getShopCurrencyHandler(currencyCode)
    if not handler then
        return nil
    end

    local ok, _ = handler.remove(identifier, amount, reason)
    return ok == true
end)
