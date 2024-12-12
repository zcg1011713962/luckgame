local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local config = require"cashslots.common.config"
local player_tool = require "base.player_tool"
--检测是否是免费状态
local function isFreeState(deskInfo)
	if deskInfo.state ~= config.GAME_STATE["FREE"] then
		return false
	else
		return true
	end
end

--[[
TODO: 一般是看scatter有几个
freeCnt的定义在代码中做了处理
freeGameConf = {card = scatter, min = 3, freeCnt = 15}
local freeGameConf = {card = scatter, min = 3, freeCnt = {[3] = 7, [4] = 10, [5] = 15}}
]] 
local function checkFreeGame(cards, freeGameConf)
    if not freeGameConf then
        return {}
    end
    local freeCardIdxs = {}
    for k, v in pairs(cards) do
        if v == freeGameConf.card then
            table.insert(freeCardIdxs, k)
        end
    end
    local ret = {}
    if #freeCardIdxs >= freeGameConf.min then
        ret.freeCnt = freeGameConf.freeCnt
        ret.scatterIdx = freeCardIdxs
        ret.scatter = freeGameConf.card  
        ret.addMult = freeGameConf.addMult  or 1
        ret.idxs = freeCardIdxs         --为通用idxs
    end
    return ret
end

--玩家金币操作处理
local function caulCoin(deskInfo, coin, type)
    local poolround_id = 0
    coin = Double_Add(coin, 0)
    player_tool.calUserCoinSlot(
        deskInfo.user.uid, 
        coin, 
        "拉霸"..deskInfo.gameid.."修改金币:"..coin, 
        type, 
        deskInfo,
        poolround_id
    )
    deskInfo.user.coin = Double_Add(deskInfo.user.coin, coin)
    if type == PDEFINE.ALTERCOINTAG.WIN then
        deskInfo.lastWinCoin = coin
    end
end

--[[
    内存数据，免费游戏数据及桌子状态更新
    更新数据：
        state：桌子状态，触发时修改，结束时修改

        allFreeCount：总次数
        restFreeCount：剩余次数
        freeWinCoin： 免费总赢分（免费游戏结束后统一结算）
        addMult： 免费期间翻倍

    总结
    1.触发免费：
        1.1.普通状态触发免费： updateDeskFreeInfo(deskInfo, {winCoin = 0, startFree = true, freeCnt = *, addMult = *})
        1.2.免费状态触发免费： updateDeskFreeInfo(deskInfo, {winCoin = winCoin, freeIng = true, freeCnt = *, addMult = *})
    2.免费状态更新数据：updateDeskFreeInfo(deskInfo, {winCoin = winCoin, freeIng = true, freeCnt = -1, addMult = *})
    3.关闭免费: updateDeskFreeInfo(deskInfo, {endFree = true})
]]
local function updateDeskFreeInfo(deskInfo, data) --freeIng 免费进行中
    if data.startFree ~= nil and data.startFree then
        deskInfo.state = config.GAME_STATE["FREE"]              --**关键**游戏修改
        deskInfo.freeGameData.allFreeCount = data.freeCnt       -- 总次数
        deskInfo.freeGameData.restFreeCount = data.freeCnt      -- 剩余免费次数
        deskInfo.freeGameData.freeWinCoin = data.winCoin or 0   --免费期间总赢分
        if data.addMult ~= nil then
            deskInfo.freeGameData.addMult = data.addMult
        end
        deskInfo.freeGameData.triFreeData = {
            triFreeCnt = 1,
            freeInfo = data.freeInfo or {}
        }
                --记录触发次数
    elseif data.freeIng ~= nil and data.freeIng then
          deskInfo.freeGameData.restFreeCount = deskInfo.freeGameData.restFreeCount + data.freeCnt
          deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + data.winCoin
          deskInfo.freeGameData.triFreeData.freeInfo = {}
          if data.freeCnt >= 0 then                             --免费触发免费
              deskInfo.freeGameData.allFreeCount = deskInfo.freeGameData.allFreeCount + data.freeCnt    -- 总次数
              deskInfo.freeGameData.triFreeData.triFreeCnt = deskInfo.freeGameData.triFreeData.triFreeCnt + 1        --记录触发次数 
              deskInfo.freeGameData.triFreeData.freeInfo = data.freeInfo or {}
          end
          if data.addMult ~= nil then
              deskInfo.freeGameData.addMult = data.addMult
          end
    elseif data.endFree ~= nil and data.endFree then  -- 结束时需要把状态改变
        if deskInfo.freeGameData.addMult ~= nil then
            deskInfo.freeGameData.addMult = 1
        end
        deskInfo.state = config.GAME_STATE["NORMAL"]        --**关键**游戏修改
        deskInfo.freeGameData = {                           --重置游戏数据
            allFreeCount = 0,
            restFreeCount = 0,
            freeWinCoin = 0,
            addMult = 1,
            triFreeData = {freeInfo = {}, triFreeCnt = 0},
        }
    end
    return deskInfo
end
--[[
    --type： 1.普通触发，2：免费中更新数据，3.免费结束
    --freeCnt: 免费次数
    --addMult:  倍数
    --winCoin: 赢分
]]
local function updateFreeData(deskInfo, type, freeCnt, addMult, winCoin, freeInfo)
    if addMult == 0 then
        addMult = 1
    end
    if type == 1 then
        if not isFreeState(deskInfo) then
            local freeCnt = freeCnt
            local addMult = addMult or 1
            updateDeskFreeInfo(deskInfo, {winCoin = winCoin, startFree = true, freeCnt = freeCnt, addMult = addMult, freeInfo = freeInfo}) --wincoin=0 触发这一局的不算在免费游戏中
        else
            updateDeskFreeInfo(deskInfo, {winCoin = winCoin, freeIng = true, freeCnt = freeCnt, freeInfo = freeInfo})
        end
        -- local spinData = {
        --     betCoin = 0,
        --     winCoin = 0,
        --     triggerFree = 1,
        --     isFree = 0,
        --     triggerBonus = 0,
        --     resultCards = {},
        --     spEffectkind = 0,
        -- }
        -- pcall(cluster.call, "master", ".club", "onSpin", deskInfo.user.uid, spinData)
    elseif type == 2 then
        updateDeskFreeInfo(deskInfo, {winCoin = winCoin, freeIng = true, freeCnt = -1})
    elseif type == 3 then
        caulCoin(deskInfo, deskInfo.freeGameData.freeWinCoin, PDEFINE.ALTERCOINTAG.WIN)
        updateDeskFreeInfo(deskInfo, {endFree = true})
    end
end


return {
    isFreeState = isFreeState,
    checkFreeGame = checkFreeGame,
    updateFreeData = updateFreeData,
}