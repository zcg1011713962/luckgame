local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local queue     = require "skynet.queue"
local player_tool = require "base.player_tool"
local baseDeskInfo = require "base.deskInfo"
local baseAgent = require "base.agent"
local record = require "base.record"
local commonUtils = require "cashslots.common.utils"
local BetStgy = require "betgame.betstgy"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

---@type BetStgy
local stgy = BetStgy.new()

--控制参数
--参数值一般规则：为1时保持平衡；大于1时玩家buff；小于1时玩家debuff
local ControlParams = { --控制参数，
    robot_roll_high_dice_prob = 0.7,    --机器人使用高权重筛子的概率(注意，实际概率是1-0.7=0.3)
    robot_direct_arrive_end_prob = 0.7,--机器人直接进入终点的概率(0.17->0.3)
    robot_kill_user_prob = 0.75,        --机器人直接杀死玩家棋子的概率(0.17->0.25)
}

---@type BaseDeskInfo
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例

local LastDealerSeat = nil
local TimerTime = 0

local config = {
    AutoDelayMoveTime = 3,
    Protect = {1, 9, 14, 22, 27, 35, 40, 48}, --保护的位置列表
    Quick = 51,     --quick玩法截停的位置
    Win = 57,       --到达这个步数算赢
    QuickZero = 58, --这个位置比较特殊，本来应该是-1，兼容客户端定义为58
    MaxDot = 6,     --最大点数
    ActionType = {  --操作类型
        RUN = 1,
        ROLL = 2
    },
    GameType = {    --玩法类型
        --[[ quick:
            1、1个棋子到终点就算赢
            2、过quick需至少杀敌1次
            3、开局第1个棋子就在1位置
            4、如果我的2个棋子在同1格子中，不被杀,对方可以跳过或落到同1格子
        ]]
        QUICK = 1,
        --[[ classic:
            1, 4枚棋子全部到终点算赢
            2, 过quick不需要杀敌
            3, 如果我的2个棋子在同1格子中，不被杀,对方可以跳过或落到同1格子
        ]]
        CLASSIC =2,
        --[[ master:
            1、4枚棋子全部到终点算赢
            2、过quick需要至少杀敌1次;
            3、如果两个相同颜色的标记落在同一个盒子里，那么它们来自一个联合标记。联合标记将充当墙，你或你的对手不能越过或降落在上面。联合标记只能在掷骰子时移动（2,4,6）和一半的数字。 Eg.如果你掷2，那么联合令牌只会移动1格，如果它落在保险箱上，联合令牌会被打破[全球/星]
        ]]
        MASTER = 3, --master
    }
}

--骰子权重（比平均高5%）
local HighDiceWeight = {
    {dice=1, weight=70},
    {dice=2, weight=85},
    {dice=3, weight=90},
    {dice=4, weight=90},
    {dice=5, weight=95},
    {dice=6, weight=105},
}

--获取控制系数
local function getControlParam(key)
    local param = ControlParams[key]
    if not param then return 1 end
    local rtp = 100
    if stgy:isValid() then
        rtp = stgy.rtp
    end
    local p = param * (rtp / 100)
    return p
end

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

local function initDesk()
    deskInfo.conf.gametype = config.GameType.CLASSIC --玩法
    if deskInfo.gameid == PDEFINE_GAME.GAME_TYPE.LUDO_QUICK then
        deskInfo.conf.gametype = config.GameType.QUICK
    end
end

local function initDeskInfoRound(uid, seatid)
    deskInfo.round = {}
    deskInfo.round.activeSeat = seatid -- 当前活动座位
    deskInfo.round.settle = {}      -- 小结算
    deskInfo.round.dealer = {       --此把的庄家(庄家先出)
        uid = uid,
        seatid = seatid
    }
    deskInfo.round.winuid = 0       --赢家
    deskInfo.round.pannel = {}      --按座位记录 摇骰子, 杀，被杀
    for i = 1, deskInfo.seat do
        deskInfo.round.pannel[i] = {0, 0, 0}
    end
end

---@param user BaseUser
local function initUserRound(user)
    user.state = PDEFINE.PLAYER_STATE.Wait
    user.round = {}
    user.round.isWin = 0            -- 是否赢了
    user.round.chess = {1,2,3,4}    --每人4颗棋子
    user.round.times = 0            --摇动骰子的次数
    user.round.steps = {0,0,0,0}    --棋子位置
    user.round.dices = {}           --本次摇骰子的数据，最大3个,每次自己走完棋子就清空
    user.round.resetTimes = 0       --用户重摇骰子次数
    user.round.kill = 0             --杀他人骰子次数
    if deskInfo.conf.gametype == config.GameType.QUICK then
        user.round.steps = {1,0,0,0}
        user.round.chess = {2,3,4}
    end
end

local function assignSeat()
    local seatid_list = {1, 3, 2, 4}
    for _, seatid in ipairs(seatid_list) do
        if table.contain(deskInfo.seatList, seatid) then
            for i = #deskInfo.seatList, 1, -1 do
                if deskInfo.seatList[i] == seatid then
                    table.remove(deskInfo.seatList, i)
                    break
                end
            end
            return seatid
        end
    end
end

-- 自动摇骰子
local function autoRollDice(uid)
    LOG_DEBUG("autoRollDice uid:", uid)

    local user = deskInfo:findUserByUid(uid)
    if deskInfo.round.activeSeat ~= user.seatid then
        LOG_WARNING("autoRollDice activeSeat error uid:", uid, user.seatid, deskInfo.round.activeSeat)
        return
    end
    user:clearTimer()
    if user.cluster_info then
        if user.auto == 0 and os.time()>=TimerTime+deskInfo.delayTime then
            user.auto = 1
            deskInfo:autoMsgNotify(user, 1, 0)
        end
    end

    local msg = {
        c = 26901,
        uid = uid,
    }
    local code = CMD.rollDice(nil, msg)
    if code ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("rollDice error", code)
    end
end

local SeatMap = { --classic玩法 转换到位置1的坐标, 从仓库出来第一个位置为1
    [1] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51}, --左下
    [2] = {14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,1,2,3,4,5,6,7,8,9,10,11,12}, --左上
    [3] = {27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25}, --右上
    [4] = {40,41,42,43,44,45,46,47,48,49,50,51,52,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38}, --右下
}

--检查是否可杀
---@param user BaseUser
---@param step integer
---@param other BaseUser
local function checkKill(user, step, other)
    local killids = {}
    local pos = SeatMap[user.seatid][step] --转换到位置1的坐标
    local steps = other.round.steps
    for id, sp in pairs(steps) do
        if sp > 0 then
            local p = SeatMap[other.seatid][sp]
            if p and p == pos and table.count(steps, sp) == 1 then  --有两颗及以上棋子是不能踢的
                table.insert(killids, id)
            end
        end
    end
    local cankill = #killids > 0
    return cankill, killids
end

local SeatMapQuickZero = {
    [1] = {58, 39, 26, 13}, --座位1的玩家的58号位置对应的其他玩家的位置
    [2] = {13, 58, 39, 26},
    [3] = {26, 13, 58, 39},
    [4] = {39, 26, 13, 58},
}
--检查是否可杀（QuickZero）
local function checkKillQuickZero(user, mystep, other)
    local killed = false
    local killedList = {}
    if mystep ~= config.QuickZero then
        return killed, killedList
    end

    local step = SeatMapQuickZero[user.seatid][other.seatid]
    local steps = other.round.steps
    for k, s in pairs(steps) do
        if s > 0 then
            if s == step and table.count(steps, s) == 1 then
                killed = true
                table.insert(killedList, k)
            end
        end
    end
    return killed, killedList
end

--检查是否能杀死其他棋子
local function canKillOtherByStep(user, step)
    if (step <= config.Quick or step == config.QuickZero) and not table.contain(config.Protect, step) then
        for _, muser in pairs(deskInfo.users) do
            if muser.cluster_info and muser.uid ~= user.uid then
                local killed = checkKill(user, step, muser)
                if killed then
                    return true
                end
            end
        end
    end
    return false
end

--检查是否安全，如果后面4个范围内跟有其他玩家棋子，则被判定为不安全
local function checkSafe(user, step)
    if step < 1 or step > config.Quick then return true end
    if table.contain(config.Protect, step) then return true end
    local distance = 6
    local pos = SeatMap[user.seatid][step]
    for _, muser in pairs(deskInfo.users) do
        if muser.uid ~= user.uid then
            for _, sp in ipairs(muser.round.steps) do
                local mpos = SeatMap[muser.seatid][sp]
                if mpos and pos > mpos and pos <= mpos + distance then
                    return false
                end
            end
        end
    end
    return true
end

--找出需要移动的棋子以及对应移动的骰子
---@class Result
---@field chess integer
---@field dice integer
---@field weight integer
local function findMoveChessAndDice(user)
    ---@type Result[]
    local result = {}
    local dices = user.round.dices
    local dice_combs = {}  --骰子组合
    --单个骰子
    for _, dice in ipairs(dices) do
        table.insert(dice_combs, {dice=dice, addstep=dice})
    end
    --多个骰子
    if #dices > 1 then
        table.insert(dice_combs, {dice=dices[1], addstep=dices[1]+dices[2]})  --1/2骰子
        if #dices > 2 then
            table.insert(dice_combs, {dice=dices[1], addstep=dices[1]+dices[3]})    --1/3骰子
            table.insert(dice_combs, {dice=dices[2], addstep=dices[2]+dices[3]})    --2/3骰子
            table.insert(dice_combs, {dice=dices[1], addstep=dices[1]+dices[2]+dices[3]})   --1/2/3骰子
        end
    end

    for _, item in ipairs(dice_combs) do
        local dice = item.dice
        local chesses = {}
        for chess, step in pairs(user.round.steps) do
            if step == config.QuickZero and deskInfo.conf.gametype == config.GameType.QUICK then
                table.insert(chesses, chess)
            end
            if step > 0 and (step < config.Quick or step + dice <= config.Win) then
                table.insert(chesses, chess)
            end
        end
        if dice == config.MaxDot then --6点
            for _, chess in pairs(user.round.chess) do
                table.insert(chesses, chess)
            end
        end
        for _, chess in ipairs(chesses) do
            if user.cluster_info then  --玩家直接返回
                return {chess = chess, dice = dice}
            end
            --机器人寻找最优
            --1，如果能踢走玩家的棋子，则优先级为10
            --2，如果能进终点，则优先级9
            --3, 如果能进安全区，则优先级为8
            --4，如果能摆脱其他棋子，则优先级为7
            --5，如果离开安全区，则优先级为2
            --6，如果超到其他棋子前面，则优先级为1
            --7，如果路上少于3个棋子，且有棋子能出家，则优先级为8
            --8，其余情况，优先级为5
            local step = user.round.steps[chess] or 0
            local weight = 5
            if table.contain(user.round.chess, chess) and dice == config.MaxDot then
                local onroad = 0
                for _, p in ipairs(user.round.steps) do
                    if p > 0 and p < config.Win then onroad = onroad + 1 end
                end
                if onroad < 3 then
                    weight = 8
                else  --别出太多
                    weight = 6
                end
            else
                local newStep = step + item.addstep
                if canKillOtherByStep(user, newStep) then
                    weight = 10
                elseif newStep == config.Win then
                    weight = 9
                elseif ((step <= config.Quick or step == config.QuickZero) and newStep > config.Quick and newStep < config.Win) or table.contain(config.Protect, newStep) then
                    weight = 8
                elseif not checkSafe(user, step) and checkSafe(user, newStep) then
                    weight = 7
                elseif table.contain(config.Protect, step) then
                    weight = 4
                elseif step > config.Quick and newStep < config.Win then
                    weight = 3
                elseif not checkSafe(user, newStep) then
                    if step <= 30 then weight = 2
                    else weight = 1 end
                end
            end
            ---@type Result
            local res = {chess = chess, dice = dice, weight = weight}
            table.insert(result, res)
        end
    end

    shuffle(result) --打乱，如果权重相同则随机
    table.sort(result, function(a, b)
        return a.weight > b.weight
    end)

    return result[1]
end

-- 自动走棋子
local function autoMoveChess(uid)
    local user = deskInfo:findUserByUid(uid)
    if deskInfo.round.activeSeat ~= user.seatid then
        LOG_WARNING("autoMoveChess activeSeat error uid:", uid, user.seatid, deskInfo.round.activeSeat)
        return
    end
    user:clearTimer()
    if user.cluster_info then
        if user.auto == 0 and os.time()>=TimerTime+deskInfo.delayTime then
            user.auto = 1
            deskInfo:autoMsgNotify(user, 1, 0)
        end
    end

    local res = findMoveChessAndDice(user)
    LOG_DEBUG("autoMoveChess: uid:", uid, "steps:", table.concat(user.round.steps, ','), 'dices:', table.concat(user.round.dices, ','), 'dice:', res.dice, 'chess:', res.chess)

    local msg = {
        c = 26902,
        uid = uid,
        step = res.dice,
        chessid = res.chess
    }
    local code = CMD.moveChess(nil, msg)
    if code ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("moveChess error", code)
    end
end

-- 自动准备
local function autoReady(uid)
    return cs(function()
        LOG_DEBUG("自动准备 uid:".. uid)
        local user = deskInfo:findUserByUid(uid)

        if not user or user.state == PDEFINE.PLAYER_STATE.Ready then
            return
        end
        user:clearTimer()

        local msg = {
            c = 26903,
            uid = uid,
        }
        CMD.ready(nil, msg)
    end)
end

local function setAutoReady(delayTime, uid)
    CMD.userSetAutoState('autoReady', delayTime, uid)
end

--! agent退出
function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

local function shouldAddAi()
    local hasPlayer = false
    if DEBUG then
        return hasPlayer
    end
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info then
            hasPlayer = true
            break
        end
    end
    if hasPlayer and #deskInfo.users< 2 then
        return true
    end
    return false
end

-- 开始发牌
local function roundStart()
    local retobj = {}
    LOG_DEBUG("roundStart:", deskInfo.deskid)
    deskInfo.curround = deskInfo.curround + 1
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH and shouldAddAi() then --匹配房人数不够继续填充机器人
        deskInfo:aiJoin()
    end
    if #deskInfo.users == 0 then
        for _, user in ipairs(deskInfo.users) do
            user.state = PDEFINE.PLAYER_STATE.Wait
            user:clearTimer()
        end
        deskInfo:destroy()
        return
    end

    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.activeUid = deskInfo.round.dealer.uid
    retobj.dealerUid = deskInfo.round.dealer.uid

    local users = table.copy(deskInfo.users)
    for _, user in ipairs(users) do
        -- 去掉连接信息
        user.cluster_info = nil
        -- 去掉定时器信息
        user.timer = nil
        user.luckBuff = nil
        user.isexit = nil
        user.realCoin = nil
        user.settlewin = nil
        user.winTimes = nil
        user.wincoin = nil
        user.wincoinshow = nil
        user.autoCnt = nil
        -- cjson不支持function
        for key, v in pairs(user) do
            if type(v) == 'function' then
                user[key] = nil
            end
        end
        -- 清除元表
        user = setmetatable(user, {})
    end
    retobj.users = users
    -- 切换桌子状态
    deskInfo:updateState(PDEFINE.DESK_STATE.PLAY)
    -- 开始发牌
    retobj.delayTime = deskInfo.delayTime
    for _, user in pairs(deskInfo.users) do
        -- 庄家切换到出牌阶段
        if user.seatid == deskInfo.round.dealer.seatid then
            -- 切换状态
            user.state = PDEFINE.PLAYER_STATE.Draw --摇骰子状态
            deskInfo.round.activeSeat = user.seatid

            local delayTime = deskInfo.delayTime + 1  -- 第一次出牌设置慢一点
            CMD.userSetAutoState('autoRollDice', delayTime, user.uid)
        else
            user.state = PDEFINE.PLAYER_STATE.Wait
        end
    end
    -- 广播消息
    deskInfo:broadcast(cjson.encode(retobj))
end

-- 开始游戏
---@param delayTime integer 用于指定发牌前的延迟时间
local function startGame(delayTime)
    if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY then
        return
    end
    -- 调用基类的开始游戏
    deskInfo:startGame()
    local dealer
    if LastDealerSeat then
        dealer = deskInfo:findNextUser(LastDealerSeat)
    else
        -- 随机庄家
        dealer = deskInfo.users[math.random(#deskInfo.users)]
    end

    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and #deskInfo.users == 2 then
        local changeSeat = false
        for _, muser in pairs(deskInfo.users) do
            local seatid = muser.seatid
            muser.oldseatid = seatid --之前旧的座位号
            if seatid ~= 1 and seatid ~= 3 then
                table.insert(deskInfo.seatList, seatid)
                local otherUser = deskInfo:findUserBySeatid(1)
                if otherUser then
                    muser.seatid = 3
                else
                    muser.seatid = 1
                end
                for i=#deskInfo.seatList, 1, -1 do
                    if deskInfo.seatList[i] == muser.seatid then
                        table.remove(deskInfo.seatList, i)
                        break
                    end
                end
                changeSeat = true
            end
        end
        if changeSeat then
            local oldDealer = deskInfo:findUserByUid(dealer.uid)
            if not oldDealer then --庄家可能离开了
                dealer = deskInfo.users[math.random(#deskInfo.users)]
            end
        end
    end

    LOG_DEBUG("dealer", dealer.uid, dealer.seatid)
    LastDealerSeat = dealer.seatid
    -- 初始化桌子信息
    deskInfo:initDeskRound(dealer.uid, dealer.seatid)

    delayTime = (delayTime or 0) * 100 + 30
    skynet.timeout(delayTime, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart()
    end)
end

-- 游戏结束，大结算
local function gameOver(isDismiss)
    LOG_DEBUG("gameOver:", deskInfo.deskid)
    deskInfo.state = PDEFINE.DESK_STATE.SETTLE
    ---@type Settle
    local settle = {
        uids = {}, -- 座位号对应的uid
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        scores = {}, -- 获得的分数
        levelexps = {}, -- 经验值
        rps = {},  -- rp 值
        fcoins = {},  -- 最终的金币
        pannel = deskInfo.round.pannel,
    }
    for i = 1, deskInfo.seat do
        local u = deskInfo:findUserBySeatid(i)
        if u then
            table.insert(settle.uids, u.uid)
        else
            table.insert(settle.uids,0)
        end
        table.insert(settle.league, 0)
        table.insert(settle.coins, 0)
        local score = 0
        if u then
            for _, step in pairs(u.round.steps) do
                score = score + step
            end
        end
        table.insert(settle.scores, score)
        table.insert(settle.levelexps, 0)
        table.insert(settle.rps, 0)
        table.insert(settle.fcoins, 0)
    end

    for _, user in ipairs(deskInfo.users) do
        settle.scores[user.seatid] = user.score
    end
    local winners = {}
    local winuid = deskInfo.round.winuid
    local userInfo = deskInfo:findUserByUid(winuid)
    table.insert(winners, userInfo.seatid)
    deskInfo:gameOver(settle, isDismiss, true, winners)

    if stgy:isValid() then
        local playertotalbet = 0
        local playertotalwin = 0
        local betcoin = deskInfo.bet
        local wincoin =  (#deskInfo.users) * betcoin
        local tax = math.round_coin(math.max(0, wincoin-betcoin) * deskInfo.taxrate)
        wincoin = wincoin - tax
        for _, user in ipairs(deskInfo.users) do
            if user.cluster_info and user.istest ~= 1 then
                playertotalbet = playertotalbet + betcoin
                if user.uid == winuid then
                    playertotalwin = playertotalwin + wincoin
                end
            end
        end
        stgy:update(playertotalbet, playertotalwin)
    end
end

-------- 设定玩家定时器 --------
function CMD.userSetAutoState(type, autoTime, uid)
    autoTime = autoTime + 1
    TimerTime = os.time()
    deskInfo.round.autoTime = autoTime + os.time() --自动截止时间, 断线重连用

    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    user:clearTimer()

    if not user.cluster_info or (type ~= "autoReady" and user.auto == 1) then
        if user.auto == 1 then
            autoTime = 2
        else
            local minTime = 1
            local maxTime = 3
            if type == autoMoveChess then maxTime = 4 end
            autoTime = math.random(minTime, maxTime)
        end
    end
    -- 自动摇骰子
    if type == "autoRollDice" then
        user:setTimer(autoTime, autoRollDice, uid)
    -- 自动走棋子
    elseif type == "autoMoveChess" then
        user:setTimer(autoTime, autoMoveChess, uid)
    -- 自动准备
    elseif type == "autoReady" then
        user:setTimer(autoTime, autoReady, uid, true)
    end
end

-- 自动加入机器人
function CMD.aiJoin(source, aiUser)
    return deskInfo:aiJoin(aiUser)
end

-- 退出房间
function CMD.exitG(source, msg)
    local ret = agent:exitG(msg)
    return warpResp(ret)
end

-- 发起解散
function CMD.applyDismiss(source, msg)
    local retobj = agent:applyDismiss(msg)
    return warpResp(retobj)
end

-- 同意/拒绝 解散房间
function CMD.replyDismiss(source, msg)
    local retobj = agent:replyDismiss(msg)
    return warpResp(retobj)
end

-- 根据座位号，找到下一个玩家
local function findNextUser(seatId)
    local tryCnt = 3
    while tryCnt > 0 do
        seatId = seatId + 1
        if seatId > 4 then seatId = 1 end
        for _,user in pairs(deskInfo.users) do
            if user.seatid == seatId then
                return user
            end
        end
        tryCnt = tryCnt - 1
    end
    return nil
end

--计算可以走的棋子的数量
local function calCanMoveChess(user)
    local cnt = 0
    if table.contain(user.round.dices, config.MaxDot) and #user.round.chess > 0 then
        cnt = cnt + #user.round.chess
    end
    for _, s in pairs(user.round.steps) do
        if s == config.QuickZero and deskInfo.conf.gametype == config.GameType.QUICK then
            cnt = cnt + 1
        elseif s > 0 and s < config.Win then
            for _, dice in pairs(user.round.dices) do
                if s + dice <= config.Win then
                    cnt = cnt + 1
                    break
                end
            end
        end
    end
    return cnt
end

--是否可走棋子
local function checkCanMove(user)
    return calCanMoveChess(user) > 0
end

--是否只有一颗棋子可走
local function checkOnlyOneChessCanMove(user)
    return calCanMoveChess(user) == 1
end

--摇骰子
local function randomGetDice(user)
    local random = math.random(1, 6)
    local cc_dice = getControlParam("robot_roll_high_dice_prob")
    if not user.cluster_info and math.random() > cc_dice then
        random = commonUtils.randByWeight(HighDiceWeight)
    end
    if #user.round.chess == 4 and table.count(user.round.dices, config.MaxDot) == 0 then
        local threshold = 60
        if user.cluster_info then threshold = 40 end
        if math.random(1, 100) <= threshold then
            random = 6
        end
    else
        if not user.cluster_info then --机器人
            local cc_kill = getControlParam("robot_kill_user_prob")
            if math.random() > cc_kill then
                --增加击杀他人棋子的
                for _, step in pairs(user.round.steps) do
                    if step > 0 and step < config.Quick then
                        for i = 1, 6 do
                            if not table.contain(config.Protect, (step+i)) then
                                for _, muser in pairs(deskInfo.users) do
                                    if muser.cluster_info and muser.uid ~= user.uid then
                                        local killed = checkKill(user, (step+i), muser)
                                        if killed then
                                            return i
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            local cc_end = getControlParam("robot_direct_arrive_end_prob")
            if math.random() > cc_end then
                for _, step in pairs(user.round.steps) do
                    if step > config.Quick and step < config.Win then
                        return config.Win - step
                    end
                end
            end
        end
    end
    return random
end

--[[
    摇骰子
   1、摇到6就继续摇，最多3次，连续3个6本次作废，轮到下一个人摇
   2、如果我的棋子都已超过quick(51)位置，摇的数字大于距离最大位置57的步数,不用走棋子,直接作废，轮到下一个人摇
   3、如果摇到6，从家里移出棋子，只能走1步
   4、正常，我摇完，就轮到自己走棋子
]]
function CMD.rollDice(source, msg)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {c = recvobj.c, uid = uid, code = PDEFINE.RET.SUCCESS, spcode = 0, coin = 0}

    local user = deskInfo:findUserByUid(uid)
    if not user then
        LOG_ERROR("rollDice user not found", uid)
        return PDEFINE.RET.ERROR.USER_NOT_FOUND
    end
    if deskInfo.round.activeSeat ~= user.seatid then
        LOG_ERROR("rollDice activeSeat error uid:", uid, 'activeSeat:', deskInfo.round.activeSeat)
        return PDEFINE.RET.ERROR.USER_STATE_ERROR
    end
    if user.state ~= PDEFINE.PLAYER_STATE.Draw then
        LOG_ERROR("rollDice state error uid:", uid, 'state:', user.state)
        return PDEFINE.RET.ERROR.USER_STATE_ERROR
    end
    user:clearTimer()

    local random = randomGetDice(user)

    local autoPass = 0  --是否因为不能走棋子才pass的
    local autoMove = 0  --是否直接自己自动走棋子
    local delayTime = deskInfo.delayTime

    retobj.nextSeat = user.seatid --下一步操作玩家
    retobj.nextgametype = config.ActionType.RUN --下一步动作类型
    retobj.canreset = 0  -- 这里默认关闭，这个项目不需要钻石重置
    retobj.delayTime = delayTime

    LOG_DEBUG("rollDice:", user.uid, 'dice:', random, ' seatid:', user.seatid , 'chess:', table.concat(user.round.chess, ','), 'steps:', table.concat(user.round.steps,','), 'dices:', table.concat(user.round.dices,','))

    table.insert(user.round.dices, random)
    if table.count(user.round.dices, config.MaxDot) >= 3 then
        --摇到3个6
        autoPass = 1
        user.state = PDEFINE.PLAYER_STATE.Wait
        user.round.dices = {}
        --下一个玩家摇
        local nextUser = findNextUser(user.seatid)
        nextUser.state = PDEFINE.PLAYER_STATE.Draw
        deskInfo.round.activeSeat = nextUser.seatid
        retobj.nextSeat = nextUser.seatid
        retobj.nextgametype = config.ActionType.ROLL
        LOG_DEBUG("3个6, uid:", user.uid, 'next:', nextUser.uid, nextUser.seatid)
        CMD.userSetAutoState('autoRollDice', delayTime, nextUser.uid)
    else
        if random == config.MaxDot and #user.round.dices < 3 then
            --继续摇
            retobj.nextgametype = config.ActionType.ROLL
            LOG_DEBUG("get 6, nexttype roll, uid:", user.uid)
            CMD.userSetAutoState('autoRollDice', delayTime, uid)
        else
            --切换为移动棋子
            if checkCanMove(user) then
                --可以移动
                user.state = PDEFINE.PLAYER_STATE.Discard
                retobj.nextgametype = config.ActionType.RUN
                if checkOnlyOneChessCanMove(user) then
                    autoMove = 1
                    delayTime = config.AutoDelayMoveTime
                end
                retobj.delayTime = delayTime
                LOG_DEBUG("nexttype movechess", user.uid, user.seatid, autoMove)
                CMD.userSetAutoState('autoMoveChess', delayTime, user.uid) --该我移动棋子, hosting为false，标识不进入默认托管状态
            else
                --不能移动
                autoPass = 1
                user.state = PDEFINE.PLAYER_STATE.Wait
                user.round.dices = {}
                --下一个玩家摇
                local nextUser = findNextUser(user.seatid)
                nextUser.state = PDEFINE.PLAYER_STATE.Draw
                deskInfo.round.activeSeat = nextUser.seatid
                retobj.nextSeat = nextUser.seatid
                retobj.nextgametype = config.ActionType.ROLL
                LOG_DEBUG("cannot move uid:", user.uid, 'next:', nextUser.uid, nextUser.seatid)
                CMD.userSetAutoState('autoRollDice', delayTime, nextUser.uid)
            end
        end
    end

    retobj.automove = 0
    retobj.automove = autoMove
    retobj.pass = autoPass
    retobj.dices = user.round.dices --本次摇完的点数列表
    retobj.dot = random
    retobj.nextSeat = deskInfo.round.activeSeat --下一步谁操作

    LOG_DEBUG("rollDice2:", user.uid, 'dice:'..random, 'seatid:'..user.seatid , "state:"..user.state, 'chess:', table.concat(user.round.chess, ','), 'steps:', table.concat(user.round.steps,','), 'dices:', table.concat(user.round.dices,','), 'nextSeat:', deskInfo.round.activeSeat)
    deskInfo.round.pannel[user.seatid][1] = deskInfo.round.pannel[user.seatid][1] + 1

    retobj.c = PDEFINE.NOTIFY.ROLLE_RESULT
    deskInfo:broadcast(cjson.encode(retobj))

    return PDEFINE.RET.SUCCESS
end

--杀死棋子
local function killChess(user, other, chessid)
    other.round.steps[chessid] = 0 --杀掉
    table.insert(other.round.chess, chessid) --打回仓库
    --记录次数
    deskInfo.round.pannel[other.seatid][3] =deskInfo.round.pannel[other.seatid][3] + 1
    deskInfo.round.pannel[user.seatid][2] = deskInfo.round.pannel[user.seatid][2] + 1 --记录杀的次数
    user.round.kill = user.round.kill + 1
end

--[[
    走棋子
    1、按路线走棋子，步数等于摇骰子的结果点数
    2、如果点数列表有多个，可以选择优先走一个点数, 剩余点数可以同一个棋子走，也可以选另外一个棋子走
    3、路线中，非保护位置可以干掉对方的棋子, 对方棋子回到他自己家,重新开始
    4、如果棋子超过quick位置不能被其他人杀掉
    5、如果走到win位置(非最后1颗棋子),奖励自己1次摇骰子的次数
    6、如果棋子超过quick，要走的步数超过它距win位置的距离步数，则不能走
]]
function CMD.moveChess(source, msg)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)
    local chessid = math.floor(recvobj.chessid or 0) --棋子id
    local step = math.floor(recvobj.step or 0) --步数(可能有多种选择)
    local retobj = {c=recvobj.c, uid=uid, code=PDEFINE.RET.SUCCESS, spcode=0, chessid=chessid, addStep=step, dice=step}

    local user = deskInfo:findUserByUid(uid)
    if not user then
        LOG_ERROR("moveChess user not found", uid)
        return PDEFINE.RET.ERROR.USER_NOT_FOUND
    end
    if chessid > 4 or chessid < 1 then --每个人只有4颗棋子
        LOG_ERROR("moveChess chess error uid:", uid, 'chessid:', chessid)
        return PDEFINE.RET.ERROR.PUT_CARD_ERROR
    end
    if deskInfo.round.activeSeat ~= user.seatid then --TODO:不是他操作
        LOG_ERROR("moveChess activeSeat error uid:", uid, 'activeSeat:', deskInfo.round.activeSeat, 'seatid:', user.seatid)
        return PDEFINE.RET.ERROR.USER_STATE_ERROR
    end
    if user.state ~= PDEFINE.PLAYER_STATE.Discard then
        LOG_ERROR("moveChess state error uid:", uid, ' state:', user.state)
        return PDEFINE.RET.ERROR.USER_STATE_ERROR
    end
    if step ~= config.MaxDot and table.contain(user.round.chess, chessid) then --它走的数字不是6，想从仓库中走出来
        LOG_ERROR("moveChess chess state error uid:", uid, 'step:', step, 'chessid:', chessid, 'dices:', table.concat(user.round.dices,','), 'chess:', table.concat(user.round.chess,','))
        return PDEFINE.RET.ERROR.PUT_CARD_ERROR
    end
    if not table.contain(user.round.dices, step) then
        LOG_ERROR("moveChess step error uid:", uid, 'step:', step, 'dices:', user.round.dices)
        return PDEFINE.RET.ERROR.PUT_CARD_ERROR
    end
    local nowStep = user.round.steps[chessid] or 0
    if nowStep > config.Quick and nowStep ~= config.QuickZero and step > (config.Win - nowStep) then
        LOG_ERROR("moveChess end track error uid:", uid, 'dices:', user.round.dices, 'step:', step, 'nowStep:', nowStep, 'chessid:', chessid)
        return PDEFINE.RET.ERROR.PUT_CARD_ERROR
    end

    user:clearTimer()
    LOG_DEBUG("begin moveChess uid:", uid, "step:", step, 'chessid:', chessid, 'steps:', table.concat(user.round.steps,','), 'dices:', table.concat(user.round.dices,','))

    for i = #user.round.dices, 1, -1 do --从摇出来的队列中删除
        if user.round.dices[i] == step then
            table.remove(user.round.dices, i)
            break
        end
    end

    if step == config.MaxDot and table.contain(user.round.chess, chessid) then
        table.removeVal(user.round.chess, chessid)
        user.round.steps[chessid] = 1
        retobj.addStep = 1
        LOG_DEBUG("moveChess uid:",uid, 'leave home:', chessid)
    else
        if deskInfo.conf.gametype == config.GameType.QUICK or deskInfo.conf.gametype == config.GameType.MASTER then
            local tmpStep = user.round.steps[chessid] + step
            if tmpStep > config.Quick and user.round.kill == 0 then
                --quick玩法，未杀敌，继续跑圈
                local leftStep = 0
                if user.round.steps[chessid] == config.QuickZero then
                    leftStep = step
                else
                    leftStep = step - (config.Quick - user.round.steps[chessid]) - 1 --跳过51和1之间的格子
                    if leftStep <= 0 then
                        leftStep = config.QuickZero
                    end
                end
                user.round.steps[chessid] = leftStep
                LOG_DEBUG("quick_mater：not kill other uid:",uid, 'another circle:', chessid, ' leftStep:', leftStep)
            else
                user.round.steps[chessid] = user.round.steps[chessid] + step
            end
        else
            user.round.steps[chessid] = user.round.steps[chessid] + step
        end
    end

    local afterstep = user.round.steps[chessid]
    local delayTime = deskInfo.delayTime
    retobj.step = afterstep
    retobj.isOver = 0
    if afterstep == config.Win then --到了终点
        if table.count(user.round.steps, config.Win) == 4 or (deskInfo.conf.gametype == config.GameType.QUICK) then --quick 玩法只要有棋子走到终点就算赢
            LOG_DEBUG("win uid:", uid, 'chessid:', chessid)
            retobj.isOver = 1
            deskInfo.round.winuid = uid
            skynet.timeout(300, function()
                agent:gameOver()
            end)
        else --奖励自己1次摇的机会
            user.state = PDEFINE.PLAYER_STATE.Draw
            retobj.nextgametype = config.ActionType.ROLL
            retobj.nextSeat = user.seatid
            retobj.killed = {}
            retobj.dices = user.round.dices
            retobj.c = PDEFINE.NOTIFY.MOVE_RESULT
            deskInfo:broadcast(cjson.encode(retobj))

            CMD.userSetAutoState('autoRollDice', delayTime, uid)
            LOG_DEBUG("chess enter win area, award 1 roll chance, uid:", uid, "step:", step, 'chessid:', chessid, 'afterstep:', afterstep, 'steps:', table.concat(user.round.steps, ','))
            return PDEFINE.RET.SUCCESS
        end
    end
    --是否进入安全区
    retobj.defend = 0
    local times = 0
    for _, s in pairs(user.round.steps) do
        if s == afterstep then
            times = times + 1
        end
    end
    if (times > 1 and afterstep ~= config.Win) or table.contain(config.Protect, afterstep) then
        retobj.defend = 1
    end
    --是否杀人
    local killedlist = {}
    if retobj.isOver == 0 then
        if (afterstep <= config.Quick or afterstep == config.QuickZero) and not table.contain(config.Protect, afterstep) then  --目标位置有棋子 要杀
            for _, muser in pairs(deskInfo.users) do
                if muser.uid ~= uid then
                    local _, killedChessids = checkKill(user, afterstep, muser)
                    for _, id in pairs(killedChessids) do
                        LOG_DEBUG("killed uid:", uid, 'afterstep:', afterstep, 'other uid:',muser.uid, 'steps:', table.concat(muser.round.steps, ','), 'chessid:', id)
                        table.insert(killedlist, {uid=muser.uid, chessid=id, seatid=muser.seatid})
                        killChess(user, muser, id)
                    end
                end
            end
        end
        if afterstep == config.QuickZero and deskInfo.conf.gametype == config.GameType.QUICK then --停留在58号位(quick玩法特有)
            for _, muser in pairs(deskInfo.users) do
                if muser.uid ~= uid then
                    local _, killedChessids = checkKillQuickZero(user, afterstep, muser)
                    for _, id in pairs(killedChessids) do
                        LOG_DEBUG("killed uid:", uid, 'afterstep:', afterstep, 'other uid:',muser.uid, 'steps:', table.concat(muser.round.steps, ','), 'chessid:', id)
                        table.insert(killedlist, {uid=muser.uid, chessid=id, seatid=muser.seatid})
                        killChess(user, muser, id)
                    end
                end
            end
        end
        LOG_DEBUG("after moveChess, uid:", uid, 'steps:', table.concat(user.round.steps, ','), 'killedlist:', cjson.encode(killedlist))

        retobj.nextgametype = config.ActionType.ROLL
        if not table.empty(killedlist) then
            user.state = PDEFINE.PLAYER_STATE.Draw
            LOG_DEBUG("kill chess, uid:", uid, "award 1 roll chance:")
            CMD.userSetAutoState('autoRollDice', delayTime, uid)
        else
            local canmove = false
            if #user.round.dices > 0 then
                canmove = checkCanMove(user)
            end
            LOG_DEBUG("not kill chess, uid:", uid, 'canmove:', canmove, 'steps:', table.concat(user.round.steps, ','), 'dices:', table.concat(user.round.dices, ','))
            if canmove then
                retobj.nextgametype = config.ActionType.RUN
                CMD.userSetAutoState('autoMoveChess', delayTime, uid)
            else
                user.state = PDEFINE.PLAYER_STATE.Wait
                user.round.dices = {}
                local nextUser = findNextUser(user.seatid)
                nextUser.state = PDEFINE.PLAYER_STATE.Draw
                deskInfo.round.activeSeat = nextUser.seatid
                CMD.userSetAutoState('autoRollDice', delayTime, nextUser.uid)
            end
        end
    end
    retobj.killed = killedlist
    retobj.dices = user.round.dices
    retobj.nextSeat = deskInfo.round.activeSeat
    retobj.c = PDEFINE.NOTIFY.MOVE_RESULT
    deskInfo:broadcast(cjson.encode(retobj))
    return PDEFINE.RET.SUCCESS
end

function CMD.enterAuto(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}

    if user.auto == 1 then
        return warpResp(retobj)
    end
    user.auto = 1 -- 进入托管
    deskInfo:autoMsgNotify(user, 1)

    return warpResp(retobj)
end

--! 出牌过程中 取消托管
function CMD.cancelAuto(source, msg)
    local recvobj  = msg
    LOG_DEBUG('cancelAuto, msg:', recvobj)
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if user.auto == 0 then
        LOG_DEBUG("cancelAuto auto==0  uid:", uid)
        return warpResp(retobj)
    end

    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    retobj.delayTime = deskInfo.delayTime
    if user.state == PDEFINE.PLAYER_STATE.Discard then
        CMD.userSetAutoState('autoMoveChess', retobj.delayTime, uid)
    elseif user.state == PDEFINE.PLAYER_STATE.Draw then
        CMD.userSetAutoState('autoRollDice', retobj.delayTime, uid)
    end
    deskInfo:autoMsgNotify(user, 0, retobj.delayTime)

    return warpResp(retobj)
end

-- 换桌子
function CMD.switchDesk(source, msg)
    local spcode = 0
    local uid = msg.uid
    if (deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY) then
        spcode = agent:switchDesk(msg)
    else
        local user = deskInfo:findViewUser(uid)
        -- 观战的可以换桌
        if user then
            spcode = agent:switchDesk(msg)
        else
            spcode = 1
        end
    end
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = spcode,
    }
    return warpResp(retobj)
end

-- 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, _agent)
    deskInfo:updateUserAgent(uid, _agent)
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local deskInfoStr = deskInfo:toResponse(msg.uid)
    if not deskInfoStr then
        return
    end
    local bet = deskInfo.bet
    for _, user in pairs(deskInfoStr.users) do
        user.wincoinshow = user.settlewin * bet
    end

    local now = os.time()
    local autoTime = deskInfo.round.autoTime or 0
    local delayTime = deskInfo.delayTime
    if autoTime > now then
        delayTime = autoTime - now
    end
    deskInfoStr.round.delayTime = delayTime
    deskInfoStr.seat = deskInfo.conf.seat

    return deskInfoStr
end

-- 用户在线离线
function CMD.offline(source, offline, uid)
    agent:offline(offline, uid)
end

-- 用户更改麦克风状态
function CMD.updateUserMic(source, msg)
    return agent:updateUserMic(msg)
end

-- 通知用户比赛结束
function CMD.updateRaceStatus(source, msg)
    return agent:updateRaceStatus(msg)
end

-- 是否自动加机器人
local function autoAiJoin()
    return true
end

-- 创建房间
function CMD.create(source, cluster_info, msg, ip, deskid, newplayercount, gameid)
    -- 实例化桌子
    deskInfo = baseDeskInfo(GAME_NAME, gameid, deskid)
    -- 绑定自定义方法
    ---@type DeskInfoFunc
    deskInfo.func = {
        initDeskRound = initDeskInfoRound,
        initUserRound = initUserRound,
        startGame = startGame,
        setAutoReady = setAutoReady,
        assignSeat = assignSeat,
    }
    msg.conf.minseat = 2
    if msg.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and msg.conf.seat then
        msg.conf.minseat = msg.conf.seat
    end
    deskInfo.seatList = {4, 2, 3, 1}

    -- 实例化游戏
    agent = baseAgent(gameid, deskInfo)
    -- 绑定自定义方法
    ---@type AgentFunc
    agent.func = {
        gameOver = gameOver,
        autoAiJoin = autoAiJoin,
    }
    -- 创建房间
    local err = agent:createRoom(msg, deskid, gameid, cluster_info)
    if err then
        return err
    end
    initDesk()

    if msg.sid then
        stgy:load(msg.sid, gameid)
    end

    -- 获取桌子回复
    local deskInfoStr = deskInfo:toResponse(deskInfo.owner)

    return PDEFINE.RET.SUCCESS, deskInfoStr
end

function CMD.setPlayerExit(source, uid)
    return deskInfo:setPlayerExit(uid)
end

-- 加入房间
function CMD.join(source, cluster_info, msg, ip)
    return cs(function()
        local uid = msg.uid
        local err, retobj = agent:joinRoom(msg, cluster_info)
        if err then
            return err, retobj
        end
        -- 获取加入房间回复
        local retobj = agent:joinRoomResponse(msg.c, uid)

        -- 检测是否可以开始游戏
        local canStart = agent:checkStart()
        LOG_DEBUG("cmd.join uid:", uid, ' canStart:', canStart, ' users:', #deskInfo.users)
        if canStart then
            startGame(3)
        end
        return warpResp(retobj)
    end)
end

-- 准备，如果是私人房，则有这个阶段
function CMD.ready(source, msg)
    local errono = deskInfo:userReady(msg.uid)
    if errono == PDEFINE.RET.ERROR.COIN_NOT_ENOUGH then
        local retobj  = {code = PDEFINE.RET.SUCCESS, c = math.floor(msg.c), uid=msg.uid, spcode=PDEFINE.RET.ERROR.COIN_NOT_ENOUGH}
        return PDEFINE.RET.SUCCESS, retobj
    end
    return PDEFINE.RET.SUCCESS
end

-- 观战坐下
function CMD.seatDown(source, msg)
    return agent:seatDown(msg)
end

--! 语聊的按钮
function CMD.chatIcon(source, msg)
    agent:actChatIcon(msg)
    return PDEFINE.RET.SUCCESS
end

-- 发送聊天信息
function CMD.sendChat(source, msg)
    agent:sendChat(msg)
    return PDEFINE.RET.SUCCESS
end

-- 房主解散房间
function CMD.dismissRoom(source)
    return deskInfo:dismissRoom()
end

-- 剔除一个观战玩家
function CMD.removeViewer(source, uid)
    local viewer = deskInfo:findViewUser(uid)
    if viewer then
        deskInfo:viewExit(uid)
        pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
    end
end

-- 更新玩家信息
function CMD.updateUserInfo(source, uid)
    agent:updateUserInfo(uid)
end

-------- API更新桌子里玩家的金币 --------
function CMD.addCoinInGame(source, uid, coin, diamond)
    LOG_DEBUG("addCoinInGame uid:",uid, ' coin:', coin, ' diamond:', diamond)
    agent:addCoinInGame(uid, coin, diamond)
end

------ api取牌桌信息 ------
function CMD.apiGetDeskInfo(source,msg)
    local deskInfoStr = deskInfo:toResponse()
    return deskInfoStr
end

------ api停服清房 ------
function CMD.apiCloseServer(source,csflag)
    closeServer = csflag
end

------ api解散房间 ------
function CMD.apiKickDesk(source)
    agent:apiKickDesk()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.retpack(f(source, ...))
    end)

    collectgarbage("collect")
end)