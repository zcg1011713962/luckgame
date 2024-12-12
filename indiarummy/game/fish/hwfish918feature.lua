local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson   = require "cjson"
require "fish.fishfeature"

--海王捕鱼特有玩法: 烈焰风暴

Hwfish918Feature = class(FishFeature)

function Hwfish918Feature:init(fishconfig)
    self.revenue = 0             --系统收分(烈焰风暴额外奖励从收分中出)
    self.lyfb_config = fishconfig.lyfb  --烈焰风暴配置
end

function Hwfish918Feature:endLyfb(deskInfo, userInfo)
    if not userInfo.freeTime then return end  -- 防止重入

    local score = userInfo.freeScore
    --计算额外番数
    local extMul = math.random(110, 150) / 100
    if math.random(1, 100) <= 20 then
        extMul = math.random(150, 250) / 100
    end
    local extScore = (extMul - 1) * score
    extScore = math.floor(extScore * 100) / 100
    if self.delegate._deductStock(extScore) > 0 then    -- 扣库存
        userInfo.coin = userInfo.coin + extScore
        userInfo.winCoin = userInfo.winCoin + extScore
        self.revenue = self.revenue - extScore
    else
        extMul = 1
        extScore = 0
    end

    userInfo.freeTime = nil
    userInfo.freeCnt = nil
    userInfo.freeMul = nil
    userInfo.freeScore = nil
    --发送消息
    local retobj  = {}
    retobj.c      = PDEFINE.NOTIFY.NOTIFY_FISH_EVENT
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.seat   = userInfo.seat
    retobj.evt    = "lyfb_end"
    retobj.score  = score
    retobj.extmul = extMul
    retobj.totalscore = score + extScore
    retobj.coin   = userInfo.coin
    self:broadcast(deskInfo, cjson.encode(retobj))

    LOG_INFO("lyfb end:", userInfo.uid, score, extMul, extScore, self.revenue)
end

function Hwfish918Feature:onUpdate(deskInfo)
    for _, userInfo in pairs(deskInfo.users) do
        if userInfo.freeTime then
            local tick = skynet.now()
            if tick > userInfo.freeTime then
                self:endLyfb(deskInfo, userInfo)
            end
        end
    end
end

function Hwfish918Feature:onUserFire(deskInfo, userInfo, bulletInfo)
    if userInfo.freeTime then    --免费游戏
        userInfo.freeCnt = userInfo.freeCnt - 1
        if userInfo.freeCnt <= 0 or userInfo.tick > userInfo.freeTime then  -- 免费次数结束
            self:endLyfb(deskInfo, userInfo)
        end
    else
        if userInfo.real then  --真实玩家
            self.revenue = self.revenue + bulletInfo.mul
        end
    end
end

function Hwfish918Feature:onUserTryCatch(deskInfo, userInfo, fishInfo, bulletInfo, rate)
    if userInfo.freeTime then
        if fishInfo.ft >= 25 and fishInfo.ft <= 29 then  --免费期间不触发技能鱼
            return 0 
        end
    end
    return -1
end

function Hwfish918Feature:onUserCatched(deskInfo, userInfo, fishInfo, bulletInfo)
    if userInfo.real then
        -- 真实玩家
        if userInfo.freeTime then
            userInfo.freeScore = userInfo.freeScore + fishInfo.multiple * bulletInfo.mul
        else
            self.revenue = self.revenue - fishInfo.multiple * bulletInfo.mul

            if fishInfo.ft >= 5 and fishInfo.ft <= 19 then  -- 烈焰风暴不重复获取
                if self.revenue > self.lyfb_config.drop_need_revenue   -- 收入条件1
                    and math.random() < self.lyfb_config.base_drop_ratio * fishInfo.multiple then -- 概率条件
                    if self.revenue > bulletInfo.mul * self.lyfb_config.max_free_count then  -- 收入条件2
                        --获得免费游戏
                        userInfo.freeTime = skynet.now() + 100 * self.lyfb_config.duration
                        userInfo.freeCnt = self.lyfb_config.max_free_count
                        userInfo.freeMul = bulletInfo.mul
                        userInfo.freeScore = 0

                        --发送消息
                        local retobj  = {}
                        retobj.c      = PDEFINE.NOTIFY.NOTIFY_FISH_EVENT
                        retobj.code   = PDEFINE.RET.SUCCESS
                        retobj.seat   = userInfo.seat
                        retobj.evt    = "lyfb_start"
                        retobj.duration = self.lyfb_config.duration
                        retobj.mul = bulletInfo.mul
                        self:broadcast(deskInfo, cjson.encode(retobj))

                        LOG_INFO("lyfb start:", userInfo.uid, bulletInfo.mul, self.revenue)
                    end
                end
            end
        end
    else
        --机器人
        if (fishInfo.ft>=20 and fishInfo.ft<=24) or fishInfo.ft==30 then
            local ai = self.delegate._getAi(userInfo.uid)
            if ai then ai:pause(6) end
        end
    end
end

function Hwfish918Feature:onUserBomb(deskInfo, userInfo, boomInfo, score)
    if userInfo.real then  --真实玩家
        self.revenue = self.revenue - score
    else    --机器人
        local t = 8
        if boomInfo and boomInfo.ft == 28 then t = 12 end
        local ai = self.delegate._getAi(userInfo.uid)
        if ai then ai:pause(t) end
    end
end

