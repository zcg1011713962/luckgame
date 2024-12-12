--[[
    单机游戏房间
    一个standaloneagent对应一组杀率控制策略以及命中这条策略的若干个玩家
    每个玩家有独立的桌子数据和玩家数据，但他们共享一条杀率策略和杀率数据
]]

local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local queue = require "skynet.queue"
local player_tool = require "base.player_tool"
local sysmarquee = require "sysmarquee"
local record = require "base.record"
local betUtil = require "betgame.betutils"
local BetStgy = require "betgame.betstgy"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false) --将空table{}打包成[]
local cs = queue()

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
}

local MAX_SEAT = 400    --座位数

--控制策略
---@type BetStgy
local stgy = BetStgy.new()

--游戏逻辑
local gamelogic = {}

--玩家信息
---@class User
---@field uid integer            --ID
---@field seatid integer         --座位号
---@field usericon string        --头像
---@field coin integer           --金币
---@field cluster_info table     --node地址
---@field level integer          --等级
---@field svip integer           --vip

--机台deskInfo
---@class DeskInfo
---@field user User             --玩家信息
---@field state integer         --桌子状态
---@field private table         --私有信息（不下发前端）

--房间信息

local GameId = 0         --游戏id
local DeskId = 0         --房间id
local DeskUuid = ""      --房间唯一id
local TaxRate = 0        --房间税率

---@type DeskInfo []
local DeskList = {}      --机台列表,和原单人slots结构兼容


local timeout = 900 --15分钟不操作

--玩法脚本
local GAME = PDEFINE.GAME_TYPE
local GAME_LOGIC_MODULES = {
    [GAME.COINS] = "coins",
    [GAME.CRYPTO] = "crypto",
    [GAME.DICE] = "dice",
    [GAME.HILO] = "hilo",
    [GAME.KENO] = "keno",
    [GAME.LIMBO] = "limbo",
    [GAME.MINES] = "mines",
    [GAME.PLINKO] = "plinko",
    [GAME.TOWERS] = "towers",
    [GAME.TRIPLE] = "triple"
}

-- 接口函数组
local CMD = {}

local function srand()
    local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
    seed = seed + skynet.now()
    math.randomseed(seed)
end

srand()

local timer_list = {}     -- 定时器列表
--添加定时器
local function setTimer(uid, name, sec, func, params)
    if not timer_list[uid] then
        timer_list[uid] = {}
    end
    timer_list[uid][name] = skynet.timeout(sec*100, function()
        LOG_DEBUG("onTimer", uid, name)
        func(params)
        timer_list[uid][name] = nil
    end)
end
-- 清理定时器
local function clearTimer(uid, name)
    if timer_list[uid] and timer_list[uid][name] then
        skynet.remove_timeout(timer_list[uid][name])
        timer_list[uid][name] = nil
    end
end
--清理seatid的所有定时器
local function clearAllTimer(uid)
    if timer_list[uid] then
        for name, timer in pairs(timer_list[uid]) do
            skynet.remove_timeout(timer)
            timer_list[uid][name] = nil
        end
    end
end
--查找玩家
local function findUser(uid)
    for _, deskInfo in ipairs(DeskList) do
        if deskInfo.user.uid == uid then
            return deskInfo.user
        end
    end
end
--查找机台
local function findDeskInfo(uid)
    for _, deskInfo in ipairs(DeskList) do
        if deskInfo.user.uid == uid then
            return deskInfo
        end
    end
end
--拷贝机台信息
local function copyDeskInfo(uid)
    local deskInfo = findDeskInfo(uid)
    if deskInfo then
        local tmp = table.copy(deskInfo)
        tmp.user.cluster_info = nil
        if gamelogic and gamelogic.filterDeskInfo then
            gamelogic.filterDeskInfo(tmp)
        end
        return tmp
    end
end
--发送消息
local function sendMsg(user, retobj)
    if user.cluster_info then
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
    end
end
-- 广播给房间里的所有人
local function broadcastRoom(retobj, excludeUid)
    for _, deskInfo in ipairs(DeskList) do
        local user = deskInfo.user
        if (not excludeUid or excludeUid ~= user.uid) then
            sendMsg(deskInfo.user, retobj)
        end
    end
end
--修改金币
local function changeCoin(user, type, coin, deskInfo)
    if coin == 0 then return true end
    local ret = true
    if user.cluster_info then
        LOG_INFO(user.uid.." changeCoin type:", type, 'coin:', coin)
        ret = player_tool.calUserCoin(user.uid, coin, deskInfo.issue, type, deskInfo)
    end
    if ret then
        user.coin = user.coin + coin
    end
    return ret
end
-- 播放走马灯
local function notifyLobby(user, coin)
    sysmarquee.onGameWin(user.playername, GameId, coin, 5)
end
-- 房间税率
local function calcTax(betcoin, wincoin)
    return betUtil.calcTax(betcoin, wincoin, TaxRate)
end
--游戏记录
local function recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    local user = deskInfo.user
    record.betGameLog(deskInfo, user, betcoin, wincoin, settle, tax)
end
--生成投注期号
local function newIssue(deskInfo)
    local shortname = PDEFINE.GAME_SHORT_NAME[GameId] or 'XX'
    local osdate = os.date("%y%m%d")
    deskInfo.no = deskInfo.no + 1
    local number = string.format("%04d", deskInfo.no%10000)
    deskInfo.issue = shortname..osdate..(deskInfo.id)..number
end
--策略策略控制条件
local function getRestriction()
    return stgy:getRestriction()
end
--更新策略数据
local function updateStrategyData(userbet, userwin)
    stgy:update(userbet, userwin)
end
--将玩家数据保存到缓存
local function redisSet(uid, tbl)
    local rediskey = string.format("%s:%s:%s", PDEFINE.REDISKEY.GAME.deskdata, GameId, uid)
    do_redis({"setex", rediskey, cjson.encode(tbl), 30*24*3600}, uid)
end
--从缓存中读取玩家数据
local function redisGet(uid)
    local rediskey = string.format("%s:%s:%s", PDEFINE.REDISKEY.GAME.deskdata, GameId, uid)
    local jsondata = do_redis({"get", rediskey}, uid)
    if jsondata ~= nil then
        return cjson.decode(jsondata)
    end
end
-- 从缓存中删除数据
local function redisDel(uid)
    local rediskey = string.format("%s:%s:%s", PDEFINE.REDISKEY.GAME.deskdata, GameId, uid)
    do_redis({"del", rediskey}, uid)
end

--代理方法
---@class StandaloneAgentDelegate
local delegate = {
    sendMsg = sendMsg,
    broadcastRoom = broadcastRoom,
    findUser = findUser,
    findDeskInfo = findDeskInfo,
    changeCoin = changeCoin,
    notifyLobby = notifyLobby,
    calcTax = calcTax,
    recordGameLog = recordGameLog,
    getRestriction = getRestriction,
    updateStrategyData = updateStrategyData,
    redisSet = redisSet,
    redisGet = redisGet,
    redisDel = redisDel,
    newIssue = newIssue,    --start协议里会自动生成新的期号，如果游戏不走start协议，需要自行调用生成
}

--重置房间
local function resetDesk(force)
    if not force then
        if (#DeskList > 0) then
            return
        end
    end
    pcall(cluster.send, "game", ".dsmgr", "recycleAgent", skynet.self(), DeskId, GameId)
end

local function sysCloseServer(cmd)
    for _, deskInfo in ipairs(DeskList) do
        local user = deskInfo.user
        if user then
            clearAllTimer(user.uid)
            if user.cluster_info then
                local retobj= {
                    code = PDEFINE.RET.SUCCESS,
                    c = cmd,
                    uid = user.uid
                }
                sendMsg(user, retobj)
            end
        end
    end
    resetDesk(true)
end

local function updatePlayerNum()
    local robotnum = math.random(10, 20)
    local playernum = #DeskList + robotnum
    pcall(cluster.send, "master", ".strategymgr", "updateDeskPlayerNum", DeskId, playernum)
end

local function userExit(uid, spcode)
    local user = findUser(uid)
    if not user then return end
    if user.cluster_info then
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", GameId)
    end
    LOG_DEBUG("userExit uid:", user.uid, "spcode:", spcode)
    for i, deskInfo in ipairs(DeskList) do
        if uid == deskInfo.user.uid then
            --移除列表
            table.remove(DeskList, i)
            break
        end
    end
    updatePlayerNum()
end

local function autoKick(uid)
    local user = findUser(uid)
    if not user then return end
    local retobj = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.NOTIFY_KICK,
        uid = uid
    }
    sendMsg(user, retobj)
    userExit(uid, PDEFINE.RET.ERROR.TIMEOUT_KICK_OUT)
end

local function createDeskInfo(cluster_info, playerInfo)
    local user = {
        seatid = 0, --先不分配座位号
        uid = playerInfo.uid,
        playername = playerInfo.playername,
        usericon = playerInfo.usericon,
        coin = playerInfo.coin,
        cluster_info = cluster_info,
        level = playerInfo.level or 1,
        svip =  playerInfo.svip or 0,
        istest = playerInfo.istest,
    }
    local deskInfo = {
        gameid = GameId,
        deskid = DeskId,
        uuid = DeskUuid,
        user = user,
        id = math.random(100000, 999999),
        no = 0,
        conf = {}
    }
    gamelogic.initDeskInfo(deskInfo, delegate)
    return deskInfo
end

-- 创建房间
function CMD.create(source, cluster_info, msg, ip, deskid, newplayercount, gameid)
    msg.deskid = deskid
    DeskId = deskid
    DeskUuid = deskid..os.time()
    GameId = gameid
    TaxRate = msg.taxrate or 0

    local script = GAME_LOGIC_MODULES[GameId]
    if not script then
        LOG_ERROR("game module not exist", GameId)
        return PDEFINE.RET.ERROR.PARAMS_ERROR
    end
    gamelogic = require("standalonegames."..GAME_LOGIC_MODULES[GameId])
    gamelogic.create(GameId)

    local ssid = math.sfloor(msg.ssid) or 0
    stgy:load(ssid, GameId)

    local uid = msg.uid
    if uid and uid > 0 then
        local playerInfo = player_tool.getPlayerInfo(uid)
        if not playerInfo then
            LOG_ERROR("user not exist", uid)
            return PDEFINE.RET.ERROR.USER_NOT_FOUND
        end
        ---@type DeskInfo
        local deskInfo = createDeskInfo(cluster_info, playerInfo)
        table.insert(DeskList, deskInfo)

        setTimer(uid, "autoKick", timeout, autoKick, uid)

        local resp = copyDeskInfo(uid)
        return PDEFINE.RET.SUCCESS, resp
    end

    setTimer(0, "updatePlayerNum", 5, updatePlayerNum)

    local resp = {
        deskid = deskid,
        gameid = GameId,
        uuid = DeskUuid
    }
    return PDEFINE.RET.SUCCESS, resp
end

--spin游戏
function CMD.start(source, msg)
    local uid = msg.uid
    local deskInfo = findDeskInfo(uid)
    if not deskInfo then
        return PDEFINE.RET.SUCCESS, {c=msg.c, code=200, spcode=PDEFINE.RET.ERROR.USER_NOT_FOUND}
    end
    clearTimer(uid, "autoKick")
    newIssue(deskInfo)
    local retobj = gamelogic.start(deskInfo, msg, delegate)
    setTimer(uid, "autoKick", timeout, autoKick, uid)
    return PDEFINE.RET.SUCCESS, retobj
end

-- gameLogicCmd 其他操作
function CMD.gameLogicCmd(source, msg)
    local uid = msg.uid
    local deskInfo = findDeskInfo(uid)
    if not deskInfo then
        return PDEFINE.RET.SUCCESS, {c=msg.c, code=200, spcode=PDEFINE.RET.ERROR.USER_NOT_FOUND}
    end
    local retobj = gamelogic.gameLogicCmd(deskInfo, msg, delegate)
    return PDEFINE.RET.SUCCESS, retobj
end

--进入房间
function CMD.join(source, cluster_info, msg, ip)
    local uid = msg.uid
    local deskid = math.floor(msg.deskid)
    if deskid ~= DeskId then
        LOG_ERROR("deskid: ", deskid, " is not match ==> ", DeskId)
        return PDEFINE.RET.ERROR.DESKID_FAIL
    end
    local ok, playerInfo = pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
    if not ok or not playerInfo then
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    ---@type User|nil
    local user = findUser(uid)
    if user then
        user.cluster_info = cluster_info
        user.coin = playerInfo.coin
    else
        local deskInfo = createDeskInfo(cluster_info, playerInfo)
        table.insert(DeskList, deskInfo)
        setTimer(uid, "autoKick", timeout, autoKick, uid)
    end

    updatePlayerNum()

    local retobj  = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(msg.c)
    retobj.gameid = GameId
    local deskInfo = copyDeskInfo(uid)
    retobj.deskinfo = deskInfo
    if retobj.deskinfo then
        retobj.deskinfo.deskFlag = 1
    end

    return PDEFINE.RET.SUCCESS, retobj
end

-- 退出房间
function CMD.exitG(source,msg)
    local deskInfo = findDeskInfo(msg.uid)
    if deskInfo then
        clearAllTimer(msg.uid)
        userExit(msg.uid, 0)
    end
    return PDEFINE.RET.SUCCESS
end

--用户在线离线
function CMD.offline(source, offline, uid)
    LOG_INFO("CMD.offline", "offline:", offline, "uid:", uid)
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local user = findUser(msg.uid)
    if user then
        local deskInfo = copyDeskInfo(msg.uid)
        return deskInfo
    end
end

--更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, agent)
    LOG_DEBUG("updateUserClusterInfo", uid, " agent:", agent, "gameid:", GameId)
    local user = findUser(uid)
    if user and user.cluster_info then
        user.cluster_info.address = agent
    end
end

--后台API 停服清房
function CMD.apiCloseServer(source,csflag)
    if csflag == true then
        sysCloseServer(PDEFINE.NOTIFY.NOTIFY_SYS_KICK)
    end
end

--解散房间
function CMD.apiKickDesk(source)
    sysCloseServer(PDEFINE.NOTIFY.ALL_GET_OUT)
end

function CMD.reload()
end

--API更新桌子里玩家的金币
function CMD.addCoinInGame(source, uid, coin)
    LOG_DEBUG("addCoinInGame uid:",uid," coin:", coin)
    local user = findUser(uid)
    if user then
        user.coin = user.coin + coin
    end
end

function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

--重载桌子策略
function CMD.reloadStrategy(source)
    stgy:reload()
end

--重载桌子配置
function CMD.reloadSetting(source)
    local ok ,cfg = pcall(cluster.call, "master", ".gamemgr", "getRow", GameId)
    if ok and cfg then
        TaxRate = tonumber(cfg.taxrate) or 0
    end
    LOG_DEBUG("reloadSetting", DeskId, GameId, TaxRate)
end


local counter = 0
skynet.start(function()
    skynet.dispatch("lua", 
        function(session, source, command, ...)
            counter = counter + 1
            if counter > 197 then
                counter = 0
                srand()
            end
            local f = CMD[command]
            local ret
            local param = {...}
            if f then
                cs(
                    function()
                        ret = {f(source, table.unpack(param))}
                    end
                )
            else
                LOG_INFO("undefined cmd", command)
            end
            skynet.retpack(table.unpack(ret))
        end
    )
    collectgarbage("collect")
end)