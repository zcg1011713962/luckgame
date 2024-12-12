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
local record = require "base.record"
local cs = queue()
local GAME_NAME = "doubleroll"
local DEBUG = skynet.getenv("DEBUG")
local closeServer = false

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)

---@type BetAgent
local agent = nil  -- 游戏实例

-------------------- 游戏配置 --------------------
local config = {
    -- 中奖数字
    Cards = {
        1, 14, 2, 13, 3, 12, 4, 0, 11, 5, 10, 6, 9, 7, 8
    },
    -- 中奖颜色
    Colors = {
        1, 2, 1, 2, 1, 2, 1, 3, 2, 1, 2, 1, 2, 1, 2
    },
    -- 方位数量
    PlaceCount = 3,
    -- 押注方位
    Places = {
        RED = 1,     --红
        BLACK = 2,   --黑
        GREEN = 3    --绿
    },
    -- 方位倍数
    Multiples = {2, 2, 14},
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
        FreeTime = 3,
        BettingTime = 15,
        SettleTime = 5,
    }
}

-------------------- 游戏逻辑 --------------------
local gamelogic = {}

function gamelogic.initDesk(deskInfo)
    deskInfo.state = config.State.Free      --初始为空闲时段
    deskInfo.chips = table.copy(config.Chips)
    deskInfo.round = {
        bets = {0, 0, 0},       --各位置押注总额
    }
end

function gamelogic.initUser(user)
    user.round = {
        bets = {0, 0, 0},   --各位置下注额
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

        agent:broadcast(cjson.encode(notify))
    end
end

-- 进入押注时段
function gamelogic.startBet()
    agent:setState(config.State.Betting, config.Times.BettingTime)
    local deskInfo = agent:getDeskInfo()
    deskInfo.curround = deskInfo.curround + 1
    -- 下一状态时间
    agent:setTimer(config.Times.BettingTime+1, function ()
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
    local idx = math.random(#config.Cards)
    local result = {
        card = config.Cards[idx],   --开奖牌
        res = config.Colors[idx],   --开奖结果(颜色)
    }
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
        local wp = result.res --赢分区域
        for _, user in ipairs(users) do
            if user.cluster_info then
                totalwin = totalwin + user.round.bets[wp] * config.Multiples[wp]
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
    -- 下一状态时间
    agent:setTimer(config.Times.SettleTime, function ()
        gamelogic.startFree(true)
    end)

    --结算
    local result = gamelogic.tryGetRestrictiveResult(deskInfo)
    local users = agent:getUsers()
    local wp = result.res --赢分区域
    local playertotalwin = 0
    local playertotalbet = 0
    for _, user in ipairs(users) do
        user.round.wincoin = 0
        user.round.betinfo = {}
        for p = 1, config.PlaceCount do
            if user.round.bets[p] > 0 then
                local wincoin = 0
                if p == wp then
                    wincoin = user.round.bets[p] * config.Multiples[p]
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
    table.insert(deskInfo.records, result)
    if #(deskInfo.records) > 80 then
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
    for _, user in ipairs(deskInfo.users) do
        table.insert(notify.users, {
            uid = user.uid,
            seatid = user.seatid,
            wincoin = user.round.wincoin - user.round.totalbet,
            coin = user.coin,
        })
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
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin, place=msg.place}
    if agent:getState() ~= config.State.Betting then
        ret.spcode = PDEFINE.RET.ERROR.DESK_STATE_ERROR
        return ret
    end
    local user = agent:findUserByUid(msg.uid)
    if not user then
        ret.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return ret
    end
    if user.round.totalbet > 0 then --只能下一个方位
        ret.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return ret
    end
    local betcoin = math.sfloor(msg.betcoin) or 0
    local p = tonumber(msg.place) or 0
    if betcoin <= 0 or (p~=1 and p~=2 and p~=3) then
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end
    if user.coin < betcoin then
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    local deskInfo = agent:getDeskInfo()
    if not user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -betcoin, deskInfo) then
        LOG_INFO("user change coin fail", msg.uid, -betcoin)
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end

    deskInfo.round.bets[p] = deskInfo.round.bets[p] + betcoin
    user.round.bets[p] = user.round.bets[p] + betcoin
    user.round.totalbet = user.round.totalbet + betcoin

    ret.bets = user.round.bets

    --广播通知下注
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_USER_BET,
        uid = msg.uid,
        place = msg.place,
        betcoin = betcoin,
    }
    if user.seatid <= 0 then
        notify.uid = 0
    end
    agent:broadcast(cjson.encode(notify), msg.uid)

    return ret
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
--协议说明
    deskInfo:
    {
        chips = {10, 50, 100, 500, 1000, 5000, 10000},  --筹码列表
        round:{
            bets = {0, 1000, 100},       --桌子各位置押注总额
        },
        state = 1,  --桌子状态(1:空闲，2：押注，3：结算)
        time = 5, --当前状态倒计时
        users = {}, --桌上6个玩家的列表
        user = {    --我自己的信息
            coin = 1000,
            round = {
                bets = {100, 1000, 100}, --玩家各区域当前下注总额
                totalbet = 0,       --当前轮次总下注额
                wincoin = 0,        --当前轮次总赢分
            }
        },
        records = {}, --记录列表
        playercnt = 10, --房间玩家数
    }

--通知类：
     --空闲阶段
    {
        c = BET_STATE_FREE(128000),   
        time = 5,
        users = {}, --桌上6个玩家的列表
    }
    --下注阶段
    {
        c = BET_STATE_BETTING(128001), 
        time = 15,
    }
    --结算阶段
    {
        c = BET_STATE_SETTLE(128002),  
        time = 10,
        result = {
            card = 1,   --开出的数字
            res = 3,  --1：红 2：黑 3：绿
        },
        user = {    --我自己的信息
            coin = 1000,
            wincoin = 100,
        }
    }
    --其他玩家下注(如果uid>0，说明是桌上玩家，从玩家头像飞金币； 如果uid=0，说明是列表里的玩家，从列表处飞金币，列表里的玩家每1秒同步一次，因此收到消息后在一秒内分多次飞金币)     
    {
        c = BET_USER_BET(128003),
        uid = uid,
        betcoin = 10,   --下注金额
        place = 1,  --下注区域
    }

--交互类
    --玩家下注(C->S) 不要太频繁，可以等玩家点完几次后再一次性上传
    {
        c = 37,
        uid = uid,
        betcoin = 10,   --下注金额
        place = 1,  --下注区域
    }
    --返回
    {
        c = 37,
        spcode = 0, --spcode不为0表示下注失败，前端从桌面移除筹码即可
        uid = uid,
        betcoin = 10,   --下注金额
        place = 1,  --下注区域
        bets = {100,200,100} --玩家各区域当前下注总额，spcode==0时带下来
    }
]]
