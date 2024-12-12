local skynetroot = "./skynet/"

local lua_cpath = skynetroot .. "luaclib/?.so;" .. skynetroot.."luaclib/?.so"
package.cpath = package.cpath .. lua_cpath

local lua_path = skynetroot .. "lualib/?.lua;" ..  skynetroot .. "lualib/compat10/?.lua;" .. 
           "./?.lua;"..
           "./lualib/?.lua;" ..
           "./luaclib/?.lua;" ..
           "./global/?.lua;" ..
           "./common/?.lua;" ..
           "./design/?.lua"
package.path = lua_path

require "pdefine"
require "luaext"

-- 随机种子
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
-- 测试开关
TEST_RTP = true

local __skynet = {
    getenv = function() end,
    start = function() end,
    info_func = function() end,
}

local __cjson = {
    encode_sparse_array = function() end,
    encode_empty_table_as_object = function() end,
}

local initrequire = require
require = function(name)
    local excepts = {'protobuf', 'api_service', 'MessagePack'}
    for i, v in ipairs(excepts) do
        if string.find(name, v) then
            return nil
        end
    end
    if string.find(name, 'queue') then
        return function() end
    end
    if string.find(name, 'skynet') then
        return __skynet
    end
    if string.find(name, 'cjson') then
        return __cjson
    end

    return initrequire(name)
end

local function log_tostring(log_tbl, concatstr)
    if concatstr == nil then
        concatstr = " "
    end
    local tem = {}
    for idx, msg in pairs(log_tbl) do
        if type(msg) ~= 'string' then
            msg = tostring(msg)
        end
        table.insert(tem, msg)
    end
    return table.concat(tem, concatstr)
end

PRINT = print

local g_logfile = nil

sprint = function( ... )
    local str = log_tostring({os.date("%H:%M:%S",os.time()), ...})
    PRINT(str)

    if g_logfile == nil then
        g_logfile = io.open("log.log", "a")
    end
    if g_logfile then
        g_logfile:write(str.."\n")
        g_logfile:flush()
    end
end

WRITE_FILE = function(filename, content)
    local file = io.open(filename, "w")
    if file then
        file:write(content)
        file:close()
    end
end

print = function( ... )  -- 屏蔽掉游戏脚本里的屏幕输出
end
systemprint = function( ... ) -- 屏蔽掉游戏脚本里的屏幕输出
end
LOG_DEBUG = function( ... )  -- 屏蔽日志
end
LOG_INFO = function( ... )  -- 屏蔽日志
end
LOG_ERROR = function( ... )  -- 屏蔽日志
end
