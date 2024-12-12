PDEFINE_REDISKEY =
{
    ["YOU9API"] =
    {
        ["disbigbang"] = "you9sdkapi:bigbang:disbigbang",
        ["bigbangreward"] = "you9sdkapi:bigbang:reward",
        ["redbagsetting"] = "you9sdkapi:redbag:setting",
        ["pooljp"] = "you9sdkapi:pooljp:data",
        ["day7coindiff"] = "you9sdkapi:7daycoindiff",
        ["rewardrate_user"] = "you9sdkapi:rewardrate:user",
        ["rewardrate_agent"] = "you9sdkapi:rewardrate:agent",
        ["token2account"] = "you9sdkapi:account:token2account",
        ["account2token"] = "you9sdkapi:account:account2token",
        ["subgame_localpool"] = "you9sdkapi:subgamepool",
        ['MAIN_TAIN'] = 'server_maintain',
        ['KICK_USER'] = '{bigbang}:account:login:matchpwd:locksec:', --后台踢掉用户，2分钟内禁止登录
    },
    ["GAME"]=
    {
        --类型:数据所属层次
        ["waterpool"]="game:waterpool",
        ["waterpool_local"]="game:waterpool_local",
        ["waterpool_rate"]="game:waterpool_rate",
        ["loginlock"]="game:loginlock",
        ["deskdata"]="game:deskdata",
        ["history"]="game:history",
        ["loandata"]="game:loandata",
        ["expire_sortedset"]="game:deskdata:expire_sortedset",
        ["exitgame"] = "game:exit",
        ["online"] = "game:online:",
        ["gamedata"]="game:gamedata",
        ["favorite"] = "game:favorite:",
        ["coinpot"] = "game:bet:coinpot:",  -- 下注游戏的金币池
        ["records"] = "game:records:",  --游戏趋势图记录
        ["resrecords"] = "game:resrecords:" --游戏开奖结果记录
    },
    ["RACE"] = {
        ["last_user"] = "race:first:last:"
    },
    ["LOBBY"] = {
        ["fbshare"] = "fb:share",
        ["fbinvite"] = "fb:invite",
        ["testaccount"] = "lobby:testaccount", --测试用户uid
        ["exchange"] = "exchange_code", -- 可用兑换码set
        ["exchange_times_err"] = "exchange_err:", --兑换码错误次数
        ["exchange_err_ban"] = "exchange_err_ban:", --兑换码禁用
        ["exchange_times_use"] = "exchange_ok:", --兑换成功次数
        ["exchange_ok_ban"] = "exchange_ok_ban:", --兑换成功禁用
        ["backgame"] = "lobby:backgame:",  -- 召回推送奖励
        ["BanUserList"] = "lobby:ban:uids",  -- 召回推送奖励
        ["INVITE_USER"] = 'invite_users:', --邀请用户
        ["ALL_INVITE_CODES"] = 'all_invite_code', --所有邀请码集合
        ['REG_ONE_TIME'] = 'reg_one_time:', --新用户协议1的时间戳
        ['REG_DIFF_TIME'] = 'reg_diff_time:', --新用户协议2 - 协议1的时间戳
    },
    ["WINRANK"] = {
        ["hour"] = "winlist_slot:hour:",            -- slot时榜
        ["pk"] = "winlist_slot:hour_single_pk:",    --PK锦标赛（时榜赢得金币数最多的玩家）
        ["total"] = "winlist_slot:hour_total:",     --今日累计赢家
        ["single"] = "winlist_slot:daily_single:",  --今日手气最佳
        ["lastround"]= "winlist_slot:last_round:",  --上一局信息
        ["yesterday"] = "winlist_slot:yesterday:",  --排行榜昨日加成玩家排名记录
    },
    ["CHARMRANK"] = {
        ["week"] = "rank:charm:week", -- 周魅力值排行榜
        ["month"] = "rank:charm:month", -- 月魅力值排行榜
        ["total"] = "rank:charm:total",  -- 总魅力值排行榜
    },
    ["VIP"] = {
        ["levelslot"] = "vip:level:slot:", --等级礼包slot blast
        ["levelburst"] = "vip:level:burst:", --等级礼包 升级
        ["levelcollect"] = "vip:level:collect:", --等级礼包, 可以打开信箱一键收藏功能
        ["levelspeed"] = "vip:level:speed:", --升级加速，对应金币得到的经验值翻倍
        ["levelreward"] = "vip:level:reward:", --升级对应奖励金币得到翻倍
        ["maxfriendscount"] = "vip:friends:cnt:", --好友数上限
        ["badge1"] = "vip:badge1:", --vip 会员勋章 骑士
        ["badge2"] = "vip:badge2:", --vip 会员勋章 爵士
        ["periodbonus"] = "vip:periodbonus:", --周奖励
    },
    ["TASK"] ={
        ["levelup"] = "task:levelup",       --升级任务
        ["NEWBIE"] = "task:newbie",       -- 新手任务
        ["SKIN_SEND"] = "skin_send:", --签到奖励道具
        ["SKIN_CHARM"] = "skin_charm:", --魅力值道具赠送次数
    },
    ["OTHER"] = {
        ["reddot"] = "OTHER:tag:reddot:", --标签页红点
        ["doublewin"] = "OTHER:doublewin:",  --分享bigwin翻倍
        ["viprewards"] = "vip:rewards:", --待领取的vip奖励
        ["rpendtime"] = "rp:endtime:", --rp截止时间
        ["booster"] = "exp:booster:", --exp加速时间
        ["private_room_reward"] = "private:room:reward:", -- 好友房抽水
        ["recent_send_charm"] = "other:send_charm:recent:", -- 最近随机赠送礼物的uid
        ["persistent_room_uids"] = "other:persistent_room:uids",  -- 自动创建沙龙房的uids
        ["invite_count_offline"] = 'offline:', --我离线时候，绑我码的人数, 我上线后会清理掉
        ['today_draw_times'] = 'daydrawtimes:', --今日成功提现次数
        
    },
    ["CARD"] = {
        ["WEEK"] = "card:weekcoin:", --周卡, 周期内已获取金币数
        ["MONTH"] = "card:monthcoin:", --月卡，周期内已获取金币数
        ["GETMONTH"] = "card:getmonth:", --今日领取月卡标记
        ["GETWEEK"] = "card:getweek:", --今日领取周卡标记
        ["MONTHTRIAL"] = "card:trial:"  --今日月卡试用标记
    },
    ["SUBGAME"] = {
        ["BINGO"] = "subgame:bingo:",  -- bingo小游戏
    },
    ["RANK_SETTLE"] = {
        ['WEATHTIME'] = "rank:wealth:settletime", --财富榜每7天结算, 下一次结算奖励的时间
        ['WEALTHKING'] = "rank:wealth:king:", --财富榜结算 榜首前缀
        ['GAME_LEAGUE'] = 'rand:game:uid', --周游戏排位分排行
        ['WEATHTOPUID'] = 'rand:settle:topuid',
        ['GAME_BET_COIN'] = 'rank:game:bet:',  -- 转盘游戏中的押注排行榜
    },
    ["PASS"] = {
        ["QUEST"] = "pass:quest:",  -- 每个人的今日任务信息
    },
    ["CLUB"] = {
        ["SEASON"] = {
            ["START"] = "club:season:start",  -- 赛季开始时间
            ["STOP"] = "club:season:stop",  -- 赛季结束时间
        }
    },
    ["ADCHANNEL"] = {
        ['ANDROID'] = 'android_install_uids', --安卓渠道注册用户uids
    },
    ["SHARE"] = {
        ["TYPE"] = {
            ["TOTAL"] = "TotalWinTime:%s:%d", --累计次数
            ["CONT"] = "ContWinTimes:%s:%d:%d:%d", --每日连胜次数
            ["CONTGET"] = "ContWinGetTimes:%s:%d:%d", --每日连胜领取次数
        },
        ["COINKEY"] = "fbshare:%d:%d", --分享完可领取的金币数
    },
    ['QUEUE'] = {
        ['USER_BIND'] = 'usericon_queue', --绑定用户
        ['salon_tasks_list'] = 'salon_tasks_list', --沙龙任务
        ['fbshare_wheel_list'] ='fbshare_wheel_list', --fb分享转盘配置
        ['VIP_UPGRADE'] = 'vip_upgrade_list', --vip升级队列
        ['bonus_wheel_list'] ='bonus_wheel_list', --邀请下级奖励的转盘配置
        ['bonus_wheel_step'] = 'bonus_wheel_step:', --用户此轮bonus wheel的进度
        ['UNSUB_FIREBASE_TOPIC'] = 'unsub_firebase_topic', --旧的token取消订阅
        ['PAY_SUCC'] = 'recharge_succ', --支付成功
    },
    ["CONFIG"] = {
        ["WHEEL_GAME_SETTLE_REWARDS"] = "config:wheel_game:settle:rewards",  -- 转盘游戏的结算奖励
    },
    ["LEADERBOARD"] = {
        ["T_REGISTER"] = "d_lb_register:",  -- 注册表缓存
        ["T_REWARD"] = "d_leaderboard_reward:",  -- 奖励表缓存
        ['GAMEIDS'] = 'leaderboardgames', --支持排行榜的gameids
    },
    ["LOGIN"] = {
        ['REGISTER_OFF'] = 'register_off', --注册关闭
        ["SAME_IP_REGISTER_MAX_NUM"] = 'same_ip_reg_maxnum', --同一个IP最多允许注册N个账号
        ['SAME_IP_REGISTER_POOL'] = 'same_ip_reg_pool', --同一个IP最多允许注册N个账号的ip池
        ["IP_REGISTER_NUM"] = 'ip_reg_nums', --zset ip对应的注册数量
        ["BLACK_IP_POOL"] = 'blacklist_ip_pool', --黑名单ip
        ["DDID_LOGIN_POOL"] = 'ddid:',  --zset ddid对应的登录数量
        ["DDID_LOGIN_MAX_NUM"] = 'ddid_login_maxnum', --同一个ddid对应的最大登录数
        ['PHONE_LOGIN_LIMIT_LIST'] = 'phone_limit_set', --限制的设备型号列表
    }
}
return PDEFINE_REDISKEY