local skynet = require "skynet"
local cluster = require "cluster"
local cjson = require "cjson"
local sportconst = require "sport.sportconst"
local sportutil = require "sport.sportutil"
require "sport.sporter"

--比赛
Sport = class()

function Sport:ctor(delegate, id, tid, mode, room_param, start_time, status, cur_round)
    self.delegate = delegate      -- 代理接口
    self.id = id                  -- 比赛ID
    self.tid = tid                -- 配置模版ID
    self.mode = mode              -- 比赛模式
    self.room_param = room_param  -- 房间参数
    self.start_tm = sportutil.timestruct(start_time)
    self.start_ostime = sportutil.ostimestamp(self.start_tm)
    self.end_ostime = self.start_ostime + 55*60 --默认55分钟
    if mode == sportconst.SPORT_MODE_DAILY then
        self.max_round = 1
    elseif mode == sportconst.SPORT_MODE_FINAL then
        self.max_round = 2
        self.next_round_time = self.start_ostime + sportconst.FINAL_SPORT_ROUND_DURATION
    end
    self.status = status          -- 比赛状态
    self.cur_round = cur_round    -- 当前轮数

    self.sporter_dict = {}          -- 参赛者表
    self.sporter_ranking_list = {}  -- 玩家排序列表
    self.ranking_need_update = true -- 是否需要重新排序

    self.wait_time = 10             -- 玩家等待时间
    self.wait_users = {}            -- 等待中玩家

    self.desk_list = {}             -- 比赛房间表
end

--从DB加载
function Sport:loadFromDb()
    local sql = string.format("SELECT A.uid, A.usericon, A.playername, B.score FROM d_user AS A INNER JOIN (SELECT user_id, score FROM d_sport_user WHERE sport_id = %d) AS B ON A.uid = B.user_id",
         self.id)
    local sporters = sportutil.mysql_exec(sql)
    if sporters then
        for _, sptr in pairs(sporters) do
            local user_id = tonumber(sptr.uid)
            local sporter = Sporter.new(self.id, self.tid, user_id, sptr.playername, sptr.usericon)
            sporter.score = tonumber(sptr.score)
            sporter.is_inserted = true
            self.sporter_dict[user_id] = sporter
        end
    end
end

--是否在比赛中
function Sport:isInSport(user_id)
    return (self.sporter_dict[user_id] ~= nil)
end

--剩余游戏次数
function Sport:getLeftGameCount(user_id)
    local cnt = 0;
    local sporter = self.sporter_dict[user_id]
    if sporter then
        cnt = sporter.games
    end
    return sportconst.MAX_GAME_COUNT - cnt
end

--加入比赛
function Sport:_join(user_id, nick, icon)
    if not self.sporter_dict[user_id] then
        local sporter = Sporter.new(self.id, self.tid, user_id, nick, icon)
        self.sporter_dict[user_id] = sporter
    end

    local sporter = self.sporter_dict[user_id]
    if sporter.desk_id ~= 0 then
        return 3
    end

    if sporter.games >= sportconst.MAX_GAME_COUNT then
        return 6
    end

    --进入分配列表
    if not table.contain(self.wait_users, user_id) then
        table.insert(self.wait_users, user_id)
    end
    self.wait_time = os.time()

    return 0
end

--取消匹配
function Sport:cancel(user_id)
    for idx, uid in ipairs(self.wait_users) do
        if uid == user_id then
            table.remove(self.wait_users, idx)
            break
        end
    end
end

--定时器
function Sport:_heartbeat(dt)
    LOG_WARNING("not implement")
end

--比赛开始
function Sport:_start()
    self.status = sportconst.SPORT_STATUS_GOING
    self:saveStatusToDb()
end

--分配桌子
function Sport:assign()
    local assign_count = 0
    local count = #self.wait_users
    -- LOG_DEBUG("等待人数: " .. count)
    while count > 0 do
        assign_count = assign_count + 1
        if assign_count > 5 then  --让出线程
            -- LOG_DEBUG("当前分配人数：" .. assign_count )
            return
        end

        local desk = self:findIdleDesk()
        -- if nil == desk then
        --     LOG_DEBUG("==============寻找不到桌子================")
        -- else
        --     LOG_DEBUG("==============寻找到桌子1================: ",  desk)
        -- end
        
        if desk then
            local uid = table.remove(self.wait_users, 1)
            self:joinDesk(desk, uid)
        else
            -- LOG_DEBUG("等待人数: " .. count, " 开始等待时间：" .. self.wait_time )
            if count <= 1 and self.wait_time + 8 > os.time() then  -- 无法配对时，等待15秒
                LOG_DEBUG("已经等待15s了")
                break
            end
            local uid = table.remove(self.wait_users, 1)
            -- LOG_DEBUG("要给用户创建桌子：" .. uid)
            self:createDesk(uid)
        end
        skynet.sleep(1)
        count = #self.wait_users
    end
    -- LOG_DEBUG("==============等待人数================: " .. count)
    --给空闲桌子分配机器人
    local desk = self:findIdleDesk()
    if nil == desk then
        -- LOG_DEBUG("==============寻找桌子2,找不到================: ")
    else
        -- LOG_DEBUG("==============寻找桌子2================: " , desk)
    end

    if desk and os.time() > desk.create_time + 5 then
        -- LOG_DEBUG("==============找到了桌子， 要添加1个机器人================: " , desk)
        self:addAi(desk)
    end
end

function Sport:findIdleDesk()
    -- LOG_DEBUG("-----当前的桌子数目：" .. #self.desk_list)
    for _, desk in ipairs(self.desk_list) do
        -- LOG_DEBUG("------当前桌子人数：", desk.curseat)
        if desk.curseat < 2 then
            return desk
        end
    end
end

-- 创建桌子
function Sport:createDesk(uid)
    local sporter = self.sporter_dict[uid]
    local agent = sporter:getAgent()
    if not agent then
        LOG_INFO("[Sport]玩家不在线，不能创建游戏")
        return nil
    end

    -- 创建桌子
    local params = table.copy(self.room_param)
    params.uid = uid

    local gameName = skynet.call(".mgrdesk", "lua", "getMatchGameName", params.gameid)
    local rs = PDEFINE_GAME.SESS['match'][params.gameid][params.ssid]
    params.typeid = 1
    params.virtualCoin = rs.param1 or 0
    params.basecoin = rs.basecoin or 0
    params.mincoin = rs.mincoin or 0
    params.leftcoin = rs.leftcoin or 0
    params.level = rs.level or 1
    params.free = rs.free or 0
    params.revenue = 0
    params.seat = rs.seat or 4
    params.param2 = rs.param2 or 0
    params.param3 = rs.param3 or 0
    params.param4 = rs.param4 or 0

    local msg = cjson.encode(params)
    local retok, retcode, retobj, deskAddr = pcall(cluster.call, gameName, ".dsmgr", "createDeskInfo", agent, msg, "127.0.0.1", params.gameid)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("[Sport]创建比赛房间失败", retok, retcode)
        return nil
    end
    -- LOG_INFO("[Sport]创建比赛房间成功", uid, cjson.encode(deskAddr))
    -- 加入桌子
    skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)

    --通知客户端
    local retmsg = cjson.decode(retobj)
    retmsg.c = 43
    retmsg.code = PDEFINE.RET.SUCCESS
    sporter.desk_id = deskAddr.desk_id
    self:sendAgentMsg(agent, retmsg)

    -- 设置玩家桌子
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)

    -- 保存桌子
    local desk = { server = deskAddr.server,
            address = deskAddr.address,
            gameid = deskAddr.gameid,
            desk_id = deskAddr.desk_id,
            sport_id = deskAddr.sport_id,
            desk_uuid = deskAddr.desk_uuid,
            create_time = os.time(),
            curseat = 1,
    }
    table.insert(self.desk_list, desk)
    -- LOG_DEBUG("~~~~~~添加的桌子信息~~~~~~：" .. desk)
    return desk
end

-- 加入桌子
function Sport:joinDesk(desk, uid)
    local sporter = self.sporter_dict[uid]
    local agent = sporter:getAgent()
    if not agent then
        LOG_INFO("[Sport]玩家不在线，不能加入游戏")
        return false
    end

    --加入桌子
    local params = table.copy(self.room_param)
    params.deskid = desk.desk_id
    params.uid = uid
    params.c = 43
    local msg = cjson.encode(params)
    local retok,retcode,retobj,deskAddr = pcall(cluster.call, desk.server, ".dsmgr", "joinDeskInfo", agent, msg, "127.0.0.1", params.gameid)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("[Sport]加入比赛房间失败", retok, retcode)
        return false
    end
    -- LOG_INFO("[Sport]加入比赛房间成功", uid, cjson.encode(deskAddr))
    -- 加入桌子
    skynet.call(".agentdesk","lua","joinDesk",deskAddr,uid)

    -- 人数加1
    desk.curseat = desk.curseat + 1
    sporter.desk_id = desk.desk_id

    --通知客户端
    local retmsg = cjson.decode(retobj)
    retmsg.c = 43
    retmsg.code = PDEFINE.RET.SUCCESS
    self:sendAgentMsg(agent, retmsg)

    -- 设置玩家桌子
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)

    return true
end

-- 加入机器人
function Sport:addAi(desk)
    local retok, retcode, userinfo = pcall(cluster.call, desk.server, desk.address, "aiJoin")
    if retok and retcode == PDEFINE.RET.SUCCESS then
        desk.curseat = desk.curseat + 1
        LOG_INFO("[Sport] addAi succ", desk.desk_id)
        --机器人信息添加进比赛玩家列表
        if userinfo then
            if not self.sporter_dict[userinfo.uid] then
                local sporter = Sporter.new(self.id, self.tid, userinfo.uid, userinfo.nick, userinfo.icon)
                self.sporter_dict[userinfo.uid] = sporter
            end
        end

        return true
    end
    LOG_WARNING("[Sport] addAi fail", retok, retcode, desk.desk_id)
    return false;
end

--比赛结束
function Sport:_finish()
    self.status = sportconst.SPORT_STATUS_END
    self:saveStatusToDb()
end

--当前状态
function Sport:getStatus()
    return self.status
end

function Sport:isFinished()
    return (self.status == sportconst.SPORT_STATUS_END)
end

--结算
function Sport:_settle(desk_id, players_score)
    for user_id, score in pairs(players_score) do
        LOG_DEBUG("------开始结算-----:", user_id, " score:", score)
        local sporter = self.sporter_dict[user_id]
        if sporter then
            sporter:settle(score)
            sporter.desk_id = 0
        end
    end
    -- 已完成桌子
    for idx, desk in ipairs(self.desk_list) do
        if desk_id == desk.id then
            table.remove(self.desk_list, idx)
            break
        end
    end
    self.ranking_need_update = true
end

--同步桌子人数
function Sport:syncDeskSeat(desk_id, seat)
    for _, desk in ipairs(self.desk_list) do
        if desk_id == desk.id then
            desk.curseat = seat
            break
        end
    end
end

-- 解散桌子
function Sport:dismissDesk(desk_id)
    for idx, desk in ipairs(self.desk_list) do
        if desk_id == desk.id then
            table.remove(self.desk_list, idx)
            break
        end
    end
    for _, sporter in pairs(self.sporter_dict) do
        if sporter.desk_id == desk_id then
            sporter.desk_id = 0
        end
    end
end

--排行
function Sport:getRanklist()
    if self.ranking_need_update then
        local sporter_list = {}
        for _, sporter in pairs(self.sporter_dict) do
            if sporter.ranking >= 0 then
                table.insert(sporter_list, {id=sporter.user_id, nk=sporter.nick, sc=sporter.score})
            end
        end

        table.sort(sporter_list, function (a, b)
            return a.sc > b.sc
        end)
        -- 排名
        for i, v in ipairs(sporter_list) do
            v.rk = i
        end

        -- 只取前100名
        if #sporter_list > sportconst.MAX_RANK_COUNT then
            for i=sportconst.MAX_RANK_COUNT+1, #sporter_list do
                sporter_list[i] = nil
            end
        end

        self.sporter_ranking_list = sporter_list
        self.ranking_need_update = false
    end

    return self.sporter_ranking_list;
end

function Sport:saveStatusToDb()
    local sql = string.format("UPDATE d_sport SET status='%d', cur_round='%d' WHERE id = '%d'",
            self.status, self.cur_round, self.id)
    sportutil.mysql_exec_async(sql)
end

function Sport:saveRankToDb(rand_data)
    local sql = string.format("UPDATE d_sport SET rank_data='%s' WHERE id = '%d'",
            rand_data, self.id)
    sportutil.mysql_exec_async(sql)
end

--发送奖励邮件
function Sport:sendRewardMail(uid, msg, gold_num, title)
    if nil == title then
        title = 'Grand Prize Game'
    end
    local mail_message = {
        uid = uid,
        fromuid = 0,
        msg  = msg,
        type = PDEFINE.MAIL_TYPE.WEBGIFT,
        title = title,
        attach = {{id=1, num=gold_num}},
        isall = 0,
        received = 0,
        sendtime = os.time(),
    }
    skynet.send(".mail", "lua", "sendSysMail", uid, cjson.encode(mail_message))
end

function Sport:sendAgentMsg(agent, msg)
    return pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(msg))
end

function Sport:sendUidMsg(uid, msg)
    local sporter = self.sporter_dict[uid]
    if sporter then
        return sporter:sendMsg(msg)
    end
    return false
end

