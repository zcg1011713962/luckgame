local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local queue     = require "skynet.queue"
local snax = require "snax"
local player_tool = require "base.player_tool"
local baseDeskInfo = require "base.deskInfo"
local baseUser = require "base.user"
local baseAgent = require "base.agent"
local baseUtil = require "base.utils"
local record = require "base.record"
local utils = require "indiarummy.indiarummyutils"
local robot = require "indiarummy.indiarummyrobot"
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
    deal_card_dilute_prob = 0.8,    --发牌时稀释玩家手牌的反向概率
    draw_card_needed_prob = 0.8,    --摸牌时机器人获得需求牌的反向概率
    robot_lose_total_point = 50,    --机器人输最大总点数
    robot_lose_point = 15,          --机器人输分点数
}

---@type BaseDeskInfo
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例

local config = {
    -- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块, 0x*E为A, 0x51小王， 0x52大王
    Cards = {  --使用两副牌
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,   --方块
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,   --梅花
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,   --红桃
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,   --黑桃
        0x51,0x52,
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
        0x51,0x52
    },

    InitCardLen = 13,
}

local CardDeck = {} --牌堆

--玩家状态
local PlayerState = {
    Wait = PDEFINE.PLAYER_STATE.Wait,       --等待状态(1)
    Ready = PDEFINE.PLAYER_STATE.Ready,     --就绪状态(2)
    Draw = 3,   --摸牌状态
    Discard = 4,--出牌状态
    Confirm = 5,--定牌状态(该状态还未定牌，定完之后变成Show状态)
    Show = 6,   --亮牌状态(亮牌成功或Confirm后的状态)
    Fail = 7,   --亮牌失败
    Drop = 8,   --弃牌状态
}

--游戏状态
local DeskState = {
    Match = PDEFINE.DESK_STATE.MATCH,      --匹配阶段（1）
    Ready = PDEFINE.DESK_STATE.READY,      --准备阶段（2）
    Play = PDEFINE.DESK_STATE.PLAY,        --玩牌阶段（3）
    Settle = PDEFINE.DESK_STATE.SETTLE,    --结算阶段
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

-- 检测用户，和检测状态
local function checkUserAndState(user, state, retobj)
    -- 检测用户
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return false, retobj
    else
        retobj.seat   = user.seatid
        retobj.uid    = user.uid
    end
    -- 检测状态，只有非等待状态才能操作
    if user.state ~= state then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end
    return true, retobj
end

local function initDeskInfoRound(seatid)
    deskInfo.round = {}
    deskInfo.round.discardCards = {}    --弃牌牌堆
    deskInfo.round.cardCnt  = 0         --剩余牌张数
    deskInfo.round.wildCard = 0         --癞子牌
    deskInfo.round.activeSeat = 0       --当前活动座位号
    deskInfo.round.winnerUid  = 0       --亮牌成功的玩家id
    deskInfo.round.winCard    = 0       --亮牌成功的牌
    deskInfo.round.poolcoin   = 0       --池子金币数
    deskInfo.round.dealseat = seatid or 0   --庄家座位号
    deskInfo.round.firstcard  = 1       --是否是发的第一张牌
    deskInfo.round.stm = skynet.time()
end

---@param user BaseUser
local function initUserRound(user)
    user.state             = PlayerState.Wait
    user.round = {}
    user.round.cards       = {} --手牌
    user.round.groupcards  = {} --分组的牌
    user.round.dropmult    = 20 --drop倍数
    user.round.point       = 0  --点数（用于算分）
    user.round.wincoin     = 0  --赢分
    user.round.autocnt     = 0
    user.round.drawtime    = 0  --摸牌时间
    user.round.discard     = 0
end

local function formatHandcard(handcard)
    local str = ""
    for _, cards in ipairs(handcard) do
        str = str .. "[" .. table.concat(cards, ",") .. "]"
    end
end

local function drop(user)
    local msg = {
        c = 29201,  --弃牌
        uid = user.uid,
    }
    local _, resp = CMD.drop(nil, msg)
    LOG_DEBUG("自动弃牌返回: ", resp)
    resp.is_auto = 1
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("drop error", resp.spcode)
    end
end

local function show(user, card, groupcards)
    local msg = {
        c = 29203,  --亮牌
        uid = user.uid,
        card = card,
        groupcards = groupcards
    }
    local _, resp = CMD.show(nil, msg)
    LOG_DEBUG("自动亮牌返回: ", resp)
    resp.is_auto = 1
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("show error", resp.spcode)
    end
end

local function draw(user)
    local op = 1   --1：从发牌堆摸， 2：从弃牌堆摸
    --玩家直接从发牌堆摸，机器人有概率从弃牌堆摸
    if user.cluster_info then
        if #CardDeck <= 0 then
            op = 2
        end
    else
        if #CardDeck > 0 then
            if (#deskInfo.round.discardCards > 0) and (not user.cluster_info) then
                --做选择
                local card1 = CardDeck[#CardDeck]
                local card2 = deskInfo.round.discardCards[#deskInfo.round.discardCards]
                if not utils.IsWild(card2, deskInfo.round.wildCard) or (deskInfo.round.firstcard == 1) then
                    local rand = math.random()
                    if rand < 0.5 then
                        op = robot.checkDrawCard(user.round.cards, card1, card2, deskInfo.round.wildCard)
                    elseif card2 ~= user.round.discard and robot.checkCardPriority(user.round.cards, card2, deskInfo.round.wildCard) >= 3 then
                        op = 2
                    end
                end
                --LOG_DEBUG("xxx Drawcard", op, robot.formatCard(card1), robot.formatCard(card2), robot.formatGroupCards(user.round.groupcards), "wild:"..robot.formatCard(deskInfo.round.wildCard))
            end
        else
            op = 2
        end
    end
    local msg = {
        c = 29202,  --摸牌
        uid = user.uid,
        op = op,
    }
    local _, resp = CMD.draw(nil, msg)
    LOG_DEBUG("自动摸牌返回: ", resp)
    resp.is_auto = 1
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("draw error", resp.spcode)
    end
end

local function discard(user, card)
    local groupcards = table.copy(user.round.groupcards)
    for i = #groupcards, 1, -1 do
        local group = groupcards[i]
        if baseUtil.RemoveCard(group, card) then
            if #group == 0 then
                table.remove(groupcards, i)
            end
            break
        end
    end
    local msg = {
        c = 29204,  --出牌
        uid = user.uid,
        card = card,
        groupcards = groupcards
    }
    local _, resp = CMD.discard(nil, msg)
    LOG_DEBUG("自动出牌返回: ", resp)
    resp.is_auto = 1
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("discard error", resp.spcode)
    end
end

-- 自动摸牌
local function autoDraw(uid)
    return cs(function()
        LOG_DEBUG("用户摸牌  uid:".. uid)

        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()

        if user.state ~= PlayerState.Draw then
            LOG_WARNING("状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                deskInfo:autoMsgNotify(user, 1, 0)
            else
                user.round.autocnt = user.round.autocnt + 1
            end
            if user.isexit == 1 or user.round.autocnt >= 5 then
                --玩家弃牌
                drop(user)
            else
                --玩家摸牌
                draw(user)
            end
        else
            --机器人摸牌
            --如果所有的玩家都弃牌了，机器人有概率弃牌
            local alldroped = true
            for _, u in ipairs(deskInfo.users) do
                if u.cluster_info then
                    if u.state > PlayerState.Wait and u.state ~= PlayerState.Drop and u.state ~= PlayerState.Fail then
                        alldroped = false
                        break
                    end
                end
            end

            if alldroped and math.random() < 0.3 then
                local pasttime = skynet.time() - deskInfo.round.stm
                local totalscore = utils.GetTotalScore(user.round.groupcards, deskInfo.round.wildCard)
                if totalscore > 50 and pasttime > math.random(120, 150) then
                    drop(user)
                    return
                elseif totalscore > 40 and pasttime > math.random(180, 240) then
                    drop(user)
                    return
                elseif pasttime > math.random(300, 360) then
                    drop(user)
                    return
                end
            end

            if user.round.dropmult < 40 then
                if robot.checkDropCard(user.round.cards, deskInfo.round.wildCard) then
                    drop(user)
                else
                    draw(user)
                end
            else
                draw(user)
            end
        end
    end)
end

--获取随机打出的牌
local function getRandomDiscard(cards, wildCard)
    for i = #(cards), 1, -1 do
        if not utils.IsWild(cards[i], wildCard) and utils.ScanValue(cards[i])>=10 then
            return cards[i]
        end
    end
    for i = #(cards), 1, -1 do
        if not utils.IsWild(cards[i], wildCard) then
            return cards[i]
        end
    end
    return cards[#cards]
end

--自动出牌
local function autoDiscard(uid)
    return cs(function()
        LOG_DEBUG("用户自动出牌 uid:".. uid)

        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()

        if user.state ~= PlayerState.Discard then
            LOG_WARNING("出牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end

        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end

        if user.cluster_info then
            local card = getRandomDiscard(user.round.cards, deskInfo.round.wildCard)
            discard(user, card)
        else
            local succ, discardCard, groups = robot.checkDiscardCard(user.round.cards, deskInfo.round.wildCard)
            if succ then
                --亮牌
                show(user, discardCard, groups)
            else
                --LOG_DEBUG("xxx Discard", robot.formatCard(discardCard), robot.formatGroupCards(user.round.groupcards), "wild:"..robot.formatCard(deskInfo.round.wildCard))
                --出牌
                discard(user, discardCard)
                --理一下手里的牌
                if user.state == PlayerState.Ready then
                    user.round.groupcards = robot.arrangeCards(user.round.cards, deskInfo.round.wildCard)
                end
            end
        end
    end)
end

--自动定牌
local function autoConfirm(uid)
    return cs(function()
        LOG_DEBUG("用户自动定牌 uid:".. uid)

        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()

        if user.state ~= PlayerState.Confirm then
            LOG_WARNING("出牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end

        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end

        local groupcards = user.round.groupcards
        if not user.cluster_info then
            --机器人定牌
            groupcards = robot.confirmCards(user.round.cards, deskInfo.round.wildCard)
        end

        local msg = {
            c = 29206,
            uid = uid,
            groupcards = groupcards
        }
        local _, resp = CMD.confirm(nil, msg)
        LOG_DEBUG("自动定牌返回: ", resp)
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        else
            LOG_ERROR("confirm error", resp.spcode)
        end
    end)
end

-- 自动准备
local function autoReady(uid)
    return cs(function()
        deskInfo:print("自动准备 uid:".. uid)
        local user = deskInfo:findUserByUid(uid)

        if not user or user.state >= PDEFINE.PLAYER_STATE.Ready then
            return
        end
        user:clearTimer()

        local msg = {
            ['c'] = 25708,
            ['uid'] = uid,
        }
        CMD.ready(nil, msg)
    end)
end

--自动离开
local function autoLeave(uid)
    if deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.MATCH then return end
    return cs(function()
        deskInfo:onRobotDropLeave(uid)
        LOG_DEBUG("弃牌后离桌", uid)
    end)
end

-------- 设定玩家定时器 --------
local function userSetAutoState(type,autoTime,uid,addTime)
    autoTime = autoTime + 1
    deskInfo.round.expireTime = os.time() + autoTime
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    user:clearTimer()
    if not user.cluster_info then
        local minTime = 30
        local maxTime = math.min(110, (autoTime-2)*10)
        if type == "autoDraw" then
            minTime = 20
            maxTime = 40
        end
        addTime = addTime or 0
        autoTime = math.random(minTime, maxTime)/10 + addTime
    end
    -- if DEBUG and user.cluster_info and user.isexit == 0 then
    --     autoTime = 1000000
    -- end

    -- 自动摸牌
    if type == "autoDraw" then
        user:setTimer(autoTime, autoDraw, uid)
    -- 自动出牌
    elseif type == "autoDiscard" then
        user:setTimer(autoTime, autoDiscard, uid)
    -- 自动定牌
    elseif type == "autoConfirm" then
        user:setTimer(autoTime, autoConfirm, uid)
    -- 自动准备
    elseif type == "autoReady" then
        user:setTimer(autoTime, autoReady, uid, true)
    end
end

local function setAutoReady(delayTime, uid)
    userSetAutoState('autoReady', delayTime, uid)
end

--! agent退出
function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

-- 观战坐下
function CMD.seatDown(source, msg)
    return agent:seatDown(msg)
end

function CMD.chatIcon(source, msg)
    agent:actChatIcon(msg)
    return PDEFINE.RET.SUCCESS
end

--找到下一个未结束的玩家
local function findNextUser(seatId)
    local tryCnt = deskInfo.seat
    while tryCnt > 0 do
        seatId = seatId + 1
        if seatId > deskInfo.seat then seatId = 1 end
        for _,user in pairs(deskInfo.users) do
            if user.seatid == seatId and user.state == PlayerState.Ready then
                return user
            end
        end
        tryCnt = tryCnt - 1
    end
end

--分配座位
local function assignSeat(isRobot)
    local seated = {}
    for _, user in ipairs(deskInfo.users) do
        if user.cluster_info then
            seated[user.seatid] = 1  --玩家
        else
            seated[user.seatid] = 2 --机器人
        end
    end
    local seatList = {}
    for i = 1 , deskInfo.seat do
        if not seated[i] then
            table.insert(seatList, i)
        end
    end
    table.shuffle(seatList)
    --机器人优先分配246，玩家优先分配135
    if isRobot then
        for pos, seatid in ipairs(seatList) do
            if seatid % 2 == 0 then
                local preSeat = seatid - 1
                if preSeat < 1 then preSeat = deskInfo.seat end
                local nextSeat = seatid + 1
                if nextSeat > deskInfo.seat then nextSeat = 1 end
                --如果左右都是玩家，优先分配
                if seated[preSeat]==1 and seated[nextSeat]==1 then
                    return table.remove(seatList, pos)
                end
            end
        end
        for pos, seatid in ipairs(seatList) do
            if seatid % 2 == 0 then
                return table.remove(seatList, pos)
            end
        end
    else
        for pos, seatid in ipairs(seatList) do
            if seatid % 2 == 1 then
                local preSeat = seatid - 1
                if preSeat < 1 then preSeat = deskInfo.seat end
                local nextSeat = seatid + 1
                if nextSeat > deskInfo.seat then nextSeat = 1 end
                --如果左右都是机器人，优先分配
                if seated[preSeat]==2 and seated[nextSeat]==2 then
                    return table.remove(seatList, pos)
                end
            end
        end
        for pos, seatid in ipairs(seatList) do
            if seatid % 2 == 1 then
                return table.remove(seatList, pos)
            end
        end
    end
    return table.remove(seatList)
end

-- 开始发牌
local function roundStart()
    if #deskInfo.users < 2 then
        LOG_DEBUG("users less than 2", #deskInfo.users)
        deskInfo:updateState(DeskState.Match)
        return
    end
    deskInfo.curround = deskInfo.curround + 1
    LOG_DEBUG("roundStart ", deskInfo.uuid, #deskInfo.users, deskInfo.curround)
    -- 切换桌子状态
    deskInfo:updateState(DeskState.Play, true)

    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.cards = nil

    -- 随机堆上的牌
    local deckcards = utils.RandomCards(config.Cards)
    CardDeck = table.copy(deckcards)
    --最后一张牌不为王
    if baseUtil.IsJoker(CardDeck[1]) then
        for i = 5, #CardDeck do
            if not baseUtil.IsJoker(CardDeck[i]) then
                CardDeck[1], CardDeck[i] = CardDeck[i], CardDeck[1]
                break
            end
        end
    end
    --最后一张牌为癞子
    local wildCard = CardDeck[1]

    -- 开始发牌
    local cc = getControlParam("deal_card_dilute_prob")
    for _, user in ipairs(deskInfo.users) do
        user.state = PlayerState.Ready
        local cards = {}
        for i = 1, config.InitCardLen do
            local card = table.remove(CardDeck)
            if (not user.cluster_info) and (not utils.IsWild(card, wildCard)) and table.contain(cards, card) then
                local nextCard = table.remove(CardDeck)
                table.insert(cards, nextCard)
                table.insert(CardDeck, card)
            else
                table.insert(cards, card)
            end
        end
        if user.cluster_info and math.random() > cc then  --增加玩家难度
            robot.diluteUserCards(cards, CardDeck, wildCard)
        end

        table.sort(cards)
        user.round.cards = cards
        user.round.groupcards = utils.GroupCards(cards)
    end
    --第一张牌到弃牌堆上
    local card = table.remove(CardDeck)
    table.insert(deskInfo.round.discardCards, card)

    local dealseat = deskInfo.round.dealseat
    local activeUser = findNextUser(dealseat)   --活动玩家

    activeUser.state = PlayerState.Draw
    activeUser.round.drawtime = skynet.now()
    userSetAutoState('autoDraw', deskInfo.delayTime, activeUser.uid, 2)

    deskInfo.round.cardCnt = #CardDeck
    deskInfo.round.wildCard = wildCard
    deskInfo.round.activeSeat = activeUser.seatid
    deskInfo.round.firstcard = 1

    retobj.dealseat = dealseat
    retobj.cardCnt = deskInfo.round.cardCnt
    retobj.wildCard = deskInfo.round.wildCard
    retobj.discardCards = deskInfo.round.discardCards
    retobj.activeSeat = deskInfo.round.activeSeat
    retobj.activeState = PlayerState.Draw
    retobj.delayTime = deskInfo.delayTime

    --广播消息
    for _, user in ipairs(deskInfo.users) do
        retobj.cards = table.copy(user.round.cards)
        retobj.groupcards = table.copy(user.round.groupcards)
        --广播消息
        user:sendMsg(cjson.encode(retobj))
    end
end

local function addAi(num, maxNum)
    if num <= 0 then return end
    local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", num, true)
    if ok and not table.empty(aiUserList) then
        for _, ai in pairs(aiUserList) do
            if #deskInfo.users >= maxNum then
                deskInfo:RecycleAi(ai)
                break
            end
            -- 防止加入重复的机器人
            local exist_user = deskInfo:findUserByUid(ai.uid)
            if not exist_user then
                local seatid = assignSeat(true)
                if not seatid then
                    deskInfo:RecycleAi(ai)
                    break
                end
                ai.ssid = deskInfo.ssid

                local userObj = baseUser(ai, deskInfo)
                -- 初始化金币
                userObj.coin = math.random(math.ceil(deskInfo.bet*200), math.ceil(deskInfo.bet*2000)) + math.random(0,99)/100
                userObj.leavetime = os.time() + math.random(300, 1200)  --5~20min
                userObj:init(seatid, deskInfo)
                deskInfo:insertUser(userObj)
                deskInfo:broadcastPlayerEnterRoom(userObj.uid)
                LOG_DEBUG("加入机器人: seatid->", userObj.seatid, "uid->", userObj.uid, "state->", deskInfo.state)
            end
        end
    end
end

-- 创建房间后第1次开始游戏
---@param delayTime integer 用于指定发牌前的延迟时间
local function startGame(delayTime)
    if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH then
        return
    end
    LOG_INFO("startGame:", delayTime)
    delayTime = (delayTime or 0) * 100 + 10

    -- 调用基类的开始游戏
    deskInfo:stopAutoKickOut()
    -- 这里需要先切了，反之有人退出
    deskInfo:updateState(DeskState.Play)

    --如果是杀率房，且两个玩家，一个机器人，则调整机器人数量防止玩家串通
    local realUserNum = deskInfo:getRealUserCnt()
    local aiNum = #deskInfo.users - realUserNum
    if stgy:isValid() then
        if (realUserNum==2 and aiNum==1) or realUserNum > 2 then
            if math.random() < 0.5 or realUserNum > 2 then
                local uids = {}
                for _, user in ipairs(deskInfo.users) do
                    if not user.cluster_info then
                        table.insert(uids, user.uid)
                    end
                end
                for _, uid in ipairs(uids) do
                    deskInfo:userExit(uid)
                end
                LOG_DEBUG("realuser:2 ai:1 ai leave")
            else
                addAi(1, 4)
                LOG_DEBUG("realuser:2 ai:1 add ai")
            end
            delayTime = delayTime + 20
        end
    end

    local uids = {}
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
    end
    pcall(cluster.send, "master", ".mgrdesk", "lockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

    local dealseat = math.random(1, deskInfo.seat)
    if deskInfo.round and deskInfo.round.dealseat then
        dealseat = deskInfo.round.dealseat
    end
    local dealer = deskInfo:findNextUser(dealseat)   --轮庄
    -- 初始化桌子信息
    deskInfo:initDeskRound(dealer.seatid)
    -- LOG_DEBUG("deskInfo ", deskInfo)
    skynet.timeout(delayTime, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart()
    end)
end

-- 检查是否可以开始
local function checkGameStart(delayTime)
    if not deskInfo.isDestroy and deskInfo.state == DeskState.Match then
        if (#deskInfo.users == deskInfo.seat and deskInfo.curround == 0)    --如果匹配玩家数坐满
           or (#deskInfo.users >= 2 and skynet.now() >= deskInfo.beginTime) then --房间人数大于等于2，且都已准备 就开始
            startGame(delayTime)
        end
    end
end

local function calcSuitablePlayerNum()
    local nums = {2, 3, 3, 3, 3, 4, 4} --avg=3.14
    if stgy:isValid() and stgy.rtp <= 60 then
        nums = {2,3,3}
    end
    return nums[math.random(#nums)]
end

local function aiJoin(maxNum)
    if deskInfo.private.aijoin == 0 then
        checkGameStart(1)
        return
    end

    if not maxNum then
        maxNum = calcSuitablePlayerNum()
        LOG_DEBUG("maxNum", maxNum)
        local realUserNum = deskInfo:getRealUserCnt()
        if stgy:isValid() and realUserNum >= 2 then
            if #deskInfo.users <= 2 then
                maxNum = 2
            else
                maxNum = 4
            end
        end
    end
    local num = maxNum - #deskInfo.users
    local curNum = num
    if curNum > 2 then
        curNum = 2
    end

    addAi(curNum, maxNum)

    if curNum < num and #deskInfo.users < maxNum then
        skynet.timeout(math.random(100, 200), function ()
            aiJoin(maxNum)
        end)
    else
        --检查是否可以开始游戏
        checkGameStart(1)
    end

    return PDEFINE.RET.SUCCESS, curNum
end

local function aiJoinCS(maxNum)
    cs(function()
        aiJoin(maxNum)
    end)
end

-- 下一局
local function roundNext(waitSettle)
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        if not waitSettle then
            if #deskInfo.users < deskInfo.minSeat then
                local uids = {}
                for _, u in ipairs(deskInfo.users) do
                    table.insert(uids, u.uid)
                end
                deskInfo:waitSwitchDesk(uids)
            else
                deskInfo.func.startGame(0)
            end
        end
    elseif deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        if deskInfo:hasRealPlayer() then
            if #deskInfo.users < deskInfo.seat then
                aiJoin()
            else
                deskInfo.func.startGame(0)
            end
        else
            deskInfo:destroy()
        end
    else
        if deskInfo:hasRealPlayer() then
            for _, u in ipairs(deskInfo.users) do
                if u.state ~= PDEFINE.PLAYER_STATE.Ready then
                    if deskInfo.conf.autoStart == 1 or not u.cluster_info then
                        LOG_DEBUG("DeskInfo:resetDesk userReady:", u.uid)
                        deskInfo:userReady(u.uid)
                    end
                end
            end
            if deskInfo:getUserCnt() == deskInfo.seat then
                deskInfo:setAutoKickOut()
            end
        else
            local uids = {}
            for _, u in ipairs(deskInfo.users) do
                table.insert(uids, u.uid)
            end
            for _, uid in ipairs(uids) do
                deskInfo:userExit(uid)
            end
        end
    end
end

-- 重置桌子，准备下一大局
local function resetDesk(delayTime, isDismiss, waitSettle)
    local now = os.time()
    deskInfo.uuid = deskInfo.deskid..now  -- 更改uuid
    deskInfo:newIssue()

    local exitedUsers = {}
    local uids = {}
    local killUsers = {}  -- 需要踢掉的人
    local offlineUsers = {}  -- 离线的人
    local dismissUsers = {}  -- 解散踢人
    local autoUsers = {}  --托管的人
    local noCoinUsers = {}  -- 比赛房间，输掉的人
    for _, user in ipairs(deskInfo.users) do
        -- 游戏大局结束之后，解禁所有玩家，可以加入其它房间
        table.insert(uids, user.uid)
        if not user.cluster_info and (now > user.leavetime) then
            user.isexit = 1
        end
        -- 判断金币是否够, 或者已经离线
        local minCoin = deskInfo.conf.mincoin
        if isDismiss then
            table.insert(dismissUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.isexit == 1 then
            table.insert(exitedUsers, {uid=user.uid, seatid=user.seatid})
        elseif deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.TOURNAMENT and user.offline == 1 then  -- 放这里，会清除cluster信息
            table.insert(offlineUsers, {uid=user.uid, seatid=user.seatid})
        elseif deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.TOURNAMENT and user.coin < minCoin then
            table.insert(killUsers, {uid=user.uid, seatid=user.seatid})
        elseif deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.TOURNAMENT and user.auto == 1 then
            table.insert(autoUsers, {uid=user.uid, seatid=user.seatid})
        elseif deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT and user.coin < deskInfo.bet then
            table.insert(noCoinUsers, {uid=user.uid, seatid=user.seatid})
        end
        user.state             = PDEFINE.PLAYER_STATE.Wait
        user.autoStartTime     = nil -- 托管开始时间
        if user.auto == 1 then
            user.autoStartTime = os.time()
        end
        user.autoTotalTime     = 0 -- 当局游戏处于托管的时间
    end

    -- 将已经退出的玩家删除，并且广播
    for _, user in ipairs(exitedUsers) do
        deskInfo:userExit(user.uid)
    end

    -- 将需要剔除的玩家剔除，并且广播
    for _, user in ipairs(killUsers) do
        local duser = deskInfo:findUserByUid(user.uid)
        deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.COIN_NOT_ENOUGH)
        if duser and duser.cluster_info then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
        end
    end

    -- 离线的玩家，从桌子信息中删除用户
    for _, user in ipairs(offlineUsers) do
        deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.USER_OFFLINE)
        local duser = deskInfo:findUserByUid(user.uid)
        if duser and duser.cluster_info then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid)
        end
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
    end

    -- 解散踢人
    for _, user in ipairs(dismissUsers) do
        for _, u in ipairs(deskInfo.users) do
            if u.uid == user.uid and u.cluster_info then
                pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid)
            end
        end
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        deskInfo:userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.GAME_ALREADY_DELTE)
    end

    --托管踢人
    if not DEBUG then
        for _, user in ipairs(autoUsers) do
            local duser = deskInfo:findUserByUid(user.uid)
            deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.AUTO_COUNT_LIMIT)
            if duser and duser.cluster_info then
                pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
            end
            pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        end
    end

    -- 比赛踢人
    for _, u in ipairs(noCoinUsers) do
        local duser = deskInfo:findUserByUid(u.uid)
        -- 通知用户淘汰
        deskInfo:weedOut(u)
        deskInfo:userExit(u.uid, PDEFINE.RET.ERROR.TN_WEED_OUT)
        if duser and duser.cluster_info then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
        end
        -- 汇报给master，这个人被踢了
        pcall(cluster.send, "master", ".tournamentmgr", "weedOut", u.uid, deskInfo.conf.tn_id, deskInfo.deskid)
    end

    pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", deskInfo.name, deskInfo.gameid, deskInfo.deskid, deskInfo:getUserCnt(), deskInfo:getRealUserCnt())

    if waitSettle then
        deskInfo:updateState(PDEFINE.DESK_STATE.WaitSettle)
        deskInfo:waitSettle()
    else
        -- 切换回匹配状态
        deskInfo:updateState(DeskState.Match)
        deskInfo.waitTime = delayTime
        deskInfo.beginTime = skynet.now() + deskInfo.waitTime*100
        deskInfo.uuid  = deskInfo.deskid..now  -- 更改uuid
        deskInfo.conf.create_time = now
        deskInfo:writeDB()  -- 写入数据库
        deskInfo:initDeskRound(deskInfo.round.dealseat)
    end

    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        delayTime = delayTime + 2
    end
    skynet.timeout(delayTime*100+20, function()
        cs(function ()
            roundNext(waitSettle)
        end)
    end)
end

-- 游戏结束
local function gameOver(isDismiss, delayTime)
    local uids = {}
    for _, user in ipairs(deskInfo.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
    end
    -- 需要将玩家解禁，可以退出后加入其它房间
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

    -- 比赛房间汇报场次结果
    local waitSettle = false
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        local players = {}
        for _, user in ipairs(deskInfo.users) do
            table.insert(players, {uid=user.uid, coin=user.coin})
        end
        local ok, ord_info, tonext = pcall(cluster.call, "master", ".tournamentmgr", "updateCoin", players, deskInfo.conf.tn_id, deskInfo.deskid)
        if ok then
            for _, info in ipairs(ord_info) do
                local u = deskInfo:findUserByUid(info.uid)
                if u then
                    u.tn_ord = info.ord
                end
            end
            deskInfo:updateTnOrd()
            if not tonext then
                waitSettle = true
            end
        end
    end

    if isDismiss then
        local notify_retobj = { c=PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
        deskInfo:broadcast(cjson.encode(notify_retobj))
        deskInfo:destroy()
    else
        resetDesk(delayTime, isDismiss, waitSettle)  --10秒结束时间
    end
end

-- 此轮游戏结束
local function roundOver(winUser)
    deskInfo:updateState(DeskState.Settle)
    -- 清除玩家定时器
    for _, user in ipairs(deskInfo.users) do
        user:clearTimer()
    end
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_ROUND_OVER
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.settle = {}
    retobj.waitTime = 10

    local playertotalbet = 0
    local playertotalwin = 0
    local totalwincoin = deskInfo.round.poolcoin
    local basecoin = deskInfo.basecoin
    if winUser.cluster_info then
        --如果玩家赢，那么计算机器人输牌总倍数
        local totalpoint = 0
        local users = {}
        for _, user in ipairs(deskInfo.users) do
            if not user.cluster_info and user ~= winUser then
                if user.state == PlayerState.Show and #user.round.cards > 0 then
                    user.round.point = utils.GetTotalScore(user.round.groupcards, deskInfo.round.wildCard)
                    totalpoint = totalpoint + user.round.point
                    table.insert(users, user)
                end
            end
        end
        local maxtotalpoint = getControlParam("robot_lose_total_point")
        local maxpoint = getControlParam("robot_lose_point")
        if (totalpoint > maxtotalpoint or totalpoint*basecoin > 1000) and #CardDeck > 1 then --机器人输分倍数超过60倍
            table.sort(users, function (a, b)
                return a.round.point > b.round.point
            end)
            for _, user in ipairs(users) do
                if user.round.point > maxpoint or user.round.point*basecoin > 500 then
                    LOG_DEBUG("--------fixCards before--------", user.round.point, robot.formatGroupCards(user.round.groupcards), basecoin, deskInfo.issue)
                    robot.fixCards(user, CardDeck, deskInfo.round.wildCard)
                    user.round.point = utils.GetTotalScore(user.round.groupcards, deskInfo.round.wildCard)
                    LOG_DEBUG("--------fixCards after---------", user.round.point, robot.formatGroupCards(user.round.groupcards), basecoin, deskInfo.issue)
                end
            end
        end
    end
    --输家结算
    for _, user in ipairs(deskInfo.users) do
        if user.state > PlayerState.Wait and #user.round.cards > 0 and user ~= winUser then
            local wincoin = 0
            local remark = ""
            if user.state == PlayerState.Drop then
                --弃牌玩家(金额已扣除)
                wincoin = -user.round.point * basecoin
                remark = "drop"
            elseif user.state == PlayerState.Fail then
                --亮牌失败玩家（金额已扣除）
                wincoin = -user.round.point * basecoin
                remark = "fail"
            else
                --正常结算玩家
                user.round.point = utils.GetTotalScore(user.round.groupcards, deskInfo.round.wildCard)
                wincoin = -user.round.point * basecoin
                remark = "show"
                if wincoin ~= 0 then
                    user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, wincoin, deskInfo)
                end

                totalwincoin = totalwincoin + (0 - wincoin)
            end
            user.round.wincoin = wincoin

            if user.cluster_info and user.istest ~= 1 then
                if wincoin < 0 then playertotalbet = playertotalbet + (-wincoin)
                else playertotalwin = playertotalwin + wincoin end
            end

            local result = {wincards=winUser.round.groupcards, groupcards=user.round.groupcards, wild=deskInfo.round.wildCard, point=user.round.point, remark=remark}
            record.betGameLog(deskInfo, user, 0, wincoin, result, 0)

            local res = {
                seatid = user.seatid,
                uid = user.uid,
                usericon = user.usericon,
                playername = user.playername,
                avatarframe = user.avatarframe,
                coin = user.coin,
                wincoin = wincoin,
                groupcards = user.round.groupcards,
                point = user.round.point
            }
            table.insert(retobj.settle, res)
        end
    end
    --赢家结算
    local wincoin = totalwincoin
    local tax = 0
    if deskInfo.taxrate > 0 then
        tax = math.round_coin(deskInfo.taxrate * wincoin)
        wincoin = wincoin - tax
    end
    winUser.round.wincoin = wincoin

    if winUser.cluster_info and winUser.istest ~= 1 then
        playertotalwin = playertotalwin + wincoin
    end

    if winUser.state == PlayerState.Show then  --亮牌
        winUser.round.point = 0
    else
        winUser.round.point = utils.GetTotalScore(winUser.round.groupcards, deskInfo.round.wildCard)
    end
    if wincoin ~= 0 then
        winUser:notifyLobby(wincoin, winUser.uid, deskInfo.gameid)
        winUser:changeCoin(PDEFINE.ALTERCOINTAG.WIN, wincoin, deskInfo)
    end
    local result = {wincards=winUser.round.groupcards, groupcards=winUser.round.groupcards, wild=deskInfo.round.wildCard, point=winUser.round.point, remark="win"}
    record.betGameLog(deskInfo, winUser, 0, wincoin, result, tax)

    if stgy:isValid() then
        stgy:update(playertotalbet, playertotalwin)
    end

    local res = {
        seatid = winUser.seatid,
        uid = winUser.uid,
        usericon = winUser.usericon,
        playername = winUser.playername,
        avatarframe = winUser.avatarframe,
        coin = winUser.coin,
        wincoin = wincoin,
        groupcards = winUser.round.groupcards,
        point = winUser.round.point
    }
    table.insert(retobj.settle, 1, res)  --记录插到最前

    --结算小局记录
    local winner = winUser.uid
    local multiple = 1
    local allCards = {}
    deskInfo:recordDB(0, winner, retobj.settle, allCards, multiple)

    -- 私人房需要给房主分成
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        local totalbet = (deskInfo.private.totalbet or 0) + totalwincoin
        deskInfo.private.totalbet = totalbet
        local totalTaxCoin = totalwincoin * deskInfo.taxrate
        pcall(cluster.send, "master", ".balprivateroommgr", "gameOver", deskInfo.deskid, deskInfo.owner, totalTaxCoin, deskInfo.bet, totalbet)
    end

    deskInfo:broadcast(cjson.encode(retobj))

    local notifyMsg = function ()
        local dismiss = isMaintain()  -- 维护强行大结算
        gameOver(dismiss, retobj.waitTime)
    end
    skynet.timeout(1, notifyMsg)

    return PDEFINE.RET.SUCCESS
end


local function checkWinUser()
    local cnt = 0
    local winUser = nil
    for _, user in ipairs(deskInfo.users) do
        if user.state == PlayerState.Ready then
            cnt = cnt + 1
            winUser = user
        end
    end
    if cnt == 1 then
        return winUser
    end
    return nil
end

-- 弃牌
function CMD.drop(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Draw, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 清除计时器
    user:clearTimer()
    user.state = PlayerState.Drop
    --弃牌点数
    user.round.point = user.round.dropmult
    --弃牌后显示牌背
    table.fill(user.round.cards, 0)
    for _, group in ipairs(user.round.groupcards) do
        table.fill(group, 0)
    end
    retobj.cards = user.round.cards
    retobj.groupcards = user.round.groupcards
    --扣除金额
    local dropcoin = deskInfo.basecoin * user.round.dropmult
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -dropcoin, deskInfo)
    --池子更新
    deskInfo.round.poolcoin = deskInfo.round.poolcoin + dropcoin
    retobj.poolcoin = deskInfo.round.poolcoin
    retobj.coin = user.coin

    local winUser = checkWinUser()
    if winUser then
        retobj.userState = user.state
        retobj.activeSeat = 0
        retobj.activeState = 0

        skynet.timeout(100, function()
            agent:roundOver(winUser)
        end)
    else
        local delayTime = deskInfo.delayTime
        local activeUser = findNextUser(user.seatid)
        if not activeUser then
            LOG_ERROR("No activeUser")
            for _, u in ipairs(deskInfo.users) do
                LOG_INFO("user state", u.uid, u.state)
            end
        end
        if activeUser.auto == 1 then delayTime = 0 end
        activeUser.state = PlayerState.Draw
        activeUser.round.drawtime = skynet.now()
        userSetAutoState('autoDraw', delayTime, activeUser.uid)

        deskInfo.round.activeSeat = activeUser.seatid
        retobj.userState = user.state
        retobj.activeSeat = activeUser.seatid
        retobj.activeState = activeUser.state
        retobj.delayTime = delayTime

        local leave_prob = math.min(0.2, PDEFINE.ROBOT.DROP_LEAVE_ROOM_PROB*3)
        if not user.cluster_info and math.random() < leave_prob then
            user:setTimer(math.random(1, 5), autoLeave, user.uid)
        end
    end

    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 摸牌
function CMD.draw(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local op = math.sfloor(recvobj.op)  --1：从发牌堆摸， 2：从弃牌堆摸
    ---@type BaseUser>
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.op     = op
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Draw, retobj)
    if not ok then
        return warpResp(retobj)
    end
    if op ~= 1 and op ~= 2 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    local card = nil
    if op == 1 then
        card = table.remove(CardDeck)
        local cc = getControlParam("draw_card_needed_prob")
        if math.random() > cc then  --控制
            local needcards = robot.checkNeedCards(user.round.cards, deskInfo.round.wildCard)
            if user.cluster_info then  --如果是玩家
                if table.contain(needcards, card) or utils.IsWild(card, deskInfo.round.wildCard) then
                    for i = #CardDeck, 2, -1 do
                        if (not table.contain(needcards, CardDeck[i])) and (not utils.IsWild(CardDeck[i], deskInfo.round.wildCard)) then
                            LOG_DEBUG("user change_card", robot.formatCard(card).." => "..robot.formatCard(CardDeck[i]))
                            card, CardDeck[i] = CardDeck[i], card
                            break
                        end
                    end
                end
            else    --如果是机器人
                if (not table.contain(needcards, card)) and (not utils.IsWild(card, deskInfo.round.wildCard)) then
                    for i = #CardDeck, 2, -1 do
                        if table.contain(needcards, CardDeck[i]) then
                            LOG_DEBUG("robot change_card", robot.formatCard(card).." => "..robot.formatCard(CardDeck[i]))
                            card, CardDeck[i] = CardDeck[i], card
                            break
                        end
                    end
                end
            end
        end
    else
        card = deskInfo.round.discardCards[#(deskInfo.round.discardCards)]
        --癞子和王不能摸(除非是首张牌)
        if utils.IsWild(card, deskInfo.round.wildCard) and deskInfo.round.firstcard ~= 1 then
            retobj.spcode = PDEFINE.RET.ERROR.CAN_NOT_JOKER
            retobj.errmsg = "cannot draw wild card"
            return warpResp(retobj)
        end
        table.remove(deskInfo.round.discardCards)
    end
    if not card then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end
    if #CardDeck <= 1 then
        retobj.shuffle = true
        --弃牌堆洗牌放入发牌堆
        table.shuffle(deskInfo.round.discardCards)
        for _, c in ipairs(deskInfo.round.discardCards) do
            table.insert(CardDeck, c)
        end
        deskInfo.round.discardCards = {}
    end
    deskInfo.round.cardCnt = #CardDeck
    deskInfo.round.firstcard = 0

    -- 清除计时器
    user:clearTimer()
    user.state = PlayerState.Discard
    user.round.dropmult = 40
    table.insert(user.round.cards, card)
    local idx = #user.round.groupcards
    table.insert(user.round.groupcards[idx], card)

    local delayTime = deskInfo.delayTime
    if user.round.drawtime > 0 then
        local elapsed = math.floor((skynet.now() - user.round.drawtime)/100)
        delayTime = math.max(0, deskInfo.delayTime - elapsed)
    end
    if user.auto == 1 then delayTime = 0 end
    userSetAutoState('autoDiscard', delayTime, user.uid) --刷新定时器

    retobj.userState = user.state
    retobj.activeSeat = user.seatid
    retobj.activeState = user.state
    retobj.delayTime = delayTime
    retobj.cardCnt = deskInfo.round.cardCnt
    retobj.dropmult = user.round.dropmult
    retobj.card = 0

    deskInfo:broadcast(cjson.encode(retobj), uid)

    retobj.card = card
    return warpResp(retobj)
end


-- 亮牌
function CMD.show(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local card = math.sfloor(recvobj.card)
    local groupcards = recvobj.groupcards
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.card   = card
    retobj.spcode = 0
    retobj.success= 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Discard, retobj)  --出牌状态能show
    if not ok then
        return warpResp(retobj)
    end
    --检查合法性
    if not table.contain(user.round.cards, card) then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end
    local cards = table.copy(user.round.cards)
    baseUtil.RemoveCard(cards, card)
    --检查牌组
    local spcode = utils.CheckGroups(groupcards, cards)
    if spcode ~= 0 then
        retobj.spcode = spcode
        LOG_DEBUG("show group error", uid, card, robot.formatGroupCards(groupcards), robot.formatCards(user.round.cards))
        return warpResp(retobj)
    end

    -- 清除计时器
    user:clearTimer()
    --出掉选中的牌
    baseUtil.RemoveCard(user.round.cards, card)
    --保存卡牌分组
    user.round.groupcards = groupcards

    local delayTime = deskInfo.delayTime
    local totalScore = utils.GetTotalScore(groupcards, deskInfo.round.wildCard)
    if totalScore == 0 then --亮牌成功
        --切换玩家状态
        user.state = PlayerState.Show
        retobj.success = 1
        --其他人confirm
        local activeSeats = {}
        for _, u in ipairs(deskInfo.users) do
            if u.state == PlayerState.Ready then
                u.state = PlayerState.Confirm
                table.insert(activeSeats, u.uid)
                userSetAutoState('autoConfirm', delayTime, u.uid)
            end
        end
        deskInfo.round.winnerUid = user.uid
        deskInfo.round.winCard = card
        deskInfo.round.activeSeat = activeSeats
        retobj.userState = user.state
        retobj.delayTime = delayTime
        retobj.activeSeat = deskInfo.round.activeSeat
        retobj.activeState = PlayerState.Confirm

    else  --亮牌失败
        -- 加入到弃牌堆
        table.insert(deskInfo.round.discardCards, card)
        --扣除金额
        local failcoin = deskInfo.basecoin * 80
        user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -failcoin, deskInfo)
        --池子更新
        deskInfo.round.poolcoin = deskInfo.round.poolcoin + failcoin
        retobj.poolcoin = deskInfo.round.poolcoin
        retobj.failcoin = failcoin
        --切换玩家状态
        user.state = PlayerState.Fail
        --失败点数
        user.round.point = 80
        retobj.success = 0
        --其他人继续
        local winUser = checkWinUser()
        if winUser then
            retobj.userState = user.state
            retobj.activeSeat = 0
            retobj.activeState = 0

            skynet.timeout(100, function()
                agent:roundOver(winUser)
            end)
        else
            local activeUser = findNextUser(user.seatid)
            activeUser.state = PlayerState.Draw
            if activeUser.auto == 1 then delayTime = 0 end
            activeUser.round.drawtime = skynet.now()
            userSetAutoState('autoDraw', delayTime, activeUser.uid)

            deskInfo.round.activeSeat = activeUser.seatid
            retobj.userState = user.state
            retobj.activeSeat = activeUser.seatid
            retobj.activeState = activeUser.state
            retobj.delayTime = delayTime
        end
    end

    retobj.coin = user.coin
    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 出牌
function CMD.discard(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local card = math.sfloor(recvobj.card)
    local groupcards = recvobj.groupcards
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.card   = card
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Discard, retobj)
    if not ok then
        return warpResp(retobj)
    end
    --检查合法性
    if not table.contain(user.round.cards, card) then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        retobj.errmsg = "card not exist"
        retobj.groupcards = user.round.groupcards
        return warpResp(retobj)
    end
    local cards = table.copy(user.round.cards)
    baseUtil.RemoveCard(cards, card)
    --检查牌组
    local spcode = utils.CheckGroups(groupcards, cards)
    if spcode ~= 0 then
        retobj.spcode = spcode
        retobj.errmsg = "card group error"
        retobj.groupcards = user.round.groupcards
        LOG_DEBUG("discard group error", uid, robot.formatCard(card), robot.formatGroupCards(groupcards), robot.formatCards(user.round.cards))
        return warpResp(retobj)
    end

    -- 扣除手牌
    user.round.cards = baseUtil.RemoveCard(user.round.cards, card)
    --保存卡牌分组
    user.round.groupcards = groupcards

    -- 清除计时器
    user:clearTimer()
    user.state = PlayerState.Ready

    -- 加入到弃牌堆
    table.insert(deskInfo.round.discardCards, card)
    user.round.discard = card

    --下一个玩家摸牌
    local delayTime = deskInfo.delayTime
    local activeUser = findNextUser(user.seatid)
    activeUser.state = PlayerState.Draw
    if activeUser.auto == 1 then delayTime = 0 end
    activeUser.round.drawtime = skynet.now()
    userSetAutoState('autoDraw', delayTime, activeUser.uid)

    deskInfo.round.activeSeat = activeUser.seatid
    retobj.userState = user.state
    retobj.activeSeat = activeUser.seatid
    retobj.activeState = activeUser.state
    retobj.delayTime = delayTime

    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end


-- 理牌
function CMD.arrange(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local groupcards = recvobj.groupcards
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end
    if user.state < PlayerState.Ready or user.state > PlayerState.Confirm then  --定牌之前都可以排列
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end
    --检查牌组
    local spcode = utils.CheckGroups(groupcards, user.round.cards)
    if spcode ~= 0 then
        retobj.spcode = spcode
        retobj.cards = user.round.cards
        retobj.groupcards = user.round.groupcards
        LOG_DEBUG("arrange group error", uid, robot.formatGroupCards(groupcards), robot.formatCards(user.round.cards))
        return warpResp(retobj)
    end

    --保存卡牌分组
    user.round.groupcards = groupcards

    return warpResp(retobj)
end

-- 定牌
function CMD.confirm(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local groupcards = recvobj.groupcards
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Confirm, retobj)
    if not ok then
        return warpResp(retobj)
    end

    --检查牌组
    local spcode = utils.CheckGroups(groupcards, user.round.cards)
    if spcode ~= 0 then
        retobj.spcode = spcode
        LOG_DEBUG("confirm group error", uid, robot.formatGroupCards(groupcards), robot.formatCards(user.round.cards))
        return warpResp(retobj)
    end

    -- 清除计时器
    user:clearTimer()
    --切换玩家状态
    user.state = PlayerState.Show
    --保存卡牌分组
    user.round.groupcards = groupcards
    --清除活动玩家座位
    if type(deskInfo.round.activeSeat) == 'table' then
        table.removeVal(deskInfo.round.activeSeat, user.seatid)
    end

    --是否所有人都完成confirm
    local bAllConfirm = true
    for _, u in ipairs(deskInfo.users) do
        if u.state == PlayerState.Confirm then
            bAllConfirm = false
            break
        end
    end

    if bAllConfirm then
        local winUser = deskInfo:findUserByUid(deskInfo.round.winnerUid)
        skynet.timeout(100, function()
            agent:roundOver(winUser)
        end)
    end

    retobj.userState = user.state
    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 自动加入机器人
function CMD.aiJoin(source, aiUser)
end

local function checkSupplyAi()
    if deskInfo.state == DeskState.Match and deskInfo:hasRealPlayer() and #deskInfo.users == 1 and skynet.now() < deskInfo.beginTime then
        local delayTime = deskInfo.beginTime - skynet.now() + 100
        skynet.timeout(delayTime, function ()
            if deskInfo.state == DeskState.Match and #deskInfo.users == 1 then
                aiJoinCS(2)
            end
        end)
    end
end

-- 退出房间
function CMD.exitG(source, msg)
    return cs(function()
        local user = deskInfo:findUserByUid(msg.uid)

        local unlock = false
        if user and (user.state == PlayerState.Wait or user.state == PlayerState.Drop or user.state == PlayerState.Fail)  then
            unlock = true
        end
        local ret = agent:exitG(msg, unlock)
        checkSupplyAi()
        return warpResp(ret)
    end)
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

function CMD.enterAuto(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then return end

    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}

    if user.auto == 1 then
        return warpResp(retobj)
    end

    user.auto = 1 -- 进入托管
    user.round.autocnt = 0

    deskInfo:autoMsgNotify(user, 1)
    
    return warpResp(retobj)
end

--! 出牌过程中 取消托管
function CMD.cancelAuto(source, msg)
    local recvobj  = msg
    LOG_DEBUG('cancelAuto, msg:', recvobj)
    local uid = math.sfloor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then return end

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if user.auto == 0 then
        return warpResp(retobj)
    end

    user.auto = 0 --关闭自动
    user.round.autocnt = 0

    -- 因为托管时间很短，这里不在重新开启计时器
    -- user:clearTimer()
    -- if user.state == PlayerState.Draw then
    --     retobj.delayTime = deskInfo.delayTime
    --     userSetAutoState('autoDraw', retobj.delayTime, uid)
    -- elseif user.state == PlayerState.Discard then
    --     retobj.delayTime = deskInfo.delayTime
    --     userSetAutoState('autoDiscard', retobj.delayTime, uid)
    if user.state == PlayerState.Confirm then
        user:clearTimer()
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoConfirm', retobj.delayTime, uid)
    end

    deskInfo:autoMsgNotify(user, 0, retobj.delayTime)

    return warpResp(retobj)
end

-- 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, _agent)
    deskInfo:updateUserAgent(uid, _agent)
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local desk = deskInfo:toResponse(msg.uid)
    if desk then
        for _, user in ipairs(desk.users) do
            if user.uid ~= msg.uid and user.round then
                for _, group in ipairs(user.round.groupcards) do
                    table.fill(group, 0)
                end
            end
        end
    end
    --LOG_DEBUG("getDeskInfo msg:", desk)
    return desk
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
    -- 实例化游戏
    agent = baseAgent(gameid, deskInfo)
    -- 绑定自定义方法
    ---@type AgentFunc
    local function autoAiJoin()
        return false
    end
    agent.func = {
        gameOver = gameOver,
        roundOver = roundOver,
        autoAiJoin = autoAiJoin,
    }
    -- 创建房间
    local err = agent:createRoom(msg, deskid, gameid, cluster_info)
    if err then
        return err
    end
    -- 房间底分
    local bet = deskInfo.bet
    deskInfo.basecoin = bet
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        deskInfo.waitTime = 10
        --加入机器人
        skynet.timeout(math.random(200, (deskInfo.waitTime-3)*100), function()
            aiJoinCS()
        end)

        skynet.timeout((deskInfo.waitTime+2)*100, function()
            cs(function()
                checkGameStart()
            end)
        end)
    else
        deskInfo.waitTime = 0
    end
    deskInfo.beginTime = skynet.now() + deskInfo.waitTime*100

    if msg.sid then
        stgy:load(msg.sid, gameid)
    end

    -- 获取桌子回复
    local desk = deskInfo:toResponse(deskInfo.owner)
    return PDEFINE.RET.SUCCESS, desk
end

function CMD.setPlayerExit(source, uid)
    return deskInfo:setPlayerExit(uid)
end

-- 加入房间
function CMD.join(source, cluster_info, msg, ip)
    return cs(function()
        local uid = msg.uid
        local err, retobj = agent:joinRoom(msg, cluster_info)
        -- 有返回则直接返回了对象
        if err then
            return err, retobj
        end
        -- 获取加入房间回复
        retobj = agent:joinRoomResponse(msg.c, uid)

        --检查是否可以开始游戏
        if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            checkGameStart(2)
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

-- 赛事开始游戏
function CMD.TNGameStart(source)
    agent:TNGameStart()
    return PDEFINE.RET.SUCCESS
end

-- 赛事关闭入口
function CMD.TNNoticCloseTime(source)
    agent:TNNoticCloseTime()
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

-- 换桌子
function CMD.switchDesk(source, msg)
    local spcode = 0
    local uid = msg.uid
    if (deskInfo.state == DeskState.Match or deskInfo.state == DeskState.Settle) then
        spcode = agent:switchDesk(msg)
    else
        local user = deskInfo:findUserByUid(uid)
        -- 弃牌后也可以换桌
        if user and (user.state == PlayerState.Wait or user.state == PlayerState.Drop or user.state == PlayerState.Fail)  then
            spcode = agent:switchDesk(msg)
        else
            spcode = 1
        end
    end
    checkSupplyAi()
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = spcode,
    }
    return warpResp(retobj)
end

-- 更新玩家信息
function CMD.updateUserInfo(source, uid)
    agent:updateUserInfo(uid)
end

-------- API更新桌子里玩家的金币 --------
function CMD.addCoinInGame(source, uid, coin, diamond)
    agent:addCoinInGame(uid, coin, diamond)
end

------ api取牌桌信息 ------
function CMD.apiGetDeskInfo(source,msg)
    return deskInfo:toResponse()
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
