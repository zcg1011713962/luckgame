local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local queue     = require "skynet.queue"
local snax = require "snax"
local player_tool = require "base.player_tool"
local BetUser = require "betgame.betuser"
local BetAgent = require "betgame.betagent"
local betUtil = require "betgame.betutils"
local baseUtil = require "base.utils"
local commonUtils = require "cashslots.common.utils"
local record = require "base.record"
local cs = queue()
local GAME_NAME = "crash"
local DEBUG = skynet.getenv("DEBUG")
local closeServer = false

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)

---@type BetAgent
local agent = nil  -- 游戏实例

-------------------- 游戏配置 --------------------
local config = {
    --筹码
    Chips = {1, 10, 50, 100, 500, 1000, 5000},
    --游戏状态
    State = {
        --Free = 1,   --空闲阶段
        Betting = 2,  --押注阶段
        Play = 3,     --游戏阶段
    },
    --状态时长（秒）
    Times = {
        BettingTime = 18,--押注阶段时长
        WaitTime = 4,   --游戏结束后等待下一局开始的时间
    },
    --飞行二次函数系数(时间与倍数关系)  mult = a*t*t + b*t + c
    Quad = {
        a = 0.0052,
        b = 0.025,
        c = 1
    },
    -- 结果权重
    MultWeight = {
        {min=100, max=150,  weight=360},
        {min=151, max=200,  weight=210},
        {min=201, max=300,  weight=150},
        {min=301, max=400,  weight=100},
        {min=401, max=600,  weight=75},
        {min=601, max=900,  weight=50},
        {min=901, max=1200, weight=25},
        {min=1201, max=1600, weight=12},
        {min=1601, max=2000, weight=8},
    },
}

--获取时间（精度0.01秒）
local function getTime()
    return skynet.now()/100
end

-------------------- 游戏逻辑 --------------------
local gamelogic = {}

gamelogic.autofleeusers = {} --自动逃离的玩家列表

function gamelogic.initDesk(deskInfo)
    deskInfo.state = config.State.Betting      --初始为下注时段
    deskInfo.chips = table.copy(config.Chips)
    deskInfo.quad = table.copy(config.Quad)
    deskInfo.round = {
        bets = {},      --押注列表
        launchtime = 0, --发射时间
        curtime = 0,    --当前时间
        crash = 0,      --是否爆炸
        mult = 1,       --最终倍数
    }
end

function gamelogic.initUser(user)
    user.round = {
        betcoin = 0,    --下注额
        wincoin = 0,    --赢分
        flee = 0,       --逃离倍数
        cashout = 0,    --是否已提取
        tax = 0,            --税收
    }
end

-- 进入押注时段
function gamelogic.startBet(broadcast)
    LOG_INFO("startBet")
    agent:setState(config.State.Betting, config.Times.BettingTime)
    local deskInfo = agent:getDeskInfo()
    --重置桌子数据
    deskInfo.round.bets = {}
    deskInfo.round.launchtime = 0
    deskInfo.round.curtime = 0
    deskInfo.round.crash = 0
    deskInfo.round.mult = 1
    --重置玩家数据
    local users = agent:getUsers()
    for _, user in ipairs(users) do
        user.round.betcoin = 0
        user.round.wincoin = 0
        user.round.flee = 0
        user.round.cashout = 0
    end

    deskInfo.curround = deskInfo.curround + 1
    gamelogic.restriction = agent:getRestriction()
    gamelogic.playertotalbet = 0
    gamelogic.playertotalwin = 0
    -- 下一状态时间
    agent:setTimer(config.Times.BettingTime+1, function ()
        gamelogic.startPlay()
    end)

    if broadcast then
        -- 广播前端
        local notify = {
            code = PDEFINE.RET.SUCCESS,
            c = PDEFINE.NOTIFY.BET_STATE_BETTING,
            time = config.Times.BettingTime,
            issue = deskInfo.issue,
        }
        agent:broadcast(cjson.encode(notify))
    end

    --机器人开始下注
    agent:satrtAiBet(gamelogic, config, config.Times.BettingTime)
end

--机器人自动押注
function gamelogic.autoBet(user)
    if user.cluster_info then return end
    if math.random()>0.6 then return end  --减少一些，防止名字重叠
    --筹码概率
    local chipProb = {}
    for i = 1, #config.Chips do
        local val = #config.Chips-i+1
        table.insert(chipProb, {weight = val * val})
    end
    local chipidx = commonUtils.randByWeight(chipProb)
    local betcoin = config.Chips[chipidx]
    local flee = 1.2
    local rand = math.random()
    if rand < 0.6 then
        flee = math.random(120, 240) / 100
    elseif rand < 0.9 then
        flee = math.random(180, 360) / 100
    else
        flee = math.random(320, 640) / 100
    end
    if math.random() < 0.8 then
        flee = math.floor(flee*10+0.5)/10
    end

    local msg =   {
        c =   37,
        uid = user.uid,
        betcoin = betcoin,
        flee = flee,
    }
    if user.coin < betcoin then
        user.coin = betcoin
    end
    gamelogic.bet(msg)
end

--计算预期倍数
local function getExpectMult()
    local _, rs = commonUtils.randByWeight(config.MultWeight)
    return math.random(rs.min, rs.max) / 100
end

--通过倍数计算时间
local function calcTimeByMult(mult)
    local c = config.Quad.c - mult
    local b = config.Quad.b
    local a = config.Quad.a
    local t = (math.sqrt(b*b-4*a*c) - b) / (2 * a)
    return t
end

--通过时间计算倍数
local function calcMultByTime(t)
    local quad = config.Quad
    return quad.a * t * t + quad.b * t + quad.c
end

--进入游戏进行时段
function gamelogic.startPlay()
    LOG_INFO("startPlay")
    agent:setState(config.State.Play)
    local deskInfo = agent:getDeskInfo()
    --游戏开始
    deskInfo.round.launchtime = getTime()
    deskInfo.round.mult = 1
    deskInfo.round.crash = 0
    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_PALY,
        launchtime = deskInfo.round.launchtime
    }
    agent:broadcast(cjson.encode(notify))
    --预期倍数
    local expectMult = getExpectMult()
    --预期飞行时间
    local expectTime = calcTimeByMult(expectMult)
    gamelogic.expectTime = expectTime
    gamelogic.expectMult = expectMult
end

-- 进入游戏结算阶段
function gamelogic.startSettle()
    local deskInfo = agent:getDeskInfo()
    if deskInfo.round.crash > 0 then return end

    deskInfo.round.crash = 1
    deskInfo.round.mult = gamelogic.expectMult
    --自动逃离玩家列表清空
    gamelogic.autofleeusers = {}

    local playertotalwin = gamelogic.playertotalwin
    local playertotalbet = gamelogic.playertotalbet
    agent:updateStrategyData(playertotalbet, playertotalwin)
    LOG_INFO(string.format("%s player bet:%.2f win:%.2f, system win:%.2f", GAME_NAME, playertotalbet, playertotalwin, playertotalbet-playertotalwin))

    --游戏结果
    local result = {
        mult = deskInfo.round.mult
    }
    LOG_INFO(string.format("yrp mult = %s",deskInfo.round.mult))

    --游戏记录
    table.insert(deskInfo.records, result.mult)
    if #(deskInfo.records) > 80 then
        table.remove(deskInfo.records, 1)
    end

    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_SETTLE,
        result = result,
    }
    local userbet = false
    local users = agent:getUsers()
    for _, user in ipairs(users) do
        notify.user = {
            wincoin = user.round.wincoin,
            coin = user.coin,
        }
        user:sendMsg(cjson.encode(notify))
        --游戏记录
        if user.round.betcoin > 0 then
            record.betGameLog(deskInfo, user, user.round.betcoin, user.round.wincoin, result, user.round.tax)
            if user.cluster_info then
                userbet = true
            end
        end
    end

    -- 等待4秒后进入下一状态时间
    agent:setTimer(config.Times.WaitTime, function ()
        gamelogic.startBet(true)
    end)

    --记录游戏日志
    agent:recordDB(result, userbet)

    --保存趋势图
    agent:saveRecords()

    --计算完了，准备开启新一轮
    agent:nextRound()
end

--玩家下注
function gamelogic.bet(msg)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin, flee=msg.flee}
    if agent:getState() ~= config.State.Betting then
        ret.spcode = PDEFINE.RET.ERROR.DESK_STATE_ERROR
        return ret
    end
    local user = agent:findUserByUid(msg.uid)
    if not user then
        ret.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return ret
    end
    local totalcoin = tonumber(msg.betcoin) or 0
    local flee = tonumber(msg.flee) or 0
    if totalcoin <= 0 or (flee ~= 0 and flee < 1.01) then
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end
    if user.coin < totalcoin then
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    if user.round.betcoin > 0 then
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        ret.errmsg = "already bet"
        return ret
    end
    local deskInfo = agent:getDeskInfo()
    if not user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -totalcoin, deskInfo) then
        LOG_INFO("user change coin fail", msg.uid, -totalcoin)
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    user.round.betcoin = totalcoin
    user.round.flee = flee
    if user.cluster_info and user.istest ~= 1 then
        gamelogic.playertotalbet = gamelogic.playertotalbet + totalcoin
    end
    --加入自动逃离的队列
    if flee > 1 then
        if not table.contain(gamelogic.autofleeusers, user) then
            table.insert(gamelogic.autofleeusers, user)
        end
    end

    return ret
end

--玩家取现
function gamelogic.cashout(msg)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, wincoin=0, mult=0}
    if agent:getState() ~= config.State.Play then
        ret.spcode = PDEFINE.RET.ERROR.DESK_STATE_ERROR
        return ret
    end
    local user = agent:findUserByUid(msg.uid)
    if not user then
        ret.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return ret
    end
    if user.round.cashout > 0 then
        ret.spcode = PDEFINE.RET.ERROR.TIMEOUT
        ret.errmsg = "already cashout"
        return ret
    end
    if user.round.betcoin <= 0 then
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        ret.errmsg = "no bet"
        return ret
    end
    local deskInfo = agent:getDeskInfo()
    local elapsed = getTime() - deskInfo.round.launchtime
    if elapsed > gamelogic.expectTime or deskInfo.round.crash > 0 then
        ret.spcode = PDEFINE.RET.ERROR.TIMEOUT
        ret.errmsg = "timeout"
        return ret
    end
    local mult = calcMultByTime(elapsed)
    mult = math.floor(mult*100) / 100
    local wincoin = mult * user.round.betcoin
    if not gamelogic.checkRestriction(wincoin, mult) then
        ret.spcode = PDEFINE.RET.ERROR.TIMEOUT
        ret.errmsg = "timeout"
        return ret
    end

    user.round.cashout = 1
    user.round.wincoin = wincoin
    local tax = betUtil.calcTax(user.round.betcoin, user.round.wincoin, deskInfo.taxrate)
    user.round.wincoin = user.round.wincoin - tax
    user.round.tax = tax
    user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, user.round.wincoin, deskInfo)
    if user.cluster_info and user.round.wincoin > user.round.betcoin then
        user:notifyLobby(user.round.wincoin - user.round.betcoin, deskInfo.gameid, 2)
    end
    if user.cluster_info and user.istest ~= 1 then
        gamelogic.playertotalwin = gamelogic.playertotalwin + user.round.wincoin
    end

    --移除出自动逃离的队列
    local idx = table.findIdx(gamelogic.autofleeusers, user)
    if idx > 0 then
        table.remove(gamelogic.autofleeusers, idx)
    end

    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_USER_CASHOUT,
        uid = user.uid,
        playername = user.playername,
        mult = mult
    }
    agent:broadcast(cjson.encode(notify), user.uid)

    ret.wincoin = user.round.wincoin
    ret.mult = mult

    return ret
end

--自动取现
function gamelogic.autocashout(user)
    if user.round.cashout > 0 then
        return
    end
    if agent:getState() ~= config.State.Play then
        return
    end
    local deskInfo = agent:getDeskInfo()
    if deskInfo.round.crash > 0 then
        return
    end
    local mult = user.round.flee
    user.round.cashout = 1
    user.round.wincoin = mult * user.round.betcoin
    local tax = betUtil.calcTax(user.round.betcoin, user.round.wincoin, deskInfo.taxrate)
    user.round.wincoin = user.round.wincoin - tax
    user.round.tax = tax
    user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, user.round.wincoin, deskInfo)
    if user.cluster_info and user.round.wincoin > user.round.betcoin then
        user:notifyLobby(user.round.wincoin - user.round.betcoin, deskInfo.gameid, 2)
    end
    if user.cluster_info and user.istest ~= 1 then
        gamelogic.playertotalwin = gamelogic.playertotalwin + user.round.wincoin
    end

    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_USER_CASHOUT,
        uid = user.uid,
        playername = user.playername,
        mult = mult,
        wincoin = user.round.wincoin
    }
    agent:broadcast(cjson.encode(notify))
end

--添加额外的桌子信息
function gamelogic.additionDeskData(desk)
    if desk.round then
        --告诉前端当前时间，前端用curtime-launchtime得到飞行时间
        desk.round.curtime = getTime()
    end
end

--赔率控制
function gamelogic.checkRestriction(win, mult)
    if gamelogic.restriction < 0 and gamelogic.playertotalwin + win >= gamelogic.playertotalbet then
        LOG_DEBUG("crash restriction:", gamelogic.restriction, gamelogic.playertotalwin, gamelogic.playertotalbet)
        --提前进入结算
        gamelogic.expectMult = mult - 0.01 * math.random(1,3)
        gamelogic.startSettle()
        return false
    end
    return true
end

function gamelogic.update(dt)
    if agent:getState() ~= config.State.Play then
        return
    end
    local deskInfo = agent:getDeskInfo()
    if deskInfo.round.crash > 0 then
        return
    end
    local elapsed = getTime() - deskInfo.round.launchtime
    if elapsed >= gamelogic.expectTime then --结束
        gamelogic.startSettle()
        return
    end
    local mult = calcMultByTime(elapsed)
    local size = #(gamelogic.autofleeusers)
    for i = size, 1, -1 do
        local user = gamelogic.autofleeusers[i]
        if mult >= user.round.flee then
            local wincoin = user.round.flee * user.round.betcoin
            if not gamelogic.checkRestriction(wincoin, user.round.flee) then
                break
            end
            gamelogic.autocashout(user)
            table.remove(gamelogic.autofleeusers, i)
        end
    end
end

local game_running = false

local function threadfunc(interval)
    LOG_DEBUG("thread start")
    local dt = interval/100.0
    while game_running do
        xpcall(gamelogic.update,
            function(errmsg)
                print(debug.traceback(tostring(errmsg)))
            end,
            dt)
        skynet.sleep(interval)
    end
    LOG_DEBUG("thread end")
end


-------------------- 游戏接口 --------------------
local CMD = {}

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

-- 玩家下注
function CMD.bet(source, msg)
    local ret = gamelogic.bet(msg)
    return warpResp(ret)
end

-- 玩家取现
function CMD.cashout(source, msg)
    local ret = gamelogic.cashout(msg)
    return warpResp(ret)
end

--获取玩家列表
function CMD.getUserList(source, msg)
    local ret = agent:getUserList(msg)
    return warpResp(ret)
end

--获取游戏记录
function CMD.getRecords(source, msg)
    local ret = agent:getRecords(msg)
    return warpResp(ret)
end

-- 创建房间
function CMD.create(source, cluster_info, msg, ip, deskid, newplayercount, gameid)
    local uid = math.floor(msg.uid)
    -- 实例化游戏
    agent = BetAgent.new(GAME_NAME, gameid, deskid)
    -- 创建房间
    local err = agent:createRoom(msg, deskid, gameid, cluster_info, gamelogic)
    if err then
        return err
    end
    --进入空闲阶段
    gamelogic.startBet(false)
    --加入机器人
    skynet.timeout(math.random(100,200), function()
        agent:aiJoin()
    end)
    --启动线程
    if not game_running then
        game_running = true
        skynet.fork(threadfunc, 2)
    end

    -- 获取桌子回复
    local ret = agent:getDeskInfoData(uid)
    return warpResp(ret)
end

-- agent退出
function CMD.exit()
    collectgarbage("collect")
    game_running = false
    skynet.exit()
end

-- 自动加入机器人
function CMD.aiJoin(source, aiUser)
    return agent:aiJoin(aiUser)
end

-- 退出房间
function CMD.exitG(source, msg)
    local ret = agent:exitG(msg)
    return warpResp(ret)
end

-- 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, _agent)
    agent:updateUserAgent(uid, _agent)
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    return agent:getDeskInfoData(msg.uid)
end

-- 用户在线离线
function CMD.offline(source, offline, uid)
    agent:offline(offline, uid)
end

-- 通知用户比赛结束
function CMD.updateRaceStatus(source, msg)
    return agent:updateRaceStatus(msg)
end

function CMD.setPlayerExit(source, uid)
    return agent:setPlayerExit(uid)
end

-- 加入房间
function CMD.join(source, cluster_info, msg, ip)
    return cs(function()
        return agent:joinRoom(msg, cluster_info)
    end)
end

-- 发送聊天信息
function CMD.sendChat(source, msg)
    agent:sendChat(msg)
    return PDEFINE.RET.SUCCESS
end

-- 更新玩家信息
function CMD.updateUserInfo(source, uid)
    agent:updateUserInfo(uid)
end

-- API更新桌子里玩家的金币
function CMD.addCoinInGame(source, uid, coin, diamond)
    agent:addCoinInGame(uid, coin, diamond)
end

-- api取牌桌信息
function CMD.apiGetDeskInfo(source,msg)
    return agent:getDeskInfoData()
end

-- api停服清房
function CMD.apiCloseServer(source,csflag)
    closeServer = csflag
end

-- api解散房间
function CMD.apiKickDesk(source)
    agent:apiKickDesk()
end

-- 更新桌子策略
function CMD.reloadStrategy(source)
    agent:reloadStrategy()
end

-- 更新游戏配置
function CMD.reloadSetting(source)
    agent:reloadSetting()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.retpack(f(source, ...))
    end)

    collectgarbage("collect")
end)


--[[
--桌子状态
    State = {
        Betting = 2,  --押注阶段
        Play = 3,     --游戏阶段
    },
--桌子信息
--deskInfo增加字段
    {
        quad = {  --飞行二次函数系数(时间与倍数关系)  mult = a*t*t + b*t + c
            a = 0.0052,
            b = 0.025,
            c = 1
        },
        round = {
            bets = {},      --押注列表
            launchtime = 0, --发射时间
            curtime = 0,    --当前时间
            crash = 0,      --是否爆炸
            mult = 1,       --最终倍数
        }
    }

--开始游戏（火箭起飞）
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_PALY,
        launchtime = 154.54 --发射时间戳（秒）
    }

--游戏结束（火箭爆炸）
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_SETTLE,
        result = {mult=1.55}, --最终倍数
    }

--交互类
    --玩家下注(C->S)
    {
        c = 37,
        uid = uid,
        betcoin = 10,   --押注额（点击Guess后一把押定，不能追加）
        flee = 120, --逃走值（x100）
    }
    --返回
    {
        c = 37,
        spcode = 0, --spcode不为0表示下注失败，前端从桌面移除筹码即可
        uid = uid,
        betcoin = 10,   --押注额
        flee = 1.15, --逃走值
    }

    --玩家提取(C->S)
    {
        c = 81,
        uid = uid,
    }
    --返回
    {
        c = 81,
        spcode = 0, --spcode==0表示提取成功，spcode==1表示提取失败，火箭已经爆炸
        uid = uid,
        wincoin = 100,      --赢得金币
        mult = 1.5,         --倍数
    }
]]

--[[
local testcase = {1.07, 1.18, 1.53, 3.58, 6.43, 12.16, 17.5}
for _, mult in ipairs(testcase) do
    print(mult, calExpectTime(mult))
end
]]
