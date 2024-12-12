local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"

local APP = tonumber(skynet.getenv("app"))
local gamename = "game"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local SLOTS_GAME_ID = 600  --slots游戏ID（所有slots游戏公用一套策略）

--接口
local CMD = {}

-- 房间列表
local desk_list = {}
local desk_created = false

-- 策略列表
local strategy_list = {}

--创建一条策略
local function createStrategy(st)
    local stgy = {
        id = tonumber(st.id),           --策略ID
        title = st.title,               --标题
        gameid = tonumber(st.gameid),   --游戏ID
        gametitle = st.gametitle,       --游戏标题
        status = math.sfloor(st.status),--杀率状态(status为0时不控制也不统计)
        rtp = tonumber(st.killrate),    --杀率
        cycle = tonumber(st.cycle),     --周期
        alone = tonumber(st.alone),     --是否单独房间(只匹配机器人)
        svips = string.split_to_number(st.svip, ','),   --支付等级
        tagids = string.split_to_number(st.tagid, ','), --标签等级
        ord = tonumber(st.ord),         --排序
    }
    return stgy
end

--删除一条策略
local function deleteStrategy(id)
    for i, st in ipairs(strategy_list) do
        if st.id == id then
            table.remove(strategy_list, i)
            LOG_INFO("delete strategy", id)
            break
        end
    end
end

--创建一个房间
local function createDesk(stgy)
    local msg = {
        uid = 0,
        ssid = stgy.id,
    }
    local gameid = stgy.gameid
    local retok, retcode, retobj, cluster_desk = pcall(cluster.call, gamename, ".dsmgr", "createDeskInfo", nil, msg, "127.0.0.1", gameid)
    if retcode == 200 then
        local desk = {
            stgy = stgy,
            server = cluster_desk.server,
            address = cluster_desk.address,
            gameid = cluster_desk.gameid,
            desk_id = cluster_desk.desk_id,
            desk_uuid = cluster_desk.desk_uuid,
            create_time = os.time(),
            pnum = 0,
        }
        table.insert(desk_list, desk)
        LOG_INFO("create desk succ", gameid, stgy.id)
    else
        LOG_ERROR("create desk fail", gameid, stgy.id, retcode)
    end
end

--删除策略id对应的房间
local function deleteDesk(gameid, ssid)
    for i, desk in ipairs(desk_list) do
        if desk.gameid == gameid and desk.stgy.id == ssid then
            table.remove(desk_list, i)
            LOG_INFO("delete desk", gameid, ssid)
            break
        end
    end
end

--更新策略id对应的房间
local function modifyDesk(newstgy)
    for i, desk in ipairs(desk_list) do
        if desk.gameid == newstgy.gameid and desk.stgy.id == newstgy.id then
            desk.stgy = newstgy
            local ok = pcall(cluster.call, desk.server, desk.address, "reloadStrategy")
            if ok then
                LOG_INFO("game desk reload strategy succ", desk.desk_id, desk.gameid, desk.stgy.id)
            else
                LOG_ERROR("game desk reload strategy fail", desk.desk_id, desk.gameid, desk.stgy.id)
            end
            break
        end
    end
end

local function findDeskByDeskid(deskid)
    for _, desk in ipairs(desk_list) do
        if desk.desk_id == deskid then
            return desk
        end
    end
end

local function updateDeskPlayerNum(deskid, num)
    local desk = findDeskByDeskid(deskid)
    if desk then
        desk.pnum = num
    end
end


local function joinDesk(cluster_info, msg, ip)
    local deskid = tonumber(msg.deskid)
    local desk = findDeskByDeskid(deskid)
    if desk then
        local ok, retcode, retobj, cluster_desk = pcall(cluster.call, gamename, ".dsmgr", "joinDeskInfo", cluster_info,msg, ip, desk.gameid)
        if retcode == PDEFINE.RET.SUCCESS then
            return PDEFINE.RET.SUCCESS, retobj, cluster_desk
        else
            LOG_INFO("joinDesk fail", retcode)
            return retcode
        end
    else
        LOG_INFO("joinDesk fail, no deskid", deskid)
        return PDEFINE.RET.ERROR.DESKID_FAIL
    end
end

--从数据库加载
local function loadFromDb()
    local sql = "SELECT * FROM s_config_kill ORDER BY ord"
    local strategys = skynet.call(".mysqlpool", "lua", "execute", sql)
    if strategys and not table.empty(strategys) then
        for _, st in pairs(strategys) do
            local stgy = createStrategy(st)
            table.insert(strategy_list, stgy)
        end
    end
end

--@act add:新增 update:更新 del:删除
--@id 策略id
--@gameid 对应的游戏
local function reloadFromDb(act, id, gameid)
    if act == "del" then
        deleteStrategy(id)
        deleteDesk(gameid, id)
    else
        local sql = "SELECT * FROM s_config_kill WHERE id = "..id.. " LIMIT 1"
        local strategys = skynet.call(".mysqlpool", "lua", "execute", sql)
        if strategys and not table.empty(strategys) then
            local newstgy = createStrategy(strategys[1])
            --更新或新增
            local exist = false
            for i, stgy in pairs(strategy_list) do
                if stgy.id == id then
                    strategy_list[i] = newstgy
                    exist = true
                    break
                end
            end
            if not exist then
                table.insert(strategy_list, newstgy)
                local gameBase = PDEFINE.GAME_TYPE_INFO[APP][1][newstgy.gameid]
                if gameBase and gameBase.STATE == 1 and gameBase.MATCH == "BET"  then
                    createDesk(newstgy)
                end
            else
                modifyDesk(newstgy)
            end
            table.sort(strategy_list, function (a, b)
                return a.ord < b.ord
            end)
        end
    end
    return PDEFINE.RET.SUCCESS
end

local function createAllDesks()
    --先为每个游戏创建一个无策略房间
    for _, gameBase in pairs(PDEFINE.GAME_TYPE_INFO[APP][1]) do
        if gameBase.STATE == 1 and gameBase.MATCH == "BET" then
            createDesk({id=0, gameid=gameBase.ID})
            skynet.sleep(5)
        end
    end

    --为所有策略创建房间
    for _, stgy in ipairs(strategy_list) do
        local gameBase = PDEFINE.GAME_TYPE_INFO[APP][1][stgy.gameid]
        if gameBase and gameBase.STATE == 1 and gameBase.MATCH == "BET"  then
            createDesk(stgy)
            skynet.sleep(5)
        end
    end
end

--! 获取
function CMD.getStrategy(gameid, svip, tagid)
    --标签的优先级高于vip等级
    for _, stgy in ipairs(strategy_list) do
        if stgy.gameid == gameid and stgy.status == 1 and table.contain(stgy.tagids, tagid) then
            return stgy
        end
    end
    for _, stgy in ipairs(strategy_list) do
        if stgy.gameid == gameid and stgy.status == 1 and table.contain(stgy.svips, svip) then
            return stgy
        end
    end
    return nil
end

--! 获取
function CMD.getSlotsStrategy(svip, tagid)
    return CMD.getStrategy(SLOTS_GAME_ID, svip, tagid)
end

function CMD.updateStrategyData(sid, playertotalbet, playertotalwin)
    for _, stgy in ipairs(strategy_list) do
        if stgy.id == sid and stgy.status == 1 then
            stgy.totalbet = stgy.totalbet + playertotalbet
            stgy.totalprofit = stgy.totalprofit + playertotalwin
            if (playertotalbet > 0 or playertotalwin > 0) then
                local sql = "UPDATE s_config_kill SET totalbet = totalbet + "..playertotalbet..", totalprofit = totalprofit + "..playertotalwin.. " WHERE id = "..sid.." LIMIT 1"
                skynet.send(".mysqlpool", "lua", "execute", sql)
            end
            LOG_DEBUG("strategy update", sid, stgy.gameid, stgy.rtp, playertotalbet, stgy.totalbet, playertotalwin, stgy.totalprofit)
        end
    end
end


--! 获取桌子列表
function CMD.getDeskList(gameid, svip, tagid)
    local desks = {}
    --标签的优先级高于vip等级
    for _, desk in ipairs(desk_list) do
        local stgy = desk.stgy
        if stgy.id > 0 and stgy.gameid == gameid then
            if table.contain(stgy.tagids, tagid) then
                table.insert(desks, {
                    deskid = desk.desk_id,
                    pnum = desk.pnum,
                    basecoin = 100,
                })
            end
        end
    end
    if #desks == 0 then
        for _, desk in ipairs(desk_list) do
            local stgy = desk.stgy
            if stgy.id > 0 and stgy.gameid == gameid then
                if table.contain(stgy.svips, svip) then
                    table.insert(desks, {
                        deskid = desk.desk_id,
                        pnum = desk.pnum,
                        basecoin = 100,
                    })
                end
            end
        end
    end
    if #desks == 0 or (svip==0 and tagid==0) then
        for _, desk in ipairs(desk_list) do
            local stgy = desk.stgy
            if stgy.id == 0 and desk.gameid == gameid then
                table.insert(desks, {
                    deskid = desk.desk_id,
                    pnum = desk.pnum,
                    basecoin = 100,
                })
            end
        end
    end
    return desks
end

--! 加入桌子
function CMD.joinDesk(cluster_info, msg, ip)
    return joinDesk(cluster_info, msg, ip)
end

--! 更新策略
function CMD.reloadStrategy(act, id, gameid)
    LOG_INFO("reload strategy", act, id, gameid)
    return reloadFromDb(act, tonumber(id), tonumber(gameid))
end

--! 更新桌子人数
function CMD.updateDeskPlayerNum(deskid, num)
    updateDeskPlayerNum(deskid, num)
end

--! 移除桌子
function CMD.onDeskDestroy(deskid, gameid)
    for i, desk in ipairs(desk_list) do
        if desk.desk_id == deskid and desk.gameid == gameid then
            table.remove(desk_list, i)
            break
        end
    end
end

--!重新加载游戏配置 
function CMD.reloadGameSetting(gameid)
    for i, desk in ipairs(desk_list) do
        if desk.gameid == gameid then
            pcall(cluster.send, desk.server, desk.address, "reloadSetting")
            LOG_INFO("game desk reload setting", desk.desk_id, gameid, desk.stgy.id)
        end
    end
end

--! 游戏服就绪
function CMD.onDsmgrInit(gameName)
    if desk_created then return end  --防止重入
    LOG_INFO("onDsmgrInit createAllDesks", gameName)
    desk_created = true

    gamename = gameName
    createAllDesks()
end

local function heartbeat(dt)
end

local function threadfunc(interval)
    local dt = interval/100.0
    while true do
        xpcall(heartbeat,
            function(errmsg)
                print(debug.traceback(tostring(errmsg)))
            end,
            dt)
        skynet.sleep(interval)
    end
end

function CMD.start()
    loadFromDb()
    skynet.fork(threadfunc, 100)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".strategymgr")
    collectgarbage("collect")
end)


