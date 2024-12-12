-- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块, 0x*E为A, 0x51小王， 0x52大王
Cards = {  --使用两副牌（只有一组大小鬼）
	0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
	0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
	0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
	0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,

	0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
	0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
	0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
	0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
	0x51,0x52
},

--------------------------------------------------------------------
--spcode错误码
COIN_NOT_ENOUGH = 804       --金币不足
PARAMS_ERROR =  101001,  -- 参数错误
USER_NOT_FOUND  =101002     --未找到玩家
USER_STATE_ERROR = 101003   --玩家状态错误
HAND_CARDS_ERROR = 101006, -- 手牌未找到

--牌型
local CardType =
{
    Invalid = 0,--非法牌
    Pts = 1,    --单牌
    Set = 2,    --刻子
    Seq = 3,    --顺子
    PureSeq = 4,--纯顺子
}

--------------------------------------------------------------------

--玩家状态
local PlayerState = {
    Wait = PDEFINE.PLAYER_STATE.Wait,       --等待状态(1)
    Ready = PDEFINE.PLAYER_STATE.Ready,     --就绪状态(2)
    Draw = 3,   --摸牌状态
    Discard = 4,--出牌状态
    Confirm = 5,--定牌状态(该状态还未定牌，定完之后变成Show状态)
    Show = 6,   --亮牌状态(亮牌成功或Confirm后的状态)
    Fail = 7,   --亮牌失败
    Drop = 8,   --弃牌状态
}

--游戏状态
local DeskState = {
    Match = 1,          --匹配阶段
    Ready = 2,          --准备阶段
    Play = 3,           --玩牌阶段
    Compare = 4,        --比牌阶段
    Settle = 5,         --结算阶段
}

--------------------------------------------------------------------

--玩家回合信息
user.round = {
    cards       = {} --手牌
    groupcards  = {} --分组的牌
    dropmult    = 20 --drop倍数
    point       = 0  --点数（用于算分）
    wincoin     = 0  --赢分
}

--底分
deskInfo.basecoin = 100
--桌子回合信息
deskInfo.round = {
    discardCards = {}    --弃牌牌堆
    wildCard = 0         --癞子牌
    activeSeat = 0       --当前活动座位号
    winnerUid  = 0       --亮牌成功的玩家id
    poolcoin   = 0       --池子金币数
}

--------------------------------------------------------------------

--上行协议（玩家操作后会同时广播给桌上其他玩家）
["29201"] = "cluster.game.dsmgr.drop",      --弃牌
["29202"] = "cluster.game.dsmgr.draw",      --摸牌
["29203"] = "cluster.game.dsmgr.show",      --亮牌
["29204"] = "cluster.game.dsmgr.discard",   --出牌
["29205"] = "cluster.game.dsmgr.arrange",   --理牌
["29206"] = "cluster.game.dsmgr.confirm",   --定牌


--下行协议（通知）
GAME_DEAL                  = 126003, -- 游戏开始发牌
GAME_ROUND_OVER            = 126005, -- 回合结束

--------------------------------------------------------------------

--协议详细说明
--发牌 GAME_DEAL
--通知
{
    c = 126003,
    cardCnt = 14,           --发牌堆剩余数量
    wildCard = 0x42,        --癞子牌
    discardCards = {0x41},  --弃牌牌堆
    activeSeat = 1,         --活动玩家座位号
    activeState = 3,        --活动玩家座位号
    delayTime = 10,         --倒计时时间
    cards = {0x11,0x12,0x13, ...},  --手牌(未分组)
    groupcards = {{0x11,0x12}, {0x23,0x24}, ...}   --手牌牌组
}

--结算 GAME_ROUND_OVER
--通知
{
    c = 126005,
    settle = {
        {
            seatid = 1,
            wincoin = 10,   --输赢金币
            groupcards = {{0x11, 0x12}, {0x23,0x24}, ...},  --牌组
            point = 20  --点数
        },
        ...
    },
    delayTime = 10, --下局开始倒计时
}

-- 弃牌drop
--请求
{
    c = 29201,
}
--返回（并同时广播给所有玩家）
{
    c = 29201,
    spcode = 0,     --操作成功为0（下同）
    uid = 10000,    --玩家ID（操作玩家ID，下同）
    userState = 8,  --玩家状态（玩家操作后的状态，下同）
    activeSeat = 2， --活动玩家座位号（当前操作的玩家，下同）
    activeState = 3, --活动玩家状态（当前操作的玩家的状态，下同）
    delayTime = 10,  --倒计时时间（当前玩家操作的剩余时间，下同）
    poolcoin = 200,  --池子金币数
}

-- 摸牌draw
--请求
{
    c = 29202,
    op = 1, --1：从发牌堆摸， 2：从弃牌堆摸
}
--返回（并同时广播给所有玩家）
{
    c = 29202,
    spcode = 0,
    uid = 10000,
    userState = 4,
    card = 0x21,    --摸到的牌
    dropmult = 40,  --弃牌倍数
    cardCnt = 32,   --发牌堆剩余牌数
    activeSeat = 2
    activeState = 3,
    delayTime = 10,
}

-- 亮牌show
--请求
{
    c = 29203,
    card = 0x21,    --打出的牌
    groupcards = {{0x11, 0x12}, {0x23,0x24}, ...},  --出牌后的牌组
}
--返回（并同时广播给所有玩家）
{
    c = 29203,
    spcode = 0,
    uid = 10000,
    userState = 6,
    card = 0x21,
    sucess = 1,  --0:失败 1:成功
    activeSeat = {2,3,4},  --如果亮牌成功，此处为数组，数组内的玩家全部切换到Confirm(activeState)状态，同时Confirm
    activeState = 3,
    delayTime = 10,
}

-- 出牌discard
--请求
{
    c = 29204,
    card = 0x21,    --打出的牌
    groupcards = {{0x11, 0x12}, {0x23,0x24}, ...},  --出牌后的牌组
}
--返回（并同时广播给所有玩家）
{
    c = 29204,
    spcode = 0,
    uid = 10000,
    userState = 6,
    card = 0x21,
    activeSeat = 2,
    activeState = 3,
    delayTime = 10,
}

-- 理牌arrange
--请求
{
    c = 29205,
    groupcards = {{0x11, 0x12}, {0x23,0x24}, ...},  --出牌后的牌组
}
--返回（不广播）
{
    c = 29205,
    spcode = 0,
    uid = 10000,
}

-- 定牌confirm
--请求
{
    c = 29206,
    groupcards = {{0x11, 0x12}, {0x23,0x24}, ...},  --出牌后的牌组
}
--返回（并同时广播给所有玩家）
{
    c = 29206,
    spcode = 0,
    uid = 10000,
    userState = 6,
}







