-- 俱乐部管理
local skynet = require "skynet"
require "skynet.manager"
local clubDb = require "base.club_db"

local start_redis_key = PDEFINE.REDISKEY.CLUB.SEASON.START
local stop_redis_key = PDEFINE.REDISKEY.CLUB.SEASON.STOP

local CMD = {}

-- 俱乐部排行榜时间期
local SeasonCfg = {
    [1] = {
        id = 1,
        begin=os.time({day=1, month=12, year=2021, hour=0, minute=0, second=0}),
        stop=os.time({day=1, month=3, year=2022, hour=0, minute=0, second=0})
    },
    [2] = {
        id = 2,
        begin=os.time({day=1, month=3, year=2022, hour=0, minute=0, second=0}),
        stop=os.time({day=1, month=6, year=2022, hour=0, minute=0, second=0})
    }
}

local function syncSeason()
    local cnt = 0
    while true do
        cnt = cnt + 1
        local stop_time = do_redis({"get", stop_redis_key})
        local now = os.time()
        local currSeason = nil
        for _, cfg in ipairs(SeasonCfg) do
            -- 先找到赛季
            if cfg.begin < now and now < cfg.stop then
                -- 如果开始时间不是处于这个赛季，则要对赛季进行清理，并且重新设置开始时间
                currSeason = cfg
            end
        end
        if not stop_time then
            do_redis({"set", start_redis_key, currSeason.begin})
            do_redis({"set", stop_redis_key, currSeason.stop})
        else
            stop_time = tonumber(stop_time)
            if stop_time <= now then
                local result = clubDb.refreshScore()
                if result then
                    do_redis({"set", start_redis_key, currSeason.begin})
                    do_redis({"set", stop_redis_key, currSeason.stop})
                end
            end
        end
        if cnt == 1000 then
            LOG_DEBUG("俱乐部赛季, 1000次10秒检测打印一次日志...", os.time())
            cnt = 0
        end
        skynet.sleep(1000) --每10秒查询一下
    end
end

function CMD.start()

end

function CMD.stop()
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)
    skynet.fork(syncSeason)
    skynet.register(".clubmgr")
end)
