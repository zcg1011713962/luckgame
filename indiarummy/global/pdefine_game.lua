PDEFINE_GAME = {}

PDEFINE_GAME.GAME_TYPE = 
{
    ["SPECIAL"] = 
    {
        ["UP_COIN"] = 10000,--下分
        ["DOWN_COIN"] = 20000,--下分
        ["PLATFORM_EVO"]= 30000, --evo平台对应gameid
        ["STORE_BUY"] = 40000, --商城购买
        ["STORE_SEND"] = 41000, --商城赠送
        ["BIGBANG"] = 50000, --BIGBANG
        ["REDBAG"] = 60000, --REDBAG
        ["UPGRADEAWARD"] = 80000, --升级奖励
        ["LUCK_TURNTABLE"] = 70000, --BB幸运转盘
        ["LUACK_REDBAG"] = 90000, -- 幸运红包
        ["RAIN_REDBAG"] = 100000, -- 红包雨
        ["GROW_BOX"] = 110000, -- 成长系统的宝箱
        ["ONLINE_REAWARD"] = 120000, --在线奖励
        ["ONLINE_GUAGUALE"] = 120100, --在线奖励刮刮乐
        ["REGISTERAWARD"] =  130000, --玩家注册奖励
        ["TURNTABLE"] =  140000, --玩家转盘奖励
        ["MAILATTACH"] =  150000, --邮件附件
        ["QUEST"] =  160000, --任务奖励
        ["TAG_REAWARD"] = 170000, --标签页奖励
        ["STAMPSHOP"] =  180000, --集邮商城奖励
        ["STAMPREWARD"] =  180001, --集邮奖励
        ["MISSONPASS"] =  185000, --mission奖励
        ["FRIENDS"] =  186000, -- 好友系统领取
        ["FUND"] =  187000, -- 基金赠送
        ["FBSHARE"] = 188000, --fb分享
        ["FBSHARE_FRIENDS"] = 188001, --fb分享，好友列表
        ["FBSHARE_DOUBLE_WIN"] = 188002, --bigwin分享翻倍
        ["OFFLINEAWARDS"] = 189000, --离线收益
        ["BANKRUPT"] =  190000, --破产补助
        ["ACTIVITY"] = 191000,  -- 活跃度奖励
        ["CARDWEEK"] = 192000,  -- 周卡
        ["CARDMONTH"] = 193000,  -- 月卡
        ["FREE_PIGGY"] = 194000, -- 免费金猪
        ["HEROCARD"] = 195000, -- 英雄卡牌
        ["EGG_SILVER"] = 196000,  -- 银蛋奖励
        ["EGG_GOLD"] = 197000,  -- 金蛋奖励
        ["CARD_LOTTERY"] = 195100, --卡牌抽卡
        ["DAILYBONUS"] = 195200, --daily bonus 签到 
        ["PHIZ"] = 188003, --游戏内道具
        ["PRIVATE_ROOM_COIN"] = 188004, --好友房抽水
        ["DRAW_COIN"] = 188005, --draw coin
        ["VIP_REWARDS"] = 188006,
        ['DRAW_RETURN'] = 188007, --拒绝提现
        ['FREE_WINNS2BONUS'] = 188008, --转移到bonus中
        ['BONUS2BALANCE'] = 188009, --bonus转移到balance中
    },

    ["ANDAR_BAHAR"] = 11,   -- Andar Bahar
    ["CRASH"] = 12,     --Crash
    ["JHANDI_MUNDA"] = 13, -- Jhandi Munda
    ["HORSE_RACING"] = 14,  -- 赛马
    ["WINGO_LOTTERY"] = 15, -- Wingo Lottery
    ["FORTUNE_WHEEL"] = 16, -- Fortune Wheel
    ["DRAGON_VS_TIGER"] = 17, -- 龙虎斗
    ["ROULETTE"] = 18, -- 俄罗斯轮盘
    ["BACCARAT"] = 19, -- 百家乐
    ["SEVEN_UP_DOWN"] = 20, -- 7 Up Down
    ["ALADDIN_WHEEL"] = 21, -- 阿拉丁转盘游戏
    ["AVIATOR"] = 22,       --Aviator 飞行员
    ["AVIATRIX"] = 23,      --Aviatrix 飞行员X
    ["CRASHX"] = 24,    --CrashX
    ["CRICKETX"] = 25,  --CricketX 棒球X
    ["JETX"] = 26,      --JetX  喷气式飞机X
    ["ZEPPELIN"] = 27,  --Zeppelin 齐柏林飞艇
    ["DICE"] = 28,  --Dice 骰子
    ["LIMBO"] = 29, --Limbo 赛车
    ["PLINKO"] = 30,    --Plinko 弹珠
    ["KENO"] = 31,  --Keno 基诺
    ["MINES"] = 32, --Mines 扫雷
    ["HILO"] = 33,  --Hilo 希洛
    ["TOWERS"] = 34,    --Towers 爬塔
    ["DOUBLE_ROLL"] = 35,    --Double Roll 双辊
    ["COINS"] = 36, --Coins 猜硬币
    ["CRYPTO"] = 37,    --Crypto 宝石
    ["TRIPLE"] = 38,    --Triple 三倍

    ["JACKPOT_FISH"] = 81,  --彩金捕鱼
    ["MEGA_FISH"] = 82,     --王者捕鱼

    ["BLACK_JACK"] = 255, -- 21点
    ["BALOOT"] = 256, --boloot
    ["HAND"] = 257, -- hand
    ["HAND_SAUDI"] = 258, -- hand沙特
    ["TARNEEB"] = 259,  -- tarneeb
    ["BASRA"] = 260,  -- basra
    ["BANAKIL"] = 261,  -- banakil
    ["TRIX"] = 262,  -- trix
    ["TRIX_FRIEND"] = 263,  -- trix 双人玩法
    ["ESTIMATION"] = 264,  -- estimation 玩法
    ["DOMINO"] = 265,  -- domino 玩法
    ["KOUTBO"] = 266,  -- koutbo 玩法
    ["HAND_PARTNER"] = 267,  -- hand 组队玩法，mesa占用
    ["HAND_SAUDI_PARTNER"] = 268, -- hand沙特组队玩法 mesa占用
    ["LUDO"] = 269, --ludo
    ["TARNEEB_SYRIAN"] = 270,  -- tarneeb syrian
    ["LEEKHA"] = 271,   -- leekha
    ["TARNEEB_400"] = 272,  -- tarneeb 400
    ["TRIX_COMPLEX"] = 273,  -- trix Complex
    ["DURAK_X2"] = 274, -- durak 2人
    ["DURAK_X3"] = 275, -- durak 3人
    ["DURAK_X4"] = 276, -- durak 4人
    ["DURAK_X5"] = 277, -- durak 5人
    ["DURAK_X6"] = 278, -- durak 6人
    ["BINT_AL_SHEET"] = 279,  -- bint al sheet
    ["COMPLEX_FRIEND"] = 280,  -- Complex 双人玩法
    ["COMPLEX_CC"] = 281,  -- Complex cc 玩法
    ["CC_FRIEND"] = 282,  -- cc 双人玩法
    ["CONCAN"] = 283,  -- concan 玩法
    ["KASRA"] = 284,  -- kasra 玩法
    ["KASRA_PARTNER"] = 285,  -- kasra 组队玩法
    ["RONDA"] = 286,  -- ronda 玩法
    ["UNO"] = 287,  -- uno 个人
    ["SAUDIDEAL"] = 288,  -- saudideal
    ["BALOOT_FAST"] = 289, -- baloot fast (一局玩法)
    ["LUDO_QUICK"] = 290, -- LUDO Quick (玩法)

    ["TEENPATTI"] = 291,    -- Teenpatti
    ["INDIA_RUMMY"] = 292,  -- 印度拉米
    ["TEXAS_HOLDEM"] = 293, -- 德州扑克
}

-- 开启的游戏，供后台接口使用
PDEFINE_GAME.OPEN = {
    ["BLACK_JACK"] = 255, -- 21点
    ["BALOOT"] = 256, --boloot
    ["HAND"] = 257, -- hand
    ["HAND_SAUDI"] = 258, -- hand沙特
    ["TARNEEB"] = 259,  -- tarneeb
    ["BASRA"] = 260,  -- basra
    ["BANAKIL"] = 261,  -- banakil
    ["TRIX"] = 262,  -- trix
    ["TRIX_FRIEND"] = 263,  -- trix 双人玩法
    ["ESTIMATION"] = 264,  -- estimation 玩法
    ["DOMINO"] = 265,  -- domino 玩法
    ["KOUTBO"] = 266,  -- koutbo 玩法
    ["HAND_PARTNER"] = 267,  -- hand 组队玩法，mesa占用
    ["HAND_SAUDI_PARTNER"] = 268, -- hand沙特组队玩法 mesa占用
    ["LUDO"] = 269, --ludo
    ["TARNEEB_SYRIAN"] = 270,  -- tarneeb syrian
    ["LEEKHA"] = 271,   -- leekha
    ["TARNEEB_400"] = 272,  -- tarneeb 400
    ["TRIX_COMPLEX"] = 273,  -- trix Complex
    ["BINT_AL_SHEET"] = 279,  -- bint al sheet
    ["COMPLEX_FRIEND"] = 280,  -- Complex 双人玩法
    ["COMPLEX_CC"] = 281,  -- Complex cc 玩法
    ["CC_FRIEND"] = 282,  -- cc 双人玩法
    ["CONCAN"] = 283,  -- concan 玩法
    ["KASRA"] = 284,  -- kasra 玩法
    ["KASRA_PARTNER"] = 285,  -- kasra 组队玩法
    ["RONDA"] = 286,  -- ronda 玩法
    ["UNO"] = 287,  -- uno 个人
    ["BALOOT_FAST"] = 289,  -- Baloot Fast 个人
    ["LUDO_QUICK"] = 290,  -- Ludo Quick 个人
    ["INDIA_RUMMY"] = 292,  -- rumy
}

-- 好友房自动解散时间
PDEFINE_GAME.AUTO_DISMISS_TIME = 5*60  -- 5分钟

-- 好友房人满后自动踢人时间
PDEFINE_GAME.AUTO_KICK_OUT_TIME = 30

-- 是否自动加入机器人
PDEFINE_GAME.AUTO_JOIN_ROBOT = false

-- 观战人数限制
PDEFINE_GAME.MAX_VIEW_NUM = 20

-- (德州，teenpatti)托管多少次踢掉
PDEFINE_GAME.MAX_AUTO_CNT = 1

-- 设置置顶的游戏列表
PDEFINE_GAME.PIN_GAME_LIST = {

}

-- 设置游戏的难度比例 0-1
PDEFINE_GAME.GAME_CLEVER = {
    UNO = 0.2,  -- 玩家上家出现黑牌的几率
}

-- 设置初始化的游戏列表
PDEFINE_GAME.F_GAME_LIST = {
    PDEFINE_GAME.GAME_TYPE.DOMINO,
}

-- 存放游戏对应的名称以及阿拉伯语名称
-- 走马灯需要调用这个表，所以每个需要走马灯的游戏都需要加入到这个表中
PDEFINE_GAME.GAME_NAME = {
    [PDEFINE_GAME.GAME_TYPE.DOMINO]             = {en='Domino', al='دومينو'},
    [PDEFINE_GAME.GAME_TYPE.UNO]                = {en='Uno', al='أونو'},
    [PDEFINE_GAME.GAME_TYPE.LUDO]               = {en='Ludo', al='لودو'},
    [PDEFINE_GAME.GAME_TYPE.TEENPATTI]          = {en='Teenpatti', al='تينباتي'},
    [PDEFINE_GAME.GAME_TYPE.TEXAS_HOLDEM]       = {en='Poker', al='تكساس هولدم بوكر'},
    [11] =          {en='AndarBahar', ar='AndarBahar'},
    [12] =          {en='Crash', ar='Crash'},
    [13] =          {en='JhandiMunda', ar='JhandiMunda'},
    [14] =          {en='HorseRacing', ar='HorseRacing'},
    [15] =          {en='WingoLottery', ar='WingoLottery'},
    [16] =          {en='FortuneWheel', ar='FortuneWheel'},
    [17] =          {en='DragonVsTiger', ar='DragonVsTiger'},
    [18] =          {en='Roulette', ar='Roulette'},
    [19] =          {en='Baccarat', ar='Baccarat'},
    [20] =          {en='SevenUpDown', ar='SevenUpDown'},
    [21] =          {en='AladdinsBlessing', ar='AladdinsBlessing'},
    [22] =          {en='Aviator', ar='Aviator'},
    [23] =          {en='Aviatrix', ar='Aviatrix'},
    [24] =          {en='CrashX', ar='CrashX'},
    [25] =          {en='CricketX', ar='CricketX'},
    [26] =          {en='JetX', ar='JetX'},
    [27] =          {en='Zeppelin', ar='Zeppelin'},
    [81] =          {en='JackpotFishing', ar='JackpotFishing'},
    [82] =          {en='MegaFishing', ar='MegaFishing'},
    [255] =          {en='BlackJack', ar='BlackJack'},
    [292] =          {en='Rummy', ar='Rummy'},
    [419] =          {en='RegalTiger', ar='RegalTiger'},
    [541] =          {en='PowerOfTheKraken', ar='PowerOfTheKraken'},
    [635] =          {en='TheLegendOfDragon', ar='TheLegendOfDragon'},
    [691] =          {en='PrinceOfPersia', ar='PrinceOfPersia'},
    [692] =          {en='Archer', ar='Archer'},
    [693] =          {en='Alibaba', ar='Alibaba'},
    [694] =          {en='Xerxes', ar='Xerxes'},
    [695] =          {en='HangingGarden', ar='HangingGarden'},
    [696] =          {en='Sinbad', ar='Sinbad'},
    [697] =          {en='GorgeousCleopatra', ar='GorgeousCleopatra'},
    [698] =          {en='LampOfAladdin', ar='LampOfAladdin'},
    [699] =          {en='Sphinx', ar='Sphinx'},
}

--游戏名缩写
PDEFINE_GAME.GAME_SHORT_NAME = {
    [PDEFINE_GAME.GAME_TYPE.ANDAR_BAHAR] = 'AB',   -- Andar Bahar
    [PDEFINE_GAME.GAME_TYPE.CRASH] = 'CS',     --Crash
    [PDEFINE_GAME.GAME_TYPE.JHANDI_MUNDA] = 'JM', -- Jhandi Munda
    [PDEFINE_GAME.GAME_TYPE.HORSE_RACING] = 'HR',  -- 赛马
    [PDEFINE_GAME.GAME_TYPE.WINGO_LOTTERY] = 'WL', -- Wingo Lottery
    [PDEFINE_GAME.GAME_TYPE.FORTUNE_WHEEL] = 'FW', -- Fortune Wheel
    [PDEFINE_GAME.GAME_TYPE.DRAGON_VS_TIGER] = 'DT', -- 龙虎斗
    [PDEFINE_GAME.GAME_TYPE.ROULETTE] = 'RT', -- 俄罗斯轮盘
    [PDEFINE_GAME.GAME_TYPE.BACCARAT] = 'BC', -- 百家乐
    [PDEFINE_GAME.GAME_TYPE.SEVEN_UP_DOWN] = 'UD', -- 7 Up Down
    [PDEFINE_GAME.GAME_TYPE.ALADDIN_WHEEL] = 'AW', -- 阿拉丁转盘游戏
    [PDEFINE_GAME.GAME_TYPE.AVIATOR] = 'AV',    --女飞行员
    [PDEFINE_GAME.GAME_TYPE.AVIATRIX] = 'AX',   --飞行员
    [PDEFINE_GAME.GAME_TYPE.CRASHX] = 'CX',     -- CrashX
    [PDEFINE_GAME.GAME_TYPE.CRICKETX] = 'CK',   --棒球X
    [PDEFINE_GAME.GAME_TYPE.JETX] = 'JX',       -- 喷气式飞机X
    [PDEFINE_GAME.GAME_TYPE.ZEPPELIN] = 'ZP',   --齐柏林飞艇
    [PDEFINE_GAME.GAME_TYPE.DICE] = "DC",  --Dice 骰子
    [PDEFINE_GAME.GAME_TYPE.LIMBO] = "LB", --Limbo 赛车
    [PDEFINE_GAME.GAME_TYPE.PLINKO] = "PL",    --Plinko 弹珠
    [PDEFINE_GAME.GAME_TYPE.KENO] = "KN",  --Keno 基诺
    [PDEFINE_GAME.GAME_TYPE.MINES] = "MN", --Mines 扫雷
    [PDEFINE_GAME.GAME_TYPE.HILO] = "HL",  --Hilo 希洛
    [PDEFINE_GAME.GAME_TYPE.TOWERS] = "TW",    --Towers 爬塔
    [PDEFINE_GAME.GAME_TYPE.DOUBLE_ROLL] = "DR",    --Double Roll 双辊
    [PDEFINE_GAME.GAME_TYPE.COINS] = "CO", --Coins 猜硬币
    [PDEFINE_GAME.GAME_TYPE.CRYPTO] = "CR",    --Crypto 宝石
    [PDEFINE_GAME.GAME_TYPE.TRIPLE] = "TR",    --Triple 三倍
    [PDEFINE_GAME.GAME_TYPE.JACKPOT_FISH] = 'JF', -- 彩金捕鱼
    [PDEFINE_GAME.GAME_TYPE.MEGA_FISH] = 'MF', -- 王者捕鱼
    [PDEFINE_GAME.GAME_TYPE.BLACK_JACK] = 'BJ', -- 21点
    [PDEFINE_GAME.GAME_TYPE.DOMINO] = 'DO',  -- domino 玩法
    [PDEFINE_GAME.GAME_TYPE.LUDO] = 'LD', --ludo
    [PDEFINE_GAME.GAME_TYPE.UNO] = 'UN',  -- uno 个人
    [PDEFINE_GAME.GAME_TYPE.TEENPATTI] = 'TP',    -- Teenpatti
    [PDEFINE_GAME.GAME_TYPE.INDIA_RUMMY] = 'RM',  -- 印度拉米
    [PDEFINE_GAME.GAME_TYPE.TEXAS_HOLDEM] = 'PK', -- 德州扑克

    [419] = 'TG', --老虎
    [541] = 'KK', --克拉肯之力
    [635] = 'DG', --龙的传说 The Legend of Dragon
    [691] = 'PP', --波斯王子
    [692] = 'AC', -- 弓箭手
    [693] = 'AL', -- 阿里巴巴四十大盗
    [694] = 'XE', -- 薛西斯
    [695] = 'NB', -- 尼布甲尼撒二世和空中花园
    [696] = 'SB', -- 辛巴达航海冒险
    [697] = 'GC', -- 绚丽的埃及艳后  Gorgeous Cleopatra
    [698] = 'LA', -- 阿拉丁神灯 Lamp of Aladdin
    [699] = 'SP', -- 狮身人面像 Sphinx
}

--游戏类型
PDEFINE_GAME.KIND = 
{
    ["FIGHT"] = "FIGHT", --对战
    ["BET"]   = "BET", --下注类  百人场
    ["ALONE"]   = "ALONE", --单击
}

--游戏匹配接口
PDEFINE_GAME.MATCH = 
{
    ["FIGHT"] = "matchFight", --对战
    ["BET"]   = "matchBet", --下注类  百人场
    ["ALONE"]   = "matchAlone", --单击
}

--游戏类型ID 以及需要创建的个数
--ID 游戏ID
--COUNT 创建的agent数量 百人场目前配置一个就行
--MATCH 0直接创建新房间(单机类) 1匹配规则(对战类) 2百人场(百人场)

--['YONOGAMES'] = 17, --YD: Yono Games
--['RUMMYVIP'] = 19,  --YD: Rummy Vip
local YD_GAME_LIST = {
    [11] = { --andar bahar
        ID = 11,
        COUNT = 1,
        STATE = 1,
        AGENT = "andarbaharagent",
        MATCH = "BET",
    },
    [12] = { --crash
        ID = 12,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashagent",
        MATCH = "BET",
    },
    [13] = { --jhandi munda
        ID = 13,
        COUNT = 1,
        STATE = 1,
        AGENT = "jhandimundaagent",
        MATCH = "BET",
    },
    [14] = { --赛马
        ID = 14,
        COUNT = 1,
        STATE = 1,
        AGENT = "horseagent",
        MATCH = "BET",
    },
    [15] = {--wingolottery
        ID = 15,
        COUNT = 1,
        STATE = 1,
        AGENT = "wingolotteryagent",
        MATCH = "BET",
    },
    [16] = { --fortune wheel
        ID = 16,
        COUNT = 1,
        STATE = 1,
        AGENT = "fortunewheelagent",
        MATCH = "BET",
    },
    [17] = {--龙虎斗
        ID = 17,
        COUNT = 1,
        STATE = 1,
        AGENT = "dragonvstigeragent",
        MATCH = "BET",
    },
    [18] = {--轮盘
        ID = 18,
        COUNT = 1,
        STATE = 1,
        AGENT = "rouletteagent",
        MATCH = "BET",
    },
    [19] = {--百家乐
        ID = 19,
        COUNT = 1,
        STATE = 1,
        AGENT = "baccaratagent",
        MATCH = "BET",
    },
    [20] = {--7 up down
        ID = 20,
        COUNT = 1,
        STATE = 1,
        AGENT = "sevenupdownagent",
        MATCH = "BET",
    },
    [21] = {--阿拉丁转盘
        ID = 21,
        COUNT = 1,
        STATE = 1,
        AGENT = "aladdinwheelagent",
        MATCH = "BET",
    },
    [22] = {--飞行员
        ID = 22,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashxagent",
        MATCH = "BET",
    },
    [23] = {--飞行员X
        ID = 23,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashxagent",
        MATCH = "BET",
    },
    [24] = {--Crash X
        ID = 24,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashxagent",
        MATCH = "BET",
    },
    [25] = {--板球X
        ID = 25,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashxagent",
        MATCH = "BET",
    },
    [26] = {--喷气式飞机X
        ID = 26,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashxagent",
        MATCH = "BET",
    },
    [27] = {--齐柏林飞艇
        ID = 27,
        COUNT = 1,
        STATE = 1,
        AGENT = "crashxagent",
        MATCH = "BET",
    },
    [28] = {  --Dice
        ID = 28,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [29] = {  --Limbo
        ID = 29,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [30] = {  --Plinko
        ID = 30,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [31] = { --Keno
        ID = 31,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [32] = {  -- Mines
        ID = 32,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [33] = {  -- Hilo
        ID = 33,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [34] = {  -- Towers
        ID = 34,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [35] = {  -- 35
        ID = 35,
        COUNT = 1,
        STATE = 1,
        AGENT = "doublerollagent",
        MATCH = "BET",
    },
    [36] = {  -- Coins
        ID = 36,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [37] = {  -- Crypto
        ID = 37,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [38] = {  -- Triple
        ID = 38,
        COUNT = 1,
        STATE = 1,
        AGENT = "standaloneagent",
        MATCH = "BET",
    },
    [81] = {    --彩金捕鱼
        ID = 81,
        COUNT = 10,
        STATE = 0,
        AGENT = "fishagent",
        MATCH = "FIGHT",
        SEAT = 4,
    },
    [82] = {    --王者捕鱼
        ID = 82,
        COUNT = 10,
        STATE = 0,
        AGENT = "fishagent",
        MATCH = "FIGHT",
        SEAT = 4,
    },
    [419] = {
        ID = 419,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [541] = {
        ID = 541,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [635] = {
        ID = 635,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [691] = {
        ID = 691,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [692] = {
        ID = 692,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [693] = {
        ID = 693,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [694] = {
        ID = 694,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [695] = {
        ID = 695,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [696] = {
        ID = 696,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [697] = {
        ID = 697,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [698] = {
        ID = 698,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [699] = {
        ID = 699,
        COUNT = 10,
        STATE = 1,
        AGENT = "slotsagent",
        MATCH = "ALONE",
    },
    [255] = {
        ID = 255,
        COUNT = 10,
        STATE = 1,
        AGENT = "blackjackagent",
        MATCH = "FIGHT",
        SEAT = 5,
        EXPRATE = 1,
    },
    [265] = {
        ID = 265,
        COUNT = 10,
        STATE = 1,
        AGENT = "dominoagent",
        MATCH = "FIGHT",
        SEAT = 4,
        EXPRATE = 0.2,
    },
    [269] = {
        ID = 269,
        COUNT = 10,
        STATE = 1,
        AGENT = "ludoagent",
        MATCH = "FIGHT",
        SEAT = 4,
        EXPRATE = 3,
    },
    [287] = {
        ID = 287,
        COUNT = 10,
        STATE = 1,
        AGENT = "unoagent",
        MATCH = "FIGHT",
        SEAT = 4,
        EXPRATE = 0.5,
    },
    [290] = {
        ID = 290,
        COUNT = 10,
        STATE = 1,
        AGENT = "ludoagent",
        MATCH = "FIGHT",
        SEAT = 4,
        EXPRATE = 1,
    },
    [292] = {
        ID = 292,
        COUNT = 10,
        STATE = 1,
        AGENT = "indiarummyagent",
        MATCH = "FIGHT",
        SEAT = 6,
        EXPRATE = 1,
    },
    [291] = {
        ID = 291,
        COUNT = 10,
        STATE = 1,
        AGENT = "teenpattiagent",
        MATCH = "FIGHT",
        SEAT = 5,
        EXPRATE = 1,
    },
    [293] = {
        ID = 293,
        COUNT = 10,
        STATE = 1,
        AGENT = "texasholdemagent",
        MATCH = "FIGHT",
        SEAT = 9,
        EXPRATE = 1,
    }
}

PDEFINE_GAME.TYPE_INFO = 
{
    [12] =   -- Poker Hero
    {
        [1] =  YD_GAME_LIST --匹配场
    },
    [17] =   -- YD: Yono Games
    {
        [1] =  YD_GAME_LIST --匹配场
    },
    [19] =   -- YD: Rummy Vip
    {
        [1] =  YD_GAME_LIST --匹配场
    },
}

PDEFINE_GAME.NUMBER =
{
    views = 16, --观战人数
    maxround = 100000, --最大局数

    people = 2,
    delteTime = 60,
    nvalue = 1000,
    fgrgame = 1000000,
    matchWaitTime = {2, 5},  -- 匹配方需要等待的时间
    maxOptTime = 8,  -- 机器人操作最长时间
    minOptTime = 2,  -- 机器人最低操作时长
    settleCharge = 0.1,  -- 抽水比例
    tn_delayTime = 10,  -- 锦标赛操作时间
}

-- 匹配场次信息
PDEFINE_GAME.SESS =  {
    ['match'] = { --改押注档位，记得改金猪的增长档位
        [255] = { --blackjack （个人）
            [1] = {ssid=1, seat={1,2,3,4,5}, entry = 100, score=100, reward=180, vipLevel=0, section={2000,10000}},
            [2] = {ssid=2, seat={1,2,3,4,5}, entry = 1000, score=1000, reward=1800, vipLevel=0, section={5000,150000}},
            [3] = {ssid=3, seat={1,2,3,4,5}, entry = 5000, score=5000, reward=9000, vipLevel=0, section={25000,1000000}},
            [4] = {ssid=4, seat={1,2,3,4,5}, entry = 50000, score=50000, reward=90000, vipLevel=0, section={250000,-1}}, -- 负1表示无穷大
        },
        [265] = { -- dominuo （个人）
            [1] = {ssid=1, seat={4}, entry = 100, score=100, reward=0, vipLevel=0, section={500,10000}},
            [2] = {ssid=2, seat={4}, entry = 1000, score=2000, reward=0, vipLevel=0, section={5000,150000}},
            [3] = {ssid=3, seat={4}, entry = 5000, score=10000, reward=0, vipLevel=0, section={25000,1000000}},
            [4] = {ssid=4, seat={4}, entry = 50000, score=100000, reward=0, vipLevel=0, section={250000,-1}},
        },
        [269] = { -- ludo
            [1] = {ssid=1, seat={2}, entry = 100, score=5, reward=360, vipLevel=0, section={500,10000}},
            [2] = {ssid=2, seat={2}, entry = 1000, score=20, reward=3600, vipLevel=0, section={5000,150000}},
            [3] = {ssid=3, seat={2}, entry = 5000, score=50, reward=18000, vipLevel=0, section={25000,1000000}},
            [4] = {ssid=4, seat={2}, entry = 50000, score=100, reward=180000, vipLevel=0, section={250000,-1}},
        },
        [287] = {  -- uno （单人）
            [1] = {ssid=1, seat={4}, entry = 100, score=5, reward=360, vipLevel=0, section={500,10000}},
            [2] = {ssid=2, seat={4}, entry = 1000, score=20, reward=3600, vipLevel=0, section={5000,150000}},
            [3] = {ssid=3, seat={4}, entry = 5000, score=50, reward=18000, vipLevel=0, section={25000,1000000}},
            [4] = {ssid=4, seat={4}, entry = 50000, score=100, reward=180000, vipLevel=0, section={250000,-1}},
        },
        [290] = { -- ludo quick
            [1] = {ssid=1, seat={4,6}, entry = 100, score=5, reward=360, vipLevel=0, section={500,10000}},
            [2] = {ssid=2, seat={4,6}, entry = 1000, score=20, reward=3600, vipLevel=0, section={5000,150000}},
            [3] = {ssid=3, seat={4,6}, entry = 5000, score=50, reward=18000, vipLevel=0, section={25000,1000000}},
            [4] = {ssid=4, seat={4,6}, entry = 50000, score=100, reward=180000, vipLevel=0, section={250000,-1}},
        },
        [292] = { -- rummy
            [1] = {ssid=1, seat={2,3,4,5,6}, entry = 10, score=5, reward=36, vipLevel=0, section={1000,10000}},
            [2] = {ssid=2, seat={2,3,4,5,6}, entry = 100, score=20, reward=360, vipLevel=0, section={10000,150000}},
            [3] = {ssid=3, seat={2,3,4,5,6}, entry = 500, score=50, reward=1800, vipLevel=0, section={50000,1000000}},
            [4] = {ssid=4, seat={2,3,4,5,6}, entry = 5000, score=100, reward=18000, vipLevel=0, section={500000,-1}},
        },
        [291] = { -- teenpatti
            [1] = {ssid=1, seat={5}, entry = 100, score=5, reward=360, vipLevel=0, section={2000,100000}},
            [2] = {ssid=2, seat={5}, entry = 1000, score=20, reward=3600, vipLevel=0, section={50000,1500000}},
            [3] = {ssid=3, seat={5}, entry = 5000, score=50, reward=18000, vipLevel=0, section={250000,10000000}},
            [4] = {ssid=4, seat={5}, entry = 50000, score=100, reward=180000, vipLevel=0, section={2500000,-1}},
        },
        [293] = { -- texasholdem
            [1] = {ssid=1, seat={9}, entry = 100, score=5, reward=360, vipLevel=0, section={2000,100000}},
            [2] = {ssid=2, seat={9}, entry = 1000, score=20, reward=3600, vipLevel=0, section={50000,1500000}},
            [3] = {ssid=3, seat={9}, entry = 5000, score=50, reward=18000, vipLevel=0, section={250000,10000000}},
            [4] = {ssid=4, seat={9}, entry = 50000, score=100, reward=180000, vipLevel=0, section={2500000,-1}},
        },
    },
    ['vip'] = {
        [255] = {  -- blackjack
            {entry = 1, seat={5}, reward={}},
            {entry = 10, seat={5}, reward={}},
            {entry = 100, seat={5}, reward={}},
            {entry = 1000, seat={5}, reward={}},
        },
        [265] = {  --  dominuo(个人)
            {entry = 0.1, score = 1000, reward={0.45,4.5}},
            {entry = 10, score = 1000,reward={45,450}},
            {entry = 50, score = 1000,reward={225,2250}},
            {entry = 500,score = 1000, reward={2250,22500}},
        },
        [269] = {  --  ludo(个人)
            {entry = 1, seat={2,4}, reward={1.8,3.6}},
            {entry = 10, seat={2,4}, reward={18,36}},
            {entry = 100, seat={2,4}, reward={180,360}},
            {entry = 500, seat={2,4}, reward={900,1800}},
        },
        [287] = {  -- uno (单人)
            {entry = 1, score=10, seat={4}, reward={3.6,3.6}},
            {entry = 10, score=50, seat={4}, reward={36,36}},
            {entry = 100, score=100, seat={4}, reward={360,360}},
            {entry = 500, score=200, seat={4}, reward={1800,1800}},
        },
        [291] = {  -- teenpatti
            {entry = 0.1, seat={9}, reward={}},
            {entry = 5, seat={9}, reward={}},
            {entry = 10, seat={9}, reward={}},
            {entry = 50, seat={9}, reward={}},
        },
        [292] = {  -- rummy
            {entry = 0.1, seat={6}, reward={}},
            {entry = 1, seat={6}, reward={}},
            {entry = 5, seat={6}, reward={}},
            {entry = 10, seat={6}, reward={}},
        },
        [293] = {  -- 德州扑克
            {entry = 0.1, seat={9}, reward={}},
            {entry = 1, seat={9}, reward={}},
            {entry = 10, seat={9}, reward={}},
            {entry = 100, seat={9}, reward={}},
        },
    }
}
            
--slots游戏场次
PDEFINE_GAME.SLOTS_SESS = {
    [1] = {ssid=1, entry = 100, betRange={1,12}, section={1000,25000}},
    [2] = {ssid=2, entry = 200, betRange={2,13}, section={5000,150000}},
    [3] = {ssid=3, entry = 500, betRange={4,14}, section={25000,1000000}},
    [4] = {ssid=4, entry = 1000, betRange={6,15}, section={250000,-1}}, -- 负1表示无穷大
} 

-- 好友房默认配置
---@param maxRound integer 最大局数
---@param maxScore integer 结算分数
---@param minSeat integer 最小开始人数
---@param voice   integer  是否开启语音 1开启音效 2不开启
---@param turntime integer  延迟时间
---@param invite integer 是否在大厅显示牌桌(发送邀请消息到聊天室)  1:表示显示 2:不显示
PDEFINE_GAME.DEFAULT_CONF = {
    [PDEFINE_GAME.GAME_TYPE.BLACK_JACK]         = {round=nil, maxScore=nil, seat=5, minSeat=2, voice=0, turntime=10, invite=0},  --turntime:10
    [PDEFINE_GAME.GAME_TYPE.DOMINO]             = {round=5, maxScore=nil, seat=4, minSeat=2, voice=1, turntime=8, invite=1},    --turntime:8
    [PDEFINE_GAME.GAME_TYPE.LUDO]               = {round=1, maxScore=nil, seat=4, minSeat=2, voice=1, turntime=10, invite=1},    --turntime:10
    [PDEFINE_GAME.GAME_TYPE.UNO]                = {round=1, maxScore=nil, seat=4, minSeat=4, voice=1, turntime=10, invite=1},    --turntime:10
    [PDEFINE_GAME.GAME_TYPE.LUDO_QUICK]         = {round=1, maxScore=nil, seat=4, minSeat=2, voice=1, turntime=10, invite=1},    --turntime:10
    [PDEFINE_GAME.GAME_TYPE.INDIA_RUMMY]        = {round=1, maxScore=nil, seat=6, minSeat=3, voice=1, turntime=25, invite=1},    --turntime:12
    [PDEFINE_GAME.GAME_TYPE.TEENPATTI]          = {round=1, maxScore=nil, seat=5, minSeat=3, voice=1, turntime=10, invite=1},    --turntime:10
    [PDEFINE_GAME.GAME_TYPE.TEXAS_HOLDEM]       = {round=1, maxScore=nil, seat=9, minSeat=3, voice=1, turntime=10, invite=1},    --turntime:10
}

---@param minSeat integer 少于这个minSeat就会加机器人直到这么多人，再开始
PDEFINE_GAME.DEFAULT_MATCH_CONF = {
    [PDEFINE_GAME.GAME_TYPE.DOMINO]             = {turntime=6}, --turntime:6
    [PDEFINE_GAME.GAME_TYPE.LUDO]               = {turntime=10}, --turntime:10
    [PDEFINE_GAME.GAME_TYPE.UNO]                = {turntime=10}, --turntime:10
    [PDEFINE_GAME.GAME_TYPE.LUDO_QUICK]         = {turntime=10}, --turntime:10
    [PDEFINE_GAME.GAME_TYPE.BLACK_JACK]         = {turntime=10}, --turntime:10
    [PDEFINE_GAME.GAME_TYPE.INDIA_RUMMY]        = {turntime=25}, --turntime:12
    [PDEFINE_GAME.GAME_TYPE.TEENPATTI]          = {turntime=10, minSeat=3},  --turntime:10
    [PDEFINE_GAME.GAME_TYPE.TEXAS_HOLDEM]       = {turntime=10, minSeat=3},  --turntime:10
}

-- VIP能创建的房间数量
PDEFINE_GAME.VIP_ROOM_CNT = {
    [1] = 2, --VIP0
    [2] = 3, --VIP1
    [3] = 3,
    [4] = 3,
    [5] = 3,
    [6] = 3,
    [7] = 4,
    [8] = 4,
    [9] = 4,
    [10] = 5,
    [11] = 5,
    [12] = 5,
    [13] = 8, --vip12
}

-- 破产提示线，下注的多少倍
PDEFINE_GAME.DANGER_BET_MULT = 2

-- 自动创房所用的gameid
PDEFINE_GAME.AUTO_PRIVATE_GAME = {
    PDEFINE_GAME.GAME_TYPE.DOMINO,
}

return PDEFINE_GAME