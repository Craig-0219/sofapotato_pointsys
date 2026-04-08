-- ═══════════════════════════════════════════════════════════════════════════
--  Auto SQL Installer
--  Executes SQL schema statements on resource start.
-- ═══════════════════════════════════════════════════════════════════════════

local function log(msg)
    print(('[sp-recharge][AutoSQL] %s'):format(msg))
end

local function stripLineComment(line)
    local trimmed = line:gsub('^%s+', '')
    if trimmed:sub(1, 2) == '--' then
        return ''
    end
    return line
end

local function parseSqlStatements(sqlContent)
    local cleanedLines = {}
    for line in sqlContent:gmatch('[^\r\n]+') do
        cleanedLines[#cleanedLines + 1] = stripLineComment(line)
    end

    local cleaned = table.concat(cleanedLines, '\n')
    local statements = {}
    for statement in cleaned:gmatch('([^;]+);') do
        local normalized = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if normalized ~= '' then
            statements[#statements + 1] = normalized
        end
    end
    return statements
end

local function runAutoSql()
    local autoCfg = Config.AutoSQL or {}
    if autoCfg.Enable == false then
        log('Disabled in config (Config.AutoSQL.Enable = false).')
        return
    end

    local sqlFile = autoCfg.File or 'sql/install.sql'
    local sqlContent = LoadResourceFile(GetCurrentResourceName(), sqlFile)
    if not sqlContent or sqlContent == '' then
        log(('Cannot read SQL file: %s'):format(sqlFile))
        return
    end

    local statements = parseSqlStatements(sqlContent)
    if #statements == 0 then
        log(('No executable SQL statements found in %s'):format(sqlFile))
        return
    end

    for index, sql in ipairs(statements) do
        MySQL.query.await(sql)
        if autoCfg.LogEachStatement then
            log(('Executed statement %d/%d'):format(index, #statements))
        end
    end

    log(('Completed schema check (%d statements) from %s'):format(#statements, sqlFile))
end

CreateThread(function()
    Wait(500)
    runAutoSql()
end)
