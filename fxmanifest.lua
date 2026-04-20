fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'sp_recharge'
description 'FiveM Recharge Core – Points, Membership & Cashback'
version     '2.0.0'
author      'fb-dev'

shared_scripts {
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- Framework bridge (load order matters)
    'server/framework/bridge.lua',
    'server/framework/standalone.lua',
    'server/framework/esx.lua',
    'server/framework/qbcore.lua',
    'server/framework/qbox.lua',
    -- Core modules
    'server/autosql.lua',
    'server/database.lua',
    'server/reward_dispatcher.lua',
    'server/membership.lua',
    'server/points.lua',
    'server/recharge.lua',
    'server/rewards.lua',
    -- Entry point & exports
    'server/exports.lua',
    'server/custom_exports.lua',
    'server/main.lua',
}

dependencies {
    'sp_bridge'
}
