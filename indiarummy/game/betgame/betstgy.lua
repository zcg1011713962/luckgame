--百人游戏策略控制
local skynet    = require "skynet"

local util = {}
function util.mysql_exec(sql)
    return skynet.call(".mysqlpool", "lua", "execute", sql)
end
function util.mysql_exec_async(sql)
    return skynet.send(".mysqlpool", "lua", "execute", sql)
end
function util.redis_exec(args, uid)
    local cmd = assert(args[1])
    args[1] = uid
    return skynet.call(".redispool", "lua", cmd, table.unpack(args))
end

--开启控制的最下总下注
local CONST_MIN_TOTALBET = 1000
--RTP随机范围 +-0.02
local CONST_RTP_RANDOM_RANGE = 0.02
--是否开启控赢
local CONST_OPEN_STRATEGY_WIN = false
--控赢开启的最小总下注
local CONST_WIN_STRATEGY_MIN_TOTALBET = 20000

---@class BetStgy
local BetStgy = class()

function BetStgy:ctor()
    self.ssid = 0
    self.gameid = 0
    self.status = 1
    self.rtp = 0
    self.cycle = 0
    self.stopcoin = 0
    self.totalbet = 0
    self.totalprofit = 0
end

function BetStgy:isValid()
    return self.ssid > 0
end

--从数据库加载
function BetStgy:load(ssid, gameid)
    self.ssid = ssid
    self.gameid = gameid
    if ssid <= 0 then
        return
    end
    local sql = "SELECT * FROM s_config_kill WHERE id = "..(ssid).. " LIMIT 1"
    local strategys = util.mysql_exec(sql)
    if strategys and not table.empty(strategys) then
        local st = strategys[1]
        local rtp = tonumber(st.killrate)
        self.rtp = math.min(150, math.max(50, rtp))  --杀率
        self.status = math.sfloor(st.status)    --状态
        self.cycle = tonumber(st.cycle)     --周期
        self.stopcoin = tonumber(st.stopcoin) or 0   --止盈金额
        self.totalbet = tonumber(st.totalbet) or 0  --总押注额(玩家)
        self.totalprofit = tonumber(st.totalprofit) or 0 --总赢分(玩家)
    else
        self.status = 0
    end
    LOG_DEBUG("load bet strategy", ssid, gameid, self.rtp, self.cycle, self.totalbet, self.totalprofit)
end

--重载
function BetStgy:reload()
    LOG_DEBUG("reload bet strategy before", self.ssid, self.gameid, self.rtp, self.cycle, self.totalbet, self.totalprofit)
    self:load(self.ssid, self.gameid)
end

--更新输赢金币
function BetStgy:update(totalbet, totalwin)
    if self.status ~= 1 then
        return
    end
    self.totalbet = self.totalbet + totalbet
    self.totalprofit = self.totalprofit + totalwin
    if self.ssid > 0 and (totalbet > 0 or totalwin > 0) then
        local sql = "UPDATE s_config_kill SET totalbet = totalbet + "..totalbet..", totalprofit = totalprofit + "..totalwin.. " WHERE id = "..self.ssid.." LIMIT 1"
        util.mysql_exec_async(sql)
    end
    LOG_DEBUG("strategy update", self.ssid, self.gameid, self.rtp, totalbet, self.totalbet, totalwin, self.totalprofit)
end

--获取控制条件
--return -1:控输 0:随机 1:控赢
function BetStgy:getRestriction()
    if self.ssid <= 0 or self.status ~= 1 or self.cycle == 0 then
        return 0
    end
    local rand = math.random()
    if rand * self.cycle > 1 then  --周期判断
        return 0
    end
    --回报率判断
    if self.totalbet < CONST_MIN_TOTALBET then  --累积下注额不足
        return 0
    end
    --预期回报率
    local exprtp = self.rtp/100 + (math.random()*CONST_RTP_RANDOM_RANGE*2 - CONST_RTP_RANDOM_RANGE)  --设置rtp+-0.02
    --实际回报率
    local realrtp = self.totalprofit / self.totalbet
    if realrtp > exprtp then  --如果实际rtp>预期rtp，则控输
        return -1
    elseif CONST_OPEN_STRATEGY_WIN and self.totalbet > CONST_WIN_STRATEGY_MIN_TOTALBET and realrtp < exprtp * 0.85 then  --如果实际rtp低于预期rtp的85%，则控赢
        return 1
    end
    return 0
end


return BetStgy