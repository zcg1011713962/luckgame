--总决赛
local cjson = require "cjson"
local sportconst = require "sport.sportconst"
local sportutil = require "sport.sportutil"
require("sport.sport")


SportFinal = class(Sport)

function SportFinal:heartbeat(dt)
    local ostime = os.time()
    if self.status == sportconst.SPORT_STATUS_INIT then
        if ostime > self.start_ostime and ostime < self.end_ostime then
            self:start()
        end
    elseif self.status == sportconst.SPORT_STATUS_GOING then
        if self.cur_round < self.max_round then
            if ostime > self.next_round_time then
                -- 进入下一轮
                self:nextRound()
            end
        end
        -- 分配桌子
        self:assign()
    end

    --超时不管处于什么状态都结算掉
    if ostime > self.end_ostime then
        self:finish()
    end
end

function SportFinal:start()
    self.next_round_time = self.start_ostime + sportconst.FINAL_SPORT_ROUND_DURATION
    self.end_ostime = self.start_ostime + 55*60
    self:_start()
end

function SportFinal:nextRound()
    local sporter_list = self:getRanklist()
    local out_user_list = {}
    self.cur_round = self.cur_round + 1
    self.next_round_time = self.next_round_time + sportconst.FINAL_SPORT_ROUND_DURATION
    if self.cur_round == 2 then
        -- 二轮
        -- 当前玩家取前20名, 20名以外的淘汰
        for _, sporter in pairs(self.sporter_dict) do
            local condition = false
            for _, sp in ipairs(sporter_list) do
                if sporter.user_id == sp.id then
                    condition = true
                    break
                end
            end
            if not condition then
                sporter.ranking = -1   --设置为-1表示淘汰
                table.insert(out_user_list, sporter.user_id)
            end
        end
    end

    --更新DB
    if #out_user_list > 0 then
        local sql = string.format("UPDATE d_sport_user SET ranking='-1' WHERE sport_id = '%d' AND user_id IN (%s)",
            self.sport_id, table.concat(out_user_list, ","))
        sportutil.mysql_exec_async(sql)
    end

end

function SportFinal:finish()
    -- 积分排序
    local sporter_list = self:getRanklist()

    --保存排名
    local rank_data = cjson.encode(sporter_list)
    self:saveRankToDb(rank_data)

    -- 发放奖励
    for i, reward in ipairs(sportconst.FINAL_SPORT_RANK_REWARD) do
        if i <= #sporter_list then
            local uid = sporter_list[i].id
            local t = sportutil.timestamp(self.start_tm)
            local msg = string.format("恭喜您获得第 %d 期金拉米牌王争霸赛 第 %d 名，奖励 %d 金币", math.floor(t/100), i, reward)
            self:sendRewardMail(uid, msg, reward)

            -- 更新名次
            local sporter = self.sporter_dict[uid]
            sporter:setRanking(i)
            sporter:addSendCoinLog(reward)
        end
    end

    --清除常规赛数据
    self.delegate.clearDailyChampion()

    self:_finish()

end

function SportFinal:settle(desk_id, players_score)
    if self.cur_round > 1 then
        for user_id, score in pairs(players_score) do
            local sporter = self.sporter_dict[user_id]
            if sporter and sporter.ranking==-1 then  -- 已淘汰
                for idx, desk in ipairs(self.desk_list) do 
                    if desk_id == desk.id then
                        table.remove(self.desk_list, idx)
                        break
                    end
                end
                return
            end
        end
    end
    self:_settle(desk_id, players_score)
end

function SportFinal:join(user_id, nick, icon, coin)
    if self.status ~= sportconst.SPORT_STATUS_GOING then  --未开始
        return 1  -- 不在比赛时间内
    end
    if os.time() + 10*60 > self.end_ostime then   -- 超时禁止进入
        return 2  -- 已进入结算阶段
    end
    if self.cur_round == 1 then
        if not self.delegate.isDailyChampion(user_id) then
            return 4
        end
    elseif self.cur_round == 2 then
        local sport = self.sporter_dict[user_id]
        if not sport then return 4 end  --未参加首轮
        if sport:isOut() then return 4 end    --首轮被淘汰
    end
    if coin < sportconst.FINAL_SPORT_COIN_THRESHOLD then
        return 5
    end

    return self:_join(user_id, nick, icon)
end



