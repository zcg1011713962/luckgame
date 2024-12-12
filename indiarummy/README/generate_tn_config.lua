
local interval_time = 5  -- 分钟
local ahead_time = 300  -- 300秒
local deadline_time = 180  -- 180秒

local hour = 0   -- 小时
local minute = 0  -- 分钟

local function addMinute()
    minute = minute + interval_time
    if minute == 60 then
        minute = 0
        hour = hour + 1
        if hour == 24 then
            return false
        end
    end
    return true
end

local id = 1
while true do
    local start_time = hour * 100 + minute
    if not addMinute() then
        break
    end
    local stop_time = hour * 100 + minute

    local sql = string.format([[
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(%d,293,10,3,30, "30,20,10,10,10,5,5,5,5",%d,%d,%d,%d, 2,100,70, %d, %d);
    ]], id, start_time, stop_time, ahead_time, deadline_time, os.time(), os.time())
    print(sql)
    if not addMinute() then
        break
    end
    id = id + 1
end