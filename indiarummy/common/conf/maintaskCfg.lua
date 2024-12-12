
local PROP_ID = PDEFINE.PROP_ID
local KIND = PDEFINE.MAIN_TASK.KIND

local Cfg = {
    [KIND.Pay] = {
        {id=1, ord=1, desc="累积完成100充值", params={100}, en_desc="Complete recharge 100",  rewards={{type=PROP_ID.COIN, count=50}}},
        {id=2, ord=1, desc="累积完成1000充值", params={1000}, en_desc="Complete recharge 1000",  prev=1, rewards={{type=PROP_ID.COIN, count=100}}},
        {id=3, ord=1, desc="累积完成3000充值", params={3000, en_desc="Complete recharge 3000",  prev=2, rewards={{type=PROP_ID.COIN, count=160}}}},
    },
    [KIND.WinCoin] = {
        {id=1, ord=2,  desc="累积在游戏内赢得50000金币", params={50000}, en_desc="Accumulate to win 50000 gold coins in the game", rewards={{type=PROP_ID.COIN, count=5}}},
        {id=2, ord=2, desc="累积在游戏内赢得100000金币", params={100000}, en_desc="Accumulate to win 100000 gold coins in the game", prev=1, rewards={{type=PROP_ID.COIN, count=10}}},
        {id=3, ord=2,  desc="累积在游戏内赢得200000金币", params={200000}, en_desc="Accumulate to win 200000 gold coins in the game", prev=2, rewards={{type=PROP_ID.COIN, count=12}, {type=PROP_ID.SKIN_CHARM, count=3, img="gift_1"}}},
    },
    [KIND.GameTimes] = {
        {id=1, ord=3, desc="累积在2局游戏内获胜", params={2}, en_desc="Accumulate wins in 2 rounds of games",  rewards={{type=PROP_ID.COIN, count=5}}},
        {id=2, ord=3, desc="累积在5局游戏内获胜", params={5}, en_desc="Accumulate wins in 5 rounds of games",  prev=1, rewards={{type=PROP_ID.COIN, count=10}}},
        {id=3, ord=3, desc="累积在8局游戏内获胜", params={8}, en_desc="Accumulate wins in 8 rounds of games",  prev=2, rewards={{type=PROP_ID.COIN, count=20}}},
    },
    [KIND.BetCoin] = {
        {id=1, ord=4,  desc="累积在游戏内下注100", params={100}, en_desc="Accumulate wins in 2 rounds of games",  rewards={{type=PROP_ID.COIN, count=5}}},
        {id=2, ord=4, desc="累积在游戏内下注1000", params={1000}, en_desc="Accumulate wins in 5 rounds of games",  prev=1, rewards={{type=PROP_ID.COIN, count=10}}},
        {id=3, ord=4, desc="累积在游戏内下注3000", params={3000}, en_desc="Accumulate wins in 8 rounds of games", prev=2, rewards={{type=PROP_ID.COIN, count=20}}},
    },
}

return Cfg