
local skynet = require "skynet"
local cjson = require "cjson"
local cluster = require "cluster"
local DEV_DEBUG = skynet.getenv("DEV_DEBUG")

local function create()
    local data = {
        ssid = 0,       --策略ID
        tagid = 0,      --玩家vip等级
        svip = 0,       --玩家标签
        tag = 0,
        tspin = 0,      --总spin次数
        twin = 0,       --总赢分
        tbet = 0,       --总下注
        lspin = 0,      --近期spin次数
        lwin = 0,       --近期赢分
        lbet = 0,       --近期下注
        lwins = {},     --近期赢分列表
        lbets = {},     --近期下注列表
        cspin = 0,      --当前阶段spin次数
        cwin = 0,       --当前阶段赢分
        cbet = 0,       --当前阶段下注
        ctspin = 0,     --当前阶段需要下注的次数
        crtp = 0.98,    --当前阶段rtp
        ctime = 0,      --当前阶段开始时间
        prtp = 0.99,    --上一阶段rtp
        lrtpcnt = 0,    --连续低rtp次数
        hrtpcnt = 0,    --连续高rtp次数
        dspin = 0,      --当天spin次数
        ltime = 0,      --最近一次spin的时间
        bigwin = 0,     --大奖次数
    }
    return data
end

local function load(uid)
    local sdata = create()
    if not TEST_RTP then
        local datastr = skynet.call(".gamedatamgr", "lua", "get", uid, "stgydata")
        if datastr then
            local data = cjson.decode(datastr)
            table.merge(sdata, data)
        end
    end
    return sdata
end

local function save(uid, data)
    if not TEST_RTP then
        local datastr = cjson.encode(data)
        skynet.call(".gamedatamgr", "lua", "set", uid, "stgydata", datastr, true)
    end
end

local function onSpin(data, basegame)
    data.tspin = data.tspin + 1
    data.lspin = data.lspin + 1
    data.cspin = data.cspin + 1
    data.dspin = data.dspin + 1

    if data.lspin >= 200 then
        table.insert(data.lwins, data.lwin)
        table.insert(data.lbets, data.lbet)
        if #(data.lwins) > 5 then   --只保留最近500局数据
            table.remove(data.lwins, 1)
        end
        if #(data.lbets) > 5 then
            table.remove(data.lbets, 1)
        end
        data.lspin = 0
        data.lwin = 0
        data.lbet = 0
    end

    local t = os.time()
    if data.ltime > 0 then
        local d1 = os.date("*t", data.ltime)
        local d2 = os.date("*t", t)
        if d1.day ~= d2.day then
            data.dspin = 0
        end
    end
    data.ltime = t
end

local function onWin(data, win)
    data.twin = data.twin + win
    data.lwin = data.lwin + win
    data.cwin = data.cwin + win
end

local function onBet(data, bet)
    data.tbet = data.tbet + bet
    data.lbet = data.lbet + bet
    data.cbet = data.cbet + bet
end

local function onBigwin(data, bet)
    data.bigwin = data.bigwin + 1
end

local function format(data)
    if DEV_DEBUG then
        local l = {}
        for k, v in pairs(data) do
            if type(v)=="table" then
                table.insert(l, k..":"..table.concat(v, ","))
            else
                table.insert(l, k..":"..tostring(v))
            end
        end
        return table.concat(l, " ")
    end
end

return {
    load = load,
    save = save,
    format = format,
    onSpin = onSpin,
    onWin = onWin,
    onBet = onBet,
    onBigwin = onBigwin,
}





