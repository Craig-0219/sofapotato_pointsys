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

local SQL_FILE = 'sql/install.sql'

local function runAutoSql()
    if not Config.AutoSQL then
        log('Disabled (Config.AutoSQL = false).')
        return
    end

    local sqlContent = LoadResourceFile(GetCurrentResourceName(), SQL_FILE)
    if not sqlContent or sqlContent == '' then
        log(('Cannot read SQL file: %s'):format(SQL_FILE))
        return
    end

    local statements = parseSqlStatements(sqlContent)
    if #statements == 0 then
        log(('No executable statements found in %s'):format(SQL_FILE))
        return
    end

    for _, sql in ipairs(statements) do
        MySQL.query.await(sql)
    end

    log(('Schema check complete (%d statements)'):format(#statements))
end

CreateThread(function()
    Wait(500)
    runAutoSql()
end)
