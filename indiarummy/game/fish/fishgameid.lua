--捕鱼游戏ID


--游戏ID定义
local GAME_ID = {
    MIN_ID = 51,
    HWBY = 32,   -- 海王捕鱼
    JACKPOT_FISH = 81,  --彩金捕鱼
    MEGA_FISH = 82,     --王者捕鱼
    MAX_ID = 82,
}


--是否海王捕鱼
function GAME_ID.isHWBY(gameid)
    return (gameid==GAME_ID.JACKPOT_FISH or gameid==GAME_ID.MEGA_FISH)
end

return GAME_ID