
local time_tool = {}

function time_tool.dayPoint(now, hour)
    local now_date = os.date("*t", now)
    local t = os.time({year=now_date.year, month=now_date.month, day=now_date.day, hour=hour or 0}) --当天N点之后，默认周期起点是当天N点
    if now < t then
        t = t - 86400  --当天N点之前，默认周期起点是昨天的N点
    end
    return t
end

function time_tool.weekPoint(now, wday, hour)
    local now_date = os.date("*t", now)
    local day = now_date.wday - (wday or 2)
    if day < 0 then
        day = day + 7
    end
    local t = os.time({year=now_date.year, month=now_date.month, day=now_date.day, hour=hour or 0}) --当天N点之后，默认周期起点是当天N点
    if now < t then
        t = t - 86400  --当天N点之前，默认周期起点是昨天的N点
    end
    return t - day * 3600 * 24
end

local t = 1613805501
local v = nil
v = time_tool.dayPoint(t)
print("dayPoint", v == 1613750400, v)
v = time_tool.dayPoint(t, 8)
print("dayPoint", v == 1613779200, v)
v = time_tool.weekPoint(t)
print("weekPoint", v == 1613318400, v)
v = time_tool.weekPoint(t, 1, 8)
print("weekPoint", v == 1613260800, v)

return time_tool