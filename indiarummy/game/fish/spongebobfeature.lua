local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson   = require "cjson"
require "fish.fishfeature"

--海绵宝宝特有玩法
-- 1，必杀雷射
-- 2，循环电网
-- 3，无敌炸弹

SpongebobFeature = class(FishFeature)

function SpongebobFeature:init(fishconfig)
    self.revenue = 0             --系统收分(技能炮弓额外奖励从收分中出)
    self.skill_config = fishconfig.skill  --技能炮配置
    self.total_weight = 0
    for _, item in ipairs(self.skill_config.items) do
        self.total_weight = self.total_weight + item.weight
    end
end

function SpongebobFeature:onUserFire(deskInfo, userInfo, bulletInfo)
    if userInfo.real then  --真实玩家
        self.revenue = self.revenue + bulletInfo.mul
    end
end

function SpongebobFeature:onUserCatched(deskInfo, userInfo, fishInfo, bulletInfo)
    if userInfo.real then 
        self.revenue = self.revenue - fishInfo.multiple * bulletInfo.mul

        if userInfo.sk == nil and fishInfo.ft >= 5 and fishInfo.ft <= 19 then  -- 技能炮不重复获取
            --技能炮
            if self.revenue > self.skill_config.drop_need_revenue   -- 收入条件1
                and math.random() < self.skill_config.base_drop_ratio * fishInfo.multiple then -- 概率条件
                --按权重计算技能类型
                local rand = math.random(1, self.total_weight)
                local cur_weight = 0
                local idx = 1
                for i, item in ipairs(self.skill_config.items) do
                    cur_weight = cur_weight + item.weight
                    if cur_weight >= rand then
                        idx = i
                        break
                    end
                end

                local item = self.skill_config.items[idx]
                if self.revenue > bulletInfo.mul * item.max_multiple then  -- 收入条件2
                    userInfo.sk = true      -- 标记技能炮
                    --创建炸弹
                    local boomInfo = {uid=userInfo.uid, mul=bulletInfo.mul, bm=item.boom, ft=item.id, 
                        max=item.max_multiple*bulletInfo.mul*1.5}  --记录炸弹信息
                    local boomid = self.delegate._newFishId()
                    self.delegate._addBoom(boomid, boomInfo)

                    --发送消息
                    local retobj  = {}
                    retobj.c      = PDEFINE.NOTIFY.NOTIFY_FISH_EVENT
                    retobj.code   = PDEFINE.RET.SUCCESS
                    retobj.seat   = userInfo.seat
                    retobj.evt    = "skill"
                    retobj.boomid = boomid
                    retobj.fid    = fishInfo.id
                    retobj.ft     = item.id
                    self:sendmsg(userInfo, cjson.encode(retobj))

                    LOG_INFO("获得技能炮:"..item.id, userInfo.uid, bulletInfo.mul, self.revenue)
                end
            end
        end
    end
end

function SpongebobFeature:onUserBomb(deskInfo, userInfo, boomInfo, score)
    if userInfo.real then  --真实玩家
        self.revenue = self.revenue - score

        if boomInfo.ft >= 31 and boomInfo.ft <= 33 then
            userInfo.sk = nil       --清除技能炮标记
        end
    end
end

