--
-- Author: 
-- Date: 2019-03-29
-- 配牌器接口

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"

local casetesting = false
if skynet then
    casetesting = skynet.getenv('casetesting')
end

local REDIS_KEY_PREFIX = "testcase"     -- 牌型 redis key前缀

--获取QA配置的测试牌型
--@param gameid 游戏ID
--@param userid 玩家ID
--@return 配置牌型，游戏直接按此牌型出牌
local function getCaseCards(gameid, userid)
    if not casetesting then
        return nil
    end
    local key = REDIS_KEY_PREFIX..":"..gameid..":"..userid
    local cards = do_redis({"get", key})
    if cards then
        do_redis({"del", key})
        return cjson.decode(cards)
    end
end


return {
    getCaseCards = getCaseCards,
}