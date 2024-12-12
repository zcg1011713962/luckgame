local balcfg = {}

balcfg.CARDS= --扑克数据原始数据
{
	0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E, --方 16
    0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E, --梅 32
    0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E, --红 48
    0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E, --黑桃 64
}

balcfg.TYPE = { -- 游戏玩法选项 1 hokom 2 sun 3 ashkal 4 pass 
	['HOKOM'] = 1,
    ['SUN'] = 2,
    ['ASHKAL'] = 3,
    ['PASS'] = 4,
	['TWO'] = 5, --2倍
	['THREE'] = 6, --3倍
	['FOUR'] =7, --4倍
	['GAHWA'] = 8, --一把定输赢
	['LOCK'] = 9, --锁住
	['OPEN'] = 10, --打开
	['SECOND'] = 11, --SECOND HOKOM 
	['CONFIRM'] = 12, --confirm hokom
	['NEITHER'] = 13, --neither
}

balcfg.QUEST_ID = {
	['SPECIAL'] = { --特殊牌型
		['LEAGUE'] = {75,76,77}, --排位赛特殊牌型任务id
		['OTHER'] = {4,5,6} 
	},
	['GAMETIMES'] = { --游戏次数
		['OTHER'] = {30,31,32}, --其他
	},
	['WINTIMES'] = { --赢的次数
		['OTHER'] = {1,2,3}, --其他
	},
	['SIRA'] = {
		['LEAGUE'] = {75,76,77},
		['OTHER'] = {4,5,6}
	}
}

-- 玩家状态
balcfg.UserState = {
    Wait = 1,  -- 等待状态
    Ready = 2,  -- 准备阶段
    Bidding = 3,  -- 选玩法状态
    Gameing = 4,  -- 游戏中
    -- Discard = 5,  -- 出牌阶段
}

-- balcfg.DeskState = {
--     ["READYGO"] = PDEFINE.DESK_STATE.READY, --游戏开始
--     ["SELECT"]   = PDEFINE.DESK_STATE.BIDDING, --发牌,玩法选择中
--     ["GAMEING"]= PDEFINE.DESK_STATE.PLAY, --游戏中
--     ["SETTLE"] = PDEFINE.DESK_STATE.SETTLE, --结算
-- 	["MATCHING"] = PDEFINE.DESK_STATE.MATCH, --匹配状态
-- }
return balcfg