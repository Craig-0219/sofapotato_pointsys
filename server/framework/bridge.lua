-- ═══════════════════════════════════════════════════════════════════════════
--  Framework Bridge – Abstract Interface
--
--  All framework adapters (standalone / esx / qbcore / qbox) must implement
--  every function defined here.  The active adapter is selected at runtime
--  based on Config.Framework and stored in `Bridge`.
-- ═══════════════════════════════════════════════════════════════════════════

---@class FrameworkBridge
---@field GetIdentifier   fun(source: number): string|nil
---@field GetCharacterId  fun(source: number): number|nil
---@field GetPlayerName   fun(source: number): string
---@field Notify          fun(source: number, msg: string, notifType: string)
---@field IsPlayerLoaded  fun(source: number): boolean

Bridge = {}  -- will be populated by the selected adapter

-- Registry of all registered adapters
local _adapters = {}

---Register a framework adapter.
---@param name    string           'standalone' | 'esx' | 'qbcore' | 'qbox'
---@param adapter FrameworkBridge
function RegisterBridgeAdapter(name, adapter)
    _adapters[name] = adapter
end

---Activate the adapter chosen in Config.Framework.
---Called once from main.lua after all adapter files are loaded.
function ActivateBridge()
    local name    = Config.Framework or 'standalone'
    local adapter = _adapters[name]

    if not adapter then
        print(('[sp-recharge] WARNING: No adapter for framework "%s". Falling back to standalone.'):format(name))
        adapter = _adapters['standalone']
    end

    -- Merge adapter into global Bridge table
    for k, v in pairs(adapter) do
        Bridge[k] = v
    end

    print(('[sp-recharge] Framework bridge activated: %s'):format(name))
end
