-- 多人观战类房间控制类
local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)


local GAME_NAME = skynet.getenv("gamename") or "game"
local fightagent = {}

local READY_TIMEOUT = 25
local KICK_TIMEOUT = 5
local READY_AUTO_TIMEOUT = 13

local roomfactory = require "base.roomfactory"
local roomctl = require "base.roomctl"

local send_result = roomfactory.send_result
local init_user = roomfactory.init_user
local create_user = roomfactory.create_user
local getBrokenTimes = roomfactory.getBrokenTimes
local create_desk = roomfactory.create_desk
local revenue = roomfactory.revenue

local basehander = require "base.basehander"

function fightagent.start(game_hander, gameconfig)

    local game_cmd = gameconfig.CMD -- 消息命令
    local user_proxy = gameconfig.user_proxy -- user代理主要用于自动托管和AI控制

    assert(game_hander.create_deskinfo)
    assert(game_hander.create_userinfo)
    assert(game_hander.get_deskinfo_2c) -- 获取给uid 玩家发的桌子信息
    assert(game_hander.get_userinfo_2c) -- 获得玩家信息
    assert(game_hander.start_game)
    assert(game_hander.get_result)

    local deskobj = nil -- create 时候创建
    local closeServer = false -- 控制关闭服务
    local autoStartTimer = nil -- 自动开始游戏定时器
    local checkStartGame = nil

    -- DEBUG 
    local function print_deskusers(uid)
        local count = 0
        local tbl = {}
        for _, user in pairs(deskobj.users) do
            count = count + 1
            table.insert(tbl, user.uid)
        end
        LOG_DEBUG("PRINT_DESKUSERS !!!! %s, count %s , find uid is %s ", table.concat(tbl, ","), count, uid)
    end
    
    local function ready(recvobj)

        local code, retobj  =  basehander.ready(deskobj, recvobj)

        local pnum = 0
        for idx, userReady in pairs(deskobj.users) do
            if userReady.is_ready  then
                pnum = pnum + 1
            end
        end
        if pnum == deskobj.conf.seat or (pnum >= 2 and pnum == #deskobj.users) then
            skynet.timeout(1, function()
                checkStartGame()
            end)
        end

        return code, retobj
    end

    local function kickUser(user, type_)
        user:stop_action()
        local retobj = {}
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.c = PDEFINE.NOTIFY.NOTIFY_STUD_EXIT
        retobj.uid = user.uid
        retobj.kickType = type_
        retobj.seatid = user.seatid
        deskobj:broadcastdeskAll(retobj)
        deskobj:delUserFromDesk(user.uid)
        if user.uid == math.floor(deskobj.owner) then
            deskobj.owner = 0
        end

        pcall(cluster.call, "master", ".mgrdesk", "changMatchPreseat", GAME_NAME, deskobj.gameid, deskobj.deskid, -1)

        checkStartGame()
    end

    local function end_game(_, is_over)
        deskobj.state = 3
        for _, user in ipairs(deskobj.users) do
            user:stop_action()
            user.state = 0
        end
        local result = game_hander.get_result(deskobj, is_over)


        -- for idx, user_result in ipairs(data.users) do
        --     send_result(deskobj.users[idx], deskobj, user_result.addcoin, deskobj.conf.free)
        -- end
        result.ready_timeout = READY_TIMEOUT
        result.c = result.c and result.c or PDEFINE.NOTIFY.blance

        local  kickNum = 0
        for _, user in ipairs(deskobj.users) do
            if not user.is_vistor then
                user:init(); -- 上一把再打的人需要清理
            end
            user.info = game_hander.create_userinfo()
            if user.coin <= deskobj.leftcoin then
                user.info.kick_type = 1
            end
            if user.gj_count > 0 then
                user.gj_count_total = user.gj_count_total + 1
                if user.gj_count_total >= 3 then
                    user.info.kick_type = 3
                    kickNum = kickNum + 1
                end
            elseif user.ofline > 1 then
                user.of_count = user.of_count + 1
                user.of_count_total = user.of_count_total + 1
                if user.of_count >= 3 or user.of_count_total >= 6 then
                    user.info.kick_type = 2
                    kickNum = kickNum + 1
                end
            end
            -- LOG_DEBUG("----user.gj_count:",user.gj_count, "   --total:",user.gj_count_total)
            user.gj_count = 0
            if not user.is_vistor and user.info.kick_type > 0 then
                user:auto_action('KICK_USER', KICK_TIMEOUT, function ()
                    -- LOG_DEBUG("---------------------->>>踢出玩家 ！！！", user.uid)
                    kickUser(user, user.info.kick_type)
                end)
            end
        
        end
        for _, user in ipairs(deskobj.users) do
            -- LOG_DEBUG("~~~~~~~~~~~~~~~~~~~~~~~~----userinfo:",user)
            if user.info.kick_type == 0 then
                if not user.is_vistor and #deskobj.users - kickNum >= 2 then
                    result.ready_timeout = READY_AUTO_TIMEOUT
                    user:auto_action('READY_USER', READY_AUTO_TIMEOUT, function ()
                        ready({c = 35, uid = user.uid})
                    end)
                else
                    user:auto_action('KICK_USER', READY_TIMEOUT, function ()
                        -- LOG_DEBUG("---------------------->>>踢出玩家 ！！！", user.uid)
                        -- deskobj:autoKickuser(user)
                        kickUser(user, 2)
                        -- checkStartGame()
                    end)
                end
            end
        end
        deskobj:broadcastdeskAll(result)
        
        for len = #deskobj.vistor_users, 1, -1 do
            local vuser = deskobj.vistor_users[len]
            if vuser.isSitdown then
                table.remove(deskobj.vistor_users, len)
                table.insert(deskobj.users, vuser)
            end
        end
        -- TODO 房间状态清理
        game_hander.reset_deskinfo(deskobj) -- 清理工作
        -- table.merge(deskobj, game_hander.create_deskinfo())
        deskobj.state = 0
        if closeServer then
            closeServer = false
            deskobj:sysKickAllUser()
        end
    end

    local CMD = {}
    local DOING = {} --玩家同时操作 准备 + 离开

    local function dispatch_ai_msg(data, user)
        local c = data.c
        local cmd = PDEFINE.PROTOFUN[tostring(c)]
        local cmd = string.gsub(cmd, "cluster.game.dsmgr.", "")
        local f = CMD[cmd]
        if f then
            f(source, data)
        else
            local game_f = game_cmd[cmd]
            if game_f then
                local recvobj = data
                return game_f(deskobj, user, recvobj)
            end
        end
    end

    function CMD.create(source, cluster_info, msg, ip, deskid)
        -- local recvobj  = cjson.decode(msg)
        local recvobj = msg
        local uid = math.floor(recvobj.uid)
        local ssid = math.floor(recvobj.ssid or 0)
        local free = recvobj.free or 0 --体验场 free = 1 其他场次 free = 0
        local user, code

        recvobj.seatNum = recvobj.seatNum or 5
        code, deskobj, user = basehander.create(cluster_info, recvobj, ip, deskid)
        if code ~= PDEFINE.RET.SUCCESS then
            return code
        end
        deskobj.end_game = end_game
        local ok, data = game_hander.create_deskinfo(recvobj,deskobj.conf)
        if not ok then
            return data
        end
        table.merge(deskobj, data)

        local playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid) --去node服找对应的player
        if playerInfo.coin < deskobj.mincoin then
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end

        user.info = game_hander.create_userinfo() -- game user info
        if user_proxy then
            user_proxy(user, dispatch_ai_msg, deskobj)
        end
        user.is_vistor = true
        table.insert(deskobj.vistor_users, user)

        -- if deskobj.state == 0 then
        --     table.insert(deskobj.users, user)
        -- end
        local roomtype = recvobj.roomtype or 2
        deskobj.roomtype = math.floor(roomtype)

        deskobj.visitornum = #deskobj.vistor_users
        deskobj.owner = uid -- 房主
        local deskdata = game_hander.get_deskinfo_2c(deskobj:getdata(), uid)
        for idx, muser in ipairs(deskdata.users) do
            data.usersp[idx] = game_hander.get_userinfo_2c(user, tonumber(uid) == tonumber(muser.uid))
        end

        return PDEFINE.RET.SUCCESS, deskdata or {}
    end

    local userIsJoin = {}
    function CMD.join(source, cluster_info, msg, ip)
        -- local recvobj = cjson.decode(msg)
        local recvobj = msg
        LOG_DEBUG("-------join:",recvobj)
        local uid = math.floor(recvobj.uid)
        if userIsJoin[uid] then
            return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
        end
        userIsJoin[uid] = true
        local deskid = recvobj.deskid
        local code, user = basehander.join(deskobj, cluster_info, recvobj, ip)
        if code ~= PDEFINE.RET.SUCCESS then
            userIsJoin[uid] = nil
            return code
        end
        user.info = game_hander.create_userinfo()
        if user_proxy then
            user_proxy(user, dispatch_ai_msg, deskobj)
        end
        user.is_vistor = true
        user.of_count = 0
        user.of_count_total = 0
        user.gj_count = 0
        user.gj_count_total = 0
        table.insert(deskobj.vistor_users, user)
        local desk_data = game_hander.get_deskinfo_2c(deskobj:getdata(), uid)
        for idx, muser in ipairs(desk_data.users) do
            desk_data.users[idx] = game_hander.get_userinfo_2c(muser, tonumber(uid) == tonumber(user.uid))
        end
        local retobj  = {}
        retobj.c      = PDEFINE.NOTIFY.join
        retobj.code   = PDEFINE.RET.SUCCESS
        retobj.gameid = deskobj.gameid
        retobj.ssid   = deskobj.ssid
        retobj.deskid = deskobj.deskid
        retobj.deskinfo = desk_data
        local user_data = game_hander.get_userinfo_2c(user:getdata(), false)

        -- 看是否需要广播
        -- local ret = {
        --     c = PDEFINE.NOTIFY.join,
        --     code = PDEFINE.RET.SUCCESS,
        --     userinfo = user_data,
        -- }
        -- deskobj:broadcastdesk(ret, user.uid)
        --LOG_DEBUG("===========>>>> join ", uid, retobj)
        userIsJoin[uid] = nil
        return PDEFINE.RET.SUCCESS, retobj
    end

    local function start_game()
        if deskobj.state == 1 then
            return
        end
        if autoStartTimer then
            skynet.remove_timeout(autoStartTimer)
            autoStartTimer = nil
            deskobj.curTime = nil
        end
        deskobj.state = 1
        for _, user in ipairs(deskobj.users) do
            user:stop_action()
            user.is_vistor = false
            user.dstate = 0
        end
        game_hander.start_game(deskobj)
    end

    checkStartGame = function ()
        local readynum = 0
        for _,user in pairs(deskobj.users) do
            if user.state == 1 then
                readynum = readynum + 1
            end
        end
        if readynum == deskobj.conf.seat or (readynum >= 2 and readynum == #deskobj.users) then
            start_game()
        end
    end

    local function autoStartGame()
        autoStartTimer = nil
        deskobj.curTime = nil
        if deskobj.state == 0 then
            checkStartGame()
        end
    end

    -- 准备游戏
    function CMD.ready(source, msg)
        LOG_DEBUG("--------ready:",msg)
        local recvobj  = msg
        local uid     = math.floor(recvobj.uid)
        local user = deskobj:select_userinfo(uid)

        if not addDoing(uid) then
            return PDEFINE.RET.ERROR.ACT_AT_SAME_TIME
        end

        -- 准备时候如果金币不足需要退出房间
        if user.coin <= deskobj.leftcoin then
            releaseDoing(uid)
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
        -- LOG_DEBUG("----recvobj:", recvobj)
        local code, retobj = ready(recvobj)

        releaseDoing(uid)
        return code, retobj
    end

    -- 坐下协议、坐下就是准备
    function CMD.sitdown(source, msg)
        LOG_DEBUG("--------sitdown:",msg)
        -- LOG_DEBUG("----sitdown deskobj.vistor_users:",deskobj.vistor_users)
        local recvobj = msg
        local uid     = math.floor(recvobj.uid)
        local deskid  = math.floor(recvobj.deskid)
        local seatid  = math.floor(recvobj.seatid)
        local isfast = math.floor(recvobj.isfast or 0)

        if not addDoing(uid) then
            return PDEFINE.RET.ERROR.ACT_AT_SAME_TIME
        end

        local user = deskobj:select_userinfo(uid)
        if user and user.seatid then
            releaseDoing(uid)
            return PDEFINE.RET.ERROR.ERROR_HAD_SITDOWN  --玩家是否已坐下
        end
        if deskid ~= math.floor(deskobj.deskid) then
            releaseDoing(uid)
            return PDEFINE.RET.ERROR.DESKID_FAIL --桌子号对不对
        end

        local userInfo = nil
        for idx, muser in ipairs(deskobj.vistor_users) do
            if muser.uid == uid then
                if deskobj.state == 0 then
                    userInfo = table.remove(deskobj.vistor_users, idx)
                    table.insert(deskobj.users, userInfo)
                else
                    userInfo = deskobj.vistor_users[idx]
                end
                break
            end
        end
        --群众变为玩家
        if not userInfo then
            releaseDoing(uid)
            return PDEFINE.RET.ERROR.NOT_IN_ROOM --玩家不在房间内
        end

        --金币够不够门槛
        local playerInfo = cluster.call(userInfo.cluster_info.server, userInfo.cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        -- LOG_DEBUG("----info",playerInfo, " deskobj.mincoin:",deskobj.mincoin)
        if playerInfo.coin < deskobj.mincoin or playerInfo.coin <= 0 then
            releaseDoing(uid)
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
    

        -- if deskobj.state ~= 0 then
        -- if tonumber(deskobj.join) ~= 1 and gameStart then
            -- return PDEFINE.RET.ERROR.ERROR_NO_JOINMIDDLE --桌子不允许中途加入
        -- end

        -- LOG_DEBUG("-----deskobj.seat_list:",deskobj.seat_list)
        local ok = deskobj:getSpeSeatID(seatid)
        if isfast > 0 and not ok then
            local findSeat = 0

            for idx, sid in ipairs(deskobj.seat_list) do
                if findSeat == 0 then
                    findSeat = table.remove(deskobj.seat_list, idx)
                    break
                end
            end 
            if findSeat > 0 then
                LOG_DEBUG("-------->find~",findSeat)
                ok = true
                seatid = findSeat
            end
        end
        if not ok then
            releaseDoing(uid)
            return PDEFINE.RET.ERROR.ERROR_SEAT_EXISTS_USER --此位置是否已有人
        end
        local sTime = 3

        local notify  = {}
        notify.c      = PDEFINE.NOTIFY.leave --有围观群众离开
        notify.code   = PDEFINE.RET.SUCCESS
        notify.gameid = deskobj.gameid
        notify.ssid   = deskobj.ssid
        notify.deskid = deskobj.deskid
        notify.visitornum = #deskobj.vistor_users
        notify.user = { uid = uid , playername = playerInfo.playername, usericon= playerInfo.usericon}
        deskobj:broadcastdeskAll(notify)

        userInfo.dstate = deskobj.state
        userInfo.seat = seatid
        userInfo.is_ready = true --坐下就是准备
        user.isSitdown = true -- 玩家已坐下
        user.state = 1

        pcall(cluster.call, "master", ".mgrdesk", "changCurSeat", GAME_NAME, deskobj.gameid, deskobj.deskid, 1)
        LOG_DEBUG('坐下',deskobj.uuid, "坐下成功啦~~~~~~~ 座位编号:", seatid, " 玩家个数：", #deskobj.users)
        if deskobj.owner == 0 then
            deskobj.curTime = os.time() + sTime
            skynet.timeout(sTime * 100,function ( ... )
                checkStartGame()
            end)
        elseif #deskobj.users >= 2 and not autoStartTimer and deskobj.state == 0 then

            if deskobj.curTime == nil then
                deskobj.curTime = os.time() + sTime
                autoStartTimer = skynet.timeout(sTime * 100, function()
                    autoStartGame()
                end)
            end
        end
        

        local retobj  = {}
        retobj.c      = PDEFINE.NOTIFY.sitdown
        retobj.code   = PDEFINE.RET.SUCCESS
        retobj.gameid = deskobj.gameid
        retobj.ssid   = deskobj.ssid
        retobj.deskid = deskobj.deskid
        retobj.sTime = 0
        if deskobj.curTime and deskobj.state == 0 then
            retobj.sTime = deskobj.curTime - os.time()
        end
        retobj.user   = userInfo:getdata()
        deskobj:broadcastdeskAll(retobj, uid)
        
        retobj.c = math.floor(recvobj.c)
        releaseDoing(uid)
        return PDEFINE.RET.SUCCESS, retobj --返回
    end

    function CMD.auto(source, msg)
        local recvobj  = msg
        basehander.auto(recvobj)
        return PDEFINE.RET.SUCCESS
    end

    -- 整个游戏退出
    function CMD.exit()
        collectgarbage("collect")
        skynet.exit()
    end
    
    function CMD.getMulDeskInfo(source, msg)
        local recvobj = msg
        local uid = math.floor(recvobj.uid)
        local data = game_hander.get_deskinfo_2c(deskobj:getdata(), uid)
        local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, deskInfo = data}
        return PDEFINE.RET.SUCCESS, retobj
    end

    function CMD.getDeskInfo(source, msg)
        local recvobj = msg
        print(" CMD.getDeskInfo:", msg)
        local uid = math.floor(recvobj.uid)
        local data = game_hander.get_deskinfo_2c(deskobj:getdata(), uid)
        for _, user in ipairs(data.users) do
            user = game_hander.get_userinfo_2c(user, tonumber(uid) == tonumber(user.uid))
        end
        if tonumber(recvobj.c) == 21604 then -- 兼容处理
            return PDEFINE.RET.SUCCESS, cjson.encode(data)
        else
            if game_hander.renter then -- 重新进入
                skynet.timeout(10, function()
                    local user =  deskobj:select_userinfo(uid)
                    if not user then
                        LOG_DEBUG("GetDeskInfo ERROR !!! %s", uid)
                        print_deskusers(uid)
                        return
                    end
                    if user then
                        game_hander.renter(deskobj, user, recvobj)
                    end
                end)
            end
            return data
        end
    end

    function CMD.getVistors(source, msg)
        local recvobj = msg
        local uid     = math.floor(recvobj.uid)
        local deskid  = math.floor(recvobj.deskid)
        local user = deskobj:select_userinfo(uid)
        if not user then
            return PDEFINE.RET.ERROR.NOT_IN_ROOM
        end
        local userList = {}

        for _,muser in pairs(deskobj.vistor_users) do
            local item = {}
            item.uid        = muser.uid
            item.playername = muser.playername
            item.usericon    = muser.usericon
            table.insert(userList, item)
        end

        local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, vistors = userList}
        return PDEFINE.RET.SUCCESS, retobj
    end

    function addDoing(uid)
        if nil ~= DOING[uid] then
            return false
        end
        if nil == DOING[uid] then
            DOING[uid] = 1
        end
        return true
    end

    function releaseDoing(uid)
        if nil ~= DOING[uid] then
            DOING[uid] = nil
        end
    end

    -- 退出房间
    function CMD.exitG(source, msg)
        local recvobj = msg
        local uid     = math.floor(recvobj.uid)
        LOG_DEBUG("--------exitG:",msg)

        if not addDoing(uid) then
            return PDEFINE.RET.ERROR.ACT_AT_SAME_TIME
        end
        local exUser  =  deskobj:select_userinfo(uid)
        if not exUser then
            print_deskusers(uid)
            releaseDoing(uid)
            return PDEFINE.RET.SUCCESS
        end
        if deskobj.state == 0 then -- 0 未开始
            local retobj = {}
            retobj.c     = PDEFINE.NOTIFY.exit
            retobj.code  = PDEFINE.RET.SUCCESS
            retobj.uid   = uid
            retobj.seatid = exUser.seatid
            retobj.roomtype = deskobj.roomtype
            deskobj:broadcastdeskAll(retobj, uid)
            deskobj:delUserFromDesk(uid)
            if uid == math.floor(deskobj.owner) then
                deskobj.owner = 0
            end
            pcall(cluster.call, "master", ".mgrdesk", "changMatchPreseat", GAME_NAME, deskobj.gameid, deskobj.deskid, -1)
            checkStartGame()
        else
            exUser =  deskobj:select_userinfo(uid)
            if exUser.is_vistor then -- 访问者直接退出
                local retobj = {}
                retobj.c     = PDEFINE.NOTIFY.exit
                retobj.code  = PDEFINE.RET.SUCCESS
                retobj.uid   = uid
                retobj.seatid = exUser.seatid
                deskobj:broadcastdesk(retobj,uid)
                deskobj:delUserFromDesk(uid)
                if uid == math.floor(deskobj.owner) then
                    deskobj.owner = 0
                end
                pcall(cluster.call, "master", ".mgrdesk", "changMatchPreseat", GAME_NAME, deskobj.gameid, deskobj.deskid, -1)
                releaseDoing(uid)
                return PDEFINE.RET.SUCCESS
            else
                releaseDoing(uid)
                return PDEFINE.RET.ERROR.GAME_ING_ERROR --游戏中不能退出
            end
        end
        releaseDoing(uid)
        return PDEFINE.RET.SUCCESS
    end

    function CMD.start(source, msg)
        local recvobj = msg
        local uid     = math.floor(recvobj.uid)
        local user    = deskobj:select_userinfo(uid)
        if not user then
            return PDEFINE.RET.ERROR.AlREADY_BACK --用户已退出
        end
        if uid ~= math.floor(deskobj.owner) then
            return PDEFINE.RET.ERROR.NOT_ROOM_OWNER --不是房主
        end

        if deskobj.state == 1 then
            return PDEFINE.RET.ERROR.GAME_ING_ERROR --已在游戏中，请等下一局
        end
        if #deskobj.users < 2 then
            return PDEFINE.RET.ERROR.PERSON_NOT_ENOUGH --人数不足
        end
        deskobj.owner = 0 --房主开始游戏后，不再有房主
        checkStartGame()
        return PDEFINE.RET.SUCCESS
    end

    local function dispatchRoomctl(command, ...)
        if command == "sendChatMsg" then
            return false
        end
        local f = roomctl[command]
        if f then
            return true, skynet.retpack(f(deskobj, ...))
        end
        return false
    end

    skynet.start(function()
        skynet.dispatch("lua", function (_, address, cmd, ...)
            local ok, data = dispatchRoomctl(cmd, ...)
            if ok then
                return data
            end
            local f = CMD[cmd]
            if f then
                skynet.retpack(f(source, ...))
            else
                local game_f = game_cmd[cmd]
                if game_f then
                    local msg = ...
                    local recvobj = msg
                    local uid  = recvobj.uid
                    if not uid then
                        LOG_DEBUG("if user alone agent base , all msg need uid !!")
                        return
                    end
                    local user =  deskobj:select_userinfo(uid)
                    skynet.retpack(game_f(deskobj, user, recvobj))
                end
            end
        end)
    end)

    --其他一些API操作
    skynet.info_func(function ()
        return cjson.encode(deskobj:getdata())
    end)
end

return fightagent