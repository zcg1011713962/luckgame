
local cluster = require "cluster"
local game_tool = require "game_tool"
local freeTool = require "cashslots.common.gameFree"
local isFreeState = freeTool.isFreeState


--发送结果日志
local function sendGameLog(gameType ,user, deskInfo, prize_result, ex1, ex2)
end

local gameData = {}
---cash. 游戏单独专用代码
--[[游戏数据存redis]]
function gameData.set(deskInfo)
    if not TEST_RTP then
        local data = table.copy(deskInfo)
        data.control = nil
        data.strategy = nil
        game_tool.data.push2Redis(deskInfo.gameid, deskInfo.user.uid, data, 30*24*3600)
    end
end
  
  --检测玩家是否还在上次遗留的免费游戏中，有的话获取在此游戏中上次的免费游戏数据，继续进入免费游戏
function gameData.get(deskInfo)
    if not TEST_RTP then
        return game_tool.data.reloadRedisData(deskInfo.gameid, deskInfo.user.uid)
    end
end
  
function gameData.del(deskInfo)
    if not TEST_RTP then
        game_tool.data.delRedis( deskInfo.gameid, deskInfo.user.uid)
    end
end



--[[后台记录大游戏结果
deskInfo:桌子信息
betCoin：押注额
winCoin： 玩家总赢分
pooljp：  jp奖金，包含在winCoin中
retobj： 返回给客户端的所有数据
]]
local function pushLog(deskInfo, betCoin, winCoin, pooljp, retobj, rtype)
    assert(false, "deprecated function call")
    if not TEST_RTP then
        if rtype == "big" then
            local gameType = "big"
            if isFreeState(deskInfo) then
                if deskInfo.freeGameData.restFreeCount <= 0 then 
                    gameType = "free"
                else
                    gameType = "no"
                end
            end

            local apiRecordResult = {}
            apiRecordResult.comment = "BigGameRecord"
            if gameType == "free" then
                apiRecordResult.comment = "FreeGameRecord"
            end
            apiRecordResult.bet = {singleBet = deskInfo.singleBet, line = deskInfo.line, totalBet = deskInfo.totalBet}
            -- 发游戏结果给api
            local user_1 = {uid = deskInfo.user.uid, bet_coin = -betCoin, win_coin = winCoin + betCoin, winjp_coin = pooljp}
            apiRecordResult.result = retobj
            local apiuser = {send_api_result_userlist = {user_1}}
            -- 是否是自动spin
            -- {all=总次数, rmd=剩余次数}
            local ex1, ex2
            if deskInfo.bAuto then
                ex1 = {auto={total=deskInfo.bAuto.all, rest=deskInfo.bAuto.rmd}}
            end
            sendGameLog(gameType, apiuser, deskInfo, apiRecordResult, ex1, ex2)
        elseif rtype == "cmd51" then
            local gameType = "cmd51"
            --=========================================
            local is_win
            local winCoin = retobj.winCoin or 0
            if winCoin > 0 then
                is_win = true
            end

            local apiRecordResult = {}
            apiRecordResult.comment = "Cmd51Record"
            apiRecordResult.bet = {data = retobj, is_win = is_win}
            apiRecordResult.result = retobj
            local user_1 = {
                uid = deskInfo.user.uid, 
                bet_coin = 0, 
                win_coin = winCoin, 
            }
            local apiuser = {send_api_result_userlist = {user_1}}
            sendGameLog(gameType, apiuser, deskInfo, apiRecordResult)
        end 
    end
end

return {
    gameData = gameData,
    pushLog = pushLog,
}


