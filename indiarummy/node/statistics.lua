local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local player_tool = require "base.player_tool"
local CMD = {}

function CMD.expExitG(gameid, uid)
    LOG_DEBUG("CMD.expExitG gameid:", gameid, ' uid:',uid)
    local playerInfo = player_tool.getPlayerInfo(uid)
    local coin
    if playerInfo ~= nil then
        coin = playerInfo.coin
    end
    local data = {uid = uid, act = PDEFINE.ACTIONS.GAME[3]..":"..gameid, ext = coin}
    CMD.addActionsDot(data)
end

local function formatData(data)
    if nil == data.act then
        data.act = ""
    end
    if nil == data.ts then
        data.ts = ""
    end
    if nil == data.ext then
        data.ext = ""
    end
    if nil == data.gameid then
        data.gameid = 0
    end
    if nil == data.menu then
        data.menu = 0
    end
    if nil == data.itemid then
        data.itemid = 0
    end
    return data
end

function CMD.addActionsDot(data)
    if nil == data.uid then
        LOG_ERROR('addActionsDot uid is nil:', data)
        return        
    end
    if nil == data.ts then
        data.ts = os.time()
    end
    if type(data.ext) == 'table' then
        data.ext = mysqlEscapeString(cjson.encode(data.ext))
    end
    if type(data.ext) == 'boolean' then
        if data.ext then
            data.ext = '1'
        else
            data.ext = '0'
        end
    end
    if nil == data.ext or string.len(data.ext)  == 0 then
        data.ext = " "
    end
    data = formatData(data)

    local tbname = getStatisticsTbName()
    local sql = string.format( "insert into `%s` (uid, act, ts, gameid, menu, itemid, ext) value(%d,'%s',%d,%d,%d, %d,'%s')",
                           tbname, data.uid, data.act, data.ts, data.gameid, data.menu, data.itemid, data.ext)
    do_mysql_queue(sql)

    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".statistics")
end)