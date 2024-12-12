local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"
-- 玩家的agent管理
local CMD = {}
-- 游戏数据配置

--游戏标签枚举
local GAME_TAG =
{
    ["normal"] = 0,
    ["hot"] = 1,
    ["new"] = 2,
    ["online"] = 3,
    ["max"] = 4, --越界检查
}

local game_type_list     = {} --当前开启的分类中有效子游戏列表(按分类)
local all_game_list      = {} --所有游戏列表
local send2clinet_data   = {} --发给客户端的数据
local tag_id_list = {} --打了tag的游戏id

--发送给客户端的数据格式
function reset2ClientGameList()
    local temp_send2clinet_data = {}
    LOG_DEBUG("reset2ClientGameList:", all_game_list)
    for gametype ,gamelist in pairs(all_game_list) do
        if nil == temp_send2clinet_data[gametype] then
            temp_send2clinet_data[gametype] = {}
        end
        for _, v in pairs(gamelist) do
            local constInfo = {}
            constInfo.id    = v.id
            constInfo.ord   = v.ord
            constInfo.tag   = v.gametag
            constInfo.level = v.level or 1
            constInfo.status = v.status
            constInfo.tag = v.gametag
            if v.gametag > 0 then
                constInfo.level = 0
                table.insert(tag_id_list, v.id)
            end
            table.insert(temp_send2clinet_data[gametype], constInfo)
        end
    end
    send2clinet_data = temp_send2clinet_data
end

-- 防止并发调用，这里先用临时变量顶替，最后赋值。暂没使用cs.queue
local function getGameList()
    local temp_all_game_list = {}

    local sql = "select * from s_game where status=1 order by `ord` desc"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            -- LOG_DEBUG("getGameList gameid:", row.id)
            row.type = math.floor(row.type)
            if nil == temp_all_game_list[row.type] then
                temp_all_game_list[row.type] = {}
            end
            temp_all_game_list[row.type][row.id] = row --所有游戏信息
        end
    end
    LOG_DEBUG("getGameList:", temp_all_game_list)
    all_game_list = temp_all_game_list
    reset2ClientGameList()
end

--重新加载游戏列表信息
--@return game_type_list
local function reloadGamelist( ... )
    getGameList()
end

--广播游戏列表信息
--@param game_type_list 游戏列表
local function broadcastGamelist()
    skynet.send(".userCenter", "lua", "ApiSendAllGameChange", send2clinet_data)
end

--发送给客户端的数据格式
function CMD.get2ClientGameList( ... )
    return send2clinet_data
end

-------- 后台重新设置概率控制 --------
function CMD.setgamerateconf(gameid, t_type, newcontrol)
    local settable
    if t_type == -1 then
        --设置整个字符串
        settable = newcontrol
    else
        local row = CMD.getRow(gameid)
        if row == nil then
            return true
        end
        if row.control == nil or row.control == "" then
            return true
        end

        local controljson = cjson.decode(row.control)
        if controljson == nil then
            return true
        else
            controljson = newcontrol
        end
        settable = controljson
    end

    local sql = string.format("update s_game set control = '%s' where id = %d", cjson.encode(settable), gameid)
    skynet.call(".mysqlpool", "lua", "execute", sql, true)
    CMD.reload(gameid)
end

---设置游戏开放状态
function CMD.changegamestatus( gameid )
    gameid = tonumber(gameid or 0)
    game_type_list = CMD.getGameList()
    local findgame = false
    for _, gametable in pairs(game_type_list) do
        for _, game in pairs(gametable) do
            if tonumber(game.id) == gameid then
                findgame = true
                break
            end
        end
        if findgame then
            break
        end
    end

    local gameStatus = 1
    if findgame then
        gameStatus = 0
    end
    local sql = string.format("update s_game set status = %d where id = %d", gameStatus, gameid)
    skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if gameStatus == 0 then
        --关闭游戏
        pcall(skynet.send, ".agentdesk", "lua", "apiKickGame", gameid)
    end

    --广播入口状态变化
    reloadGamelist()
    broadcastGamelist()
    return PDEFINE.RET.SUCCESS
 end

--设置游戏的开放等级
--@param gameids 110
--@param tag
function CMD.setGameLevel(gameid, level)
    gameid = math.floor(gameid)
    level = math.floor(level)
    LOG_DEBUG("setGameLevel", gameid, level)

    if gameid == nil or gameid == "" or level == nil then
        LOG_DEBUG("setGameLevel gameid or level is nil", gameid, level)
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end

    if gameid > 0 then
        local sql = string.format("update s_game set level =%d where id in (%s)", level, gameid)
        -- LOG_DEBUG("setGameLevel sql ", sql)
        skynet.call(".mysqlpool", "lua", "execute", sql, true)
        reloadGamelist()
        broadcastGamelist()
    end
    return PDEFINE.RET.SUCCESS
end

--设置游戏tag
--@param gameids 1,2,3
--@param tag
function CMD.setGameTag( gameids, tag )
    LOG_DEBUG("setGameTag", gameids, tag)
    if gameids == nil or gameids == "" or tag == nil or tag =='' then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    local gametag = math.floor(tonumber(tag))
    if gametag < 0 or gametag >= GAME_TAG.max then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end

    local gameidarr = {}
    local gametable = string.split(gameids, ',')
    for _, gameidstr in ipairs(gametable) do
        local gameid = math.floor(tonumber(gameidstr))
        table.insert(gameidarr, gameid)
    end
    if #gameidarr > 0 then
        local gamearrs = table.concat(gameidarr, ",")
        local sql = string.format("update s_game set gametag = %d where id in (%s)", gametag, gamearrs)
        skynet.call(".mysqlpool", "lua", "execute", sql, true)
        reloadGamelist()
        broadcastGamelist()
    end
    return PDEFINE.RET.SUCCESS
end

--设置游戏排序
--@param gameid 101
--@param ord 10
--@param type 3 (1 在线  2 slots  3 hot  4 街机 5 捕鱼 6桌游)
function CMD.setGameOrd(gameid, ord, gametype)
    if gameid == nil or ord == 0 or gametype == nil then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    gameid = math.floor(gameid)
    ord = math.floor(tonumber(ord))
    gametype = math.floor(tonumber(gametype))
    if gametype < 0 or gametype > 6 then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end

    if gameid > 0 then
        local sql = string.format("update s_game_type set ord = %d where gameid=%d", ord, gameid)
        skynet.call(".mysqlpool", "lua", "execute", sql, true)
        reloadGamelist()
        broadcastGamelist()
    end
    return PDEFINE.RET.SUCCESS
end

--为打了Tag的游戏设置排序
--@param gameid 101
--@param ord 10
--@param type 3 (1 在线  2 slots  3 hot  4 街机 5 捕鱼 6桌游)
function CMD.setGameTagOrd(gameid, ord, gametype)
    if gameid == nil or ord == 0 or gametype == nil then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    gameid = math.floor(gameid)
    ord = math.floor(tonumber(ord))

    if gameid > 0 then
        local sql = string.format("update s_game set taghot = %d where gameid=%d", ord, gameid)
        skynet.call(".mysqlpool", "lua", "execute", sql, true)
        reloadGamelist()
        broadcastGamelist()
    end
    return PDEFINE.RET.SUCCESS
end

function CMD.getRow(gameid)
    --获取所有匹配场GAMENAME
    if table.empty(all_game_list) then
        getGameList()
    end
    for _, gamelist in pairs(all_game_list) do
        for game_id, row  in pairs(gamelist) do
            if tonumber(game_id) == tonumber(gameid) then
                if nil ~= tag_id_list and table.contain(tag_id_list, game_id) then
                    row.level = 0
                end
                return row
            end
        end
    end
    return nil
end

function CMD.getGameStatus(gameid)
    for _, gamelist in pairs(all_game_list) do
        for _, game in pairs(gamelist) do
            if game.id == gameid then
                return game.status
            end
        end
    end
    return 0
end

function CMD.getAll()
    if table.empty(all_game_list) then
        getGameList()
    end
    return all_game_list
end

function CMD.getAll_Game_Type()
    return {}
end

function CMD.getGameList()
    if table.empty(all_game_list) then
        getGameList()
    end
    return all_game_list
end

--重新从库里加载配置到游戏
function CMD.reload(gameid)
	local sql = string.format("select * from s_game where id=%d", gameid)
	local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
	if #rs == 1 then
        reloadGamelist()
        --重新加载一遍控制模块的缓存数据
        skynet.send(".mgrdesk", "lua", "brodcastMsgByGameID", gameid, "reloadGame")
        skynet.send(".strategymgr", "lua", "reloadGameSetting", gameid)
	end
end

function CMD.start()
    if table.empty(all_game_list) then
        getGameList()
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
        -- print('cmd:', cmd, ' params:', (...))
		skynet.retpack(f(...))
	end)
	skynet.register(".gamemgr")
end)