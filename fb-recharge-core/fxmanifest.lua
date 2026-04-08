fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'fb-recharge-core'
description 'FiveM Recharge Core System - Points & Cumulative Rewards'
version     '1.0.0'
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
    'server/database.lua',
    'server/reward_dispatcher.lua',
    'server/points.lua',
    'server/recharge.lua',
    'server/rewards.lua',
    -- Entry point & exports
    'server/exports.lua',
    'server/main.lua',
}
