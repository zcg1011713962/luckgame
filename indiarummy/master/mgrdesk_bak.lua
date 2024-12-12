local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"
local game_tool = require "game_tool"
local player_tool = require "base.player_tool"
--游戏服有哪些房间
local CMD = {}
-- 管理玩家所在game节点信息  每个game服上有哪些房间号 及房间简单数据
local dsmgr     = {} --亲友+公开房间
local dsmgrgame = {} --匹配场 每个game上的房间号
local fight_desks   = {} --对战类游戏场次->桌子id
local bet_desks   = {} --下注类游戏场次->桌子id
local alone_desks   = {} --单机类游戏场次->桌子id
local hundredGameName = {} --百人场服对应

local CREATING = {}
CREATING[10]= 0    --红黑创建中
CREATING[5] = 0    --龙虎创建中
CREATING[6] = 0    --百人创建中
local APP = tonumber(skynet.getenv("app")) or 1

local userrunning = {} --玩家正在提交
local closeServer = nil --关服标记
local uid_in_private_game = {}  -- 在游戏中的人
local uid_in_match_game = {}  -- 在游戏中的人

function CMD.joinDsmgr(dsmgrname)
    dsmgr[dsmgrname] = {}
end

function CMD.getDsmgrName()
    return dsmgrgame
end

function CMD.apendDsmgr(dsmgrname, gameid, baseinfo)
    if dsmgr[dsmgrname] == nil then
        dsmgr[dsmgrname] = {}
    end
    if nil == dsmgr[dsmgrname][gameid] then
        dsmgr[dsmgrname][gameid] = {}
    end
    table.insert(dsmgr[dsmgrname][gameid], baseinfo)
end

function CMD.delteDsmgr(dsmgrname, gameid, deskid)
    if nil == dsmgr[dsmgrname] or nil == dsmgr[dsmgrname][gameid] then
        return
    end
    for k, item in pairs(dsmgr[dsmgrname][gameid]) do
        if item.deskid == deskid then
            table.remove(dsmgr[dsmgrname][gameid], k)
        end
    end
end

function CMD.joinDeskInfo(cluster_info,msg,IP)
    local recvobj= cjson.decode(msg)
    local deskid = math.floor(recvobj.deskid)
    for gamename, item in pairs(dsmgr) do
        for gameid,deskinfoList in pairs(item) do
            for _,deskinfo in pairs(deskinfoList) do
            if math.floor(deskinfo.deskid) == deskid then
                    local ok,retcode,retobj,cluster_desk = pcall(cluster.call, gamename, ".dsmgr", "joinDeskInfo", cluster_info,msg,IP, gameid)
                    LOG_INFO("ok,retcode,retobj,cluster_desk ", ok,retcode,retobj,cluster_desk )
                    if retcode == PDEFINE.RET.SUCCESS then
                        return PDEFINE.RET.SUCCESS,retobj,cluster_desk
                    else
                        return retcode
                    end
                end
            end
        end
    end
    return 700
end

--负载均衡取出一个房间服务的名字
function CMD.getGameName(gameid)
    local exincludeNames = {}
    for gamename,gameVlue in pairs(dsmgr) do
        if not table.empty(gameVlue) then
            for id,deskinfoList in pairs(gameVlue) do
                if tonumber(id) == tonumber(gameid) then
                    if #deskinfoList < 1000 then
                        return gamename
                    end
                    table.insert(exincludeNames, gamename)
                end
            end
        else
            return gamename
        end
    end


    local gameNames =  table.indices(dsmgr)
    if not table.empty(exincludeNames) then
        for _, exinclude in pairs(exincludeNames) do
            for k, name in pairs(gameNames) do
                if exinclude == name then
                    table.remove(gameNames, k)
                    break
                end
            end
        end
    end
    if table.empty(gameNames) then
        local gameNames2 =  table.indices(dsmgr)
        return gameNames2[1]
    end
    return gameNames[1]
end

--更改房间当前人数
function CMD.changCurSeat(gamename, gameid, deskid, num)
    deskid = math.floor(deskid)
    if nil == dsmgr or nil == dsmgr[gamename] or nil == dsmgr[gamename][gameid] then
        return false
    end
    for index, deskinfo in pairs(dsmgr[gamename][gameid]) do
        if math.floor(deskinfo.deskid) == deskid then 
            deskinfo.curseat = deskinfo.curseat + num
            if deskinfo.curseat > deskinfo.seat then
                deskinfo.curseat = deskinfo.seat
            end

            if deskinfo.curseat < 0 then
                deskinfo.curseat = 0
            end

            if deskinfo.curseat == 0 then
                table.remove(dsmgr[gamename][gameid], index)
            end
            break
        end
    end
end

--房间游戏状态修改
function CMD.changeDeskStatus(gamename, gameid, deskid, status)
    if nil == dsmgr[gamename][gameid] then
        return false
    end

    for index, deskinfo in pairs(dsmgr[gamename][gameid]) do
        if deskinfo.deskid == deskid then
            deskinfo.state = status
            LOG_INFO("deskinfo.state:", deskinfo.state)
            break
        end
    end
end


-- 开始新的一轮
function CMD.lockPlayer(deskid, uids, gameid, gametype)
    if gametype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, uid in ipairs(uids) do
            uid_in_match_game[uid..gameid] = {deskid=tonumber(deskid), gameid=tonumber(gameid)}
        end
    else
        for _, uid in ipairs(uids) do
            -- 这里不再记录，不需要再拉回原来的房间
            -- uid_in_private_game[tonumber(uid)] = {deskid=tonumber(deskid), gameid=tonumber(gameid)}
        end
    end
end

-- 解禁玩家，可以加入其它房间
function CMD.unlockPlayer(deskid, uids, gameid, gametype)
    if gametype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, uid in ipairs(uids) do
            uid_in_match_game[uid..gameid] = nil
        end
    else
        for _, uid in ipairs(uids) do
            uid_in_private_game[tonumber(uid)] = nil
        end
    end
end

-- 获取玩家当前所在桌子
function CMD.getPlayerDesk(uid, gametype, gameid)
    -- 这里坐下区分，好友房和匹配方是分开的
    if gametype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        return uid_in_match_game[uid..gameid]
    else
        return uid_in_private_game[tonumber(uid)]
    end
end

-- 告知玩家桌子，玩家已换游戏
function CMD.setPlayerExit(uid, deskid)
    local uid = tonumber(uid)
    local deskid = deskid and tonumber(deskid) or 0
    LOG_DEBUG("wait setPlayerExit: ", deskid, uid)
    for uidgameid, desk in pairs(uid_in_match_game) do
        local struid = tostring(uid)
        if string.sub(uidgameid,1,string.len(struid))==struid then
            local gameid = string.sub(uidgameid,string.len(struid)+1,string.len(uidgameid))
            gameid = tonumber(gameid)
            local gameName = CMD.getMatchGameName(gameid)
            if desk and desk.deskid ~= deskid and desk.gameid == gameid then
                LOG_DEBUG("setPlayerExit: ", desk.deskid, uid)
                pcall(cluster.send, gameName, ".dsmgr", "setPlayerExit", desk.deskid, uid)
            end
        end
    end
    if uid_in_private_game[uid] then
        local desk = uid_in_private_game[uid]
        local gameName = CMD.getMatchGameName(desk.gameid)
        LOG_DEBUG("setPlayerExit: ", desk.deskid, uid)
        pcall(cluster.send, gameName, ".dsmgr", "setPlayerExit", desk.deskid, uid)
    end
    local viewGame = skynet.call(".balprivateroommgr", "lua", "getViewRoom", uid)
    if viewGame and viewGame.deskid ~= deskid then
        LOG_DEBUG("setPlayerExit view: ", viewGame.deskid, uid)
        local gameName = CMD.getMatchGameName(viewGame.gameid)
        pcall(cluster.send, gameName, ".dsmgr", "setPlayerExit", viewGame.deskid, uid)
    end
end

--公开房 获取游戏对应的所有桌子
function CMD.getDeskList(gamename, gameid, all)
    local roomList = {}
    local limit = 10
    if all == 2 then
        limit = 1000
    end
    local num = 0
    if nil ~= dsmgr[gamename][gameid] then
        for index,deskinfo in pairs(dsmgr[gamename][gameid]) do
            if deskinfo.roomtype == 2 then
                num = num + 1
                table.insert(roomList, deskinfo)
                if num > limit then
                    break
                end
            end
        end
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(roomList)
end

------------------------------- 匹配场 ---------------------------
local function getBaseGameId(gameid)
    local basev = math.floor(gameid/100)
    local baseGameId = gameid
    if basev == 1 or basev == 4 or basev == 5 or basev == 6 or gameid == 238 then
        baseGameId = 100
    end
    return baseGameId
end

-- 是否区分场次 true:分场次，不乱匹配; false:多场次匹配到一起玩
local function isSessionGame(gameid)
    return false
end

function CMD.joinMatchDsmgr(gname)
    dsmgrgame[gname] = {}
end

function CMD.apendMatchDsmgr(gname,gameid, baseinfo)
    if nil == dsmgrgame[gname] then
        CMD.joinMatchDsmgr(gname)
    end

    if nil == dsmgrgame[gname][gameid] then
        dsmgrgame[gname][gameid] = {}
    end

    local maxRound = baseinfo.maxRound or 0
    if isSessionGame(gameid) then
        local ssid = baseinfo.ssid
        if nil == dsmgrgame[gname][gameid][ssid] then
            dsmgrgame[gname][gameid][ssid] = {}
        end
        if nil == dsmgrgame[gname][gameid][ssid][maxRound] then
            dsmgrgame[gname][gameid][ssid][maxRound] = {}
        end
        table.insert(dsmgrgame[gname][gameid][ssid][maxRound], baseinfo)
    else
        if nil == dsmgrgame[gname][gameid][maxRound] then
            dsmgrgame[gname][gameid][maxRound] = {}
        end
        table.insert(dsmgrgame[gname][gameid][maxRound], baseinfo)
    end
    LOG_DEBUG("after apendMatchDsmgr dsmgrgame:", dsmgrgame)
end

function CMD.deleteMatchDsmgr(gname, gameid, deskid, ssid, maxRound)
   --优先看为哪种类型的游戏
    if PDEFINE.GAME_TYPE_INFO[APP][1][gameid].MATCH == "BET" then
        return
    end

    local isSessGame = isSessionGame(gameid)
    if nil ~= dsmgrgame[gname] and nil ~= dsmgrgame[gname][gameid] then
        if isSessGame then
            if nil ~= dsmgrgame[gname][gameid][ssid] and nil ~= dsmgrgame[gname][gameid][ssid][maxRound] then
                for i=#dsmgrgame[gname][gameid][ssid][maxRound], 1, -1 do
                    local item = dsmgrgame[gname][gameid][ssid][maxRound][i]
                    if tonumber(item.deskid) == tonumber(deskid) then
                        table.remove(dsmgrgame[gname][gameid][ssid][maxRound], i)
                        break
                    end 
                end
            end
        else
            if nil ~= dsmgrgame[gname][gameid][maxRound] then
                for i=#dsmgrgame[gname][gameid][maxRound], 1, -1 do
                    local item = dsmgrgame[gname][gameid][maxRound][i]
                    if tonumber(item.deskid) == tonumber(deskid) then
                        table.remove(dsmgrgame[gname][gameid][maxRound], i)
                        break
                    end 
                end
            end

        end
    end

    --针对有场次id的对战类游戏
    if nil ~= fight_desks[gameid] then
        if isSessGame then
            if nil ~= fight_desks[gameid][ssid][maxRound] then
                for i=#fight_desks[gameid][ssid][maxRound], 1, -1 do
                    local item = fight_desks[gameid][ssid][maxRound][i]
                    if tonumber(item.deskid) == tonumber(deskid) then
                        table.remove(fight_desks[gameid][ssid][maxRound], i)
                        break
                    end 
                end
            end
        else
            if nil ~= fight_desks[gameid][maxRound] then
                for i=#fight_desks[gameid][maxRound], 1, -1 do
                    local item = fight_desks[gameid][maxRound][i]
                    if tonumber(item.deskid) == tonumber(deskid) then
                        table.remove(fight_desks[gameid][maxRound], i)
                        break
                    end 
                end
            end
        end
    end
end

--负载
function CMD.getMatchGameName(gameid)

    local gameInfo = skynet.call(".gamemgr", "lua", "getRow", gameid)
    if gameInfo~=nil and nil~=gameInfo.isHundred and gameInfo.isHundred==1 and not table.empty(hundredGameName) then
        if hundredGameName[gameid] ~= nil then
            return hundredGameName[gameid]
        end
    end

    local gameNames =  table.indices(dsmgrgame)
    if table.empty(gameNames) then
        return "game"
    end
    local index = math.random(#gameNames)
    return gameNames[index]

    -- local exincludeNames = {}
    -- for gamename,gameVlue in pairs(dsmgrgame) do
    --     if not table.empty(gameVlue) then
    --         for id,deskinfoList in pairs(gameVlue) do
    --             if tonumber(id) == tonumber(gameid) then
    --                 if #deskinfoList < 200 then
    --                     if gameInfo.isHundred and nil==hundredGameName[gameid] then
    --                         hundredGameName[gameid] = gamename
    --                     end
    --                     return gamename
    --                 end
    --                 table.insert(exincludeNames, gamename)
    --             end
    --         end
    --     else
    --         if gameInfo.isHundred and nil==hundredGameName[gameid] then
    --             hundredGameName[gameid] = gamename
    --         end
    --         return gamename
    --     end
    -- end

    -- local gameNames =  table.indices(dsmgrgame)
    -- if not table.empty(exincludeNames) then
    --     for _, exinclude in pairs(exincludeNames) do
    --         for k, name in pairs(gameNames) do
    --             if exinclude == name then
    --                 table.remove(gameNames, k)
    --                 break
    --             end
    --         end
    --     end
    -- end
    -- if table.empty(gameNames) then
    --     local gameNames2 =  table.indices(dsmgrgame)
    --     return gameNames2[1]
    -- end
    -- return gameNames[1]
end

--房间内准备的玩家人数同步
function CMD.changMatchUserReady(gname, gameid, deskid, num)
    LOG_INFO("changMatchUserReady gname, gameid, deskid, num", gname, gameid, deskid, num)
    gameid = math.floor(gameid)
    deskid = math.floor(deskid)
    if nil == dsmgrgame[gname][gameid] then
        return false
    end
    if isSessionGame(gameid) then
        for ssid, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, itemList in pairs(dataList) do
                for _, deskinfo in pairs(itemList) do
                    if deskinfo.deskid == deskid then
                        deskinfo.ready = deskinfo.ready + num
                        if deskinfo.ready < 0 then
                            deskinfo.ready = 0
                        end
            
                        if deskinfo.ready > deskinfo.seat then
                            deskinfo.ready = deskinfo.seat
                        end
                        break
                    end
                end
            end
        end
    else
        for round, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, deskinfo in pairs(dataList) do
                if deskinfo.deskid == deskid then
                    deskinfo.ready = deskinfo.ready + num
                    if deskinfo.ready < 0 then
                        deskinfo.ready = 0
                    end
                    if deskinfo.ready > deskinfo.seat then
                        deskinfo.ready = deskinfo.seat
                    end
                    break
                end
            end
        end
    end
end


--房间内准备的玩家人数
function CMD.changMatchUserSeatDown(gname, gameid, deskid, num)
    LOG_INFO("changMatchUserSeatDown gname, gameid, deskid, num", gname, gameid, deskid, num)
    gameid = math.floor(gameid)
    deskid = math.floor(deskid)
    if nil == dsmgrgame[gname][gameid] then
        return false
    end
    if isSessionGame(gameid) then
        for ssid, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, itemList in pairs(dataList) do
                for _, deskinfo in pairs(itemList) do
                    if deskinfo.deskid == deskid then
                        deskinfo.seatdown = deskinfo.seatdown + num
                        if deskinfo.seatdown < 0 then
                            deskinfo.seatdown = 0
                        end
    
                        if deskinfo.seatdown > deskinfo.seat then
                            deskinfo.seatdown = deskinfo.seat
                        end
                        break
                    end
                end
            end
        end
    else
        for round, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, deskinfo in pairs(dataList) do
                if deskinfo.deskid == deskid then
                    deskinfo.seatdown = deskinfo.seatdown + num
                    if deskinfo.seatdown < 0 then
                        deskinfo.seatdown = 0
                    end

                    if deskinfo.seatdown > deskinfo.seat then
                        deskinfo.seatdown = deskinfo.seat
                    end
                    break
                end
            end
        end
    end
end

--一局打完同步当前人数
function CMD.syncMatchCurUsers(gname, gameid, deskid, num, ssid)
    if nil==dsmgrgame[gname] or nil == dsmgrgame[gname][gameid] then
        return false
    end
    if isSessionGame(gameid) then
        for ssid, dataList in pairs(dsmgrgame[gname][gameid]) do
            for maxRound, itemList in pairs(dataList) do
                for _, deskinfo in pairs(itemList) do
                    if deskinfo.deskid == deskid then
                        deskinfo.curseat = num
                        deskinfo.preseat = num
                        if deskinfo.curseat == 0 then
                            CMD.deleteMatchDsmgr(gname, gameid, deskid, ssid, maxRound)
                        end
                        break
                    end
                end
            end
        end
    else
        for maxRound, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, deskinfo in pairs(dataList) do
                if deskinfo.deskid == deskid then
                    deskinfo.curseat = num
                    deskinfo.preseat = num
                    if deskinfo.curseat == 0 then
                        CMD.deleteMatchDsmgr(gname, gameid, deskid, ssid, maxRound)
                    end
                    break
                end
            end
        end
    end
end

function CMD.changMatchPreseat(gname, gameid, deskid, num)
    deskid = math.floor(deskid)
    if nil==dsmgrgame[gname] or nil == dsmgrgame[gname][gameid] then
        return false
    end
    if isSessionGame(gameid) then
        for ssid, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, itemList in pairs(dataList) do
                for _, deskinfo in pairs(itemList) do
                    if deskinfo.deskid == deskid then
                        if num < 0 then
                            deskinfo.preseat = deskinfo.preseat + num
                        end
                        if deskinfo.preseat < 0 then
                            deskinfo.preseat = 0
                        end
                        break
                    end
                end
            end
        end
    else
        for round, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, deskinfo in pairs(dataList) do
                if deskinfo.deskid == deskid then
                    if num < 0 then
                        deskinfo.preseat = deskinfo.preseat + num
                    end
                    if deskinfo.preseat < 0 then
                        deskinfo.preseat = 0
                    end
                    break
                end
            end
        end
    end
end

--更改房间内当前用户数
function CMD.changMatchCurUsers(gname, gameid, deskid, num)
    deskid = math.floor(deskid)
    if nil==dsmgrgame[gname] or nil == dsmgrgame[gname][gameid] then
        return false
    end
    if isSessionGame(gameid) then
        for ssid, dataList in pairs(dsmgrgame[gname][gameid]) do
            for maxRound, itemList in pairs(dataList) do
                for _, deskinfo in pairs(itemList) do
                    if deskinfo.deskid == deskid then
                        deskinfo.curseat = deskinfo.curseat + num
                        if num < 0 then
                            deskinfo.preseat = deskinfo.preseat + num
                        end
                        if deskinfo.curseat > deskinfo.seat then
                            deskinfo.curseat = deskinfo.seat
                        end
                        if deskinfo.preseat < 0 then
                            deskinfo.preseat = 0
                        end
                        if deskinfo.curseat < 0 then
                            deskinfo.curseat = 0
                        end
                        if deskinfo.curseat == 0 then
                            CMD.deleteMatchDsmgr(gname, gameid, deskid, ssid, maxRound) --针对有场次的，把场次id传过去
                        end
                        break
                    end
                end
            end
        end
    else
        for maxRound, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, deskinfo in pairs(dataList) do
                if deskinfo.deskid == deskid then
                    deskinfo.curseat = deskinfo.curseat + num
                    if num < 0 then
                        deskinfo.preseat = deskinfo.preseat + num
                    end
                    if deskinfo.curseat > deskinfo.seat then
                        deskinfo.curseat = deskinfo.seat
                    end
                    if deskinfo.preseat < 0 then
                        deskinfo.preseat = 0
                    end
                    if deskinfo.curseat < 0 then
                        deskinfo.curseat = 0
                    end
                    if deskinfo.curseat == 0 then
                        CMD.deleteMatchDsmgr(gname, gameid, deskid, 0, maxRound) --针对有场次的，把场次id传过去
                    end
                    break
                end
            end
        end
    end
end

--房间状态修改
function CMD.changeMatchDeskStatus(gname, gameid, deskid, status)
    gameid = math.floor(gameid)
    deskid = math.floor(deskid)
    if nil == dsmgrgame[gname] or nil == dsmgrgame[gname][gameid] then
        return false
    end
    if isSessionGame(gameid) then
        for ssid, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, itemList in pairs(dataList) do
                for _, deskinfo in pairs(itemList) do
                    if deskinfo.deskid == deskid then
                        deskinfo.state = status
                        if deskinfo.state == PDEFINE.DESK_STATE.READY then
                            deskinfo.ready = 0
                        end
                        break
                    end
                end
            end
        end
    else
        for round, dataList in pairs(dsmgrgame[gname][gameid]) do
            for _, deskinfo in pairs(dataList) do
                if deskinfo.deskid == deskid then
                    deskinfo.state = status
                    if deskinfo.state == PDEFINE.DESK_STATE.READY then
                        deskinfo.ready = 0
                    end
                    break
                end
            end
        end
    end
end

--按匹配顺序给房间排序
local function sortMathDesk(a, b)
    if a.state < b.state then
        return true
    elseif a.state > b.state then
        return false
    else
        if a.ready > b.ready then
            return true
        elseif a.ready < b.ready then
            return false
        else
            local ak = (a.seat - a.curseat)
            local bk = (b.seat - b.curseat)
            if ak > bk then
                return true
            elseif ak < bk then
                return false
            else
                return a.deskid > b.deskid
            end
        end
    end
end

-- 寻找合适的房间号
local function findMathDesks(desklist, gameName, gameid, ssid, maxRound)
    LOG_DEBUG(" findMathDesks dsmgrgame:", dsmgrgame, ' desklist:', desklist)
    if #desklist == 0 then return nil end
    if nil == dsmgrgame[gameName][gameid] then
        LOG_WARNING("not found 桌子id", gameid, desklist)
        return nil
    end

    local tmpdesklist = {}
    local isSess = isSessionGame(math.floor(gameid))
    local deskList = dsmgrgame[gameName][gameid]
    if isSess then
        deskList = dsmgrgame[gameName][gameid][ssid]
    end

    if gameid and isSessionGame(math.floor(gameid)) then
        if nil == dsmgrgame[gameName][gameid][ssid][maxRound] then
            LOG_WARNING("not found 桌子id", gameid, desklist)
            return nil
        end
    end
    local checkState = PDEFINE.DESK_STATE.MATCH
    if gameid == PDEFINE.GAME_TYPE.BLACK_JACK then checkState = 5 end
    for _, deskAddr in pairs(desklist) do
        if not deskAddr.ignore_match then
            for _, dataList in pairs(deskList) do
                for _, item in pairs(dataList) do
                    if deskAddr.desk_id == item.deskid then
                        if item.curseat ~= item.seat and item.preseat<item.seat and item.state <= checkState then
                            table.insert(tmpdesklist, item)
                        end
                    end
                end
            end
        end
    end

    LOG_DEBUG("findMathDesks qualified desklist：", cjson.encode(tmpdesklist))
    if table.empty(tmpdesklist) then
        return 0
    end

    table.sort(tmpdesklist, sortMathDesk)
    
    for _, dataList in pairs(deskList) do
        for _, item in pairs(dataList) do
            if tmpdesklist[1].deskid == item.deskid then
                item.preseat = item.preseat + 1
                if item.preseat > item.seat then
                    item.preseat = item.seat
                    break
                end
            end
        end
    end
    LOG_DEBUG("find this deskid:", tmpdesklist[1].deskid, " type:", type(tmpdesklist[1].deskid))
    return tmpdesklist[1].deskid
end

local match = {}
--百人场匹配
function match.matchBet(gameid)
    local ssdesklist
    local sslist = bet_desks[gameid]
    if nil == sslist then
        bet_desks[gameid] = {}
        bet_desks[gameid][1] = {}
        return false
    else
        ssdesklist = bet_desks[gameid][1] --场次下的房间列表
        if nil == ssdesklist or table.empty(ssdesklist) then
            bet_desks[gameid][1] = {}
            return false
        end
    end
    return ssdesklist[1].desk_id
end
--拉霸单机类匹配
function match.matchAlone(gameid)
    local ssdesklist
    local sslist = alone_desks[gameid]
    if nil == sslist then
        alone_desks[gameid] = {}
        alone_desks[gameid][1] = {}
    else
        ssdesklist = alone_desks[gameid][1] --场次下的房间列表
        if nil == ssdesklist or table.empty(ssdesklist) then
            alone_desks[gameid][1] = {}
        end
    end
    return false
end

-- 当分配了房间号，但是又加入失败的情况下，将预分配占用的位置号减1
local function decreasePreset(gameName, gameid, ssid, deskid)
    if nil == dsmgrgame[gameName] then
        return 
    end
    if nil == dsmgrgame[gameName][gameid] then
        return 
    end
    if nil == dsmgrgame[gameName][gameid][ssid] then 
        return 
    end

    for _, item in pairs(dsmgrgame[gameName][gameid][ssid]) do
        if item.deskid == deskid then
            item.preseat = item.preseat - 1
            if item.preseat < 0 then 
                item.preseat = 0
            end
            break
        end
    end
end

--战斗对战类匹配
function match.matchFight(gameid,ssid,uid,newplayercount, maxRound)
    --没有对应的游戏房间或者场次房间则创建
    if nil == fight_desks[gameid] then
        fight_desks[gameid] = {}
        if isSessionGame(gameid) then
            fight_desks[gameid][ssid] = {}
            if nil == fight_desks[gameid][ssid][maxRound] then
                fight_desks[gameid][ssid][maxRound] = {}
            end
        end
        
        return false
    else
        if isSessionGame(gameid) then
            if nil == fight_desks[gameid][ssid]  then
                fight_desks[gameid][ssid] = {}
            end
        end
    end
    if isSessionGame(gameid) then
        if nil == fight_desks[gameid][ssid][maxRound] then
            fight_desks[gameid][ssid][maxRound] = {}
        end
    else
        if nil == fight_desks[gameid][maxRound] then
            fight_desks[gameid][maxRound] = {}
        end
    end

    if newplayercount then
        newplayercount = math.floor(newplayercount)
        if newplayercount < PDEFINE.NEW_PLAYER_COUNT then
            return false
        end
    end

    local newssid = nil
    local ssdesklist 
    if isSessionGame(gameid) then
        ssdesklist = fight_desks[gameid][ssid][maxRound]--场次下的房间列表
    else
        ssdesklist = fight_desks[gameid][maxRound]
    end
    
    local gameName = CMD.getMatchGameName(gameid)
    local deskid = findMathDesks(ssdesklist, gameName, gameid, ssid, maxRound)
    if deskid == nil or deskid == 0 then
        return false
    end
    if newssid then
        ssid = newssid
    end

    local ok,deskInfo = pcall(cluster.call, gameName, ".dsmgr", "getDeskInfo", deskid)
    LOG_DEBUG("after dsmgr getDeskInfo ok:", ok, ' deskInfo:', deskInfo, ' gameName:', gameName)
    if not ok or deskInfo == nil then
        CMD.deleteMatchDsmgr(gameName, gameid, deskid, ssid, maxRound) --既然拿不到房间信息，必定是报错了
        LOG_ERROR(os.date("%Y-%m-%d %H:%M:%S", os.time()), " ~~~~~~ master matchSess错误 ~~ gameid ~~~~~~~ ", gameid)
        return false
    end
    --TODO: 桌子已经开始了不让匹配,
    if deskInfo and (deskInfo.seat == #deskInfo.users or deskInfo.state ~= PDEFINE.DESK_STATE.MATCH) then
        LOG_ERROR(os.date("%Y-%m-%d %H:%M:%S", os.time()), " ~~~~~~ master matchSess错误 ~~ gameid ~~~~~~~ ", gameid, ' 桌子已经开始了 deskid:', deskid)
        return false
    end
    if isSessionGame(gameid) then
        if deskInfo and deskInfo.users then
            for _, user in pairs(deskInfo.users) do
                if user.uid == uid then
                    decreasePreset(gameName, gameid, ssid, deskid)
                    return false
                end
            end

            local usernum = #deskInfo.users
            if usernum == 0 then
                CMD.deleteMatchDsmgr(gameName, gameid, deskid, deskInfo.ssid, deskInfo.maxRound) --房间里人数为0 ，必定是要被清理了
                return false
            end

            for _, item in pairs(dsmgrgame[gameName][gameid][ssid][deskInfo.maxRound]) do
                if item.deskid == deskid and usernum == item.seat  then 
                    item.preseat = item.seat
                    CMD.syncMatchCurUsers(gameName, gameid, deskid, usernum, ssid)
                    return false;
                end
            end
        end
    end
    return deskid
end

local function getGameNameByDeskid(deskid, gameid)
    for gamename, item in pairs(dsmgrgame) do
        for _gid, dataList in pairs(item) do
            if isSessionGame(_gid) then
                for ssid, roundItemList in pairs(dataList) do -- sess
                    for _, deskList in pairs(roundItemList) do --round
                        for _, desk in pairs(deskList) do
                            if math.floor(desk.deskid) == math.floor(deskid) then
                                return gamename
                            end
                        end
                        
                    end
                end
            else
                for _, deskList in pairs(dataList) do --round
                    for _, desk in pairs(deskList) do
                        if math.floor(desk.deskid) == math.floor(deskid) then
                            return gamename
                        end
                    end
                end
            end
        end
    end
end
--
local function setDeskId(gameid, ssid, deskAddr, maxRound)
    if not maxRound then
        maxRound = 0
    end
    LOG_DEBUG("setDeskId gameid:",gameid, ' ssid:', ssid, ' deskAddr:', deskAddr)
    -- local baseGameId = getBaseGameId(gameid)
    if PDEFINE.GAME_TYPE_INFO[APP][1][gameid].MATCH == "FIGHT" then
        if isSessionGame(gameid) then
            if not fight_desks[gameid][ssid][maxRound] then
                fight_desks[gameid][ssid][maxRound] = {}
            end
            table.insert(fight_desks[gameid][ssid][maxRound],deskAddr)
        else
            if not fight_desks[gameid][maxRound] then
                fight_desks[gameid][maxRound] = {}
            end
            table.insert(fight_desks[gameid][maxRound],deskAddr)
        end
    end
    LOG_DEBUG("setDeskId fight_desks:",fight_desks)

    if PDEFINE.GAME_TYPE_INFO[APP][1][gameid].MATCH == "BET" then
        table.insert(bet_desks[gameid][1],deskAddr)
    end

    if PDEFINE.GAME_TYPE_INFO[APP][1][gameid].MATCH == "ALONE" then
        table.insert(alone_desks[gameid][1],deskAddr)
    end
end

-- 匹配场次
function CMD.matchSess(cluster_info, msg, ip, newplayercount)
    local recvobj = msg
    LOG_DEBUG("matchSess msg:", msg)
	local gameid = math.floor(recvobj.gameid)
	local deskid = recvobj.deskid and math.floor(recvobj.deskid) or nil
    local reqssid = recvobj.ssid or 1 --用户选中的场次 1: 普通场 2:高级场
    local maxRound = tonumber(recvobj.round or 1) --大于0 则表示多局
    recvobj.maxRound = maxRound
	reqssid   = math.floor(reqssid)
	local uid    = math.floor(recvobj.uid)
    if closeServer then
        local inWhiteList = skynet.call(".loginmaster", "lua", "InWhiteList", uid, ip) --判断uid或ip是否在白名单
        if not inWhiteList then
            return PDEFINE.RET.ERROR.ERROR_GAME_FIXING
        end
    end
    local gameType = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].MATCH
    -- 如果是非slots则需要判断是否还在房间内
    if gameType ~= "ALONE" then
        -- 是否是从好友房退出的
        local desk = CMD.getPlayerDesk(uid, PDEFINE.BAL_ROOM_TYPE.MATCH, gameid)
        LOG_DEBUG("matchSess", desk)
        if desk then
            -- 如果原来的房间还在，则强制回原来的房间
            recvobj.deskid = desk.deskid
            local ok,retcode,retobj,cluster_desk = pcall(cluster.call, "game", ".dsmgr", "joinDeskInfo", cluster_info,recvobj,ip, desk.gameid)
            if retcode == PDEFINE.RET.SUCCESS then
                skynet.call(".agentdesk","lua","joinDesk",cluster_desk,uid)
                return PDEFINE.RET.SUCCESS,retobj,cluster_desk
            else
                return retcode
            end
        end
    end

    -- local baseGameId = getBaseGameId(gameid)
    LOG_DEBUG("reqssid:", reqssid)
    if reqssid == 0 and gameType == "FIGHT" then --用户金币超过了点击的场次金币范围，需要系统自动分配场次
        local playerInfo = player_tool.getPlayerInfo(uid)
        local sessList = PDEFINE_GAME.SESS.match[gameid]
        for i=#sessList, 1, -1 do
            if playerInfo.coin >= sessList[i].section[1] then
                reqssid = sessList[i].ssid
                LOG_DEBUG("sessList reqssid:", reqssid)
                break
            end
        end
    end
    if gameid == 255 then
        reqssid = 1
    end
    local ssid = reqssid
    if gameid ~= 256 and gameid ~= 257 then
        if reqssid == 1 or reqssid== 2 then --低场次默认值
            ssid = 0
        end
    end

    local cmd = PDEFINE.GAME_MATCH[gameType]
    local f = match[cmd]
    deskid = f(gameid,ssid,uid,newplayercount, maxRound)

    if gameType == "FIGHT" then
        --检测游戏状态gameid
        local gameinfo = skynet.call(".gamemgr", "lua", "getRow", tonumber(gameid))
        LOG_DEBUG("mgrdesk gameid:", gameid, " gameinfo: ", gameinfo)
        if nil == gameinfo or gameinfo.status == 0 then
            return PDEFINE.RET.ERROR.BAD_REQUEST --客户端提示没有权限
        end
        local settingdata = game_tool.gamesetting.getGameSetting(gameid, uid)
        if tonumber(settingdata.state) == 1 then
            return PDEFINE.RET.ERROR.CREATE_DESK_ERROR
        end
        if nil ~= userrunning[uid] then
            return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
        end
        userrunning[uid] = 1
        LOG_DEBUG("PDEFINE_GAME.SESS reqssid:", reqssid, ' gameid:', gameid)
        local sess = PDEFINE_GAME.SESS['match'][gameid][reqssid]
        if not sess then
            -- TODO:场次id不对
            userrunning[uid] = nil
            return PDEFINE.RET.ERROR.CREATE_AT_THE_SAME_TIME, gameid
        end
        recvobj.ssid = reqssid --用户选中的场次参数
        recvobj.conf = {
            ['roomtype'] = PDEFINE.BAL_ROOM_TYPE.MATCH,
            ['round'] = 1,
            ['entry'] = sess.entry,
            ['score'] = sess.score,
            ['turntime'] = sess.turntime or 0,
            ['shuffle'] = sess.shuffle or 1,
            ['voice'] = sess.voice or 0,
            ['private'] = 0,
            ['seat'] = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT  -- 这里取默认配置的座位数量
        }
    end

    -- 告知其他房间，已加入新房间
    CMD.setPlayerExit(uid, deskid)

    local gameName = CMD.getMatchGameName(gameid)
    if not deskid then
        if gameType == "BET" then
            if CREATING[gameid] == 1 then
                userrunning[uid] = nil
                return PDEFINE.RET.ERROR.CREATE_AT_THE_SAME_TIME, gameid
            end
            CREATING[gameid] = 1
        end

        --场次下面没有房间，只能直接去创建了
        LOG_DEBUG("=====CMD.matchSess=====gameid:", gameid, " ssid:", ssid, " uid:", uid, " reqssid:", reqssid)
        recvobj.seat    = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT
        recvobj.taxrate = 0
        local ok, gameInfo = pcall(skynet.call, ".gamemgr", "lua", "getRow", gameid)
        if ok and gameInfo and gameInfo.taxrate then
            recvobj.taxrate = gameInfo.taxrate/1000
        end
        LOG_DEBUG('gameid:', gameid, ' recvobj.taxrate:', recvobj.taxrate)
		local retok, retcode, retobj, deskAddr = pcall(cluster.call, gameName, ".dsmgr", "createDeskInfo", cluster_info, recvobj, ip, gameid, newplayercount)
        LOG_DEBUG("retok:",retok, ' retcode:', retcode, ' retobj:', retobj)
		if retcode ~= 200 then
            userrunning[uid] = nil
            if nil ~= CREATING[gameid] then
                CREATING[gameid] = 0
            end
			return retcode
		end

        skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)
        --保存对应的游戏ID
        setDeskId(gameid, ssid, deskAddr, maxRound)
        userrunning[uid] = nil
        if nil ~= CREATING[gameid] then
            CREATING[gameid] = 0
        end

		return PDEFINE.RET.SUCCESS,retobj,deskAddr
    else
		recvobj.deskid = deskid
        LOG_INFO("加入房间：", recvobj)
        local gamename = getGameNameByDeskid(deskid, gameid)
        if gamename then
            local ok,retcode,retobj,cluster_desk = pcall(cluster.call, gamename, ".dsmgr", "joinDeskInfo", cluster_info,recvobj,ip, gameid)
            userrunning[uid] = nil
            if retcode == PDEFINE.RET.SUCCESS then
                skynet.call(".agentdesk","lua","joinDesk",cluster_desk,uid)
                return PDEFINE.RET.SUCCESS,retobj,cluster_desk
            else
                return retcode
            end
        end
        userrunning[uid] = nil
		return 700
	end
end

--后台接口：获取游戏对应的所有桌子
function CMD.apiDeskList(gameid, type)
    local datasource = nil
    if "room" == type then
        datasource = table.copy(dsmgr)
    else
        datasource = table.copy(dsmgrgame)
    end
    local roomList = {}
    for gname , item in pairs(datasource) do
        for mgid, desklist in pairs(item) do
            if tonumber(mgid) == tonumber(gameid) then
                roomList = desklist
            end
        end
    end

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.gameid = gameid
    retobj.roomlist = roomList

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--后台接口：关闭游戏入口
function CMD.apiCloseServer()
    closeServer = true
    --通知匹配场
    for gamename, _ in pairs(dsmgrgame) do
        pcall(cluster.call, gamename, ".dsmgr", "apiCloseServer", closeServer)
    end
    --通知房卡场
    for gamename, _ in pairs(dsmgr) do
        pcall(cluster.call, gamename, ".dsmgr", "apiCloseServer", closeServer)
    end
    return PDEFINE.RET.SUCCESS,'succ'
end

--后台接口：开启游戏入口
function CMD.apiStartServer()
    closeServer = nil
    --通知匹配场
    for gamename, item in pairs(dsmgrgame) do
        pcall(cluster.call, gamename, ".dsmgr", "apiCloseServer", closeServer)
    end
    --通知房卡场
    for gamename, item in pairs(dsmgr) do
        pcall(cluster.call, gamename, ".dsmgr", "apiCloseServer", closeServer)
    end
    --通知登录服
    -- pcall(cluster.call, "login", ".login_master", "start")
    return PDEFINE.RET.SUCCESS,'succ'
end

--后台接口：房间里面的信息
function CMD.apiDeskInfo(gameid, type, deskid)
    local datasource = nil
    if type == 'room' then
        datasource = table.copy(dsmgr)
    else
        datasource = table.copy(dsmgrgame)
    end
    local resp = { code = PDEFINE.RET.SUCCESS }
    for gamename, item in pairs(datasource) do
        for _,deskinfoList in pairs(item) do
            for _,deskinfo in pairs(deskinfoList) do
                if tonumber(deskinfo.deskid) == tonumber(deskid) then
                    local ok,retcode,retobj = pcall(cluster.call, gamename, ".dsmgr", "apiDeskInfo", deskid)
                    resp.code = retcode
                    resp.deskinfo = cjson.decode(retobj)
                end
            end
        end
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(resp)
end

--后台接口：删除房间
function CMD.apiKickDesk(gameid, type, deskid)
    local datasource = nil
    if type == 'room' then
        datasource = table.copy(dsmgr)
    else
        datasource = table.copy(dsmgrgame)
    end
    local resp = { code = PDEFINE.RET.SUCCESS }
    local ok,retcode,retobj = pcall(cluster.call, 'game', ".dsmgr", "apiKickDesk", deskid)
    resp.code = retcode
    if retobj then
        resp.deskinfo = cjson.decode(retobj)
    end
    
    -- for gamename, item in pairs(datasource) do
    --     for _,deskinfoList in pairs(item) do
    --         for _,deskinfo in pairs(deskinfoList) do
    --             if tonumber(deskinfo.deskid) == tonumber(deskid) then
    --                 local ok,retcode,retobj = pcall(cluster.call, gamename, ".dsmgr", "apiKickDesk", deskid)
    --                 resp.code = retcode
    --                 if retobj then
    --                     resp.deskinfo = cjson.decode(retobj)
    --                 end
    --             end
    --         end
    --     end
    -- end
    return PDEFINE.RET.SUCCESS, cjson.encode(resp)
end

--后台接口，推送某个游戏的跑马灯
function CMD.apiSendDeskNotice(msgid, gameid)
    local retobj = { c = PDEFINE.NOTIFY.NOTIFY_NOTICE_GAME, code = PDEFINE.RET.SUCCESS, notices = {}}
    local msg   = do_redis({"hget", "push_notice:" .. msgid, "msg"}, nil) --消息内容
    if nil ~= msg then
        local speed = do_redis({"hget", "push_notice:" .. msgid, "speed"}, nil) --速度
        table.insert(retobj.notices, { speed = speed, msg = msg })
        --单游戏广播
        for gamename, item in pairs(dsmgr) do
            for gid,deskinfoList in pairs(item) do
                if tonumber(gid) == tonumber(gameid) then
                    for _,deskinfo in pairs(deskinfoList) do
                        local ok,retcode,retobj = pcall(cluster.call, gamename, ".dsmgr", "apiSendDeskNotice", deskinfo.deskid, cjson.encode(retobj))
                        --resp.code = retcode
                        --resp.deskinfo = cjson.decode(retobj)
                    end
                end
            end
        end

        for gamename, item in pairs(dsmgrgame) do
            for gid,deskinfoList in pairs(item) do
                if tonumber(gid) == tonumber(gameid) then
                    for _,deskinfo in pairs(deskinfoList) do
                        local ok,retcode,retobj = pcall(cluster.call, gamename, ".dsmgr", "apiSendDeskNotice", deskinfo.deskid, cjson.encode(retobj))
                        --resp.code = retcode
                        --resp.deskinfo = cjson.decode(retobj)
                    end
                end
            end
        end
    end

    return PDEFINE.RET.SUCCESS
end

skynet.info_func(function ()
    return " dsmgr:" .. cjson.encode(dsmgr)
end)

--清除掉缓存的桌子
function cleardesk( servername )
    for gameid, sesses in pairs(bet_desks) do
        for ssid, desklist in pairs(sesses) do
            local del = {}
            for i = #desklist , 1 , -1 do
                if desklist[i].server == servername then
                    table.remove(desklist,i)
                end
            end
        end
    end
    
    for gameid, sesses in pairs(alone_desks) do
        for ssid, desklist in pairs(sesses) do
            local del = {}
            for i = #desklist , 1 , -1 do
                if desklist[i].server == servername then
                    table.remove(desklist,i)
                end
            end
        end
    end

    for gameid, sesses in pairs(fight_desks) do
        for ssid, desklist in pairs(sesses) do
            local del = {}
            for i = #desklist , 1 , -1 do
                if desklist[i].server == servername then
                    table.remove(desklist,i)
                end
            end
        end
    end

    dsmgrgame[servername] = nil
end

--维护游戏服
function weihugame( gname )
    --通知匹配场
    LOG_DEBUG("weihugame call apiCloseServer")
    pcall(cluster.call, gname, ".dsmgr", "apiKickAllDesk", true)
    cleardesk( gname )
end

function ongamechange( server )
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx,
            serverinfo = {}
        }
    ]]
    if server.status == PDEFINE.SERVER_STATUS.stop then
        --清除掉缓存的桌子
        cleardesk(server.name)
    elseif server.status == PDEFINE.SERVER_STATUS.weihu then
        weihugame(server.name)
    end

    LOG_DEBUG("ongamechange server:", server)
end

function CMD.onserverchange( server )
    LOG_DEBUG("onserverchange server:",server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx，
            serverinfo = {}
        }
    ]]
    if server.tag == "game" then
        ongamechange(server)
    end
end

--系统启动完成后的通知
function CMD.start_init( ... )
    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()

    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)
end

--广播消息到游戏服  
--@param gameid
--@param cmd
function CMD.brodcastMsgByGameID(gameid, cmd, ...)
    for gameName,items in pairs(dsmgrgame) do
        for gid, desklist in pairs(items) do
            if tonumber(gid) == gameid then
                for _, desk in pairs(desklist) do
                    pcall(cluster.call, gameName, ".dsmgr", cmd, gameid, desk.deskid, ...)
                end
            end
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".mgrdesk")
end)