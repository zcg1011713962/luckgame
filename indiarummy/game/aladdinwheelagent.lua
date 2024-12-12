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
local commonUtil = require "cashslots.common.utils"
local record = require "base.record"
local cs = queue()
local GAME_NAME = "aladdinwheel"
local DEBUG = skynet.getenv("DEBUG")
local closeServer = false

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)

---@type BetAgent
local agent = nil  -- 游戏实例
local biddingAddTime =2
local rankUserMap = {}  -- 存放用户信息，比如名称，头像，id
local rankCache = nil  -- 排行榜缓存

local config = {
    Cards = {
        1, 2, 3, 4, 5
    },
    -- 方位数量
    PlaceCount = 8,
    -- 转盘图标
    Places = {
        Lantern = 0,  -- 神灯
        People = 1,  -- 人物
        Monkey = 2,-- 猴子
        Carpet = 3,  -- 飞毯
        Diamond = 4, -- 宝石
        Cup = 5,  -- 奖杯
        Key = 6, -- 钥匙
        Helmet = 7,  -- 头盔
        Tiger = 8,  -- 老虎
    },
    --中奖结果
    Results = {
        -- 神灯, 老虎*5, 奖杯*2, 头盔*10, 奖杯*10, 人物*50, 人物*120, 老虎*5, 老虎*2, 钥匙*10, 宝石*20, 宝石*2 
        0, 8, 5, 7, 5, 1, 1, 8, 8, 6, 4, 4, 
        -- 神灯, 老虎*5, 头盔*2, 头盔*10, 奖品*10, 猴子*2, 猴子*40, 老虎*5, 钥匙*2, 钥匙*10, 飞毯*30, 飞毯*2
        0, 8, 7, 7, 5, 2, 2, 8, 6, 6, 3, 3
    },
    -- 两行第一位为神灯，中神灯会给予中3个图标的记录，所以神灯的倍数可适当提高
    LanternPos = {1, 13},
    --! 这个数值可以调
    -- 中奖倍数
    Multiples = {
        2, 5, 2, 10, 10, 50, 120, 5, 2, 10, 20, 2,
        2, 5, 2, 10, 10, 2,  40,  5, 2, 10, 30, 2
    },

    --概率倍数
    ProbabilityWeight = {
        6, 25, 6, 30, 30, 100, 240, 25, 10, 30, 40, 4,
        6, 25, 6, 30, 30, 4,   80,  25, 6,  30, 60, 4 
    },

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
        SettleTime = 11,
        ExtraTime = 8,  -- 碰到神灯，多延长的时间
    },
    -- 中了神灯之后，多出的中奖次数
    LanternCnt = {3,4},
    RecordType = {
        Common = 1,  -- 普通
        Lantern = 2,  -- 神灯
        Triple = 3,  -- 10倍三连中
        Tiger = 4, -- 老虎*4
        Train3 = 5, -- 火车*3
        Train4 = 6, -- 火车*4
        Train5 = 7, -- 火车*5
        Clover = 8 -- 四叶草
    },
}

-- 中到神灯后，中特殊图标的概率
config.LanternWeight = {
    {type=config.RecordType.Lantern, weight=100},
    {type=config.RecordType.Triple, idxs={4,5,10,16,17,22}, weight=10},
    {type=config.RecordType.Tiger, idxs={2, 8, 14, 20}, weight=10},
    {type=config.RecordType.Train3, weight=10},
    {type=config.RecordType.Train4, weight=5},
    {type=config.RecordType.Train5, weight=2},
    {type=config.RecordType.Clover, weight=0},  -- 四叶草还不知道怎么出
}

-------------------- 游戏逻辑 --------------------

local gamelogic = {}

function gamelogic.initDesk(deskInfo)
    deskInfo.state = config.State.Free      --初始为空闲时段
    deskInfo.chips = table.copy(config.Chips)
    deskInfo.round = {
        bets = {0, 0, 0, 0, 0, 0, 0, 0},       --各位置押注总额
        chips = {{}, {}, {}, {}, {}, {}, {}, {}},     --各位置筹码数
    }
    for i = 1, config.PlaceCount do
        table.fill(deskInfo.round.chips[i], 0, #(config.Chips))
    end
end

function gamelogic.initUser(user)
    user.round = {
        bets = {0, 0, 0, 0, 0, 0, 0, 0},   --各位置下注额
        totalbet = 0,       --总下注额
        wincoin = 0,        --赢分
        tax = 0,            --税收
    }
end

-- 获取排行榜redis_key
function gamelogic.getRankRedisKey(yestoday)
    local rediskey = PDEFINE.REDISKEY.RANK_SETTLE.GAME_BET_COIN..agent.gameid
    local now = os.time()
    if yestoday then
        local day = os.date("%Y%m%d", now-86400)
        return rediskey..":"..day
    else
        local day = os.date("%Y%m%d",now)
        return rediskey..":"..day
    end
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
        res = {},
        win = {},  -- 位置对应的倍率
        sp = 0,  -- 是否显示神灯
        op1 = 0,  -- 特效类型1
        op2 = 0,  -- 特效类型2
    }
    local res = betUtil.getRandomIdxByMultiplesWithCnt(config.ProbabilityWeight, 1)
    -- 如果中了神灯，则再次给3次机会
    if table.contain(config.LanternPos, res) then
        result.sp = math.random() <= 0.3 and 1 or 0
        if result.sp == 1 then
            result.op1 = math.random() <= 0.5 and 1 or 0
            result.op2 = math.random() <= 0.5 and 1 or 0
        end
        local mults = table.copy(config.ProbabilityWeight)
        for _, idx in ipairs(config.LanternPos) do
            mults[idx] = 0
        end
        -- 根据概率来中第二轮图标
        local res2
        local _, lanternItem = randByWeight(config.LanternWeight)
        if lanternItem and lanternItem.type ~= config.RecordType.Lantern then
            local trainLen = nil
            -- 中老虎
            if lanternItem.type == config.RecordType.Tiger then
                res2 = table.copy(lanternItem.idxs)
            elseif lanternItem.type == config.RecordType.Triple then
                local randIdxs = genRandIdxs(#lanternItem.idxs, 3)
                for _, idx in ipairs(randIdxs) do
                    if not res2 then
                        res2 = {}
                    end
                    table.insert(res2, lanternItem.idxs[idx])
                end
            elseif lanternItem.type == config.RecordType.Train3 then
                trainLen = 3
            elseif lanternItem.type == config.RecordType.Train4 then
                trainLen = 4
            elseif lanternItem.type == config.RecordType.Train5 then
                trainLen = 5
            end
            -- 中火车
            if trainLen then
                res2 = {}
                for i = 1, trainLen, 1 do
                    table.insert(res2, res+i)
                end
            end
        end
        if not res2 then
            res2 = betUtil.getRandomIdxByMultiplesWithCnt(mults, config.LanternCnt[math.random(#config.LanternCnt)])
        end
        table.insert(result.res, {res})
        table.insert(result.res, res2)
        local winMap = {}
        for _, idx in ipairs(res2) do
            local mult = config.Multiples[idx]
            local place = config.Results[idx]
            if not winMap[place] then
                winMap[place] = mult
            else
                winMap[place] = winMap[place] + mult
            end
        end
        for place, mult in pairs(winMap) do
            table.insert(result.win, {place=place, mult=mult})
        end
    else
        result.res = {{res},}
        local mult = config.Multiples[res]
        local place = config.Results[res]
        result.win = {
            {place=place, mult=mult}
        }
    end
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
        for _, user in ipairs(users) do
            if user.cluster_info then
                for _, item in ipairs(result.win) do
                    totalwin = totalwin + user.round.bets[item.place] * item.mult
                    totalbet = totalbet + user.round.totalbet
                end
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
    local deskInfo = agent:getDeskInfo()
    local result = gamelogic.tryGetRestrictiveResult(deskInfo)

    local settleTime = config.Times.SettleTime

    if #result.res > 1 then
        settleTime = settleTime + config.Times.ExtraTime
    end

    -- 根据结果来生成结算时长
    agent:setState(config.State.Settle, settleTime)

    --结算
    local users = agent:getUsers()
    -- 系统赢取的金币
    local playertotalwin = 0
    local playertotalbet = 0
    -- 金币池赢取的金币
    local wincoinpot = 0
    for _, user in ipairs(users) do
        user.round.wincoin = 0
        user.round.betinfo = {}
        local betWinMap = {}
        for _, item in ipairs(result.win) do
            local wincoin = user.round.bets[item.place] * item.mult
            betWinMap[item.place] = wincoin
            user.round.wincoin = user.round.wincoin + wincoin
        end
        for p = 1, config.PlaceCount do
            if user.round.bets[p] > 0 then
                local wincoin = betWinMap[p] or 0
                table.insert(user.round.betinfo, {p=p, bet=user.round.bets[p], win=wincoin})
            end
        end
        if user.cluster_info and user.istest ~= 1 then
            playertotalbet = playertotalbet + user.round.totalbet
            playertotalwin = playertotalwin + user.round.wincoin
        end
        wincoinpot = wincoinpot + user.round.totalbet
        wincoinpot = wincoinpot - user.round.wincoin
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

    local coinPot = do_redis({"get", PDEFINE.REDISKEY.GAME.coinpot..agent.gameid, deskInfo.coinPot})
    deskInfo.coinPot = tonumber(coinPot or 0)
    deskInfo.coinPot = deskInfo.coinPot + wincoinpot
    if deskInfo.coinPot < 0 then
        LOG_INFO("coinPot is less than zero:", deskInfo.coinPot)
        deskInfo.coinPot = 0
    end
    -- 写入redis中
    do_redis({"set", PDEFINE.REDISKEY.GAME.coinpot..agent.gameid, deskInfo.coinPot})

    --游戏记录
    local game_record = {type=config.RecordType.Common, place=nil, mult=nil}
    if #result.res > 1 then
        game_record.type = config.RecordType.Lantern
        -- 找出最大押注
        local idxs = result.res[2]
        local sameMult = true  -- 是否都是10被下注
        local maxMult = nil  -- 最大倍数
        local maxPlace = nil  -- 最大图标
        local isTrain = 0 -- 火车长度
        local isClover = true  -- 是否是四叶草
        for _, idx in ipairs(idxs) do
            if not maxMult or maxMult < config.Multiples[idx] then
                maxMult = config.Multiples[idx]
                maxPlace = config.Results[idx]
            elseif maxMult ~= config.Multiples[idx] then
                sameMult = false
            end
        end
        -- 检测是否是火车，从神灯开始，连续中奖
        local startIdx = result.res[1][1]
        for i = 1, 5, 1 do
            local idx = startIdx + i
            if table.contain(idxs, idx) then
                isTrain = isTrain + 1
            else
                break
            end
        end
        -- 检测是否是四叶草，中四个角
        for _, idx in ipairs({4,10,16,22}) do
            if not table.contain(idxs, idx) then
                isClover = false
                break
            end
        end
        game_record.place = maxPlace
        game_record.mult = maxMult
        if sameMult and maxMult == 10 then
            result.sp = 0
            result.op2 = 0
            game_record.type = config.RecordType.Triple
        elseif sameMult and maxMult == 5 and maxPlace == config.Places.Tiger then
            result.sp = 1
            result.op2 = 0
            game_record.type = config.RecordType.Tiger
        elseif isTrain == 3 then
            result.sp = 1
            result.op2 = 1
            game_record.type = config.RecordType.Train3
        elseif isTrain == 4 then
            result.sp = 1
            result.op2 = 1
            game_record.type = config.RecordType.Train4
        elseif isTrain == 5 then
            result.sp = 1
            result.op2 = 1
            game_record.type = config.RecordType.Train5
        elseif isClover then
            result.sp = 1
            result.op2 = 0
            game_record.type = config.RecordType.Clover
        end
    else
        local idx = result.res[1][1]
        game_record.place = config.Results[idx]
        game_record.mult = config.Multiples[idx]
    end
    result.rtype = game_record.type
    table.insert(deskInfo.records, game_record)
    if #(deskInfo.records) > 10 then
        table.remove(deskInfo.records, 1)
    end

    -- 广播前端
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_SETTLE,
        time = settleTime,
        result = result,
        coinPot = deskInfo.coinPot,
        users = {},
    }
    --桌上玩家的输赢
    table.sort(users, function(a, b)
        return a.round.wincoin > b.round.wincoin
    end)
    local cnt = 10
    for _, u in ipairs(users) do
        if cnt <= 0 then
            break
        end
        -- 不显示未中奖的玩家
        if u.round.wincoin > 0 then
            cnt = cnt - 1
            table.insert(notify.users, {
                uid = u.uid,
                seatid = u.seatid,
                wincoin = u.round.wincoin,
                coin = u.coin,
                avatarframe = u.avatarframe or "",
                playername = u.playername or "",
                usericon = u.usericon or "",
            })
        end
    end
    --自己的输赢
    for _, u in ipairs(users) do
        notify.user = {
            wincoin = u.round.wincoin,
            coin = u.coin,
        }
        u:sendMsg(cjson.encode(notify))
        --游戏记录
        if u.round.totalbet > 0 then
            record.betGameLog(deskInfo, u, u.round.totalbet, u.round.wincoin, result, u.round.tax)
        end
    end

    -- 下一状态时间
    agent:setTimer(settleTime, function ()
        gamelogic.startFree(true)
    end)

    --广播赢钱
    agent:broadcastWinners(settleTime)

    -- 清除缓存的排行榜
    rankCache = nil

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
    -- 将玩家的加注金额加入排行榜
    local rediskey = gamelogic.getRankRedisKey()
    do_redis({"zincrby", rediskey, totalcoin, user.uid})
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
    ret.all_bets = deskInfo.round.bets
    ret.coin = user.coin

    --广播通知下注
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_USER_BET,
        uid = msg.uid,
        chips = msg.chips,
        all_bets = deskInfo.round.bets
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
    local multiples = {7, 10, 12, 22, 52, 20, 10, 8}
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

    --下注区域个数
    local placecnt = math.random(3, 8)

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
        local cnt = math.random(1, 4)
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

function gamelogic.getRankList(msg)
    local uid = math.floor(msg.uid)
    local user = agent:findUserByUid(msg.uid)
    local deskInfo = agent:getDeskInfo()
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, uid=uid, today={}, yestoday={}, coinPot=deskInfo.coinPot, myself={}}
    local todayKey = gamelogic.getRankRedisKey()
    local yestodayKey = gamelogic.getRankRedisKey(true)
    local self_today_score = do_redis({"zscore", todayKey, uid}) or 0
    local self_today_total = do_redis({"zcard", todayKey}) or 0
    local self_today_rank = do_redis({"zrevrank", todayKey, uid}) or -1
    if self_today_rank >= 0 then
        self_today_rank = self_today_rank + 1
    end
    ret.myself.uid = uid
    ret.myself.coin = tonumber(self_today_score)
    ret.myself.ord = tonumber(self_today_rank)
    -- ret.myself.nextScore = 0
    -- -- 找出前一个用户的分数
    -- if ret.myself.ord > 1 then
    --    local rs = do_redis({"zrevrange", todayKey, ret.myself.ord-2, ret.myself.ord-2, 'withscores'})
    --    ret.myself.nextScore = tonumber(rs[2]) - ret.myself.nextScore
    -- end
    ret.myself.nextOrd = self_today_rank - 1
    if ret.myself.nextOrd > 30 then
        ret.myself.nextOrd = 30
    elseif ret.myself.nextOrd < 1 then
        ret.myself.nextOrd = 1
    end
    ret.myself.guessCoin = 0
    ret.myself.extraPoint = 0
    ret.myself.avatarframe = user.avatarframe
    ret.myself.playername = user.playername
    ret.myself.usericon = user.usericon
    ret.myself.totalCnt = tonumber(self_today_total)

    if rankCache then
        ret.today = rankCache.today
        ret.yestoday = rankCache.yestoday
    else
        -- 获取今日排行榜和昨日排行榜
        local today_data = do_redis({"zrevrangebyscore", todayKey, 40, 1})
        local yestoday_data = do_redis({"zrevrangebyscore", yestodayKey, 40, 1})
        for i = 1, #today_data, 2 do
            -- 过滤掉零值
            if tonumber(today_data[i+1]) == 0 then
                break
            end
            table.insert(ret.today, {uid=tonumber(today_data[i]), coin=tonumber(today_data[i+1])})
        end
        if #yestoday_data > 0 then
            for i = 1, #yestoday_data, 2 do
                -- 过滤掉零值
                if tonumber(yestoday_data[i+1]) == 0 then
                    break
                end
                table.insert(ret.yestoday, {uid=tonumber(yestoday_data[i]), coin=tonumber(yestoday_data[i+1])})
            end
        end
        for ord, u in ipairs(ret.today) do
            u.ord = ord
            local info
            if rankUserMap[u.uid] then
                info = rankUserMap[u.uid]
            end
            if u.uid == uid then
                info = ret.myself
            end
            if not info then
                -- 直接从redis中获取信息
                local fields = {'avatarframe', 'playername','usericon'}
                local cacheData = do_redis({ "hmget", "d_user:"..u.uid, table.unpack(fields)})
                cacheData = make_pairs_table(cacheData, fields)
                info = {
                    avatarframe = cacheData.avatarframe or "",
                    playername = cacheData.playername or "",
                    usericon = cacheData.usericon or "",
                }
                if cacheData.avatarframe and cacheData.playername and cacheData.usericon then
                    rankUserMap[u.uid] = info
                end
            end
            u.avatarframe = info.avatarframe
            u.playername = info.playername
            u.usericon = info.usericon
        end
        for ord, u in ipairs(ret.yestoday) do
            u.ord = ord
            local info
            if rankUserMap[u.uid] then
                info = rankUserMap[u.uid]
            end
            if u.uid == uid then
                info = ret.myself
            end
            if not info then
                -- 直接从redis中获取信息
                local fields = {'avatarframe', 'playername','usericon'}
                local cacheData = do_redis({ "hmget", "d_user:"..u.uid, table.unpack(fields)})
                cacheData = make_pairs_table(cacheData, fields)
                info = {
                    avatarframe = cacheData.avatarframe or "",
                    playername = cacheData.playername or "",
                    usericon = cacheData.usericon or "",
                }
                if cacheData.avatarframe and cacheData.playername and cacheData.usericon then
                    rankUserMap[u.uid] = info
                end
            end
            u.avatarframe = info.avatarframe
            u.playername = info.playername
            u.usericon = info.usericon
        end
        rankCache = {
            today = ret.today,
            yestoday = ret.yestoday,
        }
    end
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
    local ret = {c=msg.c, code=PDEFINE.RET.SUCCESS, list={}}
    local users = {}
    local myself = {}
    for _, user in ipairs(agent.users) do
        table.insert(users, {
            uid = user.uid,
            playername = user.playername,
            coin = user.coin,
            betCoin = user.betcoin or 0,
            avatarframe = user.avatarframe or "",
            usericon = user.usericon or "",
        })
        if user.uid == msg.uid then
            myself = {
                uid = user.uid,
                playername = user.playername,
                coin = user.coin,
                betCoin = user.betcoin or 0,
                avatarframe = user.avatarframe or "",
                usericon = user.usericon or "",
            }
        end
    end
    table.sort(users, function(a, b)
        return a.betCoin > b.betCoin
    end)
    for ord, user in ipairs(users) do
        if user.uid == msg.uid then
            myself.ord = ord
        end
        user.ord = ord
        -- 超过30名，就不显示
        if ord <= 30 then
            table.insert(ret.list, user)
        end
    end
    ret.myself = myself
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
    -- 获取当前游戏的奖池(从redis中读取)
    local deskInfo = agent:getDeskInfo()
    local coinPot = do_redis({"get", PDEFINE.REDISKEY.GAME.coinpot..gameid})
    deskInfo.coinPot = coinPot and math.floor(coinPot) or 0
    -- 进入空闲阶段
    gamelogic.startFree(false)
    --加入机器人
    skynet.timeout(math.random(100,200), function()
        agent:aiJoin()
    end)
    -- 获取桌子回复
    local ret = agent:getDeskInfoData(uid)
    return warpResp(ret)
end

-- 获取排行榜信息
function CMD.getRankList(source, msg)
    local ret = gamelogic.getRankList(msg)
    return warpResp(ret)
end

-- 通知排行榜已经结算
function CMD.settleWheelGameRank(source, notifyUsers)
    LOG_DEBUG("settleWheelGameRank:", notifyUsers)
    do_redis({"del", PDEFINE.REDISKEY.GAME.coinpot..agent.gameid})
    local deskInfo = agent:getDeskInfo()
    deskInfo.coinPot = 0
    local notifyObj = {c=PDEFINE.NOTIFY.BET_RANK_RESULT, code=PDEFINE.RET.SUCCESS, uid=uid,spcode=0}
    -- 重新刷新进入
    for _, u in ipairs(notifyUsers) do
        local user = agent:findUserByUid(u.uid)
        if user and user.cluster_info then
            notifyObj.ord = u.ord
            notifyObj.mailid = u.mailid
            notifyObj.rewards = u.rewards
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notifyObj))
        end
    end
    return PDEFINE.RET.SUCCESS
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
