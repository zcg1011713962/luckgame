local skynet    = require "skynet"
local cluster   = require "cluster"

-- 捕鱼机器人

AI_TICK = 40

FishAi = class()

function FishAi:ctor()
    self.deskInfo = nil
    self.userInfo = nil
    self.fire_func = nil
    self.seat = 0
    self.behavior = 0  --0:休息，1:打鱼
    self.cannon = 1   --炮台类型
    self.multiple = 10 --押注倍率
    self.angle = 0    --角度
    self.bulletid = 0 --子弹ID

    self.behavierTime = 2  --下次改变行为时间
    self.adaptTime = 10 --适配时间
    self.randAngleTime = 3 --切换角度时间
    self.fireTime = 0
    self.fireInterval = 0
    self.pauseTime = 0  --暂停时间
end

function FishAi:init(deskInfo, userInfo, aiInfo, fire_func)
    self.deskInfo = deskInfo
    self.userInfo = userInfo
    self.aiInfo = aiInfo
    self.seat = userInfo.seat
    self.deskseat = deskInfo.seat
    self.fire_func = fire_func
    self.behavior = 0
    self.bulletid = 0
    self.behavierTime = math.random(2, 4)
    self:adapt()
    self:randAngle()
end

function FishAi:pause(time)
    self.pauseTime = time
end

function FishAi:adapt()
    local mults = self.aiInfo.mults
    self.multiple = mults[math.random(1, #mults)]
    local cannons = self.aiInfo.cannons
    local idx = math.random(1, #cannons)
    self.cannon = cannons[idx]
    if self.aiInfo.fireInterval then
        self.fireInterval = self.aiInfo.fireInterval[idx]
    else
        self.fireInterval = 0
    end
    self.adaptTime = math.random(15, 25)
end

function FishAi:randAngle()
    self.angle = (math.random()-0.5)*2.5
    if self.seat > self.deskseat/2 then
        self.angle = self.angle + 3.1415926
    end

    self.randAngleTime = math.random(3, 6)
end

function FishAi:fire()
    --assert(self.fire_func)
    if not self.fire_func then return end
    --随机找一个真实玩家
    local realuids = {}
    for _, user in pairs(self.deskInfo.users) do
        if user.cluster_info and user.offline == 0 then
            table.insert(realuids, user.uid)
        end
    end
    if #realuids == 0 then return end

    if self.bulletid > 1000 then
        self.bulletid = 0
    end
    self.bulletid = self.bulletid + 1
    local bulletid = self.bulletid * 10 + self.seat
    local recvobj = {c=2402, uid=self.userInfo.uid, bt=self.cannon, bid=bulletid, ang=self.angle, mul=self.multiple, fid=0}
    self.fire_func(recvobj, self.userInfo.uid)
end


function FishAi:update(dt)
    --assert(self.userInfo)
    if not self.userInfo then
        return false
    end

    if self.pauseTime > 0 then
        self.pauseTime = self.pauseTime - dt
        return true
    end

    self.behavierTime = self.behavierTime - dt
    if self.behavierTime < 0 then
        self.behavior = 1 - self.behavior
        if self.behavior == 0 then
            self.behavierTime = math.random(2, 8)
        else
            self.behavierTime = math.random(6, 20)
        end
    end
    if self.behavior == 1 then  -- 连续射击
        if self.fireInterval > 0 then
            self.fireTime = self.fireTime - dt
            if self.fireTime <= 0 then
                self:fire()
                self.fireTime = self.fireTime + self.fireInterval
            end
        else
            self:fire()
        end

        -- 调整角度
        self.randAngleTime = self.randAngleTime - dt
        if self.randAngleTime <= 0 then
            self:randAngle()
        end

        -- 切换炮台和倍率
        self.adaptTime = self.adaptTime - dt
        if self.adaptTime <= 0 then
            self:adapt()
        end
    else
        if math.random(1, 15) == 1 then
            self:fire()
        end
    end
    return true
end

