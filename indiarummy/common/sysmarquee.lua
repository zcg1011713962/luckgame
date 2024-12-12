local cluster = require "cluster"
local skynet = require "skynet"

--发送全服广播的条件
local mqconfig = {
    game_win_coin = 2500,   --游戏赢分
    vip_level = 5,          --vip等级
    leaderboard_rank = 3,   --排行榜名次
    refer_earn_coin = 1000, --代理佣金
    rebate_bonus = 500,     --投注返水
    task_bonus = 500,       --任务奖励
    withdraw_coin = 20000,  --提现金额
    consecutive_win = 5,    --竞技类游戏连续赢得场次
}

local AR = PDEFINE.USER_LANGUAGE.Arabic
local EN = PDEFINE.USER_LANGUAGE.English

local sysmq = {}

sysmq.config = mqconfig

function sysmq.send(msg, delaySec)
    pcall(cluster.send, "master", ".userCenter", "sendAllServerNotice", msg, PDEFINE.NOTICE_TYPE.SYS, 1, nil, nil, delaySec)
end

--游戏赢分广播
function sysmq.onGameWin(playername, gameid, wincoin, delaySec)
    if wincoin >= mqconfig.game_win_coin then
        local gamename = "Game"
         if PDEFINE_GAME.GAME_NAME[gameid] then
            gamename = PDEFINE_GAME.GAME_NAME[gameid].en
        end
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has won [<color=#f0ff00>%.2f</c>] at [<color=#f87521>%s</c>], join him now at [<color=#f87521>%s</c>] to win big together.",
                                hidePlayername(playername), wincoin, gamename, gamename)
        }
        --延时，防止开奖结果未展示就播放中奖广播
        local delayTime = (delaySec or 7) * 100 + math.random(1, 10)
        skynet.timeout(math.floor(delayTime), function()
            sysmq.send(msg, 0)
        end)
        LOG_INFO("sysmarquee onGameWin", playername)
    end
end

--vip等级
function sysmq.onVipLevel(playername, level, bonus, weekbonus, monthbonus)
    if level >= mqconfig.vip_level then
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has upgrade to [<color=#f87521>Vip.%d</c>]. Upgrade bonus [<color=#f0ff00>%.2f</c>], Weekly bonus [<color=#f0ff00>%.2f</c>], Monthly bonus [<color=#f0ff00>%.2f</c>], upgrade your VIP level now and enjoy more bonus together.",
                            hidePlayername(playername), level, bonus, weekbonus, monthbonus)
        }
        sysmq.send(msg)
        LOG_INFO("sysmarquee onVipLevel", playername)
    end
end

--排行榜名次
--param rtype: Daily/Weekly/Monthly
function sysmq.onLeaderboardRank(playername, rtype, rank, coin)
    if rank <= mqconfig.leaderboard_rank then
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has won [<color=#f0ff00>%.2f</c>] at %s Leaderboard ranking %d, join %s Leaderboard now to win big together.",
                            hidePlayername(playername), coin, rtype, rank, rtype)
        }
        sysmq.send(msg)
        LOG_INFO("sysmarquee onLeaderboardRank", playername)
    end
end

--代理佣金
function sysmq.onReferEarn(playername, coin)
    if coin >= mqconfig.refer_earn_coin then
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has earned [<color=#f0ff00>%.2f</c>] at Refer&Earn, share your refer link now to earn more together.",
                            hidePlayername(playername), coin)
        }
        sysmq.send(msg)
        LOG_INFO("sysmarquee onReferEarn", playername)
    end
end

--投注返水
function sysmq.onRebateBonus(playername, coin)
    if coin > mqconfig.rebate_bonus then
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has climed [<color=#f0ff00>%.2f</c>] at Rebate Bonus, play more and clim more bonus together with him.",
                    hidePlayername(playername), coin)
        }
        sysmq.send(msg)
        LOG_INFO("sysmarquee onRebateBonus", playername)
    end
end

--任务奖励
function sysmq.onTaskBonus(playername, coin)
    if coin > mqconfig.task_bonus then
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has climed [<color=#f0ff00>%.2f</c>] at Task Bonus, finish more tasks and clim more bonus together with him.",
                        hidePlayername(playername), coin)
        }
        sysmq.send(msg)
        LOG_INFO("sysmarquee onTaskBonus", playername)
    end
end

--提现金额
function sysmq.onWithdrawCoin(playername, coin)
    if coin > mqconfig.withdraw_coin then
        local msg = {
            [AR] = '',
            [EN] = string.format("[<color=#00ff00>%s</c>] has withdrawed [<color=#f0ff00>%.2f</c>] successfully, join our telegram withdrawal proof channel at Contact US to check details,play safe and win big at Yono Games.",
                            hidePlayername(playername), coin)
        }
        sysmq.send(msg)
        LOG_INFO("sysmarquee onWithdrawCoin", playername)
    end
end

local cache_user_win_times = {}  --缓存玩家赢分次数(连赢只在userCenter处理，因此可以存在本地变量里)

--竞技类游戏连续赢得场次
function sysmq.onConsecutiveWin(playername, uid, wincoin)
    if wincoin <= 0 then
        cache_user_win_times[uid] = nil
    else
        local times = (cache_user_win_times[uid] or 0) + 1
        if times >= mqconfig.consecutive_win then
            cache_user_win_times[uid] = nil
            local msg = {
                [AR] = '',
                [EN] = string.format("[<color=#00ff00>%s</c>] have won [<color=#f0ff00>%d</c>] games in a row, play and win more together with him.", hidePlayername(playername), mqconfig.consecutive_win)
            }
            sysmq.send(msg)
            LOG_INFO("sysmarquee onConsecutiveWin", playername)
        else
            cache_user_win_times[uid] = times
        end
    end
end



return sysmq