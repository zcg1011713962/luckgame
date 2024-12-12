--日常赛
local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
local sportconst = require "sport.sportconst"
local sportutil = require "sport.sportutil"
require("sport.sport")


SportDaily = class(Sport)

function SportDaily:heartbeat(dt)
    local ostime = os.time()
    if self.status == sportconst.SPORT_STATUS_INIT then
        if ostime > self.start_ostime and ostime < self.end_ostime then
            self:start()
        end
    elseif self.status == sportconst.SPORT_STATUS_GOING then
        -- 分配桌子
        self:assign()
    end

    --超时不管处于什么状态都结算掉
    if ostime > self.end_ostime then
        self:finish()
    end
end

function SportDaily:start()
    self.end_ostime = self.start_ostime + 55*60
    self:_start()
end

function SportDaily:finish()
    -- 积分排序
    local sporter_list = self:getRanklist()

    --保存排名
    local rank_data = cjson.encode(sporter_list)
    self:saveRankToDb(rank_data)

    -- 发放奖励
    for i, reward in ipairs(sportconst.DAILY_SPORT_RANK_REWARD) do
        if i <= #sporter_list then
            local uid = sporter_list[i].id
            local t = sportutil.timestamp(self.start_tm)
            LOG_DEBUG("uid：", uid, " 名次:", i, " 要发送邮件奖励了:", reward)
            -- local msg = string.format("恭喜您获得第 %d 期金拉米大奖赛 第 %d 名，奖励 %d 金币", math.floor(t/100), i, reward)
            local msg = string.format("congratulation! NO.%d in the %dth Grand Prize Game", i, math.floor(t/100),  reward)
            -- local msg = string.format("Congrats! You are No.%d of the S1 Gin Rummy Grand Prix Tournament. The prize is %d coins!")
            local title = string.format("NO.%d in the %dth Grand Prize Game", i, math.floor(t/100))
            self:sendRewardMail(uid, msg, reward, title)
            
            -- 更新名次
            local sporter = self.sporter_dict[uid]
            sporter:setRanking(i)
            sporter:addSendCoinLog(reward)
            -- 冠军获得总决赛资格
            if i==1 then
                self.delegate.addDailyChampion(uid)
            end
        end
    end

    self:_finish()
end

function SportDaily:settle(desk_id, players_score)
    self:_settle(desk_id, players_score)
end

function SportDaily:join(user_id, nick, icon, coin)
    if self.status ~= sportconst.SPORT_STATUS_GOING then  --未开始
        return 1  -- 不在比赛时间内
    end
    if os.time() + 10*60 > self.end_ostime then   -- 超时禁止进入
        return 2  -- 已进入结算阶段
    end
    if coin < sportconst.DAILY_SPORT_COIN_THRESHOLD then
        return 5
    end
    return self:_join(user_id, nick, icon)
end
