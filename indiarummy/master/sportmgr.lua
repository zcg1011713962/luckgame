local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"
local sportconst = require "sport.sportconst"
local sportutil = require "sport.sportutil"
require "sport.sportdaily"
require "sport.sportfinal"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

--接口
local CMD = {}

--比赛列表
local sport_dict = {}

--代理
local delegate = {}

local function newSportId()
    return sportutil.redis_exec({"incr", sportconst.SPORT_ID_REDIS_KEY})
end

--添加日常赛冠军
local function addDailyChampion(userid)
    sportutil.redis_exec({"sadd", sportconst.DAILY_SPORT_CHAMPIONS_REDIS_KEY, userid})
end
delegate.addDailyChampion = addDailyChampion

--是否日常赛冠军
local function isDailyChampion(userid)
    local res = sportutil.redis_exec({"sismember", sportconst.DAILY_SPORT_CHAMPIONS_REDIS_KEY, userid})
    return (res and (res > 0))
end
delegate.isDailyChampion = isDailyChampion

--清除日常赛冠军
local function clearDailyChampion()
    sportutil.redis_exec({"del", sportconst.DAILY_SPORT_CHAMPIONS_REDIS_KEY})
end
delegate.clearDailyChampion = clearDailyChampion

--从数据库加载未完比赛
local function loadFromDb()
    local sql = "SELECT id, status, `mode`, cur_round, tid, room_param, start_time FROM d_sport WHERE status > 0"
    local sports = sportutil.mysql_exec(sql)
    if sports then
        for _, spt in pairs(sports) do
            local id = tonumber(spt.id)
            local tid = tonumber(spt.tid)
            local mode = tonumber(spt.mode)
            local status = tonumber(spt.status)
            local cur_round = tonumber(spt.cur_round)
            local start_time = tonumber(spt.start_time)
            local room_param = cjson.decode(spt.room_param)
            local sport
            if mode == 1 then
                sport = SportDaily.new(delegate, id, tid, mode, room_param, start_time, status, cur_round)
            else
                sport = SportFinal.new(delegate, id, tid, mode, room_param, start_time, status, cur_round)
            end
            sport:loadFromDb()
            sport_dict[id] = sport
        end
    end
end


local function tryCreateDialySport()
    for _, sport in pairs(sport_dict) do
        if sport.mode == 1 then
            return
        end
    end
    local tm = sportutil.currenttimestruct()
    if tm.min > 5 then -- 当前分钟超过5则放到下一小时
        tm.hour = tm.hour + 1
    end
    if sportconst.DAILY_SPORT_BEGIN_HOUR <= sportconst.DAILY_SPORT_END_HOUR then
        -- 只在当天
        if tm.hour < sportconst.DAILY_SPORT_BEGIN_HOUR then
            tm.hour = sportconst.DAILY_SPORT_BEGIN_HOUR
        elseif tm.hour > sportconst.DAILY_SPORT_END_HOUR then
            --放到第二天
            tm = os.date("*t", os.time()+20*60*60)
            tm.hour = sportconst.DAILY_SPORT_BEGIN_HOUR
        end
    else
        -- 当天持续到第二天
        if tm.hour >= sportconst.DAILY_SPORT_END_HOUR
          and tm.hour < sportconst.DAILY_SPORT_BEGIN_HOUR then
            tm.hour = sportconst.DAILY_SPORT_BEGIN_HOUR
        end
    end

    tm.min = 0 -- 整点开始
    local start_time = sportutil.timestamp(tm)
    local sport_id = newSportId()
    local tid = 1
    local mode = sportconst.SPORT_MODE_DAILY
    local room_param = table.copy(sportconst.DAILY_SPORT_ROOM_PARAM)
    room_param.sport_id = sport_id
    local sql = string.format("INSERT INTO d_sport(id, tid, `mode`, room_param, start_time, create_time) VALUES ('%d', '%d', '%d', '%s', '%d', '%d')",
        sport_id, tid, mode, cjson.encode(room_param), start_time, os.time())
    sportutil.mysql_exec(sql)

    local sport = SportDaily.new(delegate, sport_id, tid, mode, room_param, start_time, 1, 1)
    sport_dict[sport_id] = sport

    LOG_INFO("create daily sport:", sport_id, start_time)
end

local function tryCreateFinalSport()
    for _, sport in pairs(sport_dict) do
        if sport.mode == 2 then
            return
        end
    end
    local tm = sportutil.currenttimestruct()
    if (tm.wday > sportconst.FINAL_SPORT_BEGIN_WDAY)
        or (tm.wday == sportconst.FINAL_SPORT_BEGIN_WDAY and tm.hour > sportconst.FINAL_SPORT_BEGIN_HOUR - 1) then
        -- 比赛放到下周五
        tm = os.date("*t", os.time()+(7+sportconst.FINAL_SPORT_BEGIN_WDAY-tm.wday)*24*60*60)
        tm.hour = sportconst.FINAL_SPORT_BEGIN_HOUR
    else
        -- 比赛在这周五
        tm = os.date("*t", os.time()+(sportconst.FINAL_SPORT_BEGIN_WDAY-tm.wday)*24*60*60)
        tm.hour = sportconst.FINAL_SPORT_BEGIN_HOUR
    end
    tm.min = 0  -- 整点开始
    local start_time = sportutil.timestamp(tm)
    local sport_id = newSportId()
    local tid = 2
    local mode = sportconst.SPORT_MODE_FINAL
    local room_param = table.copy(sportconst.FINAL_SPORT_ROOM_PARAM)
    room_param.sport_id = sport_id
    local sql = string.format("INSERT INTO d_sport(id, tid, `mode`, room_param, start_time, create_time) VALUES ('%d', '%d', '%d', '%s', '%d', '%d')",
        sport_id, tid, mode, cjson.encode(room_param), start_time, os.time())
    sportutil.mysql_exec(sql)

    local sport = SportFinal.new(delegate, sport_id, tid, mode, room_param, start_time, 1, 0)
    sport_dict[sport_id] = sport

    LOG_INFO("create final sport:", sport_id, start_time)
end

local function getSportByMode(mode)
    for _, sport in pairs(sport_dict) do
        if sport.mode == mode then
            return sport
        end
    end
    return nil
end

local function heartbeat(dt)
    for id, sport in pairs(sport_dict) do
        sport:heartbeat(dt)
        --删除已结束比赛
        if sport:isFinished() then
            sport_dict[id] = nil
        end
    end

    --创建新比赛
    tryCreateDialySport()
    tryCreateFinalSport()
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

function CMD.list(rcvobj)
    local list = {}
    local now = os.time()
    for _, sport in pairs(sport_dict) do
        local left_time = sport.end_ostime-now
        if sport.status == sportconst.SPORT_STATUS_INIT then
            left_time = sport.start_ostime - now
        end
        local t = sportutil.timestamp(sport.start_tm)
        local need_coin = 0
        if sport.mode == sportconst.SPORT_MODE_DAILY then
            need_coin = sportconst.DAILY_SPORT_COIN_THRESHOLD
        else
            need_coin = sportconst.FINAL_SPORT_COIN_THRESHOLD
        end
        table.insert(list, {
            id = sport.id,
            mode = sport.mode,
            status = sport.status,
            start_time = tostring(math.floor(t/100)),
            left_time = left_time,
            cur_round = sport.cur_round,
            need_coin = need_coin,
            left_count = sport:getLeftGameCount(rcvobj.uid),
        })
    end
    local retobj = {list = list}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function CMD.join(rcvobj)
    LOG_DEBUG("[Sport] join",cjson.encode(rcvobj))
    local retobj = {}
    local uid = rcvobj.uid
    local sport = getSportByMode(rcvobj.mode)
    if not sport then
        retobj.res = 1
    end
    retobj.res = sport:join(uid, rcvobj.nick, rcvobj.icon, rcvobj.coin)
    retobj.id = sport.id
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function CMD.ranking(rcvobj)
    local ranking = {}
    local sport = sport_dict[rcvobj.sportid]
    if sport then
        ranking = sport:getRanklist();
    end
    local retobj = {ranking = ranking}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function CMD.cancel(rcvobj)
    local uid = rcvobj.uid
    local sport = getSportByMode(rcvobj.mode)
    if sport then
        sport:cancel(uid)
    end
    local retobj = {res = 0}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function CMD.settle(sport_id, desk_id, players_score)
    LOG_DEBUG("[Sport] settle", sport_id, desk_id, cjson.encode(players_score))
    local sport = sport_dict[sport_id]
    if sport then
        sport:settle(desk_id, players_score)
    end
end

function CMD.syncDeskSeat(sport_id, desk_id, seat)
    local sport = sport_dict[sport_id]
    if sport then
        sport:syncDeskSeat(desk_id, seat)
    end
end

function CMD.dismissDesk(sport_id, desk_id)
    LOG_DEBUG("[Sport] dismissDesk", sport_id, desk_id)
    local sport = sport_dict[sport_id]
    if sport then
        sport:dismissDesk(desk_id)
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
    skynet.register(".sportmgr")
    collectgarbage("collect")
end)


