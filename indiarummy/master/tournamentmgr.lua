-- 私人房，数据存在内存中
-- 如果服务器重启，需要调用解散命令，将全部房间强行解散

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local date     = require "date"
local player_tool = require "base.player_tool"
local cjson = require "cjson"
local s_special_quest = require "conf.s_special_quest"
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local APP = tonumber(skynet.getenv("app")) or 1
local DEBUG = skynet.getenv("DEBUG")

-- 接口
local CMD = {}

local allDesks = {} -- 所有桌子列表, 二维数组 [gameid] = {desk}
local tn_list = nil  -- 场次配置
local his_tn_top3_redis = "tournament_his_top3"
local his_tn_info = nil
local delayFunc = {}  -- 倒计时函数
local tn_in_register = {}  -- 存在正在注册的用户数，防止超额注册
local Before_limit_time = 2*60*60  -- 往前推显示的场次
local After_limit_time = 2*60*60  -- 往后推显示的场次
local notice_before_start = 30  -- 提前多少秒弹窗提示
local waitSwitchKey = "tournament_switch_desk"

local offlineNotice = {
    "The league starts in 3 minutes, come on!",
    "The league is about to start, come and join!",
    "Only 3 minutes left to join the league!"
}

local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

-- 成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

-- 定时器
local function addTimer(delayTime, f, params)
    local function t()
        if f then
            f(params)
        end
    end
    skynet.timeout(math.floor(delayTime*100), t)
    return function(params) f=nil end
end

-- 转换时间字符串
-- 格式:  13:10
local function convertTime(stime, start)
    local now = os.date("*t", os.time())
    local hour = stime // 100
    local minute = stime % 100
    if start then
        return os.time({year=now.year, month=now.month, day=now.day, hour=hour, min=minute, sec=0})
    else
        return os.time({year=now.year, month=now.month, day=now.day, hour=hour, min=minute, sec=59})
    end
end

-- 获取当前正在注册人数
local function getRegisterCnt(tn_id)
    return tn_in_register[tn_id] or 0
end

-- 增加人数
local function addRegisterCnt(tn_id)
    if not tn_in_register[tn_id] then
        tn_in_register[tn_id] = 0
    end
    tn_in_register[tn_id] = tn_in_register[tn_id] + 1
end

-- 减少人数
local function removeRegisterCnt(tn_id)
    if tn_in_register[tn_id] and tn_in_register[tn_id] > 0 then
        tn_in_register[tn_id] = tn_in_register[tn_id] - 1
    end
end

-- 获取最近前3名玩家
local function getTop3Players()
    if not his_tn_info then
        local cacheData = do_redis({"get", his_tn_top3_redis})
        if cacheData then
            his_tn_info = cjson.decode(cacheData)
            if not his_tn_info.tn_info then
                his_tn_info = nil
            end
        end
    end
    return his_tn_info or nil
end

-- 获取最小座位数
local function getMinSeat(gameid)
    if gameid == PDEFINE_GAME.GAME_TYPE.TEXAS_HOLDEM then
        return 3
    end
    return PDEFINE_GAME.DEFAULT_CONF[gameid].minSeat
end

-- 获取当前正在游戏桌子数量
local function getOpenDeskCnt(tn_id)
    local cnt = 0
    for _, desk in pairs(allDesks) do
        if desk.tn_id == tn_id then
            if desk.is_close ~= 1 then
                cnt = cnt + 1
            end
        end
    end
    return cnt
end

-- 解散所有房间
local function dismissRoom(tn_id)
    LOG_DEBUG("tn dismissRoom:", tn_id)
    -- 解散所有房间
    local tmpDesks = {}
    for _, desk in pairs(allDesks) do
        if desk.tn_id == tn_id then
            pcall(cluster.send, desk.server, desk.address, "dismissRoom")
        else
            tmpDesks[desk.deskid] = desk
        end
    end
    allDesks = tmpDesks
end

-- 全部解散
local function dismissAllRoom()
    -- 解散所有房间
    for _, desk in pairs(allDesks) do
        pcall(cluster.send, desk.server, desk.address, "dismissRoom")
    end
    allDesks = {}
end

-- 告诉桌子需要换桌了
local function noticCloseTime(tn_id)
    -- 解散所有房间
    for _, desk in pairs(allDesks) do
        if desk.tn_id == tn_id then
            pcall(cluster.send, desk.server, desk.address, "TNNoticCloseTime")
        end
    end
end

-- 排序赛事中的玩家
local function sortPlayers(roundInfo)
    table.sort(roundInfo.players, function(a, b)
        -- 用户排序，按照分数来
        if a.state == PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER then
            return false
        end
        if b.state == PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER then
            return true
        end
        if a.state == PDEFINE.TOURNAMENT.PLAYER_STATE.OUT then
            if b.state == PDEFINE.TOURNAMENT.PLAYER_STATE.PLAYING then
                return false
            else
                return a.out_time > b.out_time
            end
        else
            if b.state == PDEFINE.TOURNAMENT.PLAYER_STATE.PLAYING then
                return a.coin > b.coin
            else
                return true
            end
        end
    end)
    for ord, player in ipairs(roundInfo.players) do
        player.ord = ord
    end
end

-- 发送邮件(退款和发送奖励)
---@param rtype integer 1=退款，2=奖励
local function sendMail(rtype, coin, uid, roundInfo)
    local msg_al, msg, title, title_al
    title_al = ""
    msg_al = ""
    if rtype == 1 then
        msg = "Today %s Classic Mode Not participating in the game Buy-in chips have been refunded."
        title = "Refund"
    else
        msg = "Today %s Classic Mode Competition reward chips have arrived."
        title = "Reward"
    end
    msg = string.format(msg, os.date("%H:%M", roundInfo.start_time))
    local attach = {}
    local mailid = genMailId()
    local mail_message = {
        mailid = mailid,
        uid = uid,
        fromuid = 0,
        msg  = msg,
        type = rtype == 1 and PDEFINE.MAIL_TYPE.TOURNAMENT_REFUND or PDEFINE.MAIL_TYPE.TOURNAMENT_SETTLE,
        title = title,
        attach = cjson.encode(attach),
        sendtime = os.time(),
        received = 1,
        hasread = 0,
        sysMailID= 0,
        title_al = title_al,
        msg_al = msg_al,
    }
    LOG_DEBUG("tournament send mail uid:", uid, ' coin:', coin, ' rtype:', rtype)
    skynet.send(".userCenter", "lua", "addUsersMail", uid, mail_message)
end


-- 加载配置
-- 配置会加载到内存中，如果没有则从数据库中读取
-- 数据库中的更改第二天生效
local function getConfigFromDB()
    local sql = "select * from d_tn_config";
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local tmp = {}
    local now = os.date("*t", os.time())
    if rs and #rs > 0 then
        for _, row in pairs(rs) do
            local item = {
                tn_id = row.id,
                gameid = row.gameid,
                bet = row.bet,
                buy_in = row.buy_in,
                ahead_time = row.ahead_time,
                state = PDEFINE.TOURNAMENT.DESK_STATE.WAIT_REGISTER,
                deadline_time = row.deadline_time,
                start_time = convertTime(row.start_time, true),
                stop_time = convertTime(row.stop_time, nil),
                is_playing = 0,  -- 是否是游戏中
                is_close = 0,  -- 等于1代表无法加入了
                pool_rate = row.pool_rate,
                init_coin = row.init_coin,
                max_cnt = row.max_cnt,
                min_cnt = row.min_cnt,
                win_ratio = string.split_to_number(row.win_ratio, ','),
                curr_cnt = 0,
                join_cnt = 0,
                players = {},  -- 报名的人
                pool_prize = row.min_cnt * row.buy_in * row.pool_rate // 100
            }
            -- 更新状态
            if os.time() > item.start_time - item.ahead_time and os.time() < item.start_time + item.deadline_time then
                item.state = PDEFINE.TOURNAMENT.DESK_STATE.WAIT_JOIN
            elseif os.time() >= item.start_time + item.deadline_time and os.time() < item.stop_time then
                -- 如果重启在游戏过程中，则这场比赛就失效了
                item.state = PDEFINE.TOURNAMENT.DESK_STATE.CANCEL
            elseif os.time() > item.stop_time then
                -- 从数据库中的结果判断是否正常结束
                local sql = string.format([[
                    select count(*) as cnt from d_tn_result where tn_id=%d and date=%s and status=1
                ]], item.tn_id, os.date("%Y-%m-%d", os.time()))
                local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                if rs and #rs > 0 then
                    if rs[1].cnt > 0 then
                        item.state = PDEFINE.TOURNAMENT.DESK_STATE.COMPLETED
                    else
                        item.state = PDEFINE.TOURNAMENT.DESK_STATE.CANCEL
                    end
                end
            end
            tmp[item.tn_id] = item
        end
    end
    -- 从数据中读取当前报名数
    local sql = string.format([[select * from d_tn_register where date='%s' and status=1]], os.date("%Y-%m-%d", os.time()))
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        for _, row in pairs(rs) do
            local item = tmp[row.tn_id]
            if item and item.start_time > os.time() then
                local player = {
                    uid = row.uid,
                    state = PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER,
                    coin = 0,
                }
                local fields = {'playername', 'avatarframe','usericon'}
                local userInfo = do_redis({ "hmget", "d_user:"..player.uid, table.unpack(fields)})
                userInfo = make_pairs_table(userInfo, fields)
                player.usericon = userInfo.usericon or 1
                player.avatarframe = userInfo.avatarframe or ""
                player.playername = userInfo.playername or ""
                table.insert(item.players, player)
                item.curr_cnt = item.curr_cnt + 1
                if item.curr_cnt > item.min_cnt then
                    item.pool_prize = item.curr_cnt * item.buy_in * item.pool_rate // 100
                end
            end
        end
    end
    -- 用列表存，不用hash表
    local list = {}
    for _, item in pairs(tmp) do
        table.insert(list, item)
    end
    tn_list = list
end

-- 获取房间列表, 赋值最新的状态
-- rn_ids 已报名的id
local function getRoundInfo(tn_id)
    local now = os.time()
    for _, item in pairs(tn_list) do
        if item.tn_id == tn_id then
            return item
        end
    end
    return nil
end

-- 重新计算金额
local function calcPoolPrize(roundInfo)
    -- 重新计算金额
    if roundInfo.curr_cnt > roundInfo.min_cnt then
        roundInfo.pool_prize = roundInfo.curr_cnt * roundInfo.buy_in * roundInfo.pool_rate // 100
    else
        roundInfo.pool_prize = roundInfo.min_cnt * roundInfo.buy_in * roundInfo.pool_rate // 100
    end
end

-- 获取桌子
local function getDesk(deskid)
    return allDesks[deskid]
end

-- 获取玩家
local function getPlayer(tn_id, uid)
    local roundInfo = getRoundInfo(tn_id)
    for _, player in ipairs(roundInfo.players) do
        if player.uid == uid then
            return player
        end
    end
    return nil
end

-- 获取当前参与人数
local function getJoinCnt(roundInfo)
    local cnt = 0
    for _, p in ipairs(roundInfo.players) do
        if p.state ~= PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER then
            cnt = cnt + 1
        end
    end
    return cnt
end

-- 设置开始广播定时器
local function setStartTimer(tn_info)
    local tn_id = tn_info.tn_id
    if not delayFunc[tn_id] then
        delayFunc[tn_id] = {}
    end
    if not delayFunc[tn_id].start then
        LOG_DEBUG("tn setStartTimer")
        local delayTime = tn_info.start_time - notice_before_start - os.time()
        if delayTime < 0 then
            delayTime = 1
        end
        delayFunc[tn_id].start = addTimer(delayTime, function()
            LOG_DEBUG("tn StartTime")
            local roundInfo = getRoundInfo(tn_id)
            local retobj = {
                c = PDEFINE.NOTIFY.NOTIFY_TN_GAME_START,
                code = PDEFINE.RET.SUCCESS,
                tn_id = tn_id,
                spcode = 0,
                start_time = roundInfo.start_time
            }
            for _, u in ipairs(roundInfo.players) do
                local agent = getAgent(u.uid)
                if agent then
                    pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(retobj))
                end
            end
        end)
    end
end

-- 设置离线通知开始
local function setNoticeTimer(tn_info)
    local tn_id = tn_info.tn_id
    if not delayFunc[tn_id] then
        delayFunc[tn_id] = {}
    end
    if not delayFunc[tn_id].offline_notice then
        LOG_DEBUG("tn setNoticeTimer")
        local delayTime = tn_info.start_time - tn_info.ahead_time - os.time()
        if delayTime < 0 then
            delayTime = 1
        end
        delayFunc[tn_id].offline_notice = addTimer(delayTime, function()
            LOG_DEBUG("tn NoticeTimer")
            local roundInfo = getRoundInfo(tn_id)
            roundInfo.state = PDEFINE.TOURNAMENT.DESK_STATE.WAIT_JOIN
            local offlineUids = {}
            for _, u in ipairs(roundInfo.players) do
                local agent = getAgent(u.uid)
                if not agent then
                    table.insert(offlineUids, u.uid)
                end
            end
            if not table.empty(offlineUids) then
                -- pcall(cluster.send, "node", ".pushmsg", "push", offlineUids, offlineNotice[math.random(#offlineNotice)])
            end
        end)
    end
end

-- 设置退款定时器
local function setRefundTimer(tn_info)
    local tn_id = tn_info.tn_id
    if not delayFunc[tn_id] then
        delayFunc[tn_id] = {}
    end
    if not delayFunc[tn_id].close then
        LOG_DEBUG("tn setRefundTimer")
        local delayTime = tn_info.start_time + tn_info.deadline_time - os.time()
        if delayTime < 0 then
            delayTime = 1
        end
        delayFunc[tn_id].close = addTimer(delayTime, function()
            LOG_DEBUG("tn RefundTime")
            local roundInfo = getRoundInfo(tn_id)
            local retobj = {
                c = PDEFINE.NOTIFY.NOTIFY_TN_GAME_REFUND,
                code = PDEFINE.RET.SUCCESS,
                tn_id = roundInfo.tn_id,
                start_time = roundInfo.start_time,
                spcode = 0,
                rewards = {},
            }
            local cnt = 0
            local refundCnt = 0
            local totalCnt = #roundInfo.players
            for _, u in ipairs(roundInfo.players) do
                if u.state ~= PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER then
                    cnt = cnt + 1
                end
            end
            -- 如果人数不满足要求，则将剩下的人也退款
            if cnt < roundInfo.min_cnt then
                roundInfo.is_close = 1
                retobj.is_dismiss = 1
            end
            local today = os.date('%Y-%m-%d', os.time())
            for _, u in ipairs(roundInfo.players) do
                if u.state == PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER or retobj.is_dismiss == 1 then
                    u.is_refunded = 1
                    refundCnt = refundCnt + 1
                    local coin = roundInfo.buy_in
                    retobj.rewards = {
                        {type=PDEFINE.PROP_ID.COIN, count=coin}
                    }
                    local title = '游戏:'.. roundInfo.gameid ..',赛事:'.. tn_id ..",退款:"..coin
                    player_tool.calUserCoin_nogame(u.uid, coin, title, PDEFINE.ALTERCOINTAG.TN_REWARD, 0)
                    -- 插入结果到数据库
                    local sql = string.format([[
                        insert into d_tn_result (tn_id, date, uid, ord, settle_coin, reward_coin, total_coin, status, create_time)
                        values (%d, '%s', %d, %d, %0.2f, %0.2f, %0.2f, %d, %d)
                    ]], roundInfo.tn_id, today, u.uid, 0, 0, coin, roundInfo.pool_prize, 3, os.time())
                    skynet.call(".mysqlpool", "lua", "execute", sql)
                    -- 更改报名状态
                    local sql = string.format([[
                        update d_tn_register set status=4 where uid=%d and date='%s' and tn_id=%d and status=1;
                    ]], u.uid, today, tn_id)
                    skynet.call(".mysqlpool", "lua", "execute", sql)
                    local agent = getAgent(u.uid)
                    if agent then
                        pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(retobj))
                    end
                    -- 发送退款邮件
                    sendMail(1, coin, u.uid, roundInfo)
                end
            end
            -- 清理列表
            if retobj.is_dismiss ~= 1 then
                local players = {}
                for _, u in ipairs(roundInfo.players) do
                    if not u.is_refunded then
                        table.insert(players, u)
                    end
                end
                roundInfo.players = players
                roundInfo.curr_cnt = #roundInfo.players
                -- 重新计算金额
                calcPoolPrize(roundInfo)
            end
            local sql = string.format([[
                    insert d_tn_stat (tn_id, gameid, start_time,stop_time,buy_in,rewardscoin,enrolcount,exitcount,create_time)
                    values(%d, %d, %d, %d, %d, %d, %d, %d, %d)
                ]], roundInfo.tn_id, roundInfo.gameid, roundInfo.start_time, roundInfo.stop_time, 
                roundInfo.buy_in, roundInfo.pool_prize, totalCnt, refundCnt, os.time())
            skynet.call(".mysqlpool", "lua", "execute", sql)
            if retobj.is_dismiss == 1 then
                roundInfo.state = PDEFINE.TOURNAMENT.DESK_STATE.CANCEL
                LOG_DEBUG("tn dismissRoom")
                -- 解散所有房间
                dismissRoom(roundInfo.tn_id)
            else
                roundInfo.state = PDEFINE.TOURNAMENT.DESK_STATE.ONGOING
                -- 轮训所有桌子，如果桌子里面人数不够的，直接开始换桌
                noticCloseTime(roundInfo.tn_id)
            end
        end)
    end
end

-- 设置游戏开始定时器
local function setStartGameTimer(roundInfo)
    if not delayFunc[roundInfo.tn_id] then
        delayFunc[roundInfo.tn_id] = {}
    end
    local tn_id = roundInfo.tn_id
    if not delayFunc[tn_id].startGame then
        LOG_DEBUG("tn setStartGameTimer")
        local delayTime = roundInfo.start_time - os.time()
        if delayTime < 0 then
            delayTime = 1
        end
        delayFunc[tn_id].startGame = addTimer(delayTime, function()
            local currRoundInfo = getRoundInfo(tn_id)
            local redisKey = waitSwitchKey..tn_id
            -- 开始前先删除等待队列
            do_redis({"del", redisKey})
            currRoundInfo.is_playing = 1
            for _, desk in pairs(allDesks) do
                if desk.tn_id == tn_id then
                    LOG_DEBUG("call TNGameStart, desk.server:", desk.server, " desk.address:", desk.address)
                    pcall(cluster.send, desk.server, desk.address, "TNGameStart")
                end
            end
        end)
    end
end

-- 减少某人
local function removePlayer(roundInfo, uid)
    local now = os.time()
    local todayZeroTime = date.GetTodayZeroTime()
    local sql = string.format("update d_tn_register set status=2,update_time=%d where uid=%d and date='%s' and tn_id=%d and status=1 and create_time > %d", 
                now, uid, os.date("%Y-%m-%d", now), roundInfo.tn_id, todayZeroTime)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    roundInfo.curr_cnt = roundInfo.curr_cnt - 1
    for idx, player in ipairs(roundInfo.players) do
        if player.uid == uid then
            table.remove(roundInfo.players, idx)
            break
        end
    end
    -- 重新计算金额
    calcPoolPrize(roundInfo)
end

-- 增加某人
local function addPlayer(roundInfo, uid)
    local now = os.time()
    local startTime = roundInfo.start_time
    local sql = string.format([[
        insert into d_tn_register (tn_id, date, uid, coin, status, update_time, create_time)
        values(%d, '%s', %d, %d, 1, %d, %d)
    ]], roundInfo.tn_id, os.date("%Y-%m-%d", startTime), uid, roundInfo.buy_in, now, now)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    local isExist = false
    for idx, p in ipairs(roundInfo.players) do
        if p.uid == uid then
            isExist = true
            p.state = PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER
        end
    end
    if not isExist then
        local player = {
            uid = uid,
            state = PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER
        }
        local fields = {'playername', 'avatarframe','usericon'}
        local userInfo = do_redis({ "hmget", "d_user:"..player.uid, table.unpack(fields)})
        userInfo = make_pairs_table(userInfo, fields)
        player.usericon = userInfo.usericon or 1
        player.playername = userInfo.playername or ""
        player.avatarframe = userInfo.avatarframe or ""
        table.insert(roundInfo.players, player)
    end
    roundInfo.curr_cnt = #roundInfo.players
    -- 重新计算金额
    calcPoolPrize(roundInfo)
end

-- 从桌子中解放某人
local function removeFromDesk(desk, uid)
    local removeDeskid
    for idx, p in ipairs(desk.players) do
        if p.uid == uid then
            table.remove(desk.players, idx)
            removeDeskid = desk.deskid
            break
        end
    end
    if removeDeskid then
        skynet.send(".agentdesk", "lua", "removeDesk", uid, removeDeskid)
    end
    -- 桌子没人了，设置桌子标识位
    if #desk.players == 0 then
        desk.is_close = 1
        -- pcall(cluster.send, desk.server, desk.address, "dismissRoom")
        -- allDesks[desk.deskid] = nil
    end
end

-- 除了某个桌子，从其他桌子删除玩家
local function removeFromDeskExpect(nowDesk, uid)
    for _, desk in pairs(allDesks) do
        if desk.deskid ~= nowDesk.deskid then
            local remove_deskid
            for idx, p in ipairs(desk.players) do
                if p.uid == uid then
                    remove_deskid = desk.deskid
                    table.remove(desk.players, idx)
                    break
                end
            end
            if remove_deskid then
                skynet.send(".agentdesk", "lua", "removeDesk", uid, remove_deskid)
            end
            -- 桌子没人了，则直接解散桌子
            if #desk.players == 0 then
                pcall(cluster.send, desk.server, desk.address, "dismissRoom")
                allDesks[desk.deskid] = nil
            end
        end
    end
end

-- 加入到桌子中
local function joinToDesk(desk, player)
    for _, p in ipairs(desk.players) do
        if p.uid == player.uid then
            return
        end
    end
    table.insert(desk.players, player)
    LOG_DEBUG("joinToDesk deskid:", desk.deskid, " currCnt:", #desk.players, " uid:", player.uid)
end

-- 发送更新消息
local function sendUpdateInfo(roundInfo)
    local retobj = {
        c = PDEFINE.NOTIFY.NOTIFY_TN_GAME_UPDATE,
        code = PDEFINE.RET.SUCCESS,
        tn_id = roundInfo.tn_id,
        join_cnt = roundInfo.join_cnt,
        curr_cnt = roundInfo.curr_cnt,
        min_cnt = roundInfo.min_cnt,
        players = roundInfo.players,
    }
    for _, u in ipairs(roundInfo.players) do
        if u.state == PDEFINE.TOURNAMENT.PLAYER_STATE.PLAYING then
            local agent = getAgent(u.uid)
            if agent then
                pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(retobj))
            end
        end
    end
end

-- 创建一个房间
-- 创建桌子
local function createDesk(roundInfo)
    local gameid = roundInfo.gameid
    local params = {
        uid = 1,
        taxrate = 0,
        gameid = gameid,
        conf = {
            initCoin = roundInfo.init_coin,
            seat = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT,
            minSeat = getMinSeat(gameid),
            entry = roundInfo.bet,
            roomtype = PDEFINE.BAL_ROOM_TYPE.TOURNAMENT,
            turntime = PDEFINE_GAME.DEFAULT_CONF[gameid].turntime,
            start_time = roundInfo.start_time,
            stop_time = roundInfo.stop_time,
            round = 1,
            tn_id = roundInfo.tn_id,
            is_playing = 0,  -- 场次是否在游戏中
        }
    }
    if roundInfo.is_playing == 1 then
        params.conf.is_playing = 1
    end
    local gameName = skynet.call(".mgrdesk", "lua", "getMatchGameName", gameid)
    local retok, retcode, retobj, deskAddr = pcall(cluster.call, gameName, ".dsmgr", "createDeskInfo", nil, params, "127.0.0.1", params.gameid)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("创建锦标赛房间失败", retok, retcode)
        return false, retcode
    end

    local desk = {
        tn_id = roundInfo.tn_id,
        is_close = 0,  -- 是否关闭桌子，不再加入，比如房间人数不够，被塞入其他房间
        server = deskAddr.server,
        address = deskAddr.address,
        gameid = deskAddr.gameid,
        deskid = deskAddr.desk_id,
        seat = params.conf.seat,
        desk_uuid = deskAddr.desk_uuid,
        create_time = os.time(),
        players = {},  -- 房间中的用户
        state = PDEFINE.DESK_STATE.WaitStart
    }
    allDesks[desk.deskid] = desk

    return true, desk, retobj
end

-- 加入桌子
local function joinDesk(desk, uid, tn_id, coin)
    local agent = getAgent(uid)
    local params = {}
    params.gameid = desk.gameid
    params.deskid = desk.deskid
    params.tn_id = tn_id
    params.uid = uid
    params.coin = coin  -- 是否换桌带入金币
    params.c = 43
    LOG_DEBUG("joinDesk: msg:", params)
    local retok,retcode,retobj,deskAddr = pcall(cluster.call, desk.server, ".dsmgr", "joinDeskInfo", agent, params, "127.0.0.1", params.gameid)
    LOG_DEBUG("joinDesk return retcode:".. retcode, ' deskAddr:', deskAddr)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("加入房间失败", retok, retcode)
        return retok,retcode,retobj,deskAddr
    end
    -- 加入桌子
    skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)
    
    if agent then
        pcall(cluster.send, agent.server, agent.address, "setClusterDesk", deskAddr) -- 设置玩家桌子
    end
    return true, 200, retobj, deskAddr
end

-- 是否所有桌子都已结束
local function checkAllFinish(tn_id)
    local allFinish = true
    for _, desk in pairs(allDesks) do
        if desk.tn_id == tn_id then
            if desk.state == PDEFINE.DESK_STATE.PLAY and desk.is_close == 0 then
                LOG_DEBUG("checkAllFinish: ", desk.deskid)
                allFinish = false
            end
        end
    end
    return allFinish
end

-- 结算所有用户
local function settleGame(tn_id)
    LOG_DEBUG("tn settleGame:", tn_id)
    local roundInfo = getRoundInfo(tn_id)
    if roundInfo.is_close == 1 or roundInfo.state == PDEFINE.TOURNAMENT.DESK_STATE.COMPLETED then
        return
    end
    roundInfo.is_close = 1
    roundInfo.state = PDEFINE.TOURNAMENT.DESK_STATE.COMPLETED
    do_redis({"del", waitSwitchKey..tn_id})
    -- 分发奖励
    local retobj = {
        c = PDEFINE.NOTIFY.NOTIFY_TN_GAME_SETTLE,
        code = PDEFINE.RET.SUCCESS,
        tn_id = roundInfo.tn_id,
        spcode = 0,
        players = {}
    }
    -- 前面3名需要处理下, 保留到redis，方便显示
    local top3 = {}
    for _, player in ipairs(roundInfo.players) do
        if player.state == PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER then
            break
        end
        if player.ord <= #roundInfo.win_ratio then
            local reward_coin = roundInfo.pool_prize * roundInfo.win_ratio[player.ord] // 100
            player.rewards = {{type=PDEFINE.PROP_ID.COIN, count=reward_coin}}
        end
        if player.ord <= 3 then
            table.insert(top3, table.copy(player))
        end
        table.insert(retobj.players, player)
    end
    if not table.empty(top3) then
        local his_top3_info = {
            players = top3,
            tn_info = {
                buy_in = roundInfo.buy_in,
                start_time = roundInfo.start_time,
                stop_time = roundInfo.stop_time,
                gameid = roundInfo.gameid,
                pool_prize = roundInfo.pool_prize,
            }
        }
        do_redis({"set", his_tn_top3_redis, cjson.encode(his_top3_info)})
        his_tn_info = his_top3_info
    end
    local today = os.date('%Y-%m-%d', os.time())
    for _, player in ipairs(retobj.players) do
        local coin = 0
        if player.rewards and #player.rewards > 0 then
            coin = player.rewards[1].count
            local title = '游戏:'.. roundInfo.gameid ..',赛事:'.. tn_id ..",排名:".. player.ord .. ',奖金:'..coin
            player_tool.calUserCoin_nogame(player.uid, coin, title, PDEFINE.ALTERCOINTAG.TN_REWARD, 0)
        end
        -- 插入结果到数据库
        local sql = string.format([[
            insert into d_tn_result (tn_id, date, uid, ord, settle_coin, reward_coin, total_coin, status, create_time)
            values (%d, '%s', %d, %d, %0.2f, %0.2f, %0.2f, %d, %d)
        ]], roundInfo.tn_id, today, player.uid, player.ord, player.coin, coin, roundInfo.pool_prize, 1, os.time())
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        local agent = getAgent(player.uid)
        if agent then
            pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(retobj))
        end
        if coin > 0 then
            -- 发送奖励邮件
            sendMail(2, coin, player.uid, roundInfo)
        end
    end
    -- 这里需要解散所有桌子
    skynet.timeout(200, function()
        dismissRoom(tn_id)
    end)
end

-- 获取比赛列表
function CMD.getList(msg)
    local uid = msg.uid
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        list = {},
        tn_ids = {},  -- 已报名的id
        his_winner = {},  -- 历史获奖者
    }
    -- 从数据库中获取自己报名的游戏列表
    local sql = string.format("select * from d_tn_register where date='%s' and uid=%d and status=1",
                os.date("%Y-%m-%d", os.time()), uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        for _, row in ipairs(rs) do
            table.insert(retobj.tn_ids, row.tn_id)
        end
    end
    for _, roundInfo in ipairs(tn_list) do
        if roundInfo.start_time > os.time() - Before_limit_time and roundInfo.start_time < os.time() + After_limit_time then
            local copyInfo = table.copy(roundInfo)
            copyInfo.is_register = 0
            for _, p in ipairs(copyInfo.players) do
                if p.uid == uid then
                    copyInfo.is_register = 1
                    break
                end
            end
            table.insert(retobj.list, copyInfo)
        end
    end
    table.sort(retobj.list, function (a, b)
        return a.start_time < b.start_time
    end)
    -- 从redis中读取上一次获奖的名单
    retobj.his_winner = getTop3Players()
    return resp(retobj)
end

-- 列出赛事详细信息
function CMD.detail(msg)
    local uid = msg.uid
    local tn_id = msg.tn_id
    local reconnect = msg.reconnect
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        reconnect = reconnect,
        tn_id = msg.tn_id,
        tn_info = nil,
    }
    if not tn_id then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_IS_EMPTY
        return resp(retobj)
    end
    retobj.tn_info = getRoundInfo(tn_id)
    return resp(retobj)
end

-- 报名比赛
function CMD.register(msg)
    local uid = msg.uid
    local tn_id = msg.tn_id
    local undo = msg.undo or 0  -- 是否取消报名
    local is_auto = msg.is_auto -- 是否自动加入
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        tn_id = tn_id,
        spcode = 0,
        uid = uid,
        undo = undo,
        is_auto = is_auto,
        tn_info = nil,  -- 当前的赛事信息
    }
    if not tn_id then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return resp(retobj)
    end
    local roundInfo = getRoundInfo(tn_id)
    if #roundInfo.players + getRegisterCnt(tn_id) >= roundInfo.max_cnt and undo == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.TN_CANNOT_REGISTER
        return resp(retobj)
    end
    if undo == 0 then
        addRegisterCnt(tn_id)
    end
    -- 检查自己是否报名
    local is_registered = false
    for _, p in ipairs(roundInfo.players) do
        if p.uid == uid then
            is_registered = true
        end
    end
    -- 判断桌子状态是否正确
    retobj.tn_info = getRoundInfo(tn_id)
    if os.time() > retobj.tn_info.start_time + retobj.tn_info.deadline_time then
        retobj.spcode = PDEFINE.RET.ERROR.TN_CANNOT_REGISTER
        if undo == 0 then
            removeRegisterCnt(tn_id)
        end
        return resp(retobj)
    end 
    -- 判断是否已报名
    if is_registered then
        if undo ~= 1 then
            retobj.spcode = PDEFINE.RET.ERROR.TN_REGISTERED
            if undo == 0 then
                removeRegisterCnt(tn_id)
            end
            return resp(retobj)
        end
    else
        if undo == 1 then
            retobj.spcode = PDEFINE.RET.ERROR.TN_UNREGISTERED
            return resp(retobj)
        end 
    end
    local currCoin = skynet.call(".userCenter", "lua", "getUserCoin", uid)
    local addcoin = -1 * retobj.tn_info.buy_in
    local act = "tn_register"
    if undo ~= 1 then
        -- 扣除金币参与游戏
        if currCoin < retobj.tn_info.buy_in then
            retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            if undo == 0 then
                removeRegisterCnt(tn_id)
            end
            return resp(retobj)
        end
    else
        addcoin = retobj.tn_info.buy_in
        act = "tn_unregister"
    end
    local title = retobj.tn_info.gameid .. '竞标赛:'..tn_id..'报名'
    player_tool.calUserCoin_nogame(uid, addcoin, title, PDEFINE.ALTERCOINTAG.TN_REGISTER, 0)
    retobj.aftercoin = currCoin + addcoin
    retobj.coin = addcoin
    if undo ~= 1 then
        retobj.tn_info.is_register = 1
        -- 增加注册信息
        addPlayer(retobj.tn_info, uid)
    else
        retobj.tn_info.is_register = 0
        -- 去掉注册信息
        removePlayer(retobj.tn_info, uid)
    end
    if undo == 0 then
        removeRegisterCnt(tn_id)
    end
    return resp(retobj)
end

-- 加入桌子
local function findRoom(roundInfo)
    local fdesk
    for _, desk in pairs(allDesks) do
        if #desk.players < desk.seat and desk.is_close == 0 and desk.tn_id == roundInfo.tn_id then
            fdesk = desk
            break
        end
    end
    if not fdesk then
        local ok, desk, joinResp = createDesk(roundInfo)
        if not ok then
            return nil
        else
            fdesk = desk
        end
    end
    return fdesk
end

-- 进入游戏
function CMD.enterRoom(msg)
    local uid = msg.uid
    local tn_id = msg.tn_id
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        tn_id = tn_id,
        spcode = 0,
        uid = uid,
        tn_info = nil,  -- 当前的赛事信息
    }
    if not tn_id then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_IS_EMPTY
        return resp(retobj)
    end
    -- 检查自己是否已报名
    local sql = string.format("select * from d_tn_register where date='%s' and uid=%d and tn_id=%d and status <> 2",
                            os.date("%Y-%m-%d", os.time()), uid, tn_id)
    LOG_DEBUG("enterRoom: ", sql)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local tn_ids = {}
    local registered = true
    if rs and #rs > 0 then
        if rs[1].status == 3 then
            retobj.spcode = PDEFINE.RET.ERROR.TN_ALREADY_USERED
            return resp(retobj)
        end
        -- if rs[1].status == 2 then
        --     registered = false
        -- end
    else
        registered = false
    end
    if not registered then
        retobj.spcode = PDEFINE.RET.ERROR.TN_UNREGISTERED
        return resp(retobj)
    end
    local roundInfo = getRoundInfo(tn_id)
    if roundInfo.is_close == 1 then
        retobj.spcode = PDEFINE.RET.ERROR.TN_STATE_ERROR
        return resp(retobj)
    end
    if roundInfo.start_time - roundInfo.ahead_time > os.time() or roundInfo.start_time + roundInfo.deadline_time < os.time() then
        retobj.spcode = PDEFINE.RET.ERROR.TN_STATE_ERROR
        return resp(retobj)
    end
    -- 先去缓存中找桌子，如果没有位置则新建一个桌子
    local fdesk = findRoom(roundInfo)
    if not fdesk then
        LOG_DEBUG("创建锦标赛房间失败:")
        retobj.spcode = PDEFINE.RET.ERROR.CALL_FAIL
        return resp(retobj)
    end
    -- 开始加入房间
    local retok,retcode,joinResp,deskAddr = joinDesk(fdesk, uid, tn_id)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        if retcode == PDEFINE.RET.ERROR.DESK_NO_SEAT or retcode == PDEFINE.RET.ERROR.DESK_ERROR or retcode == PDEFINE.RET.ERROR.SEATID_EXIST then
            LOG_DEBUG("房间已满或者状态不对，需要重新创建一个房间: msg", msg)
            -- 再给一次重试的机会，如果不行，就返回失败
            local fdesk = findRoom(roundInfo)
            if fdesk then
                retok,retcode,joinResp,deskAddr = joinDesk(fdesk, uid, tn_id)
            end
            if not retok or retcode ~= PDEFINE.RET.SUCCESS then
                LOG_DEBUG("再次加入失败: ", retok, retcode)
                retobj.spcode = retcode
                return resp(retobj)
            end
        else
            LOG_DEBUG("加入错误: retcode", retcode, " msg:", msg)
            retobj.spcode = retcode
            return resp(retobj)
        end
    end
    CMD.useTicket(uid, tn_id, deskAddr.desk_id)
    local agent = getAgent(uid)
    if agent then
        pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(joinResp)) -- 设置玩家桌子
    end
    return resp(retobj)
end

-- 进入游戏
function CMD.useTicket(uid, tn_id, deskid)
    LOG_DEBUG("tn useTicket", uid, tn_id, deskid)
    local roundInfo = getRoundInfo(tn_id)
    local player
    for _, p in ipairs(roundInfo.players) do
        if p.uid == uid then
            player = p
        end
    end
    -- 状态不对的情况下，不需要操作
    if not player or player.state ~= PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER then
        return
    end
    local sql = string.format("update d_tn_register set status=3 where uid=%d and tn_id=%d and status=1", uid, tn_id)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and rs.errno then
        LOG_ERROR("update d_tn_register error:", rs)
    end
    player.state = PDEFINE.TOURNAMENT.PLAYER_STATE.PLAYING
    player.coin = roundInfo.init_coin
    sortPlayers(roundInfo)
    local desk = getDesk(deskid)
    if not desk then
        LOG_ERROR("找不到比赛桌子")
    else
        joinToDesk(desk, {uid=uid, coin=roundInfo.init_coin})
    end
    -- 获取当前参与人数，满足人数则正式开始, 不满足人数则继续等待，告知当前人数
    local join_cnt = getJoinCnt(roundInfo)
    roundInfo.join_cnt = join_cnt
    -- 发送更新消息
    skynet.timeout(100, function ()
        sendUpdateInfo(roundInfo)
    end)
    -- 如果可以开始，则告知桌子开始游戏
    if join_cnt >= roundInfo.min_cnt then
        setStartGameTimer(roundInfo)
    end
end

-- 更新金币
function CMD.updateCoin(players, tn_id, deskid)
    LOG_DEBUG("tn updateCoin", players, tn_id, deskid)
    local uid_coin_map = {}
    local desk = getDesk(deskid)
    for _, player in ipairs(players) do
        uid_coin_map[player.uid] = player.coin
        if desk then
            for _, p in ipairs(desk.players) do
                if p.uid == player.uid then
                    p.coin = player.coin
                end
            end
        else
            LOG_DEBUG("can not find desk: ", deskid)
        end
    end
    local roundInfo = getRoundInfo(tn_id)
    for _, player in ipairs(roundInfo.players) do
        if uid_coin_map[player.uid] then
            player.coin = uid_coin_map[player.uid]
        end
    end
    -- 排序
    sortPlayers(roundInfo)
    -- 返回排名
    local ord_info = {}
    for ord, player in ipairs(roundInfo.players) do
        if uid_coin_map[player.uid] then
            table.insert(ord_info, {uid=player.uid, ord=ord})
        end
    end
    -- 如果时间不够30秒了，则不继续游戏了，等待结算
    local tonext = true
    LOG_DEBUG("tn updateCoin stop_time", roundInfo.stop_time, " os.time():", os.time())
    if roundInfo.stop_time - os.time() < 30 then
        tonext = false
        desk.is_close = 1
        desk.state = PDEFINE.DESK_STATE.WaitSettle
        -- 检测是否所有桌子都结束了
        if checkAllFinish(roundInfo.tn_id) then
            -- 延迟，先返回结果
            skynet.timeout(200, function()
                settleGame(roundInfo.tn_id)
            end)
        end
    end
    return ord_info, tonext
end

-- 淘汰出局
function CMD.weedOut(uid, tn_id, deskid)
    LOG_DEBUG("tn weedOut", uid, tn_id, deskid)
    local roundInfo = getRoundInfo(tn_id)
    if roundInfo.state == PDEFINE.TOURNAMENT.DESK_STATE.COMPLETED then
        return
    end
    for _, player in ipairs(roundInfo.players) do
        if player.uid == uid then
            player.state = PDEFINE.TOURNAMENT.PLAYER_STATE.OUT
            player.coin = 0
            player.out_time = os.time()  -- 淘汰时间, 会根据这个淘汰时间来排名
        end
    end
    local desk = getDesk(deskid)
    if desk then
        removeFromDesk(desk, uid)
    end
    sendUpdateInfo(roundInfo)
end

-- 查看是否有可用桌子加入
function CMD.checkSwitchDesk(deskid, tn_id)
    LOG_DEBUG("checkSwitchDesk", deskid)
    for _, desk in pairs(allDesks) do
        if desk.deskid ~= deskid and desk.tn_id == tn_id and desk.is_close ~= 1 then
            return true
        end
    end
    skynet.timeout(200, function()
        settleGame(tn_id)
    end)
    return false
end

-- 将人数加入换桌队列中
function CMD.trySwitchDesk(uids, deskid, tn_id)
    -- 加入到队列中
    local redisKey = waitSwitchKey..tn_id
    local prevDesk = getDesk(deskid)
    if prevDesk then
        prevDesk.is_close = 1
    end
    for _, uid in ipairs(uids) do
        LOG_DEBUG("switchDesk sadd uid:", uid)
        do_redis({"sadd", redisKey, uid})
    end
    return PDEFINE.RET.SUCCESS
end

-- 更换桌子
function CMD.switchDesk(tn_id)
    local redisKey = waitSwitchKey..tn_id
    -- 先看是否有人等待换桌
    local count = do_redis({"scard", redisKey})
    local roundInfo = getRoundInfo(tn_id)
    LOG_DEBUG("tn switchDesk cnt:", count, " tn_id:", tn_id)
    if count == 0 then
        return
    end
    local currDesks = {}
    for _, desk in pairs(allDesks) do
        table.insert(currDesks, desk)
    end
    -- 然后桌子排序
    table.sort(currDesks, function(a, b)
        return #a.players > #b.players
    end)
    -- 可以等待的桌子数量
    local to_cnt = 0
    -- 按照顺序往桌子里面塞玩家, 优先塞到用户多的房间
    for _, desk in ipairs(currDesks) do
        if desk.tn_id == tn_id and desk.is_close == 0 then
            to_cnt = to_cnt + 1
            local emptySeat = desk.seat - #desk.players
            if emptySeat > 0 then
                for i = 1, emptySeat, 1 do
                    local uid = do_redis({"spop", redisKey})
                    if uid then
                        uid = tonumber(uid)
                        -- 开始加入房间
                        -- 需要带入目前的金币
                        local player = getPlayer(tn_id, uid)
                        if not player then
                            LOG_DEBUG("switchDesk can not find uid:", uid, " tn_id", tn_id)
                            break
                        end
                        local retok,retcode,joinResp,deskAddr = joinDesk(desk, uid, tn_id, player.coin)
                        if not retok or retcode ~= PDEFINE.RET.SUCCESS then
                            LOG_DEBUG("switchDesk fail:", retok, retcode)
                            -- 失败了需要丢回去，防止不再继续了
                            do_redis({"sadd", redisKey, uid})
                            break
                        end
                        LOG_DEBUG("switchDesk success:", desk.deskid, " uid:", uid, " tn_id", tn_id)
                        joinToDesk(desk, {uid=uid, coin=player.coin})
                        local agent = getAgent(uid)
                        if agent then
                            pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(joinResp)) -- 设置玩家桌子
                        end
                        -- 加入房间后，不需要操作退出房间
                        -- skynet.call(".agentdesk", "lua", "removeDesk", uid, deskid)
                        removeFromDeskExpect(desk, uid)
                    else
                        break
                    end
                end
            end
        end
    end
    LOG_DEBUG("tn switchDesk to_cnt:", to_cnt)
    -- 如果当前人数还大于最小人数，则给他们分配新的桌子
    local roundInfo = getRoundInfo(tn_id)
    local currCnt = do_redis({"scard", redisKey})
    if roundInfo.is_close == 0 and currCnt > getMinSeat(roundInfo.gameid) then
        local ok, _, _ = createDesk(roundInfo)
        if not ok then
            LOG_DEBUG("中途创建锦标赛房间失败 当前人数:", currCnt)
        else
            LOG_DEBUG("中途创建锦标赛房间成功 当前人数:", currCnt)
        end
    else
        if to_cnt == 0 then
            -- 说明没有桌子等待
            skynet.timeout(200, function()
                settleGame(tn_id)
            end)
        end
    end
end

function CMD.exitRoom(uid, deskid, tn_id)
    LOG_DEBUG("tn exitRoom", uid, deskid, tn_id)
    local desk = getDesk(deskid)
    if desk then
        removeFromDesk(desk, uid)
    end
    -- 如果在等待队列中，则踢出等待队列
    local redisKey = waitSwitchKey..tn_id
    do_redis({"srem", redisKey, uid})
    local roundInfo = getRoundInfo(tn_id)
    for _, p in ipairs(roundInfo.players) do
        if p.uid == uid then
            if roundInfo.start_time > os.time() then
                p.state = PDEFINE.TOURNAMENT.PLAYER_STATE.NO_ENTER
                p.coin = nil
                local join_cnt = getJoinCnt(roundInfo)
                roundInfo.join_cnt = join_cnt
                if join_cnt < roundInfo.min_cnt and delayFunc[tn_id] and delayFunc[tn_id].startGame then
                    delayFunc[tn_id].startGame()
                    delayFunc[tn_id].startGame = nil
                end
                -- 改数据库
                local sql = string.format("update d_tn_register set status=1 where uid=%d and tn_id=%d and date='%s'",
                    uid, tn_id, os.date("%Y-%m-%d", os.time()))
                skynet.call(".mysqlpool", "lua", "execute", sql)
            else
                p.state = PDEFINE.TOURNAMENT.PLAYER_STATE.OUT
                p.out_time = os.time()
                p.coin = 0
                -- 改数据库
                local sql = string.format("update d_tn_result set status=2 where uid=%d and tn_id=%d and date='%s'",
                    uid, tn_id, os.date("%Y-%m-%d", os.time()))
                skynet.call(".mysqlpool", "lua", "execute", sql)
            end
            break
        end
    end
    sendUpdateInfo(roundInfo)
end

-- 标记桌子已经开始
function CMD.deskStart(deskid)
    local desk = getDesk(deskid)
    if desk then
        desk.state = PDEFINE.DESK_STATE.PLAY
    end
end

-- 隔一段时间检测下是否需要设置定时器
local function autoSetTimer()
    for _, tn_info in ipairs(tn_list) do
        -- 如果是5分钟内会开始，则设置定时器
        if tn_info.start_time > os.time() and tn_info.start_time < os.time() + 5*60 then
            -- 如果没有开始倒计时, 就增加一个倒计时
            setStartTimer(tn_info)
            setNoticeTimer(tn_info)
        end
        if tn_info.is_close == 0 and tn_info.start_time < os.time() and tn_info.start_time + tn_info.deadline_time > os.time() then
            -- 设置开始退款定时器
            setRefundTimer(tn_info)
        end
        -- 需要检测换桌
        if tn_info.is_close == 0 and tn_info.start_time < os.time() and tn_info.stop_time > os.time() then
            CMD.switchDesk(tn_info.tn_id)
        end
    end
    -- 打印下当前桌子情况，方便调试
    local cnt = 0
    for deskid, desk in pairs(allDesks) do
        cnt = cnt + 1
        local uids = {}
        for _, p in ipairs(desk.players) do
            table.insert(uids, p.uid)
        end
        -- LOG_DEBUG(string.format("当前桌子<%d> tn_id:%d, deskid: %d, players: [%s]", cnt, desk.tn_id, deskid, table.concat(uids, ',')))
    end
end

-- 刷新场次信息，重置老的场次(8小时前的)
local function resetTnConfig()
    -- 将8小时前的场次都重置了
    for _, tn_info in ipairs(tn_list) do
        if tn_info.stop_time < os.time() - 8*60*60 then
            local tn_id = tn_info.tn_id
            delayFunc[tn_id] = {}
            tn_in_register[tn_id] = 0
            for deskId, desk in pairs(allDesks) do
                if desk.tn_id == tn_id then
                    pcall(cluster.send, desk.server, desk.address, "dismissRoom")
                end
                desk[deskId] = nil
            end
            -- 将时间改成第二天的时间
            tn_info.start_time = tn_info.start_time + 86400
            tn_info.stop_time = tn_info.stop_time + 86400
            tn_info.state = PDEFINE.TOURNAMENT.DESK_STATE.WAIT_REGISTER
            tn_info.is_playing = 0
            tn_info.is_close = 0
            tn_info.players = {}
            tn_info.pool_prize = tn_info.min_cnt * tn_info.buy_in * tn_info.pool_rate // 100
        end
    end
end

local function timerLoop()
    while true do
        autoSetTimer()
        resetTnConfig()
        skynet.sleep(500)
    end
end




skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.timeout(500, function()
        getConfigFromDB()
    end)
    skynet.timeout(6000, function()
        -- 自动设置定时器，防止重启加载后，不会自动开始
        skynet.fork(timerLoop)
    end)
    skynet.register(".tournamentmgr")
    collectgarbage("collect")
end)