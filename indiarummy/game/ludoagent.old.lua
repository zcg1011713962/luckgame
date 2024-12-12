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

---@type BetStgy
local stgy = BetStgy.new()

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

--控制参数
--参数值一般规则：为1时保持平衡；大于1时玩家buff；小于1时玩家debuff
local ControlParams = { --控制参数，
    robot_roll_high_dice_prob = 0.7,    --机器人使用高权重筛子的概率(注意，实际概率是1-0.7=0.3)
    robot_direct_arrive_end_prob = 0.7,--机器人直接进入终点的概率(0.17->0.3)
    robot_kill_user_prob = 0.75,        --机器人直接杀死玩家棋子的概率(0.17->0.25)
}

---@type BaseDeskInfo @instance of dominoagent
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例
local USER_ROLLING = {}
local USER_MOVING = {}
local LastDealerSeat = nil
--[[
    ludo agent
]]

local config = {
    -- 错误码
    Spcode = {
        ParamsError = 1,  -- 参数错误
        UserNotFound = 2,  -- 用户未找到
        UserStateError = 3,  -- 用户状态错误
        CanNotPass =  202,  -- 不能pass
        CanNotConnect = 203, --不能接龙
    },
    AutoDelayTime = 10,
    AutoMoveTimeout = 1,
    AutoDelayMoveTime = 3,
    AutoDelayDiceTime = 3,
    WaitDiamondTime = 2,  -- 等待使用钻石重置的时间
    Diamond = 3, --钻石价格
    Diamonds = {3,8, 20}, --摇筛子后，花钻石继续摇的价格
    Protect = {1,9,14,22,27,35,40,48}, --保护的位置列表
    Quick = 51, --quick玩法截停的位置
    Win = 57, --到达这个步数算赢
    QuickZero = 58, --这个位置比较特殊，本来应该是-1，兼容客户端定义为58
    MaxDot = 6, --连续点数
    NextGameType = {
        ['RUN'] = 1,
        ['ROLL'] = 2
    },
    GameType = {
        ['QUICK'] = 1, --quick 
        ['CLASSIC'] =2, --classic: 4枚棋子全部到终点算赢，过quick不需要杀敌;如果我的2个棋子在同1格子中，不被杀,对方可以跳过或落到同1格子
        ['MASTER'] = 3, --master
--[[
    quick:
    1、1个棋子到终点就算赢
    2、过quick需至少杀敌1次
    3、开局第1个棋子就在1位置
    4、如果我的2个棋子在同1格子中，不被杀,对方可以跳过或落到同1格子
    master:
    1、4枚棋子全部到终点算赢
    2、过quick需要至少杀敌1次;
    3、如果两个相同颜色的标记落在同一个盒子里，那么它们来自一个联合标记。联合标记将充当墙，你或你的对手不能越过或降落在上面。联合标记只能在掷骰子时移动（2,4， 6）和一半的数字。 Eg.如果你掷2，那么联合令牌只会移动1格，如果它落在保险箱上，联合令牌会被打破[全球/星]
]]
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

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

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

local function initDesk()
    deskInfo.conf.gametype = config.GameType.CLASSIC --玩法
    if deskInfo.gameid == PDEFINE_GAME.GAME_TYPE.LUDO_QUICK then
        deskInfo.conf.gametype = config.GameType.QUICK
    end
    --deskInfo.seat = 4
    --deskInfo.minSeat = 2 --最少可玩人数
end

local function initDeskInfoRound(uid, seatid)
    deskInfo.round = {}
    deskInfo.round.activeSeat = seatid -- 当前活动座位
    deskInfo.round.settle = {} -- 小结算
    deskInfo.round.dealer = { ----此把的庄家(庄家先出)
        uid = uid,
        seatid = seatid
    }
    deskInfo.round.winuid = 0 --赢家
    deskInfo.round.preActiveUid = 0 --上一次操作的uid  他的状态是时间到了后修改
    deskInfo.round.pannel = {} --按座位记录 摇骰子, 杀，被杀
    -- deskInfo.conf.gametype = config.GameType.CLASSIC --玩法
    -- deskInfo.seat = 4
    -- deskInfo.minSeat = 2 --最少可玩人数
end

---@param user BaseUser
local function initUserRound(user)
    user.state       = PDEFINE.PLAYER_STATE.Wait
    user.round = {}
    user.round.isWin       = 0  -- 是否赢了
    user.round.chess = {1,2,3,4} --每人4颗棋子
    user.round.times = 0 --摇动骰子的次数
    user.round.steps = {0,0,0,0} --棋子位置
    user.round.dices = {} --本次摇骰子的数据，最大3个,每次自己走完棋子就清空
    user.round.resetTimes = 0 --用户重摇骰子次数
    user.round.kill = 0 --杀他人骰子次数
    if deskInfo.conf.gametype == config.GameType.QUICK then
        user.round.steps = {1,0,0,0}
        user.round.chess = {2,3,4}
    end
end

local function getDelayTime(user)
    local delayTime = config.AutoDelayTime
    if not user.cluster_info then
        delayTime = math.random(1, 2)
    else
        if user.auto == 1 then
            delayTime = 2
        end
    end
    return delayTime
end

local function assignSeat()
    local seatid_list = {1, 3 , 2, 4}
    deskInfo:print("assignSeat deskInfo.seatList:", deskInfo.seatList)
    for _, seatid in ipairs(seatid_list) do
        if table.contain(deskInfo.seatList, seatid) then
            for i=#deskInfo.seatList, 1, -1 do
                if deskInfo.seatList[i] == seatid then
                    table.remove(deskInfo.seatList, i)
                    break
                end
            end
            deskInfo:print("assignSeat deskInfo.seatList return:", seatid)
            return seatid
        end
    end
end

-- 自动摇骰子
local function autoRollDice(uid)
    deskInfo:print("autoRollDice 自动摇骰子 uid:".. uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        DEBUG("autoRollDice uid:", uid, ' user not found')
        return
    end
    if deskInfo.round.activeSeat ~= user.seatid then
        deskInfo:print("autoRollDice 自动摇骰子, 不是他摇 uid:".. uid)
        return
    end

    user:clearTimer()
    if deskInfo.round.preActiveUid ~= uid then
        local preUser = deskInfo:findUserByUid(deskInfo.round.preActiveUid)
        if preUser then
            preUser.state = PDEFINE.PLAYER_STATE.Wait
            preUser.round.dices = {}
        end
    end
    
    user.state = PDEFINE.PLAYER_STATE.Draw
    local delayTime = 1
    if user.cluster_info then
        if user.auto == 0 then
            user.auto = 1
            delayTime = config.AutoDelayTime
            deskInfo:autoMsgNotify(user, 1, 0)
        end
    end
    --skynet.timeout(delayTime, function()
        local msg = {
            ['c'] = 26901,
            ['uid'] = uid,
            ['is_auto'] = 1,
        }
        CMD.rollDice(nil, msg)
    --end)
end

local SeatMap = { --classic玩法 全部转换到位置1的坐标, 从仓库出来第一个位置为1
    [1] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51}, --左下
    [2] = {14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,1,2,3,4,5,6,7,8,9,10,11,12}, --左上
    [3] = {27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25}, --右上
    [4] = {40,41,42,43,44,45,46,47,48,49,50,51,52,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38}, --右下
}
--检查是否可杀
local function checkKillMap(myseatid, mystep, seatid, steps)
    local killed = false
    local killedList = {}
    local seatMap = SeatMap
    local checkOthersPosCnt = function (seatid, myseatid, pos)
        local cnt = 0
        for _, muser in pairs(deskInfo.users) do
            if muser.seatid ~= myseatid and muser.seatid ~= seatid then
                for k, s in pairs(muser.round.steps) do
                    local lo = seatMap[muser.seatid][s]
                    if lo == pos then
                        cnt = cnt + 1
                    end
                end
            end
        end
        return cnt
    end

    local myAfterChange = seatMap[myseatid][mystep] --转换到位置1的坐标
    for k, s in pairs(steps) do
        if s > 0 then
            local lo = seatMap[seatid][s]
            if lo and lo == myAfterChange and table.count(steps, s) == 1 and checkOthersPosCnt(seatid, myseatid, lo) == 0 then
                killed = true
                table.insert(killedList, k)
            end
        end
    end
    return killed, killedList
end

local SeatMapQuickZero = {
    [1] = {
        [1] = {[58]=58}, --左下
        [2] = {[39]=58}, --左上
        [3] = {[26]=58}, --右上
        [4] = {[5]=58}, --右下
    },
    [2] = {
        [1] = {[58]=58}, --左下
        [2] = {[39]=58}, --左上
        [3] = {[26]=58}, --右上
        [4] = {[5]=58}, --右下
    },
    [3] = {
        [1] = {[26]=58}, --左下
        [2] = {[13]=58}, --左上
        [3] = {[58]=58}, --右上
        [4] = {[39]=58}, --右下
    },
    [4] = {
        [1] = {[39]=58}, --左下
        [2] = {[26]=58}, --左上
        [3] = {[13]=58}, --右上
        [4] = {[58]=58}, --右下
    }
}
--检查是否可杀（QuickZero）
local function checkKillMapQuickZero(myseatid, mystep, seatid, steps)
    LOG_DEBUG('checkKillMapQuickZero ', myseatid, mystep, seatid, steps)
    local killed = false
    local killedList = {}

    local checkOthersPosCnt = function (seatid, myseatid, pos, userSeatMap)
        local cnt = 0
        for _, muser in pairs(deskInfo.users) do
            if muser.seatid ~= myseatid and muser.seatid ~= seatid then
                for k, s in pairs(muser.round.steps) do
                    local lo = userSeatMap[muser.seatid][s]
                    if lo and lo == pos then
                        cnt = cnt + 1
                    end
                end
            end
        end
        return cnt
    end

    local seatMap = SeatMapQuickZero[myseatid]
    LOG_DEBUG('checkKillMapQuickZero ', 'myseatid:', myseatid, ' seatMap:', seatMap)
    local myAfterChange = seatMap[mystep] --转换到位置1的坐标
    for k, s in pairs(steps) do
        if s > 0 then
            local lo = seatMap[seatid][s]
            if lo and lo == myAfterChange and table.count(steps, s) == 1 and checkOthersPosCnt(seatid, myseatid, lo, seatMap) == 0 then
                killed = true
                table.insert(killedList, k)
            end
        end
    end
    return killed, killedList
end

--检查是否能杀死其他棋子
local function canKillOtherByStep(user, step)
    if step <= config.Quick and not table.contain(config.Protect, step) then
        for _, muser in pairs(deskInfo.users) do
            if muser.cluster_info and muser.uid ~= user.uid then
                local killed = checkKillMap(user.seatid, step, muser.seatid, muser.round.steps)
                if killed then
                    return true
                end
            end
        end
    end
    return false
end

--检查是否安全，如果后面4个范围内跟有其他玩家棋子，则被判定为不安全
local function checkSafe(user, step, cnt)
    if step < 1 or step > config.Quick then return true end
    if table.contain(config.Protect, step) then return true end
    cnt = cnt or 4
    local seatMap = SeatMap
    local pos = seatMap[user.seatid][step]
    for _, muser in pairs(deskInfo.users) do
        if muser.uid ~= user.uid then
            for _, sp in ipairs(muser.round.steps) do
                local mpos = seatMap[muser.seatid][sp]
                if mpos and pos > mpos and pos < mpos + cnt then
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
    for _, dice in ipairs(user.round.dices) do
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
            --1，如果能踢走玩家的棋子，则优先级为5
            --2，如果能进终点，则优先级4
            --3, 如果能进安全区，则优先级为3
            --4，如果能摆脱其他棋子，则优先级为2
            --5，如果离开安全区，则优先级为0
            --6，如果超到其他棋子前面，则优先级为0
            --7，如果路上少于2个棋子，且有棋子能出家，且安全，则优先级为2
            --8，其余情况，优先级为1
            local step = user.round.steps[chess] or 0
            local weight = 1
            if table.contain(user.round.chess, chess) and dice == config.MaxDot then
                local onroad = 0
                for _, p in ipairs(user.round.steps) do
                    if p > 0 and p < config.Win then onroad = onroad + 1 end
                end
                if onroad < 3 then
                    weight = 3
                elseif onroad > 3 then  --别出太多
                    weight = 0
                end
            else
                local newStep = step + dice
                if canKillOtherByStep(user, newStep) then
                    weight = 5
                elseif newStep == config.Win then
                    weight = 4
                elseif (step <= config.Quick and newStep > config.Quick and newStep < config.Win) or table.contain(config.Protect, newStep) then
                    weight = 3
                elseif not checkSafe(user, step) and checkSafe(user, newStep, 6) then
                    weight = 2
                elseif table.contain(config.Protect, step) then
                    weight = 0
                elseif not checkSafe(user, newStep, 2) then
                    weight = 0
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
local function autoMoveChess(params)
    local uid = params[1]
    local hosting = params[2]
    deskInfo:print("自动走棋子 uid:".. uid)
    if nil == hosting then
        hosting = true --自动托管
    end
    
    local user = deskInfo:findUserByUid(uid)
    if not user then
        DEBUG("自动走棋子 uid:", uid, ' user not found')
    end
    if deskInfo.round.activeSeat ~= user.seatid then
        deskInfo:print("自动走棋子: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
        return
    end
    if deskInfo.round.preActiveUid ~= uid then
        local preUser = deskInfo:findUserByUid(deskInfo.round.preActiveUid)
        if preUser then
            preUser.state = PDEFINE.PLAYER_STATE.Wait
        end
    end
    
    deskInfo.round.activeSeat = user.seatid
    user.state = PDEFINE.PLAYER_STATE.Discard
    user:clearTimer()
    local delayTime = 1
    if hosting then
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                delayTime = config.AutoDelayTime
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end
    end
    --skynet.timeout(delayTime, function()
        deskInfo:print("autoMoveChess user.round.steps:", table.concat(user.round.steps, ','), ' dices:', table.concat(user.round.dices, ','))
        local res = findMoveChessAndDice(user)
        deskInfo:print("autoMoveChess:", ' uid:', uid, ' step:', res.dice, ' chessid:', res.chess)

        local msg = {
            c = 26902,
            uid = uid,
            is_auto = 1,
            step = res.dice,
            chessid = res.chess
        }
        local _, resp = CMD.moveChess(nil, msg)
        resp.is_auto = 1
        if user.cluster_info then
            if user.isexit == 0 and resp.spcode == 0 then
                pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(resp))
                deskInfo:print("autoRollDice msg:", msg, "返回: ", resp)
            end
        end
    --end)
end

-- 自动准备
local function autoReady(uid)
    return cs(function()
        deskInfo:print("自动准备 uid:".. uid)
        local user = deskInfo:findUserByUid(uid)
        
        if not user or user.state == PDEFINE.PLAYER_STATE.Ready then
            return 
        end
        user:clearTimer()

        local msg = {
            ['c'] = 26903,
            ['uid'] = uid,
        }
        CMD.ready(nil, msg)
    end)
end

local function setAutoReady(delayTime, uid)
    CMD.userSetAutoState('autoReady', delayTime, uid)
end

--! agent退出
function CMD.exit()
    if deskInfo.conf and deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.VIP then
        pcall(cluster.send, "master", ".balviproommgr", "syncVipRoomData", deskInfo.gameid, deskInfo.deskid, deskInfo.users, deskInfo.panel.score)
    end
    USER_ROLLING = {}
    USER_MOVING = {}
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
    deskInfo:print("开始游戏: deskid:", deskInfo.uuid)
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
    retobj.activeUid = deskInfo.round.dealer['uid']
    retobj.dealerUid = deskInfo.round.dealer['uid']

    -- if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then --可能改动了座位，需要同步下去
        local users = table.copy(deskInfo.users)
        for _, user in ipairs(users) do
            -- 去掉连接信息
            user.cluster_info = nil
            -- 去掉定时器信息
            user.timer = nil
            user.timer = nil
            user.luckBuff = nil
            user.isexit = nil
            user.realCoin = nil
            user.settlewin = nil
            user.winTimes = nil
            user.wincoin = nil
            user.wincoinshow = nil
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
    -- end

    for _, muser in pairs(deskInfo.users) do
        deskInfo:print("roundstart uid:", muser.uid, ' seatid:', muser.seatid)
    end

    -- 切换桌子状态
    deskInfo:updateState(PDEFINE.DESK_STATE.PLAY)
    deskInfo:print("ludo roundStart:", #deskInfo.users)
    -- 开始发牌
    retobj.delayTime = deskInfo.delayTime
    for _, user in pairs(deskInfo.users) do
        -- 庄家切换到出牌阶段
        if user.seatid == deskInfo.round.dealer['seatid'] then
            -- 切换状态
            user.state = PDEFINE.PLAYER_STATE.Draw --摇骰子状态
            deskInfo.round.activeSeat = user.seatid
            -- 设置定时器
            deskInfo:print("roundStart autoDiscard delayTime:", deskInfo.delayTime, ' uid:', user.uid)
            local autoTime = deskInfo.delayTime + 4  -- 第一次出牌设置慢一点
            if not user.cluster_info then
                autoTime = math.random(1,3)
            end
            CMD.userSetAutoState('autoRollDice', autoTime, user.uid)
        else
            user.state = PDEFINE.PLAYER_STATE.Wait
        end
        
        deskInfo:print("round start uid:", user.uid, ' chess:',user.round.chess)
        -- 广播消息
        if user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    -- 广播给观看者
    deskInfo:broadcastViewer(cjson.encode(retobj))
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
            local oldDealer = deskInfo:findUserByUid(dealer['uid'])
            if not oldDealer then --庄家可能离开了
                dealer = deskInfo.users[math.random(#deskInfo.users)]
            end
        end
    end

    -- deskInfo.minSeat = 2
    -- deskInfo.seat = 2
    deskInfo:print("dealer", dealer.uid, dealer.seatid)
    LastDealerSeat = dealer.seatid
    -- 初始化桌子信息
    deskInfo:initDeskRound(dealer.uid, dealer.seatid)
    -- deskInfo:print("deskInfo ", deskInfo)
    if delayTime then
        delayTime = delayTime * 100
    else
        delayTime = 30
    end
    
    skynet.timeout(delayTime, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart()
    end)
end

-- 游戏结束，大结算
local function gameOver(isDismiss)
    deskInfo:print("结束了，要开始结算了:", deskInfo.deskid)
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
function CMD.userSetAutoState(type,autoTime,uid, hosting)
    if nil == hosting then
        hosting = true
    end
    if hosting then
        autoTime = autoTime + 1
    end

    deskInfo:print("设定玩家定时器:", type, " uid:", uid)
    -- 调试期间，机器人只间隔2秒操作
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    if not user then
        return
    end
    user:clearTimer()
    deskInfo.round.autoTime = autoTime + os.time() --自动截止时间, 断线重连用
    if hosting then
        if not user.cluster_info or (type ~= "autoReady" and user.auto == 1) then
            -- 如果是第一次出牌，则时间拉长一点
            if user.state == PDEFINE.PLAYER_STATE.Draw then
                if type ~= 'autoRollDice' then
                    autoTime = 6
                end
            else
                if user.auto == 1 then
                    autoTime = 1
                else
                    local maxTime = autoTime > PDEFINE_GAME.NUMBER.maxOptTime and PDEFINE_GAME.NUMBER.maxOptTime or autoTime
                    local minTime = autoTime < PDEFINE_GAME.NUMBER.minOptTime and autoTime or PDEFINE_GAME.NUMBER.minOptTime
                    autoTime = math.random(minTime, maxTime)
                end
            end
        end
    end
    
    
    -- 自动摇骰子
    deskInfo:print("设定玩家定时器2:", type, " user:", uid, ' autoTime:', autoTime, ' user.auto:',user.auto)
    if type == "autoRollDice" then
        user:setTimer(autoTime, autoRollDice, uid)
    end
    -- 自动走棋子
    if type == "autoMoveChess" then
        user:setTimer(autoTime, autoMoveChess, {uid, hosting})
    end
    -- 自动准备
    if type == "autoReady" then
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
    deskInfo:print("dominuo applyDismiss retobj:", retobj)
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

local function canSkipMove(user)
    local all_steps = true
    if table.contain(user.round.dices, config.MaxDot) and #user.round.chess > 0 then
        all_steps = false
        return all_steps;
    end
    for id, s in pairs(user.round.steps) do
        if s == config.QuickZero and deskInfo.conf.gametype == config.GameType.QUICK then
            all_steps = false
            break
        end
        if s > 0 then
            for _, dice in pairs(user.round.dices) do
                if (config.Win -s) >= dice then
                    all_steps = false
                    break
                end
            end
        end
    end
    return all_steps
end

local function calCanMove(steps, dices)
    local outSize, canMove = 0, 0
    for _, s in pairs(steps) do
        if s > 0 and s < config.Win then
            outSize = outSize + 1
            for _, d in pairs(dices) do
                if (config.Win -s) >= d then
                    canMove = canMove + 1
                end
            end
        end
        if deskInfo.conf.gametype == config.GameType.QUICK and s == config.QuickZero then
            canMove = canMove + 1
        end
    end
    return outSize, canMove
end

-- 外面已经判断了有棋子可走情况下，判断是否只有1个棋子可以移动
-- 只有3中情况: 6,x(1-5) 或 6,6,x(1-5) 或者 x(1-5)
local function onlyOnechessCanMove(steps, chess, dices)
    local chessSize = table.size(chess) --家里有几个棋子
    local outSize, canMove = calCanMove(steps, dices) --outSize:从家里出来了，但没到终点的棋子有几个 , canMove:此次可移动的外面的棋子数
    local diceSize = #dices
    if diceSize >=2 then --dices: 6,x(1-5) 或 6,6,x(1-5)
        if chessSize == 1 and outSize==0 then --家里有1颗，其他3颗已经到终点
            return true
        end
        if chessSize==0 then
            if outSize == 1 or canMove ==1 then --家里没有:外面只有1颗棋子 或者有多颗棋子(但只有1个可以走)
                return true
            end
        end
    else --dices中只有1颗 1-5的棋子
        if outSize == 1 or canMove == 1 then  --外面只有1颗； 或者有多颗棋子，但只有1个可以走
            return true
        end
    end
    return false
end

local function calCoin(resetTimes)
    local diamond = config.Diamonds[1]
    if config.Diamonds[resetTimes] then
        diamond = config.Diamonds[resetTimes]
    end
    if resetTimes >= #config.Diamonds then
        diamond = config.Diamonds[#config.Diamonds]
    end
    return diamond
end

-- 要的骰子不满意，花钻石重置
function CMD.resetDice(source, msg)
    deskInfo:print("cmd.resetDice msg:", msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    local coin = calCoin((user.round.resetTimes + 1))
    local retobj = {c=recvobj.c, code=PDEFINE.RET.SUCCESS, spcode=0, uid=uid, coin = coin}
    deskInfo:print("CMD.resetDice uid:",uid, 'coin:',user.coin, ' state:', user.state)
    if deskInfo.round.preActiveUid ~= uid then
        deskInfo:print("CMD.resetDice 上一个不是他 uid:", uid, "上一个:",deskInfo.round.preActiveUid,' nextActiveSeat:', deskInfo.round.activeSeat)
        retobj.spcode = PDEFINE.RET.ERROR.NOT_THIS_USER
        return warpResp(retobj)
    end
    -- if #user.round.dices == 0  then
    --     deskInfo:print("CMD.resetDice 至少要先摇了才能显示 uid:", uid)
    --     retobj.spcode = PDEFINE.RET.ERROR.DICES_MIN_ERR
    --     return warpResp(retobj)
    -- end

    if (#user.round.dices == 1 or #user.round.dices==2) and user.round.dices[#user.round.dices] == config.MaxDot then
        deskInfo:print("CMD.resetDice 摇了1次，上一个是6，不能再摇了 uid:", uid)
        retobj.spcode = PDEFINE.RET.ERROR.DICES_RULE_ERR
        return warpResp(retobj)
    end
    
    if user.coin < coin then
        deskInfo:print("CMD.resetDice 金币不够 uid:", uid, ' coin:',user.coin)
        retobj.spcode = PDEFINE.RET.ERROR.LEAGUE_USER_DIAMOND
        return warpResp(retobj)
    end
    
    user:clearTimer()
    deskInfo:print("CMD.resetDice 清理掉了自己的定时器 uid:", uid)
    for _, muser in pairs(deskInfo.users) do
        if muser.uid ~= uid then
            muser:clearTimer() --打断流程
            deskInfo:print("CMD.resetDice 清理掉了其他人的定时器 uid:", muser.uid)
            muser.state = PDEFINE.PLAYER_STATE.Wait
        end
    end
    user.round.resetTimes = user.round.resetTimes + 1
    user.coin = user.coin - coin
    if user.cluster_info then
        local update_data = {
            coin = -coin,
            act = 'ludogame'
        }
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "player", "setPersonalExp", uid, update_data)
    end

    deskInfo.round.activeSeat = user.seatid
    user.state = PDEFINE.PLAYER_STATE.Draw
    table.remove(user.round.dices) --把上一次的结果清掉
    local reqMsg = {
        ['c'] = 26901,
        ['uid'] = uid,
    }
    CMD.rollDice(nil, reqMsg)
    
    return warpResp(retobj)
end


--[[
    摇骰子
   1、摇到6就继续摇，最多3次，连续3个6本次作废，轮到下一个人摇
   2、如果我的棋子都已超过quick(51)位置，摇的数字大于距离最大位置57的步数,不用走棋子,直接作废，轮到下一个人摇
   3、如果摇到6，从家里移出棋子，只能走1步
   4、正常，我摇完，就轮到自己走棋子
]]
function CMD.rollDice(source, msg)
    deskInfo:print("cmd.rollDice msg:", msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    deskInfo.print(' USER_ROLLING[uid]:', USER_ROLLING[uid], ' uid:',uid)
    if nil == USER_ROLLING[uid] then
        USER_ROLLING[uid] = true
    else
        return
    end
    local is_auto = recvobj.is_auto
    local retobj  = {c = recvobj.c, uid = uid, code =PDEFINE.RET.SUCCESS, spcode=0}
    if is_auto then
        retobj.is_auto = is_auto
    end
    local user = deskInfo:findUserByUid(uid)
    if deskInfo.round.activeSeat ~= user.seatid then
        deskInfo:print("CMD.rollDice 下一个不是他 uid:", uid, ' nextActiveSeat:', deskInfo.round.activeSeat)
        USER_ROLLING[uid] = nil
        return
    end
    if user.state ~= PDEFINE.PLAYER_STATE.Draw then
        deskInfo:print("CMD.rollDice 用户状态不对 uid:", uid, ' state:',user.state)
        USER_ROLLING[uid] = nil
        return
    end

    user:clearTimer()
    deskInfo:print("CMD.rollDice 清理自己的定时器 uid:", uid)
    local random = math.random(1, 6)
    local cc_dice = getControlParam("robot_roll_high_dice_prob")
    if not user.cluster_info and math.random() > cc_dice then
        random = commonUtils.randByWeight(HighDiceWeight)
    end
    if #user.round.chess == 4 and table.count(user.round.dices, config.MaxDot)==0 then
        local threshold = 60
        if user.cluster_info then threshold = 40 end
        if math.random(1, 100) <= threshold then
            random = 6
        end
    else
        if not user.cluster_info then --机器人
            local cc_end = getControlParam("robot_direct_arrive_end_prob")
            local cc_kill = getControlParam("robot_kill_user_prob")
            local leftstep = 0
            if math.random() > cc_end then
                for _, step in pairs(user.round.steps) do
                    if step > config.Quick and step < config.Win then
                        leftstep = config.Win - step
                        break
                    end
                end
                if leftstep > 0 then
                    random = leftstep --有棋子进入了快要胜利的阶段，直接出对应的数
                end
            end

            if leftstep == 0 and math.random() > cc_kill then
                --增加击杀他人棋子的
                local dice = 0
                for _, step in pairs(user.round.steps) do
                    if step > 0 and step < config.Quick then
                        for i =1, 6 do
                            if not table.contain(config.Protect, (step + i)) then
                                for _, muser in pairs(deskInfo.users) do
                                    if muser.cluster_info and muser.uid ~= user.uid then
                                        local killed = checkKillMap(user.seatid, (step+i), muser.seatid, muser.round.steps)
                                        if killed then
                                            dice = i
                                            goto randomedice
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                ::randomedice::
                if dice > 0 then
                    random = dice
                end
            end
        end
    end

    local autoPass = 0 --是否因为不能走棋子才pass的
    deskInfo.round.preActiveUid = uid
    retobj.nextgametype = config.NextGameType.RUN --下一步走步数
    retobj.canreset = 0  -- 这里默认关闭，这个项目不需要钻石重置
    retobj.nextSeat = user.seatid --下一步谁操作
    retobj.delayTime = config.AutoDelayTime
    deskInfo:print("11我摇骰子:", user.uid, ' 摇到点数:', random, ' seatid:', user.seatid ,' 家里chess:', table.concat(user.round.chess, ','), ' steps:', table.concat(user.round.steps,','), ' 已有dices:', table.concat(user.round.dices,','))
    local autoMove = false --是否直接自己自动走棋子, 
    if random == config.MaxDot then --摇到6了继续摇，除非连续3次6就下一位
        retobj.nextgametype = config.NextGameType.ROLL
        table.insert(user.round.dices, random)
        deskInfo:print("我摇到了6点, uid:", user.uid, ' random:', random)
        if table.size(user.round.dices) >= 3 then
            if table.count(user.round.dices, config.MaxDot) >= 3 then
                user.state = PDEFINE.PLAYER_STATE.Wait --走棋子状态
                user.round.dices = {} --3个6直接跳过自己，清理掉自己的骰子
                local nextUser = findNextUser(user.seatid)
                nextUser.state = PDEFINE.PLAYER_STATE.Draw
                retobj.nextSeat = nextUser.seatid
                deskInfo.round.activeSeat = nextUser.seatid
                deskInfo:print("我有3个骰子,3个六，下一个位走, 自己不能走 uid:", user.uid, ' dices:', table.concat(user.round.dices, ','), ' steps:' , table.concat(user.round.steps, ','), ' 下一位:', nextUser.uid, nextUser.seatid)
                local delayTime = config.WaitDiamondTime
                CMD.userSetAutoState('autoRollDice', delayTime, nextUser.uid, false)
                autoPass = 1
            else
                if canSkipMove(user) then --里面可能有非6的
                    user.state = PDEFINE.PLAYER_STATE.Wait --走棋子状态
                    user.round.dices = {} --自己不能走，清理掉自己的骰子
                    local nextUser = findNextUser(user.seatid)
                    nextUser.state = PDEFINE.PLAYER_STATE.Draw
                    retobj.nextSeat = nextUser.seatid
                    deskInfo.round.activeSeat = nextUser.seatid
                    deskInfo:print("我有3个骰子,但不能走 uid:", user.uid, ' dices:', table.concat(user.round.dices, ','), ' steps:' , table.concat(user.round.steps, ','), ' 下一位:', nextUser.uid, nextUser.seatid)
                    CMD.userSetAutoState('autoRollDice', getDelayTime(nextUser), nextUser.uid)
                    autoPass = 1
                else
                    deskInfo.round.activeSeat = user.seatid
                    user.state = PDEFINE.PLAYER_STATE.Discard
                    retobj.nextgametype = config.NextGameType.RUN
                    deskInfo:print("我有3个骰子，第3个是6点,摇到了其他数，下一个人自己走操作", user.uid,  user.seatid)
                    local delayTime = config.AutoDelayTime
                    local hosting = true
                    if onlyOnechessCanMove(user.round.steps, user.round.chess, user.round.dices) then
                        autoMove = true
                        hosting = false
                        if not user.cluster_info then
                            delayTime = config.AutoMoveTimeout --当我有棋子可走(1:家里3个，外面1个，摇的不是6; 或者 2:其他3已经到终点，只有1个在外面 或者 3:家里1个，摇到了6)，
                        else
                            delayTime = config.AutoDelayMoveTime
                        end
                    end
                    retobj.delayTime = delayTime
                    CMD.userSetAutoState('autoMoveChess', delayTime, user.uid, hosting)
                end
            end
        else
            retobj.canreset = 0
            deskInfo.round.activeSeat = user.seatid
            user.state = PDEFINE.PLAYER_STATE.Draw
            deskInfo:print("我再摇到6点后再摇, uid:", user.uid, ' 下一位自己继续摇:', user.uid)
            CMD.userSetAutoState('autoRollDice', getDelayTime(user), uid)
        end
    else
        table.insert(user.round.dices, random)
        local maxLeftStep = 0
        for _, s in pairs(user.round.steps) do
            local diff_step = config.Win - s
            if deskInfo.conf.gametype == config.GameType.QUICK and s == config.QuickZero then
                diff_step = config.Win
            end
            if diff_step > maxLeftStep then
                maxLeftStep = diff_step
            end
        end
        if maxLeftStep < random then --我棋子都已经快要赢了，需要的步数超过骰子的数
            user.state = PDEFINE.PLAYER_STATE.Wait
            user.round.dices = {}
            local nextUser = findNextUser(user.seatid)
            nextUser.state = PDEFINE.PLAYER_STATE.Draw
            retobj.nextSeat = nextUser.seatid
            deskInfo.round.activeSeat = nextUser.seatid
            CMD.userSetAutoState('autoRollDice', config.AutoDelayTime, nextUser.uid)
            deskInfo:print("我的棋子快要赢了, uid:", user.uid, ' nextuid:', nextUser.uid, 'chess:', user.round.chess)
            retobj.nextgametype = config.NextGameType.ROLL
            autoPass = 1
        else
            local hasSix = table.contain(user.round.dices, config.MaxDot)
            if #user.round.chess == 4 then 
                if not hasSix then --棋子都在家里,没有摇到6,下一位
                    user.state = PDEFINE.PLAYER_STATE.Wait
                    user.round.dices = {}
                    local nextUser = findNextUser(user.seatid)
                    nextUser.state = PDEFINE.PLAYER_STATE.Draw
                    retobj.nextSeat = nextUser.seatid
                    deskInfo.round.activeSeat = nextUser.seatid
                    deskInfo:print("我摇到了其他数，4个棋子都在家，下一个人操作", nextUser.uid,  nextUser.seatid, ' 我uid:', user.uid, ' 位置:', user.seatid)
                    CMD.userSetAutoState('autoRollDice', getDelayTime(nextUser), nextUser.uid)
                    retobj.nextgametype = config.NextGameType.ROLL
                    autoPass = 1 
                else
                    deskInfo.round.activeSeat = user.seatid
                    user.state = PDEFINE.PLAYER_STATE.Discard
                    retobj.nextgametype = config.NextGameType.RUN
                    deskInfo:print("我摇到了其他数，4个棋子都在家，但我有6，下一个人自己走操作", user.uid,  user.seatid)
                    CMD.userSetAutoState('autoMoveChess', getDelayTime(user), user.uid) --该我移动棋子
                end
            else
                local all_steps = true
                for _, s in pairs(user.round.steps) do
                    if deskInfo.conf.gametype == config.GameType.QUICK and s == config.QuickZero then
                        all_steps = false
                        break
                    end
                    if s > 0 and random <= (config.Win - s) then
                        all_steps = false
                        break
                    end
                end
                if all_steps and table.contain(user.round.dices, config.MaxDot) and not table.empty(user.round.chess) then --是不是包含6
                    all_steps = false
                end
                deskInfo:print("我摇到了非6点，uid:", uid," random:", random, ' all_steps:', all_steps, ' user.round.steps:', table.concat(user.round.steps, ','))
                if all_steps then
                    user.round.dices = {}
                    user.state = PDEFINE.PLAYER_STATE.Wait
                    local nextUser = findNextUser(user.seatid)
                    nextUser.state = PDEFINE.PLAYER_STATE.Draw
                    retobj.nextSeat = nextUser.seatid
                    deskInfo.round.activeSeat = nextUser.seatid
                    retobj.nextgametype = config.NextGameType.ROLL
                    deskInfo:print("我摇到了其他数 uid:", user.uid, ' random:', random, ' steps:', user.round.steps)
                    deskInfo:print("我摇到了其他数，有棋子不在家, 但都超过剩余步数了，下一个人操作", nextUser.uid,  nextUser.seatid)
                    CMD.userSetAutoState('autoRollDice', getDelayTime(nextUser), nextUser.uid)
                    autoPass = 1 
                else
                    deskInfo.round.activeSeat = user.seatid
                    user.state = PDEFINE.PLAYER_STATE.Discard
                    retobj.nextgametype = config.NextGameType.RUN
                    deskInfo:print("我摇到了其他数，有棋子不在家，下一个人自己走操作", user.uid,  user.seatid)
                    local delayTime = config.AutoDelayTime
                    local hosting = true
                    if onlyOnechessCanMove(user.round.steps, user.round.chess, user.round.dices) then
                        autoMove = true
                        hosting = false
                        if not user.cluster_info then
                            delayTime = config.AutoMoveTimeout --当我有棋子可走(家里3个，外面1个，摇的不是6; 或者，其他3已经到终点，只有1个在外面)，
                        else
                            delayTime = config.AutoDelayMoveTime
                        end
                    end
                    retobj.delayTime = delayTime
                    CMD.userSetAutoState('autoMoveChess', delayTime, user.uid, hosting) --该我移动棋子, hosting为false，标识不进入默认托管状态
                end
            end
        end
    end
    
    retobj.automove = 0
    retobj.pass = autoPass
    retobj.dices = user.round.dices --本次摇完的点数列表
    retobj.dot = random
    if retobj.nextSeat == 0 then
        retobj.nextSeat = deskInfo.round.activeSeat --下一步谁操作
    end
    if autoMove then
        retobj.automove = 1
    end

    deskInfo:print("22我摇完骰子了:", user.uid, ' 点数:', random, ' seatid:', user.seatid ,' 家里chess:', table.concat(user.round.chess, ','), ' steps:', table.concat(user.round.steps,','), ' dices:', table.concat(user.round.dices,','), ' nextSeat:', deskInfo.round.activeSeat)
    deskInfo:print("我的状态:", user.state, ' uid:', uid)
    if deskInfo.round.pannel[user.seatid] == nil then
        deskInfo.round.pannel[user.seatid] = {1, 0, 0} --摇骰子次数、kill次数, killed次数
    else
        deskInfo.round.pannel[user.seatid][1] = deskInfo.round.pannel[user.seatid][1] + 1
    end

    local notify = table.copy(retobj)
    notify.c = PDEFINE.NOTIFY.ROLLE_RESULT
    notify.coin = calCoin(user.round.resetTimes+1)
    deskInfo:broadcast(cjson.encode(notify))
    USER_ROLLING[uid] = nil
    if is_auto then
        return warpResp(retobj)
    end
    return PDEFINE.RET.SUCCESS
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
    deskInfo:print("cmd.moveChess msg:", msg)
    local recvobj  = msg
    local is_auto = recvobj.is_auto
    local uid = math.floor(recvobj.uid)
    if nil == USER_MOVING[uid] then
        USER_MOVING[uid] = true
    else
        return
    end
    local chessid  = math.floor(recvobj.chessid or 0) --棋子id
    local step = math.floor(recvobj.step or 0) --步数(可能有多种选择)
    local retobj  = {c = recvobj.c, uid = uid, code =PDEFINE.RET.SUCCESS, spcode=0, chessid=chessid, addStep=step, dice=step}
    local user = deskInfo:findUserByUid(uid)
    if chessid>4 or chessid <1 then --每个人只有4颗棋子
        retobj.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
        deskInfo:print("moveChess 每个人只有4颗棋子 uid:", uid, ' chessid:', chessid)
        USER_MOVING[uid] = nil
        return warpResp(retobj)
    end
    if deskInfo.round.activeSeat ~= user.seatid then --TODO:不是他操作
        retobj.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
        deskInfo:print("moveChess 每个人只有4颗棋子 uid:", uid, ' activeSeat:', deskInfo.round.activeSeat, ' seatid:', user.seatid)
        USER_MOVING[uid] = nil
        return warpResp(retobj)
    end
    if step ~= config.MaxDot and table.contain(user.round.chess, chessid) then --它走的数字不是6，想从仓库中走出来
        retobj.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
        deskInfo:print("moveChess 它走的数字不是6，想从仓库中走出来 uid:", uid,  ' step:', step, ' chessid:', chessid, ' dices:', user.round.dices,' chess:', table.concat(user.round.chess,','))
        USER_MOVING[uid] = nil
        return warpResp(retobj)
    end
    if not table.contain(user.round.dices, step) then --TODO:不是这个步数
        retobj.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
        deskInfo:print("moveChess 每个人只有4颗棋子 uid:", uid, ' dices:', user.round.dices, ' step:', step)
        USER_MOVING[uid] = nil
        return warpResp(retobj)
    end
    user:clearTimer()

    local nowStep = user.round.steps[chessid] or 0
    if nowStep > config.Quick and step > (config.Win - nowStep) and nowStep ~= config.QuickZero then
        retobj.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
        deskInfo:print("moveChess 这颗棋子剩余步数超了uid:", uid, ' dices:', user.round.dices, ' step:', step, 'nowStep:', nowStep, ' chessid:', chessid)
        USER_MOVING[uid] = nil
        return warpResp(retobj)
    end
    user.state = PDEFINE.PLAYER_STATE.Discard
    deskInfo:print("我开始走棋子 uid:", uid,  " step:",  step, ' chessid:',  chessid, ' steps:', table.concat(user.round.steps,','), ' dices:', table.concat(user.round.dices,','))
    --1、先走出来
    for i = #user.round.dices, 1, -1 do --从摇出来的队列中删除
        if user.round.dices[i] == step then
            table.remove(user.round.dices, i)
            break
        end
    end
    deskInfo:print("我走棋子，去掉待用骰子 uid:",uid, ' dices:', table.concat(user.round.dices,','))
    local out = false
    if step == 6 then
        for i=#user.round.chess, 1 , -1 do
            if user.round.chess[i] == chessid then
                table.remove(user.round.chess, i)
                user.round.steps[chessid] = 1
                retobj.addStep = 1
                out = true --从家中走出来
                deskInfo:print("我走棋子，走6 uid:",uid, ' 从家里出棋子chessid:', chessid)
                break
            end
        end
    end
    if not out then
        if user.round.steps[chessid] == nil then --记录自己的棋子步数
            user.round.steps[chessid] = 0
        end
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
                deskInfo:print("quick玩法：我走棋子，未杀敌 uid:",uid, ' 绕一圈:', chessid, ' leftStep:', leftStep)
            else
                user.round.steps[chessid] = user.round.steps[chessid] + step
                deskInfo:print("quick玩法：我走棋子，走6 uid:",uid, ' chessid不在家中:', chessid)
            end
        else
            user.round.steps[chessid] = user.round.steps[chessid] + step
            deskInfo:print("我走棋子2222 uid:",uid, ' chessid不在家中:', chessid)
        end
        
    end
    local afterstep = user.round.steps[chessid]
    retobj.defend = 0
    local times = 0
    for _, step in pairs(user.round.steps) do
        if step == afterstep then
            times = times + 1
        end        
    end
    if times > 1 or table.contain(config.Protect, afterstep) then
        retobj.defend = 1
    end
    retobj.isOver = 0
    --2、到终点了
    if afterstep == config.Win then --到了终点
        if table.count(user.round.steps, config.Win) == 4 or (deskInfo.conf.gametype == config.GameType.QUICK) then --quick 玩法只要有棋子走到终点就算赢
            --我赢了
            deskInfo:print("我赢了 uid:", uid,  " step:",  afterstep, ' chessid:',  chessid,' steps:', user.round.steps)
            retobj.isOver = 1
            deskInfo.round.winuid = uid
            skynet.timeout(300, function()
                agent:gameOver()
            end)
        else --奖励自己1次摇的机会
            retobj.nextgametype = config.NextGameType.ROLL
            retobj.nextSeat = user.seatid
            retobj.step = afterstep
            retobj.killed = {}
            retobj.dices = user.round.dices
            local notify = table.copy(retobj)
            notify.c = PDEFINE.NOTIFY.MOVE_RESULT
            deskInfo:broadcast(cjson.encode(notify))
            user.state = PDEFINE.PLAYER_STATE.Draw
            local delayTime = math.random(1,3)
            CMD.userSetAutoState('autoRollDice', delayTime, uid)

            deskInfo:print("我走棋子 1个棋子赢了 接着摇棋子 uid:", uid,  " step:",  step, ' chessid:',  chessid, ' afterstep:', afterstep, ' steps:', user.round.steps)
            USER_MOVING[uid] = nil
            return warpResp(retobj)
        end
    end
    --3、可能杀别人棋子
    local killedlist = {}
    retobj.killed = killedlist
    retobj.nextgametype = config.NextGameType.ROLL
    deskInfo:print("我走完后，uid:", uid, ' steps:', table.concat(user.round.steps, ','))
    if retobj.isOver == 0 then
        if afterstep <= config.Quick and not table.contain(config.Protect, afterstep) then  --目标位置有棋子 要杀
            deskInfo:print("我走完后，uid:", uid, ' steps:', table.concat(user.round.steps, ','), ' 考虑是否要杀他人棋子了')
            for _, muser in pairs(deskInfo.users) do
                if muser.uid ~= uid then
                    -- local killed , killedChessids = canKill(muser.seatid, muser.round.steps, user.seatid, afterstep)
                    local killed, killedChessids = checkKillMap(user.seatid, afterstep, muser.seatid, muser.round.steps)
                    if killed then
                        for _, id in pairs(killedChessids) do
                            deskInfo:print("killed 我走完后，uid:", uid, ' 他在这个位置上有棋子:', table.concat(muser.round.steps, ','), ' chessid:', id, ' 被我干掉了')
                            muser.round.steps[id] = 0 --杀掉
                            table.insert(muser.round.chess, id) --打回仓库
                            table.insert(killedlist, {uid=muser.uid, chessid = id, seatid=muser.seatid})
                            deskInfo:print("killed 我走完棋子 位置上有其他的棋子 afterstep:", afterstep, " uid:", uid, " vs other uid:", muser.uid,  " steps:",  table.concat(muser.round.steps, ','), ' chess:', table.concat(muser.round.chess, ','))
                            --记录次数
                            if deskInfo.round.pannel[muser.seatid] == nil then
                                deskInfo.round.pannel[muser.seatid] = {0, 0, 1} --要骰子次数、kill次数, killed次数
                            else
                                deskInfo.round.pannel[muser.seatid][3] =deskInfo.round.pannel[muser.seatid][3] + 1
                            end
                            deskInfo.round.pannel[user.seatid][2] = deskInfo.round.pannel[user.seatid][2] + 1 --记录杀的次数
                            user.round.kill = user.round.kill + 1
                            deskInfo:print("killed 我走棋子 位置上有其他的棋子 afterstep:", afterstep, " uid:", uid, " other uid:", muser.uid,  ' pannel:',  deskInfo.round.pannel)
                        end
                    end
                end
            end
        end
        if afterstep == config.QuickZero and deskInfo.conf.gametype == config.GameType.QUICK then --停留在58号位(quick玩法特有)
            deskInfo:print("quick玩法 停留在58号位 走完后，uid:", uid, ' steps:', table.concat(user.round.steps, ','), ' 考虑是否要杀他人棋子了')
            for _, muser in pairs(deskInfo.users) do
                if muser.uid ~= uid then
                    --58号位置杀敌
                    local killed, killedChessids = checkKillMapQuickZero(user.seatid, afterstep, muser.seatid, muser.round.steps)
                    if killed then
                        for _, id in pairs(killedChessids) do
                            deskInfo:print("killed 我走完后，uid:", uid, ' 他在这个位置上有棋子:', table.concat(muser.round.steps, ','), ' chessid:', id, ' 被我干掉了')
                            muser.round.steps[id] = 0 --杀掉
                            table.insert(muser.round.chess, id) --打回仓库
                            table.insert(killedlist, {uid=muser.uid, chessid = id, seatid=muser.seatid})
                            deskInfo:print("killed 我走完棋子 位置上有其他的棋子 afterstep:", afterstep, " uid:", uid, " vs other uid:", muser.uid,  " steps:",  table.concat(muser.round.steps, ','), ' chess:', table.concat(muser.round.chess, ','))
                            --记录次数
                            if deskInfo.round.pannel[muser.seatid] == nil then
                                deskInfo.round.pannel[muser.seatid] = {0, 0, 1} --要骰子次数、kill次数, killed次数
                            else
                                deskInfo.round.pannel[muser.seatid][3] =deskInfo.round.pannel[muser.seatid][3] + 1
                            end
                            deskInfo.round.pannel[user.seatid][2] = deskInfo.round.pannel[user.seatid][2] + 1 --记录杀的次数
                            user.round.kill = user.round.kill + 1
                            deskInfo:print("killed 我走棋子 位置上有其他的棋子 afterstep:", afterstep, " uid:", uid, " other uid:", muser.uid,  ' pannel:',  deskInfo.round.pannel)
                        end
                    end
                end
            end
        end
        deskInfo:print("我走完后，uid:", uid, ' killedlist:', killedlist)
        retobj.killed = killedlist
    
        --4、自己骰子队列中是否还有
        if not table.empty(killedlist) then
            retobj.nextgametype = config.NextGameType.ROLL
            deskInfo.round.activeSeat = user.seatid
            user.state = PDEFINE.PLAYER_STATE.Draw
            deskInfo:print("我杀了棋子 uid:", uid, " 奖励摇骰子, 剩余骰子:", table.concat(user.round.dices, ','), ' 下一步我接着摇骰子')
            CMD.userSetAutoState('autoRollDice', config.AutoDelayMoveTime, uid)
        else
            deskInfo:print("我没有杀棋子 uid:", uid, " 可能接着走dices:", table.concat(user.round.dices, ','), ' steps:', table.concat(user.round.steps, ','), ' chess:',table.concat(user.round.chess, ','))
            if #user.round.dices > 0 then
                local all_steps = canSkipMove(user) --是不是跳过剩下的棋子
                deskInfo:print("我都走完了 uid:", uid, ' all_steps:', all_steps, ' user.round.steps:', table.concat(user.round.steps, ','), ' dices:', table.concat(user.round.dices, ','))
                if all_steps then
                    user.round.dices = {}
                    user.state = PDEFINE.PLAYER_STATE.Wait
                    local nextUser = findNextUser(user.seatid)
                    nextUser.state = PDEFINE.PLAYER_STATE.Draw
                    deskInfo.round.activeSeat = nextUser.seatid
                    deskInfo:print("我都走完11了 uid:", uid, " 下一个:", nextUser.uid,  ' nextSeatid:', nextUser.seatid)
                    CMD.userSetAutoState('autoRollDice', getDelayTime(nextUser), nextUser.uid)
                else
                    retobj.nextgametype = config.NextGameType.RUN
                    deskInfo.round.activeSeat = user.seatid
                    user.state = PDEFINE.PLAYER_STATE.Discard
                    deskInfo:print("我还有未清空的棋子， uid:", uid, " 需要接着走dices:", table.concat(user.round.dices, ','), ' steps:', table.concat(user.round.steps, ','))
                    CMD.userSetAutoState('autoMoveChess', config.AutoDelayMoveTime, uid)
                end
            else
                user.state = PDEFINE.PLAYER_STATE.Wait
                local nextUser = findNextUser(user.seatid)
                nextUser.state = PDEFINE.PLAYER_STATE.Draw
                deskInfo.round.activeSeat = nextUser.seatid
                deskInfo:print("我都走完22了 uid:", uid, " 下一个:", nextUser.uid,  ' nextSeatid:', nextUser.seatid, ' config.AutoDelayTime:',config.AutoDelayTime)
                CMD.userSetAutoState('autoRollDice', getDelayTime(nextUser), nextUser.uid)
            end
        end
    end
    retobj.dices = user.round.dices
    retobj.nextSeat = deskInfo.round.activeSeat
    retobj.step = afterstep
    local notify = table.copy(retobj)
    notify.c = PDEFINE.NOTIFY.MOVE_RESULT
    deskInfo:broadcast(cjson.encode(notify))
    USER_MOVING[uid] = nil
    if is_auto then
        return warpResp(retobj)
    end
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
    deskInfo:print('cancelAuto, msg:', recvobj)
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if user.auto == 0 then
        deskInfo:print("cancelAuto auto==0  uid:", uid)
        return warpResp(retobj)
    end
    
    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PDEFINE.PLAYER_STATE.Discard then
        local timeout = deskInfo.delayTime
        retobj.delayTime = timeout
        deskInfo:print("cancelAuto 加上自动出牌定时器 timeout:", timeout, ' uid:', uid)
        CMD.userSetAutoState('autoMoveChess', timeout, uid)
    elseif user.state == PDEFINE.PLAYER_STATE.Draw then
        local timeout = deskInfo.delayTime
        retobj.delayTime = timeout
        deskInfo:print("cancelAuto 加上自动摇骰子定时器 timeout:", timeout, ' uid:', uid)
        CMD.userSetAutoState('autoRollDice', timeout, uid)
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
    local userInfo = deskInfo:findUserByUid(msg.uid)
    local bet = deskInfo.bet
    for _, user in pairs(deskInfoStr.users) do
        user.wincoinshow = user.settlewin * bet
    end

    local now = os.time()
    local autoTime = deskInfo.round.autoTime or 0
    local delayTime = config.AutoDelayTime
    if autoTime > now then
        delayTime = autoTime - now
    end
    deskInfoStr.round.delayTime = delayTime
    deskInfoStr.seat = deskInfo.conf.seat

    --deskInfo:print("getDeskInfo msg:", msg)
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
    deskInfoStr.delayTime = config.AutoDelayTime

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
        deskInfo:print("cmd.join uid:", uid, ' canStart:', canStart, ' users:', #deskInfo.users)
        if canStart then
            startGame(3)
        end
        deskInfo:syncChatItem()
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
    deskInfo:print("addCoinInGame uid:",uid, ' coin:', coin, ' diamond:', diamond)
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