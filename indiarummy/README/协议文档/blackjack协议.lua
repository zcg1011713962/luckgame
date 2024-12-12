--牌定义
-- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块
Cards = {
	0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
	0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
	0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
	0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
},

--spcode错误码
USER_STATE_ERROR = 101003
USER_NOT_FOUND  =101002
COIN_NOT_ENOUGH = 804

--牌型
CardType = {
	Boom = 0, 			--爆牌
	P1 = 1,				--1点
	P2 = 2,				--2点
	...
	P21 = 21,			--21点
	FiveCard = 100,		--五张
	BalckJack = 101,	--black jack
	
}

--玩家状态
local PlayerState = {
    Wait = 1,       --等待状态
    Ready = 2,     --就绪状态(还没轮到操作)
    Bet = 3,    --下注状态
    Insure = 4,--选择保险状态（该状态必须选择投保还是拒保）
    Play = 5,   --玩牌状态(该状态可以选择停牌/要牌/加倍/拆牌)
    Stand = 6,  --停牌状态(操作已完成)
}

--游戏状态
local DeskState = {
    Match = PDEFINE.DESK_STATE.MATCH,      --匹配阶段（1）
    Ready = PDEFINE.DESK_STATE.READY,      --准备阶段（2）
    Play = PDEFINE.DESK_STATE.PLAY,       --玩牌阶段（3）
    Bet = 4,        --下注阶段
    Insure = 5,     --选择保险阶段
    Settle = 6,     --结算阶段
}

--上行协议
["25501"] = "cluster.game.dsmgr.bet",           --下注
["25502"] = "cluster.game.dsmgr.stand",         --停牌
["25503"] = "cluster.game.dsmgr.hit",           --要牌
["25504"] = "cluster.game.dsmgr.double",        --加倍
["25505"] = "cluster.game.dsmgr.split",         --拆牌
["25506"] = "cluster.game.dsmgr.insure",        --投保/拒保


--下行协议（通知）
GAME_BET                   = 126045, -- 游戏开始下注 
GAME_DEAL                  = 126003, -- 游戏开始发牌
GAME_ROUND_OVER            = 126005, -- 回合结束
GAME_INSURE_OVER           = 126046, -- 保险结束 

--协议详细说明
--1, 开始下注
--通知
{
	c = 126045,
	code = 200,
	mincoin = 10,	--最小注
	maxcoin = 1000,	--最大注
	delayTime = 10, --倒计时时间
}

--2，下注 bet
--请求
{
	c = 25501,
	betcoin = 100, --押注金额
}
--返回(当spcode==0会同时广播给其他玩家，停牌/要牌/加倍/拆牌/投保/拒保同样如此)
{
	c = 25501,
	code = 200,
	spcode = 0, --错误号，0表示操作成功
	seat = 1, --座位号
	userState = 5,--玩家状态
	betcoin = 100,
}

--3 开始发牌
--通知
{
	c = 126003,
	seats = {1, 3, 4}, --闲家座位号
	handcards = {		-- 闲家手牌，因为存在split后出现两副手牌，所以闲家手牌使用数组表示，数组里放一副或两副手牌
		{{62,54}},
		{{63,55}},
		{{52,73}},
	},
	cardtypes = {  --闲家手牌牌型
		{11},
		{21},
		{101}
	}
	bankercard = {41, 0},  --庄家手牌，0显示为牌背
	activeSeat = 1,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	delayTime = 6,	--活动玩家倒计时
}

--2，停牌 stand
--请求
{
	c = 25502,
} 
--返回
{
	c = 25502,
	code = 200,
	spcode = 0,
	seat = 4,
	userState = 5,--玩家状态
	tileid = 2, --操作的牌堆  (操作顺序先2后1，先右后左, ==1表示操作的是左边的牌堆，==2表示操作的是右边的牌堆, 单牌堆该值为1)
	activeSeat = 2,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	activeTile = 2, --活动牌堆
	delayTime = 6,	--活动玩家倒计时
}

--2，要牌 hit
--请求
{
	c = 25503,
} 
--返回
{
	c = 25503,
	code = 200,
	spcode = 0,
	seat = 4,
	userState = 5,--玩家状态
	handcard = {{42,43,44}}, --手牌
	cardtype = {14}, --牌型
	tileid = 2, --操作的牌堆
	activeSeat = 2,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	activeTile = 2, --活动牌堆
	delayTime = 6,	--活动玩家倒计时
}

--2，加倍 double
--请求
{
	c = 25504,
} 
--返回
{
	c = 25504,
	code = 200,
	spcode = 0,
	seat = 4,
	userState = 5,--玩家状态
	betcoin = {200},	--下注额
	handcard = {{42,43,44}}, --手牌 （下注额翻倍，并添加一张牌，然后停牌）
	cardtype = {14}, --牌型
	tileid = 2, --操作的牌堆（只有单堆牌的时候为1）
	activeSeat = 2,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	activeTile = 2, --活动牌堆
	delayTime = 6,	--活动玩家倒计时
}

--2，拆牌 split
--请求
{
	c = 25505,
} 
--返回
{
	c = 25505,
	code = 200,
	spcode = 0,
	seat = 4,
	userState = 5,--玩家状态
	handcard = {{42,43},{10,11}},
	cardtype = {12,14}, --牌型
	betcoin = {100, 100}, --下注额
	activeSeat = 2,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	activeTile = 2, --活动牌堆
	delayTime = 6,	--活动玩家倒计时
}

--2，保险 insure
--请求
{
	c = 25506,
	choice = 0,  --0:不买保险  1：买保险
} 
--返回
{
	c = 25502,
	code = 200,
	spcode = 0,
	seat = 4,
	choice = 1, --是否保险
	insurecoin = 100, --保险金额
	userState = 5,--玩家状态
	activeSeat = 2,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	delayTime = 6,	--活动玩家倒计时
}

--7，保险结算
--通知
{
	c = 126046,
	code = 200,
	res = 0,  --保险结果, 0，庄家非黑杰克  1，庄家黑杰克
	--如果庄家黑杰克，有下列字段
	bankercard: {{11,12}}, --庄家开牌
	bankertype: 13,  --庄家牌型
	bankerwin: 200, --庄家赢分
	settle: {
		{
			seatid: 1,	--座位号
			wincoin: 100,	--赢分
			coin: 10000,	--当前金币
		},
		{
		...
		},
		...
	},
	--如果庄家非黑杰克，有下列字段
	activeSeat = 2,	--活动玩家座位号
	activeState = 3,--活动玩家状态
	delayTime = 6,	--活动玩家倒计时
	
}



--7，小结算
--通知
{
	c = 126005,
	code = 200,
	bankercard: {{11,12},{11,12,13}}, --庄家开牌
	bankertype: {13, 0},  --庄家牌型
	bankerwin: 200, --庄家赢分
	settle: {
		{
			seatid: 1,	--座位号
			wincoin: 100,	--赢分
			coin: 10000,	--当前金币
		},
		{
		...
		},
		...
	}
	
}

