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
local commonUtil = require "cashslots.common.utils"
local record = require "base.record"
local cs = queue()
local GAME_NAME = "fortunewheel"
local DEBUG = skynet.getenv("DEBUG")
local closeServer = false

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)

---@type BetAgent
local agent = nil  -- 游戏实例

-------------------- 游戏配置 --------------------
local config = {
    Cards = {
        1, 2, 3, 4, 5
    },
    -- 方位数量
    PlaceCount = 5,
    -- 押注方位
    Places = {
        Apple = 1,  -- 苹果
        Kiwifruit = 2,-- 猕猴桃
        Grape = 3,  -- 葡萄
        Banana = 4, -- 香蕉
        Orange = 5, -- 橙子
    },
    --中奖结果，分别表示: 苹果2, 葡萄10, 橙子2, 猕猴桃8, 香蕉2, 苹果5, 葡萄2, 橙子50, 猕猴桃2, 香蕉20
    Results = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
    -- 中奖倍数
    Multiples = {2, 10, 2, 8, 2, 5, 2, 50, 2, 20},
    --中奖结果映射中奖区域
    ResultToPlace = {1, 3, 5, 2, 4, 1, 3, 5, 2, 4},
    --筹码
    Chips = {1, 10, 50, 100, 500, 1000, 5000},
    --游戏状态
    State = {
        Free = 1,   --空闲阶段
        Betting = 2,--押注阶段
        Settle = 3, --结算阶段
    },
    --状态时长（秒）
    Times = {
        FreeTime = 2,
        BettingTime = 20,
        SettleTime = 12,
    }
}

-------------------- 游戏逻辑 --------------------
local gamelogic = {}

function gamelogic.initDesk(deskInfo)
    deskInfo.state = config.State.Free      --初始为空闲时段
    deskInfo.chips = table.copy(config.Chips)
    deskInfo.round = {
        bets = {0, 0, 0, 0, 0},       --各位置押注总额
        chips = {{}, {}, {}, {}, {}},     --各位置筹码数
    }
    for i = 1, config.PlaceCount do
        table.fill(deskInfo.round.chips[i], 0, #(config.Chips))
    end
end

function gamelogic.initUser(user)
    user.round = {
        bets = {0, 0, 0, 0, 0},   --各位置下注额
        totalbet = 0,       --总下注额
        wincoin = 0,        --赢分
        tax = 0,            --税收
    }
end

-- 进入空闲时段
function gamelogic.startFree(broadcast)
    agent:setState(config.State.Free, config.Times.FreeTime)
    local deskInfo = agent:getDeskInfo()
    --重置桌子数据
    table.fill(deskInfo.round.bets, 0)
    for i = 1, #(deskInfo.round.chips) do
        table.fill(deskInfo.round.chips[i], 0)
    end
    --重置玩家数据
    local users = agent:getUsers()
    for _, user in ipairs(users) do
        table.fill(user.round.bets, 0)
        user.round.totalbet = 0
        user.round.wincoin = 0
        user.round.tax = 0
    end
    -- 下一状态时间
    agent:setTimer(config.Times.FreeTime, function ()
        gamelogic.startBet()
    end)
    if broadcast then
        -- 广播前端
        local notify = {
            code = PDEFINE.RET.SUCCESS,
            c = PDEFINE.NOTIFY.BET_STATE_FREE,
            time = config.Times.FreeTime,
            issue = deskInfo.issue,
        }
        --桌上玩家更新
        agent:updateDeskUser()
        notify.users = agent:getDeskUserData()
        for i = 1, #(notify.users) do
            if i > 5 then --只发送5个
                notify.users[i] = nil
            end
        end

        agent:broadcast(cjson.encode(notify))
    end
end

-- 进入押注时段
function gamelogic.startBet()
    agent:setState(config.State.Betting, config.Times.BettingTime)
    local deskInfo = agent:getDeskInfo()
    deskInfo.curround = deskInfo.curround + 1
    -- 下一状态时间
    agent:setTimer(config.Times.BettingTime+2, function ()
        gamelogic.startSettle()
    end)
    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_BETTING,
        time = config.Times.BettingTime,
    }
    agent:broadcast(cjson.encode(notify))

    --机器人开始下注
    agent:satrtAiBet(gamelogic, config, config.Times.BettingTime)
end

function gamelogic.getResult(deskInfo)
    local result = {
        res = 0,
        winplace = 0,
    }
    result.res = betUtil.getRandomIdxByMultiples(config.Multiples)
    result.winplace = config.ResultToPlace[result.res]
    return result
end

--获取策略控制结果
function gamelogic.tryGetRestrictiveResult(deskInfo)
    local restriction = agent:getRestriction()  --0：随机 -1：输 1：赢
    local users = agent:getUsers()
    local result = nil
    for trycnt = 1, 100 do
        result = gamelogic.getResult(deskInfo)
        if restriction == 0 then
            break
        end
        local totalwin = 0  --玩家总赢分
        local totalbet = 0  --玩家总下注
        local wp = result.winplace --赢分区域
        local winMult = config.Multiples[result.res]  --赢分倍数
        for _, user in ipairs(users) do
            if user.cluster_info then
                totalwin = totalwin + user.round.bets[wp] * winMult
                totalbet = totalbet + user.round.totalbet
            end
        end
        if (totalwin == totalbet)
         or (restriction < 0 and totalwin < totalbet)
         or (restriction > 0 and totalwin > totalbet) then
            LOG_DEBUG("restriction", deskInfo.gameid, restriction, totalwin, totalbet)
            break
        end
    end
    return result
end

-- 进入结算阶段
function gamelogic.startSettle()
    agent:setState(config.State.Settle, config.Times.SettleTime)
    local deskInfo = agent:getDeskInfo()

    --结算
    local result = gamelogic.tryGetRestrictiveResult(deskInfo)
    local users = agent:getUsers()
    local wp = result.winplace --赢分区域
    local winMult = config.Multiples[result.res]  --赢分倍数
    local playertotalwin = 0
    local playertotalbet = 0
    for _, user in ipairs(users) do
        user.round.wincoin = 0
        user.round.betinfo = {}
        for p = 1, config.PlaceCount do
            if user.round.bets[p] > 0 then
                local wincoin = 0
                if p == wp then
                    wincoin = user.round.bets[p] * winMult
                end
                user.round.wincoin = user.round.wincoin + wincoin
                table.insert(user.round.betinfo, {p=p, bet=user.round.bets[p], win=wincoin})
            end
        end
        if user.cluster_info and user.istest ~= 1 then
            playertotalbet = playertotalbet + user.round.totalbet
            playertotalwin = playertotalwin + user.round.wincoin
        end
        local tax = betUtil.calcTax(user.round.totalbet, user.round.wincoin, deskInfo.taxrate)
        user.round.wincoin = user.round.wincoin - tax
        user.round.tax = tax
        user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, user.round.wincoin, deskInfo)
        --更新统计
        user.betcoin = user.betcoin + user.round.totalbet
        user.wincoin = user.wincoin + user.round.wincoin
    end
    agent:updateStrategyData(playertotalbet, playertotalwin)
    LOG_INFO(string.format("%s player bet:%.2f win:%.2f, system win:%.2f", GAME_NAME, playertotalbet, playertotalwin, playertotalbet-playertotalwin))

    --游戏记录
    table.insert(deskInfo.records, {res=result.res})
    if #(deskInfo.records) > 12 then
        table.remove(deskInfo.records, 1)
    end

    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_SETTLE,
        time = config.Times.SettleTime,
        result = result,
        users = {},
    }
    --桌上玩家的输赢
    for i, user in ipairs(deskInfo.users) do
        table.insert(notify.users, {
            uid = user.uid,
            seatid = user.seatid,
            wincoin = user.round.wincoin - user.round.totalbet,
            coin = user.coin,
        })
        if i>=5 then  --水果机只发5个
            break
        end
    end
    --自己的输赢
    for _, user in ipairs(users) do
        notify.user = {
            wincoin = user.round.wincoin - user.round.totalbet,
            coin = user.coin,
        }
        user:sendMsg(cjson.encode(notify))
        --游戏记录
        if user.round.totalbet > 0 then
            record.betGameLog(deskInfo, user, user.round.totalbet, user.round.wincoin, result, user.round.tax)
        end
    end

    -- 下一状态时间
    agent:setTimer(config.Times.SettleTime, function ()
        gamelogic.startFree(true)
    end)

    --广播赢钱
    agent:broadcastWinners(config.Times.SettleTime)

    --记录游戏日志
    agent:recordDB(result)

    --保存趋势图
    agent:saveRecords()

    --计算完了，准备开启新一轮
    agent:nextRound()
end

--玩家下注
function gamelogic.bet(msg)
    local chips = msg.chips
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, chips=msg.chips}
    if agent:getState() ~= config.State.Betting then
        ret.spcode = PDEFINE.RET.ERROR.DESK_STATE_ERROR
        return ret
    end
    local user = agent:findUserByUid(msg.uid)
    if not user then
        ret.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return ret
    end
    local totalcoin = 0
    for p = 1, config.PlaceCount do
        local chipcnts = msg.chips[p]
        if not chipcnts or type(chipcnts)~="table" then
            ret.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
            return ret
        end
        for idx, chipcoin in ipairs(config.Chips) do
            chipcnts[idx] = tonumber(chipcnts[idx]) or 0
            if chipcnts[idx] < 0 then
                ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
                return ret
            end
            totalcoin = totalcoin + chipcnts[idx] * chipcoin
        end
    end
    if totalcoin <= 0 then
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end
    if user.coin < totalcoin then
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    local deskInfo = agent:getDeskInfo()
    if not user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -totalcoin, deskInfo) then
        LOG_INFO("user change coin fail", msg.uid, -totalcoin)
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    for p = 1, config.PlaceCount do
        local chipcnts = chips[p]
        local coin = 0
        for idx, chipcoin in ipairs(config.Chips) do
            local chipcnt = chipcnts[idx] or 0
            coin = coin + chipcnt * chipcoin
            deskInfo.round.chips[p][idx] = deskInfo.round.chips[p][idx] + chipcnt
        end
        deskInfo.round.bets[p] = deskInfo.round.bets[p] + coin
        user.round.bets[p] = user.round.bets[p] + coin
        user.round.totalbet = user.round.totalbet + coin
    end
    ret.bets = user.round.bets

    --广播通知下注
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_USER_BET,
        uid = msg.uid,
        chips = msg.chips,
    }
    if user.seatid <= 0 then
        notify.uid = 0
    end
    agent:broadcast(cjson.encode(notify), msg.uid)

    return ret
end

function gamelogic.autoBet(user)
    if user.cluster_info then return end

    --位置概率
    local multiples = {7, 10, 12, 22, 52}
    local placeProb = {}
    for i, mult in ipairs(multiples) do
        table.insert(placeProb, {weight=math.floor(10000/mult+0.5)})
    end
    --筹码概率
    local chipProb = {}
    for i = 1, #config.Chips do
        local val = #config.Chips-i+1
        table.insert(chipProb, {weight = val * val})
    end

    --最多可下注区域
    local maxplacecnt = math.min(5, config.PlaceCount - 1)
    --下注区域个数
    local placecnt = math.random(1, maxplacecnt)

    local msg =   {
        c =   37,
        uid = user.uid,
    }
    msg.chips = {}
    for i = 1, config.PlaceCount do
        local chipcnt = {}
        table.fill(chipcnt, 0, #config.Chips)
        table.insert(msg.chips, chipcnt)
    end

    local betcoin = 0
    for i = 1, placecnt do
        local placeidx = commonUtil.randByWeight(placeProb)
        local cnt = math.random(2, 5)
        for j = 1, cnt do
            local chipidx = commonUtil.randByWeight(chipProb)
            msg.chips[placeidx][chipidx] = msg.chips[placeidx][chipidx] + 1
        end
    end
    if user.coin < betcoin then
        user.coin = betcoin
    end
    gamelogic.bet(msg)
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
    gamelogic.startFree(false)
    --加入机器人
    skynet.timeout(math.random(100,200), function()
        agent:aiJoin()
    end)
    -- 获取桌子回复
    local ret = agent:getDeskInfoData(uid)
    return warpResp(ret)
end

-- agent退出
function CMD.exit()
    collectgarbage("collect")
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
协议说明
  结算信息
    local result = {
        res = 2,  --中奖结果
        winplcae = 1,--中奖区域
    }

  其他参考龙虎斗 drgonvstiger
]]
