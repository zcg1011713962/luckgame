--[[
-- Author: 
-- Date: 2019-02-13
-- 功能描述:
	1.通用的小游戏
]] 

local configline = require "cashslots.config.configline"
local configJackpot = require "jackpotConfig"

local GAME_STATE = {
    ["NORMAL"] = 1,
    ["FREE"] = 2,
    ["OTHER"] = 3,
}

local POS = {
    [5] = {1, 2, 3, 4, 5},
    [15] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
    [20] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20},
}

local LINECONF = configline.LINECONF
local MULTSCONF = configline.MULTSCONF
-- 这里卡牌配置已经分离到不同文件
local CARDCONF = setmetatable({}, {
    __index = function(CARDCONF, gameId)
        local cardConf = require ("cashslots.config.card.card_"..gameId)
        return cardConf
    end
})

local JACKPOTCONF = configJackpot

local LINEINDEX = {
    [5] = {
        [3] = {
            {1,6,11},{2,7,12},{3,8,13},{4,9,14},{5,10,15},
        },
        [4] = {
           {1,6,11,16},{2,7,12,17},{3,8,13,18},{4,9,14,19},{5,10,15,20} 
        },
    },
    [3] = {
        [3] = {
            {1,4,7},{2,5,8},{3,6,9}
        },
    }
}


return {
    POS = POS,
    MULTSCONF = MULTSCONF,
    LINECONF = LINECONF,
    GAME_STATE = GAME_STATE,
    CARDCONF = CARDCONF,
    LINEINDEX = LINEINDEX,
    JACKPOTCONF = JACKPOTCONF,
}