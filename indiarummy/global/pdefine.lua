-- by: xiehuawei@pandadastudio.com
local PDEFINE_MSG = require "pdefine_msg"
local PDEFINE_ERRCODE = require "pdefine_errcode"
local PDEFINE_GAME = require "pdefine_game"
local PDEFINE_REDISKEY = require "pdefine_rediskey"
require "language/chineselang"
require "language/englishlang"

-- 使用msgpack作为通信协议
USE_PROTOCOL_MSGPACK = false

-- 定义一些常量
PDEFINE = {}

-- 接口协议对应处理函数
PDEFINE.PROTOFUN = PDEFINE_MSG.PROTOFUN
-- 错误码
PDEFINE.RET = PDEFINE_ERRCODE

PDEFINE.GAME_TYPE = PDEFINE_GAME.GAME_TYPE

--游戏类型
PDEFINE.GAME_KIND = PDEFINE_GAME.KIND

--游戏匹配接口
PDEFINE.GAME_MATCH = PDEFINE_GAME.MATCH

--游戏类型ID 以及需要创建的个数
--ID 游戏ID
--COUNT 创建的agent数量 百人场目前配置一个就行
--MATCH 0直接创建新房间(单机类) 1匹配规则(对战类) 2百人场(百人场)
PDEFINE.GAME_TYPE_INFO = PDEFINE_GAME.TYPE_INFO

--游戏名缩写
PDEFINE.GAME_SHORT_NAME = PDEFINE_GAME.GAME_SHORT_NAME

PDEFINE.NOTIFY = PDEFINE_MSG.NOTIFY

PDEFINE.NUMBER = PDEFINE_GAME.NUMBER

--应用ID
PDEFINE.APPID = 
{
    ["RUMMYSLOTS"] = 5, --横版rummyslots cash hero
    ["TEXASSLOTS"] = 6, --华为(Cash Hero)
    ["CASHHERO"] = 7, --cash master
    ["EUROPE"] = 8, --欧洲版华为
    ["MENSACARD"] = 9,  --10 是预定的rummyslot内网映射包
    ["MENSACARDHUAWEI"] = 11, 
    ["POKERHERO"] = 12, --pokerhero
    ["POKERHEROHUAWEI"] = 13, --pokerhero huawei
    ["DURAKHUAWEI"] = 14, --durak huawei
    ['ARABHEROGG'] = 15, --arab hero google
    ['ARABHEROIOS'] = 16, --arab hero ios
    ['YONOGAMES'] = 17, --YD: Yono Games
    ['ANOTHERHUAWEI'] = 18,  -- pokerhero another huawei
    ['RUMMYVIP'] = 19,  --YD: Rummy Vip
}

PDEFINE.LOGIN_TYPE = {
    ["GUEST"]  = 1, --游客
    ["MOBILE"] = 9, --手机号
    ["GOOGLE"] = 10, 
    ["APPLE"]  = 11,
    ["FB"]     = 12, --FB登录
    ["HUAWEI"] = 13,
}

-- 消息类型
PDEFINE.NOTICE_TYPE =
{
    ["SYS"] = 1, --系统
    ["USER"] = 2, --玩家
}

-- slot日志类型
PDEFINE.LOG_TYPE =
{
    ["BONUS_GAME"] = 1, --BONUS_GAME
    ["BET_X"] = 2, --BET_X
    ["FREE_GAME"] = 3, --FREE_GAME
}

PDEFINE.QUEST_STATE =
{
    ["INIT"] = 0, --初始化
    ["DONE"]  = 1, --完成了,可以领取了
    ["GET"] = 2, --领取了
    ["STOP"] = 4, --停止
}

--rediskey
PDEFINE.REDISKEY = PDEFINE_REDISKEY

--默认的概率配置
PDEFINE.DEFAULTREWARDRATE = "3"

--api的worker数量
PDEFINE.MAX_APIWORKER = 4

--表名对应的自增key 缓存值
PDEFINE.CACHE_LOG_KEY = {
    ["poolround_log"] = 'api_poolround',
    ["coin_log"] = 'master_coin_log_key',

    ["q_coins_log"] = "api_coins_log",
    ["q_pool_log"] = "api_pool_log",
    ["q_gplay_log"] = "api_tpgame_log",
    ["q_poolevent_log"] = "api_poolevent_log",
    ["club_id"] = "clubs_id",
}

--上报数据的功能模块名称
PDEFINE.REPORTMOD=
{
    ["login_c1"] = "login_c1",
    ["login_c2"] = "login_c2",
    ["offline"] = "offline",
    ["matchsess"] = "matchsess",
    ["exitgame"] = "exitgame",
    ["gamekick"] = "gamekick",
    ["gameresult"] = "gameresult",
}

--第三方平台定义
PDEFINE.PLATFORM = 
{
    
}

PDEFINE.SERVER_STATUS =
{
    ["start"] = 0,
    ["run"] = 1,
    ["full"] = 2,
    ["weihu"] = 3,
    ["stop"] = 4,
}

PDEFINE.SERVER_EVENTS =
{
    ["start"] = "start",
    ["stop"] = "stop",
    ["changestatus"] = "changestatus",
}

--玩家类型
PDEFINE.USER_TYPE =
{
    ["vip"] = "vip",
    ["normal"] = "normal",
}

-- 策略模块服务数量
PDEFINE.STRATEGY_WORKER_NUM = 8

--语言常量
PDEFINE.LANGUAGE =
{
    {
        ["KEY"] = "chinese", 
        ["LANG"] = CHINESELANG,
    },
    {
        ["KEY"] = "english", 
        ["LANG"] = ENGLISHLANG,
    },
}

-- 用户语言表现配置
PDEFINE.USER_LANGUAGE = {
    Arabic = 1,
    English = 2,
}

PDEFINE.COMMISSION_RATE = 0.1

PDEFINE.RANK_TYPE = {
    ["TOTALCOIN"] = 1, -- 总赢榜(定时榜, 所有数据当天凌晨形成排行榜)
    ["TOTALINCOME"] = 2, -- 当日收入榜(定时榜, 所有数据当天凌晨形成排行榜)
    ["TOTALLEAGUE"] = 3,  -- 排位分榜,(实时榜)
    ["FRIENDCOIN"] = 4, -- 好友财富榜(实时榜)
    ["FRIENDLEAGUE"] = 5, --好友排位赛榜单(实时榜)
    ["CHARM_WEEK"] = 6,  -- 魅力值周排行榜
    ["CHARM_MONTH"] = 7,  -- 魅力值月排行榜
    ["CHARM_TOTAL"] = 8,  -- 魅力值总排行榜
    ["GAME_WINCOIN"] = 9,  -- 指定游戏内赢取金币数量
    ["DIAMOND_WEEK"] = 10, --钻石消耗周榜
    ["RP_MONTH"] = 11, --RP值排行榜
    ["GAME_LEAGUE"] = 12, -- 游戏排位赛榜单
    ["VIP_WEEK"] = 13, --vip排行榜
}

--修改coin类型
PDEFINE.ALTERCOINTAG =
{
    ["UP"] = 1,--上分
    ["DOWN"] = 2,--下分
    ["BET"] = 3,--下注
    ["WIN"] = 4,--赢钱
    ["BIGBANG"] = 5,--bigbang
    ["REDBAG"] = 6,--红包
    ["THRIDADD"] = 7,--第三方转入
    ["THRIDOUT"] = 8,--第三方转出
    ["GROW_BOX"] = 11, --成长系统的宝箱
    ["MAXTAG"] = 11,--最大的tag值
    ["REDENVELOPE"] = 12,--红包用户从初始红包上分
    ["REDENVELOPESYS"] = 13,--bb总代直接红包
    ["LUCK_TURNTABLE"] = 14,--bb幸运转盘
    ["SHOP_RECHARGE"] = 15,--商城充值
    ["ONLINEAWARD"] = 16,   --在线奖励
    ["REGISTERAWARD"] = 17,  --玩家注册奖励
    ["TURNTABLE"] = 18,  --转盘奖励
    ["UPGRADEAWARD"] = 20,   --升级奖励
    ["MAILATTACH"] = 21,   --邮件附件
    ["QUESTAWARD"] = 22,       --任务奖励
    ["SHOP_GIFT"] = 23,--商城礼盒
    ["COMBAT"] = 24,  -- 结算（对战类游戏，多人游戏）
    ["REVENUE"] = 25,   --扣税（对战类游戏，多人游戏）
    ["VISTORCOIN"] = 26,
    ["SIGN"] = 27,
    ["TAG"] = 28,
    ["STAMPSHOP"] = 29, -- 集邮商店
    ["STAMPREWARD"] = 30, -- 集邮奖励
    ["MISSIONPASS"] = 31, -- mission pass
    ["FRIENDS"] = 32, -- friends jackpot
    ["FUNDAWARD"] = 33, --基金
    ["FBSHARE"] = 34, --fbshare
    ["ACTIVITY"] = 35,  -- 活跃度奖励
    ["CARDWEEK"] = 36, --周卡
    ["CARDMONTH"] = 37, --月卡
    ["FREE_PIGGY"] = 38,   --免费金猪
    ["HEROCARD"] = 39,   --英雄卡牌
    ["EGG"] = 40,  -- 砸蛋
    ["FRIENDSHARE"] = 41, --friends jackpot fbshare
    ["CARD"] = 42,  -- 卡牌活动
    ["GAMETASK"] = 43, --gametask
    ['CARD_LOTTERY'] = 44, --卡牌抽卡
    ["BINGO"] = 45, -- bingo游戏
    ["NEWBIE"] = 46, -- 新手任务
    ["DAILYBONUS"] = 47, --daily bonus 签到
    ['FUND'] = 48, --fund
    ["SHOP"] = 49, --商城
    ["BINDCODE"] = 50, --绑定邀请码
    ["WINRANKCOIN"] = 2700, --排行榜金币 --27会和游戏id重复
    ["PROFIT_TRANSFER"] = 101, --收益余额提现成账户余额，玩家账户将自身当前的收益余额提现到账户余额
    ["ONLINEAWARD_GUAGUALE"] = 102,   --刮刮乐
    ["FBSHARE_FRIENDS"] = 103, --好友列表 FB分享
    ["FBSHARE_DOUBLE_WIN"] = 104, --bigwin分享翻倍
    ["BANKRUPT"] = 109, --破产补助
    ["BINDFB"] = 110, --绑定fb
    ["OFFLINEAWARDS"] = 111, --离线奖励
    ["LEAGUE_TICKET"] = 112, --排位赛
    ["PRIVATE_ROOM"] = 113,  -- 私人房 营收
    ['CHARM'] = 114, --魅力值道具
    ['CDKEY'] = 115, --兑换码激活
    ['MAIN_TASK'] = 116, -- 主线任务
    ["RP"] = 117, --rp值兑换
    ['SEND'] = 118, --好友赠送
    ['LEAGUE'] = 119,  -- 排位奖励
    ['PHIZ'] = 120, --游戏内道具
    ['PRIVATE_ROOM_COIN'] = 121, --好友房收益
    ['FBSAHRE_IN_GAME'] = 122, --房间内结算FB分享
    ['DRAW'] = 123, --提现
    ['VIP_REWARDS'] = 124, --VIP塔奖励
    ['BANKDOWN'] = 125, --银行存款
    ['BANKUP'] = 126, --银行取款
    ['RAKEBACK'] = 127, -- 返水 
    ['WITHDRAW_BACK'] = 128, --提现打回
    ['LEADERBOARD'] = 129, -- 排行榜
    ['AGENT_REG_REWARDS'] = 130, --下级注册奖励
    ['AGENT_BUY_REWARDS'] = 131, --下级购买奖励
    ['AGENT_BET_REWARDS'] = 132, --下级bet奖励
    ['BONUS_TRANSFER'] = 133, --bonus 转可用余额
    ['TN_REWARD'] = 134, -- 锦标赛奖励
    ['TN_REGISTER'] = 135, -- 锦标赛注册
    ['MAIL_REWARDS'] = 136, --邮件附件
    ['DRAWRETURN'] = 137, --拒绝draw，返回
    ['VIP_BONUS'] = 138, --vip bonus奖励
    ['OTHER_REWARDS'] = 139, --其他奖励
    ['FREE_WINNS2BONUS'] = 140, --转移到bonus中
    ['QUEST_RECHARGE'] = 141, --充值任务
    ['QUEST_GAMES'] = 142, --游戏任务
    ['QUEST_WINCOIN'] = 143, --盈利任务
    ['QUEST_BET'] = 144, --下注任务
    ['BONUS2BALANCE'] = 145, --bonus转移到balance中
    ['VIP_WEEK'] = 146, --vip 周彩金
    ['VIP_MONTH'] = 147, --vip 月彩金
    ["RECHARGE_SELF_BONUS"] = 148,--自己充值彩金
}

-- 弹窗类型
PDEFINE.POP_TYPE = {
    NewPlayGift = 1,  -- 新手礼包
    OneTimeOnly = 2,  -- one time only
    OpenEvent = 3,  -- 开服活动
    FbShare = 4,  -- FB分享
    Signup = 5,  -- 签到
    Shop = 6,  -- 商城 
    MasterGame = 7,  -- 引导主推游戏弹窗
    MoneyPig = 8,  -- 金猪
    LevelGift = 9,  -- 等级礼包 
    OfflineGift = 10,  -- 离线奖励礼包
    Quest = 11,  -- QUEST
    MonthCard = 12,  -- 月卡
    Bingo = 13,  -- bingo活动
    ShareFbWithCoin = 14, -- fb分享弹窗 送金币
    Fund = 15,  -- 基金
    FirstPay = 16,  -- 首充
    BindFbUnlockGame = 17,  -- 绑定fb解锁游戏
    BackGame = 18,  -- 召回奖励弹窗
    RecommendGame = 19,  -- 推荐子游戏
    CoinWheel = 20,  -- 大转盘
}

--一轮借款或者扣库存的状态
PDEFINE.POOLROUND_STATUS = 
{
    ["start"] = 0, --开始
    ["end"] = 1, --已经结束
    ["expireend"] = 2, --过期结束
}

-- 任务类型
PDEFINE.QUEST_TYPE =
{
    ["REPEAT"] = 1, --每日任务
    ["LIFE"] = 2, --终身只能一次
    ["ADDUP"]  = 3,  --累计叠加型，邀请有礼
    ["RECHARGE"] = 4, --每日充值有奖任务
    ["NEWER"] = 8, --新手任务
}

PDEFINE.QUEST_STATE =
{
    ["INIT"] = 0, --初始化
    ["DONE"]  = 1, --完成了,可以领取了
    ["GET"] = 2, --领取了
    ["STOP"] = 4, --停止
}


--彩池事件的类型
PDEFINE.POOLEVENT_TYPE = 
{
    ["delstock"] = 1, --扣库存结算
    ["loan"] = 2, --结算-来自借款
    ["redbag"] = 3 --红包-来自借款
}

--彩池的类型
PDEFINE.POOL_TYPE = 
{
    ["none"] = 0, --不是彩池来的
    ["delstock"] = 1, --扣库存
    ["loan"] = 2, --借款
}

PDEFINE.SUBGAME_STATE = {
    ["START"] = 1, -- join时候为开始
    ["ACTION"] = 2, -- 选择动作时候
    ["PEXIT"] = 3, -- 准备退出
    ["NORMAL"] = 0,
}

--slots 押注是否押满
PDEFINE.BET_TYPE = {
    ['FULL'] = 1,    -- 押满
    ['NOTFULL'] = 0, -- 未押满
}

--订单状态
PDEFINE.ORDER_STATUS = {
    ['PAYING'] = 1,
    ['PAID'] = 2, --支付成功，发货成功
    ['SHIPPING'] = 3, --支付完成发货中
}

PDEFINE.FLOW_TYPE =
{
    ["COMBAT"] = 1,--结算 
    ["REVENUE"] = 2,--扣税
    ["ESCAPE"] = 3, --逃跑
    ["UP_DOWN_COIN"] = 4,--猜拳过分 --
    ["MAIL_COIN"] = 5,--邮件附件获取分数 --
    ["SIGN"] = 6,--签到送分 --
    ["NICKNAME"] = 7,--修改昵称扣分 --
    ["QUEST"] = 8,--完成任务送分 --
    ["BDFB"] = 9,--绑定FB送分 --
    ["RANKLIST"] = 10,--排行榜送分 --
    ["WINLIST"] = 11,--赢家排行榜送分 --
    ["ONLINE"] = 12,--在线时长 --
    ["LOGIN"] = 13,--登录奖励 --
    ["REG"] = 14,--注册奖励 --
    ["ORDER"] = 15,--下单购买 --
    ["BET"] = 16, --下注
    ["UP"] = 17, --上分
    ["DOWN"] = 18, --下分
    ["BIGBANG"] = 19, --bigbang
    ["REDBAG"] = 20, --红包
    ["THRIDADD"] = 21, --第三方转入
    ["THRIDOUT"] = 22, --第三方转出
    ["WEEKCARD"] = 23, --周卡
    ["MONTHCARD"] = 24, --第三方转出
    ["BINDACCOUNTCODE"] = 25, --绑定账号绑定码赠送金币
}


-- d_user_xxx_data 表数据类型
PDEFINE.USERDATA =
{
    ["COMMON"] =
    {
        ["HAS_UNREAD_MAIL"] = 1,	-- 是否有未读邮件
        ["HAS_NEW_MAIL"] = 2,		-- 是否有新邮件到达
        ["HAD_MODIFY_NICKNAME"] = 3,-- 是否已修改昵称
        ["HAD_MODIFY_USERICON"] = 4,-- 是否已修改头像
        ["GUEST_PIC_ID"] = 5, --游客头像id
        ["FUND_BUYTIME"] = 6, --基金购买时间
        ["FUND_COLLECT"] = 7, --基金全部收集完的时间
        ["TIMELIMITPOP"] = 8, --限时礼包是否购买过
        ["LASTLOGOUTTIME"] = 9, --上次退出时间
        ["SPRINGGIFT"] = 10, --春季礼包
        ["CARDWEEKCOIN"] = 12, --周卡初始订单获得的金币
        ["CARDMONTHCOIN"] = 13, --月卡初始订单获得的金币
        ["CARDWEEK"] = 14, --周卡
        ["CARDMONTH"] = 15, --月卡
        ["GUIDE"] = 16, --新手引导
        ["ACTIVITY_LEVEL"] = 17, -- 存放当轮活跃值的触发等级
        ["EGG_TIME"] = 18, --金蛋锤子初始时间
        ["EGG_HAMME_SILVER"] = 19, --金蛋，银锤子
        ["EGG_HAMME_GOLD"] = 20, --金蛋，金锤子
        ["FREE_PIGGY"] = 21,   --免费金猪
        ["CARD_REVIVE"] = 22, --复活卡
        ["CARDMONTHTRIAL"] = 23, --月卡试用
        ["CARD_REVIVE_BOSS"] = 24, --幸运抽卡reset次数
        ["SHARE_COUNT"] = 25, -- facebook分享次数
        ["FIRST_PAY_GIFT_RECORD"] = 26, -- 首充礼包领取情况
        ["TIMES_SUMMON"] = 27, --10连抽剩余次数
        ["HAS_NEW_MESSAGE"] = 28, --有新系统消息
        ["LEAGUE_EXP_LAST_BALOOT"] = 29, --最高排位分上次金额 baloot
        ["FRIENDSMAX"] = 30, --好友上限
        ["SEND_TICKET_TIME"] = 31, --赠送排位券的时间
        ["SEND_TICKET_EXTRA"] = 32, --额外赠送排位券的时间
        ["TODAY_LEAGUE_TIMES"] = 33, --今日排位赛次数(券用完后)
        ["LEAGUE_EXP_LAST_HAND"] = 34, --最高排位分上次金额 hand
        ["SHARE_TURNTABLE"] = 35, --fb分享后，可以转转盘的标识
        ["VIP_END_TIME"] = 36, --基础vip到期时间
        ['DAILY_TASK_BONUS'] = 37, --每日任务进度条bonus
        ['SWITCH_SENDER'] = 38, --开关:赠送给好友金币
        ['SWITCH_GIFTCODE'] = 39, --开关: 礼品码，兑换码
        ['SWITCH_REPORT'] = 40, --开关:举报功能
        ['SPECIAL_QUEST'] = 41, -- 首次完成特殊日常任务
        ['CHANGE_AVATAR'] = 42, --修改头像
        ['CHANGE_NICK'] = 43, --修改昵称
        ['CHANGE_COUNTRY'] = 44, --修改国家
        ['CHAT_TIMES'] = 45, --聊天次数
        ['DONE_NEWBIE'] = 46, --新手任务全部完成
        ['SLOTS_COUNTRY'] = 100, --老虎机的国家选择
        ['CHARM_GIFT_PACK'] = 47, --新手大礼包
        ['TEMP_VIP_EXP'] = 48, -- 赠送的临时vip经验值
        ['TIMES_OF_TURNTABLE'] = 49, -- 奖励的转盘次数
        ['KYC_OF_SUN'] = 50, --直属下级通过kyc的数量
    },
}

--邮件类型
--[[
    购买钻石：18
购买金币：18
购买道具：18
排行榜奖励:17
激活VIP:15
升级段位:19
邀请好友奖励：7
系统欢迎邮件：8
系统通知  ：1
维护后的奖励邮件：13

]]
PDEFINE.MAIL_TYPE = {
    ["SYSTEM"] = 1,     --系统赠送
    ["FEEDBACK"] = 2,   --问题反馈邮件
    ["CASHTICKETS"] = 3, --比赛门票邮件
    ["GRANDPRIX"] = 4,   --比赛排名邮件
    ["DISCOUNT"] = 5,    --折扣
    ["WEBGIFT"] = 6,     --后台赠送(后台发送)
    ["QUESTCOIN"] = 7,   --任务未领取金币
    ["WELCOME"] = 8,    --新手奖励
    ["CASHGRANDPRIX10St"] = 9,      --争霸赛 GIN RUMMY cash 10st(后台发送)
    ["COINGRANDPRIX10ST"] = 10,  --大奖赛邮件标题为：Gold Coin Grand Prix 10st（ (后台发送)
    ["NEWGAMES"] = 11, --新的子邮件推荐
    ["FRIENDS"] = 12, --往好友系统领取页面跳转
    ["MAINTAIN"] = 13, --维护后的奖励邮件
    ["UNLOCK"] = 14, --解锁新子游戏
    ["VIP"] = 15, --vip通知邮件
    ["BINGO"] = 16,  -- bingo游戏排名奖励
    ["RANKING"] = 17,  -- 每日排行榜奖励
    ["SHOP"] = 18, --购买
    ["LEAGUE"] = 19, --升级段位
    ["INVITE"] = 20, -- 邀请奖励
    ["RACE"] = 21, -- 比赛奖励
    ["TOURNAMENT_REFUND"] = 22, -- 锦标赛退款
    ["TOURNAMENT_SETTLE"] = 23, -- 锦标赛结算
    ["LOGINBACK"] = 24, --N天后重登
    ["FIRSTRECHARGE"] = 25, --首次充值
    ["FIRSTDRAW"]  = 26, --首次提现
    ["FIRSTAGENT"] = 27, --首次成为代理
    ["FIRSTCOMMISSION"] = 28, --首次获得佣金
    ["RANKDIFF"] = 29, --排行榜上还差多少名
    ['DRAWSUCC'] = 30, --提现成功
    ['DRAWFAIL'] = 31, --提现失败
    ['KYCMOBILE']= 32, --手机号验证成功
    ['KYCPANSUCC'] = 33, --KYC PAN验证成功
    ['KYCPANFAIL'] = 34, --KYC PAN验证失败
    ['KYCBANKSUCC'] = 35, --KYC BANK验证成功
    ['KYCBANKFAIL'] = 36, --KYC BANK验证成功
    ['WINSERIES'] = 37, --连续赢N场
    ['WINMORETHAN'] = 38, --用户赢钱超过N 
    ['RECHARGEFAIL'] = 39, --充值审核拒绝
    ["RANKING_DAY"] = 40,  -- 每日排行榜
    ["RANKING_WEEK"] = 41,  -- 每周排行榜
    ["RANKING_MONTH"] = 42,  -- 每月排行榜
    ["RANKING_AGENT"] = 43,  -- 代理排行榜排行榜
}

PDEFINE.MAIL_SYSTEM_ID = {
    System = 0,  -- 'system'
}

-- 好友系统赠送类型
PDEFINE.REWARD_TYPE = {
    ["JACKPOT"] = 1, -- jackpot
    ["PRESENT"] =2 , -- 赠送
}

-- 俱乐部奖励类型
PDEFINE.CLUB_REWARD_TYPE = {
    ["JACKPOT"] = 1, -- jackpot
}


PDEFINE.SLOTSBENEFITS = {
    ["VIP_1"] = 10,  --10%
    ["VIP_2"] = 15,
    ["VIP_3"] = 30,
    ["VIP_4"] = 50,
}

PDEFINE.SHOPSTYPE = {
    ["STORE"] = 1, --商城
    ["LIMITEDOFFER"] = 2, --限时优惠
    ["TURNTABLE"] = 3, --转盘
    -- ["BOOST"] = 4, --激励礼包
    ["LEVEL"] = 5, --等级礼包
    ["SIGN"] = 6, --签到
    ["FIRSTRECHARGE"] = 7, --首充礼包
    ["ONETIME"] = 8, --One Time Only
    -- ["RANK"] = 9, --排行榜
    ["MONEYBAG"] = 10, --金猪
    -- ["MISSION"] = 11, --任务
    ["FUND"] = 13, --成长基金
    ["CARDWEEK"] = 14, --周卡/vip骑士
    ["CARDMONTH"]= 15, --月卡/vip爵士
    ["SPRINGGIFT"] = 16, --春季礼包
    ["DAILY_GIFT"] = 17,  -- 每日礼包，包括银锤子
    ["NEWGIFT"] = 18, --新人礼包
    ["HAMME_SILVER"]= 19, --银锤子
    ["HAMME_GOLD"]= 20, --金锤子
    ["REVIVE_CARD"] = 21, --复活卡
    ["BINGO_BUFF"] = 22, -- bingo超级buff
    ["BINGO_GIFT"] = 23, -- bingo色子次数point
    ["REVIVE_BOSS_CARD"] = 24, --超级复活卡，重置整个游戏
    ['DIAMOND'] = 25, --钻石
    ['VIP'] = 26, --vip
    ['SUPERPACK'] = 27, --优惠礼包1
    ['PROPACK'] = 28, --优惠礼包2
    ['PASS'] = 29,  -- 通行证
    ['VIP5'] = 30, --直达vip5
    ['TIMELIMITED'] = 31, --
    ['SKINS'] = 32, --皮肤道具
}

--新手礼包金额
PDEFINE.VISTOR = {
    ["INITCOIN"]  = 2000,
    ["ONETIMEONLY"] = 14400, --4个小时有效期 
    ["ANDROID_ID"] = 'com.rummyfree.19',
    ["IOS_ID"] = 'com.mensacard.19', --配合显示价格，实际不用来购买
}

PDEFINE.FBINFO = {
    ["DAILYMAX"] = {
        ["SHARE"] = 5,  --每天最多分享5次
        ["INVITE"] = 10,  
    }
}

PDEFINE.EMOJI = {
    ['FRIEND'] = {2,5,6}, --给好友发的互动表情
    ['RIVAL'] = {1,3,4}, --对对手发的互动表情
    ['ALL'] = {1,2,3,4,5,6}, --所有的
    ['PROB'] = 0.95,  -- 不触发赠送的概率
    ['TEXT'] = 0.85,  -- 不触发文字消息的概率
}

--账号类型
PDEFINE.ACCOUNT_TYPE = {
    ["GUEST"] = 1, --游客
    ["WX"] = 2,--微信
    ["FB"] = 3,--FB
    ["REGISTER"] = 4,--账号
    ["FB_SMALL_APP"] = 7,--FB小程序
}

PDEFINE.ACTIONS = {
    ["GAME"] = {
        [1] = "JOIN",      -- 子游戏进入时间	
        [2] = "EXIT",      -- 子游戏退出时间	
        [3] = "EXPEXIT",    -- 子游戏异常退出
    },
}

PDEFINE.SUBGAME_STATE = {
    ["START"] = 1, -- join时候为开始
    ["ACTION"] = 2, -- 选择动作时候
    ["PEXIT"] = 3, -- 准备退出
    ["NORMAL"] = 0,
}

PDEFINE.NEW_PLAYER_COUNT = 5

PDEFINE.REWARD_STATE = {
    ["NONE"] = 0, -- 不可用
    ["CANNOT_TAKE"] = 1, -- 不可领取
    ["CAN_TAKE"] = 2, -- 可以领取
    ["ALREADY_TAKE"] = 3, -- 已领取
}

PDEFINE.TASK_KEY = {
    ["NONE"] = 0, --
    ["SPIN_COUNT"] = 1, -- 押注次数
    ["WIN_COUNT"] = 2, -- 赢取次数
    ["SPIN_COIN"] = 3, -- 押注金币
    ["WIN_COIN"] = 4, -- 赢取金币
    ["MEMBER_LEVEL"] = 5, -- 成员等级
    ["COUNT_CARDS"] = 6, -- 统计图标
    ["COUNT_COLLECT"] = 7, --统计收集图标
}

PDEFINE.TASK_STATE = {
    ["NONE"] = 0, -- 不可用
    ["ACTIVE"] = 1, -- 进行中
    ["COMPLETE"] = 2, -- 达成
    ["FINISH"] = 3, -- 结束
}

PDEFINE.LIMIT = {
    ["CLUB_REWARD_COUNT"] = 200, -- 俱乐部奖励
}

PDEFINE.PROP_TYPE_FACTOR = 100000
PDEFINE.PROP_TYPE = {
    ["COMMON"] = 0, -- 通用
    ["STAMP"] = 1, -- 邮票
}
PDEFINE.PROP_ID = {
    ["COIN"] = 1, -- 金币
    ["VIP_POINT"] = 2, -- VIP点数
    ["DOUBLE_LEVEL_EXP"] = 3, -- 双倍等级经验
    ["DOUBLE_LEVEL_REWARD"] = 4, -- 双倍等级奖励
    ["TURN_TABLE"] = 5, -- 在线转盘
    ["ACTIVITY"] = 6,  -- 活跃值
    ["MISSION"] = 7,  -- mission star
    ["HERO_CARD"] = 8,  -- 英雄卡牌 (11 - 15不配置 表示1-5星卡牌)
    ["REVIVE_CARD"] = 9, --复活卡
    ["PALACE_POINT"] = 10, --富豪厅点数
    ["COIN_CAN_DRAW"] = 11, --可提现余额
    ["COIN_BONUS"] = 12, --优惠余额
    ["BINGO"] = 16, --bingo球
    ["GAMEOVER"] = 20, -- game over 幸运抽卡道具
    ["HERO_COMPLETE_CARD"] = 21,  -- 完整的卡(非碎片)
    ["STAMP_0_1"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 01, -- 一张随机星级邮票
    ["STAMP_1_1"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 11, -- 一张一星邮票
    ["STAMP_2_1"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 21, -- 一张两星邮票
    ["STAMP_3_1"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 31, -- 一张三星邮票
    ["STAMP_4_1"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 41, -- 一张四星邮票
    ["STAMP_5_1"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 51, -- 一张五星邮票
    ["STAMP_0_3"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 03, -- 三张随机星级邮票
    ["STAMP_1_3"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 13, -- 三张一星邮票
    ["STAMP_2_3"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 23, -- 三张两星邮票
    ["STAMP_3_3"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 33, -- 三张三星邮票
    ["STAMP_4_3"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 43, -- 三张四星邮票
    ["STAMP_5_3"] = 1 * PDEFINE.PROP_TYPE_FACTOR + 53, -- 三张五星邮票
    ['DIAMOND'] = 25, --钻石
    ["BOX_BRONZE"] = 26, --青铜宝箱
    ["BOX_SILVER"] = 27,  -- 白银宝箱
    ["BOX_GOLD"] = 28,  -- 黄金宝箱
    ["LEAGUE_TICKET"] = 29,
    ["WEALTH_AVATAR"] = 31, --财富榜奖励皇冠头像框
    ["WEALTH_EMOTO"] = 32, --财富榜奖励表情包
    ["WEALTH_KING"] = 33, --财富榜奖励king标志
    ["BOX_DIAMOND"] = 34,  -- 钻石宝箱
    ["SKIN_FONT"] = 35,  -- 字体皮肤奖励
    ["PASS_EMOJI"] = 36,  -- 通行证专属纪念表情包
    ["VIP_DAY"] = 38,  -- VIP天数
    ["SKIN_POKER"] = 39,  -- 牌背奖励
    ["SKIN_TABLE"] = 40, --牌桌
    ["CHARM"] = 41, --魅力值
    ["RP"] = 42, --rp值积分
    ["SKIN_FRAME"] = 43, --奖励头像框
    ["SKIN_CHAT"] = 44, --奖励聊天框
    ["SKIN_EMOJI"] = 50, --表情包
    ["VIP_LEVEL"] = 51, --vip等级
    ["LEAGUE_LEVEL"] = 52, --排位等级
    ["SKIN_FACE"] = 53, --牌花
    ["SKIN_CHARM"] = 54, --魅力值道具, bonus会赠送次数
    ["SKIN_EXP"] = 55, --加速升级道具
    ["TEMP_VIP_LEVEL"] = 56, -- 临时vip等级(包括天数)
}

--系统解锁等级
PDEFINE.SYS_UNLOCK_LEVEL = {
    ["QUEST"] = 3,      --新手任务
    ["HEROES"] = 12,     --英雄卡牌系统
    ["PIGGY"] = 8,     --金猪
    ["FRIEND"] = 15,    --好友
    ["FREE_PIGGY"] = 20, --免费送1次金猪
    ["EGG"] = 16,  -- 砸蛋
    ["DailyEvent"] = 5,  -- 日常活动
    ["Bingo"]  = 10,  -- bingo
}

-- 活动类型，用来标识活动，目前用于标识卡牌掉落分类
PDEFINE.EVENT_TYPE = {
    ["EGG"] = 1,  -- 砸蛋活动
    ["BINGO"] = 2,  -- Bingo活动
}

PDEFINE.BAL_ROOM_TYPE = {
	['MATCH'] = 1, --匹配房
	['VIP'] = 2, --vip房
	['LEAGUE'] =3, --排位赛分
    ['CLUB'] = 4,  -- 俱乐部房间
    ['PRIVATE'] = 5,  -- 私人房间
    ['TOURNAMENT'] = 6,  -- 锦标赛房间
}

PDEFINE.PRIVATE_ROOM_COIN = 400  -- 私人房间房费

PDEFINE.CHAT_ROOM = 4 --世界聊天室

PDEFINE.DEFAULTSKIN = {
    ["NEWER_AVATAR"] = "avatarframe_newer", --新人头像框
}

PDEFINE.TICKET = {
    ["TICKET"] = {1,2}, --hand one扣1张  normal扣2张
    ["VIP0"] = {10, 20, 30, 40, 50}, --普通用户，5次都是钻石
    ["VIP1"] = {10, 20, 30, 40, 50}, --基础vip
    ["VIP2"] = {10, 20, 30, 40, 50},
    ["VIP3"] = {10, 20, 30, 40, 50},
    ["VIP4"] = {10, 20, 30, 40, 50},
    ["VIP5"] = {10, 20, 30, 40, 50},
    ["VIP6"] = {10, 20, 30, 40, 50},
    ["VIP7"] = {10, 20, 30, 40, 50},
    ["VIP8"] = {10, 20, 30, 40, 50},
    ["VIP9"] = {10, 20, 30, 40, 50},
    ["VIP10"] = {10, 20, 30, 40, 50},
    ["VIP11"] = {10, 20, 30, 40, 50},
    ["VIP12"] = {10, 20, 30, 40, 50},
    ["VIP13"] = {10, 20, 30, 40, 50}, --vip 12级
}

-- 推送消息id
PDEFINE.PUSHMSG = {
    ['ONE'] = 1, --升到下一级还需要100经验值时
    ['TWO'] = 2, --每日奖励可用时!
    ['THREE'] = 3, --当您的一位朋友与您聊天，您未查看消息时!
    ['FOUR'] = 4, --当玩家 3 天未玩时!
    ['FIVE'] = 5, --当玩家接受您的好友请求时!
    ['SIX'] = 6, --当新手任务未全部完成时
    ['SEVEN'] = 7, --当一名玩家在(财富榜)排行榜中被超越时!
    ['EIGHT'] = 8, --每周最后一天，结算前3个小时!
}

-- 用于大厅的任务，目前是写死任务id，后续再优化
PDEFINE.COMMON_QUEST = {
    singleTimesQuestIds = {107,108,109}, -- 单局游戏
    multiTimesQuestIds = {110,111,112},  -- 多局游戏
    singleWinQuestIds = {113,114,115},  -- 单局赢
    multiWinQuestIds = {116,117,118},  -- 多局赢
    goDownTimesQuestIds = {119,120,121},  -- godown次数
}

-- 桌子状态
PDEFINE.DESK_STATE = {
    MATCH = 1,  -- 匹配阶段
    READY = 2,  -- 准备阶段
    PLAY = 3,  -- 玩牌阶段
    SETTLE = 4,  -- 小结算状态
    GAMEOVER = 5,  -- 游戏结束
    BIDDING = 6,  -- 叫牌阶段
    SHOWCARD = 7,  -- 亮牌阶段
    ChooseRule = 8,  -- 庄家选择游戏规则阶段
    SwitchCard = 9,  -- 换牌阶段
    ChooseInitScore = 10,  -- 选择分数阶段
    WaitStart = 11,  -- 等待开始
    WaitSwitch = 12,  -- 等待换桌
    WaitSettle = 13,  -- 等待结算
}

-- 玩家状态
PDEFINE.PLAYER_STATE = {
    Wait = 1,  -- 等待状态
    Ready = 2,  -- 准备阶段
    Bidding = 3,  -- 叫牌阶段
    Discard = 4,  -- 出牌阶段(ludo:走棋子)
    ChooseSuit = 5,  -- 选择花色阶段
    Draw = 6,  -- 摸牌阶段 (ludo:摇骰子状态)
    ChooseMethod = 7,  -- 选择玩法阶段
    ChooseShowCard = 8,  -- 选择亮牌
    DashCall = 9,  -- dash call 阶段
    ChooseScore = 10,  -- 选择期望分数
    ChooseRule = 11,  -- 选择游戏古则
    SwitchCard = 12,  -- 换牌
    ChooseInitScore = 13,  -- 选择初始化分数
    GoDown = 14,  -- hand类似游戏中摸了上家牌，必须godown
    ConCan = 15,  -- concan 游戏中的concan选择
    Darba = 16,  -- ronda中，出了相同牌后，可用相同牌收回
    DiscardPass = 17,  -- uno中，摸了牌之后可以打出, 也可以选择留着
    WaitChallenge = 18,  -- uno中，上家出了+4牌之后，可以提出质疑
    Response = 19,  -- 玩家响应操作
    ChooseCard = 20,  -- 选择卡牌操作
    ChooseUser = 21,  -- 选择玩家操作
    Oppose = 22,  -- 抵抗操作
    RefuseOppose = 23,  -- 抵消抵抗操作(使用拒绝卡抵抗拒绝不利卡)

    SideShowReq = 24,  -- 请求sideShow状态
    SideShowRes = 25,  -- 响应sideShow状态
    Bet         = 26,  -- 下注阶段
}

PDEFINE.VIPLEVELUP = {
    MIN = 78,
    MAX = 106
}



-- 主线任务
PDEFINE.MAIN_TASK = {
    STATE = {
        Wait = 0,  -- 等待激活
        Doing = 1,  -- 正在进行中
        Done = 2,  -- 已完成
        Complete = 3,  -- 已领取
    },
    KIND = {
        Common = 1,  -- 通用类型，固定显示，且通过其他类型来定位
        BindFB = 2,  -- 绑定fb
        PlayMatchGame = 3, -- 玩匹配游戏
        PlayLeagueGame = 4,  -- 玩排位游戏
        PlayPrivateGame = 5,  -- 玩好友房
        ViewRank = 6,  -- 查看排位赛
        AddFriend = 7, -- 添加好友
        WinMatchGame = 8,  -- 赢取匹配游戏
        GlobalChat = 9,  -- 在世界聊天频道进行发言
        ShareFb = 10,  -- 分享一次fb
        PayDiamond = 12,  -- 购买钻石数量
        VipLevel = 13,  -- 激活vip等级
        LoginDayCnt = 15,  -- 累计登陆天数
        ContinuousLogin = 16,  -- 连续登陆
        LeagueLevel = 18,  -- 排位等级
        MatchGameWinCoin = 20,  -- 匹配游戏赢金币数
        Pay = 11,  -- 充值
        DiamondConvertCoin = 14,  -- 使用钻石换区金币
        OnlineTime = 17,  -- 在线时长
        LeagueLevelCnt = 19,  -- 多少个赛季达到指定段位
        Expression = 21, --交互表情
        GameTimes = 22, --累计游戏次数
        WinCoin = 23, --累计赢得金币
        SalonGames = 24, --在好友房的游戏局数
        SlotsGame = 25, --累计slots游戏
        RP = 26, --累计rp值
        WinGameTimes = 27, --游戏内获胜
        CharmGift = 28, --世界礼物
        DailyTask = 29, --每日任务

        UseDiamond = 30, -- 使用钻石
        MatchGameTime = 31,  -- 匹配游戏时长
        PrivateGameTime = 32,  -- 好友房游戏时长
        BetCoin = 33, --累计下注
    },
    
}
PDEFINE.MAIN_TASK_JUMP = {
    [PDEFINE.MAIN_TASK.KIND.Expression] = 100256,
    [PDEFINE.MAIN_TASK.KIND.GameTimes] = 100256,
    [PDEFINE.MAIN_TASK.KIND.SalonGames] = 2,
    [PDEFINE.MAIN_TASK.KIND.WinCoin] = 100256,
    [PDEFINE.MAIN_TASK.KIND.OnlineTime] = 3,
    [PDEFINE.MAIN_TASK.KIND.SlotsGame] = 4,
    [PDEFINE.MAIN_TASK.KIND.Pay] = 5,
    [PDEFINE.MAIN_TASK.KIND.UseDiamond] = 5,
    [PDEFINE.MAIN_TASK.KIND.RP] = 100256,
    [PDEFINE.MAIN_TASK.KIND.VipLevel] = 5,
    [PDEFINE.MAIN_TASK.KIND.WinGameTimes] = 100256,
    [PDEFINE.MAIN_TASK.KIND.CharmGift] = 6,
    [PDEFINE.MAIN_TASK.KIND.DailyTask] = 7,
    [PDEFINE.MAIN_TASK.KIND.LeagueLevelCnt] = 100256,
}

PDEFINE.CHAT = {}
PDEFINE.CHAT.MsgType = {
    Normal = 1, -- 普通消息
    Emoji = 2, -- 表情 
    VipRoom = 3,  -- 房间邀请
    ClubRoom = 4,  -- 俱乐部房间
    PrivateRoom = 5,  -- 私人房间
    LevelUp = 6, -- 等级提升
    CHARM = 7, --世界礼物，魅力值
}

PDEFINE.GAME = {}
PDEFINE.GAME.DISMISS_DELAY_TIME = 10  -- 解散等待时间

PDEFINE.GAME.DISMISS_STATUS = {
    Waiting = 0,  -- 等级解散
    Agree = 1,  -- 同意解散
    Refuse = 2,  -- 拒绝解散
    Timeout = 3,  -- 超时解散
}




--新手任务和每日任务ID配置
PDEFINE.QUESTID = {
    ['NEW'] = {
        ['LINKFB'] = 130,
        -- ['CHANGEAVATAR'] = 131,
        -- ['CHANGEAVATARFRAME'] = 132,
        -- ['CHANGECHATBOX'] = 133,
        -- ['PROPOSEDGAME '] = 134,
        -- ['RANKEDGAME'] = 135,
        -- ['FRIENDGAME'] = 136,
        -- ['MATCHGAME'] = 137,
        -- ['SPEAKINWORD'] = 138,
        -- ['RATEUS'] = 139,
        ['SENDGIFT'] = 140,
        ['CHANGENICKNAME'] = 141,
        ['CHANGECOUNTRY'] = 142,
        -- ['SHAREFB'] = 143,
        ['PAYMENT'] = 144,
        ['REDEMPOTION'] = 135, --兑换码 改为与10个好友聊天
        ['SHAREWHATAPP'] = 134,
    },
    ['DAILY'] = {
        ['PRIVATEROOM'] = 1, --开1次好友房
        ['EMOJI'] = 2, --游戏内互动表情
        ['GAMESHARE'] = 3, --游戏分享
        ['ONLINE'] = 4, -- 在线1小时
        ['PAYMENT'] = 5, --1次付费
        ['POKERGAME'] = 6, --10局牌类游戏
        ['DOMINOGAME'] = 8, --10局多米诺
    }
}
-- 皮肤道具类型(s_shop_skin)
PDEFINE.SKINKIND = {
    ['FRAME'] = 1, --头像框
    ['CHAT'] = 2, --聊天框
    ['TABLE'] = 3, --牌桌
    ['POKER'] = 4, --牌背
    ['FACE'] = 5, --表情
    ['EMOJI'] = 6,
    ['FRONT'] = 7,
    ['EXPCAT'] = 9, --经验值道具分类id
    ['SALON'] = 10, --沙龙咖啡馆道具
}

--1:头像框，2:聊天边框, 3:牌桌背景, 4:扑克牌背景 5:牌花 6:表情包 7:聊天文字颜色
PDEFINE.SKIN = {
    ['DEFAULT'] = { --默认
        ['AVATAR'] = {img='avatarframe_1000', category=1, title_en='Free', title_al = 'مجانا'}, --头像框
        ['CHAT']  = {img='chat_000', category=2, title_en='Free', title_al ='مجانا'},
        ['TABLE'] = {img='desk_000', category=3, title_en='Free', title_al = 'مجانا'},
        ['POKER'] = {img='poker_free', category=4, title_en='Free', title_al ='مجانا'},
        ['FACE'] = {img='poker_face_000', category=5, title_en='Free', title_al ='مجانا'},
        ['EMOJI'] = {img='emoji_0', category=6, title_en='Free', title_al ='مجانا'},
        ['FRONT'] = {img='font_color_0', category=7, title_en='Free', title_al = 'مجانا'},
        ['SALON'] = {img='coffee_1', category=10, title_en='Free', title_al = 'مجانا'},
    },
    ['UPGRADE'] = { --升级奖励
        ['AVATAR'] = {
            [10] = {img ='avatarframe_1001', category=1, title_en='Unlocked for free when players reach level 10.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 10', lv=10},
            [20] = {img ='avatarframe_1002', category=1, title_en='Unlocked for free when players reach level 20.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 20', lv=20},
            [30] = {img = 'avatarframe_1003', category=1, title_en='Unlocked for free when players reach level 30.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 30', lv=30},
            [40] = {img ='avatarframe_1004', category=1, title_en='Unlocked for free when players reach level 40', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 40', lv=40},
            [50] = {img='avatarframe_2005', category=1, title_en='Unlocked for free when players reach level 50', title_al ='تم فتحه مجانًا عندما يصل اللاعب إلى المستوى 50.', lv=50},
        },
        ['CHAT'] = {
            [10] = {img='chat_001', category=2, title_en='Unlocked for free when players reach level 10.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 10', lv=10},
            [20] = {img='chat_003', category=2, title_en='Unlocked for free when players reach level 20.', title_al = 'يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 20', lv=20},
            [30] = {img='chat_005', category=2, title_en='Unlocked for free when players reach level 30.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 30', lv=30},
            [50] = {img='chat_007', category=2, title_en='Unlocked for free when players reach level 50.', title_al = 'يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 50', lv=50},
        },
        ['TABLE'] = {
            [10] = {img='desk_007', category=3, title_en='Unlocked for free when players reach level 10.', title_al = 'يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 10', lv=10},
            [20] = {img='desk_005', category=3, title_en='Unlocked for free when players reach level 20.', title_al = 'يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 20', lv=20},
        },
        ['FRONT'] = {
            [10] = {img='font_color_2', category=7, title_en='Unlocked for free when players reach level 10.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 10', lv=10},
            [20] = {img='font_color_3', category=7, title_en='Unlocked for free when players reach level 20.', title_al = 'يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 20', lv = 20},
            [30] = {img='font_color_0', category=7, title_en='Unlocked for free when players reach level 30.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 30', lv=30},
            [40] = {img='font_color_1', category=7, title_en='Unlocked for free when players reach level 40.', title_al ='يتم فتحه مجانًا عندما يصل اللاعب إلى المستوى 40', lv=40},
        },
    },
    ['NEWBIE'] = { --新手任务奖励
        ['AVATAR'] = {img='avatarframe_1005', category=1, title_en='Rewards for players to complete novice tasks', title_al ='مكافآت للاعبين لإكمال مهام المبتدئين', questid=1}, --新手任务
        ['CHAT'] = {img='chat_009', category=2, title_en='Rewards for players to complete novice tasks', title_al ='مكافآت للاعبين لإكمال مهام المبتدئين', questid=1}, --新手任务聊天框
        ['POKER'] = {img='poker_006', category=4, title_en='Rewards for players to complete novice tasks', title_al ='مكافآت للاعبين لإكمال مهام المبتدئين', questid=1},

    },
    ['RANKDIAMOND'] = { --所有排行榜的第一名玩家获得
        ['TOP1'] = { --第1名
            ['AVATAR'] = {img='avatarframe_2006', days=7, category=1, title_en='The first player in the weekly leaderboard is rewarded', title_al = 'تتم مكافأة أول لاعب في لوحة الصدارة الأسبوعية' } ,
            ['EMOJI'] = {img='emoji_2', category=6, title_en='The first player in the weekly leaderboard is rewarded', title_al = 'تتم مكافأة أول لاعب في لوحة الصدارة الأسبوعية'}
        },
        ['TOP2'] = { --第2名
            ['AVATAR'] = {img='avatarframe_2007', days=7, category=1, title_en='The second player on the weekly leaderboard is rewarded.', title_al ='تتم مكافأة ثاني لاعب في لوحة الصدارة الأسبوعية'} ,
        },
        ['TOP3'] = { --第3名
            ['AVATAR'] = {img='avatarframe_2008', days=7, category=1, title_en='The third player in the weekly leaderboard is rewarded.', title_al ='تتم مكافأة ثالث لاعب في لوحة الصدارة الأسبوعية'} ,
        }
    },
    ['LEAGUE'] = {
        ['MASTER'] = {img='avatarframe_s_d_1', category=1, title_en='League Master Rank Rewards', title_al ='مكافآت رتبة متميز الدوري'}, --大师
        ['LEGEND'] = {img='avatarframe_s_c_1', category=1, title_en='League Legend Rank Rewards', title_al ='مكافآت رتبة أسطورة الدوري'}, --传奇
        ['TOP1'] = { --第1名
            ['AVATAR'] = {img='avatarframe_s_r_1', category=1, title_en='League leaderboard reward for first place', title_al ='جائزة تصنيف الدوري للمركز الأول'},
        },
        ['TOP2'] = { --第2名
            ['AVATAR'] = {img='avatarframe_s_r_2', category=1, title_en='League leaderboard reward for second place', title_al = 'جائزة تصنيف الدوري للمركز الثاني'},
        },
        ['TOP3'] = { --第3名
            ['AVATAR'] = {img='avatarframe_s_r_3', category=1, title_en='3rd place reward in league leaderboard', title_al ='جائزة تصنيف الدوري للمركز الثالث'},
        }
    },
    ['FBSHARE'] = { --fb分享奖品
        ['AVATAR'] = {img='avatarframe_2002', category=1, title_en='Rewards for completing FB sharing tasks', title_al ='مكافآت لإكمال مهام مشاركة فيسبوك', questid=3},
        ['CHAT'] = {img='chat_006', category=2, title_en='Rewards for completing FB sharing tasks', title_al = 'مكافآت لإكمال مهام مشاركة فيسبوك', questid=3} ,
    },
    ['VIP'] = { --vip(在db中)
        ['AVATAR'] = {
            [1] = {img ='avatarframe_v_0', category=1, title_en='vip1-5', title_al ='vip1-5', lv=1},
            -- [2] = {img ='avatarframe_v_1', category=1, title_en='vip1-5', title_al ='vip1-5'},
            -- [3] = {img = 'avatarframe_v_2', category=1, title_en='vip1-5', title_al ='vip1-5'},
            -- [4] = {img ='avatarframe_v_3', category=1, title_en='vip1-5', title_al ='vip1-5'},
            -- [5] = {img ='avatarframe_v_4', category=1, title_en='vip1-5', title_al ='vip1-5'},
            -- [6] = {img ='avatarframe_v_5', category=1, title_en='vip1-5', title_al ='vip1-5'},
            [6] = {img ='avatarframe_v_6', category=1, title_en='vip6-8', title_al ='vip6-8', lv=6},
            -- [8] = {img ='avatarframe_v_7', category=1, title_en='vip6-8', title_al ='vip6-8'},
            -- [9] = {img ='avatarframe_v_8', category=1, title_en='vip6-8', title_al ='vip6-8'},
            [9] = {img ='avatarframe_v_9', category=1, title_en='vip9-11', title_al ='vip9-11', lv=9},
            -- [11] = {img ='avatarframe_v_10', category=1, title_en='vip9-11', title_al ='vip9-11'},
            -- [12] = {img ='avatarframe_v_11', category=1, title_en='vip9-11', title_al ='vip9-11'},
            [12] = {img ='avatarframe_v_12', category=1, title_en='vip12', title_al ='vip12', lv=12},
            [15] = {img ='avatarframe_2002', category=1, title_en='vip15', title_al ='vip15', lv=15},
            [18] = {img ='avatarframe_2003', category=1, title_en='vip18', title_al ='vip18', lv=18},
            [20] = {img ='avatarframe_2004', category=1, title_en='vip20', title_al ='vip20', lv=20},
        },
        ['CHAT'] = {
            [5] = {img='chat_205', category=2, title_en='vip5', title_al ='vip5', lv=5 },
            [6] = {img='chat_206', category=2, title_en='vip6', title_al ='vip6 ', lv=6},
            [7] = {img='chat_207', category=2, title_en='vip7', title_al ='vip7 ', lv=7},
            [8] = {img='chat_208', category=2, title_en='vip8', title_al ='vip8 ', lv=8},
            [9] = {img='chat_209', category=2, title_en='vip9', title_al ='vip9' , lv=9},
            [10] = {img='chat_210', category=2, title_en='vip10', title_al ='vip10', lv=10 },
            [11] = {img='chat_211', category=2, title_en='vip11', title_al ='vip11', lv=11},
            [12] = {img='chat_212', category=2, title_en='vip12', title_al ='vip12',lv=12 },
            [15] = {img='chat_002', category=2, title_en='vip15', title_al ='vip15',lv=15 },
            [16] = {img='chat_004', category=2, title_en='vip16', title_al ='vip16',lv=16 },
            [18] = {img='chat_006', category=2, title_en='vip18', title_al ='vip18',lv=18 },
            [20] = {img='chat_008', category=2, title_en='vip20', title_al ='vip20',lv=20 },
        },
        ['CHARM'] = { --魅力值道具
            [1] = {img ='gift_cake', category=8, title_en='candy', title_al ='حلوى', times=1}, --VIP1
            [3] = {img ='gift_hookah', category=8, title_en='hookah', title_al ='الشيشة', times=1},
            [4] = {img = 'gift_kiss', category=8, title_en='kiss', title_al ='قبلة', times=1},
            [5] = {img ='gift_cake', category=8, title_en='candy', title_al ='حلوى', times=2},
            [6] = {img ='gift_hookah', category=8, title_en='hookah', title_al ='الشيشة', times=2},
            [8] = {img = 'gift_kiss', category=8, title_en='kiss', title_al ='قبلة', times=2},
            [9] = {img ='gift_ring', category=8, title_en='ring', title_al ='خاتم', times=1},
            [11] = {img ='gift_ring', category=8, title_en='ring', title_al ='خاتم', times=2},
            [12] = {img ='gift_car', category=8, title_en='sports car', title_al ='سيارة سباق ', times=1},
        },
        ['PROP'] = { --交互道具
            [1] = {img ='gift_7', category=8, title_en='candy', title_al ='حلوى'}, --VIP1
            [2] = {img ='gift_7', category=8, title_en='hookah', title_al ='الشيشة'},
            [3] = {img = 'gift_7', category=8, title_en='kiss', title_al ='قبلة'},
            [4] = {img ='gift_7', category=8, title_en='candy', title_al ='حلوى'},
            [5] = {img ='gift_7', category=8, title_en='hookah', title_al ='الشيشة'},
            [6] = {img = 'gift_8', category=8, title_en='kiss', title_al ='قبلة'},
            [7] = {img ='gift_8', category=8, title_en='ring', title_al ='خاتم',},
            [8] = {img ='gift_9', category=8, title_en='ring', title_al ='خاتم',},
            [9] = {img ='gift_9', category=8, title_en='sports car', title_al ='سيارة سباق ',},
            [10] = {img ='gift_10', category=8, title_en='sports car', title_al ='سيارة سباق ',},
            [11] = {img ='gift_10', category=8, title_en='sports car', title_al ='سيارة سباق ',},
            [12] = {img ='gift_11', category=8, title_en='sports car', title_al ='سيارة سباق ',},
            [13] = {img ='gift_12', category=8, title_en='sports car', title_al ='سيارة سباق ',},
        }
    },
    ['TASK_GROUTH'] = { --成长任务
        ['EMOJI'] = {img='emoji_3', category=6, title_en='Rewards for players to complete growth tasks', title_al = 'مكافآت للاعبين لإكمال مهام التقدم', questid=4}
    },
    ['INVITE'] = {
        ['AVATAR'] = {img='avatarframe_2005', category=1, title_en='Unlocked for free when players reach level 50', title_al ='تم فتحه مجانًا عندما يصل اللاعب إلى المستوى 50.'},
    },
    ['SIGN'] = {
        ['AVATAR'] = {img='avatarframe_2004', category=1, title_en='Login for seven days bonus', title_al = 'تسجيل الدخول لمدة سبعة أيام مكافأة', questid=3},
        ['CHAT'] = {img='chat_008', category=2, title_en='Login for seven days bonus', title_al = 'تسجيل الدخول لمدة سبعة أيام مكافأة', questid=3},
    },
    ['CHANGENICK'] = { --改名
        ['AVATAR'] = {img='avatarframe_1002', category=1, title_en='Change name once', title_al = 'غيرت اسمك مرة واحدة', days=3, questid=3},
    },
}

-- 新人魅力值道具礼包
PDEFINE.CHARM_GIFT_PACK = {
    [1] = {
        ['count'] = 100,
        ['type'] = PDEFINE.PROP_ID.COIN,
    },
}

PDEFINE.MONEYBAG = {
    ['MATCH'] = {
        [1] = {entry=2500, addCoin=120000},
        [2] = {entry=10000, addCoin=160000},
        [3] = {entry=50000, addCoin=200000},
        [4] = {entry=500000, addCoin=300000},
    },
    ['VIP'] = {
        [1] = {entry=2500, addCoin=144000},
        [2] = {entry=10000, addCoin=196000},
        [3] = {entry=50000, addCoin=240000},
        [4] = {entry=500000, addCoin=360000},
    }
}

PDEFINE.LEAGUE = {
    ["SEASON_KEY"] = "cur_league_season",
    ["SIGN_UP_KEY"] = "left_league_times:",
    ['PRIZE'] = 50, --报名价格
    ['SEASON'] = { --赛季
        [1] = {
            ['start'] = 1627790400,
            ['stop'] = 1633060800,
        },
        [2] = {
            ['start'] = 1646582400,
            ['stop'] = 1647014400,
        },
        [3] = {
            ['start'] = 1647014401,
            ['stop'] = 1647619200,
        }
    },
    ['HOUR'] = { --每天开启的时间段
        [1] = {
            ['start'] = 12,
            ['stop'] = 14,
        },
        [2] = {
            ['start'] = 20,
            ['stop'] = 23,
        },
    }
}

PDEFINE.LEAGUE.RANK_REWARD = {
    [1] = {{type=PDEFINE.PROP_ID.COIN, count=1000}},
    [2] = {{type=PDEFINE.PROP_ID.COIN, count=5000}, {type=PDEFINE.PROP_ID.DIAMOND, count=50}},
    [3] = {{type=PDEFINE.PROP_ID.COIN, count=10000},{type=PDEFINE.PROP_ID.DIAMOND, count=100}},
    [4] = {{type=PDEFINE.PROP_ID.COIN, count=20000},{type=PDEFINE.PROP_ID.DIAMOND, count=200}},
    [5] = {{type=PDEFINE.PROP_ID.COIN, count=30000},{type=PDEFINE.PROP_ID.DIAMOND, count=400}},
    [6] = {
        {type=PDEFINE.PROP_ID.SKIN_FRAME, img=PDEFINE.SKIN.LEAGUE.MASTER.img, count=1, days=7},
        {type=PDEFINE.PROP_ID.COIN, count=50000},
        {type=PDEFINE.PROP_ID.DIAMOND, count=400}
    },
    [7] = {
        {type=PDEFINE.PROP_ID.SKIN_FRAME, img=PDEFINE.SKIN.LEAGUE.LEGEND.img, count=1, days=7},
        {type=PDEFINE.PROP_ID.COIN, count=100000},
        {type=PDEFINE.PROP_ID.DIAMOND, count=500}
    },
}

PDEFINE.RP = {
    ['TIME'] = { --双倍时间
        ['weekday'] = { --周一到周五
            {
                start = 19,
                stop = 20,
            }
        },
        ['weekend'] = { --周六到周日
            {
                start = 12,
                stop = 13,
            },
            {
                start = 19,
                stop = 20,
            }
        },
    },
}
        -- rp开启时间
-- week 代表星期
-- hour 代表开通的小时
-- reward 代表奖励的数值
PDEFINE.RP_CONFIG = {
    DOUBLE = { --双倍时间
        [1] = {week={1,2,3,4,5}, hour={19}},
        [2] = {week={6,7}, hour={12, 19, 20}},
    },
    REWARD = {
        default = {25,30,40,45,60},     -- 默认配置
        [256] = {60,70,80,90,100},      --baloot
        [257] = {30,35,40,45,50},       --hand
        [258] = {30,35,40,45,50},       --hand saudi
        [259] = {60,70,80,90,100},      --tarneeb
        [260] = {30,35,40,45,50},       --basra
        [261] = {15,20,25},             --banakil
        [262] = {120,135,160,185,200},  --trix
        [263] = {120,135,160,185,200},  --trix friend
        [264] = {40,50,60,70,80},       --estimation
        [265] = {15,20,25},             --domino
        [266] = {30,35,40,45,50},       --koutbo
        [269] = {120,135,160,185,200},  --ludo
        [270] = {120,135,160,185,200},  --tarneeb syrian
        [271] = {60,70,80,90,100},      --leekha
        [272] = {120,135,160,185,200},  --tarneeb 400
        [273] = {120,135,160,185,200},  --trix complex
        [279] = {15,20,25},             --bint al sheet
        [280] = {120,135,160,185,200},  --complex friend
        [281] = {60,70,80,90,100},      --cpmplex cc
        [282] = {40,50,60,70,80},       --cc friend
        [283] = {40,50,60,70,80},       --concan
        [284] = {120,135,160,185,200},  --kasra
        [285] = {60,70,80,90,100},      --kasra partner
        [286] = {15,20,25},             --ronda
        [287] = {30,35,40,45,50},       --uno
        [289] = {15,20,25},             --baloot fast
        [290] = {40,50,60,70,80},       --ludo quick
    }
}

PDEFINE.SHOP_SEND = {
    ['diamond'] = 50,
    ['coin'] = 10000
}

PDEFINE.NEWBIE_QUEST = {
    [1] = {id = 1, img = PDEFINE.SKIN.NEWBIE.CHAT.img, times=0, max=2, days=5, state=0, type=PDEFINE.PROP_ID.SKIN_CHAT, category=2},
    [2] = {id = 2, times=0, max=2, days=3, level=3, state=0, type=PDEFINE.PROP_ID.TEMP_VIP_LEVEL, category=4},
    [3] = {id = 3, img = PDEFINE.SKIN.NEWBIE.AVATAR.img, times=0, max=3, days=5, state=0, type=PDEFINE.PROP_ID.SKIN_FRAME, category=1},
}

PDEFINE.SWITCH = {
    ['REDEMPTION'] = 0, --兑换码 0:关闭 1:开启
    ['SEND'] = 0,
    ['REPORT'] = 0,
}

PDEFINE.ROBOT = {
    ['REMAINTIME'] = {120, 720},        --随机离桌时间
    ['DROP_LEAVE_ROOM_PROB'] = 0.05,     --弃牌后离桌的概率
}

PDEFINE.SHARE = {
    ['TYPE'] = {
        ['TOTAL'] = 1,
        ['CONT'] = 2,
        ['SPECIAL'] = 3,
    },
    ["WINTIMES"] = {  --倍数配置
        ["TOTAL"] = {
            ["KEYS"]  = {5, 8, 12, 16, 20},
            ["TIMES"] = {2, 3,  4,  5,  6},
        },
        ["CONT"] = {
            ["KEYS"] = {3},
            ["TIMES"] = {2}
        }
    }
}

PDEFINE.PLATFORM = {
    ['Android'] = 1,
    ['IOS'] = 2,
    ['WEB'] = 3,
}

PDEFINE.APPS = {
    ['URLS'] = {
        ['DEFAULT'] = { -- cards master ios & android
            ['www'] = 'https://yonogames.com', --官网
            ["fbshare"] = 'https://download.yonogames.com/',
            ["whatapp"] = 'https://wa.me/message/YK2DR45JCJBDO1', --whatapp
            ["adtime"] = {
                ['start'] = 1642464000,
                ['end'] = 1650326400,
                ['url'] = 'https://www.instagram.com/poker_hero_game/',
                ['open'] = 0, --1显示 0关闭
            },--广告活动链接
            --['upload'] = 'https://img.yonogames.com', --头像上传地址
            ['upload'] = 'http://192.168.0.72:8856', --头像上传地址
            ['contactus'] = 'https://vm.providesupport.com/04qetijpc30hp11ayhbj2xfvh4', --客服
            --['payurl'] = 'http://103.42.30.70/#/pages/deposit/add/add', --支付网关地址
            ['payurl'] = 'http://192.168.0.72/#/pages/deposit/add/add', --支付网关地址
            --['kyc'] = 'https://pay.yonogames.com/#/pages/audit/apply/apply', --kyc验证地址
            ['kyc'] = 'http://192.168.0.72/#/pages/audit/apply/apply', --kyc验证地址
            --['draw'] = 'https://pay.yonogames.com/#/pages/withdraw/index',
            ['draw'] = 'http://192.168.0.72/#/pages/withdraw/index',
            --['transaction'] = 'https://pay.yonogames.com/#/pages/transaction/transaction',
            ['transaction'] = 'http://192.168.0.72/#/pages/transaction/transaction',
            --['payment'] = 'https://pay.yonogames.com/#/pages/deposit/managepayment/managepayment',
            ['payment'] = 'http://192.168.0.72/#/pages/deposit/managepayment/managepayment',
        },
        -- Yono Games
        [17] = {
            ['www'] = 'https://yonogames.com', --官网
            ["fbshare"] = 'https://download.yonogames.com/',
            --['upload'] = 'https://img.yonogames.com', --头像上传地址
            ['upload'] = 'http://192.168.0.72:8856', --头像上传地址
            ['contactus'] = 'https://vm.providesupport.com/04qetijpc30hp11ayhbj2xfvh4', --客服
            --['payurl'] = 'http://103.42.30.70/#/pages/deposit/add/add', --支付网关地址
            ['payurl'] = 'http://192.168.0.72/#/pages/deposit/add/add', --支付网关地址
            --['kyc'] = 'https://pay.yonogames.com/#/pages/audit/apply/apply', --kyc验证地址
            ['kyc'] = 'http://192.168.0.72/#/pages/audit/apply/apply', --kyc验证地址
            --['draw'] = 'https://pay.yonogames.com/#/pages/withdraw/index',
            ['draw'] = 'http://192.168.0.72/#/pages/withdraw/index',
            --['transaction'] = 'https://pay.yonogames.com/#/pages/transaction/transaction',
            ['transaction'] = 'http://192.168.0.72/#/pages/transaction/transaction',
            --['payment'] = 'https://pay.yonogames.com/#/pages/deposit/managepayment/managepayment',
            ['payment'] = 'http://192.168.0.72/#/pages/deposit/managepayment/managepayment',
            ['mailsender'] = 'Yono Games',
        },
        -- Rummy Vip
        [19] = {
            ['www'] = 'https://rummyvip.com', --官网
            ["fbshare"] = 'https://download.rummyvip.com/',
            ['upload'] = 'https://img.rummyvip.com', --头像上传地址
            ['contactus'] = 'http://rummyvipkf.com', --客服
            ['payurl'] = 'https://pay.rummyvip.com/#/pages/deposit/add/add', --支付网关地址
            ['kyc'] = 'https://pay.rummyvip.com/#/pages/audit/apply/apply', --kyc验证地址
            ['draw'] = 'https://pay.rummyvip.com/#/pages/withdraw/index',
            ['transaction'] = 'https://pay.rummyvip.com/#/pages/transaction/transaction',
            ['payment'] = 'https://pay.rummyvip.com/#/pages/deposit/managepayment/managepayment',
            ['mailsender'] = 'RummyVIP',
        },

    }
}

PDEFINE.RACE_TYPE = {
    GODOWN_CARD_COUNT = 1,  -- godown 牌数量
    DOMINO_WIN_COUNT = 2,  -- domino赢取次数
    ROUND_SCORE = 3,  -- 小局分数
    ROUND_WIN_COUNT = 4,  -- 小局赢取次数
    BALOOT_COMPARE_WIN = 5,  -- baloot 比牌胜率次数
    PAIR_CARD_COUNT = 6,  -- 对子牌型的数量
}

PDEFINE.BANKRUPT = {
    TIMES = 0, --3, --每天可领取破产补助次数
    COIN = 0, --20000, 
}

PDEFINE.TYPE = {
    SOURCE = {
        REG = 1 , --下级注册
        BUY = 2, --下级充值
        BET = 3, --下级下注
        QUEST = 4, --任务奖励
        VIP = 5, --vip 升级
        Transfer = 6, --转出
        Mail = 7, --邮件奖励
        Admin = 8, --管理员操作
        VIP_WEEK = 9, --VIP周bonus
        VIP_MONTH = 10, --VIP月bonus
        QUEST_RECHARGE = 11, --充值任务
        BUY_SELF = 12, --自己充值
        QUEST_GAMES = 22, --游戏任务
        QUEST_WINCOIN = 23, --盈利任务
        QUEST_BET = 33, --下注任务
        Transfer_Cash = 34, --转出到现金钱包
        Sign = 35, --签到
        Share = 36, --分享转盘
        Rebate = 37, --返水
        Salon = 38, --沙龙
        FREE_WINNING = 39 , --Free Winnings transfer in
        DRAW_BONUS2CASH = 40, --会员首次提现余额转出
    },
    DRAW = { --提现类型
        REG = 1, --注册
        BUY = 2,  --购买
        VIP = 3, --vip
    },
    TASK = { --vip升级奖励任务
        SIGN = 1, --签到
        WEEK = 2, --周
        MONTH = 3 , --月
        UPGRADE = 4, --升级
    },
    COIN = {
        CASH = 1, --现金钱包
        DRAW = 2, --提现钱包
        BONUS = 3 , --奖金钱包
    }
}

PDEFINE.LEADER_BOARD = {
    TYPE = {
        DAY = 1,  -- 日榜
        WEEK = 2,  -- 周榜
        MONTH = 3,  -- 月榜
        REFERRALS = 4,  -- 代理榜
    }
}

PDEFINE.TOURNAMENT = {
    DESK_STATE = {
        WAIT_REGISTER = 1,  -- 等待报名
        WAIT_JOIN = 2,  -- 等待加入
        ONGOING = 3, -- 正在游戏
        COMPLETED = 4,  -- 已结束
        CANCEL = 5,  -- 人数不够，取消
    },
    PLAYER_STATE = {
        NO_ENTER = 1,  -- 未进入
        PLAYING = 2,  -- 正在游戏
        OUT = 3, -- 已淘汰
    }
}

-- 红点系统列表
PDEFINE.REDDOT = {
   MAIL_NOTICE = 'mail_notify', --通知邮件数
   MAIL_GIFT = 'mail_gift', --礼物邮件数 
   MAIL_ACTIVITY = 'mail_activity', --活动邮件数
   SOCIAL = 'social', --今日聊天
   FRIEND = 'friend', --请求加好友数
   DAILY = 'daily', --每日任务数
   DAILYGET = 'dailyGet', --
   VIPBONUS = 'vipbonus', --vip可领bonus
   FREEDIAMOND = 'freediamond', --商城免费钻石
   FREECOIN = 'freecoin', --商城免费金币
   INVITE = 'invite', --累计邀请好友的奖励是否可以领取
   FALL = 'fall', --沙龙房红点
   MAINTASK = 'maintask', --主线任务
   GETVIPLV = 'getviplv', --是否有vip道具可以领取
   FBSHARE = 'fbshare', --今日是否已分享完成
   RAKEBACK = 'rakeback', --下注返利的领取红点
   BONUSWHEEL = 'bonuswheel', --金转盘可转次数
   FBINVITE = 'fbinvite', --邀请码被绑定奖励是否领取
   PASS = 'pass', --通行证是否有可领取任务
   NOVICE = 'novice', --新手任务
   PROOM = 'proom', --私人房上创建按钮
   SALON = 'salon', --沙龙
   SALONP = 'salonp',
   SALONCOIN = 'saloncoin',
   SIGN = 'sign', --是否签到
   TRUNSBONUS = 'transbonus', --可转移金额红点
   TURNTABLE = 'turntable', --是否可以领取在线转盘类奖励
}

-- 被屏蔽的错误码
PDEFINE.LOGIN_ERROR = {
    VERSION = 1, --版本号
    EMPTY_PHONE_OR_DEVICE = 2, --型号或设备号为空
    DEVICE = 3, --设备号
    PHONE = 4, --手机型号
    OPTCODE = 5,  --手机号验证码不对
    NOTOK = 6, --auth返回第1个参数为false
    NOTSUCC = 7, --返回code不为200
    OPTCODEFail = 8,  --手机号验证码不对
}

PDEFINE.DISCOUNTLABEL = {
    RECHARGE = 1, --充值优惠
    AGENT = 2 , --代理返现优惠
    BET = 3, --下注返水
}
