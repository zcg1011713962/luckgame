local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local is_report = skynet.getenv("isreport")

--调用api模块
local function Report(modname, data)
    if not is_report then
        return
    end
end

--上报桌子T人信息
-- user={uid=xxx,coin=xxx}
local function reportGameKick(user, deskinfo)
end

-- 上报游戏结果
-- user={uid=xxx,betcoin=xxx,betline=xxx,altercoin=xxx,bet=xxx,result=xx}
-- altercoin是输赢 输用负数 betcoin是真实下注信息 bet 是下注方位信息 result=开奖结果
local function reportGameResult(user, deskinfo)
end

return {
    Report = Report,
    reportGameKick = reportGameKick,
    reportGameResult = reportGameResult
}
