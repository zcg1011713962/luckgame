local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"

cjson.encode_sparse_array(true)
local game_tool = require "game_tool"

local tmp_agent_pool = {} --临时存放点,待清理
--桌子管理 工具
local CMD = {}
local agent_pool = {} --游戏对应的桌子

local closeServer = nil
local desks     = {} --game agent对应的服务信息
local deskids   = {} --桌子id对应的agent

local GAME_NAME = skynet.getenv("gamename") or "game"
local APP = tonumber(skynet.getenv("app"))
local max_agent = 4096
local use_agent = 0

local supportLeaderBoardGameIDs = {} --需要进入排行榜中的游戏id列表

local function newDeskAgent(agentName)
    if use_agent  > max_agent then return false end
    local agent = skynet.newservice(agentName)
    -- LOG_INFO("newDeskAgent agentName: " .. agentName .. " agent: " .. agent)
    use_agent = use_agent + 1
    return agent
end

local function addAgent(type,size,AGENT)
    for i=1,size do
        local agent = newDeskAgent(AGENT)
        if agent then
            table.insert(agent_pool[type], agent)
        end
    end
end

local function getAgent(type)
    local agent = nil
    if not agent_pool[type] then
        return newDeskAgent(PDEFINE.GAME_TYPE_INFO[APP][1][type].AGENT)
    else
        agent = table.remove(agent_pool[type])
        if not agent then
            return newDeskAgent(PDEFINE.GAME_TYPE_INFO[APP][1][type].AGENT)
        end
    end
    return agent
end

-- 回收桌子
function CMD.recycleAgent(agent, deskid, gameid, ssid, maxRound)
    --直接释放掉 不回收 创建的agent花销的时间太长  
    desks[agent] = nil
    if nil ~= deskids[deskid] then
        deskids[deskid] = nil
    end

    --print('debug release agent:', agent)
    table.insert(tmp_agent_pool, {['agent']=agent, ['time']= os.time()})
    LOG_INFO("recycleAgent " .. agent)
    use_agent = use_agent - 1
    pcall(cluster.call, "master", ".mgrdesk", "deleteMatchDsmgr", GAME_NAME, gameid, deskid, ssid, maxRound)
end

-------- 随机生成房间id，防止被占用情况 --------
local function roundDeskId()
    local deskid = 0
    for i = 1, 5000 do
        deskid = math.random(100000, 999999)  --匹配房6位房间号
        if nil == deskids[deskid] or table.empty(deskids) then
            break
        end
    end
    assert(tonumber(deskid) ~= 0, "创建房间deskid==0")
    return deskid
end

-- 加载需要算入到排行榜中的gameids
function CMD.reloadGameIDs()
    local ok, gameidstrs = pcall(cluster.call, "master", ".configmgr", 'getVal', PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS)
    if ok and not isempty(gameidstrs) then
        supportLeaderBoardGameIDs = string.split_to_number(gameidstrs, ',')
    end
    return supportLeaderBoardGameIDs
end

function CMD.setGameIDs(newGameidstr)
    if not isempty(newGameidstr) then
        supportLeaderBoardGameIDs = string.split_to_number(newGameidstr, ',')
    end
    return PDEFINE.RET.SUCCESS
end

-- 获取支持排行榜的游戏id列表
--local function getGameIds()
function CMD.getGameIds()
    if #supportLeaderBoardGameIDs <= 0 then
        CMD.reloadGameIDs()
    end
    return supportLeaderBoardGameIDs
end

--从预分配的桌子信息中取出一个空闲的桌子
function CMD.createDeskInfo(cluster_info, msg, ip, gameid, newplayercount)
    LOG_DEBUG("createDeskInfo msg:", msg)
    if closeServer then
        return PDEFINE.RET.ERROR.ERROR_GAME_FIXING
    end
    local recvobj = msg
    gameid = math.floor(gameid)
    local agent = getAgent(gameid)
    if not agent then
        LOG_ERROR("createDeskInfo agent is nil")
        return PDEFINE.RET.ERROR.DESK_NOT_ENOUGH
    end

    local deskid = roundDeskId()
    local cluster_desk = { server = GAME_NAME, address = agent, delteTime = 0, delteflg = false, gameid = gameid, desk_id = deskid, desk_uuid = 0 }
    cluster_desk.maxRound = recvobj.maxRound or 0
    desks[agent] = cluster_desk

    deskids[deskid] = agent
    if not msg.taxrate then
        msg.taxrate = 0
        local ok ,cfg = pcall(cluster.call, "master", ".gamemgr", "getRow", gameid)
        if ok and cfg then
            msg.taxrate = tonumber(cfg.taxrate) or 0
        end
    end
    msg.openleadboard = 0
    local gameids = CMD.getGameIds()
    if table.contain(gameids, gameid) then
        msg.openleadboard = 1
    end
    LOG_DEBUG("createDeskInfo deskid:", deskid, "agent:", agent, " gameid:", gameid, "deskids size:", table.size(deskids), "msg.taxrate:",msg.taxrate)
    -- LOG_DEBUG('recvobj:', recvobj)
    local code, deskInfo = skynet.call(agent, "lua", "create", cluster_info, msg, ip, deskid, newplayercount, gameid)
    if code ~= 200 then
        LOG_WARNING("desk agent create fail", code, agent, deskid, gameid, newplayercount)
        CMD.recycleAgent(agent, deskid, gameid)
        return code
    end
    -- 增加房间类型
    if deskInfo and deskInfo.conf then
        cluster_desk.roomtype = deskInfo.conf.roomtype
    end

    if gameid < 400 then
        local curseat = deskInfo.curseat or 0
        --创建成功把改房间通知到管理类中
        if gameid == PDEFINE_GAME.GAME_TYPE.BALOOT then
            curseat = 1
        end
    
        --创建成功把改房间通知到管理类中
        local baseinfo = {
            deskid = deskid,
            ssid = deskInfo.ssid, --场次id
            basecoin = deskInfo.basecoin or 0, --底分金币
            leftcoin = deskInfo.leftcoin or 0, --离场金币
            mincoin = deskInfo.mincoin or 0, --准入金币
            seat = deskInfo.seat or 0, --最大人数
            curseat = curseat, --当前人数
            preseat = curseat, --预分配人数
            state = deskInfo.state or 0, --当前状态
            ready = deskInfo.ready or 0, --准备状态
            roomtype = 1, --1匹配房 2 vip房
        }
        if recvobj.conf then
            baseinfo.roomtype = recvobj.conf.roomtype --1匹配房 2 vip房
            baseinfo.entry = recvobj.conf.entry --最小携带
            baseinfo.score = recvobj.conf.score --底分
            baseinfo.turntime = recvobj.conf.turntime
            baseinfo.shuffle = recvobj.conf.shuffle
            baseinfo.voice = recvobj.conf.voice
            baseinfo.private = recvobj.conf.private
            baseinfo.maxRound = recvobj.maxRound or 0 --打多局
        end
        if baseinfo.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            pcall(cluster.call, "master", ".mgrdesk", "apendMatchDsmgr", GAME_NAME, gameid, baseinfo)
        elseif baseinfo.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
            pcall(cluster.call, "master", ".mgrdesk", "apendDsmgr", GAME_NAME, gameid, baseinfo)
        end

        if msg.uid and msg.uid > 0 then
            do_redis_async({"zincrby", PDEFINE.REDISKEY.GAME.favorite..msg.uid, 1, gameid})
        end
    end

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    if nil ~= deskInfo.users then
        for _, user in pairs(deskInfo.users) do
            user.cluster_info = nil
        end
    end
    retobj.gameid = recvobj.gameid
    retobj.deskinfo = deskInfo
    if gameid >= 400 then
        retobj.gameJackpot = {10, 50, 500, 1000}
    end

    cluster_desk.desk_uuid = deskInfo.uuid
    cluster_desk.ignore_match = deskInfo.predefine
    return PDEFINE.RET.SUCCESS, retobj, cluster_desk
end

--加入桌子
function CMD.joinDeskInfo(cluster_info, msg, ip, gameid)
    local recvobj = msg
    LOG_INFO("game dsmgr joinDeskInfo", gameid, recvobj.deskid, recvobj.uid)
    local deskid = recvobj.deskid
    gameid = math.floor(gameid)
    local agent = deskids[deskid]
    if not agent then
        LOG_ERROR("joinDeskInfo fail, agent not exist", gameid, deskid)
        return PDEFINE.RET.ERROR.DESKID_NOT_FOUND
    end
    local code, retobj = skynet.call(agent, "lua", "join", cluster_info, msg, ip, deskid)
    if code ~= 200 then
        LOG_ERROR("joinDeskInfo fail, code:", code, "gameid:", gameid)
        return code
    end
    local deskinfo = retobj.deskinfo
    if deskinfo then
        LOG_DEBUG("joinDeskInfo code:", code, "deskinfo:", deskinfo.gameid, deskinfo.deskid, deskinfo.uuid, deskinfo.state, deskinfo.round)
    else
        LOG_DEBUG("joinDeskInfo code:", code, "deskinfo: nil")
    end
    local cluster_desk = { server = GAME_NAME, address = agent, delteTime = 0, delteflg = false, gameid = recvobj.gameid, desk_id = deskid, desk_uuid = 0 }
    if deskinfo and deskinfo.conf then
        cluster_desk.roomtype = deskinfo.conf.roomtype
    end

    local jsonobj = retobj
    if jsonobj and jsonobj.deskinfo then --可能没有信息
        cluster_desk.desk_uuid = jsonobj.deskinfo.uuid
    end

    do_redis_async({"zincrby", PDEFINE.REDISKEY.GAME.favorite..msg.uid, 1, gameid})

    return PDEFINE.RET.SUCCESS, jsonobj, cluster_desk
end

-- 告知房间，玩家已换桌子
function CMD.setPlayerExit(deskid, uid)
    local agent = deskids[deskid]
    if agent then
        skynet.call(agent, "lua", "setPlayerExit", uid)
    end
    return PDEFINE.RET.SUCCESS
end

--本地调用 获取房间信息
function CMD.getDeskInfo(deskid)
    -- LOG_DEBUG("deskids:", deskids, ' deskid:', deskid)
    local agent = deskids[deskid]
    -- LOG_DEBUG("deskids:", deskids, ' deskid:', deskid, ' agent:', agent)
    if nil == agent then
        return nil
    end

    local deskInfo = skynet.call(agent, "lua", "apiGetDeskInfo", deskid)
    return deskInfo
end

-- 更新用户信息
function CMD.updateUserInfo(deskid, uid)
    local agent = deskids[deskid]
    if nil == agent then
        return nil
    end
    skynet.send(agent, "lua", "updateUserInfo", uid)
end

-- 将观战玩家剔除房间
function CMD.removeViewer(deskid, uid)
    local agent = deskids[deskid]
    skynet.call(agent, "lua", "removeViewer", uid)
end

-- 房主解散房间
function CMD.dismissRoom(deskid)
    local agent = deskids[deskid]
    if not agent then
        return nil
    end
    return skynet.call(agent, "lua", "dismissRoom")
end

--后台接口 解散房间
function CMD.apiKickDesk(deskid)
    deskid = tonumber(deskid)
    local agent = deskids[deskid]
    if nil == agent then
        return PDEFINE.RET.ERROR.DESKID_NOT_FOUND
    end

    local _, deskInfo = skynet.call(agent, "lua", "apiKickDesk")
    return PDEFINE.RET.SUCCESS, cjson.encode(deskInfo)
end

--后台接口 获取房间信息
function CMD.apiDeskInfo(deskid)
    local deskInfo  = CMD.getDeskInfo(deskid)
    if nil == deskInfo then
        deskInfo = ""
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(deskInfo)
end

--后台消息触发接口
function CMD.apiSendDeskNotice(deskid, msg)
    local agent = deskids[deskid]
    if nil == agent then
        return nil
    end
    skynet.call(agent, "lua", "apiSendDeskNotice", msg)
    return PDEFINE.RET.SUCCESS
end

--后台接口 解散房间
function CMD.apiKickAllDesk(csflag)
    closeServer = csflag
    LOG_DEBUG("apiKickAllDesk csflag:", csflag)
    for _,agent in pairs(deskids) do
        pcall(skynet.call, agent, "lua", "apiKickDesk")
    end
    return PDEFINE.RET.SUCCESS
end

--重新加载gamedc
function CMD.reloadGame(gameid, id)
    LOG_INFO("reloadGame", gameid, id)
    for deskid,agent in pairs(deskids) do
        if tonumber(deskid) == tonumber(id) then
            pcall(skynet.call, agent, "lua", "reload")
        end
    end
    return PDEFINE.RET.SUCCESS
end

--重置
function CMD.resetGameSetting(gameid, deskid, uidtable)
    LOG_INFO("resetGameSetting", gameid, deskid, uidtable)
    for deskid_t,agent in pairs(deskids) do
        if tonumber(deskid_t) == tonumber(deskid) then
            pcall(skynet.call, agent, "lua", "resetGameSetting", uidtable)
        end
    end
    return PDEFINE.RET.SUCCESS
end

local last_check_sec = -1; -- 秒

-- 定时执行循环 检测agent是否够，房间是否要清理
local function update()
    local time_now = os.time()
    local time_info = os.date("*t", time_now)

    -- 每秒判定
    if last_check_sec ~= time_info.sec then
        -- 设置秒
        for _, desinfo in pairs(desks) do
            if desinfo.delteflg == true then
                if os.time() >= desinfo.delteTime and desinfo.delteTime ~= 0 then
                    skynet.call(desinfo.address, "lua", "autoDelte") --初始化该桌子信息
                end
            end
        end
        last_check_sec = time_info.sec
        -- 每5秒处理
        if last_check_sec % 5 == 0 then
            -- 外部定时任务
            local to_exit_agents = {}
            local total = #tmp_agent_pool
            for i = total, 1, -1 do
                if time_now > tmp_agent_pool[i]['time'] + 5 then
                    table.insert(to_exit_agents, tmp_agent_pool[i]['agent'])
                    table.remove(tmp_agent_pool, i)
                end
            end
            for _, agent in ipairs(to_exit_agents) do
                LOG_INFO("exit agent: " .. agent)
                pcall(skynet.call, agent, "lua", "exit")
            end
        end
    end
end

local function gameLoop()
    while true do
        update()
        skynet.sleep(100)
    end
end

function CMD.setFreeGameDate(gameid, uid, freeCnt)
    game_tool.data.setFreeGameDate(gameid,uid,freeCnt)
end

local function notifyDsmgrInit()
    local function notify()
        local ok = pcall(cluster.send, "master", ".strategymgr", "onDsmgrInit", GAME_NAME)
        LOG_INFO("notify dsmgr inited", ok)
    end

    --多通知几次，保证服务能正确启起来，对面已做好防止重入
    skynet.timeout(100, notify)
    skynet.timeout(200, notify)
    skynet.timeout(400, notify)
    skynet.timeout(800, notify)
    skynet.timeout(1600, notify)
end

function CMD.start()
    if nil~=PDEFINE.GAME_TYPE_INFO[APP] and PDEFINE.GAME_TYPE_INFO[APP][1] then
        for _, gameBase in pairs(PDEFINE.GAME_TYPE_INFO[APP][1]) do
            if gameBase.STATE == 1 then
                agent_pool[gameBase.ID] = {}
                addAgent(gameBase.ID, gameBase.COUNT, gameBase.AGENT)
            end
        end
    end
    pcall(cluster.send, "master", ".mgrdesk", "joinMatchDsmgr", GAME_NAME) --先到master 占个坑

    notifyDsmgrInit()

    skynet.fork(gameLoop)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)
    skynet.register("." .. SERVICE_NAME)
end)
