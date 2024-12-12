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
local GAME_NAME = "roulette"
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
        0,1,2, 3, 4, 5, 6, 7, 8, 9,10,
        11,12,13,14,15,16,17,18,19,20,
        21,22,23,24,25,26,27,28,29,30,
        31,32,33,34,35,36
    },
    -- 方位数量
    PlaceCount = 156,
    -- 押注方位
    Places = {
        ----------------单个数字（36倍）
        --编号： 1~10
        {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}, {10},
        --编号： 11~20
        {11},{12},{13},{14},{15},{16},{17},{18},{19},{20},
        --编号: 21~30
        {21},{22},{23},{24},{25},{26},{27},{28},{29},{30},
        --编号: 31~37
        {31},{32},{33},{34},{35},{36},{0},

        ----------------两个数字（18倍）
        --编号：38~47
        {0,3},  {0,2},  {0,1},  {2,3},  {2,1},  {3,6},  {2,5},  {1,4},  {5,6},  {5,4},
        --编号：48~57
        {6,9},  {5,8},  {4,7},  {9,8},  {8,7},  {9,12}, {8,11}, {7,10}, {12,11},{11,10},
        --编号：58~67
        {12,15},{11,14},{10,13},{15,14},{14,13},{15,18},{14,17},{13,16},{18,17},{17,16},
        --编号：68~77
        {18,21},{17,20},{16,19},{21,20},{20,19},{21,24},{20,23},{19,22},{24,23},{23,22},
        --编号：78~87
        {24,27},{23,26},{22,25},{27,26},{26,25},{27,30},{26,29},{25,28},{30,29},{29,28},
        --编号：88~97
        {30,33},{29,32},{28,31},{33,32},{32,31},{33,36},{32,35},{31,34},{36,35},{35,34},

        ----------------三个数字（12倍）
        --编号：98~107
        {0,3,2},{0,2,1},{1,3,2},{6,5,4},{9,8,7},{12,11,10},{15,14,13},{18,17,16},{21,20,19},{24,23,22},
        --编号：108~111
        {27,26,25},{30,29,28},{33,32,31},{36,35,34},

        ----------------四个数字（9倍）
        --编号：112~116
        {3,6,2,5},    {2,5,1,4},    {6,9,5,8},    {5,8,4,7},    {9,12,8,11},
        --编号：117~121
        {8,11,7,10},  {12,15,11,14},{11,14,10,13},{15,18,14,17},{14,17,13,16},
        --编号：122~126
        {18,21,17,20},{17,20,16,19},{21,24,20,23},{20,23,19,22},{24,27,23,26},
        --编号：127~131
        {23,26,22,25},{27,30,26,29},{26,29,25,28},{30,33,29,32},{29,32,28,31},
        --编号：132~133
        {33,36,32,35},{32,35,31,34},

        ----------------六个数字（6倍）
        --编号：134~137
        {1,2,3,4,5,6},      {4,5,6,7,8,9},      {7,8,9,10,11,12},   {10,11,12,13,14,15},
        --编号：138~141
        {13,14,15,16,17,18},{16,17,18,19,20,21},{19,20,21,22,23,24},{22,23,24,25,26,27},
        --编号：142~144
        {25,26,27,28,29,30},{28,29,30,31,32,33},{31,32,33,34,35,36},

        ----------------2 to 1（3倍）
        --编号：145~147
        {3,6,9,12,15,18,21,24,27,30,33,36},{2,5,8,11,14,17,20,23,26,29,32,35},{1,4,7,10,13,16,19,22,25,28,31,34},
        --编号：148~150
        {1,2,3,4,5,6,7,8,9,10,11,12},{13,14,15,16,17,18,19,20,21,22,23,24},{25,26,27,28,29,30,31,32,33,34,35,36},

        ----------------红黑（2倍）
        --编号：151~152
        {1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36}, {2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35},

        ----------------奇偶（2倍）
        --编号：153~154
        {1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35}, {2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36},

        ----------------小大（2倍）
        --编号：155~156
        {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18}, {19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36},

    },
    -- 方位倍数
    Multiples = {
        --单个数字倍数
        36,36,36,36,36,36,36,36,36,36,
        36,36,36,36,36,36,36,36,36,36,
        36,36,36,36,36,36,36,36,36,36,
        36,36,36,36,36,36,36,
        --两个数字倍数
        18,18,18,18,18,18,18,18,18,18,
        18,18,18,18,18,18,18,18,18,18,
        18,18,18,18,18,18,18,18,18,18,
        18,18,18,18,18,18,18,18,18,18,
        18,18,18,18,18,18,18,18,18,18,
        18,18,18,18,18,18,18,18,18,18,
        --三个数字倍数
        12,12,12,12,12,12,12,12,12,12,
        12,12,12,12,
        --四个数字倍数
        9,9,9,9,9,
        9,9,9,9,9,
        9,9,9,9,9,
        9,9,9,9,9,
        9,9,
        --六个数字倍数
        6,6,6,6,
        6,6,6,6,
        6,6,6,
        --2 to 1 倍数
        3,3,3,
        3,3,3,
        --红黑倍数
        2,2,
        --奇偶倍数
        2,2,
        --小大倍数
        2,2,
    },
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
        BettingTime = 20,
        SettleTime = 16,
    }
}

-------------------- 游戏逻辑 --------------------
local gamelogic = {}

function gamelogic.initDesk(deskInfo)
    deskInfo.state = config.State.Free      --初始为空闲时段
    deskInfo.chips = table.copy(config.Chips)
    deskInfo.round = {
        bets = {},       --各位置押注总额
    }
end

function gamelogic.initUser(user)
    user.round = {
        bets = {},   --各位置下注额
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
    deskInfo.round.bets = {}
    --重置玩家数据
    local users = agent:getUsers()
    for _, user in ipairs(users) do
        user.round.bets = {}
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
    local cards = table.shuffle(config.Cards)
    local card = cards[1]
    local result = {
        res = card,  --中奖球号
        winplace = {}  --中奖位置
    }
    for id, place in ipairs(config.Places) do
        if table.contain(place, card) then
            table.insert(result.winplace, id)
        end
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
        local winplace = result.winplace --赢分区域
        for _, user in ipairs(users) do
            if user.cluster_info then
                for _, wp in ipairs(winplace) do
                    for _, bet in ipairs(user.round.bets) do
                        if bet.i == wp then
                            totalwin = totalwin + bet.c * config.Multiples[wp]
                        end
                    end
                end
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
    local winplace = result.winplace --赢分区域
    local playertotalwin = 0
    local playertotalbet = 0
    for _, user in ipairs(users) do
        user.round.wincoin = 0
        user.round.betinfo = {}
        for _, bet in ipairs(user.round.bets) do
            local wincoin = 0
            if table.contain(winplace, bet.i) then
                wincoin = bet.c * config.Multiples[bet.i]
            end
            user.round.wincoin = user.round.wincoin + wincoin
            table.insert(user.round.betinfo, {p=bet.i, bet=bet.c, win=wincoin})
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
    table.insert(deskInfo.records, result.res)
    if #(deskInfo.records) > 144 then
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
        if i>=3 then  --轮盘只发3个
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

    --广播赢钱
    agent:broadcastWinners(config.Times.SettleTime)

    --记录游戏日志
    agent:recordDB(result)

    --保存趋势图
    agent:saveRecords()

    --计算完了，准备开启新一轮
    agent:nextRound()
end

--添加下注
function gamelogic.addbet(bets, id, coin)
    for _, bet in ipairs(bets) do
        if bet.i == id then
            bet.c = bet.c + coin
            return
        end
    end
    table.insert(bets, {i=id, c=coin})
end

--玩家下注
function gamelogic.bet(msg)
    local ibets = msg.ibets
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, ibets=msg.ibets}
    if agent:getState() ~= config.State.Betting then
        ret.spcode = PDEFINE.RET.ERROR.DESK_STATE_ERROR
        return ret
    end
    local user = agent:findUserByUid(msg.uid)
    if not user then
        ret.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return ret
    end
    if not ibets or  type(ibets) ~= "table" then
        ret.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return ret
    end

    local totalcoin = 0
    for _, bet in ipairs(ibets) do
        if not bet.i or bet.i < 1 or bet.i > config.PlaceCount or not bet.c or bet.c < 0 then
            ret.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
            return ret
        end
        totalcoin = totalcoin + bet.c
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
    for _, bet in ipairs(ibets) do
        gamelogic.addbet(user.round.bets, bet.i, bet.c)
        gamelogic.addbet(deskInfo.round.bets, bet.i, bet.c)
    end
    user.round.totalbet = user.round.totalbet + totalcoin
    ret.bets = user.round.bets

    --广播通知下注
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_USER_BET,
        uid = msg.uid,
        ibets = msg.ibets,
    }
    if user.seatid <= 0 then
        notify.uid = 0
    end
    agent:broadcast(cjson.encode(notify), msg.uid)

    return ret
end

--机器人自动押注
function gamelogic.autoBet(user)
    if user.cluster_info then return end
    --位置概率
    local placeProb = {}
    for i, mult in ipairs(config.Multiples) do
        table.insert(placeProb, {weight=math.floor(10000/(mult+4)+0.5)})
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
        ibets = {}
    }
    local betcoin = 0
    for i = 1, placecnt do
        local placeidx = commonUtils.randByWeight(placeProb)
        local cnt = math.random(2, 5)
        local chipidx = commonUtils.randByWeight(chipProb)
        local coin = cnt * config.Chips[chipidx]
        table.insert(msg.ibets, {i=placeidx, c=coin})
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
--协议说明
--桌子信息
    deskInfo:
    {
        round:{
            bets = {     --桌子各位置押注总额
                {
                    i=13,   --区域编号
                    c=150   --该区域下注额
                },
                {i=15, c=150},
                ...
            },
        },
    }

  --结算信息
    result = {
        res = 2,  --开出的球号（0~36）
        winplace = {2, 4, 144}  --中奖位置
    }

--交互类
    --玩家下注(C->S) 不要太频繁，可以等玩家点完几次后再一次性上传
    {
        c = 37,
        uid = uid,
        ibets = {
            {
                i=13,    --区域编号
                c=150    --该区域下注额
            },
            {
                i=57, 
                c=500
            },
            ...
        },
    }
    返回
    {
        c = 37,
        spcode = 0, --spcode不为0表示下注失败，前端从桌面移除筹码即可
        uid = uid,
        ibets = {     --玩家各区域本次下注额
            {i=13, c=150},
            {i=15, c=150},
            ...
        },
        bets = {        --玩家各区域下注总额，spcode==0时带下来
            {i=13, c=150},
            {i=15, c=150},
            ...
        }, 
    }

--通知类    
    --其他玩家下注(如果uid>0，说明是桌上玩家，从玩家头像飞金币； 如果uid=0，说明是列表里的玩家，从列表处飞金币，列表里的玩家每1秒同步一次，因此收到消息后在一秒内分多次飞金币)     
    {
        c = BET_USER_BET(128003),
        uid = uid,
        ibets = {     --玩家各区域本次下注额
            {i=13, c=150},
            {i=13, c=150},
            ...
        },
    }
    
--其他参考龙虎斗 drgonvstiger
]]
