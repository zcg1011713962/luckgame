--[[
    玩家基类
]]

local skynet    = require "skynet"
local cluster   = require "cluster"
local player_tool = require "base.player_tool"
local sysmarquee = require "sysmarquee"
local DEBUG = skynet.getenv("DEBUG")

---@type BaseUser
local User = {}
User.__index = User

setmetatable(User, {
    __call = function (cls, ...)
        return cls.new(...)
    end
})

-- 创建新的玩家对象
function User.new(playerInfo, deskInfo)
    ---@class BaseUser
    local user = setmetatable({}, User)
    user.uid=playerInfo.uid
    user.playername=playerInfo.playername
    user.usericon=playerInfo.usericon
    user.coin=playerInfo.coin or 0
    user.level = playerInfo.level or 1
    user.diamond = playerInfo.diamond or 0 --携带钻石
    user.avatarframe = playerInfo.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img
    user.levelexp = playerInfo.levelexp or 0
    user.leaguelevel = 1
    user.leagueexp = 0
    user.is_league = 0
    user.chatskin = playerInfo.chatskin or PDEFINE.SKIN.DEFAULT.CHAT.img
    user.frontskin = playerInfo.frontskin or nil
    user.svip = playerInfo.svip or 0
    if playerInfo.ssid then
        user.ssid = playerInfo.ssid
    end
    user.isnew = 0
    user.rp = playerInfo.rp or 0
    user.istest = playerInfo.istest
    if isTodayReg(playerInfo.create_time) then
        user.isnew = 1
    end

    user.create_time = playerInfo.create_time --用户创建时间

    user.mic               = 0 -- 麦克风是否打开  1是 0否
    user.offline           = 0 -- 是否掉线 1是 0否
    user.auto              = 0 -- 是否自动状态
    user.autoCnt           = 0 -- 自动托管次数
    user.autoStartTime     = nil -- 托管开始时间
    user.autoTotalTime     = 0 -- 当局游戏处于托管的时间
    user.isexit            = 0 -- 是否已退出
    user.leavetime = (os.time() + math.random(PDEFINE.ROBOT.REMAINTIME[1], PDEFINE.ROBOT.REMAINTIME[2])) --离开时刻,机器人有效

    user.race_id           = 0  -- 是否是赛事局
    user.race_type         = 0  -- 计分类型
    user.coin              = playerInfo.coin  -- 携带金币数
    user.realCoin          = 0  -- 用于比赛方存放真是金币
    user.diamond           = playerInfo.diamond --携带钻石数
    user.score             = 0 -- 累计总分数
    user.winTimes          = 0 -- 赢牌次数
    user.resetTimes        = 0 --重摇骰子的次数
    user.round             = nil  -- 用户此轮信息
    user.state             = nil --状态
    user.seatid            = nil --座位号
    user.cluster_info      = nil --连接信息

    user.timer             = {  -- 用户身上的定时器
        cancel = nil,  -- 取消函数
        expireTime = nil,  -- 过期时间
        leftTime = nil,  -- 剩余时间
        runFunc  = nil,  -- 定时器执行函数
        runParams = nil,  -- 定时器执行参数
    }
    user.settlewin    = 0 --输赢次数
	user.wincoin      = 0 --输赢金币(真实)
	user.wincoinshow  = 0 --输赢金币(显示用
    return user
end

-- 打印消息
function User:print(...)
    LOG_DEBUG(self.uid , ' => ', ...)
end

-- 初始化用户身上的特殊字段
function User:init(seatid, deskInfo, cluster_info, ssid)
    -- 特殊判断下排位等级
    if self.leaguelevel <= 0 then
        self.leaguelevel = 1
    end
    -- 处理排位等级
    -- local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getCurAndNextLvInfo", self.leaguelevel)
    -- if ok then
        -- self.leagueexp = leagueArr[1].score + self.leagueexp
        -- self.leagueexp = 1
    -- end
    -- 设置用户连接信息
    if cluster_info then
        self.cluster_info = cluster_info
    end
    -- 设置座位号
    self.seatid = seatid
    if ssid then
        self.ssid = ssid
    end

    return nil
end

-- 更改用户金币
function User:changeCoin(type, coin, deskInfo)
    self:print("changeCoin type:", type, ' coin:', coin)
    self.coin = self.coin + coin
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        return
    end
    if self.cluster_info then
        player_tool.calUserCoin(self.uid, coin, deskInfo.issue, type, deskInfo)
    end
end

-- 播放走马灯
function User:notifyLobby(coin, uid, gameid)
    sysmarquee.onGameWin(self.playername, gameid, coin)
end

-- 设置定时器
function User:setTimer(delayTime, f, params, force)
    local function t()
        if f then
            f(params)
        end
    end
    skynet.timeout(math.floor(delayTime*100), t)
    -- 存储取消函数
    self.timer.cancel = function(params) f=nil end
    -- 存储过期时间，方便取消和恢复
    self.timer.expireTime = delayTime + os.time()
    -- 存储计算函数
    self.timer.runFunc = f
    -- 存储计算参数
    self.timer.runParams = params
    -- 是否强制执行
    self.timer.force = force
end

-- 清理定时器
function User:clearTimer()
    if self.timer.force then
        return
    end
    if self.timer.cancel then
        self.timer.cancel()
    end
    self.timer = {  -- 用户身上的定时器
        cancel = nil,  -- 取消函数
        expireTime = nil,  -- 过期时间
        leftTime = nil,  -- 剩余时间
        runFunc  = nil,  -- 定时器执行函数
        runParams = nil,  -- 定时器执行参数
    }
end

-- 暂停定时器
function User:pauseTimer()
    if self.timer.cancel then
        self.timer.cancel()
        self.timer.cancel = nil
    end
    if self.timer.expireTime and self.timer.expireTime >= os.time() then
        -- 增加1秒的倒计时，用于传输耗时
        self.timer.leftTime = self.timer.expireTime - os.time() + 1
    else
        self.timer.leftTime = nil
    end
end

-- 恢复定时器
function User:recoverTimer()
    if self.timer.leftTime then
        self:setTimer(self.timer.leftTime, self.timer.runFunc, self.timer.runParams)
        self.timer.leftTime = nil
    end
end

function User:sendMsg(retobj)
    if self.cluster_info and self.isexit == 0 then
        pcall(cluster.send, self.cluster_info.server, self.cluster_info.address, "sendToClient", retobj)
    end
end

function User:toReponse()
    -- 去掉连接信息
    self.cluster_info = nil
    -- 去掉定时器信息
    self.timer = nil
    -- cjson不支持function
    for key, v in pairs(self) do
        if type(v) == 'function' then
            self[key] = nil
        end
    end
    -- 清除元表
    self = setmetatable(self, {})
end

return User